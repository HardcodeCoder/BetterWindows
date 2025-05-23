# Source helper scripts
$UtilsScript = Join-Path -Path $PSScriptRoot -ChildPath "..\Utils.ps1"
. $UtilsScript

Invoke-AsAdministrator -ScriptPath $PSCommandPath
Initialize-PowershellWindow

$ProgressPreference = 'SilentlyContinue'

Write-TaskHeader "Download and install Intel Graphics Driver 2500"
try {
    $installerFile = Join-Path -Path $WorkingDir -ChildPath "win64_15.33.53.5161.exe"
    Invoke-FileDownload -Uri "https://downloadmirror.intel.com/29969/a08/win64_15.33.53.5161.exe" -OutFile $installerFile

    Write-Host "Installing..."
    Start-Process -FilePath $installerFile -ArgumentList "-s" -Wait
    Write-Host "Successfully installed graphics driver"
}
catch {
    Write-UnhandledException -Description "Failed to install graphics driver" -Exception $_.Exception
}

Remove-WorkingDir

$ProgressPreference = 'Continue'