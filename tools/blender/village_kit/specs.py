# 金穗镇各栋房屋的规格（外形 / 风格 / 内饰预设）。坐标：Blender X 右、Y 向后，门在 -Y 面（游戏里朝 +Z）。
# 风格：mm = 洛奇M 重制版（红瓦 + 暖灰泥 + 石窗框）；wow = 艾尔文式（白墙深木筋 + 蓝瓦）。
SPECS = {
    # ---- 功能建筑
    "tavern": dict(id="tavern", style="wow", shape=("L", 15.0, 12.5, 8.6, 6.4, "r"), H=6.4, rows=2, row0=3.4, Hc=5.9, bay=3.4, porch=True, dormers=[-3.4, 3.4], sign=True, oriel=[0],
                   chim=[(-5.5, -5.0), (5.4, 2.0)], interior="tavern", seed=11, ivy=0.9),
    "smithy": dict(id="smithy", style="wow", pal=dict(plaster="d8c8a4", timber="6e4a30", stone="a39d86", roof=("shake", "8c6a4a"), sh="7a5236"), shape=("rect", 11.0, 8.6), H=3.7, rows=1, porch=False,
                   chim=[], interior="smithy", smith=True, sign="smith", seed=13, bushes=0.2, ivy=0.25, beds=0.0, door_bay=2, bay=2.8,
                   solid=[(1, 1), (3, 1), (3, 2), (2, 0), (2, 1), (2, 2), (2, 3)]),    "store": dict(id="store", style="wow2", shape=("rect", 9.0, 7.6), H=3.6, rows=1, porch=True, dormers=[-1.8, 1.8], chim=[(2.6, 1.0)], sign=True, oriel=[0], interior="store", seed=17),
    "tailor": dict(id="tailor", style="wow", pal=dict(plaster="f1e4d4", roof=("slate", "68748a")), shape=("L", 9.4, 8.4, 5.2, 4.0, "l"), H=3.6, rows=1, porch=True, dormers=[0.0], chim=[(2.4, -2.0)],
                   interior="tailor", sign=True, seed=19),
    "guard": dict(id="guard", style="wow", pal=dict(plaster="aaa493", stone="9a9480"), shape=("rect", 7.8, 7.8), H=6.6, rows=2, row0=3.4, Hc=3.1, roof="pyramid", porch=False,
                  interior="guard", seed=23, small_win=True, bushes=0.3, ivy=0.5, chim=[], sign=True),
    "trainer": dict(id="trainer", style="mm2", shape=("rect", 12.4, 8.6), H=3.7, rows=1, porch=True, dormers=[-3.2, 3.2], chim=[(-4.8, 1.0), (4.8, 1.0)], interior="trainer", sign=True, oriel=[0], seed=29),
    "stable": dict(id="stable", style="wow2", pal=dict(roof=("thatch", "c9a25a"), plaster="d9c6a0"), shape=("rect", 13.0, 8.8), H=3.9, rows=1, porch=False, chim=[(4.0, 1.0)],
                   interior="stable", sign=True, barn=(1, 0), seed=31, bay=3.6, door_bay=1, bushes=0.25, ivy=0.3),
    # ---- 2026-10-10 茅草屋（参考图：厚圆润茅草屋顶 + 眉毛窗隆起 + 半木筋山墙 + 石基座 + 山墙石烟囱）
    "home_thatch": dict(id="home_thatch", style="wow2", pal=dict(plaster="eddcb6", timber="7a5236", stone="a8a28c", roof=("thatch", "d4b66c"), sh="8a5a3a"), shape=("rect", 8.6, 6.8), H=3.6, rows=1,
                        porch=False, eyebrow=[-3.4], chim=[(3.4, 0.4)], interior="home", fence=True, seed=41, bushes=0.9, beds=0.8),
    "farmhouse": dict(id="farmhouse", style="wow2", pal=dict(plaster="e6d3ab", timber="6e4a30", stone="a39d86", roof=("thatch", "cdae62"), sh="7a5236"), shape=("rect", 10.4, 7.8), H=3.6, rows=1,
                      porch=True, eyebrow=[-3.6, 3.6], chim=[(-3.8, 0.6), (3.6, 0.6)], interior="home", fence=True, seed=43, bushes=0.7, beds=0.5),
    "barn": dict(id="barn", style="wow2", walls="planks", pal=dict(plaster="b5543c", timber="4e3322", stone="8f8a78", roof=("thatch", "c4a45a"), sh="6a4a30"), shape=("rect", 12.6, 9.4), H=4.4, rows=1,
                 porch=False, chim=[], interior="stable", sign=False, barn_door=True, seed=47, bay=4.2, door_bay=1, bushes=0.15, beds=0.0),
    # ---- 民居 ×7
    "home_l": dict(id="home_l", style="mm", shape=("L", 11.0, 9.5, 5.2, 4.6, "r"), H=3.7, rows=1, porch=True, dormers=[-2.8, 1.0], chim=[(-3.8, -4.4), (4.4, 2.0)], interior="home", fence=True, seed=3),
    "home_cot": dict(id="home_cot", style="wow", shape=("rect", 8.6, 6.6), H=3.6, rows=1, porch=True, dormers=[0.0], chim=[(2.6, 0.5)], interior="home", fence=True, seed=5),
    "home_long": dict(id="home_long", style="mm2", shape=("rect", 12.2, 6.4), H=3.6, rows=1, porch=False, dormers=[-3.0, 3.0], chim=[(-4.6, 0.5), (4.6, 0.5)], interior="home", fence=True, seed=7, door_bay=2),
    "home_loft": dict(id="home_loft", style="wow2", shape=("rect", 7.8, 7.2), H=6.2, rows=2, row0=3.3, Hc=3.1, porch=True, dormers=[0.0], chim=[(2.4, 0.6)], interior="home", seed=9, bay=2.6),
    "home_wing": dict(id="home_wing", style="wow", pal=dict(plaster="f0e6d0", roof=("slate", "68748a")), shape=("L", 10.4, 9.0, 4.8, 4.2, "l"), H=3.6, rows=1, porch=True, dormers=[2.2], chim=[(3.6, -2.5)],
                      interior="home", fence=True, seed=15),
    "home_broad": dict(id="home_broad", style="mm", pal=dict(plaster="e0a982", roof=("tile", "b04a38")), shape=("rect", 10.2, 8.2), H=3.6, rows=1, porch=True, dormers=[-2.4, 2.4], chim=[(0.0, 1.0)],
                       interior="home", fence=True, oriel=[0], seed=21),
    "home_mini": dict(id="home_mini", style="wow2", shape=("rect", 7.4, 5.8), H=3.4, rows=1, porch=False, dormers=[], chim=[(2.0, 0.4)], interior="home", seed=25, door_bay=1, bay=2.8),
}


# ---------------------------------------------------------------- 2026-10-10 真实比例（1 单位 = 1 米）：玩家 1.7m，门洞 2.3m，室内净高 3.5–4m
# 占地在原设计上放大 FOOT 倍（室内要宽敞），开间 / 烟囱 / 老虎窗位置同步放大；层高按下表覆盖（单层 Hc = H - 0.32）。
FOOT = 1.2
HEIGHTS = {  # id: (H, row0, Hc)  2026-10-10 门高 3.0m（SCALE=3/2.3）、每层净高 5m：5/SCALE = 3.83 为一层的基础高度；单层 Hc = H - 0.32 → 室内净高 ≈ 5m
    "tavern": (7.96, 3.83, 7.66), "smithy": (4.15, None, None), "store": (4.15, None, None), "tailor": (4.15, None, None), "guard": (7.96, 3.83, 3.6),
    "trainer": (4.15, None, None), "stable": (4.4, None, None), "home_l": (4.15, None, None), "home_cot": (4.15, None, None), "home_long": (4.15, None, None),
    "home_loft": (7.96, 3.83, 3.6), "home_wing": (4.15, None, None), "home_broad": (4.15, None, None), "home_mini": (4.15, None, None), "home_thatch": (4.15, None, None), "farmhouse": (4.15, None, None), "barn": (5.4, None, None),
}
for _id, _sp in SPECS.items():
    _sp["shape"] = tuple(round(v * FOOT, 2) if isinstance(v, (int, float)) else v for v in _sp["shape"])
    if "chim" in _sp:
        _sp["chim"] = [(round(c[0] * FOOT, 2), round(c[1] * FOOT, 2)) for c in _sp["chim"]]
    if "dormers" in _sp:
        _sp["dormers"] = [round(x * FOOT, 2) for x in _sp["dormers"]]
    _sp["bay"] = round(_sp.get("bay", 3.0) * FOOT, 2)
    _h, _r0, _hc = HEIGHTS[_id]
    _sp["H"] = _h
    if _r0 is not None:
        _sp["row0"], _sp["Hc"] = _r0, _hc



