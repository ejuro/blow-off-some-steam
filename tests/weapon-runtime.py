#!/usr/bin/env python3
"""Silent integration tests against the installed shell UI, with all test windows hidden."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', str(Path.home() / '.local/share/omarchy'))) / 'shell'
assert (shell / 'Commons').is_dir(), f'Cannot locate Omarchy shell modules: {shell}'
with tempfile.TemporaryDirectory(prefix='steam-weapon-test-') as folder:
    base = Path(folder)
    for module in ('Commons', 'Ui', 'services'):
        (base / module).symlink_to(shell / module, target_is_directory=True)
    env = dict(os.environ, XDG_STATE_HOME=str(base / 'state'), QT_QPA_PLATFORM='wayland')
    for name, marker in [('drawer-open.qml', 'DRAWER_OPEN_OK'), ('arena-saber.qml', 'ARENA_SABER_OK'), ('arena-cut.qml', 'ARENA_CUT_OK')]:
        source = (ROOT / 'tests' / name).read_text().replace('import ".." as Steam', f'import "{ROOT.as_uri()}" as Steam')
        config = base / 'shell.qml'
        config.write_text(source)
        result = subprocess.run(['/usr/bin/qs', '-p', str(config), '--no-color'], env=env,
                                capture_output=True, text=True, timeout=10)
        log = result.stdout + result.stderr
        assert result.returncode == 0 and marker in log, log
        assert not any(word in log for word in ['ReferenceError', 'TypeError', 'Failed to load configuration']), log
        print(marker)
