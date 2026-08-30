#!/bin/bash

echo "Testing API connection to andychenpersonal.top"
echo ""

echo "1. Testing /health endpoint:"
curl -s -I https://andychenpersonal.top/health | head -5
echo ""

echo "2. Testing /api/stores endpoint:"
curl -s -I https://andychenpersonal.top/api/stores | head -5
echo ""

echo "3. TLS version check:"
openssl s_client -connect andychenpersonal.top:443 </dev/null 2>&1 | grep "Protocol"
