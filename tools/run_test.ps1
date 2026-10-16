# Re-import, run the script check, and only if it passes run an in-game autotest mode.
# (A parse error makes the game hang, so it must be caught first.)
# Usage: powershell -ExecutionPolicy Bypass -File tools\run_test.ps1 <mode>   (no mode = check only; "basic" = default smoke test)
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less files as ANSI and mangles non-ASCII text.
param([string]$mode = "", [int]$timeout = 540)
$g = "F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
$proj = "E:\wowgame"
$out = "$env:TEMP\wow_check_out.txt"; $err = "$env:TEMP\wow_check_err.txt"
# refresh global class cache (new class_name declarations are unknown until imported)
& $g --headless --path $proj --import *> "$env:TEMP\wow_imp.txt"
$p = Start-Process -FilePath $g -ArgumentList "--headless","--path",$proj,"res://tests/check.tscn" -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
if (-not $p.WaitForExit(240000)) { $p.Kill(); Write-Output "CHECK TIMEOUT"; exit 1 }
$lines = Get-Content $out, $err
$lines | Select-String "CHECKED|FAILED|Parse Error|Compile Error" | ForEach-Object { $_.Line }
if (-not ($lines | Select-String "failed 0")) { Write-Output "CHECK FAILED - skip game test"; exit 1 }
if ($mode -eq "") { exit 0 }
$args2 = @("--path", $proj, "res://tests/autotest.tscn", "--")
if ($mode -ne "basic") { $args2 += "mode=$mode" }
$args2 += "out=$proj/.shots/$mode"
$o2 = "$env:TEMP\wow_test_out.txt"; $e2 = "$env:TEMP\wow_test_err.txt"
$p2 = Start-Process -FilePath $g -ArgumentList $args2 -NoNewWindow -PassThru -RedirectStandardOutput $o2 -RedirectStandardError $e2
if (-not $p2.WaitForExit($timeout * 1000)) { $p2.Kill(); Write-Output "GAME TEST TIMEOUT ($timeout s)" }
Get-Content $o2, $e2 -Encoding UTF8 | Select-String "PASS|FAIL|RESULT|DONE|PORTAL|SCRIPT ERROR|HP |ERROR: (?!.*leaked|.*resources still)" | ForEach-Object { $_.Line }
