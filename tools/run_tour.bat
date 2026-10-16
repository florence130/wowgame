@echo off
rem Re-import, script check, then zone tour screenshots. Usage: tools\run_tour.bat <zone> <outdir-name> [extra args]
rem Writes log to %TEMP%\wow_tour_log.txt ; finishes with line TOUR_DONE
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
set L=%TEMP%\wow_tour_log.txt
echo START > %L%
"%G%" --headless --path %P% --import > %TEMP%\wow_imp.txt 2>&1
"%G%" --headless --path %P% res://tests/check.tscn >> %L% 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=tour zone=%1 out=%P%/.shots/%2 %3 %4 >> %L% 2>&1
echo TOUR_DONE >> %L%
