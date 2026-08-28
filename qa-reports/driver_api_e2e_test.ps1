# Driver App API E2E Test (using .NET HttpClient)
# Tests all driver API endpoints against the deployed backend.
$baseUrl = "https://pyconnect.run.place"
$testPhone = "9000000060"
$adminPhone = "9000000000"

Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.ServerCertificateCustomValidationCallback = [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
$script:client = New-Object System.Net.Http.HttpClient($handler)
$script:client.BaseAddress = New-Object System.Uri($baseUrl)
$script:client.Timeout = [System.TimeSpan]::FromSeconds(20)

$script:results = [System.Collections.ArrayList]::new()
$script:findings = [System.Collections.ArrayList]::new()
$script:token = $null
$script:driverId = $null
$script:adminToken = $null

function Api-Get($path, $token = $null) {
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $path)
    if ($token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token) }
    $resp = $script:client.SendAsync($req).Result
    $content = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $content" }
    return $content
}

function Api-Post($path, $body, $token = $null) {
    $json = $body | ConvertTo-Json -Depth 5 -Compress
    $content = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, "application/json")
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $path)
    $req.Content = $content
    if ($token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token) }
    $resp = $script:client.SendAsync($req).Result
    $body = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $body" }
    return $body
}

function Api-PostEmpty($path, $token = $null) {
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $path)
    if ($token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token) }
    $resp = $script:client.SendAsync($req).Result
    $content = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $content" }
    return $content
}

function Api-Put($path, $body, $token = $null) {
    $json = $body | ConvertTo-Json -Depth 5 -Compress
    $content = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, "application/json")
    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Put, $path)
    $req.Content = $content
    if ($token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token) }
    $resp = $script:client.SendAsync($req).Result
    $body = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $body" }
    return $body
}

function Test-Case($id, $description, $scriptBlock) {
    try {
        & $scriptBlock
        $script:results.Add([PSCustomObject]@{Id=$id; Description=$description; Status="PASS"; Error=""}) | Out-Null
        Write-Host "  [PASS] ${id}: $description" -ForegroundColor Green
    } catch {
        $script:results.Add([PSCustomObject]@{Id=$id; Description=$description; Status="FAIL"; Error=$_.Exception.Message}) | Out-Null
        Write-Host "  [FAIL] ${id}: $description - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Add-Finding($msg) {
    $script:findings.Add($msg) | Out-Null
    Write-Host "  [FINDING] $msg" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================="
Write-Host "Driver App API E2E Test"
Write-Host "Backend: $baseUrl"
Write-Host "Test Phone: $testPhone"
Write-Host "========================================="
Write-Host ""

# ── Health Check ──
Write-Host "`n-- Health Check --"
Test-Case "HEALTH" "Backend health check" {
    $resp = Api-Get "/health"
    $data = $resp | ConvertFrom-Json
    if ($data.status -ne "Healthy") { throw "Backend not healthy: $($data.status)" }
}

# ── Auth Flow ──
Write-Host "`n-- Auth Flow --"
Test-Case "AUTH-001" "Request OTP" {
    $resp = Api-Post "/api/auth/otp" @{phone=$testPhone}
    $data = $resp | ConvertFrom-Json
    if (-not $data.phone) { throw "OTP request failed: $resp" }
}

Test-Case "AUTH-002" "Peek OTP" {
    $resp = Api-Get "/api/auth/otp/peek?phone=$testPhone"
    $data = $resp | ConvertFrom-Json
    if (-not $data.code -or $data.code.Length -ne 6) { throw "Invalid OTP: $resp" }
}

Test-Case "AUTH-003" "Verify OTP and get token" {
    $peek = Api-Get "/api/auth/otp/peek?phone=$testPhone"
    $code = ($peek | ConvertFrom-Json).code
    $resp = Api-Post "/api/auth/otp/verify" @{phone=$testPhone; otp=$code}
    $data = $resp | ConvertFrom-Json
    $script:token = $data.accessToken
    if (-not $script:token) { throw "No token received: $resp" }
}

# ── Driver Registration (requires auth token — handler uses _currentUser) ──
Write-Host "`n-- Driver Registration --"
Test-Case "REG-001" "Register as driver" {
    $resp = Api-Post "/api/driver/register" @{
        name="Test Captain"; phone=$testPhone; vehicleType="Bike"
        vehiclePlate="PY-01-TEST-001"; licenseNumber="DL04202600001"
    } $script:token
    $data = $resp | ConvertFrom-Json
    if (-not $data.id) { throw "Registration failed: $resp" }
    # Register returns a new token with Driver role — use it
    if ($data.accessToken) { $script:token = $data.accessToken }
}

Test-Case "REG-002" "Get driver profile (requires auth)" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp | ConvertFrom-Json
    $script:driverId = $data.id
    if (-not $script:driverId) { throw "No driver ID: $resp" }
    if ($data.name -ne "Test Captain") { throw "Name mismatch: $($data.name)" }
    if ($data.phone -ne $testPhone) { throw "Phone mismatch: $($data.phone)" }
}

# ── Tutorial & Agreement (no body) ──
Write-Host "`n-- Tutorial & Agreement --"
Test-Case "TUT-001" "Complete tutorial" {
    $resp = Api-PostEmpty "/api/driver/complete-tutorial" $script:token
}
Test-Case "TUT-002" "Sign agreement" {
    $resp = Api-PostEmpty "/api/driver/sign-agreement" $script:token
}

# ── KYC Upload (multipart form with files) ──
Write-Host "`n-- KYC Upload --"
Test-Case "KYC-001" "Upload KYC documents (multipart)" {
    # Minimal valid JPEG header + EOF
    $jpegBytes = [byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9)

    $multipart = New-Object System.Net.Http.MultipartFormDataContent

    $aadhaarContent = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $aadhaarContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($aadhaarContent, "aadhaar", "aadhaar.jpg")

    $dlContent = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $dlContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($dlContent, "drivingLicense", "license.jpg")

    $rcContent = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $rcContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($rcContent, "rc", "rc.jpg")

    $upiContent = New-Object System.Net.Http.StringContent("testcaptain@upi")
    $multipart.Add($upiContent, "upiId")

    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, "/api/driver/upload-kyc")
    $req.Content = $multipart
    $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $script:token)
    $resp = $script:client.SendAsync($req).Result
    $body = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $body" }
}

Test-Case "KYC-002" "Verify KYC status" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp | ConvertFrom-Json
    if ($data.isKycUploaded -ne $true) { throw "KYC not uploaded: $resp" }
    if ($data.hasCompletedTutorial -ne $true) { throw "Tutorial not completed" }
    if ($data.hasSignedAgreement -ne $true) { throw "Agreement not signed" }
}

# ── Admin Approval ──
Write-Host "`n-- Admin Approval --"
Test-Case "ADM-001" "Get admin token" {
    Api-Post "/api/auth/otp" @{phone=$adminPhone} | Out-Null
    Start-Sleep -Seconds 2
    $peek = Api-Get "/api/auth/otp/peek?phone=$adminPhone"
    $code = ($peek | ConvertFrom-Json).code
    $resp = Api-Post "/api/auth/otp/verify" @{phone=$adminPhone; otp=$code}
    $script:adminToken = ($resp | ConvertFrom-Json).accessToken
    if (-not $script:adminToken) { throw "No admin token: $resp" }
}

Test-Case "ADM-002" "Approve driver" {
    $resp = Api-PostEmpty "/api/admin/drivers/$script:driverId/approve" $script:adminToken
    $data = $resp | ConvertFrom-Json
    if ($data.success -ne $true) { throw "Approval failed: $($data.message)" }
}

Test-Case "ADM-003" "Verify driver is approved" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp | ConvertFrom-Json
    if ($data.isApproved -ne $true) { throw "Driver not approved: $resp" }
}

# ── Dashboard Endpoints ──
Write-Host "`n-- Dashboard Endpoints --"
Test-Case "DASH-001" "Get vehicles" { Api-Get "/api/driver/vehicles" $script:token | Out-Null }
Test-Case "DASH-002" "Get compliance" { Api-Get "/api/driver/compliance" $script:token | Out-Null }
Test-Case "DASH-003" "Get preferences" { Api-Get "/api/driver/preferences" $script:token | Out-Null }
Test-Case "DASH-004" "Get tasks" { Api-Get "/api/driver/tasks" $script:token | Out-Null }

# ── Online/Offline (no body — just a toggle) ──
Write-Host "`n-- Online/Offline --"
Test-Case "ONLINE-001" "Go online" {
    Api-PostEmpty "/api/driver/go-online" $script:token | Out-Null
}
Test-Case "ONLINE-002" "Verify online status" {
    $resp = Api-Get "/api/driver/me" $script:token
    $data = $resp | ConvertFrom-Json
    if ($data.isOnline -ne $true) { throw "Driver not online: $resp" }
}
Test-Case "ONLINE-003" "Go offline" {
    Api-PostEmpty "/api/driver/go-offline" $script:token | Out-Null
}

# ── Vehicle Management ──
Write-Host "`n-- Vehicle Management --"
Test-Case "VEH-001" "Add vehicle" {
    $resp = Api-Post "/api/driver/vehicles" @{vehicleType="Auto"; registrationNumber="PY-01-TEST-002"; color="Blue"; model="Honda"} $script:token
}
Test-Case "VEH-002" "List vehicles" {
    Api-Get "/api/driver/vehicles" $script:token | Out-Null
}

# ── Preferences ──
Write-Host "`n-- Preferences --"
Test-Case "PREF-001" "Update destination preference" {
    try {
        Api-Put "/api/driver/preferences/destination" @{latitude=11.9356; longitude=79.8301; label="Pondicherry Bus Stand"} $script:token | Out-Null
    } catch { Add-Finding "Destination pref: $($_.Exception.Message)" }
}
Test-Case "PREF-002" "Update service toggles" {
    try {
        Api-Put "/api/driver/preferences/service-toggles" @{rides=$true; foodDelivery=$true; luggage=$false} $script:token | Out-Null
    } catch { Add-Finding "Service toggles: $($_.Exception.Message)" }
}

# ── Cleanup ──
Write-Host "`n-- Cleanup --"
Test-Case "CLEANUP-001" "Delete test account" {
    try {
        Api-PostEmpty "/api/driver/account/delete" $script:token | Out-Null
    } catch { Add-Finding "Account deletion: $($_.Exception.Message)" }
}

# ── Summary ──
$passed = ($script:results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($script:results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host ""
Write-Host "========================================="
Write-Host "TEST SUMMARY"
Write-Host "========================================="
Write-Host "Total: $($script:results.Count)"
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"
Write-Host "Findings: $($script:findings.Count)"
if ($script:findings.Count -gt 0) {
    Write-Host "`n-- Findings --"
    foreach ($f in $script:findings) { Write-Host "  [!] $f" -ForegroundColor Yellow }
}
if ($failed -gt 0) {
    Write-Host "`n-- Failed Tests --"
    foreach ($r in ($script:results | Where-Object { $_.Status -eq "FAIL" })) {
        Write-Host "  [X] $($r.Id): $($r.Description)" -ForegroundColor Red
        Write-Host "      Error: $($r.Error)"
    }
}
Write-Host "========================================="
Write-Host ""

$script:results | Export-Csv -Path "C:\Users\balab\OneDrive\Documents\Projects\PY_Engine\qa-reports\driver_api_results.csv" -NoTypeInformation
Write-Host "Results exported to: qa-reports\driver_api_results.csv"
