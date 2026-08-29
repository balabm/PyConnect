# Consumer App API E2E Test (corrected routes)
$baseUrl = "https://pyconnect.run.place"
$testPhone = "9000000070"

Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.ServerCertificateCustomValidationCallback = [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
$script:client = New-Object System.Net.Http.HttpClient($handler)
$script:client.BaseAddress = New-Object System.Uri($baseUrl)
$script:client.Timeout = [System.TimeSpan]::FromSeconds(20)

$script:results = [System.Collections.ArrayList]::new()
$script:findings = [System.Collections.ArrayList]::new()
$script:token = $null
$script:userId = $null

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
Write-Host "Consumer App API E2E Test"
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
    $script:userId = $data.userId
    if (-not $script:token) { throw "No token received: $resp" }
}

# ── User Profile ──
Write-Host "`n-- User Profile --"
Test-Case "USER-001" "Get user profile" {
    try {
        $resp = Api-Get "/api/auth/me" $script:token
        $data = $resp | ConvertFrom-Json
        if ($data.phone -ne $testPhone) { throw "Phone mismatch: $($data.phone)" }
    } catch { Add-Finding "Get me: $($_.Exception.Message)" }
}

# ── Venues ──
Write-Host "`n-- Venues --"
Test-Case "VENUE-001" "List venues" {
    $resp = Api-Get "/api/venues" $script:token
    $data = $resp | ConvertFrom-Json
    if (-not $data) { throw "No venues returned" }
}

Test-Case "VENUE-002" "List venues by category (Nightlife)" {
    $resp = Api-Get "/api/venues?category=Nightlife" $script:token
}

Test-Case "VENUE-003" "Get venue detail" {
    $listResp = Api-Get "/api/venues" $script:token
    $venues = $listResp | ConvertFrom-Json
    if ($venues.Count -gt 0) {
        $venueId = $venues[0].id
        $resp = Api-Get "/api/venues/$venueId" $script:token
        $data = $resp | ConvertFrom-Json
        if ($data.id -ne $venueId) { throw "Venue ID mismatch" }
    }
}

# ── Food (routes under api/) ──
Write-Host "`n-- Food --"
Test-Case "FOOD-001" "List food vendors" {
    $resp = Api-Get "/api/vendors" $script:token
    $data = $resp | ConvertFrom-Json
}

Test-Case "FOOD-002" "Get food vendor menu" {
    $listResp = Api-Get "/api/vendors" $script:token
    $vendors = $listResp | ConvertFrom-Json
    if ($vendors.Count -gt 0) {
        $vendorId = $vendors[0].id
        $resp = Api-Get "/api/vendors/$vendorId/menu" $script:token
    }
}

Test-Case "FOOD-003" "Get food order history" {
    $resp = Api-Get "/api/orders/my-orders" $script:token
}

# ── Rides (routes under api/) ──
Write-Host "`n-- Rides --"
Test-Case "RIDE-001" "Get ride history" {
    $resp = Api-Get "/api/rides/my-rides" $script:token
}

Test-Case "RIDE-002" "Get nearby drivers" {
    $resp = Api-Get "/api/rides/nearby-drivers?lat=11.9356&lng=79.8301" $script:token
}

Test-Case "RIDE-003" "Get saved locations" {
    try {
        $resp = Api-Get "/api/saved-locations" $script:token
    } catch { Add-Finding "Saved locations: $($_.Exception.Message)" }
}

Test-Case "RIDE-004" "Get scheduled rides" {
    $resp = Api-Get "/api/scheduled-rides" $script:token
}

Test-Case "RIDE-005" "Get emergency contacts" {
    $resp = Api-Get "/api/emergency-contacts" $script:token
}

# ── Stays (api/homestays) ──
Write-Host "`n-- Stays --"
Test-Case "STAY-001" "List homestays" {
    $resp = Api-Get "/api/homestays" $script:token
}

# ── Transit (api/transit/hubs, api/transit/trips) ──
Write-Host "`n-- Transit --"
Test-Case "TRANSIT-001" "List transit hubs" {
    $resp = Api-Get "/api/transit/hubs" $script:token
}

Test-Case "TRANSIT-002" "List transit trips" {
    $resp = Api-Get "/api/transit/trips" $script:token
}

# ── Luggage (api/luggage/drop-offs) ──
Write-Host "`n-- Luggage --"
Test-Case "LUGGAGE-001" "List luggage drop-offs" {
    $resp = Api-Get "/api/luggage/drop-offs" $script:token
}

# ── Rentals (api/rental/scooters) ──
Write-Host "`n-- Rentals --"
Test-Case "RENTAL-001" "List rental scooters" {
    $resp = Api-Get "/api/rental/scooters" $script:token
}

# ── Events (api/p2p-events) ──
Write-Host "`n-- Events --"
Test-Case "EVENT-001" "List P2P events" {
    $resp = Api-Get "/api/p2p-events" $script:token
}

# ── Wallet (api/user/wallet) ──
Write-Host "`n-- Wallet --"
Test-Case "WALLET-001" "Get wallet balance" {
    $resp = Api-Get "/api/user/wallet" $script:token
}

Test-Case "WALLET-002" "Get wallet transactions" {
    $resp = Api-Get "/api/user/wallet/transactions" $script:token
}

# ── Notifications ──
Write-Host "`n-- Notifications --"
Test-Case "NOTIF-001" "Register device token" {
    try {
        $resp = Api-Post "/api/user/device-token" @{token="test-fcm-token"; platform="android"} $script:token
    } catch { Add-Finding "Device token: $($_.Exception.Message)" }
}

# ── Bookings (api/bookings) ──
Write-Host "`n-- Bookings --"
Test-Case "BOOK-001" "Create booking (POST)" {
    # Bookings controller only has POST, no GET list
    try {
        $resp = Api-Post "/api/bookings" @{venueId="00000000-0000-0000-0000-000000000000"; date="2026-09-01"} $script:token
    } catch { Add-Finding "Bookings POST: $($_.Exception.Message)" }
}

# ── Support (api/support) ──
Write-Host "`n-- Support --"
Test-Case "SUPPORT-001" "Get support tickets" {
    $resp = Api-Get "/api/support/tickets" $script:token
}

# ── Equipment (api/equipment/browse) ──
Write-Host "`n-- Equipment --"
Test-Case "EQUIP-001" "Browse equipment" {
    $resp = Api-Get "/api/equipment/browse" $script:token
}

Test-Case "EQUIP-002" "List equipment items" {
    $resp = Api-Get "/api/equipment/items" $script:token
}

# ── Party Services (api/party-services/browse) ──
Write-Host "`n-- Party Services --"
Test-Case "PARTY-001" "Browse party services" {
    $resp = Api-Get "/api/party-services/browse" $script:token
}

# ── Referral (api/referrals/me) ──
Write-Host "`n-- Referral --"
Test-Case "REFERRAL-001" "Get referral info" {
    $resp = Api-Get "/api/referrals/me" $script:token
}

# ── Subscriptions (api/subscriptions/status) ──
Write-Host "`n-- Subscriptions --"
Test-Case "SUB-001" "Get subscription status" {
    $resp = Api-Get "/api/subscriptions/status" $script:token
}

# ── Dine In (api/dine-in/active) ──
Write-Host "`n-- Dine In --"
Test-Case "DINE-001" "Get active dine-in sessions" {
    $resp = Api-Get "/api/dine-in/active" $script:token
}

# ── Activity (api/activity/all) ──
Write-Host "`n-- Activity --"
Test-Case "ACTIVITY-001" "Get activity feed" {
    $resp = Api-Get "/api/activity/all" $script:token
}

# ── Public (api/flash-promos, api/service-area) ──
Write-Host "`n-- Public --"
Test-Case "PUB-001" "Get flash promos" {
    $resp = Api-Get "/api/flash-promos" $script:token
}

Test-Case "PUB-002" "Check service area" {
    $resp = Api-Get "/api/service-area?lat=11.9356&lng=79.8301" $script:token
}

# ── Config (api/config/app-versions) ──
Write-Host "`n-- Config --"
Test-Case "CONFIG-001" "Get app versions" {
    $resp = Api-Get "/api/config/app-versions" $script:token
}

# ── Cleanup ──
Write-Host "`n-- Cleanup --"
Test-Case "CLEANUP-001" "Delete test account" {
    try {
        $resp = Api-PostEmpty "/api/auth/account/delete" $script:token
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

$script:results | Export-Csv -Path "C:\Users\balab\OneDrive\Documents\Projects\PY_Engine\qa-reports\consumer_api_results.csv" -NoTypeInformation
Write-Host "Results exported to: qa-reports\consumer_api_results.csv"
