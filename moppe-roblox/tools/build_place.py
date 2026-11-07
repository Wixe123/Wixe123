#!/usr/bin/env python3
"""Builds Moppe.rbxlx (a Roblox place file) from src/ without Rojo.

Usage: python3 tools/build_place.py   (from moppe-roblox/)
Same layout as default.project.json:
  src/shared/*.lua          -> ReplicatedStorage.Shared (ModuleScript)
  src/server/*.server.lua   -> ServerScriptService (Script), other .lua there -> ModuleScript
  src/client/*.client.lua   -> StarterPlayer.StarterPlayerScripts (LocalScript), other .lua there -> ModuleScript
Lighting is saved with Technology = Future (a script cannot set it).
"""
import os, sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ref = 0


def item(cls, name, source=None, children='', extra=''):
    global ref
    ref += 1
    props = '<string name="Name">%s</string>' % escape(name) + extra
    if source is not None:
        if ']]>' in source:
            sys.exit('%s contains ]]> and cannot be placed in CDATA' % name)
        props += '<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>' % source
    return '<Item class="%s" referent="RBX%d"><Properties>%s</Properties>%s</Item>\n' % (cls, ref, props, children)


def scripts(folder, suffix, cls):
    out = ''
    d = os.path.join(ROOT, 'src', folder)
    for f in sorted(os.listdir(d)):
        if not f.endswith('.lua'):
            continue
        src = open(os.path.join(d, f), encoding='utf-8').read()
        if suffix and f.endswith(suffix):
            out += item(cls, f[:-len(suffix)], src)
        else:
            out += item('ModuleScript', f[:-4], src)
    return out


lighting = ('<token name="Technology">4</token>'
            '<float name="ClockTime">14.5</float>'
            '<float name="Brightness">2.2</float>'
            '<bool name="GlobalShadows">true</bool>')
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
       + item('Workspace', 'Workspace')
       + item('Lighting', 'Lighting', extra=lighting)
       + item('ReplicatedStorage', 'ReplicatedStorage', None, item('Folder', 'Shared', None, scripts('shared', None, 'ModuleScript')))
       + item('ServerScriptService', 'ServerScriptService', None, scripts('server', '.server.lua', 'Script'))
       + item('StarterPlayer', 'StarterPlayer', None, item('StarterPlayerScripts', 'StarterPlayerScripts', None, scripts('client', '.client.lua', 'LocalScript')))
       + '</roblox>\n')
out = os.path.join(ROOT, 'Moppe.rbxlx')
open(out, 'w', encoding='utf-8').write(xml)
print('skrev', out, len(xml), 'tecken')
