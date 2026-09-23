"""Security regressions using synthetic snapshots, never desktop screenshots."""
import importlib.util
import json
import os
from pathlib import Path
import select
import signal
import socket
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


capture = load('capture_worker')
audio = load('audio_worker')


class Security(unittest.TestCase):
    def test_runtime_and_atomic_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            runtime = parent / 'runtime'
            runtime.mkdir(mode=0o700)
            link = parent / 'link'
            link.symlink_to(runtime)
            for invalid in ('', '/', 'relative', str(link)):
                with self.assertRaises((OSError, ValueError)):
                    capture.open_runtime(invalid)
            runtime.chmod(0o755)
            with self.assertRaises(ValueError):
                capture.open_runtime(str(runtime))
            runtime.chmod(0o700)
            descriptor = capture.open_runtime(str(runtime))
            try:
                victim = parent / 'victim'
                victim.write_text('untouched')
                collision = runtime / ('blow-off-some-steam-' + 'a' * 32 + '.ppm')
                collision.symlink_to(victim)
                with patch.object(capture.secrets, 'token_hex', return_value='a' * 32):
                    with self.assertRaises(FileExistsError):
                        capture.create_snapshot(descriptor)
                self.assertEqual(victim.read_text(), 'untouched')
                name, snapshot = capture.create_snapshot(descriptor)
                try:
                    self.assertEqual(stat.S_IMODE(os.fstat(snapshot).st_mode), 0o600)
                finally:
                    os.close(snapshot)
                os.unlink(name, dir_fd=descriptor)
            finally:
                os.close(descriptor)

    def test_foreign_runtime_owner_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(capture.os, 'getuid', return_value=os.getuid() + 1):
                with self.assertRaises(ValueError):
                    capture.open_runtime(directory)

    def test_worker_responses(self):
        for message in (None, [], {'event': 'unknown'},
                        {'event': 'state', 'key': '__proto__', 'status': 2, 'playing': True},
                        {'event': 'state', 'key': 'voice-1', 'status': True, 'playing': True},
                        {'event': 'state', 'key': 'voice-1', 'status': 4, 'playing': True},
                        {'event': 'state', 'key': 'voice-1', 'status': 2, 'playing': 'yes'}):
            self.assertIsNone(audio.worker_response(message), message)
        self.assertEqual(audio.worker_response({'event': 'ready', 'extra': 'secret'}), {'event': 'ready'})
        state = dict(event='state', key='voice-1', status=2, playing=False)
        self.assertEqual(audio.worker_response(dict(state, extra='secret')), state)

    def test_socket_peer_identity(self):
        left, right = socket.socketpair()
        try:
            self.assertTrue(audio.worker_peer(left, os.getpid()))
            self.assertFalse(audio.worker_peer(left, os.getpid() + 1))
        finally:
            left.close()
            right.close()

    def test_capture_lifecycle(self):
        # Replace only the external screen-capture program, leaving real file
        # creation, process supervision, environment building and cleanup intact.
        for ending in ('eof', 'terminate', 'failure', 'capturing-eof', 'capturing-terminate'):
            with self.subTest(ending=ending), tempfile.TemporaryDirectory() as directory:
                fake = "import sys; sys.stdout.buffer.write(b'P6\\n1 1\\n255\\n\\0\\0\\0'); sys.stdout.flush()"
                if ending == 'failure':
                    fake = 'raise SystemExit(1)'
                elif ending.startswith('capturing-'):
                    fake = 'import time; time.sleep(60)'
                driver = f'''
import importlib.util, subprocess, sys
spec = importlib.util.spec_from_file_location('capture', {str(ROOT / 'capture_worker.py')!r})
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
original = subprocess.Popen
def substitute(command, **kwargs):
    assert command == ['/usr/bin/grim', '-o', 'test;$(touch unwanted)', '-s', '1', '-t', 'ppm', '-'], command
    assert set(kwargs['env']) == {{'PATH', 'LANG', 'XDG_RUNTIME_DIR', 'WAYLAND_DISPLAY'}}, kwargs['env'].keys()
    return original(['/usr/bin/python3', '-I', '-S', '-c', {fake!r}], **kwargs)
module.subprocess.Popen = substitute
sys.argv = ['capture_worker.py', 'test;$(touch unwanted)']
sys.exit(module.main())
'''
                environment = dict(os.environ, XDG_RUNTIME_DIR=directory, WAYLAND_DISPLAY='test',
                                   STEAM_TEST_SECRET='not-forwarded')
                process = subprocess.Popen(['/usr/bin/python3', '-I', '-S', '-c', driver],
                                           env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE)
                try:
                    if ending.startswith('capturing-'):
                        import time
                        deadline = time.monotonic() + 3
                        while not list(Path(directory).glob('*.ppm')) and time.monotonic() < deadline:
                            time.sleep(.05)
                        self.assertTrue(list(Path(directory).glob('*.ppm')))
                    else:
                        self.assertTrue(select.select([process.stdout], [], [], 4)[0])
                        line = process.stdout.readline()
                        if ending != 'failure':
                            path = Path(unquote(urlsplit(json.loads(line)['url']).path))
                            self.assertEqual(path.parent, Path(directory))
                            self.assertEqual(path.read_bytes(), b'P6\n1 1\n255\n\0\0\0')
                            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                    if ending.endswith('eof'):
                        process.stdin.close()
                    elif ending.endswith('terminate'):
                        process.terminate()
                    process.wait(timeout=4)
                    self.assertEqual(process.returncode, 1 if ending == 'failure' else 0,
                                     process.stderr.read().decode())
                    self.assertEqual(list(Path(directory).iterdir()), [])
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    for stream in (process.stdin, process.stdout, process.stderr):
                        stream.close()


if __name__ == '__main__':
    unittest.main(verbosity=2)
