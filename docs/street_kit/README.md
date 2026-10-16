# 晴岚港沿街楼构件库 street_kit v1

把「沿街白模楼」拆成 Blender 构件，再按规划地块在游戏里模块化装配。风格：洛奇M 重制版 / 荒野之息式手绘卡通——
木筋灰泥、砖石底层、陡坡瓦顶、石窗套、窗板、铁艺阳台、遮阳篷。**只做几何轮廓**（每件约 12–760 三角形），质感由手绘 RGB 乘数贴图
（`assets/textures/building/pt_*.png`，见 `tools/texgen/paint_building_v2.py`）在 `building.gdshader` 里出，所以构件很省面。
复杂建筑（功能建筑 / 地标 `city_lm`、可进入的店铺、街角切角楼）**保持原样，未重做**。

## 构件（`assets/models/street_kit/sk_*.glb`，缩略图 `docs/street_kit/`）

| 类 | 构件 | 说明 |
|---|---|---|
| 底层 | `sk_gf_shop` `sk_gf_arch` `sk_gf_door` `sk_gf_solid` | 商铺（橱窗 + 货架 + 招牌 + 遮阳篷 + 壁柱）/ 拱窗 / 拱门（木门扇 + 铁箍 + 石阶）/ 实墙 |
| 标准层 | `sk_uf_half` `sk_uf_plain` `sk_uf_brick` `sk_uf_balc` `sk_uf_blank` `sk_uf_side` | 木筋灰泥 / 灰泥石窗套 / 红砖过梁 / 落地窗铁艺阳台 / 无窗 / 侧墙小窗 |
| 线脚 | `sk_band` `sk_eave` | 层间腰线、檐口牛腿 |
| 屋顶 | `sk_roof_gable` `sk_gable_end` `sk_dormer` `sk_chimney` | 双坡瓦面开间、木筋山墙、老虎窗、烟囱 |
| 屋顶 | `sk_mansard_bay/_L/_R` `sk_mansard_dormer` `sk_roof_flat` | 芒萨尔屋面（左右端 45° 斜接）、老虎窗、顶面锌板 |

模数同 city_kit：开间 4.4m、底层 5.6m、标准层 4.4m、墙厚 0.3m。沿 +X 展开、外立面朝 +Z、原点在左下角墙中心线（屋面 / 山墙原点在墙顶）。
装配时开间按地块宽度整数分开间后 X 方向缩放 ≤ ±12%。

## 材质约定（构件里的材质名 → 游戏）

- `S|槽|类型|贴图|米`：**实例着色槽**（0 墙 / 1 屋顶 / 2 石材线脚 / 3 点缀：窗板、门、遮阳篷）。每栋楼各用调色板里的一色（`kitlots.js` 的 `PALETTE`）。
- `K|类型|RRGGBB|贴图|米`：固定颜色（木筋、铁艺、招牌、货品）→ `U.kit_mat`。
- `N|RRGGBB`：窗格 / 店内后墙 → `CityMat.night_window`（白天映天空的蓝灰，夜间发暖光，随昼夜系数）。

## 管线

```
tools/blender/street_kit/{street_kit.py,build.py}   → assets/models/street_kit/*.glb + manifest.json + docs/street_kit/*.png
tools/city_plan_v6/src/kitlots.js (buildKitLots)    → assets/models/street_kit/kit_lots.{bin,json}  （export_game.mjs 调用）
src/world/city_kit_lots.gd (CityKitLots)            → 运行时 MultiMesh 合批（按 120m 分块，WorldStream 流入流出）
tools/gen_city_v7.gd::_kit_lots                     → 在城市区域里放一个 CityKitLots 节点
```

- 可替换地块 = 四边形且不可进入（`kitEligible`）：约 299 栋 / 17142 个构件实例。可进入店铺、街角切角楼仍是原白模。
- 近处（≤170m）画构件，远处（≥160m）画 chunk 里的白模代理（节点 `lotfar`，缩 0.45m，由 `CityMat.apply` 设可见距离）。碰撞仍是原地块盒，未改。
- 各区风格配方在 `kitlots.js` 的 `RECIPE`（木筋 / 灰泥 / 红砖 / 芒萨尔 / 双坡 × 屋顶瓦色）。

构建命令：

```bash
"E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/street_kit/build.py -- all
node tools/city_plan_v6/export_game.mjs      # 重导 kit_lots + chunk
```

之后 `regenerate_zones`。参数可以是 `all` / `pieces` / `demos` / 逗号分隔构件 id。

## 街角楼（2026-10-09 追加）

6 / 7 边形切角楼与直角街角楼按**逐边**装配（`kitlots.js` 街角路径）：

- 临街边判定 `frontInfo`：与街区某条街道边平行且相距≈人行道宽；连续三条临街边的**中间一条是切角斜边**（法式 pan coupé）：底层中间一开间是拱门（正门），二层是落地窗铁艺阳台。
- 其余边是侧 / 背墙（实墙 + 小窗）。每条边自己分整数开间，X 缩放 ≤ ±12%。
- 屋面沿每条边铺**斜接裙边**：`sk_mansard_{L,R}{90,135}`（转角室内夹角 90° / 135°，Blender 里按角平分面切出，`miter()`）；
  山墙风格区（旧城 / 工匠 / 港口 / 海岬 / 军营 / 公园）的街角楼用四坡屋面 `sk_hip_*`（陶瓦、内收 3m）。近直线（≥160°）的拐点不斜接。
- 中间封顶用 `kit_caps.bin`（三角形）：芒萨尔 = 锌板平顶；四坡 = 向中心升起的锥顶（陶瓦，取该栋屋面色）+ 烟囱。`CityKitLots._build_caps` 生成。

可替换地块现为 584 栋 / 36503 个构件实例（规则四边形 + 街角楼），仅可进入店铺仍是原白模；构件可见距离 140m，白模代理 128m 起。
