@echo off
rem 生成 → 检查 → 世界地图 → 晨露谷巡游 → 主城服务 → 传送门 → 专业。日志 %TEMP%\wow_f_*.txt
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
"%G%" --headless --path %P% res://tools/gen.tscn -- tidewind > %TEMP%\wow_f_gen.txt 2>&1
"%G%" --headless --path %P% res://tests/check.tscn > %TEMP%\wow_f_check.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=map out=%P%/.shots/f_map > %TEMP%\wow_f_map.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=tour zone=vale out=%P%/.shots/f_tour > %TEMP%\wow_f_tour.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=services out=%P%/.shots/services > %TEMP%\wow_f_services.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=portal out=%P%/.shots/portal > %TEMP%\wow_f_portal.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=crafting out=%P%/.shots/crafting > %TEMP%\wow_f_crafting.txt 2>&1
echo DONE > %TEMP%\wow_f_done.txt
