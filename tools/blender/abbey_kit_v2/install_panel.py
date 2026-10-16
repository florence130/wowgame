"""Run in Blender's Text Editor or via Blender MCP. Keeps current scene intact."""
from pathlib import Path
import bpy, runpy, json

HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[2]
namespace=runpy.run_path(str(HERE.parent/'abbey_kit'/'blender_panel.py'))
namespace['register']()
pointer=PROJECT/'assets/models/abbey_kit_v2/LATEST.json'
build=json.loads(pointer.read_text(encoding='utf8'))['build_directory'] if pointer.exists() else str(PROJECT/'assets/models/abbey_kit_v2/game_003')
settings=bpy.context.scene.aby_settings
settings.directory=build
settings.moving_socket='start';settings.target_socket='end'
bpy.ops.aby.read_catalog()
print('Abbey v2 architecture catalog:',build)
