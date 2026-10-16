"""Package the project's MCP servers as Claude Desktop extensions (.mcpb) so they appear under Connectors
(Cowork only sees connectors / desktop extensions). Each bundle holds a thin launcher that runs the real
server from E:\\wowgame\\tools\\mcp, so editing the project needs no re-install.

Run: python tools/mcp/build_mcpb.py   -> dist/mcpb/*.mcpb   (double-click each to install in Claude Desktop)
"""
import json
import os
import zipfile

PY = r"C:\Users\17408\AppData\Local\Programs\Python\Python311\python.exe"
OUT = r"E:\wowgame\dist\mcpb"

LAUNCH_PY = '''import runpy, sys
sys.argv = [{target!r}]
runpy.run_path({target!r}, run_name="__main__")
'''
LAUNCH_EXE = '''import subprocess, sys
sys.exit(subprocess.call([{target!r}]))
'''

BUNDLES = [
    {"name": "wowgame-godot", "display_name": "wowgame Godot 工具（本机）",
     "description": "在本机运行 Godot 4.7.2：脚本检查、自动化测试、区域重新生成、游戏/UI/模型截图、Blender 批量建模、项目文件读写（E:\\wowgame）。",
     "launcher": LAUNCH_PY.format(target=r"E:\wowgame\tools\mcp\godot_mcp_server.py")},
    {"name": "funplay-godot", "display_name": "Funplay MCP for Godot（编辑器）",
     "description": "连接打开的 Godot 编辑器（Funplay MCP 插件，120+ 工具：场景、脚本、UI、运行模式、截图）。需要先在 Godot 编辑器中启用 Funplay MCP 插件。",
     "launcher": LAUNCH_PY.format(target=r"E:\wowgame\tools\mcp\funplay_stdio_bridge.py")},
    {"name": "blender-mcp", "display_name": "Blender MCP（本机 Blender）",
     "description": "连接打开的 Blender（MCP for Blender 插件，localhost:9876）：查看场景、执行 Python、截图视口。需要先在 Blender 侧栏点 Connect。",
     "launcher": LAUNCH_EXE.format(target=r"C:\Users\17408\AppData\Roaming\Python\Python311\Scripts\blender-mcp.exe")},
]

os.makedirs(OUT, exist_ok=True)
for b in BUNDLES:
    manifest = {
        "manifest_version": "0.3",
        "name": b["name"],
        "display_name": b["display_name"],
        "version": "1.0.0",
        "description": b["description"],
        "author": {"name": "wowgame"},
        "server": {
            "type": "python",
            "entry_point": "server/main.py",
            "mcp_config": {"command": PY, "args": ["${__dirname}/server/main.py"], "env": {"PYTHONIOENCODING": "utf-8"}},
        },
        "compatibility": {"platforms": ["win32"]},
    }
    path = os.path.join(OUT, b["name"] + ".mcpb")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        z.writestr("server/main.py", b["launcher"])
    print("built", path)
