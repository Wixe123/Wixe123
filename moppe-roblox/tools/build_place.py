#!/usr/bin/env python3
"""Builds Moppe.rbxlx (a Roblox place file) from src/ without Rojo.

Usage: python3 tools/build_place.py   (run from moppe-roblox/)
Same structure as default.project.json:
  src/shared/*.lua        -> ReplicatedStorage.Shared (ModuleScript)
  src/server/*.server.lua -> ServerScriptService (Script)
  src/client/*.client.lua -> StarterPlayer.StarterPlayerScripts (LocalScript)
"""
import os, sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ref = 0


def item(cls, name, source=None, children=''):
    global ref
    ref += 1
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        if ']]>' in source:
            sys.exit('%s contains ]]> and cannot be placed in CDATA' % name)
        props += '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % source
    return '<Item class="%s" referent="RBX%d"><Properties>%s</Properties>%s</Item>\n' % (cls, ref, props, children)


def scripts(folder, suffix, cls):
    out = ''
    d = os.path.join(ROOT, 'src', folder)
    for f in sorted(os.listdir(d)):
        if f.endswith('.lua'):
            name = f[:-len(suffix)] if f.endswith(suffix) else f[:-4]
            out += item(cls, name, open(os.path.join(d, f), encoding='utf-8').read())
    return out


xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
       + item('Workspace', 'Workspace')
       + item('Lighting', 'Lighting')
       + item('ReplicatedStorage', 'ReplicatedStorage', None, item('Folder', 'Shared', None, scripts('shared', '.lua', 'ModuleScript')))
       + item('ServerScriptService', 'ServerScriptService', None, scripts('server', '.server.lua', 'Script'))
       + item('StarterPlayer', 'StarterPlayer', None, item('StarterPlayerScripts', 'StarterPlayerScripts', None, scripts('client', '.client.lua', 'LocalScript')))
       + '</roblox>\n')
out = os.path.join(ROOT, 'Moppe.rbxlx')
open(out, 'w', encoding='utf-8').write(xml)
print('skrev', out, len(xml), 'tecken')
