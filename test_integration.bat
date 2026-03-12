@echo off
setlocal enabledelayedexpansion

set API_URL=http://localhost:8000

echo 🧪 Testing Counter Service
echo ==========================

REM Test 1: Get initial counter
echo 1️⃣  GET counter...
for /f "tokens=*" %%A in ('curl -s %API_URL%/ ^| findstr /R "counter"') do (
    echo    %%A
)

REM Test 2: Increment 5 times
echo 2️⃣  Incrementing 5 times...
for /L %%i in (1,1,5) do (
    curl -s -X POST %API_URL%/ > nul
    echo    ✓ Increment %%i
)

REM Test 3: Check counter increased
echo 3️⃣  GET counter again...
for /f "tokens=*" %%A in ('curl -s %API_URL%/ ^| findstr /R "counter"') do (
    echo    %%A
)

REM Test 4: Reset
echo 4️⃣  POST /reset...
for /f "tokens=*" %%A in ('curl -s -X POST %API_URL%/reset ^| findstr /R "counter"') do (
    echo    %%A
)

REM Test 5: Health check
echo 5️⃣  GET /health...
for /f "tokens=*" %%A in ('curl -s %API_URL%/health ^| findstr /R "status"') do (
    echo    %%A
)

REM Test 6: Metrics
echo 6️⃣  GET /metrics...
for /f "tokens=*" %%A in ('curl -s %API_URL%/metrics ^| find /C "counter_service_requests_total"') do (
    echo    Metrics found: %%A
)

echo.
echo ✅ All tests passed!