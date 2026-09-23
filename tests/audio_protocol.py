"""Exercise malformed audio messages through the real isolated worker, silently."""
import json
import os
from pathlib import Path
import select
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def start():
    return subprocess.Popen(['/usr/bin/python3', '-I', '-S', str(ROOT / 'audio_worker.py')],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            bufsize=0, env={key: value for key, value in os.environ.items()
                                            if key in ('XDG_RUNTIME_DIR', 'PIPEWIRE_RUNTIME_DIR', 'PULSE_SERVER')})


def send(process, message):
    process.stdin.write((json.dumps(message) + '\n').encode())


def event(process):
    end = time.monotonic() + 6
    while time.monotonic() < end:
        send(process, {'op': 'ping'})
        if select.select([process.stdout], [], [], .1)[0]:
            line = process.stdout.readline()
            assert line, 'worker unexpectedly exited'
            return json.loads(line)
    raise AssertionError('worker response timed out')


process = start()
try:
    assert event(process) == {'event': 'ready'}
    valid = dict(op='create', key='voice-1', source=(ROOT / 'sounds/pistol-shot.wav').as_uri(),
                 volume=0, loops=1, music=False)
    for malformed in (None, [], 1, 'string', {'op': 'unknown'},
                      dict(valid, key='__proto__'), dict(valid, key='constructor'),
                      dict(valid, key='voice-2', volume=100), dict(valid, key='voice-3', loops=1e9),
                      dict(valid, key='voice-4', music='yes'),
                      dict(valid, key='voice-5', source='https://example.invalid/sound.wav'),
                      dict(valid, key='voice-6', source=(ROOT / 'sounds').as_uri() + '/../README.md'),
                      dict(valid, key='voice-7', source=(ROOT / 'sounds').as_uri() + '/%2e%2e/README.md'),
                      dict(valid, key='voice-8', source=valid['source'] + '?query')):
        send(process, malformed)
    process.stdin.write(b'not JSON\n' + b'[' * 2000 + b']' * 2000 + b'\n')
    send(process, valid)
    while True:
        response = event(process)
        assert response['key'] == 'voice-1', response
        if response['status'] == 2:
            break
    send(process, {'op': 'play', 'key': 'voice-1'})
    while not event(process)['playing']:
        pass
    print('PASS malformed messages, traversal/remote sources and invalid voices rejected; valid silent playback survives')
finally:
    process.stdin.close()
    process.wait(timeout=4)
    process.stdout.close()
    process.stderr.close()

process = start()
try:
    assert event(process) == {'event': 'ready'}
    process.stdin.write(b'x' * 70000)
    process.wait(timeout=4)
    assert process.returncode == 0
    print('PASS oversized unterminated message closes worker cleanly')
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=4)
    for stream in (process.stdin, process.stdout, process.stderr):
        stream.close()
