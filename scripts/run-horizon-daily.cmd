@echo off
setlocal
cd /d "E:\code\Horizon"
if not exist "logs" mkdir "logs"
set PYTHONIOENCODING=utf-8
"C:\Users\52997\.local\bin\uv.exe" run horizon -l INFO >> "logs\horizon-daily.log" 2>&1
exit /b %ERRORLEVEL%
