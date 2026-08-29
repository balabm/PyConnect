# Partner App API E2E Test
# Flow: Self-register → KYC → Admin approve → Vendor auth → Dashboard
$baseUrl = "https://pyconnect.run.place"
$testPhone = "9000000080"
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
$script:vendorId = $null
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
Write-Host "Partner App API E2E Test"
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

# ── Vendor Self-Registration (no auth needed) ──
Write-Host "`n-- Vendor Self-Registration --"
Test-Case "REG-001" "Self-register vendor" {
    $resp = Api-Post "/api/vendor/register" @{
        businessName="Test Restaurant QA"
        category="Restaurant"
        contactPhone=$testPhone
        description="QA test vendor"
    }
    $data = $resp | ConvertFrom-Json
    $script:vendorId = $data.vendorId
    if (-not $script:vendorId) { throw "No vendor ID: $resp" }
}

# ── Vendor KYC Upload (multipart, no auth) ──
Write-Host "`n-- Vendor KYC Upload --"
Test-Case "KYC-001" "Upload vendor KYC" {
    $jpegBytes = [byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9)

    $multipart = New-Object System.Net.Http.MultipartFormDataContent

    $fssaiDoc = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $fssaiDoc.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($fssaiDoc, "FssaiDoc", "fssai.jpg")

    $gstDoc = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $gstDoc.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($gstDoc, "GstDoc", "gst.jpg")

    $panDoc = New-Object System.Net.Http.ByteArrayContent(, $jpegBytes)
    $panDoc.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/jpeg")
    $multipart.Add($panDoc, "PanDoc", "pan.jpg")

    $fssaiNum = New-Object System.Net.Http.StringContent("12345678901234")
    $multipart.Add($fssaiNum, "FssaiNumber")

    $gstNum = New-Object System.Net.Http.StringContent("33ABCDE1234F1Z5")
    $multipart.Add($gstNum, "GstNumber")

    $panNum = New-Object System.Net.Http.StringContent("ABCDE1234F")
    $multipart.Add($panNum, "PanNumber")

    $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, "/api/vendor/$script:vendorId/kyc")
    $req.Content = $multipart
    $resp = $script:client.SendAsync($req).Result
    $body = $resp.Content.ReadAsStringAsync().Result
    if (-not $resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode): $body" }
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

Test-Case "ADM-002" "Approve vendor" {
    $resp = Api-PostEmpty "/api/admin/vendors/$script:vendorId/approve" $script:adminToken
}

# ── Vendor Auth Flow (after approval) ──
Write-Host "`n-- Vendor Auth Flow --"
Test-Case "AUTH-001" "Request vendor OTP" {
    $resp = Api-Post "/api/vendor/auth/otp/request" @{phone=$testPhone}
}

Test-Case "AUTH-002" "Peek vendor OTP" {
    $resp = Api-Get "/api/vendor/auth/otp/peek?phone=$testPhone"
    $data = $resp | ConvertFrom-Json
    if (-not $data.code) { throw "No OTP code: $resp" }
}

Test-Case "AUTH-003" "Verify vendor OTP" {
    $peek = Api-Get "/api/vendor/auth/otp/peek?phone=$testPhone"
    $code = ($peek | ConvertFrom-Json).code
    $resp = Api-Post "/api/vendor/auth/otp/verify" @{phone=$testPhone; otpCode=$code}
    $data = $resp | ConvertFrom-Json
    $script:token = $data.accessToken
    if (-not $script:token) { throw "No token: $resp" }
}

# ── Vendor Profile ──
Write-Host "`n-- Vendor Profile --"
Test-Case "PROFILE-001" "Get vendor profile" {
    $resp = Api-Get "/api/vendor/profile" $script:token
    $data = $resp | ConvertFrom-Json
    if ($data.businessName -ne "Test Restaurant QA") { throw "Name mismatch: $($data.businessName)" }
}

# ── Vendor Dashboard ──
Write-Host "`n-- Vendor Dashboard --"
Test-Case "DASH-001" "Get dashboard" {
    $resp = Api-Get "/api/vendor/dashboard" $script:token
}

Test-Case "DASH-002" "Get vendor venues" {
    $resp = Api-Get "/api/vendor/venues" $script:token
}

Test-Case "DASH-003" "Get vendor bookings" {
    $resp = Api-Get "/api/vendor/bookings" $script:token
}

# ── KDS (Kitchen Display System) ──
Write-Host "`n-- KDS --"
Test-Case "KDS-001" "Get KDS orders" {
    $resp = Api-Get "/api/vendor/kds/orders" $script:token
}

# ── Vendor Wallet ──
Write-Host "`n-- Vendor Wallet --"
Test-Case "WALLET-001" "Get vendor wallet" {
    $resp = Api-Get "/api/vendor/wallet" $script:token
}

Test-Case "WALLET-002" "Get wallet transactions" {
    $resp = Api-Get "/api/vendor/wallet/transactions" $script:token
}

Test-Case "WALLET-003" "Get wallet detail" {
    $resp = Api-Get "/api/vendor/wallet/detail" $script:token
}

# ── Vendor Reviews ──
Write-Host "`n-- Reviews --"
Test-Case "REVIEW-001" "Get vendor reviews" {
    $resp = Api-Get "/api/vendor/reviews" $script:token
}

# ── Vendor Staff ──
Write-Host "`n-- Staff --"
Test-Case "STAFF-001" "Get vendor staff" {
    $resp = Api-Get "/api/vendor/staff" $script:token
}

# ── Vendor Disputes ──
Write-Host "`n-- Disputes --"
Test-Case "DISPUTE-001" "Get vendor disputes" {
    $resp = Api-Get "/api/vendor/disputes" $script:token
}

# ── Vendor Promotions ──
Write-Host "`n-- Promotions --"
Test-Case "PROMO-001" "Get vendor promotions" {
    $resp = Api-Get "/api/vendor/promotions" $script:token
}

Test-Case "PROMO-002" "Get flash promos" {
    $resp = Api-Get "/api/vendor/flash-promos" $script:token
}

# ── Vendor Luggage ──
Write-Host "`n-- Luggage --"
Test-Case "LUGGAGE-001" "Get vendor luggage" {
    try {
        $resp = Api-Get "/api/vendor/luggage" $script:token
    } catch { Add-Finding "Vendor luggage: $($_.Exception.Message)" }
}

# ── Vendor Live Tables ──
Write-Host "`n-- Live Tables --"
Test-Case "TABLE-001" "Get live tables" {
    try {
        $resp = Api-Get "/api/vendor/live-tables" $script:token
    } catch { Add-Finding "Live tables: $($_.Exception.Message)" }
}

# ── Vendor Door Log ──
Write-Host "`n-- Door Log --"
Test-Case "DOOR-001" "Get door log" {
    try {
        $resp = Api-Get "/api/vendor/door-log" $script:token
    } catch { Add-Finding "Door log: $($_.Exception.Message)" }
}

# ── Vendor Businesses (public) ──
Write-Host "`n-- Businesses --"
Test-Case "BIZ-001" "List businesses" {
    $resp = Api-Get "/api/vendor/auth/businesses"
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

$script:results | Export-Csv -Path "C:\Users\balab\OneDrive\Documents\Projects\PY_Engine\qa-reports\partner_api_results.csv" -NoTypeInformation
Write-Host "Results exported to: qa-reports\partner_api_results.csv"
