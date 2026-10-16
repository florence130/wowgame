# 晴岚港 v5 重建兼容清单

本清单为 2026-10-06 重建前的只读取证。此任务仅新增文档和审计脚本，没有修改生成器、运行时、测试或用户存档。v4 位置不是设计限制；下列稳定 ID、外部函数和保存数据是需要保留或明确迁移的契约。

## 1. 外部生成契约

`tools/gen_tidewind.gd` 对 `GenSolenne` 只有下列直接调用：

| 签名 | 调用位置 | 必须维持的语义 |
|---|---|---|
| `static func in_city(x: float, z: float) -> bool` | 35 | 基础地形生成阶段即调用，不能依赖 `build()` 已执行；返回城市地形覆盖区（可以包含海面），不能误当作可步行陆地判断。 |
| `static func city_h(n: FastNoiseLite, x: float, z: float) -> float` | 36 | 接收生成器同一噪声对象，返回区域局部坐标处的绝对地面高度；需与水位 8m、城外边缘连续。 |
| `static func coast_x(z: float) -> float` | 41 | 西海岸横坐标；调用输入先限定到 z=200..1040；城外高度和北部山脚亦依赖这个结果。 |
| `static func south_coast_z(x: float) -> float` | 44 | 南海岸纵坐标；城外调用条件 x<520，结果参与城外海岸混合。 |
| `static func build(b: ZoneBuilder) -> void` | 22 | 向同一 builder 添加城市；不能重新创建区域、覆盖城外 groups，或自行提前保存。城市完成后仍有沙滩、农庄、营地、站场、鸣风崖、圣堂和植被生成。 |

额外边界：

- `zone_id="tidewind"`；输出仍是 `data/terrain/tidewind.res`、`scenes/zones/tidewind_highlands.tscn`。当前地形原点 `(-1040,-160)`，分辨率800、格长2.5，即2000m正方形。
- `WorldLayout.offset("tidewind")=(-960,0,160)`。生成器和保存场景用区域局部坐标；存档、演员实例、运行时寻路用世界坐标。不要把两者混用。
- 城外东门公路末段是 `(430,420)→(320,442)→(288,450)`，见 `gen_tidewind.gd:93` 附近。重定位东门时接通此边界，不移动整个野外。
- 既有 `GenSolenne.build()` 添加 `b.block_fns` 以阻止后续野外植被进城。重建仍须提供与新城市范围一致的阻挡；不能只有房子占地、遗漏街道/广场的树草控制。
- `GenTidewind` 在最后仍会 `WorldLayout.stitch()`，仅接缝14m。城内生成不应改动 x≈960的区域接缝。
- 重复生成时清空静态布局缓存、道路、占地与住宅数组；地形查询必须能够在 build 前执行。修改 plan 文件后不要依赖上次进程里的 `_plan/_cache/_poly`。

## 2. 需要保留的城市标识

基线范围包括城外下城区、篱田和河源，因为它们也由 `GenSolenne` 生成。NPC共享ID（如守卫/难民）还会在野外出现，因此审计JSON保留整张区域所有节点，并区分“城市契约ID”与严格地理归属。

### NPC：71个唯一ID

```text
admiral airship_captain ambassador archbishop archivist armor_shop
artisan_master astronomer auctioneer banker banker2 bath_attendant
black_marketeer butler canal_keeper canal_officer citizen clergy
clock_keeper cook_master customs_officer dock_worker doctor expo_guide
ferry_clerk finance_minister florist gate_captain governor guard_city
guard_city_f guild_master guild_reg harbor_master inn_keeper2 item_shop
jeweler judge lecturer librarian lighthouse_keeper mage_master mayor
merchant_captain merchant_head nurse opera_manager outer_farmer park_keeper
portal_mage potion_shop rare_shop refugee researcher sailor scholar
scholar_master shipwright smith_master stable_city station_master
t_gunner_3 t_mage_3 t_rogue_3 t_warrior_3 tavern_keeper tax_officer
transmog warehouse_keeper weapon_shop welfare_officer
```

稳定 npc_id 比 Marker3D 的显示节点名重要。NPC移动到室内时仍用原ID；同一具名服务NPC不要无意生成两个（银行本来有 banker/banker2 两个不同ID）。普通市民、守卫、水手允许同ID多实例。`city_inn` 在数据库存在，但当前城内场景未放置，不属于71项基线。

| 功能契约 | NPC ID / 相关数据 |
|---|---|
| 银行、拍卖、幻化 | banker / banker2 的 bank；auctioneer 的 auction；transmog 的 transmog |
| 商店 | item_shop、weapon_shop、armor_shop、jeweler、florist、potion_shop、rare_shop、black_marketeer 的 vendor |
| 专业 | smith_master=smith；artisan_master=artisan；cook_master=cook，保留 prof/vendor/配方表 |
| 职业 | t_warrior_3、t_rogue_3、t_gunner_3、t_mage_3；mage_master同为法师训练师；archbishop是牧师训练师 |
| 旅店 | inn_keeper2、tavern_keeper 的 innkeeper/food，炉石绑定需安全位置 |
| 骑术 | stable_city 的 riding/vendor |
| 列车 | station_master 的 `train="goldenear"` |
| 飞行 | airship_captain 的 `flight="fp_solenne"` |
| 传送 | portal_mage 的 portal；目的地仍为晨钟修道院、金穗镇、东门哨站、风语旧圣堂入口 |
| 对话服务 | bath_attendant=bath；doctor=heal；welfare_officer=welfare；guild_reg=guild；opera_manager=opera；scholar_master=research；clock_keeper=time；ferry_clerk=routes |

服务定义来自 `src/data/data_world.gd:102–241`，UI分派见 `src/ui/win_npc.gd:115–164、527–598`。大臣等只有闲谈也需在整体重建中保留其身份，或显式提供数据迁移/等价替代，不能因新布局遗漏。

### POI：57个ID

```text
poi_spring poi_plaza poi_clock poi_portal_hall poi_bath poi_welfare
poi_tax poi_court poi_archive poi_shop_0 poi_shop_1 poi_shop_2 poi_shop_3
poi_shop_4 poi_shop_5 poi_shop_6 poi_market poi_exchange poi_merchant_hq
poi_cook poi_mage_guild poi_library poi_scholar poi_institute poi_academy
poi_north_slope poi_airport poi_residency poi_governor poi_canal_bureau
poi_customs poi_north_port poi_south_port poi_warehouse poi_tavern
poi_blackmarket poi_harbor poi_lighthouse poi_shipyard poi_drain
poi_cathedral poi_clergy poi_hospital poi_station poi_guild poi_smith
poi_artisan poi_city_inn poi_opera poi_park poi_citygate poi_citygate_n
poi_citygate_se poi_outer poi_farmland poi_solenne poi_canal
```

`poi_shop_0..6`依次为幻化、珍品、药剂、道具、武器、防具、珠宝。可更名 title、移动位置、改变触发半径，但ID应保留。特别是 `poi_market` 是当前“博览集市馆”实际标识，不要根据建筑新名创建另一个ID而漏掉旧任务。

`Zone.populate()`按 priority 降序、同priority按半径升序排序；`subzone_at()`找到第一个覆盖玩家的POI就返回。因此不能让高优先级大范围POI覆盖全部局部探索点，使其永不触发。`rest_area`、`explore_xp`默认值也应显式对照基线。参考 `zone.gd:44、96–118`。

### 出生点：4个城市ID

| ID | 当前位置（区域坐标；仅基线） | 用途 |
|---|---|---|
| fp_solenne | (-876,地面,274) | 飞空艇到达；飞行发现状态以同ID保存 |
| st_solenne | (36,地面,653) | 晴岚港列车到达 |
| gy_gate | (318,地面,480) | 城门外墓地/安全回退，未解锁城市也应可落地 |
| gy_cathedral | (-767.774,地面,903.270) | 城内墓地 |

必须保留 `SpawnPoints` 父节点名，`Zone._collect()`仅把父名为SpawnPoints的Marker3D登记为出生点（`zone.gd:36–37`）。可以新增通勤锚点，不以重命名原点实现。所有到达位置需满足角色胶囊不与门、台阶、栏杆、柜台重叠，且有至少一个可走出口。

## 3. 任务、门禁、保存兼容

| 任务/系统 | 不应丢失的关系 |
|---|---|
| q_c19 晴岚港的新市民 | 前置 q_c16；15级；isa→mayor；接取即授予 `city_access`，完成奖励战袍、机械坐骑和钱 |
| q_d1 城市导览 | mayor→gate_captain；探索依次为 poi_harbor、poi_plaza、poi_market、poi_guild、poi_station、poi_airport、poi_cathedral |
| q_d2 冒险者登记 | mayor→guild_master |
| q_d3 幻化的艺术 | guild_master→transmog，前置q_d2 |
| q_d4 魔导列车 | guild_master→station_master，前置q_d2 |
| q_d5 飞空艇之梦 | station_master→airship_captain，前置q_d4 |
| 铁路开放 | q_c12完成；进入晴岚港方向额外要求city_access；站名/车站外观可改但spawn ID保留 |
| 飞行开放 | fp_solenne要求city_access；玩家fps字典存已发现ID |
| 城门 | 三门的flag都为city_access；新的水门、排水口、铁路缺口、岸边绕行也须验证未授权不能绕入 |

重要：`pd.quests[qid].p`是按目标数组索引保存进度（`game.gd:788–797`）。即使保留POI ID，也不要无迁移地调换q_d1七个目标的顺序、插入新目标或更改既有任务ID。`pd.explored`以POI ID保存，不应清空重新送全部探索经验。

**仅保留ID并不足以保证旧存档安全。** `pd.pos`和`pd.bind.pos`是世界绝对坐标。当前world_ver迁移只做区域offset校正（`world.gd:67–71`）；城内新墙/水面会使旧位置失效，现有加载逻辑只向上修正低于地面的Y，不保证水平位置有出口。建议增加独立city_layout_ver，在首次读取旧城市存档时：

1. 对旧城市范围内的玩家位置做一次性迁移或落点可达检测；已解锁选择安全城市到达点，未解锁选择gy_gate；不改城外位置。
2. 对旧城市旅店绑定点做等价处理，优先通过稳定旅店/出生点ID重新绑定，不能仅移动当前玩家。
3. 当前副本离开使用 `DB.zones[cur].entrance` 的区域/出生点ID（`win_dungeon.gd:135–142`），不是保存原进入位置；继续保留城外 `from_sanctum`，不额外发明“回原地”存档字段。
4. 保留`quests/qdone/flags/fps/explored/bank/auction/tmog/professions/recipes/guild/welfare_day`等既有数据；迁移完成后记录版本，第二次加载不再移位。
5. 用复制的测试数据验证迁移，绝不让自动测试覆盖用户存档。当前autotest已经设置 `Game.slot_index=-1`（`:86`附近），应继续保持。

## 4. 地图、流式加载和建筑格式

### CityHouses

- 每栋恰好10个float：`x,y,z,yaw_deg,width,height,depth,wall_palette,roof_palette,model_index*8+trim_palette`。`CityHouses.STRIDE=10`；WorldStream又直接写死了`i*10`（`world_stream.gd:95–119`）。只有同时改消费者才能改格式。
- x/y/z为该CityHouses父坐标系的局部坐标；streamer按120m分块并保留原坐标，不要一边平移数据、一边再平移父节点。
- `models`、`palette`必须与索引一致；缺模型/错误nominal会导致缩放错误。住宅可减少到合理数量，不需保留1150栋。
- CityHouses默认每栋整体盒碰撞，不适用于需要进入的店铺/院落/廊道；这些应使用有空洞的模块建筑描述。
- `MapGen._draw_props()`遇CityHouses调用其`draw_map()`后continue；父级不应夹带需要单独绘制的其他建筑而被跳过。

### ModelProp / Prop / 模块建筑

- streamer在Zone进入SceneTree前递归登记ModelProp、Prop和CityHouses，设置`stream_deferred`；新建筑应遵循这个生命周期，不能在`_ready()`忽略标记把全城一次性建出来。
- ModelProp的`size`参与加载范围（最大尺寸×16，限制200..1100m）和地图轮廓；即使使用`asset_scene`原生米制模块，size也要填写真实占地，避免看得见但没加载或地图显示错误。
- `stream_asset_paths()`需与`rebuild()`实际加载同一资源；`stream_unload()`只释放生成子节点，保留描述符。不要把NPC/POI嵌入会被释放的`_gen`。
- 新kind需登记`ModelProp.LIB`、模型路径和`assets/models/models.json`尺寸；若使用现有kind+asset_scene，可以利用现有明确模块装配流程保留原生尺寸、材质和空门碰撞（`model_prop.gd:200`起）。
- 默认full碰撞是整个包围盒。可入内建筑必须显式使用正确分墙碰撞或精确网格，不能仅模型视觉上挖门。`MESH_COLLIDE`不是自动识别开门，白名单之外仍堵门。
- 地图只认识Prop/ModelProp及CityHouses；普通Node3D模块若不提供可被MapGen消费的外层描述，可能实体有建筑、地图却无轮廓（`map_gen.gd:176–219`）。
- NPC创建时从标记上方3m向下80m投射落地（`zone.gd:56–64`）；室内标记应给准确楼面Y，确保射线起点低于天花/雨棚，并在建筑碰撞已加载后生成。小于3m净高特别要实测。
- 当前演员加载150m、保留230m。NPC测试不能只遍历已生成npcs来证明全城NPC都存在，应先按NpcSpot ID移动/准备对应区域。

## 5. autotest需要更新的定位假设

`tests/autotest.gd`的大部分服务测试已通过 `_goto_npc(id)`定位，不是全都写死坐标。保留这一机制，不需要为新城另写一批服务坐标。

| 位置 | 当前假设 | 重建后建议 |
|---|---|---|
| TOURS.city，19–24附近 | 22个v4拍照点全为坐标 | 按新POI/NPC/专用审计锚点ID得到位置，再叠加镜头偏移；不要继续在旧地址截图 |
| TOURS.tidewind gate，39附近 | gate=(262,450) | 使用poi_citygate或城外到达锚点 |
| `_goto_npc` 227–240 | 第一次瞬移永远+世界Z方向3m，随后按NPC朝向定位 | 室内/转角会落入墙；用作者定义的交互锚点或选取朝向前的可站立点，并等待streamer/NPC就绪 |
| crafting 282 | 制作点(140,440) | 以smith_master及真实工作点ID定位；现有系统允许随时制作，勿用旧铁砧说明掩盖新室内落点失败 |
| crafting 302 | 远点(100,440) | 从当前工作点找到安全路面偏移或使用独立测试锚点 |
| services 582/584 | fp_camp=(706,390) | 城外暂不变也能运行，但应读取 `zones.tidewind.get_spawn("fp_camp").global_position` |
| services 600 | st_solenne=(36,653) | 必须改为读取st_solenne真实位置；调用ride_train本来已使用该ID |
| tour 691 | `spring.collision_mask=0` | 只适用于美术远景；另外用正常相机碰撞、正常角色高度拍街道/室内，不能把这项截图算步行体验通过 |
| crafting 255–260 | 只测当前加载NPC且ground_height也可能命中建筑 | 不能证明所有NPC没有站屋顶；逐服务ID检查预期楼面、胶囊空隙与交互视线 |

测试固定坐标排查：`rg -n '_wp\("tidewind"|TOURS|spring.collision_mask' tests/autotest.gd`。

## 6. 基线采集与可执行验收顺序

审计脚本 `.local/city_v5/capture_contract.py`只读保存场景，输出仅允许写入`.local/city_v5`。它不会启动游戏、覆盖场景、读取个人存档或修改业务数据。已保存`.local/city_v5/baseline.json`：整张潮风区域802个Prop/ModelProp描述、148个NPC、64个POI、15个出生点，城市契约71个NPC ID/57个POI ID/4个出生点，住宅1150栋。

```powershell
py -3.11 .local/city_v5/capture_contract.py --compare .local/city_v5/baseline.json --out .local/city_v5/current.json
```

比较会返回缺失ID和无效住宅步长，失败时进程退出1。它只证明描述存在，**不能证明**NPC能到达、门洞能通过、落点可用或任务触发正确。基线JSON也保存全区域节点局部坐标/姿态、POI半径与优先级、门禁flag和住宅数组，便于审查有无无意移动野外。

建议按以下顺序执行，不扩展为与此次重建无关的回归：

1. 生成前后运行采集；检查71/57/4契约和野外节点变动；场景解析/资源缺失检查通过后才进入运行时。
2. 使用隔离测试角色运行现有 `mode=services` 和 `mode=crafting`。列车返回断言必须先按ID更新；记录真实ALL PASS和失败项，不把截图存在当通过。
3. 新角色未获city_access：实走三个门、水门/河道、海岸、铁路下方/桥面，验证门禁没有漏洞；获得标记后，同样门洞可以通过且不留隐形碰撞。
4. 从城外东门连续走到市政、银行、拍卖、旅店、公会、车站、飞艇；用实际输入和正常相机，不通过瞬移证明可达。记录银行→拍卖→生产/仓库的实际路长和时长。
5. 对每个服务NPC检查可见入口、室内外转换、交互站位、NPC楼面、至少一个出口；银行/拍卖/旅店最优先。双向走门，不只站在门口。
6. 用已接q_d1测试角色依原目标顺序实际触发七POI；确认priority遮挡没有吞掉探索，交回gate_captain。检查q_d2–q_d5能完成。
7. 检查炉石、列车双向、飞行到达、死亡最近墓地、副本退出回城外 `from_sanctum`，保证着陆后能走出；一次远离加载范围再返回，验证建筑/NPC/室内碰撞正确重建。
8. 用旧数据副本验证位于旧广场、旧水边、旧旅店、城外四种保存位置和炉石绑定；迁移后任务、物品、探索和交通发现不丢，二次加载不再搬动。
9. 地图对照街道与入口，正常镜头检查主要街道/转角/广场/室内，再做航拍。最终记录未完成的验证，不混称全部通过。

上述是兼容验证建议，不表示这些运行时验证已经执行。
