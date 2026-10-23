@echo off
title Closing Time
cd /d "%~dp0"
set PORT=8777
where python >nul 2>nul || (echo Python is not installed. Get it from https://www.python.org/downloads/ & pause & exit /b)
start "Closing Time server" /min python -m http.server %PORT% --bind 127.0.0.1
powershell -NoProfile -Command "for($i=0;$i -lt 40;$i++){try{Invoke-WebRequest -UseBasicParsing http://127.0.0.1:%PORT%/closing-time.html -TimeoutSec 1 | Out-Null; break}catch{Start-Sleep -Milliseconds 250}}"
start "" "http://127.0.0.1:%PORT%/closing-time.html"
