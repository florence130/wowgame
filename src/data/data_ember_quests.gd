extends RefCounted
## 晴岚港市民篇：16条主线、14条并行支线。数据由DataWorld合并。

static func quests() -> Dictionary:
	var q := {}
	# 港口调查（15–16）：城内取证后，在东郊转运点成组外勤。
	q["q_e1"] = _q("余烬的账本", 15, "mayor", "archivist", ["q_c19"],
		[_visit("poi_archive", "城市档案馆"), _gather("q_ash_ledger", 1, "ember_ledger")],
		"守钟人已经倒下，可港务局仍在收到灰巾帮的燃料订单。市政档案馆有一份扣押的灰烬账本。去档案馆取出账本，交给奥斯本辨认。",
		"这不是圣堂的军费账，而是一条仍在运作的运输线。先查货箱的标签和海关的存档，我们需要能送进裁定厅的证据。", 1.4, true)
	q["q_e8"] = _q("档案馆的空白页", 15, "archivist", "archivist", ["q_e1"],
		[_visit("poi_customs", "海关"), _gather("q_ledger_page", 4, "ember_manifest")],
		"账本缺失的四页可能并未被烧毁。海关门外的封存档案箱里保留着同日货单，取回四页副本，核对假船籍。",
		"四份货单使用了同一个船籍号，却写着不同船名。这些副本足够让裁定厅冻结货主的账户。", 1.4)
	q["q_e9"] = _q("封存货箱", 15, "archivist", "e_port_agent", ["q_e1"],
		[_visit("poi_ember_transfer", "东郊转运点"), _gather("q_e_cargo_seal", 4, "ember_cargo")],
		"沿东门外的货运支路去东郊转运点。港务外勤诺拉在那里等你。把四只货箱上的封存标签带给她，查清燃料将被送到哪里。",
		"标签上有旧站场的编号。走私客借废弃货运线绕过了城里的检查。先截住这批货的主管。", 1.4, true,
		{"choice": ["waist:cloth:int_spi", "waist:leather:agi_sta", "waist:mail:str_sta"]})
	q["q_e6"] = _q("城墙外的余波", 15, "e_port_agent", "e_port_agent", ["q_e9"],
		[_kill("e_dock_runner", 6), _kill("e_dock_gunner", 6)],
		"转运点西侧的走私客和东北侧的护货火枪手正准备撤走。清除各六人，为港务巡查员留出安全的取证通道。",
		"巡查员现在能进入货栈了。这一带会继续有残党活动，但他们已经失去了这批货。", 1.4)
	q["q_e10"] = _q("潮汐后的调令", 16, "e_port_agent", "e_port_agent", ["q_e9"],
		[_drop("q_e_tide_orders", 6, ["e_dock_runner"])],
		"每个转运班次都有一张夜航调令。取回六张，比较他们约定的潮汐时间。走私客就在转运点西侧，调令会完整保留。",
		"交货时间与铁路调度时间一一对应。运河只是掩护，真正的线路在旧站场。", 1.4,
		{"items": [["potion_heal3", 3], ["potion_mana3", 3]]})
	q["q_e2"] = _q("运河封锁", 16, "e_port_agent", "e_port_agent", ["q_e9"],
		[_drop("q_seal_fragment", 1, ["e_dock_master"])],
		"货栈主管柯林·赤帆躲在转运点东端。他手里的港务印章能放行整条运输线。击败他，把印章碎片带回来，港务局才能作废那些通行令。",
		"印章已经被登记作废，运河闸口不会再为这些货物放行。去中央车站找格伦，查清旧站场下一批货的去向。", 1.9, true,
		{"choice": ["one:sword:str_sta", "one:dagger:agi_sta", "two:staff:int_spi", "ranged:gun:agi_sta", "two:mace2:str_sta", "off:offhand:int"]})
	# 铁路追踪（16–17）：霍华德位于站场边，四条支线可同趟完成。
	q["q_e11"] = _q("被改写的时刻表", 16, "station_master", "howard", ["q_e2"],
		[_visit("poi_ember_rail", "站场北侧的余烬调度区"), _gather("q_e_dispatch", 3, "ember_dispatch")],
		"中央车站的时刻表没有发出这批货的调度命令。去旧铁路站场北侧，收集三份被篡改的调度单，交给站场边的巡线员霍华德。",
		"有人另架了一套调度器。我的旧信号灯没有坏，是这套机器在不断覆盖它。我们要先拆掉它的供能和继电器。", 1.4, true)
	q["q_e12"] = _q("护轨傀儡", 16, "howard", "howard", ["q_e11"],
		[_kill("e_rail_guard", 8)],
		"余烬调度区西侧的护轨傀儡被写入了错误命令。摧毁八台，让巡线员能回到轨道旁作业。",
		"轨道边可以施工了。它们的控制板都是新装的，这次故障是人为破坏。", 1.5)
	q["q_e7"] = _q("灯塔的燃料", 16, "howard", "howard", ["q_e11"],
		[_drop("q_lighthouse_cell", 6, ["e_rail_guard"])],
		"老约翰的灯塔需要备用燃料。护轨傀儡使用的正是灯塔同规格的燃料芯，带回六个完好的芯子。我会随维修车送到南港。",
		"燃料芯已经装进送往南港的箱子。货运线路恢复后，灯塔会有稳定的补给。", 1.4)
	q["q_e13"] = _q("信号线上有蜘蛛", 17, "howard", "howard", ["q_e11"],
		[_kill("e_signal_spider", 7)],
		"调度区南侧的信号蜘蛛在啃咬线路。清除七只，免得新装好的继电器马上又被破坏。留意它们的远程电弧。",
		"线路里终于没有杂音了。剩下的工作是换装零件、拔掉那套非法调度器。", 1.5)
	q["q_e14"] = _q("换下继电器", 17, "howard", "howard", ["q_e11"],
		[_gather("q_e_signal_part", 4, "ember_signal")],
		"调度区轨道旁有四种损坏的信号继电器。取回四个组件，我要对比它们的接线，再把信号改回原来的频道。先清理附近的蜘蛛，战斗中无法拆件。",
		"接线的改动都出自同一只手。赫兹·断轨是这套非法调度器的负责人，他就躲在调度区东侧。", 1.5, true,
		{"choice": ["feet:cloth:int_spi", "feet:leather:agi_sta", "feet:mail:str_sta"]})
	q["q_e15"] = _q("过载的稳压器", 17, "howard", "howard", ["q_e11"],
		[_drop("q_e_regulator", 6, ["e_rail_saboteur"])],
		"调度区北侧的破轨技师都携带一只稳压器。他们靠它维持非法信号，把六只收回来，让他们无法继续覆盖正常线路。",
		"稳压器上带着海盐，最初是在海岸上的工坊组装的。铁路破坏与夜航走私确实是同一伙人。", 1.5,
		{"choice": ["wrist:cloth:int_spi", "wrist:leather:agi_sta", "wrist:mail:str_sta"]})
	q["q_e16"] = _q("断轨者的路线图", 17, "howard", "howard", ["q_e14"],
		[_drop("q_e_route_map", 1, ["e_rail_foreman"])],
		"赫兹·断轨控制着调度区东端。击败他，取回秘密运送路线图。只要知道货物最终在哪儿装船，我们就能截住幕后的人。",
		"路线图终点在礁石海滩东侧，那里有一道绕开灯塔的夜航航道。带消息去找老约翰，他会让海岸巡视员接应你。", 2.0, true,
		{"choice": ["head:cloth:int_spi", "head:leather:agi_sta", "head:mail:str_sta"], "q_reward": 3})
	q["q_e17"] = _q("从铁轨到海岸", 17, "howard", "lighthouse_keeper", ["q_e16"], [],
		"我会把铁路的证据交给格伦。你去晴岚港南端的港口灯塔，把夜航路线的消息告诉老约翰。",
		"塞林正在礁石海滩东侧的海岸前哨巡查。我会通知港务局暂缓船只出港，你去支援他。", 0.5, true,
		{"obj_text": "前往晴岚港南端的港口灯塔，与老约翰交谈。"})
	# 海岸行动（18–19）：塞林在野外接应，避免每个目标都往城里交付。
	q["q_e3"] = _q("灯塔断讯", 18, "lighthouse_keeper", "e_coast_agent", ["q_e17"],
		[_visit("poi_lighthouse", "港口灯塔"), _visit("poi_ember_coast", "礁石海滩东侧的海岸前哨")],
		"昨夜灯塔的航标信号被短暂覆盖。检查这里的灯塔，再去礁石海滩东侧的海岸前哨找巡视员塞林。他已经找到夜航船队的接应点。",
		"欢迎来到海岸前哨。走私队把真正的航标装在山麓上，故意把商船引向暗礁。我们从补给和护航设备两头下手。", 0.7, true)
	q["q_e18"] = _q("藏在岸上的补给", 18, "e_coast_agent", "e_coast_agent", ["q_e3"],
		[_gather("q_e_coast_cache", 4, "ember_cache")],
		"前哨东南侧的潮汐接应点藏着四箱密封补给。收回这些箱子，既能断掉走私队的补给，也能确认他们使用的航标频率。",
		"箱子里有一张浑浊以太透镜的保养单。岸上的航标使用了与圣堂残响相近的以太，但它是新造的设备。", 1.4, true)
	q["q_e19"] = _q("搁浅船员的药箱", 18, "e_coast_agent", "e_coast_agent", ["q_e3"],
		[_gather("q_e_rescue_kit", 6, "ember_rescue")],
		"被错误航标引来的商船丢下了几箱急救用品。接应点西侧沿岸散落着六只急救包。把它们收回来，前哨的船员正在等药。",
		"急救用品已经分给船员。伤员能由港务巡逻船送回城，我们也能把精力放到走私队身上了。", 1.4,
		{"items": [["potion_heal3", 4]]})
	q["q_e20"] = _q("切断海岸联络", 18, "e_coast_agent", "e_coast_agent", ["q_e3"],
		[_kill("e_coast_runner", 8)],
		"接应点南侧的夜航联络员在给各处岗哨传递口令。清除八人，防止他们把我们的行动传到山麓。",
		"接应点的联络中断了。山麓上的指挥官暂时还不知道我们掌握了路线图。", 1.5)
	q["q_e21"] = _q("拖船傀儡", 18, "e_coast_agent", "e_coast_agent", ["q_e3"],
		[_kill("e_tide_golem", 8)],
		"接应点北侧的潮汐拖船傀儡会袭击靠近的船员。拆掉八台，把这一段岸线清出来。小心它们的践踏。",
		"巡逻船终于能靠岸。这些傀儡以后会被船厂拆解，能用的零件留给道格拉斯。", 1.5,
		{"choice": ["hands:cloth:int_spi", "hands:leather:agi_sta", "hands:mail:str_sta"]})
	q["q_e22"] = _q("航标的骨架", 19, "e_coast_agent", "e_coast_agent", ["q_e18"],
		[_gather("q_e_lens_frame", 4, "ember_frame")],
		"接应点东侧的备用航标架上还留着四只镜架。收回镜架，老约翰就能用它们重新校准灯塔的备用航标。",
		"镜架的尺寸与晴岚港灯塔完全相同。走私队在仿制正规航标，好让船长分辨不出真假。", 1.4)
	q["q_e4"] = _q("浑浊的以太", 19, "e_coast_agent", "e_coast_agent", ["q_e18"],
		[_kill("e_lens_keeper", 6), _drop("q_aether_lens", 3, ["e_lens_keeper"])],
		"航标守镜师守着接应点东北侧的透镜库。清除六人，收回三块浑浊以太透镜。我带来了研究所的分析仪，能在前哨检查它们。",
		"透镜被调到了一种危险的共振频率。夜航领航者塞薇拉·雾灯掌握启动钥匙，先把钥匙夺下来。", 1.7, true,
		{"choice": ["trinket:misc:int", "trinket:misc:agi", "trinket:misc:str"]})
	q["q_e23"] = _q("雾灯领航者", 19, "e_coast_agent", "e_coast_agent", ["q_e4"],
		[_drop("q_e_launch_key", 1, ["e_coast_master"])],
		"塞薇拉·雾灯守在接应点东端。击败她，夺取夜航启动钥匙。她擅长风系法术，接近时留意施法预兆。",
		"钥匙到手了，但她只负责领航。山麓上的雷纳德·烬誓正在准备最后一批余烬装药，我们还要拔掉他的指挥营地。", 2.0, true,
		{"choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta"], "q_reward": 3})
	# 余烬终局（19–20）：新反派与新据点，继承前章结果。
	q["q_e24"] = _q("解读夜航密文", 19, "e_coast_agent", "e_coast_agent", ["q_e23"],
		[_visit("poi_ember_command", "山麓余烬指挥营地"), _gather("q_e_cipher", 3, "ember_cipher")],
		"指挥营地位于接应点北面的山麓。先收回营地西侧信号台上的三份航标密文。没有它们，就无法安全地停下余烬核心。",
		"密文记载着停机顺序：先撤走装药，再切断核心的护卫网。雷纳德就在营地东端。", 1.1, true)
	q["q_e25"] = _q("指挥营地的盾墙", 19, "e_coast_agent", "e_coast_agent", ["q_e23"],
		[_kill("e_ember_guard", 8)],
		"山麓营地南侧有一队余烬护卫。清除八名护卫，为后续接收营地的港务巡查员打开通道。注意他们的顺劈，避免把几人一起引来。",
		"护卫阵线已经被打散。港务局接收这座营地时会轻松很多。", 1.4)
	q["q_e26"] = _q("共振施术者", 20, "e_coast_agent", "e_coast_agent", ["q_e23"],
		[_kill("e_ember_mage", 6)],
		"营地北侧的余烬共振师在为核心提供法力。清除六人，阻止他们再次给已停机的设备供能。避开他们的暗影法术。",
		"核心的备用供能已经切断。雷纳德只剩随身的最后一颗核心了。", 1.4,
		{"items": [["potion_mana3", 4]]})
	q["q_e27"] = _q("撤下余烬装药", 19, "e_coast_agent", "e_coast_agent", ["q_e23"],
		[_gather("q_e_charge", 4, "ember_charge")],
		"指挥营地西南侧装着四箱准备出港的余烬装药。收回这些箱子，阻止这批危险燃料流入商船。必须先脱离战斗才能搬运。",
		"装药已经撤出。现在即使雷纳德启动信号，也没有货物能按计划送上船。", 1.2, true)
	q["q_e28"] = _q("安全停机阀", 19, "e_coast_agent", "e_coast_agent", ["q_e23"],
		[_gather("q_e_shutdown", 3, "ember_shutdown")],
		"营地西北侧的维修箱里有三只停机阀组件。把它们带回来，船厂就能安全回收那些失控设备，而不用把整座营地炸掉。",
		"停机阀留给船厂的拆解队。这些机器还能为港口服务，只是再也不能落到灰巾帮手里。", 1.2)
	q["q_e29"] = _q("最后的护卫网", 20, "e_coast_agent", "e_coast_agent", ["q_e24", "q_e27"],
		[_kill("e_ember_guard", 6), _kill("e_ember_mage", 4)],
		"密文已解开，装药也已搬走。最后清除六名余烬护卫与四名共振师，让我们能按停机顺序接近雷纳德。可与前哨的清剿委托同时推进。",
		"护卫网已被切开。去营地东端夺回余烬核心，我在前哨等你的消息。", 1.6, true,
		{"choice": ["neck:misc:int_spi", "neck:misc:agi_sta", "neck:misc:str_sta"]})
	q["q_e5"] = _q("余烬终局", 20, "e_coast_agent", "e_coast_agent", ["q_e29"],
		[_drop("q_ember_core", 1, ["e_ember_commander"])],
		"雷纳德·烬誓藏在山麓指挥营地东端。他继承了灰巾帮的运输网，却没有复活守钟人的力量。击败这位夜航指挥官，夺取他携带的余烬核心。小心他的炸弹与近身顺劈；这是一场单人首领战。",
		"核心已经封存，夜航运输网的证据也齐全了。守钟人留下的阴谋到这里彻底断了后路。回晴岚港向市长报告吧。", 2.0, true,
		{"choice": ["one:sword:str_sta", "one:dagger:agi_sta", "two:staff:int_spi", "ranged:gun:agi_sta", "two:mace2:str_sta", "off:offhand:int"], "q_reward": 3})
	q["q_e30"] = _q("海风再度启航", 20, "e_coast_agent", "mayor", ["q_e5"], [],
		"余烬核心和运输网证据会由港务局运回城。你已完成海岸行动，回市政大厅向阿德里安市长报告。",
		"从档案里的一个疑点，到铁路与海岸的整条运输线，你替晴岚港守住了航路。这头铁鬃战熊是港务巡查队的赠礼。远洋航线仍在筹备；当新的航线开通时，晴岚港会再次需要你。", 0.5, true,
		{"obj_text": "返回晴岚港市政大厅，向阿德里安市长报告。", "items": [["mount_bear_item", 1]], "money": 12000})
	return q

static func _q(title: String, lvl: int, giver: String, turnin: String, prev: Array, obj: Array,
		text: String, complete: String, weight: float, main: Variant = false, extra: Dictionary = {}) -> Dictionary:
	# Older quest rows omit the `main` flag when supplying the optional reward
	# dictionary as the next positional argument. Accept that data shape while
	# keeping the normalized quest record strictly boolean.
	if main is Dictionary and extra.is_empty():
		extra = main
		main = false
	var main_flag: bool = bool(main)
	var q := {"name": title, "lvl": lvl, "min": maxi(15, lvl - 1), "giver": giver, "turnin": turnin,
		"prev": prev, "obj": obj, "text": text, "obj_text": _summary(obj), "complete": complete,
		"progress": "按委托确认目标后再回来，前哨会等你的消息。", "w": weight, "main": main_flag}
	q.merge(extra, true)
	return q

static func _summary(obj: Array) -> String:
	var lines := PackedStringArray()
	for o in obj:
		if o.get("text", "") != "":
			lines.append(o["text"])
		elif o.get("type", "") == "kill":
			lines.append("击败目标：%d/%d" % [0, o.get("n", 1)])
		elif o.get("type", "") == "collect":
			lines.append("收集任务物品：%d/%d" % [0, o.get("n", 1)])
		else:
			lines.append("完成当地的外勤目标。")
	return "\n".join(lines)

static func _visit(poi: String, text: String) -> Dictionary:
	return {"type": "explore", "poi": poi, "text": "检查" + text}

static func _kill(mob: String, count: int) -> Dictionary:
	return {"type": "kill", "mob": [mob], "n": count}

static func _drop(item: String, count: int, mobs: Array) -> Dictionary:
	return {"type": "collect", "item": item, "n": count, "mobs": mobs, "chance": 1.0}

static func _gather(item: String, count: int, node: String) -> Dictionary:
	return {"type": "collect", "item": item, "n": count, "node": node}
