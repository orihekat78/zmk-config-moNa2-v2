@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0KeymapWorkflow.ps1" %*
pause
