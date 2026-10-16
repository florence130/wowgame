@echo off
call E:\wowgame\tools\run_gen.bat vale tidewind
copy /y %TEMP%\wow_gen_log.txt %TEMP%\wow_gen_merge.txt >nul
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
"%G%" --headless --path E:\wowgame res://tests/check.tscn > %TEMP%\wow_check.txt 2>&1
echo CHECK_DONE >> %TEMP%\wow_check.txt
