@echo off
cd /d "%~dp0"
start "Atualizar Semana" powershell.exe -NoLogo -NoExit -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar-semana.ps1"
