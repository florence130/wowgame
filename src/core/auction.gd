class_name Auction
extends RefCounted
## 交易所（单机模拟）。数据存 Game.pd["ah"]：
##   market: 其他"玩家"的挂单 [{id, n, price, seller}]，每 10 分钟（游戏时长）刷新
##   mine:   自己的拍卖 [{id, n, price, start, dur, sell_at, state}]；state = active / sold / expired
## 时间基准为角色游戏时长 pd["played"]（离线不流逝）。卖出时价格越接近市价越容易成交。

const REFRESH := 600.0
const DURATIONS := [[600.0, "10分钟", 1], [1800.0, "30分钟", 2], [3600.0, "60分钟", 4]]
const CUT := 0.05            # 成交手续费
const DEPOSIT_RATE := 0.05   # 保管费（按商店回收价 × 时长档位）
const SELLERS := ["海鸥商会", "银帆", "露娜", "老杰克", "米拉贝尔", "灰鸦商行", "卡尔", "晴空", "布兰登", "风笛手", "莉迪亚", "铁锚",
	"小麦", "珍珠", "奥斯汀", "红胡子", "塞西", "潮汐", "北风", "琥珀"]
const MARKET_GOODS := ["mat_linen", "mat_wool", "mat_leather", "mat_aether", "potion_heal1", "potion_heal2", "potion_mana1", "food_cheese", "food_meat"]

static func data() -> Dictionary:
	if not Game.pd.has("ah"):
		Game.pd["ah"] = {"market": [], "gen_at": -INF, "mine": []}
	return Game.pd["ah"]

static func now() -> float:
	return Game.pd.get("played", 0.0)

## 物品的市场参考价（单件）
static func market_value(id: String) -> int:
	var it := DB.get_item(id)
	var base: int = it.get("price", 1)
	if it.get("equip", "") != "":
		return maxi(1, int(base * (3.0 + it.get("q", 1) * 1.2)))
	return maxi(1, base * 3)

static func can_sell(id: String) -> bool:
	var it := DB.get_item(id)
	if it.is_empty() or it.get("quest_item", false) or it.get("price", 0) <= 0:
		return false
	return not id in ["hearthstone"] and it.get("type", "") != "junk"

static func deposit_fee(id: String, n: int, dur_i: int) -> int:
	return maxi(1, int(DB.get_item(id).get("price", 1) * n * DEPOSIT_RATE * DURATIONS[dur_i][2]))

# ---------------------------------------------------------------- 市场
static func market() -> Array:
	var d := data()
	if d["market"].is_empty() or now() - d["gen_at"] > REFRESH:
		_regen_market()
	return d["market"]

static func _regen_market() -> void:
	var d := data()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(now() / REFRESH) * 7919 + hash(Game.pd.get("name", ""))
	var lvl: int = Game.pd.get("level", 1)
	var out := []
	for i in 22:
		var r := rng.randf()
		var q := 1 if r < 0.45 else (2 if r < 0.85 else (3 if r < 0.97 else 4))
		var ilvl := clampi(lvl + rng.randi_range(-4, 3), 1, DB.MAX_LEVEL)
		var id := DB.random_gear(ilvl, q, rng)
		out.append({"id": id, "n": 1, "price": int(market_value(id) * rng.randf_range(0.8, 1.45)), "seller": SELLERS[rng.randi() % SELLERS.size()]})
	for i in 10:
		var gid: String = MARKET_GOODS[rng.randi() % MARKET_GOODS.size()]
		var ms: int = DB.get_item(gid).get("stack", 1)
		var n := rng.randi_range(1, ms)
		out.append({"id": gid, "n": n, "price": int(market_value(gid) * n * rng.randf_range(0.8, 1.3)), "seller": SELLERS[rng.randi() % SELLERS.size()]})
	d["market"] = out
	d["gen_at"] = now()

static func buy(index: int) -> bool:
	var m: Array = market()
	if index < 0 or index >= m.size():
		return false
	var e: Dictionary = m[index]
	if Game.pd["money"] < e["price"]:
		Game.err("你没有足够的钱。")
		return false
	if Game.free_bag_slots() < 1:
		Game.err("背包已满。")
		return false
	Game.add_money(-e["price"], true)
	Game.add_item(e["id"], e["n"])
	m.remove_at(index)
	Sfx.play("coin")
	return true

# ---------------------------------------------------------------- 出售
static func post(bag_idx: int, total_price: int, dur_i: int) -> bool:
	var st = Game.pd["bag"][bag_idx]
	if st == null or not can_sell(st["id"]):
		Game.err("这件物品不能拍卖。")
		return false
	if total_price <= 0:
		Game.err("请输入售价。")
		return false
	var fee := deposit_fee(st["id"], st["n"], dur_i)
	if Game.pd["money"] < fee:
		Game.err("你付不起保管费。")
		return false
	var id: String = st["id"]
	var n: int = st["n"]
	Game.add_money(-fee, true)
	Game.remove_at(bag_idx)
	var dur: float = DURATIONS[dur_i][0]
	var ratio := float(total_price) / float(market_value(id) * n)
	var p := clampf(1.25 - 0.55 * ratio, 0.05, 0.95)
	var sell_at := -1.0
	if randf() < p:
		sell_at = now() + dur * randf_range(0.15, 1.0)
	data()["mine"].append({"id": id, "n": n, "price": total_price, "start": now(), "dur": dur, "sell_at": sell_at, "state": "active"})
	Game.msg("拍卖已上架：[%s]%s，售价 %s（保管费 %s）。" % [DB.get_item(id)["name"], ("x%d" % n) if n > 1 else "", U.money_text(total_price), U.money_text(fee)], Color("ffe9a8"))
	return true

static func cancel(i: int) -> void:
	var mine: Array = data()["mine"]
	var e: Dictionary = mine[i]
	if e["state"] == "sold":
		return
	if Game.add_item(e["id"], e["n"], true) > 0:
		return
	mine.remove_at(i)
	Game.msg("你取回了[%s]。" % DB.get_item(e["id"])["name"], Color("ffe9a8"))

static func clear_sold() -> void:
	var mine: Array = data()["mine"]
	for i in range(mine.size() - 1, -1, -1):
		if mine[i]["state"] == "sold":
			mine.remove_at(i)

## 由 Game 每 5 秒调用：结算成交与过期
static func tick() -> void:
	if not Game.pd.has("ah"):
		return
	var t := now()
	for e in data()["mine"]:
		if e["state"] != "active":
			continue
		var nm: String = DB.get_item(e["id"]).get("name", "?")
		if e["sell_at"] >= 0.0 and t >= e["sell_at"]:
			e["state"] = "sold"
			var gain := maxi(1, int(e["price"] * (1.0 - CUT)))
			Game.add_money(gain, true)
			Game.msg("交易所：你的[%s]已售出，获得 %s（已扣除 5%% 手续费）。" % [nm, U.money_text(gain)], Color("80ff80"))
			Sfx.play("coin")
			Achieve.bump("auction_sold")
		elif t >= e["start"] + e["dur"]:
			e["state"] = "expired"
			Game.msg("交易所：你的[%s]没有卖出，拍卖已过期。请到交易所取回。" % nm, Color("ffb060"))
