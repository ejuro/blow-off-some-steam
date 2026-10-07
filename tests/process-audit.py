#!/usr/bin/env python3
"""Static guard: every QML process launch keeps the hardened pattern.

Each `Process` must clear its environment (directly, or by being a
DesktopProcess), and every command or exec() call must start with an absolute
/usr/bin executable. This keeps new helpers from reintroducing PATH lookups or
inherited loader settings.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
problems = []
for path in sorted(ROOT.glob('*.qml')):
    text = path.read_text()
    for match in re.finditer(r'(?m)^\s*Process\s*\{', text):
        # The body up to the matching brace at the same indentation.
        indent = len(match.group(0)) - len(match.group(0).lstrip())
        end = re.compile(r'(?m)^' + ' ' * indent + r'\}').search(text, match.end())
        body = text[match.end():end.start() if end else len(text)]
        if 'clearEnvironment: true' not in body:
            problems.append(f'{path.name}: Process without clearEnvironment (use DesktopProcess)')
    for match in re.finditer(r'(?:command:\s*|\.exec\()\s*\[\s*([\'"])(.*?)\1', text):
        if not match.group(2).startswith('/usr/bin/'):
            problems.append(f'{path.name}: command does not start with an absolute /usr/bin path: {match.group(2)}')
assert not problems, '\n'.join(problems)
print('Process audit: every launch clears its environment and uses an absolute /usr/bin executable.')
