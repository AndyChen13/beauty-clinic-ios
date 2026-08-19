#!/usr/bin/env python3
import plistlib

path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Info.plist'
with open(path, 'rb') as f:
    plist = plistlib.load(f)

# Fix ATS for proxy
plist['NSAppTransportSecurity'] = {
    'NSAllowsArbitraryLoads': True,
    'NSAllowsLocalNetworking': True,
    'NSExceptionDomains': {
        'supabase.co': {
            'NSExceptionAllowsInsecureHTTPLoads': False,
            'NSExceptionMinimumTLSVersion': 'TLSv1.2',
            'NSExceptionRequiresForwardSecrecy': False,
            'NSIncludesSubdomains': True
        }
    }
}

with open(path, 'wb') as f:
    plistlib.dump(plist, f)

print('Info.plist updated for proxy compatibility')
