# -*- coding: utf-8 -*-
"""
腾讯云 SCF COS 签名服务 - 双兼容版
同时支持：事件函数 (main_handler) 与 Web 函数 (HTTPServer)
无论 SCF 控制台把 sign 函数配置成哪种执行方法，本文件都能正常工作。
"""
import os
import json
import hmac
import hashlib
import time
import base64
from urllib.parse import quote

SECRET_ID = os.environ.get('COS_SECRET_ID')
SECRET_KEY = os.environ.get('COS_SECRET_KEY')
BUCKET = os.environ.get('COS_BUCKET', 'beautyclinic-images-1472260859')
REGION = os.environ.get('COS_REGION', 'ap-shanghai')


def sha1_hash(data: str) -> str:
    return hashlib.sha1(data.encode('utf-8')).hexdigest()


def hmac_sha1(key: str, data: str) -> bytes:
    return hmac.new(key.encode('utf-8'), data.encode('utf-8'), hashlib.sha1).digest()


def generate_cos_signature(key: str, method: str = 'put', content_type: str = 'image/jpeg') -> str:
    """Generate COS v1 authorization signature (与腾讯云官方 SDK 格式一致)."""
    now = int(time.time())
    expire = now + 3600  # 1 hour validity
    key_time = f"{now};{expire}"

    sign_key = hmac_sha1(SECRET_KEY, key_time).hex()

    uri = f"/{key}"
    query_string = ""
    host = f"{BUCKET}.cos.{REGION}.myqcloud.com"
    # COS v1 spec: header keys AND values must be URL-encoded
    headers = f"content-type={quote(content_type, safe='')}&host={quote(host, safe='')}"
    http_string = f"{method.lower()}\n{uri}\n{query_string}\n{headers}\n"  # 末尾必须有 \n

    sha1_http = sha1_hash(http_string)
    string_to_sign = f"sha1\n{key_time}\n{sha1_http}\n"  # 末尾必须有 \n（与官方 SDK 一致）

    signature = hmac_sha1(sign_key, string_to_sign).hex()

    auth = (
        f"q-sign-algorithm=sha1"
        f"&q-ak={SECRET_ID}"
        f"&q-sign-time={key_time}"
        f"&q-key-time={key_time}"
        f"&q-header-list=content-type;host"
        f"&q-url-param-list="
        f"&q-signature={signature}"
    )
    return auth


def _cors_headers() -> dict:
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    }


def _handle_sign(event: dict):
    """处理一次签名请求，返回 (status_code, dict)。event 为 SCF 事件字典。"""
    method = (event.get('httpMethod') or event.get('requestContext', {}).get('httpMethod') or 'GET').upper()

    if method == 'OPTIONS':
        return 200, {}

    if method != 'POST' or event.get('path') != '/sign':
        return 404, {'error': 'Not found'}

    body = event.get('body', '')
    if event.get('isBase64Encoded') and body:
        try:
            body = base64.b64decode(body).decode('utf-8')
        except Exception:
            body = ''
    try:
        data = json.loads(body) if body else {}
    except Exception:
        return 400, {'error': 'Invalid JSON'}

    key = data.get('key', '')
    m = data.get('method', 'put')
    content_type = data.get('content_type', 'image/jpeg')
    if not key:
        return 400, {'error': 'Missing "key" field'}
    if not SECRET_ID or not SECRET_KEY:
        return 500, {'error': 'Missing COS credentials in environment variables'}

    auth = generate_cos_signature(key, m, content_type)
    return 200, {
        'authorization': auth,
        'host': f"{BUCKET}.cos.{REGION}.myqcloud.com",
        'bucket': BUCKET,
        'region': REGION,
    }


def _build_response(status: int, data: dict) -> dict:
    return {
        'statusCode': status,
        'headers': _cors_headers(),
        'body': json.dumps(data, ensure_ascii=False),
    }


# ===================== 事件函数入口 =====================
def main_handler(event, context):
    event = event or {}
    status, data = _handle_sign(event)
    return _build_response(status, data)


# ===================== Web 函数入口 =====================
if __name__ == '__main__':
    from http.server import HTTPServer, BaseHTTPRequestHandler

    class SignHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            print(f"[SignServer] {fmt % args}")

        def _send(self, status, data):
            self.send_response(status)
            for k, v in _cors_headers().items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

        def do_GET(self):
            self._send(200, {'service': 'COS Sign Server', 'status': 'running', 'hint': 'POST to /sign with {"key": "..."}'})

        def do_OPTIONS(self):
            self._send(200, {})

        def do_POST(self):
            try:
                raw = self.rfile.read(int(self.headers.get('Content-Length', 0) or 0)).decode('utf-8')
            except Exception:
                raw = ''
            status, data = _handle_sign({'httpMethod': 'POST', 'path': self.path, 'body': raw})
            self._send(status, data)

    port = int(os.environ.get('PORT', 9000))
    print(f"COS Sign Server starting on port {port}...")
    print(f"Bucket: {BUCKET}  Region: {REGION}")
    HTTPServer(('0.0.0.0', port), SignHandler).serve_forever()
