# village_kit 材质：名字即游戏端材质（K|mtype|RRGGBB|贴图|米；N|RRGGBB 夜间发光窗格）；Blender 里只做预览（贴图 × 底色，盒状投影）。
import bpy, os
HERE = os.path.dirname(os.path.abspath(__file__))
TEXDIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "textures", "building"))
_cache = {}

def get(name):
    if name in _cache and _cache[name].name in bpy.data.materials:
        return _cache[name]
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    _cache[name] = m
    f = name.split("|")
    if f[0] == "M":                                   # 洛奇M 图集贴图（按模型自带 UV 贴）：Blender 里只是预览
        m.use_nodes = True
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 1.0
        p = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "textures", "mabi", f[1] + ".png"))
        if os.path.exists(p):
            im = nt.nodes.new("ShaderNodeTexImage")
            im.image = bpy.data.images.load(p, check_existing=True)
            nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
        return m
    c, tex, tm, glow = (0.7, 0.7, 0.7), "", 3.0, False
    if f[0] == "K":
        c = tuple(int(f[2][i:i + 2], 16) / 255 for i in (0, 2, 4))
        tex = f[3] if len(f) > 3 else ""
        tm = float(f[4]) if len(f) > 4 and f[4] else 3.0
        glow = f[1] == "glow"
    elif f[0] == "N":
        c = tuple(int(f[1][i:i + 2], 16) / 255 for i in (0, 2, 4))
    m.diffuse_color = (*c, 1.0)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*[x ** 2.2 for x in c], 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*c, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    path = os.path.join(TEXDIR, tex + ".png") if tex else ""
    if path and os.path.exists(path):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        s = 1.0 / max(tm, 0.1)
        mp.inputs["Scale"].default_value = (s, s, s)
        im = nt.nodes.new("ShaderNodeTexImage")
        im.image = bpy.data.images.load(path, check_existing=True)
        im.projection = "BOX"
        im.projection_blend = 0.2
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*[x ** 2.2 * 2.0 for x in c], 1)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], im.inputs["Vector"])
        nt.links.new(im.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m

def reset():
    _cache.clear()
