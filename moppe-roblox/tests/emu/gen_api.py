#!/usr/bin/env python3
"""Generates api_data.lua from Roblox's API dump.

Usage: curl -sSLO https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
       python3 gen_api.py API-Dump.json
Only members a game script may use are kept (security None/PluginSecurity for reading).
"""
import json, sys

d = json.load(open(sys.argv[1]))
s = json.dumps
out = ['-- Generated from the Roblox API dump (MaximumADHD/Roblox-Client-Tracker) by gen_api.py. Do not edit.', 'local C, E = {}, {}']
for c in sorted(d['Classes'], key=lambda c: c['Name']):
    P, M, EV, CB = {}, [], [], []
    for m in c['Members']:
        sec = m.get('Security', {})
        r, w = (sec.get('Read', 'None'), sec.get('Write', 'None')) if isinstance(sec, dict) else (sec, sec)
        tags = m.get('Tags', [])
        if m['MemberType'] == 'Property':
            if r not in ('None', 'PluginSecurity'):
                continue
            P[m['Name']] = [m['ValueType']['Category'], m['ValueType']['Name'], 1 if ('ReadOnly' in tags or w != 'None') else 0, 1 if 'Deprecated' in tags else 0]
        elif m['MemberType'] == 'Function' and r == 'None':
            M.append(m['Name'])
        elif m['MemberType'] == 'Event' and r == 'None':
            EV.append(m['Name'])
        elif m['MemberType'] == 'Callback':
            CB.append(m['Name'])
    props = ','.join('[%s]={%s,%s,%d,%d}' % (s(k), s(v[0]), s(v[1]), v[2], v[3]) for k, v in sorted(P.items()))
    out.append('C[%s]={s=%s,p={%s},m={%s},e={%s},c={%s},t={%s}}' % (s(c['Name']), s(c['Superclass']), props, ','.join(map(s, M)), ','.join(map(s, EV)), ','.join(map(s, CB)), ','.join(map(s, c.get('Tags', [])))))
for e in sorted(d['Enums'], key=lambda e: e['Name']):
    out.append('E[%s]={%s}' % (s(e['Name']), ','.join('[%s]=%d' % (s(i['Name']), i['Value']) for i in e['Items'])))
out.append('return {C=C,E=E}')
open('api_data.lua', 'w').write('\n'.join(out) + '\n')
print('wrote api_data.lua')
