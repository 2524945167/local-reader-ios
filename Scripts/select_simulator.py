#!/usr/bin/env python3
import json, re, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
candidates = []
for runtime, devices in data['devices'].items():
    # Match the pinned Xcode 16.4 SDK, not the newest runtime from another Xcode.
    if not runtime.endswith('.iOS-18-5'):
        continue
    version = tuple(map(int, re.findall(r'\d+', runtime.split('.iOS-')[1])))
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((version, device['name'], device['udid']))
if not candidates:
    raise SystemExit('No available iOS 18.5 iPhone simulator for Xcode 16.4; refusing to use an incompatible runtime.')
print('SIMULATOR_ID=' + sorted(candidates)[-1][2])
