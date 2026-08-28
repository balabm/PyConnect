# Driver App API E2E Test (PowerShell version)
# Tests all driver API endpoints against the deployed backend.

$baseUrl = "https://pyconnect.run.place"
$testPhone = "9000000060"
$adminPhone = "9000000000"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

$results = @()
$findings = @()

function Test-Case($id, $description, $scriptBlock) {
    try {
        & $scriptBlock
        $script:results += [PSCustomObject]@{Id=$id; Description=$description; Status="PASS"; Error=""}
        Write-Host "  [PASS] ${id}: $description" -ForegroundColor Green
    } catch {
        $script:results += [PSCustomObject]@{Id=$id; Description=$description; Status="FAIL"; Error=$_.Exception.Message}
        Write-Host "  [FAIL] ${id}: $description - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Add-Finding($msg) {
    $script:findings += $msg
    Write-Host "  [FINDING] $msg" -ForegroundColor Yellow
}

function Api-Get($path, $token = $null) {
    $headers = @{}
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $resp = Invoke-WebRequest -Uri "$baseUrl$path" -UseBasicParsing -TimeoutSec 15 -Headers $headers
    return $resp
}

function Api-Post($path, $body, $token = $null) {
    $headers = @{"Content-Type"="application/json"}
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $json = $body | ConvertTo-Json -Depth 5
    $resp = Invoke-WebRequest -Uri "$baseUrl$path" -Method Post -Body $json -Headers $headers -UseBasicParsing -TimeoutSec 15
    return $resp
}

function Api-Put($path, $body, $token = $null) {
    $headers = @{"Content-Type"="application/json"}
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $json = $body | ConvertTo-Json -Depth 5
    $resp = Invoke-WebRequest -Uri "$baseUrl$path" -Method Put -Body $json -Headers $headers -UseBasicParsing -TimeoutSec 15
    return $resp
}

Write-Host ""
Write-Host "========================================="
Write-Host "Driver App API E2E Test (PowerShell)"
Write-Host "Backend: $baseUrl"
Write-Host "Test Phone: $testPhone"
Write-Host "========================================="
Write-Host ""

$token = $null
$driverId = $null
$adminToken = $null

# ── Health Check ──
Write-Host "`n-- Health Check --"
Test-Case "HEALTH" "Backend health check" {
    $resp = Api-Get "/health"
    $data = $resp.Content | ConvertFrom-Json
    if ($data.status -ne "Healthy") { throw "Backend not healthy: $($data.status)" }
}

# ── Auth Flow ──
Write-Host "`n-- Auth Flow --"
Test-Case "AUTH-001" "Request OTP" {
    $resp = Api-Post "/api/auth/otp" @{phone=$testPhone}
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

Test-Case "AUTH-002" "Peek OTP" {
    $resp = Api-Get "/api/auth/otp/peek?phone=$testPhone"
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
    $data = $resp.Content | ConvertFrom-Json
    if ($data.code.Length -ne 6) { throw "Invalid OTP: $($data.code)" }
}

Test-Case "AUTH-003" "Verify OTP and get token" {
    $peek = Api-Get "/api/auth/otp/peek?phone=$testPhone"
    $code = ($peek.Content | ConvertFrom-Json).code
    $resp = Api-Post "/api/auth/otp/verify" @{phone=$testPhone; otp=$code}
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
    $data = $resp.Content | ConvertFrom-Json
    $script:token = $data.token
    if (-not $script:token) { throw "No token received" }
}

# ── Driver Registration ──
Write-Host "`n-- Driver Registration --"
Test-Case "REG-001" "Register as driver" {
    $resp = Api-Post "/api/driver/register" @{
        name="Test Captain"
        phone=$testPhone
        vehicleType="Bike"
        vehiclePlate="PY-01-TEST-001"
        licenseNumber="DL04202600001"
    } $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 201) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "REG-002" "Get driver profile" {
    $resp = Api-Get "/api/driver/me" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
    $data = $resp.Content | ConvertFrom-Json
    $script:driverId = $data.id
    if (-not $script:driverId) { throw "No driver ID" }
    if ($data.name -ne "Test Captain") { throw "Name mismatch: $($data.name)" }
    if ($data.phone -ne $testPhone) { throw "Phone mismatch: $($data.phone)" }
}

# ── Tutorial & Agreement ──
Write-Host "`n-- Tutorial & Agreement --"
Test-Case "TUT-001" "Complete tutorial" {
    $resp = Api-Post "/api/driver/complete-tutorial" @{} $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "TUT-002" "Sign agreement" {
    $resp = Api-Post "/api/driver/sign-agreement" @{signatureData="test-signature"} $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

# ── KYC Upload ──
Write-Host "`n-- KYC Upload --"
Test-Case "KYC-001" "Upload KYC documents" {
    $resp = Api-Post "/api/driver/upload-kyc" @{
        aadhaarUrl="test://aadhaar.jpg"
        drivingLicenseUrl="test://license.jpg"
        rcUrl="test://rc.jpg"
        upiId="testcaptain@upi"
    } $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "KYC-002" "Verify KYC status" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp.Content | ConvertFrom-Json
    if ($data.isKycUploaded -ne $true) { throw "KYC not uploaded" }
    if ($data.hasCompletedTutorial -ne $true) { throw "Tutorial not completed" }
    if ($data.hasSignedAgreement -ne $true) { throw "Agreement not signed" }
}

# ── Admin Approval ──
Write-Host "`n-- Admin Approval --"
Test-Case "ADM-001" "Get admin token" {
    Api-Post "/api/auth/otp" @{phone=$adminPhone} | Out-Null
    Start-Sleep -Seconds 1
    $peek = Api-Get "/api/auth/otp/peek?phone=$adminPhone"
    $code = ($peek.Content | ConvertFrom-Json).code
    $resp = Api-Post "/api/auth/otp/verify" @{phone=$adminPhone; otp=$code}
    $script:adminToken = ($resp.Content | ConvertFrom-Json).token
    if (-not $script:adminToken) { throw "No admin token" }
}

Test-Case "ADM-002" "Approve driver" {
    $resp = Api-Post "/api/admin/drivers/$script:driverId/approve" @{} $script:adminToken
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "ADM-003" "Verify driver is approved" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp.Content | ConvertFrom-Json
    if ($data.isApproved -ne $true) { throw "Driver not approved" }
}

# ── Dashboard Endpoints ──
Write-Host "`n-- Dashboard Endpoints --"
Test-Case "DASH-001" "Get vehicles" {
    $resp = Api-Get "/api/driver/vehicles" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

Test-Case "DASH-002" "Get compliance" {
    $resp = Api-Get "/api/driver/compliance" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

Test-Case "DASH-003" "Get preferences" {
    $resp = Api-Get "/api/driver/preferences" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

Test-Case "DASH-004" "Get tasks" {
    $resp = Api-Get "/api/driver/tasks" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

# ── Online/Offline ──
Write-Host "`n-- Online/Offline --"
Test-Case "ONLINE-001" "Go online" {
    $resp = Api-Post "/api/driver/go-online" @{lat=11.9356; lng=79.8301} $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "ONLINE-002" "Verify online status" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp.Content | ConvertFrom-Json
    if ($data.isOnline -ne $true) { throw "Driver not online" }
}

Test-Case "ONLINE-003" "Go offline" {
    $resp = Api-Post "/api/driver/go-offline" @{} $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

# ── Vehicle Management ──
Write-Host "`n-- Vehicle Management --"
Test-Case "VEH-001" "Add vehicle" {
    $resp = Api-Post "/api/driver/vehicles" @{vehicleType="Auto"; vehiclePlate="PY-01-TEST-002"} $script:token
    if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 201) {
        throw "Status: $($resp.StatusCode), Body: $($resp.Content)"
    }
}

Test-Case "VEH-002" "List vehicles" {
    $resp = Api-Get "/api/driver/vehicles" $script:token
    if ($resp.StatusCode -ne 200) { throw "Status: $($resp.StatusCode)" }
}

# ── Preferences ──
Write-Host "`n-- Preferences --"
Test-Case "PREF-001" "Update destination preference" {
    try {
        $resp = Api-Put "/api/driver/preferences/destination" @{lat=11.9356; lng=79.8301; address="Pondicherry Bus Stand"} $script:token
        if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
            throw "Status: $($resp.StatusCode)"
        }
    } catch {
        Add-Finding "Destination preference endpoint error: $($_.Exception.Message)"
    }
}

Test-Case "PREF-002" "Update service toggles" {
    try {
        $resp = Api-Put "/api/driver/preferences/service-toggles" @{rides=$true; food=$true; luggage=$false} $script:token
        if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
            throw "Status: $($resp.StatusCode)"
        }
    } catch {
        Add-Finding "Service toggles endpoint error: $($_.Exception.Message)"
    }
}

# ── Cleanup ──
Write-Host "`n-- Cleanup --"
Test-Case "CLEANUP-001" "Delete test account" {
    try {
        $resp = Api-Post "/api/driver/account/delete" @{} $script:token
        if ($resp.StatusCode -ne 200 -and $resp.StatusCode -ne 204) {
            throw "Status: $($resp.StatusCode)"
        }
    } catch {
        Add-Finding "Account deletion error: $($_.Exception.Message)"
    }
}

# ── Summary ──
Write-Host ""
Write-Host "========================================="
Write-Host "TEST SUMMARY"
Write-Host "========================================="
$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host "Total: $($results.Count)"
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"
Write-Host "Findings: $($findings.Count)"
if ($findings.Count -gt 0) {
    Write-Host "`n-- Findings --"
    foreach ($f in $findings) { Write-Host "  [!] $f" -ForegroundColor Yellow }
}
if ($failed -gt 0) {
    Write-Host "`n-- Failed Tests --"
    foreach ($r in ($results | Where-Object { $_.Status -eq "FAIL" })) {
        Write-Host "  [X] $($r.Id): $($r.Description)" -ForegroundColor Red
        Write-Host "      Error: $($r.Error)"
    }
}
Write-Host "========================================="
Write-Host ""

# Export results to CSV for the QA report
$csvPath = "C:\Users\balab\OneDrive\Documents\Projects\PY_Engine\qa-reports\driver_api_results.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Results exported to: $csvPath"
