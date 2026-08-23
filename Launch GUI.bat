@echo off
cd /d "%~dp0"
py BS2_Archipelago_Installer.py
if errorlevel 1 pause
