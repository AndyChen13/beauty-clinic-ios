// Cloudflare Worker - COS 签名服务
// 部署后得到一个 https://xxx.your-subdomain.workers.dev 地址
// iOS App 直接调用这个地址获取签名

// 在 Cloudflare Worker 控制台设置以下环境变量：
// COS_SECRET_ID = 你的腾讯云 SecretId
// COS_SECRET_KEY = 你的腾讯云 SecretKey
// COS_BUCKET = beautyclinic-images-1472260859
// COS_REGION = ap-shanghai

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  // CORS 预检
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      }
    })
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  try {
    const body = await request.json()
    const key = body.key || ''
    const method = (body.method || 'put').toLowerCase()

    if (!key) {
      return jsonResponse({ error: 'Missing "key" field' }, 400)
    }

    // 从环境变量读取
    const SECRET_ID = typeof COS_SECRET_ID !== 'undefined' ? COS_SECRET_ID : ''
    const SECRET_KEY = typeof COS_SECRET_KEY !== 'undefined' ? COS_SECRET_KEY : ''
    const BUCKET = typeof COS_BUCKET !== 'undefined' ? COS_BUCKET : 'beautyclinic-images-1472260859'
    const REGION = typeof COS_REGION !== 'undefined' ? COS_REGION : 'ap-shanghai'

    if (!SECRET_ID || !SECRET_KEY) {
      return jsonResponse({ error: 'Missing COS credentials in worker environment' }, 500)
    }

    const auth = await generateCosSignature(key, method, SECRET_ID, SECRET_KEY, BUCKET, REGION)

    return jsonResponse({
      authorization: auth,
      host: `${BUCKET}.cos.${REGION}.myqcloud.com`,
      bucket: BUCKET,
      region: REGION
    })

  } catch (e) {
    return jsonResponse({ error: e.message }, 500)
  }
}

async function generateCosSignature(key, method, secretId, secretKey, bucket, region) {
  const now = Math.floor(Date.now() / 1000)
  const expire = now + 3600
  const keyTime = `${now};${expire}`

  // SignKey = HMAC-SHA1(SecretKey, KeyTime)
  const signKey = await hmacSha1Hex(secretKey, keyTime)

  // HttpString
  const uri = `/${key}`
  const contentType = 'image/jpeg'
  const host = `${bucket}.cos.${region}.myqcloud.com`
  const headers = `content-type=${contentType}&host=${host}`
  const httpString = `${method}\n${uri}\n\n${headers}\n`

  // StringToSign
  const sha1Http = await sha1Hex(httpString)
  const stringToSign = `sha1\n${keyTime}\n${sha1Http}\n`

  // Signature = HMAC-SHA1(SignKey, StringToSign)
  const signature = await hmacSha1Hex(signKey, stringToSign)

  return (
    `q-sign-algorithm=sha1` +
    `&q-ak=${secretId}` +
    `&q-sign-time=${keyTime}` +
    `&q-key-time=${keyTime}` +
    `&q-header-list=content-type;host` +
    `&q-url-param-list=` +
    `&q-signature=${signature}`
  )
}

async function hmacSha1Hex(key, data) {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(key),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  )
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data))
  return arrayBufferToHex(signature)
}

async function sha1Hex(data) {
  const buffer = new TextEncoder().encode(data)
  const hash = await crypto.subtle.digest('SHA-1', buffer)
  return arrayBufferToHex(hash)
}

function arrayBufferToHex(buffer) {
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    }
  })
}
