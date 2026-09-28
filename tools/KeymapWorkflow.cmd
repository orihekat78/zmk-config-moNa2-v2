@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KeymapWorkflow.ps1" -OpenEditor %*
pause
