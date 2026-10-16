@echo off
rem Regress: script check -> feature tests (talents / reputation / mail / achievements) -> vale tour -> city services -> portal. Logs: %TEMP%\wow_reg_*.txt
set G=F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe
set P=E:\wowgame
"%G%" --headless --path %P% res://tests/check.tscn > %TEMP%\wow_reg_check.txt 2>&1
"%G%" --path %P% res://tests/talents.tscn > %TEMP%\wow_reg_talents.txt 2>&1
"%G%" --path %P% res://tests/reputation.tscn > %TEMP%\wow_reg_rep.txt 2>&1
"%G%" --path %P% res://tests/mail.tscn > %TEMP%\wow_reg_mail.txt 2>&1
"%G%" --path %P% res://tests/achiev.tscn > %TEMP%\wow_reg_achiev.txt 2>&1
"%G%" --path %P% res://tests/mounts.tscn > %TEMP%\wow_reg_mounts.txt 2>&1
"%G%" --path %P% res://tests/audio.tscn > %TEMP%\wow_reg_audio.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=tour zone=vale out=%P%/.shots/m2 > %TEMP%\wow_reg_tour.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=services out=%P%/.shots/services > %TEMP%\wow_reg_services.txt 2>&1
"%G%" --path %P% res://tests/autotest.tscn -- mode=portal out=%P%/.shots/portal > %TEMP%\wow_reg_portal.txt 2>&1
echo REG_DONE > %TEMP%\wow_reg_done.txt
