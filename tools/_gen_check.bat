@echo off
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
"%G%" --headless --path %P% --import > %TEMP%\wow_imp.txt 2>&1
"%G%" --headless --path %P% res://tools/gen.tscn -- vale tidewind > %TEMP%\wow_gen2.txt 2>&1
"%G%" --headless --path %P% res://tests/check.tscn > %TEMP%\wow_check3.txt 2>&1
echo DONE > %TEMP%\wow_gc_done.txt
