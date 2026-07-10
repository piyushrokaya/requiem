@echo off
title Sanksep Dev Launcher

echo ================================
echo Starting Sanksep Backend + Ngrok
echo ================================

REM Move to backend folder
cd backen

echo.
echo Starting Node server...
start cmd /k "node server.js"

timeout /t 3 >nul

echo.
echo Starting ngrok tunnel...
start cmd /k "ngrok http 5000"

timeout /t 5 >nul

echo.
echo Waiting for ngrok URL...
timeout /t 5 >nul

echo.
echo ================================
echo Copy the https ngrok URL
echo Generate QR from:
echo https://www.qr-code-generator.com/
echo ================================

pause