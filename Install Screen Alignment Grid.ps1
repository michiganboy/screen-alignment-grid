$ErrorActionPreference = 'Stop'

$appName = 'Screen Alignment Grid'
$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Screen Alignment Grid'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Screen Alignment Grid'
$desktopDir = [Environment]::GetFolderPath('Desktop')
$iconPath = Join-Path $installDir 'assets\ScreenAlignmentGrid.ico'
$scriptPath = Join-Path $installDir 'ScreenAlignmentGrid.ps1'
$launcherPath = Join-Path $installDir 'Launch Screen Alignment Grid.vbs'
$uninstallPath = Join-Path $installDir 'Uninstall Screen Alignment Grid.cmd'

Write-Host "Installing $appName for the current user..."
Write-Host "Install location: $installDir"

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
New-Item -ItemType Directory -Force -Path $startMenuDir | Out-Null

$items = @(
    'ScreenAlignmentGrid.ps1',
    'Launch Screen Alignment Grid.vbs',
    'Run Screen Alignment Grid.cmd',
    'Create Desktop Shortcut.cmd',
    'Uninstall Screen Alignment Grid.cmd',
    'README.md'
)

foreach ($item in $items) {
    $src = Join-Path $sourceDir $item
    if (Test-Path $src) {
        Copy-Item -Force -Path $src -Destination $installDir
    }
}

$assetsSrc = Join-Path $sourceDir 'assets'
if (Test-Path $assetsSrc) {
    Copy-Item -Force -Recurse -Path $assetsSrc -Destination $installDir
}

function New-AppShortcut {
    param(
        [Parameter(Mandatory=$true)][string]$ShortcutPath,
        [Parameter(Mandatory=$true)][string]$TargetPath,
        [Parameter(Mandatory=$false)][string]$Arguments = '',
        [Parameter(Mandatory=$false)][string]$WorkingDirectory = '',
        [Parameter(Mandatory=$false)][string]$IconLocation = ''
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    if ($IconLocation -and (Test-Path ($IconLocation.Split(',')[0]))) { $shortcut.IconLocation = $IconLocation }
    $shortcut.Description = $appName
    $shortcut.Save()
}

$appArgs = '"' + $launcherPath + '"'
$appIcon = if (Test-Path $iconPath) { $iconPath } else { 'wscript.exe,0' }

New-AppShortcut `
    -ShortcutPath (Join-Path $desktopDir "$appName.lnk") `
    -TargetPath 'wscript.exe' `
    -Arguments $appArgs `
    -WorkingDirectory $installDir `
    -IconLocation $appIcon

New-AppShortcut `
    -ShortcutPath (Join-Path $startMenuDir "$appName.lnk") `
    -TargetPath 'wscript.exe' `
    -Arguments $appArgs `
    -WorkingDirectory $installDir `
    -IconLocation $appIcon

$oldUninstallShortcut = Join-Path $startMenuDir ("Uninstall " + $appName + ".lnk")
if (Test-Path $oldUninstallShortcut) {
    Remove-Item -Force $oldUninstallShortcut
}

Write-Host ''
Write-Host "$appName installed successfully."
$desktopShortcut = Join-Path $desktopDir ($appName + '.lnk')
Write-Host "Desktop shortcut: $desktopShortcut"
Write-Host "Start Menu folder: $startMenuDir"
Write-Host ''
Write-Host 'You can now launch it from the Desktop or Start Menu.'
