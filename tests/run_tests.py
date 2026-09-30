"""Run with Python + lupa (LuaJIT 2.1 matches Ashita's Lua 5.1 semantics)."""
from pathlib import Path
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'vendor'))
from lupa.luajit21 import LuaRuntime

os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = './?.lua;' .. package.path")
for path in ROOT.rglob('*.lua'):
    if 'cache' in path.parts or 'vendor' in path.parts: continue
    lua.execute('assert(loadfile(...))', str(path))
print('PASS: all addon Lua files compile under LuaJIT 2.1.', flush=True)
lua.execute((ROOT / 'tests' / 'test_planner.lua').read_text())
lua.execute((ROOT / 'tests' / 'test_addon.lua').read_text())
