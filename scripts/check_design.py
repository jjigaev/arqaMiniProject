"""Check documented palette against the single Dart theme owner."""

import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
document = (root / "DESIGN.md").read_text(encoding="utf-8")
theme = (root / "frontend/lib/theme.dart").read_text(encoding="utf-8")
colors = dict(re.findall(r'^  (\w+): "#([A-Fa-f0-9]{6})"$', document, re.MULTILINE))
runtime = dict(re.findall(r"static const (\w+) = Color\(0xFF([A-Fa-f0-9]{6})\)", theme))
assert colors == runtime, f"Palette drift: {colors} != {runtime}"
print(f"Design palette verified: {len(colors)} tokens")
