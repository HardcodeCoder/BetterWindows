<#
.SYNOPSIS
    Utility script for common helper functions

.DESCRIPTION
    PowerShell script to house common utility functions.
    This is meant to be sourced in other scripts and does not
    perform any task in itself
	
.EXAMPLE
    Source this file in other scripts using the "." notation - ". .\Utils.ps1"

.NOTES
    Author: HardcodeCoder
    Created: 19 May 2025
    Last Modified: 23 May 2025
    Version: 1.0.0
    Required Modules: PowerShell Remoting

.LINK
    https://docs.microsoft.com/en-us/powershell/
#>


# Global temporary working directory
$WorkingDir = Join-Path -Path $env:TEMP -ChildPath "BetterWindows"


# Invoke script as administrator
function Invoke-AsAdministrator {
    param (
        [string]$ScriptPath
    )

    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return
    }

    try {
        Start-Process powershell.exe -ArgumentList ("-NoProfile -NoExit -ExecutionPolicy Bypass -File `"{0}`"" -f $ScriptPath) -Verb RunAs -WindowStyle Maximized
        Exit
    }
    catch {
        Write-Warning "Failed to run as Administrator. Please rerun with elevated privileges."
        Read-Host "Press any key to exit."
        Exit
    }
}

# Initialize powershell window for administrator look
function Initialize-PowershellWindow {
    $Host.UI.RawUI.WindowTitle = "Better Windows - Administrator"
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.PrivateData.ProgressBackgroundColor = "Black"
    $Host.PrivateData.ProgressForegroundColor = "White"

    Clear-Host
}

# Write text to standard output but centered
function Write-CenteredText {
    param (
        [string]$Text,
        [string]$ForegroundColor = 'White'
    )

    $consoleWidth = [Console]::WindowWidth
    $padding = [math]::Floor(($consoleWidth - $Text.Length) / 2)
    $paddedText = ' ' * $padding + $Text

    Write-Host $paddedText -ForegroundColor $ForegroundColor
}

# Write current task header
function Write-TaskHeader {
    param (
        [string]$TaskName
    )

    $decorator = '-' * 62
    $text = ' ' * ((62 - $TaskName.Length) / 2) + $TaskName
    Write-Host $decorator
    Write-Host $text
    Write-Host $decorator
    Write-Host ""
}

# Write task footer divider
function Write-TaskFooter {
    $decorator = '-' * 62
    Write-Host $decorator
    Write-Host ""
}

# Write exception message as warning
function Write-UnhandledException {
    param (
        [string]$Description,
        [System.Exception]$Exception
    )

    Write-Warning "$Description - $($Exception.Message)"
    Write-Warning $Exception.StackTrace
}

# Deserialize json from file to powershell object
function ConvertFrom-JsonFie {
    param (
        [string]$Path
    )

    if ($Path -eq '' -Or !(Test-Path -Path $Path)) {
        Write-Host "File not found: $Path" -ForegroundColor Red
        return $null
    }

    $json = Get-Content -Path $Path -Raw
    return ConvertFrom-Json -InputObject $json
}

# Utility to download file silently to improve downlad speed
function Invoke-FileDownload {
    param (
        [string]$Uri,
        [string]$OutFile
    )

    try {
        $directory = Split-Path -Path $OutFile -Parent

        if (!(Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        Write-Host "Downloading: $Uri"
        Invoke-RestMethod -Uri $Uri -OutFile $OutFile
        Write-Host "Download location: $OutFile"
    }
    catch {
        Write-UnhandledException -Description "Unable to downlad file" -E $_.Exception
    }
}

# Cleanup working directory
function Remove-WorkingDir {
    if (Test-Path -Path $WorkingDir) {
        Get-ChildItem -Path $WorkingDir -Recurse | Remove-Item -Recurse -Force
        Remove-Item -Path $WorkingDir -Force
    }
}