#!/usr/bin/env python3
"""Own a disposable Qt audio process; bridge the shell's private stdio protocol."""
import ctypes
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time

LIMIT = 65536


def now():
    # Include suspend time: discard old audio connections after a long sleep.
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def child_setup(expected_parent):
    # A forcibly killed supervisor must not leave a sound loop running.
    libc = ctypes.CDLL(None)
    if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid() != expected_parent:
        os._exit(1)


def main():
    child = None
    connection = None
    stopped = False

    def stop(*_):
        nonlocal stopped
        stopped = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with tempfile.TemporaryDirectory(prefix='steam-audio-') as directory:
        address = str(Path(directory) / 'control.sock')
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(address)
            listener.listen(1)
            listener.setblocking(False)
            env = dict(os.environ)
            # Isolate Quickshell logs/locks while retaining access to the user's audio server.
            runtime = env.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
            env.update(STEAM_AUDIO_SOCKET=address, XDG_RUNTIME_DIR=directory,
                       PIPEWIRE_RUNTIME_DIR=env.get('PIPEWIRE_RUNTIME_DIR', runtime),
                       PULSE_SERVER=env.get('PULSE_SERVER', 'unix:' + runtime + '/pulse/native'),
                       QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='basic',
                       QSG_RHI_BACKEND='software', QT_LOGGING_RULES='*=false')
            try:
                supervisor_pid = os.getpid()
                child = subprocess.Popen(
                    ['qs', '--path', str(Path(__file__).with_name('AudioWorker.qml')), '--log-rules', '*=false'],
                    env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL, start_new_session=True, preexec_fn=lambda: child_setup(supervisor_pid))
                os.set_blocking(0, False)
                os.set_blocking(1, False)
                last_ping = now()
                last_response = last_ping
                incoming = b''
                outgoing = b''
                replies = b''
                response_lines = b''
                while not stopped and child.poll() is None:
                    if now() - last_ping > 6 or now() - last_response > 6:
                        break
                    readers = [0, connection if connection else listener]
                    writers = ([connection] if connection and outgoing else []) + ([1] if replies else [])
                    readable, writable, _ = select.select(readers, writers, [], .2)
                    if 0 in readable:
                        data = os.read(0, 8192)
                        if not data:
                            break
                        incoming += data
                        if len(incoming) > LIMIT:
                            break
                        while b'\n' in incoming:
                            line, incoming = incoming.split(b'\n', 1)
                            try:
                                message = json.loads(line)
                            except (ValueError, UnicodeDecodeError):
                                continue
                            if not isinstance(message, dict):
                                continue
                            if message.get('op') == 'ping':
                                last_ping = now()
                            outgoing += line + b'\n'
                    if listener in readable:
                        connection, _ = listener.accept()
                        connection.setblocking(False)
                    if connection and connection in readable:
                        data = connection.recv(8192)
                        if not data:
                            break
                        response_lines += data
                        if len(response_lines) > LIMIT:
                            break
                        while b'\n' in response_lines:
                            line, response_lines = response_lines.split(b'\n', 1)
                            try:
                                response = json.loads(line)
                            except (ValueError, UnicodeDecodeError):
                                continue
                            if not isinstance(response, dict):
                                continue
                            if response.get('event') in ('ready', 'pong'):
                                last_response = now()
                            if response.get('event') != 'pong':
                                replies += line + b'\n'
                    if connection and connection in writable:
                        outgoing = outgoing[connection.send(outgoing):]
                    if 1 in writable:
                        replies = replies[os.write(1, replies):]
                    if len(outgoing) > LIMIT or len(replies) > LIMIT:
                        break
            except (OSError, BrokenPipeError):
                pass  # Missing worker or disconnected shell: audio fails closed.
            finally:
                if connection:
                    connection.close()
                if child:
                    # Include crash-handler descendants; never leave audio behind after shell exit.
                    try:
                        os.killpg(child.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    try:
                        child.wait(timeout=1)
                    except subprocess.TimeoutExpired:
                        pass
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    child.wait()
    return 0


if __name__ == '__main__':
    sys.exit(main())
