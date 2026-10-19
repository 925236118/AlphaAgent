param([string]$Godot = 'D:\软件安装程序\Godot\Godot_v4.5.2-stable_win64_console.exe')
# The initial isolated prototype has been replaced by production integration coverage.
& (Join-Path $PSScriptRoot '../plugin_settings/run.ps1') -Godot $Godot
exit $LASTEXITCODE