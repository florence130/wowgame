# 晴岚港 v5 住宅建筑库

原生米制建筑，Godot 正面 -Z，室内地坪 y=0，街面 y=-0.6m。节点放在整平街面 +0.6m，保持 scale=(1,1,1)。各楼层、窗门、台阶均为固定真实尺寸。

外观按材质合并。`-colonly` 子网格由 Godot 导入为静态低复杂碰撞；商铺、客栈和学院庭院的首层入口留有真实门洞与室内地坪。住宅可以封闭。图形细节不参与碰撞。

详细尺寸、入口、轮廓、实际高度和碰撞三角形数量见 manifest.json。每个GLB同目录保留对应.blend。

构建：Blender 后台运行 tools/blender/city_v5/architecture.py -- --all。单体预览：--asset corner_merchants_3 --render。
