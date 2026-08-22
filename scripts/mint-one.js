const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://16.16.120.192';
const HOST_HEADER = 'pyconnect.run.place';
const TOKEN_CACHE_FILE = path.join(__dirname, 'qa_live_tokens.json');

function callApi(method, endpoint, body = null) {
  const url = `${BASE_URL}${endpoint}`;
  let cmd = `curl.exe -k -s -w "\\n%{http_code}" -X ${method} -H "Host: ${HOST_HEADER}"`;
  let tmpFile = null;
  if (body) {
    cmd += ` -H "Content-Type: application/json"`;
    tmpFile = `mint_${Date.now()}.json`;
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

async function mintOne(phone, label) {
  console.log(`Minting for ${label} (${phone})...`);
  const req = callApi('POST', '/api/auth/otp/request', { phone });
  console.log('OTP request status:', req.status, req.body);
  if (req.status !== 200) return null;

  const peek = callApi('GET', `/api/auth/otp/peek?phone=${phone}`);
  const otp = peek.body?.code || '123456';
  console.log('Peeked OTP:', otp);

  const verify = callApi('POST', '/api/auth/otp/verify', { phone, otp });
  console.log('Verify status:', verify.status, verify.body?.userId ? 'Success' : verify.body);
  if (verify.status !== 200 || !verify.body?.accessToken) return null;

  const cache = JSON.parse(fs.readFileSync(TOKEN_CACHE_FILE, 'utf-8'));
  cache.tokens[phone] = {
    token: verify.body.accessToken,
    userId: verify.body.userId,
    name: verify.body.name,
    role: verify.body.role
  };
  fs.writeFileSync(TOKEN_CACHE_FILE, JSON.stringify(cache, null, 2));
  console.log(`Saved token for ${label}!`);
  return cache.tokens[phone];
}

async function run() {
  await mintOne('9000000050', 'Captain');
}

run();
