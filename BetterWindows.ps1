<#
.SYNOPSIS
    A windows powershell script to tweak and optimize Windows 11 

.DESCRIPTION
    Better Windows aims to tweak certain windows settings and components to enhance privacy
    and optimize unnecessary background services and tasks.
    This script is intended to run on Windows 11 Iot Enterprise LTSC or equivalent editions
    that has minimal bloatare as it currently DOES NOT debloats like some other utilities do.
	
.EXAMPLE
    Run this script in powershell by simply executing it "BetterWiindows.ps1" or,
    Right click on the script and select "Run in powershell"

.NOTES
    Author: HardcodeCoder
    Created: 03 Jan 2025
    Last Modified: 17 Jan 2025
    Version: 1.0.0
    Required Modules: PowerShell Remoting

.LINK
    https://docs.microsoft.com/en-us/powershell/
#>


# Source Utils
. .\Utils.ps1

# Config file path
$RegistryConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "config\tweaks.reg"
$ServiceConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "config\services.json"
$TaskConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "config\tasks.json"

# Global temporary working directory
$WorkingDir = Join-Path -Path $env:TEMP -ChildPath "BetterWindows"


# Show Better Windows main menu
function Show-MainMenu {
    Clear-Host

    Write-CenteredText " ____       _   _             __        __            _                   " -ForegroundColor Green
    Write-CenteredText "| __ )  ___| |_| |_ ___ _ _   \ \      / (_)_ __   __| | _____      _____ " -ForegroundColor Green
    Write-CenteredText "|  _ \ / _ \ __| __/ _ \  __\  \ \ /\ / /| |  _  \/ _  |/ _ \ \ /\ / / __/" -ForegroundColor Green
    Write-CenteredText "| |_) |  __/ |_| ||  __/ |      \ V  V / | | | | | (_| | (_) \ V  V /\__ \" -ForegroundColor Green
    Write-CenteredText "|____/ \___|\__|\__\___|_|       \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/ |___/" -ForegroundColor Green
    Write-Host ""
	
    Write-CenteredText "Warning: This script is intended for Windows 11 Iot Enterprise or equivalent edition" -ForegroundColor Yellow
    Write-Host ""

    Write-CenteredText "========================================================" -ForegroundColor Cyan
    Write-CenteredText "Select one of the options below" -ForegroundColor Cyan
    Write-CenteredText "========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-CenteredText "Tweaks and optimizations                         Software and packages                    "
    Write-CenteredText "------------------------                         ---------------------                    "
    Write-CenteredText "[1] Apply ALL tweaks (2-6)                       [a] Install Graphics Driver              "
    Write-CenteredText "[2] Apply only REGISTRY tweaks                   [b] Install Chromium browser             "
    Write-CenteredText "[3] Apply only SERVIICE tweaks                   [c] Install Windows Terminal app         "
    Write-CenteredText "[4] Apply only SCHEDULED TASK tweaks             [d] Install Office (Pro Plus 2024)       "
    Write-CenteredText "[5] Perform System cleanup                       [e] Install Winget                       "
    Write-CenteredText "[6] Disable Windows Defender                                                              "
    Write-Host ""
}

# Apply all recommended tweaks
function Invoke-AllTweaks {
    param (
        [string]$RegistryConfig,
        [string]$ServiceConfig,
        [string]$TaskConfig
    )

    Write-TaskHeader "Making your Windows Better"

    try {
        Write-Host "Disabling hibernation"
        powercfg.exe /hibernate off

        Write-Host "Setting legacy boot menu policy"
        bcdedit /set "{current}" bootmenupolicy Legacy | Out-Null

        $ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1kb

        Write-Host "Setting 'SvcHostSplitThresholdInKB' to availablle RAM: $ram"
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\" -Name "SvcHostSplitThresholdInKB" -Value $ram -Type DWord -Force

        Write-Host "Disabling AutoLogger and denying system access"
        $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger\"
        If (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl\") {
            Remove-Item "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl\"
        }
        icacls $autoLoggerDir /deny "SYSTEM:(OI)(CI)F" | Out-Null

        Write-Host "Disable Windows Defender automatic sample submission"
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue | Out-Null
        Write-Host ""

        Invoke-RegistryTweak -Config $RegistryConfig

        Invoke-ServiceTweak -Config $ServiceConfig

        Invoke-TaskTweak -Config $TaskConfig

        Disable-WindowsDefender

        Invoke-SystemCleaner
    }
    catch {
        Write-UnhandledException -Description "Failed to apply all tweaks" -Exception $_.Exception
    }

    Write-Host ""
}

# Apply registry settings from config file
function Invoke-RegistryTweak {
    param (
        [string]$Config
    )

    Write-Host "Applying registry tweaks from: $Config" -ForegroundColor Cyan

    Start-Process regedit.exe -ArgumentList "/S $Config" -Wait
    Write-Host "Success"

    Write-Host ""
}

# Configure services to recommended startup type
function Invoke-ServiceTweak {
    param (
        [string]$Config
    )

    Write-Host "Applying service configurations from: $Config" -ForegroundColor Cyan

    try {
        $serviceConfigs = ConvertFrom-JsonFie -Path $Config
        $servicesRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

        if ($null -eq $serviceConfigs) {
            Write-Warning "No service configuration found in $Config"
            return
        }

        foreach ($serviceConfig in $serviceConfigs) {
            Write-Host "Set service: $($serviceConfig.Name), Startup = $($serviceConfig.Start)"

            $service = Join-Path -Path $servicesRegistryPath -ChildPath $serviceConfig.Name
            $start = if ($serviceConfig.Start -eq 5) { 2 } else { $serviceConfig.Start }

            if (!(Test-Path -Path $service)) {
                continue
            }

            Set-ItemProperty -Path $service -Name "Start" -Value $start  -Type DWord -ErrorAction SilentlyContinue

            if ($serviceConfig.Start -eq 5) {
                Set-ItemProperty -Path $service -Name "DelayedAutoStart" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                continue
            }

            $delayAutoStart = Get-ItemProperty -Path $service -Name "DelayedAutoStart" -ErrorAction SilentlyContinue
            if ($null -ne $delayAutoStart) {
                Set-ItemProperty -Path $service -Name "DelayedAutoStart" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-UnhandledException -Description "Failed to set services" -Exception $_.Exception
    }

    Write-Host ""
}

# Configure schedule taks to recommended settiings
function Invoke-TaskTweak {
    param (
        [string]$Config
    )

    Write-Host "Applying schedule task configurations from: $Config" -ForegroundColor Cyan

    try {
        $tasks = ConvertFrom-JsonFie -Path $Config

        if ($null -eq $tasks) {
            Write-Warning "No schedule task found in: $Config"
            return
        }

        foreach ($task in $tasks) {
            Write-Host "Set: $($task.Name), Active = $($task.Active)"

            if ($task.Active) {
                Enable-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue | Out-Null
            }
            else {
                Disable-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    catch {
        Write-UnhandledException -Description "Failed to set schedule task" -Exception $_.Exception
    }

    Write-Host ""
}

# Perform sytem cleanup
function Invoke-SystemCleaner {
    try {
        Write-TaskHeader "Perform System Cleanup"

        Write-Host "Deleting temp files and caches"
        Start-Process -FilePath cleanmgr.exe -ArgumentList "/d C: /verylowdisk" -Wait
        Get-ChildItem -Path "$env:TEMP" -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path "C:\Windows\Temp\*" -Recurse -ErrorAction Ignore | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Performing component cleanup and base reset"
        Start-Process -FilePath Dism.exe -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait

        Write-Host "Completed"
    }
    catch {
        Write-UnhandledException -Description "Failed to complete system cleanup" -Exception $_.Exception
    }

    Write-Host ""
}

# Disable Windows Defender
function Disable-WindowsDefender {
    Write-TaskHeader "Disable Windows Defender"

    Invoke-RegistryTweak -Config $(Join-Path -Path $PSScriptRoot -ChildPath "config\defender\tweaks.reg")
    Invoke-ServiceTweak -Config $(Join-Path -Path $PSScriptRoot -ChildPath "config\defender\services.json")
    Invoke-TaskTweak -Config $(Join-Path -Path $PSScriptRoot -ChildPath "config\defender\tasks.json")

    Write-Host "Successfully disabled Windows Defender"
    Write-Host "Reboot system for changes to take effect"
    Write-Host ""
}

# Install Intel Graphics driver
function Install-GraphicsDriver {
    Write-TaskHeader "Download and install Intel Graphics Driver"

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

    Write-Host ""
}

# Install Chromium browser
function Install-Chromium {
    Write-TaskHeader "Download and install Chromium"

    try {
        $installer = Join-Path -Path $WorkingDir -ChildPath "mini_installer.sync.exe"
        Invoke-FileDownload -Uri "https://github.com/Hibbiki/chromium-win64/releases/latest/download/mini_installer.sync.exe" -OutFile $installer

        Write-Host "Installing for all users"
        Start-Process -FilePath $installer -ArgumentList "--system-level" -WindowStyle Hidden -Wait
        Write-Host "Successfully installed chromium"
    }
    catch {
        Write-UnhandledException -Description "Failed to install Chromium" -Exception $_.Exception
    }

    Write-Host ""
}

# Installl windows terminal
function Install-WindowsTerminal {
    Write-TaskHeader "Download and install Windows Terminal"

    try {
        Write-Host "Fetching latest (stable) release from: https://github.com/microsoft/terminal/releases/latest"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/terminal/releases/latest"

        $asset = $response.Assets | Where-Object { $_.Name.EndsWith("8wekyb3d8bbwe.msixbundle") }

        if ($null -eq $asset) {
            Write-Warning "Did not find '*.msixbundle' package in release"
        }
        else {
            $installer = Join-Path -Path $WorkingDir -ChildPath $asset.Name

            Write-Host "Asset found: $($asset.Name), Size = $($asset.Size)"
            Invoke-FileDownload -Uri $asset.Browser_Download_Url -OutFile $installer

            Write-Host "Installing..."
            Add-AppxPackage -Path $installer

            Write-Host "Successfully installed Windows Terminal"
        }
    }
    catch {
        Write-UnhandledException -Description "Failed to install Windows Terminal" -Exception $_.Exception
    }

    Write-Host ""
}

# Install Office Professional Plus 2024
function Install-Office {
    param (
        [string]$Config
    )

    Write-TaskHeader "Install Office Pro Plus 2024"

    try {
        Write-Host "Downloading setup files"
        $setupFile = Join-Path -Path $WorkingDir -ChildPath "setup.exe"
        Invoke-FileDownload -Uri "https://officecdn.microsoft.com/pr/wsus/setup.exe" -OutFile $setupFile

        Write-Host "Installing using configuration: $Config"
        Start-Process -FilePath $setupFile -ArgumentList "/configure $Config" -Wait
        Write-Host "Successfully installed office"
    }
    catch {
        Write-UnhandledException -Description "Office installation faied" -Exception $_.Exception
    }

    Write-Host ""
}

# Install Winget
function Install-Winget {
    Write-TaskHeader "Install Winget"

    try {
        $downloadDir = Join-Path -Path $WorkingDir -ChildPath "winget"

        Write-Host "Fetching latest release"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        Write-Host ""

        Write-Host "Downloading assets"
        foreach ($asset in $response.Assets) {
            Write-Host "Name: $($asset.Name), Size: $($asset.Size)"

            Invoke-FileDownload -Uri $asset.Browser_Download_Url -OutFile $(Join-Path -Path $downloadDir -ChildPath $asset.Name)
            Write-Host ""
        }

        $dependenciesZip = Get-ChildItem -Path $downloadDir -Filter *Dependencies.zip | ForEach-Object -MemberName FullName
        $dependenciesDir = Join-Path -Path $downloadDir -ChildPath "dependencies"

        Write-Host "Extracting and installing dependencies"
        Expand-Archive -Path $dependenciesZip -DestinationPath $dependenciesDir -Force

        $dependencies = Join-Path -Path $dependenciesDir -ChildPath "x64" | Get-ChildItem | ForEach-Object -MemberName FullName
        foreach ($dependency in $dependencies) {
            Add-AppxPackage -Path $dependency
        }

        Write-Host "Installing winget"
        $wingetBundle = Get-ChildItem -Path $downloadDir -Filter *8wekyb3d8bbwe.msixbundle | ForEach-Object -MemberName FullName
        Add-AppxPackage -Path $wingetBundle

        Write-Host "Configuring license"
        $license = Get-ChildItem -Path $downloadDir -Filter *License1.xml | ForEach-Object -MemberName FullName
        Add-AppxProvisionedPackage -Online -PackagePath $wingetBundle -LicensePath $license

        Write-Host "Sucessfully installed winget ($(winget.exe -v))"
    }
    catch {
        Write-UnhandledException -Description "Failed to install Winget" -Exception $_.Exception
    }

    Write-Host ""
}

# Cleanup working directory
function Remove-WorkingDir {
    if (Test-Path -Path $WorkingDir) {
        Get-ChildItem -Path $WorkingDir -Recurse | Remove-Item -Recurse -Force
        Remove-Item -Path $WorkingDir -Force
    }
}

# Run as administrator if not in admin role
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process powershell.exe -ArgumentList ("-NoProfile -NoExit -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -WindowStyle Maximized
        Exit
    }
    catch {
        Write-Warning "Failed to run as Administrator. Please rerun with elevated privileges."
        Read-Host "Press any key to exit."
        Exit
    }
}

Initialize-PowershellWindow
$ProgressPreference = 'SilentlyContinue'
$choice = ''

:menu
while ($choice -ne 'q') {
    Show-MainMenu

    $choice = Read-Host -Prompt "Enter your selection (default 1)"
    Write-Host ""

    switch ($choice) {
        "1" { Invoke-AllTweaks -RegistryConfig $RegistryConfigFile -ServiceConfig $ServiceConfigFile -TaskConfig $TaskConfigFile }
        "2" { Invoke-RegistryTweak -Config $RegistryConfigFile }
        "3" { Invoke-ServiceTweak -Config $ServiceConfigFile }
        "4" { Invoke-TaskTweak -Config $TaskConfigFile }
        "5" { Invoke-SystemCleaner }
        "6" { Disable-WindowsDefender }
        "a" { Install-GraphicsDriver }
        "b" { Install-Chromium }
        "c" { Install-WindowsTerminal }
        "d" { Install-Office -Config $(Join-Path -Path $PSScriptRoot -ChildPath "config\office\Configuration.xml") }
        "e" { Install-Winget }
        "q" { break menu }
        Default {
            $choice = "0"
            Write-Host "Invalid selection"
            Read-Host -Prompt "Press any key to continue"
        }
    }

    if ($choice -eq "0") {
        continue
    }

    Write-TaskFooter
    Write-Host "All tasks completed"
    Read-Host -Prompt "Press any key to continue."
}

Remove-WorkingDir
$ProgressPreference = 'Continue'

Write-Host "Good Bye!!!"
Exit