param(
  [string]$Out = ('E:\wowgame\assets\models\abbey_kit_v3\build_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
  [int]$Resolution = 1400,
  [string]$Preset = ''
)
$ErrorActionPreference = 'Stop'
$BlenderExe = 'E:\SteamLibrary\steamapps\common\Blender\blender.exe'
$SourceDir = $PSScriptRoot
if (Test-Path -LiteralPath $Out) { throw 'Choose a new output directory; existing builds are preserved.' }
New-Item -ItemType Directory -Path $Out | Out-Null
$BuildArguments = @('-b','--factory-startup','-t','10','--python-exit-code','1','--python',"$SourceDir\build_v3.py",'--','--out',$Out,'--res',"$Resolution")
if ($Preset) { $BuildArguments += @('--preset',$Preset) }
& $BlenderExe @BuildArguments
if ($LASTEXITCODE -ne 0) { throw 'Blender build failed.' }
& $BlenderExe -b --factory-startup -t 4 --python-exit-code 1 --python "$SourceDir\pipeline.py" -- --out "$Out\stages"
if ($LASTEXITCODE -ne 0) { throw 'Pipeline stage build failed.' }
& $BlenderExe -b --factory-startup -t 4 --python-exit-code 1 --python "$SourceDir\verify_tools.py" -- $Out
if ($LASTEXITCODE -ne 0) { throw 'Tool audit failed.' }
& $BlenderExe -b --factory-startup -t 4 --python-exit-code 1 --python "$SourceDir\verify_support.py" -- --blend "$Out\abbey_kit.blend"
if ($LASTEXITCODE -ne 0) { throw 'Support audit failed.' }
& $BlenderExe -b --factory-startup -t 4 --python-exit-code 1 --python "$SourceDir\..\abbey_kit_v2\check_palette.py" -- $Out
if ($LASTEXITCODE -ne 0) { throw 'Palette audit failed.' }
py -3 "$SourceDir\..\abbey_kit_v2\verify_exports.py" $Out --out "$Out\export_validation.json"
if ($LASTEXITCODE -ne 0) { throw 'Export audit failed.' }
py -3 "$SourceDir\verify_hierarchy.py" $Out
if ($LASTEXITCODE -ne 0) { throw 'GLB hierarchy audit failed.' }
py -3 "$SourceDir\verify_glass_exports.py" $Out
if ($LASTEXITCODE -ne 0) { throw 'Transparent glass export audit failed.' }
foreach ($Name in @('tool_validation','palette_validation','export_validation')) {
  $Report = Get-Content -LiteralPath "$Out\$Name.json" -Raw | ConvertFrom-Json
  if (-not $Report.passed) { throw "$Name contains failed checks." }
}
$SupportReport = Get-Content -LiteralPath "$Out\support_validation.json" -Raw | ConvertFrom-Json
if (-not $SupportReport.pass_check) { throw 'Support checks contain failures.' }
$StageReport = Get-Content -LiteralPath "$Out\stages\pipeline_routes.json" -Raw | ConvertFrom-Json
if (-not $StageReport.passed) { throw 'Stage geometry contains failures.' }
Write-Output "Candidate ready for visual review: $Out"
Write-Output 'Existing LATEST.json and the live Blender scene were not changed.'
