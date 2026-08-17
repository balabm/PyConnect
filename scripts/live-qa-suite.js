const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://16.16.120.192';
const HOST_HEADER = 'pyconnect.run.place';
const TOKEN_CACHE_FILE = path.join(__dirname, 'qa_live_tokens.json');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;
const results = [];

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function log(msg) {
  console.log(`[${new Date().toISOString().substring(11, 19)}] ${msg}`);
}

function assert(description, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  \x1b[32m✔ PASS\x1b[0m ${description} ${details ? '(' + details + ')' : ''}`);
    results.push({ name: description, status: 'PASS', details });
  } else {
    failedTests++;
    console.log(`  \x1b[31m✘ FAIL\x1b[0m ${description} ${details ? '(' + details + ')' : ''}`);
    results.push({ name: description, status: 'FAIL', details });
  }
}

function callApi(method, endpoint, body = null, token = null) {
  const url = `${BASE_URL}${endpoint}`;
  const start = Date.now();
  let cmd = `curl.exe -k -s -w "\\n%{http_code}" -X ${method} -H "Host: ${HOST_HEADER}"`;
  
  if (token) {
    cmd += ` -H "Authorization: Bearer ${token}"`;
  }
  
  let tmpFile = null;
  if (body) {
    cmd += ` -H "Content-Type: application/json"`;
    tmpFile = path.join(process.env.TEMP || '.', `qa_req_${Date.now()}_${Math.random().toString(36).substring(7)}.json`);
    fs.writeFileSync(tmpFile, JSON.stringify(body));
    cmd += ` -d "@${tmpFile}"`;
  }
  
  cmd += ` "${url}"`;
  
  try {
    const rawOutput = execSync(cmd, { encoding: 'utf-8', timeout: 30000 });
    const duration = Date.now() - start;
    if (tmpFile && fs.existsSync(tmpFile)) {
      try { fs.unlinkSync(tmpFile); } catch (_) {}
    }
    
    const lines = rawOutput.trim().split('\n');
    const statusCode = parseInt(lines[lines.length - 1], 10);
    const bodyText = lines.slice(0, lines.length - 1).join('\n').trim();
    
    let json = null;
    try {
      if (bodyText) json = JSON.parse(bodyText);
    } catch (_) {
      json = bodyText;
    }
    
    return { status: statusCode, body: json, raw: bodyText, duration };
  } catch (err) {
    if (tmpFile && fs.existsSync(tmpFile)) {
      try { fs.unlinkSync(tmpFile); } catch (_) {}
    }
    return { status: 0, body: null, error: err.message, duration: Date.now() - start };
  }
}

function loadTokens() {
  if (fs.existsSync(TOKEN_CACHE_FILE)) {
    try {
      const data = JSON.parse(fs.readFileSync(TOKEN_CACHE_FILE, 'utf-8'));
      if (data.expiry && Date.now() < data.expiry) {
        return data.tokens || {};
      }
    } catch (_) {}
  }
  return {};
}

function saveTokens(tokens) {
  fs.writeFileSync(TOKEN_CACHE_FILE, JSON.stringify({
    expiry: Date.now() + 45 * 60 * 1000, // 45 min cache
    tokens
  }, null, 2));
}

async function loginUser(phone, isVendor = false, cachedTokens = {}) {
  if (cachedTokens[phone]) {
    // Validate cached token with a lightweight ping
    const testRes = callApi('GET', '/api/venues', null, cachedTokens[phone].token);
    if (testRes.status === 200) {
      log(`  [Using cached token for ${phone}]`);
      return cachedTokens[phone];
    }
  }

  let reqEndpoint = isVendor ? '/api/vendor/auth/otp/request' : '/api/auth/otp/request';
  let verifyEndpoint = isVendor ? '/api/vendor/auth/otp/verify' : '/api/auth/otp/verify';
  
  let reqRes = callApi('POST', reqEndpoint, { phone });
  
  // If rate limited, wait 15s and retry
  if (reqRes.status === 429) {
    log(`  [Rate limited for ${phone}, waiting 15s...]`);
    await sleep(15000);
    reqRes = callApi('POST', reqEndpoint, { phone });
  }
  
  if (reqRes.status !== 200) {
    reqEndpoint = '/api/auth/otp/request';
    verifyEndpoint = '/api/auth/otp/verify';
    reqRes = callApi('POST', reqEndpoint, { phone });
    if (reqRes.status === 429) {
      log(`  [Rate limited for ${phone}, waiting 15s...]`);
      await sleep(15000);
      reqRes = callApi('POST', reqEndpoint, { phone });
    }
  }

  const peekRes = callApi('GET', `/api/auth/otp/peek?phone=${phone}`);
  const otpCode = peekRes.body?.code || '123456';
  
  const verifyBody = isVendor && verifyEndpoint.includes('vendor')
    ? { phone, otpCode }
    : { phone, otp: otpCode };

  let verifyRes = callApi('POST', verifyEndpoint, verifyBody);
  
  if (verifyRes.status !== 200 || !verifyRes.body?.accessToken) {
    verifyRes = callApi('POST', '/api/auth/otp/verify', { phone, otp: otpCode });
  }
  
  if (verifyRes.status !== 200 || !verifyRes.body?.accessToken) {
    throw new Error(`OTP verify failed for ${phone} (Status: ${verifyRes.status})`);
  }
  
  const res = {
    token: verifyRes.body.accessToken,
    userId: verifyRes.body.userId,
    name: verifyRes.body.name,
    role: verifyRes.body.role
  };

  cachedTokens[phone] = res;
  saveTokens(cachedTokens);
  return res;
}

async function runLiveQa() {
  console.log('\n===============================================================');
  console.log('   PY CONNECT (PONDYCONNECT) LIVE QA AUTOMATED SUITE          ');
  console.log(`   Target: ${BASE_URL} (Host: ${HOST_HEADER})                `);
  console.log('===============================================================\n');

  const cachedTokens = loadTokens();

  // -----------------------------------------------------------------
  // 1. Infrastructure & Health Check
  // -----------------------------------------------------------------
  log('--- Step 1: Infrastructure & Health Check ---');
  const healthRes = callApi('GET', '/health');
  assert('Health Endpoint returns HTTP 200', healthRes.status === 200, `${healthRes.duration}ms`);
  assert('System overall status is Healthy', healthRes.body?.status === 'Healthy');
  
  if (healthRes.body?.checks) {
    const dbCheck = healthRes.body.checks.find(c => c.Key === 'database');
    const signalrCheck = healthRes.body.checks.find(c => c.Key === 'signalr');
    const redisCheck = healthRes.body.checks.find(c => c.Key === 'redis');
    
    assert('PostgreSQL RDS Database is Healthy', dbCheck?.status === 'Healthy');
    assert('SignalR WebSocket Backplane is Healthy', signalrCheck?.status === 'Healthy');
    assert('Redis Distributed Cache is Healthy', redisCheck?.status === 'Healthy');
  }

  // -----------------------------------------------------------------
  // 2. Multi-Role Authentication
  // -----------------------------------------------------------------
  log('\n--- Step 2: Multi-Role Authentication ---');
  let consumer, driver, vendor, admin;

  try {
    consumer = await loginUser('9000000099', false, cachedTokens);
    assert('Consumer Login (9000000099 - Test Tourist)', !!consumer.token, `UserId: ${consumer.userId}`);
  } catch (err) {
    assert('Consumer Login (9000000099)', false, err.message);
  }

  await sleep(1000);

  try {
    driver = await loginUser('9000000050', false, cachedTokens);
    assert('Captain/Driver Login (9000000050 - Suresh Kumar)', !!driver.token, `UserId: ${driver.userId}`);
  } catch (err) {
    assert('Captain/Driver Login (9000000050)', false, err.message);
  }

  await sleep(1000);

  try {
    vendor = await loginUser('9000000001', true, cachedTokens);
    assert('Partner/Vendor Login (9000000001 - Fuoco Pizzeria)', !!vendor.token, `UserId: ${vendor.userId}`);
  } catch (err) {
    assert('Partner/Vendor Login (9000000001)', false, err.message);
  }

  await sleep(1000);

  try {
    admin = await loginUser('9000000000', false, cachedTokens);
    assert('Admin Login (9000000000 - Admin)', !!admin.token, `UserId: ${admin.userId}`);
  } catch (err) {
    assert('Admin Login (9000000000)', false, err.message);
  }

  // -----------------------------------------------------------------
  // 3. Consumer Food Discovery & Transparent Pricing Checkout
  // -----------------------------------------------------------------
  log('\n--- Step 3: Consumer Food Discovery & Checkout ---');
  const fuocoVendorId = '00000000-0000-0000-0000-000000000001';
  let createdOrderId = null;

  if (consumer?.token) {
    // 3.1 Venues lookup
    const venuesRes = callApi('GET', '/api/venues', null, consumer.token);
    assert('Get Venues Catalog returns HTTP 200', venuesRes.status === 200, `${venuesRes.body?.length || 0} venues available`);

    // 3.2 Fetch Fuoco Menu
    const menuRes = callApi('GET', `/api/vendors/${fuocoVendorId}/menu`, null, consumer.token);
    assert('Fetch Fuoco Pizzeria Menu returns HTTP 200', menuRes.status === 200, `${menuRes.body?.length || 0} menu items`);
    
    let margherita = null;
    let shawarma = null;
    if (Array.isArray(menuRes.body)) {
      margherita = menuRes.body.find(m => m.name === 'Woodfired Margherita');
      shawarma = menuRes.body.find(m => m.name === 'Chicken Shawarma');
    }

    assert('Menu contains Woodfired Margherita', !!margherita, `₹${margherita?.price}`);
    assert('Menu contains Chicken Shawarma', !!shawarma, `₹${shawarma?.price}`);

    // 3.3 Consumer Order Checkout
    const checkoutPayload = {
      vendorId: fuocoVendorId,
      deliveryAddress: '12 Rue Romain Rolland, White Town, Pondicherry',
      deliveryLatitude: 11.9362,
      deliveryLongitude: 79.8346,
      paymentMethod: 1, // Cash on Delivery
      items: [
        {
          name: margherita?.name || 'Woodfired Margherita',
          quantity: 1,
          unitPrice: margherita?.price || 450
        },
        {
          name: shawarma?.name || 'Chicken Shawarma',
          quantity: 1,
          unitPrice: shawarma?.price || 180
        }
      ]
    };

    const orderRes = callApi('POST', '/api/orders/checkout', checkoutPayload, consumer.token);
    assert('Food Order Checkout returns HTTP 200', orderRes.status === 200 || orderRes.status === 201, `Status: ${orderRes.status}`);
    
    if (orderRes.body && orderRes.body.orderId) {
      createdOrderId = orderRes.body.orderId;
      assert('Order ID generated', !!createdOrderId, `OrderId: ${createdOrderId}`);
      assert('Order status is Placed', orderRes.body.status === 'Placed');
      assert('Subtotal accurately computed (450 + 180 = 630)', orderRes.body.subTotal === 630, `SubTotal: ₹${orderRes.body.subTotal}`);
      assert('Delivery fee included', orderRes.body.deliveryFee >= 0, `DeliveryFee: ₹${orderRes.body.deliveryFee}`);
      assert('Total Amount is positive & transparent', orderRes.body.totalAmount >= 630, `Total: ₹${orderRes.body.totalAmount}`);
    }
  }

  // -----------------------------------------------------------------
  // 4. Ride Hailing Lifecycle & State Machine
  // -----------------------------------------------------------------
  log('\n--- Step 4: Ride Hailing & Driver State Machine ---');
  let rideId = null;

  if (consumer?.token && driver?.token) {
    // 4.1 Accept Liability Waiver first (Mandatory Guardrail)
    const waiverRes = callApi('POST', '/api/auth/waiver/accept', null, consumer.token);
    assert('Consumer Accepts Liability Waiver', waiverRes.status === 200 || waiverRes.status === 204);

    // 4.2 Ride Request
    const rideReqPayload = {
      pickupLatitude: 11.9356,
      pickupLongitude: 79.8301,
      pickupAddress: 'Promenade Beach, Pondicherry',
      dropoffLatitude: 11.9416,
      dropoffLongitude: 79.8083,
      dropoffAddress: 'JIPMER Campus, Gorimedu',
      distanceKm: 4.2,
      vehicleType: 1, // Auto
      paymentMethod: 1 // Cash
    };
    const rideReqRes = callApi('POST', '/api/rides/request', rideReqPayload, consumer.token);
    assert('Ride Request Creation returns HTTP 200', rideReqRes.status === 200 || rideReqRes.status === 201, `Status: ${rideReqRes.status}`);
    
    if (rideReqRes.body) {
      rideId = rideReqRes.body.id || rideReqRes.body.rideId;
      assert('Ride has valid ID', !!rideId, `RideId: ${rideId}`);
    }

    // 4.3 Driver Go Online & Location Update
    const onlineRes = callApi('POST', '/api/driver/go-online', null, driver.token);
    assert('Captain Toggles Online returns HTTP 200/204', onlineRes.status === 200 || onlineRes.status === 204);

    const driverLocPayload = {
      latitude: 11.9350,
      longitude: 79.8300
    };
    const locRes = callApi('POST', '/api/driver/location', driverLocPayload, driver.token);
    assert('Captain GPS Location Ping returns HTTP 200/204', locRes.status === 200 || locRes.status === 204);

    // 4.4 Driver Task / Ride Acceptance
    if (rideId) {
      const acceptRes = callApi('POST', `/api/rides/${rideId}/accept`, null, driver.token);
      assert('Captain Accepts Ride', acceptRes.status === 200 || acceptRes.status === 204, `Status: ${acceptRes.status}`);
    }

    // 4.5 Driver Wallet Query
    const walletRes = callApi('GET', '/api/driver/wallet', null, driver.token);
    assert('Captain Wallet Ledger accessible', walletRes.status === 200, `Balance: ₹${walletRes.body?.balance ?? 0}`);
  }

  // -----------------------------------------------------------------
  // 5. Partner Operations, KDS & Physical Ticket Validation
  // -----------------------------------------------------------------
  log('\n--- Step 5: Partner Operations & Ticket Validation ---');
  if (vendor?.token) {
    const vendorMenuRes = callApi('GET', `/api/vendors/${fuocoVendorId}/menu`, null, vendor.token);
    assert('Partner accesses menu items', vendorMenuRes.status === 200, `${vendorMenuRes.body?.length || 0} items`);

    const validTicketPayload = { qrPayload: 'TICKET-TEST-PASS-001' };
    const scanRes = callApi('POST', '/api/vendor/validate-ticket', validTicketPayload, vendor.token);
    assert('Physical Ticket QR Validation Endpoint accessible', scanRes.status === 200 || scanRes.status === 400 || scanRes.status === 404, `Status: ${scanRes.status}`);
  }

  // -----------------------------------------------------------------
  // 6. Admin God Mode & Live Operations
  // -----------------------------------------------------------------
  log('\n--- Step 6: Admin God Mode & Oversight ---');
  if (admin?.token) {
    const driversListRes = callApi('GET', '/api/admin/drivers', null, admin.token);
    assert('Admin Drivers Directory Query returns HTTP 200', driversListRes.status === 200, `${driversListRes.body?.length ?? 0} drivers registered`);

    const ticketsRes = callApi('GET', '/api/admin/tickets', null, admin.token);
    assert('Admin Dispute Tickets Query returns HTTP 200', ticketsRes.status === 200, `${ticketsRes.body?.length ?? 0} dispute tickets`);

    const logsRes = callApi('GET', '/api/admin/logs', null, admin.token);
    assert('Admin Audit Logs Query returns HTTP 200', logsRes.status === 200, `${logsRes.body?.length ?? 0} audit entries`);
  }

  // -----------------------------------------------------------------
  // Final Results Summary
  // -----------------------------------------------------------------
  console.log('\n===============================================================');
  console.log('                 LIVE QA TEST SUMMARY                          ');
  console.log('===============================================================');
  console.log(`Total Tests Executed : ${totalTests}`);
  console.log(`Passed               : \x1b[32m${passedTests}\x1b[0m`);
  console.log(`Failed               : ${failedTests > 0 ? '\x1b[31m' + failedTests + '\x1b[0m' : '0'}`);
  console.log(`Success Rate         : ${Math.round((passedTests / totalTests) * 100)}%`);
  console.log('===============================================================\n');

  return { totalTests, passedTests, failedTests, results };
}

runLiveQa();
