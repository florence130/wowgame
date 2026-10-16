@echo off
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
"%G%" --path %P% res://tests/autotest.tscn -- mode=basic out=%P%/.shots/basic > %TEMP%\wow_reg_basic.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=crafting out=%P%/.shots/crafting > %TEMP%\wow_reg_crafting.txt 2>&1
echo REG_DONE > %TEMP%\wow_reg_done2.txt
