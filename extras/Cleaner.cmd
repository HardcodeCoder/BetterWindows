@echo off
echo Deleting temporary files...

:: Delete files in the Temp folder for the current user
rd "%temp%" /s /q

:: Delete files in the Windows Temp folder
rd "C:\Windows\Temp\" /s /q