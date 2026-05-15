const crypto = require('crypto');
const readline = require('readline/promises');

process.env.NODE_TLS_REJECT_UNAUTHORIZED =
  process.env.NODE_TLS_REJECT_UNAUTHORIZED || '0';

const AUTH_LOGIN =
  'https://authserver.gdut.edu.cn/authserver/login?service=https%3A%2F%2Fjxfw.gdut.edu.cn%2Fnew%2FssoLogin';
const JW_ENTRY = 'https://jxfw.gdut.edu.cn';

const cookieJar = new Map();

function saveCookies(url, headers) {
  const host = new URL(url).hostname;
  const setCookies =
    typeof headers.getSetCookie === 'function'
      ? headers.getSetCookie()
      : (headers.get('set-cookie') ? [headers.get('set-cookie')] : []);

  for (const raw of setCookies) {
    const first = raw.split(';')[0];
    const index = first.indexOf('=');
    if (index > 0) {
      cookieJar.set(`${host}|${first.slice(0, index)}`, first);
    }
  }
}

function cookieHeader(url) {
  const host = new URL(url).hostname;
  return [...cookieJar.entries()]
    .filter(([key]) => {
      const cookieHost = key.split('|')[0];
      return host === cookieHost || host.endsWith(`.${cookieHost}`);
    })
    .map(([, value]) => value)
    .join('; ');
}

async function request(url, options = {}) {
  const headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 GDUTScheduleProbe/0.1',
    ...options.headers,
  };
  const cookies = cookieHeader(url);
  if (cookies) {
    headers.Cookie = cookies;
  }

  const response = await fetch(url, {
    ...options,
    headers,
    redirect: 'manual',
  });
  saveCookies(url, response.headers);
  return response;
}

function inputValue(html, idOrName) {
  const pattern = new RegExp(
    `<input[^>]*(?:id|name)=["']${idOrName}["'][^>]*>`,
    'i',
  );
  const match = html.match(pattern);
  if (!match) {
    return '';
  }

  return match[0].match(/value=["']([^"']*)["']/i)?.[1] ?? '';
}

function randomString(length) {
  const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
  return Array.from(
    { length },
    () => chars[crypto.randomInt(chars.length)],
  ).join('');
}

function encryptPassword(password, salt) {
  const cipher = crypto.createCipheriv(
    'aes-128-cbc',
    Buffer.from(salt, 'utf8'),
    Buffer.from(randomString(16), 'utf8'),
  );
  return Buffer.concat([
    cipher.update(`${randomString(64)}${password}`, 'utf8'),
    cipher.final(),
  ]).toString('base64');
}

function resolveLocation(base, response) {
  const location = response.headers.get('location');
  return location ? new URL(location, base).toString() : null;
}

async function followRedirects(startUrl, response, label) {
  let currentUrl = startUrl;
  let currentResponse = response;

  for (let i = 0; i < 12; i++) {
    const next = resolveLocation(currentUrl, currentResponse);
    if (!next) {
      return { url: currentUrl, response: currentResponse };
    }

    console.log(`${label} redirect ${currentResponse.status}: ${next}`);
    currentUrl = next;
    currentResponse = await request(currentUrl);
  }

  throw new Error(`${label} redirect loop`);
}

function extractHtmlError(html) {
  const showError = html.match(/id=["']showErrorTip["'][^>]*>(.*?)<\/div>/is);
  if (showError?.[1]) {
    return showError[1].replace(/<[^>]+>/g, '').trim();
  }
  if (html.includes('Internal Server Error')) {
    return '统一认证返回 500';
  }
  return null;
}

function termFromDate(date = new Date()) {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  if (month >= 8) {
    return { xnxqdm: `${year}01`, displayName: `${year}秋季` };
  }
  return { xnxqdm: `${year - 1}02`, displayName: `${year}春季` };
}

async function login(username, password) {
  console.log('GET auth login page');
  let response = await request(AUTH_LOGIN);
  let html = await response.text();
  const salt = inputValue(html, 'pwdEncryptSalt');
  const execution = inputValue(html, 'execution');
  if (!salt || !execution) {
    throw new Error('登录页缺少 pwdEncryptSalt 或 execution');
  }

  console.log('POST auth login');
  const body = new URLSearchParams({
    username,
    password: encryptPassword(password, salt),
    cllt: 'userNameLogin',
    dllt: 'generalLogin',
    lt: '',
    execution,
    _eventId: 'submit',
    rmShown: '1',
  });

  response = await request(AUTH_LOGIN, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Origin: 'https://authserver.gdut.edu.cn',
      Referer: AUTH_LOGIN,
    },
    body,
  });

  const location = resolveLocation(AUTH_LOGIN, response);
  if (!location) {
    html = await response.text();
    throw new Error(extractHtmlError(html) || `认证失败，HTTP ${response.status}`);
  }

  const followed = await followRedirects(AUTH_LOGIN, response, 'auth');
  const finalUrl = followed.response.url || followed.url;
  console.log(`auth final: ${followed.response.status} ${finalUrl}`);
  return finalUrl;
}

async function fetchSchedule(username, term = termFromDate()) {
  const scheduleUrl = `${JW_ENTRY}/xsgrkbcx!getDataList.action`;
  const body = new URLSearchParams({
    xnxqdm: term.xnxqdm,
    zc: process.env.GDUT_WEEK || '',
    page: '1',
    rows: '500',
    sort: 'kxh',
    order: 'asc',
  });

  console.log(`POST schedule xnxqdm=${term.xnxqdm} (${term.displayName})`);
  const response = await request(scheduleUrl, {
    method: 'POST',
    headers: {
      Accept: 'application/json, text/javascript, */*; q=0.01',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      Referer:
        `${JW_ENTRY}/xsgrkbcx!xskbList2.action?xnxqdm=${term.xnxqdm}`,
    },
    body,
  });

  const text = await response.text();
  console.log(`schedule response: ${response.status}`);
  try {
    return JSON.parse(text);
  } catch {
    console.log(text.slice(0, 500).replace(/\s+/g, ' '));
    throw new Error('课表接口没有返回 JSON');
  }
}

async function readCredentials() {
  const username = process.env.GDUT_USERNAME;
  const password = process.env.GDUT_PASSWORD;
  if (username && password) {
    return { username, password };
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  const promptedUsername = username || (await rl.question('GDUT username: '));
  const promptedPassword = password || (await rl.question('GDUT password: '));
  rl.close();
  return { username: promptedUsername.trim(), password: promptedPassword };
}

async function main() {
  const { username, password } = await readCredentials();
  await login(username, password);
  const schedule = await fetchSchedule(username);
  const courses = Array.isArray(schedule.rows) ? schedule.rows : [];
  console.log(`courses: ${courses.length}`);
  const dumpMatch = process.env.GDUT_DUMP_MATCH;
  if (dumpMatch) {
    for (const course of courses) {
      if (JSON.stringify(course).includes(dumpMatch)) {
        console.log(JSON.stringify(course, null, 2));
      }
    }
  }
  for (const course of courses.slice(0, 12)) {
    console.log(
      [
        course.kcmc,
        `第${course.zc}周`,
        `周${course.xq}`,
        course.jcdm,
        course.jxcdmc,
        course.teaxms,
      ]
        .filter(Boolean)
        .join(' | '),
    );
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
