# Automated End-to-End API Test Script for Indexsafe Evolution Backend
$baseUrl = "http://localhost:5200"
$ErrorActionPreference = "Stop"

function Log-Result($name, $status, $details) {
    if ($status) {
        Write-Host " [PASS] $name" -ForegroundColor Green
        if ($details) { Write-Host "        $details" -ForegroundColor DarkGray }
    } else {
        Write-Host " [FAIL] $name" -ForegroundColor Red
        if ($details) { Write-Host "        $details" -ForegroundColor Yellow }
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   TESTING INDEXSAFE EVOLUTION BACKEND ENDPOINTS         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Test Dashboard UI
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/" -Method Get -TimeoutSec 5
    Log-Result "Dashboard UI (GET /)" ($res -match "INDEXSAFE EVOLUTION") "Dashboard HTML served successfully"
} catch {
    Log-Result "Dashboard UI (GET /)" $false $_.Message
}

# 2. Test OpenAPI Documentation
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/openapi/v1.json" -Method Get -TimeoutSec 5
    Log-Result "OpenAPI Spec (GET /openapi/v1.json)" ($res.openapi -ne $null) "Version: $($res.openapi), Title: $($res.info.title)"
} catch {
    Log-Result "OpenAPI Spec" $false $_.Message
}

# 3. Test System Monitor Telemetry
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/system/monitor" -Method Get -TimeoutSec 5
    Log-Result "System Telemetry (GET /api/system/monitor)" ($res.stats.databaseConnected -eq $true) "DB: $($res.stats.databaseName) on $($res.stats.databaseServer) (Connected: $($res.stats.databaseConnected))"
} catch {
    Log-Result "System Telemetry (GET /api/system/monitor)" $false $_.Message
}

# 4. Test Login (NIK: 0002)
$token = ""
$currentPassword = "PasswordBaru123!" # Check if already changed or default 770403
try {
    $loginBody = @{ nik = "0002"; password = "PasswordBaru123!" } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $loginBody -ContentType "application/json"
        $currentPassword = "PasswordBaru123!"
    } catch {
        $loginBody = @{ nik = "0002"; password = "PasswordBaru77!" } | ConvertTo-Json
        try {
            $res = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $loginBody -ContentType "application/json"
            $currentPassword = "PasswordBaru77!"
        } catch {
            $loginBody = @{ nik = "0002"; password = "PasswordBaru99!" } | ConvertTo-Json
            try {
                $res = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $loginBody -ContentType "application/json"
                $currentPassword = "PasswordBaru99!"
            } catch {
                $loginBody = @{ nik = "0002"; password = "PasswordBaru456!" } | ConvertTo-Json
                try {
                    $res = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $loginBody -ContentType "application/json"
                    $currentPassword = "PasswordBaru456!"
                } catch {
                    $loginBody = @{ nik = "0002"; password = "770403" } | ConvertTo-Json
                    $res = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $loginBody -ContentType "application/json"
                    $currentPassword = "770403"
                }
            }
        }
    }

    $token = $res.token
    Log-Result "Auth Login (POST /api/login)" (![string]::IsNullOrEmpty($token)) "User: $($res.user.name), Role: $($res.user.role), Company: $($res.user.company) (Password: $currentPassword)"
} catch {
    Log-Result "Auth Login (POST /api/login)" $false $_.Message
}

$headers = @{
    "Authorization" = "Bearer $token"
}

# 5. Test Profile (GET /api/profile)
try {
    $res = Invoke-RestMethod -Uri "$baseUrl/api/profile" -Method Get -Headers $headers -TimeoutSec 5
    Log-Result "Get Profile (GET /api/profile)" ($res.no_nik -eq "0002") "NIK: $($res.no_nik), Nama: $($res.nama_lengkap), Posisi: $($res.posisi)"
} catch {
    Log-Result "Get Profile (GET /api/profile)" $false $_.Message
}

# 6. Test Change Password (POST /api/change-password) - Negative Test (wrong old password)
try {
    $badReq = @{
        old_password = "wrongpassword"
        new_password = "NewPassword123!"
        new_password_confirmation = "NewPassword123!"
    } | ConvertTo-Json
    
    $failedCorrectly = $false
    try {
        $null = Invoke-RestMethod -Uri "$baseUrl/api/change-password" -Method Post -Body $badReq -Headers $headers -ContentType "application/json"
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            $failedCorrectly = $true
        }
    }
    Log-Result "Change Password Validation (Wrong Old Password)" $failedCorrectly "Rejected with 400 Bad Request as expected"
} catch {
    Log-Result "Change Password Validation" $false $_.Message
}

# 7. Test Change Password (POST /api/change-password) - Positive Test
$tempNewPassword = "PasswordBaru99!"
try {
    $changeReq = @{
        old_password = $currentPassword
        new_password = $tempNewPassword
        new_password_confirmation = $tempNewPassword
    } | ConvertTo-Json

    $res = Invoke-RestMethod -Uri "$baseUrl/api/change-password" -Method Post -Body $changeReq -Headers $headers -ContentType "application/json"
    Log-Result "Change Password (POST /api/change-password)" ($res.message -match "berhasil") "$($res.message)"

    # Verify logging in with the newly updated password
    $testLogin = @{ nik = "0002"; password = $tempNewPassword } | ConvertTo-Json
    $loginRes = Invoke-RestMethod -Uri "$baseUrl/api/login" -Method Post -Body $testLogin -ContentType "application/json"
    Log-Result "Re-login With New Password" (![string]::IsNullOrEmpty($loginRes.token)) "Successfully authenticated using changed password"

    # Revert back to original password
    $revertReq = @{
        old_password = $tempNewPassword
        new_password = $currentPassword
        new_password_confirmation = $currentPassword
    } | ConvertTo-Json
    $revertHeaders = @{ "Authorization" = "Bearer $($loginRes.token)" }
    $resRevert = Invoke-RestMethod -Uri "$baseUrl/api/change-password" -Method Post -Body $revertReq -Headers $revertHeaders -ContentType "application/json"
    Log-Result "Revert Password to Original" ($resRevert.message -match "berhasil") "Restored password for continuity"
} catch {
    Log-Result "Change Password Flow" $false $_.Message
}

# 8. Test Master Data Endpoints
try {
    $resAreas = Invoke-RestMethod -Uri "$baseUrl/api/master/areas" -Method Get -Headers $headers
    Log-Result "Master Areas (GET /api/master/areas)" ($resAreas.Count -gt 0) "Total areas fetched: $($resAreas.Count)"
} catch {
    Log-Result "Master Areas" $false $_.Message
}

try {
    $resCompanies = Invoke-RestMethod -Uri "$baseUrl/api/master/companies" -Method Get -Headers $headers
    Log-Result "Master Companies (GET /api/master/companies)" ($resCompanies.Count -gt 0) "Total companies: $($resCompanies.Count)"
} catch {
    Log-Result "Master Companies" $false $_.Message
}

try {
    $resHierarchy = Invoke-RestMethod -Uri "$baseUrl/api/hierarchy/companies" -Method Get -Headers $headers
    Log-Result "Company Hierarchy (GET /api/hierarchy/companies)" ($resHierarchy.Count -gt 0) "Scope companies: $($resHierarchy.Count)"
} catch {
    Log-Result "Company Hierarchy" $false $_.Message
}

# 9. Test QR Endpoints (Events list & History)
try {
    $resEvents = Invoke-RestMethod -Uri "$baseUrl/api/qr/events" -Method Get -Headers $headers
    Log-Result "Active Attendance Events (GET /api/qr/events)" ($resEvents.status -eq $true) "Events available: $($resEvents.data.Count)"
} catch {
    Log-Result "Active Attendance Events" $false $_.Message
}

try {
    $resHistory = Invoke-RestMethod -Uri "$baseUrl/api/qr/history" -Method Get -Headers $headers
    Log-Result "User Attendance History (GET /api/qr/history)" ($resHistory.status -eq $true) "History count: $($resHistory.data.Count)"
} catch {
    Log-Result "User Attendance History" $false $_.Message
}

# 10. Test QR Scan - Employee / Mine Permit Scan
try {
    $qrEmployeeReq = @{
        code = "0002"
        latitude = -0.142315
        longitude = 117.581290
        accuracy = 3.5
    } | ConvertTo-Json
    $resScanEmp = Invoke-RestMethod -Uri "$baseUrl/api/qr/scan" -Method Post -Body $qrEmployeeReq -Headers $headers -ContentType "application/json"
    Log-Result "QR Scan - Mine Permit / NIK (POST /api/qr/scan)" ($resScanEmp.actionType -eq "MinePermit") "Employee: $($resScanEmp.data.nama), Status: $($resScanEmp.data.status_aktif)"
} catch {
    Log-Result "QR Scan - Mine Permit" $false $_.Message
}

# 11. Test QR Scan - Mine Permit with Prefixed Format (INDEXIM:MP:0002)
try {
    $qrPrefixReq = @{
        code = "INDEXIM:MP:0002"
        latitude = -0.142315
        longitude = 117.581290
        accuracy = 4.0
    } | ConvertTo-Json
    $resScanPrefix = Invoke-RestMethod -Uri "$baseUrl/api/qr/scan" -Method Post -Body $qrPrefixReq -Headers $headers -ContentType "application/json"
    Log-Result "QR Scan - Prefix Format (INDEXIM:MP:0002)" ($resScanPrefix.actionType -eq "MinePermit") "Resolved: $($resScanPrefix.data.nama)"
} catch {
    Log-Result "QR Scan - Prefix Format" $false $_.Message
}

# 12. Test QR Scan - Event Attendance (or General QR fallback)
try {
    # If there are active events, test scanning its qr_token
    $testToken = "EVT-SAFETY-TALK-2026"
    if ($resEvents.data -and $resEvents.data.Count -gt 0) {
        $testToken = $resEvents.data[0].qr_token
    }
    $qrEventReq = @{
        code = $testToken
        latitude = -0.142315
        longitude = 117.581290
        accuracy = 2.1
    } | ConvertTo-Json
    $resScanEvt = Invoke-RestMethod -Uri "$baseUrl/api/qr/scan" -Method Post -Body $qrEventReq -Headers $headers -ContentType "application/json"
    Log-Result "QR Scan - Event / General (POST /api/qr/scan)" ($resScanEvt.status -eq $true) "Action: $($resScanEvt.actionType), Message: $($resScanEvt.message)"
} catch {
    Log-Result "QR Scan - Event / General" $false $_.Message
}

# 13. Test Offline Sync Transaction - Hazard Ingestion with GPS coordinates
try {
    $uniqueLocalId = [Guid]::NewGuid().ToString()
    $hazardPayload = @{
        local_id = $uniqueLocalId
        area = "Pit North"
        lokasi = "Loading Point B2"
        detil_lokasi = "Dekat tanggul overburden"
        temuan = "Dinding tanggul retak tergerus air hujan"
        kategori_hazard = "Kondisi Tidak Aman (KTA)"
        tingkat_bahaya = "Tinggi"
        tindakan_perbaikan = "Pasang safety barrier dan ratakan kembali dengan dozer"
        latitude = -0.142500
        longitude = 117.582100
        accuracy = 4.8
        date = (Get-Date).ToString("yyyy-MM-dd")
        time = (Get-Date).ToString("HH:mm:ss")
    } | ConvertTo-Json

    $resHazard = Invoke-RestMethod -Uri "$baseUrl/api/tran/hazard" -Method Post -Body $hazardPayload -Headers $headers -ContentType "application/json"
    Log-Result "Offline Sync Ingestion - Hazard with GPS (POST /api/tran/hazard)" ($resHazard.status -eq $true) "Server ID: $($resHazard.data.id), Code: $($resHazard.data.code), Message: $($resHazard.message)"
} catch {
    Log-Result "Offline Sync Ingestion - Hazard" $false $_.Message
}

# 14. Verify Live Monitor Records
try {
    $resMonitor = Invoke-RestMethod -Uri "$baseUrl/api/system/monitor" -Method Get -TimeoutSec 5
    $txCount = if ($resMonitor.transactions) { $resMonitor.transactions.Count } else { 0 }
    Log-Result "Live Monitor Real-time Verification" ($txCount -gt 0) "Dashboard recorded $txCount recent live transactions (DB Connected: $($resMonitor.stats.databaseConnected))"
} catch {
    Log-Result "Live Monitor Real-time Verification" $false $_.Message
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   TEST SUITE EXECUTION COMPLETE                         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
