param(
    [string]$Godot = 'D:\软件安装程序\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [switch]$UiOnly,
    [switch]$FilesOnly,
    [switch]$ResetOnly,
    [switch]$ContextOnly
)
$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testRoot = Join-Path $env:TEMP ('alphaagent-settings-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'addons') -Destination $testRoot -Recurse
$runnerDir = Join-Path $testRoot 'addons/settings_test_runner'
New-Item -ItemType Directory -Path $runnerDir | Out-Null
$utf8 = [System.Text.UTF8Encoding]::new($false)
$runnerFile = if ($ContextOnly) { 'context_runner.gd.txt' } elseif ($ResetOnly) { 'reset_runner.gd.txt' } elseif ($FilesOnly) { 'files_runner.gd.txt' } elseif ($UiOnly) { 'ui_runner.gd.txt' } else { 'runner.gd.txt' }
[System.IO.File]::WriteAllText((Join-Path $runnerDir 'runner.gd'), [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot $runnerFile)), $utf8)
[System.IO.File]::WriteAllText((Join-Path $runnerDir 'plugin.cfg'), "[plugin]`nname=`"SettingsTestRunner`"`ndescription=`"Isolated production integration tests`"`nauthor=`"AlphaAgent`"`nversion=`"1`"`nscript=`"runner.gd`"`n", $utf8)
$entryPath = Join-Path $testRoot 'addons/agent/agent.gd'
$entry = [System.IO.File]::ReadAllText($entryPath).Replace("`r`n", "`n")
# Change only configuration storage in the copied plugin; use the real production lifecycle and UI.
$entry = $entry.Replace("`t`tsetting_file =", "`t`tsetting_dir = OS.get_user_data_dir() + `"/config/`"`n`t`tsetting_file =")
[System.IO.File]::WriteAllText($entryPath, $entry, $utf8)
$projectPath = Join-Path $testRoot 'project.godot'
[System.IO.File]::WriteAllText($projectPath, "config_version=5`n[application]`nconfig/name=`"AlphaAgent Settings Test $([guid]::NewGuid().ToString('N'))`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $testRoot 'sample.gd'), "extends Node`n`nvar value := 1`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $testRoot 'sample.tscn'), "[gd_scene format=3]`n[node name=`"Sample`" type=`"Node`"]`n", $utf8)
Write-Output "Test directory: $testRoot"
& $Godot --headless --editor --path $testRoot --import --quit *> (Join-Path $testRoot 'import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -Path (Join-Path $testRoot 'import.log') -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) { throw "Import failed: $testRoot/import.log" }
[System.IO.File]::AppendAllText($projectPath, "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/settings_test_runner/plugin.cfg`")`n", $utf8)
& $Godot --headless --editor --path $testRoot --max-fps 60 --quit-after 4200 *> (Join-Path $testRoot 'run.log')
$testExitCode = $LASTEXITCODE
if (Test-Path (Join-Path $testRoot 'results.json')) {
    $summary = Get-Content -Raw -Encoding UTF8 (Join-Path $testRoot 'results.json') | ConvertFrom-Json
    $summary | Select-Object engine,checks,failed | Format-Table
    $summary.results | Where-Object { -not $_.passed } | Format-Table
    if ($summary.failed -gt 0) { $testExitCode = 1 }
} else {
    Get-Content -Encoding UTF8 (Join-Path $testRoot 'run.log') -Tail 60
    $testExitCode = 1
}
Write-Output "Godot exit code: $testExitCode"
exit $testExitCode
