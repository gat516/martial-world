#!/usr/bin/env python3
"""Checks that test.project.json maps everything default.project.json maps.

The testbed runs the same code and assets as the game, so every `$path` mapping
outside Workspace must appear in both projects at the same instance path
(docs/systems/testbed.md). Workspace is the testbed's own world and is skipped.
Exits 1 and lists what's missing or different.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def mappings(node, path=()):
    found = {}
    if "$path" in node:
        found["/".join(path)] = node["$path"]
    for key, child in node.items():
        if not key.startswith("$") and isinstance(child, dict):
            found.update(mappings(child, path + (key,)))
    return found


def load(name):
    tree = json.loads((ROOT / name).read_text())["tree"]
    return {k: v for k, v in mappings(tree).items() if not k.startswith("Workspace")}


game, testbed = load("default.project.json"), load("test.project.json")
problems = []
for path, source in game.items():
    if path not in testbed:
        problems.append(f"missing in test.project.json: {path} -> {source}")
    elif testbed[path] != source:
        problems.append(f"differs: {path}: game {source}, testbed {testbed[path]}")
for path, source in testbed.items():
    if path not in game:
        problems.append(f"testbed-only mapping (fine if intended): {path} -> {source}")

if problems:
    print("\n".join(problems))
    sys.exit(1 if any(not p.startswith("testbed-only") for p in problems) else 0)
print("test.project.json maps everything default.project.json does.")
