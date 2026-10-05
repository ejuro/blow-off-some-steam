#!/usr/bin/python3
"""Integration check: trusted launch, environment isolation, playback and cleanup.

Run with /usr/bin/python3 tests/audio_launch.py in a desktop audio session.
All test sounds have zero volume; the desktop shell is not restarted.
"""
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def wait(check, timeout=10):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        result = check()
        if result:
            return result
        time.sleep(.1)
    raise AssertionError('timed out waiting for condition')


def gone(pid):
    try:
        return Path(f'/proc/{pid}/stat').read_text().split(') ')[1].startswith('Z')
    except FileNotFoundError:
        return True


def environment(pid):
    return dict(entry.split(b'=', 1) for entry in Path(f'/proc/{pid}/environ').read_bytes().split(b'\0') if entry)


with tempfile.TemporaryDirectory(prefix='steam-launch-test-') as temporary:
    folder = Path(temporary)
    shadow = folder / 'bin'
    shadow.mkdir()
    marker = folder / 'shadow-ran'
    for name in ('python3', 'qs'):
        executable = shadow / name
        executable.write_text(f'#!/bin/sh\n/usr/bin/touch "{marker}"\nexit 99\n')
        executable.chmod(0o700)
    (shadow / 'sitecustomize.py').write_text(f'open({str(marker)!r}, "w").close()\n')
    config = folder / 'Test.qml'
    config.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "''' + ROOT.as_uri() + '''"
Scope {
  id: scope
  property var desktopEnvironment: null
  DesktopProcess {
    command: ['/usr/bin/python3', '-I', '-S', '-c', 'import json, os; print(json.dumps(dict(os.environ)))']
    running: true
    stdout: StdioCollector {
      onStreamFinished: scope.desktopEnvironment = JSON.parse(text)
    }
  }
  AudioBridge { id: bridge }
  RemoteSound { id: sound; audio: bridge; volume: 0; loops: -2
    source: "''' + (ROOT / 'sounds/automatic-fire.wav').as_uri() + '''" }
  IpcHandler {
    target: "test"
    function start(): void { bridge.active = true; sound.play() }
    function stop(): void { bridge.active = false }
    function status(): string { return JSON.stringify({pid: bridge.workerPid,
      ready: bridge.ready, failed: bridge.failed, playing: sound.playing,
      desktopEnvironment: scope.desktopEnvironment}) }
  }
}
''')
    env = dict(os.environ)
    runtime = env.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    env.update(PATH=str(shadow) + ':/usr/bin', PYTHONPATH=str(shadow),
               PYTHONHOME=str(shadow), LD_LIBRARY_PATH=str(shadow),
               QT_PLUGIN_PATH=str(shadow), QML_IMPORT_PATH=str(shadow),
               STEAM_TEST_SECRET='must-not-reach-workers',
               PIPEWIRE_RUNTIME_DIR=env.get('PIPEWIRE_RUNTIME_DIR', runtime),
               PULSE_SERVER=env.get('PULSE_SERVER', 'unix:' + runtime + '/pulse/native'),
               XDG_RUNTIME_DIR=temporary, QT_QPA_PLATFORM='offscreen',
               QT_QPA_PLATFORMTHEME='basic', QSG_RHI_BACKEND='software')
    # IPC clients do not need the deliberately poisoned environment.
    client_env = dict(os.environ, XDG_RUNTIME_DIR=temporary)
    def call(method):
        return subprocess.check_output(['/usr/bin/qs', 'ipc', '-p', str(config),
                                        'call', 'test', method], env=client_env,
                                       stderr=subprocess.DEVNULL, text=True, timeout=3).strip()
    def status():
        try:
            return json.loads(call('status'))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return {}
    with (folder / 'parent.log').open('w') as log:
        parent = subprocess.Popen(['/usr/bin/qs', '-p', str(config)], env=env,
                                  stdout=log, stderr=log)
        child = supervisor = 0
        try:
            wait(lambda: status().get('desktopEnvironment'))
            desktop_environment = status()['desktopEnvironment']
            assert set(desktop_environment) <= {'PATH', 'LANG', 'XDG_RUNTIME_DIR',
                                                'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE'}
            assert desktop_environment['PATH'] == '/usr/bin'
            print('PASS desktop helpers clear inherited environment', flush=True)
            for mode in ('close', 'child-crash', 'supervisor-kill', 'child-hang'):
                call('start')
                wait(lambda: status().get('playing'))
                supervisor = status()['pid']
                child = int(Path(f'/proc/{supervisor}/task/{supervisor}/children').read_text().split()[0])
                args = Path(f'/proc/{supervisor}/cmdline').read_bytes().split(b'\0')
                assert args[:3] == [b'/usr/bin/python3', b'-I', b'-S'], args
                args = Path(f'/proc/{child}/cmdline').read_bytes().split(b'\0')
                assert args[0] == b'/usr/bin/qs', args
                forbidden = {b'PYTHONPATH', b'PYTHONHOME', b'LD_LIBRARY_PATH',
                             b'QT_PLUGIN_PATH', b'QML_IMPORT_PATH', b'STEAM_TEST_SECRET'}
                for pid in (supervisor, child):
                    values = environment(pid)
                    assert not forbidden.intersection(values), forbidden.intersection(values)
                    assert values[b'PATH'] == b'/usr/bin'
                worker_runtime = Path(os.fsdecode(environment(child)[b'XDG_RUNTIME_DIR']))
                # Hardware codec probing would delay the first sound by about a second.
                assert environment(child).get(b'QT_FFMPEG_ENCODING_HW_DEVICE_TYPES') == b',', 'hardware probing enabled'
                assert environment(child).get(b'QT_FFMPEG_DECODING_HW_DEVICE_TYPES') == b',', 'hardware probing enabled'
                assert not marker.exists(), 'shadow executable or Python startup hook ran'
                assert 'libQt6Multimedia' not in Path(f'/proc/{parent.pid}/maps').read_text()
                if mode == 'close':
                    call('stop')
                elif mode == 'child-crash':
                    os.kill(child, signal.SIGKILL)
                elif mode == 'supervisor-kill':
                    os.kill(supervisor, signal.SIGKILL)
                else:
                    os.kill(child, signal.SIGSTOP)
                wait(lambda: gone(child) and gone(supervisor), timeout=12)
                if mode != 'close':
                    wait(lambda: status().get('failed'))
                    call('stop')
                if mode != 'supervisor-kill':
                    assert not worker_runtime.exists(), 'worker directory was not cleaned'
                else:
                    # SIGKILL cannot run Python's directory cleanup. Both
                    # processes are gone; remove this test's private directory.
                    shutil.rmtree(worker_runtime)
                print('PASS trusted launch, clean environment, silent playback,', mode, flush=True)
                child = supervisor = 0
            assert parent.poll() is None
        except Exception:
            print((folder / 'parent.log').read_text())
            raise
        finally:
            parent.terminate()
            try:
                parent.wait(timeout=4)
            except subprocess.TimeoutExpired:
                parent.kill()
                parent.wait()
            for pid in (supervisor, child):
                if pid and not gone(pid):
                    os.kill(pid, signal.SIGKILL)
