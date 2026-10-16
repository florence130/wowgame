# 图像生成与交付来源

用户指定图片 API 服务后，使用 imagegen 技能自带 CLI 的 edit 模式、gpt-image-2、high、3072×2048，以 `references/townhall.png` 为形制参考生成一张六部件图。服务地址为 `https://www.poke2api.com/v1`。这是用户授权的 API 路径，不是内置生图工具；没有调用 Tripo 生成服务。密钥只用于请求进程环境，不写入项目文件或交接包。

源提示词在 `image_prompt.txt`。首次执行发现 Python 版本与现有依赖不匹配，切换到匹配的 Python 3.12；第一次网络请求连接中断，未获得图片。随后仅对指定 API 域名配置请求进程的 NO_PROXY，成功请求返回耗时 202.3 秒；这不是整个任务耗时，也不是计费记录。

原 API 图：`E:/wowgame/output/imagegen/abbey_tripo_20261007/tripo_parts_clean_v1.png`。原图没有编号、文字和网格，但物体并未严格位于等分格以内，不能直接按等分格切图。

`crop_regions.json` 保存按实际轮廓核对的六个不重叠裁切区域。`make_image_pack.py` 仅裁切、等比缩放、居中留白和添加总览标签，没有补画物体形状。每件输出为 1024×1024 PNG；另重新拼成 3072×2048 无字总图与 3072×2656 带编号总览。原图另存为包内 `api_source.png`；来源 hash、裁切坐标与单图 hash 在 `image_manifest.json`。

交付目录：`E:/wowgame/output/imagegen/abbey_tripo_20261007/pack_v1/`。

- `tripo_parts_board.png`：带中文名称、稳定 ID、建议尺寸的总览。
- `tripo_parts_clean.png`：六件无字总图，便于集中查看。不能保证将整图交给 Tripo 会自动输出六个独立模型。
- `parts/TR01.png` 至 `TR06.png`：对应六件的无字独立输入；同目录有逐件英文提示。
- `TRIPO_PROMPTS.md`：六件提示集合。
- `image_manifest.json`：来源、裁切和 SHA-256。

六件均为建筑造型探索参考，不是从参考图逐像素抠出的原件，不证明背面、真实拓扑、尺寸或接面已正确。建议尺寸属于模块设计提案；图中展示比例不是工程测量。默认仍可用 Blender 原生方法制作，Tripo 是可选分流。

重建图包（输出目录必须全新；不调用图片 API）：

```powershell
py -3 tools/blender/abbey_tripo/make_image_pack.py --source output/imagegen/abbey_tripo_20261007/tripo_parts_clean_v1.png --out output/imagegen/abbey_tripo_20261007/pack_rebuild --regions docs/abbey_tripo_20261007/crop_regions.json
```

图片已由主AI与独立陪审实际看图检查；具体版本、范围与最终裁定以 `REVIEW.md` 为准。真实 Tripo 模型尚未返回，合成 GLB 测试不能替代其验收。
