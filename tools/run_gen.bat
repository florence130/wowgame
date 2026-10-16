@echo off
rem Re-import + regenerate zones. Usage: tools\run_gen.bat [zones...]   log: %TEMP%\wow_gen_log.txt (ends with GEN_DONE)
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
set L=%TEMP%\wow_gen_log.txt
echo START > %L%
"%G%" --headless --path %P% --import > %TEMP%\wow_imp.txt 2>&1
"%G%" --headless --path %P% res://tools/gen.tscn -- %* >> %L% 2>&1
echo GEN_DONE >> %L%
