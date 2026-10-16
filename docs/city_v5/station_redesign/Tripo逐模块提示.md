# 晴岚中央车站 · 重设计与Tripo构件包：Tripo 逐模块提示

这份清单基于新车站设计渲染，不是旧站房资产截图。先确认整体方案，再逐件生成；尚未调用 Tripo，也未自动应用到游戏。

## 使用方法

1. 打开「模块目录.html」，先看整体视图与模块拼接关系。
2. 每次只生成一件模块，以该模块 hero.png 为主要图像参考；界面支持多图时，再加入正面、右侧、背面与俯视图。不要把整座车站视图当成单模块参考。
3. 复制该模块的英文提示。每件保持完整的结构单元，不拆成单枚窗、单根柱或零散装饰。
4. 生成后检查背面、洞口、厚度和接口。优先按拼接面、开间节距与楼层标高校准尺寸，再核对含檐口和装饰的外包尺寸；确认宽、高、深与朝向，再进行重复拼装；提示中的米制尺寸不能替代导入后的测量。
5. 保留原始生成文件。进入游戏前仍需清理拓扑、建立简化碰撞、检查材质与比例，并沿真实角色路线复验。

所有模块采用同一风格参考。清单中的设计尺寸用于结构与接口，渲染外包尺寸包含檐口、底座和装饰，不要把含外挑的整件强行缩到名义开间宽度。M05 的底部安装在大厅基准面上方 13.4m；M07 的上下平台高差也是 13.4m。

建议顺序：中央到达大厅 → 服务翼楼标准开间 → 翼端转角亭楼 → 候车厅拱顶标准段 → 中央时钟与翼饰冠 → 站台雨棚标准段 → 候车厅后端拱窗 → 通往高架站台的双跑楼梯 → 正门台阶与中间缓坡 → 站前成组双臂灯 → 海港铁路徽章浮雕。先完成中央大厅和一个标准开间的风格试件，再成批制作。

基线清单 SHA256：b07052366feb999e40b45f081cc69d9b7a771b59485f8fae03abe3c1c0ed0a7f

## M01_entrance_pavilion · 中央到达大厅

- 结构与接口设计尺寸（宽 × 高 × 深）：32 × 27 × 14 m
- 渲染外包尺寸（含檐口与装饰）：33 × 27.8 × 17.3 m
- 计划复用：1 件
- 主要参考：[立体图](modules/M01_entrance_pavilion/hero.png) · [正面](modules/M01_entrance_pavilion/front.png) · [右侧](modules/M01_entrance_pavilion/right.png) · [背面](modules/M01_entrance_pavilion/back.png) · [俯视](modules/M01_entrance_pavilion/top.png)
- 接口：左右侧面 x=±16 为翼楼拼接面
- 接口：后侧 z=7 接候车厅；14m门洞保持贯通
- 制作注意：保留大拱门、上方采光窗和门廊；时钟冠饰另件，不把钟楼和大厅熔为一体。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate the complete entrance pavilion as one architectural module: the full arched doorway, supporting wall masses, attached columns or pilasters, cornice and its integrated roof. Keep the main doorway open and usable. Do not separate individual windows or columns.

Nominal structural/interface envelope: width 32 m, height 27 m, depth 14 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 33 x 27.8 x 17.3 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated central entrance pavilion only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: The left and right structural joining planes are x=-16 m and x=+16 m. / The rear plane z=+7 m connects to the waiting hall. Keep the 14 m-wide principal passage fully open. / The separate clock-and-crest module is not part of this pavilion..
```

## M02_wing_bay · 服务翼楼标准开间

- 结构与接口设计尺寸（宽 × 高 × 深）：10 × 20 × 20 m
- 渲染外包尺寸（含檐口与装饰）：10.9 × 20.81 × 22.58 m
- 计划复用：4 件
- 主要参考：[立体图](modules/M02_wing_bay/hero.png) · [正面](modules/M02_wing_bay/front.png) · [右侧](modules/M02_wing_bay/right.png) · [背面](modules/M02_wing_bay/back.png) · [俯视](modules/M02_wing_bay/top.png)
- 接口：左右 x=±5 是无外挑装饰的拼接面
- 接口：正面 z=-10；每个10m开间包含完整门窗节奏
- 制作注意：票务、行李与旅客服务用同一标准开间复用；窗框随墙体整体生成。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete repeatable side-wing bay with its full wall, integrated window or arcade opening, pilasters, cornice and roof slice as shown. Keep the left and right joining faces clean and vertically planar so adjacent bays repeat without gaps. Do not generate a whole station.

Nominal structural/interface envelope: width 10 m, height 20 m, depth 20 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 10.9 x 20.81 x 22.58 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated repeatable side-wing bay only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: The structural joining planes are x=-5 m and x=+5 m; preserve the 10 m repeat pitch. Do not place projecting ornament on the contact planes. / Front is z=-10 m. Keep a complete door/window rhythm in each bay and continue the roof profile across adjacent bays..
```

## M03_corner_pavilion · 翼端转角亭楼

- 结构与接口设计尺寸（宽 × 高 × 深）：16 × 28 × 22 m
- 渲染外包尺寸（含檐口与装饰）：18.58 × 28.6 × 24.795 m
- 计划复用：2 件
- 主要参考：[立体图](modules/M03_corner_pavilion/hero.png) · [正面](modules/M03_corner_pavilion/front.png) · [右侧](modules/M03_corner_pavilion/right.png) · [背面](modules/M03_corner_pavilion/back.png) · [俯视](modules/M03_corner_pavilion/top.png)
- 接口：朝中央大厅的一侧与翼楼接合
- 接口：正面 z=-11；右侧版本通过旋转/适当镜像组装
- 制作注意：带转角壁柱、陡屋面和小型采光冠；它是横向站房的收尾，不是独立高塔。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete corner pavilion, including both visible facades, its supporting base, roof and attached architectural details. Preserve the connection face or faces shown in the reference; do not add adjoining station wings.

Nominal structural/interface envelope: width 16 m, height 28 m, depth 22 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 18.58 x 28.6 x 24.795 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated corner pavilion only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Keep the inward-facing side suitable for connection to the service wing. Front is z=-11 m. / The pavilion terminates the horizontal station facade; do not turn it into an independent tall tower..
```

## M04_vault_segment · 候车厅拱顶标准段

- 结构与接口设计尺寸（宽 × 高 × 深）：32 × 9 × 10 m
- 渲染外包尺寸（含檐口与装饰）：32.8 × 8.79 × 10.45 m
- 计划复用：4 件
- 主要参考：[立体图](modules/M04_vault_segment/hero.png) · [正面](modules/M04_vault_segment/front.png) · [右侧](modules/M04_vault_segment/right.png) · [背面](modules/M04_vault_segment/back.png) · [俯视](modules/M04_vault_segment/top.png)
- 接口：前后 z=±5 都保持开口
- 接口：拱脚 x=±16,y=0；按10m节距连续拼接
- 制作注意：包含完整钢拱、檩条和青色玻璃壳；禁止把端面封成实体墙。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one structural segment of the station hall vault, including the visible ribs and roof or glazing infill. Preserve the open interior volume and the flat repeated joints at both longitudinal ends. Do not cap the ends or add a floor, wall or station building not shown.

Nominal structural/interface envelope: width 32 m, height 9 m, depth 10 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 32.8 x 8.79 x 10.45 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated hall vault segment only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Keep both longitudinal ends z=-5 m and z=+5 m open for a 10 m repeat pitch. / The springing lines are x=-16 m and x=+16 m at local y=0. Preserve the steel arches, purlins and cyan glazing. Do not cap either end..
```

## M05_vault_end · 候车厅后端拱窗

- 结构与接口设计尺寸（宽 × 高 × 深）：32 × 17 × 1.2 m
- 渲染外包尺寸（含檐口与装饰）：32 × 16.84 × 1.99 m
- 计划复用：1 件
- 主要参考：[立体图](modules/M05_vault_end/hero.png) · [正面](modules/M05_vault_end/front.png) · [右侧](modules/M05_vault_end/right.png) · [背面](modules/M05_vault_end/back.png) · [俯视](modules/M05_vault_end/top.png)
- 接口：顶部半圆拱与M04同宽32m
- 接口：下部中央保留12m宽站台通道
- 接口：后端底面放在二层站台标高13.4m
- 制作注意：端墙与拱顶分件；玻璃区清晰分格，不要生成一整块不透明石墙。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate the complete vault end assembly shown, retaining the main arch profile, glazing or wall infill and attached frame. Its rear joint must match the hall vault segment. Preserve all intentional doorway openings.

Nominal structural/interface envelope: width 32 m, height 17 m, depth 1.2 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 32 x 16.84 x 1.99 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated vault end assembly only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Match the 32 m-wide arch profile of M04 at the upper edge. / Keep the lower central platform passage 12 m wide and unobstructed. / The local bottom datum is y=0; in the assembled station it is placed at y=13.4 m above the entrance-floor datum. Do not add a 13.4 m-tall plinth or wall below this module. / Keep the glazing mullions and transparent areas distinct; do not replace them with an opaque solid stone wall..
```

## M06_platform_canopy · 站台雨棚标准段

- 结构与接口设计尺寸（宽 × 高 × 深）：14 × 6.5 × 10 m
- 渲染外包尺寸（含檐口与装饰）：14.2 × 6.5 × 10.6 m
- 计划复用：6 件
- 主要参考：[立体图](modules/M06_platform_canopy/hero.png) · [正面](modules/M06_platform_canopy/front.png) · [右侧](modules/M06_platform_canopy/right.png) · [背面](modules/M06_platform_canopy/back.png) · [俯视](modules/M06_platform_canopy/top.png)
- 接口：前后 z=±5 开放，可按10m重复
- 接口：柱脚以模块底面y=0为基准
- 制作注意：整段生成柱、梁和折线屋盖，保持柱间可通行；不要自动加地面和列车。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete repeatable platform canopy unit with its integrated roof, structural frame and supporting columns. Preserve clear passenger space below the canopy and the repeated roof joints. Do not include tracks, trains, passengers or platform ground.

Nominal structural/interface envelope: width 14 m, height 6.5 m, depth 10 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 14.2 x 6.5 x 10.6 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated platform canopy unit only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Both ends z=-5 m and z=+5 m stay open for 10 m repetition. / Column feet use local y=0 as their placement datum. Keep the space between columns clear..
```

## M07_stair_gallery · 通往高架站台的双跑楼梯

- 结构与接口设计尺寸（宽 × 高 × 深）：12 × 15 × 20 m
- 渲染外包尺寸（含檐口与装饰）：12 × 14.819 × 20 m
- 计划复用：2 件
- 主要参考：[立体图](modules/M07_stair_gallery/hero.png) · [正面](modules/M07_stair_gallery/front.png) · [右侧](modules/M07_stair_gallery/right.png) · [背面](modules/M07_stair_gallery/back.png) · [俯视](modules/M07_stair_gallery/top.png)
- 接口：下层入口楼面y=0，二层楼面y=13.4
- 接口：上下出入口在前侧，两个楼梯方向相反
- 制作注意：以图保留双跑、平台和栏杆。Tripo外观件回收后须重新制作精确台阶/平滑碰撞。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete stair-gallery connection as shown, including the stair runs, landings, supporting walls and balustrades. Keep the walking path continuous and both connection landings open; do not add terrain or unrelated buildings.

Nominal structural/interface envelope: width 12 m, height 15 m, depth 20 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 12 x 14.819 x 20 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated stair-gallery connection only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: The lower entrance-floor datum is local y=0 and the upper landing datum is y=13.4 m. / The two stair flights run in opposite directions, with both the lower and upper entrances on the front side. Preserve the intermediate landing and railings. / This generated module is a visual reference; exact steps and smooth walking collision will be rebuilt separately after generation..
```

## M08_clock_crest · 中央时钟与翼饰冠

- 结构与接口设计尺寸（宽 × 高 × 深）：12 × 11 × 3 m
- 渲染外包尺寸（含檐口与装饰）：12 × 10.9 × 3 m
- 计划复用：1 件
- 主要参考：[立体图](modules/M08_clock_crest/hero.png) · [正面](modules/M08_clock_crest/front.png) · [右侧](modules/M08_clock_crest/right.png) · [背面](modules/M08_clock_crest/back.png) · [俯视](modules/M08_clock_crest/top.png)
- 接口：下方平直底座，居中装在M01屋顶前缘
- 接口：正面朝-Z，背面不添加支架以外的建筑
- 制作注意：重点精修模块：深浮雕表盘、金属指针、双翼与海港纹章；不要生成文字。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate the clock-and-crest assembly as one complete architectural ornament, including its frame, crest and mounting mass. Preserve the readable clock face and silhouette. Keep the rear mounting surface simple and flat; do not generate the pavilion beneath it.

Nominal structural/interface envelope: width 12 m, height 11 m, depth 3 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 12 x 10.9 x 3 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated clock-and-crest assembly only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Use a straight lower mounting base, centered on the front roof edge of M01. Front is -Z. / Include the clock dial relief, metal hands, paired wings and harbor crest; no lettering. Do not include the hall beneath it..
```

## M09_entry_steps · 正门台阶与中间缓坡

- 结构与接口设计尺寸（宽 × 高 × 深）：24 × 0.6 × 5 m
- 渲染外包尺寸（含檐口与装饰）：24 × 0.6 × 5 m
- 计划复用：1 件
- 主要参考：[立体图](modules/M09_entry_steps/hero.png) · [正面](modules/M09_entry_steps/front.png) · [右侧](modules/M09_entry_steps/right.png) · [背面](modules/M09_entry_steps/back.png) · [俯视](modules/M09_entry_steps/top.png)
- 接口：前缘y=-0.6；后缘y=0接大厅
- 接口：中央4m净宽缓坡，两侧三级台阶
- 制作注意：精确土木件建议最终Blender重建，Tripo可用于石材表面参考；切勿把台阶熔成乱石。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate the complete entrance step-and-landing assembly shown as one module. Preserve the stair count, broad central walking route and any ramps or side balustrades visible in the reference. Keep the top landing and rear joining edge flat.

Nominal structural/interface envelope: width 24 m, height 0.6 m, depth 5 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 24 x 0.6 x 5 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated entrance step assembly only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: The front edge is at local y=-0.6 m and the rear connection to the hall is at y=0. / Keep a clear central ramp 4 m wide, with three steps on each side. / This is a precision civil element; preserve the simple dimensions and stone surfaces, with exact geometry to be rebuilt after generation..
```

## M10_plaza_lamp · 站前成组双臂灯

- 结构与接口设计尺寸（宽 × 高 × 深）：3.6 × 6.2 × 1.4 m
- 渲染外包尺寸（含檐口与装饰）：3.86 × 6.2 × 1.06 m
- 计划复用：8 件
- 主要参考：[立体图](modules/M10_plaza_lamp/hero.png) · [正面](modules/M10_plaza_lamp/front.png) · [右侧](modules/M10_plaza_lamp/right.png) · [背面](modules/M10_plaza_lamp/back.png) · [俯视](modules/M10_plaza_lamp/top.png)
- 接口：底面中心为安装点
- 接口：保留两灯的对称朝向与实体底座
- 制作注意：两盏灯与灯柱作为完整单件；生成时不带地面、不带其他建筑。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete plaza lamp assembly, including its base, pole, brackets and lanterns. Preserve the number of lanterns and overall silhouette. Do not add ground, street furniture or other lamps.

Nominal structural/interface envelope: width 3.6 m, height 6.2 m, depth 1.4 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 3.86 x 6.2 x 1.06 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated plaza lamp assembly only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Use the center of the bottom mounting face as the placement point. / Keep the two lanterns symmetrical, with one solid base and pole..
```

## M11_relief_roundel · 海港铁路徽章浮雕

- 结构与接口设计尺寸（宽 × 高 × 深）：3.2 × 3.2 × 0.5 m
- 渲染外包尺寸（含檐口与装饰）：3.2 × 3.2 × 0.64 m
- 计划复用：4 件
- 主要参考：[立体图](modules/M11_relief_roundel/hero.png) · [正面](modules/M11_relief_roundel/front.png) · [右侧](modules/M11_relief_roundel/right.png) · [背面](modules/M11_relief_roundel/back.png) · [俯视](modules/M11_relief_roundel/top.png)
- 接口：背面为平面，正面朝-Z
- 接口：安装在门楣/翼端空白徽章位
- 制作注意：海翼与轮轨意象的浅浮雕，避免文字；与时钟冠分开，方便复用。

英文提示：

```text
A monumental European fantasy railway terminus for a stylized MMORPG. Follow the supplied new-station reference images exactly for proportions, warm masonry, roof colors, metalwork, ornament and material placement. Architectural details should read clearly at game scale.

Generate one complete relief roundel and its surrounding architectural frame. Keep the relief shallow and attached to a solid backing, with a flat rear mounting surface. Do not generate unrelated walls or separate tiny decorative pieces.

Nominal structural/interface envelope: width 3.2 m, height 3.2 m, depth 0.5 m. These are the design dimensions, not necessarily the outside limits of eaves, bases or ornaments. The rendered reference's full outer bounding dimensions, including projections, are approximately 3.2 x 3.2 x 0.64 m (width x height x depth). Preserve the reference proportions and stated joining planes. Do not shrink the entire outer silhouette to the nominal interface envelope.

Treat the supplied front, right, back and top views as views of the same object. Keep the front-facing direction consistent. Model the visible rear and side surfaces completely, with clean manifold geometry and purposeful low-frequency architectural detail. Keep openings open, avoid paper-thin walls and avoid holes or melted ornament. Joining surfaces must remain unadorned where they touch other modules. Match the connection planes documented on the module sheet.

One isolated relief roundel only, centered with no ground plane, no scene, no text labels, no dimension arrows, no people, no vegetation, no vehicles, no adjacent modules and no invented extra structures. Match the reference materials and colors. This is a game-ready architectural component, not a whole city or a diorama.

Connection requirements: Keep the rear mounting face flat and the decorated front facing -Z. / Use a shallow relief of harbor wings and railway-wheel imagery; no text. Keep the relief and backing as one assembly..
```
