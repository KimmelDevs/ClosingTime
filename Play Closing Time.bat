@echo off
cd /d "%~dp0"
start "Closing Time server" /min python -m http.server 8765
timeout /t 2 /nobreak >nul
start "" http://localhost:8765/closing-time.html
