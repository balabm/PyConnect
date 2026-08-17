const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://16.16.120.192';
const HOST_HEADER = 'pyconnect.run.place';
const TOKEN_CACHE_FILE = path.join(__dirname, 'qa_live_tokens.json');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function callApi(method, endpoint, body = null) {
  const url = `${BASE_URL}${endpoint}`;
  let cmd = `curl.exe -k -s -w "\\n%{http_code}" -X ${method} -H "Host: ${HOST_HEADER}"`;
  let tmpFile = null;
  if (body) {
    cmd += ` -H "Content-Type: application/json"`;
    tmpFile = path.join(process.env.TEMP || '.', `mint_${Date.now()}.json`);
    fs.writeFileSync(tmpFile, JSON.stringify(body));
    cmd += ` -d "@${tmpFile}"`;
  }
  cmd += ` "${url}"`;
  try {
    const rawOutput = execSync(cmd, { encoding: 'utf-8', timeout: 30000 });
    if (tmpFile && fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    const lines = rawOutput.trim().split('\n');
    const statusCode = parseInt(lines[lines.length - 1], 10);
    const bodyText = lines.slice(0, lines.length - 1).join('\n').trim();
    let json = null;
    try { if (bodyText) json = JSON.parse(bodyText); } catch (_) { json = bodyText; }
    return { status: statusCode, body: json };
  } catch (err) {
    if (tmpFile && fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
    return { status: 0, error: err.message };
  }
}

async function mintTokenFor(phone, label) {
  console.log(`\n[${label}] Requesting OTP for ${phone}...`);
  let req = callApi('POST', '/api/auth/otp/request', { phone });
  while (req.status === 429) {
    console.log(`  Rate limited, waiting 20s...`);
    await sleep(20000);
    req = callApi('POST', '/api/auth/otp/request', { phone });
  }

  if (req.status !== 200) {
    console.log(`  Request failed with status ${req.status}:`, req.body);
    return null;
  }

  await sleep(2000);
  const peek = callApi('GET', `/api/auth/otp/peek?phone=${phone}`);
  const otp = peek.body?.code || '123456';
  console.log(`  Peeked OTP: ${otp}`);

  await sleep(2000);
  const verify = callApi('POST', '/api/auth/otp/verify', { phone, otp });
  if (verify.status !== 200 || !verify.body?.accessToken) {
    console.log(`  Verify failed with status ${verify.status}:`, verify.body);
    return null;
  }

  console.log(`  ✔ Successfully minted token for ${label} (${phone})`);
  return {
    token: verify.body.accessToken,
    userId: verify.body.userId,
    name: verify.body.name,
    role: verify.body.role
  };
}

async function run() {
  const tokens = {};
  
  // Consumer
  const consumer = await mintTokenFor('9000000099', 'Consumer (Tourist)');
  if (consumer) tokens['9000000099'] = consumer;
  console.log('Waiting 15s to respect Nginx rate limits...');
  await sleep(15000);

  // Driver
  const driver = await mintTokenFor('9000000050', 'Captain (Driver)');
  if (driver) tokens['9000000050'] = driver;
  console.log('Waiting 15s to respect Nginx rate limits...');
  await sleep(15000);

  // Vendor
  const vendor = await mintTokenFor('9000000001', 'Partner (Fuoco Owner)');
  if (vendor) tokens['9000000001'] = vendor;
  console.log('Waiting 15s to respect Nginx rate limits...');
  await sleep(15000);

  // Admin
  const admin = await mintTokenFor('9000000000', 'Platform Admin');
  if (admin) tokens['9000000000'] = admin;

  fs.writeFileSync(TOKEN_CACHE_FILE, JSON.stringify({
    expiry: Date.now() + 50 * 60 * 1000,
    tokens
  }, null, 2));

  console.log('\nAll tokens saved to qa_live_tokens.json!');
}

run();
