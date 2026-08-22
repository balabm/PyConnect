const { execSync } = require('child_process');
const fs = require('fs');

const BASE_URL = 'https://16.16.120.192';
const HOST_HEADER = 'pyconnect.run.place';

const tokens = JSON.parse(fs.readFileSync('scripts/qa_live_tokens.json', 'utf-8')).tokens;
const consumerToken = tokens['9000000099'].token;

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(description, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  \x1b[32m✔ PASS\x1b[0m ${description} ${details ? '(' + details + ')' : ''}`);
  } else {
    failedTests++;
    console.log(`  \x1b[31m✘ FAIL\x1b[0m ${description} ${details ? '(' + details + ')' : ''}`);
  }
}

function callApi(method, endpoint, body = null, token = null) {
  const url = `${BASE_URL}${endpoint}`;
  const start = Date.now();
  let cmd = `curl.exe -k -s -w "\\n%{http_code}" -X ${method} -H "Host: ${HOST_HEADER}"`;
  if (token) cmd += ` -H "Authorization: Bearer ${token}"`;
  let tmpFile = null;
  if (body) {
    cmd += ` -H "Content-Type: application/json"`;
    tmpFile = `qa_req_${Date.now()}.json`;
    fs.writeFileSync(tmpFile, JSON.stringify(body));
    cmd += ` -d "@${tmpFile}"`;
  }
  cmd += ` "${url}"`;
  try {
    const rawOutput = execSync(cmd, { encoding: 'utf-8', timeout: 30000 });
    const duration = Date.now() - start;
    if (tmpFile && fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    const lines = rawOutput.trim().split('\n');
    const statusCode = parseInt(lines[lines.length - 1], 10);
    const bodyText = lines.slice(0, lines.length - 1).join('\n').trim();
    let json = null;
    try { if (bodyText) json = JSON.parse(bodyText); } catch (_) { json = bodyText; }
    return { status: statusCode, body: json, duration };
  } catch (err) {
    if (tmpFile && fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    return { status: 0, body: null, error: err.message, duration: Date.now() - start };
  }
}

async function run() {
  console.log('\n===============================================================');
  console.log('      PY CONNECT LIVE CONSUMER & SYSTEM QA VERIFICATION        ');
  console.log('===============================================================\n');

  // 1. Health
  console.log('--- 1. Infrastructure Health & Uptime ---');
  const health = callApi('GET', '/health');
  assert('Health Endpoint returns HTTP 200', health.status === 200, `${health.duration}ms`);
  assert('System Overall Status is Healthy', health.body?.status === 'Healthy');
  assert('PostgreSQL RDS Database is Healthy', health.body?.checks?.some(c => c.Key === 'database' && c.status === 'Healthy'));
  assert('SignalR WebSocket Service is Healthy', health.body?.checks?.some(c => c.Key === 'signalr' && c.status === 'Healthy'));
  assert('Redis Distributed Cache is Healthy', health.body?.checks?.some(c => c.Key === 'redis' && c.status === 'Healthy'));

  // 2. SignalR Negotiation
  console.log('\n--- 2. Real-Time SignalR Hub Connectivity ---');
  const signalr = callApi('POST', '/hubs/ride/negotiate?negotiateVersion=1', null, consumerToken);
  assert('SignalR Ride Hub Handshake returns HTTP 200', signalr.status === 200, `ConnectionId: ${signalr.body?.connectionId?.substring(0, 10)}...`);
  assert('SignalR supports WebSockets transport', signalr.body?.availableTransports?.some(t => t.transport === 'WebSockets'));

  // 3. Venues Catalog
  console.log('\n--- 3. Venues Discovery & Search ---');
  const venues = callApi('GET', '/api/venues', null, consumerToken);
  assert('Venues Catalog returns HTTP 200', venues.status === 200, `${venues.body?.length || 0} venues`);
  const fuoco = venues.body?.find(v => v.name?.includes('Fuoco'));
  assert('Fuoco Pizzeria is listed in catalog', !!fuoco, `VenueId: ${fuoco?.id}`);

  // 4. Menu Lookup
  console.log('\n--- 4. Restaurant Menu & Pricing Verification ---');
  const fuocoVendorId = '00000000-0000-0000-0000-000000000001';
  const menu = callApi('GET', `/api/vendors/${fuocoVendorId}/menu`, null, consumerToken);
  assert('Fuoco Pizzeria Menu returns HTTP 200', menu.status === 200, `${menu.body?.length || 0} items`);
  const margherita = menu.body?.find(m => m.name === 'Woodfired Margherita');
  const shawarma = menu.body?.find(m => m.name === 'Chicken Shawarma');
  assert('Woodfired Margherita item is available', margherita?.isAvailable === true, `₹${margherita?.price}`);
  assert('Chicken Shawarma item is available', shawarma?.isAvailable === true, `₹${shawarma?.price}`);

  // 5. Liability Waiver
  console.log('\n--- 5. Legal & Safety Compliance ---');
  const waiver = callApi('POST', '/api/auth/waiver/accept', null, consumerToken);
  assert('Liability Waiver Acceptance returns HTTP 200', waiver.status === 200, `Accepted: ${waiver.body?.acceptedAt || 'OK'}`);

  // 6. Ride Request
  console.log('\n--- 6. Ride Hailing Request Lifecycle ---');
  const rideReq = {
    pickupLatitude: 11.9356,
    pickupLongitude: 79.8301,
    pickupAddress: 'Promenade Beach, White Town',
    dropoffLatitude: 11.9416,
    dropoffLongitude: 79.8083,
    dropoffAddress: 'JIPMER Campus, Gorimedu',
    distanceKm: 4.2,
    vehicleType: 1, // Auto
    paymentMethod: 1 // Cash
  };
  const ride = callApi('POST', '/api/rides/request', rideReq, consumerToken);
  assert('Ride Request Creation returns HTTP 200/201', ride.status === 200 || ride.status === 201, `Status: ${ride.status}`);
  
  const rideId = ride.body?.id || ride.body?.rideId;
  assert('Ride ID was generated', !!rideId, `RideId: ${rideId}`);
  assert('Ride status is Requested', ride.body?.status === 'Requested' || ride.body?.status === 'Searching');
  assert('Fare calculation is transparent', ride.body?.fare > 0, `Fare: ₹${ride.body?.fare}`);

  console.log('\n===============================================================');
  console.log(`TOTAL TESTS: ${totalTests} | PASSED: \x1b[32m${passedTests}\x1b[0m | FAILED: \x1b[31m${failedTests}\x1b[0m`);
  console.log(`SUCCESS RATE: ${Math.round((passedTests / totalTests) * 100)}%`);
  console.log('===============================================================\n');
}

run();
