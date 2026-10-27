@echo off
title Indexsafe Evolution - Backend API (Port 7302)
color 0A
echo ========================================================
echo        INDEXSAFE EVOLUTION - BACKEND REST API
echo ========================================================
echo.
echo Database: Server=172.16.1.93;Database=DB_SAP
echo API Endpoint: http://localhost:7302
echo API Docs (Scalar): http://localhost:7302/scalar/v1
echo.
echo Menjalankan Backend ASP.NET Core...
dotnet run --no-launch-profile
pause
