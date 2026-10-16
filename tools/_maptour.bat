@echo off
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
"%G%" --path %P% res://tests/autotest.tscn -- mode=map out=%P%/.shots/w1 > %TEMP%\wow_map.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=tour zone=vale out=%P%/.shots/w1 > %TEMP%\wow_w1.txt 2>&1
echo DONE > %TEMP%\wow_mt_done.txt
