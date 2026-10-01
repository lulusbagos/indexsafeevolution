@echo off
title Indexsafe Evolution - Backend API (Port 5200)
color 0A
echo ========================================================
echo        INDEXSAFE EVOLUTION - BACKEND REST API
echo ========================================================
echo.
echo Database: Server=172.16.1.93;Database=DB_SAP
echo API Endpoint: http://localhost:5200
echo API Docs (Scalar): http://localhost:5200/scalar/v1
echo.
echo Menjalankan Backend ASP.NET Core...
dotnet run --no-launch-profile
pause
