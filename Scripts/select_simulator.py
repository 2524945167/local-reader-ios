#!/usr/bin/env python3
import json, re, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
candidates = []
for runtime, devices in data['devices'].items():
    if '.iOS-' not in runtime:
        continue
    version = tuple(map(int, re.findall(r'\d+', runtime.split('.iOS-')[1])))
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((version, device['name'], device['udid']))
if not candidates:
    raise SystemExit('No installed, available iPhone simulator; refusing to pretend tests passed.')
print('SIMULATOR_ID=' + sorted(candidates)[-1][2])
