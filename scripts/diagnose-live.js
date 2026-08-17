const { execSync } = require('child_process');
const fs = require('fs');

const tokens = JSON.parse(fs.readFileSync('scripts/qa_live_tokens.json', 'utf-8')).tokens;
const consumerToken = tokens['9000000099'].token;

function test(name, method, url, body, token) {
  let cmd = `curl.exe -k -s -i -X ${method} -H "Host: pyconnect.run.place"`;
  if (token) cmd += ` -H "Authorization: Bearer ${token}"`;
  let tmp = null;
  if (body) {
    cmd += ` -H "Content-Type: application/json"`;
    tmp = `diag_${Date.now()}.json`;
    fs.writeFileSync(tmp, JSON.stringify(body));
    cmd += ` -d "@${tmp}"`;
  }
  cmd += ` "https://16.16.120.192${url}"`;
  try {
    const res = execSync(cmd, { encoding: 'utf-8' });
    console.log(`\n=== ${name} (${method} ${url}) ===\n${res}`);
  } catch (err) {
    console.log(`\n=== ${name} ERROR ===\n${err.message}`);
  } finally {
    if (tmp && fs.existsSync(tmp)) fs.unlinkSync(tmp);
  }
}

async function run() {
  test('Venues with Consumer Token', 'GET', '/api/venues', null, consumerToken);
  test('Waiver Accept with Consumer Token', 'POST', '/api/auth/waiver/accept', null, consumerToken);
}

run();
