# 阶段 2：混元 3D 无纹理低面生成

用户在图包交付后明确要求：由本助手使用提供的混元3D API Key 生成，不生成纹理，生成低面拓扑。用户随后澄清这是混元3D的API Key，不沿用上一轮图片代理。密钥不写入此文件或项目脚本。

当前目标为六件 TR01–TR06 的实际3D模型生成、下载、纹理与面数检查、图像复核和接手资料。第一阶段的图像、ID与建议尺寸沿用；不修改原图和旧模型库。完整建筑CSG/SDF各阶段及两套结构拼装仍是后续范围。

## 已核对的官方接口

- [API Key兼容接口](https://cloud.tencent.com/document/product/1804/126189)：`https://api.ai3d.cloud.tencent.com/v1/ai3d/submit` 与 `/query`，Authorization直接使用API Key，官方例没有Bearer前缀。
- [专业版提交参数](https://cloud.tencent.com/document/product/1804/123447)：Geometry明确为无纹理白模；FaceCount最低3000；默认3个并发；图片与Prompt不能同时传。
- [独立拓扑接口](https://cloud.tencent.com/document/product/1804/126293)：SubmitReduceFaceJob为TC3接口。本轮未找到API Key路径，不臆造接口或称已经调用。

实际采用：Model=3.0，GenerateType=Geometry，FaceCount=3000，EnablePBR=false，ImageBase64为单件PNG的原始base64。不调用Normal或纹理生成。仅关闭EnablePBR不足以保证无纹理；因此明确选择Geometry。

Geometry与LowPoly是同一字段的互斥取值，不能同时启用。这里使用白模模式的面数控制来满足低面要求，不宣称使用了混元的独立智能重拓扑服务。下载后要验证真实网格，而不能仅凭3000参数宣称达标。

第一次按照兼容文档的“ImageUrl.Url”描述提交嵌套data URI，收到HTTP 400、参数错误、没有JobId。保留错误回执后按专业版文档改用ImageBase64，TR01成功受理。后续沿用同一有效schema。提交成功或结果不明时禁止自动重试，避免重复收费；可查询已保存的JobId恢复。

## 文件及完成条件

- API工具：`tools/blender/abbey_tripo/hunyuan_client.py`。凭据仅从请求进程的HUNYUAN3D_API_KEY读取，不保存。
- 任务回执：`.local/abbey_hunyuan_20261007/jobs/TRxx/`，包含不带图片base64和密钥的参数记录、JobId与查询结果。下载链接不作为永久交接资产。
- 原始模型：`assets/models/abbey_hunyuan_v1/build001/raw/TRxx.glb`，每件旁存来源/参数/hash/平台返回积分回执；原始文件不覆盖。
- 本地检查：真实三角面数、images/textures及引用、退化/边界/非流形边、连通组件，正/背/3/4视图。孔洞、手性、宽缓拱轮廓与拼接表面需实际看图。
- 候选模型需单独归一化，保留原始文件。仅在证据成立后记录“当前检查通过”；不把生成成功称为全套建筑或游戏已接入。

继承GPT-6 Astra Low同一陪审链，工程模式。新增必要目标：H1六件真实生成与来源；H2无纹理和真实低面；H3形体/孔洞/方向与参考；H4可下载可接手的模型与状态。前阶段G1–G4通过不代替这四项模型验收。
