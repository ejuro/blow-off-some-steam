#!/usr/bin/python3 -I
"""Own one private snapshot until the QML session closes this process's stdin."""
import ctypes
import json
import os
from pathlib import Path
import resource
import secrets
import select
import signal
import stat
import subprocess
import sys
import time


def open_runtime(path):
    if not path or not os.path.isabs(path) or path == '/':
        raise ValueError('private runtime directory is unavailable')
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    info = os.fstat(descriptor)
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        os.close(descriptor)
        raise ValueError('runtime directory must be owned by this user with mode 0700')
    return descriptor


def create_snapshot(directory):
    # Creation and deletion are relative to the validated directory descriptor.
    # Never follow or truncate an existing file, even on a name collision.
    for _ in range(8):
        name = 'blow-off-some-steam-' + secrets.token_hex(16) + '.ppm'
        try:
            descriptor = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                 0o600, dir_fd=directory)
            return name, descriptor
        except FileExistsError:
            continue
    raise FileExistsError('could not allocate a private snapshot')


def child_setup(parent):
    # Bound output and prevent a hung grim surviving a forcibly killed owner.
    resource.setrlimit(resource.RLIMIT_FSIZE, (256 * 1024 * 1024,) * 2)
    if ctypes.CDLL(None).prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid() != parent:
        os._exit(1)


def main():
    stopped = False

    def stop(*_):
        nonlocal stopped
        stopped = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    directory = None
    name = None
    child = None
    try:
        runtime = os.environ.get('XDG_RUNTIME_DIR', '')
        directory = open_runtime(runtime)
        name, descriptor = create_snapshot(directory)
        env = dict(PATH='/usr/bin', LANG='C.UTF-8', XDG_RUNTIME_DIR=runtime)
        if os.environ.get('WAYLAND_DISPLAY'):
            env['WAYLAND_DISPLAY'] = os.environ['WAYLAND_DISPLAY']
        command = ['/usr/bin/grim']
        if len(sys.argv) == 2 and sys.argv[1]:
            command.extend(['-o', sys.argv[1]])
        command.extend(['-s', '1', '-t', 'ppm', '-'])
        parent = os.getpid()
        with os.fdopen(descriptor, 'wb') as snapshot:
            child = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL,
                                     stdout=snapshot, stderr=subprocess.DEVNULL,
                                     start_new_session=True, preexec_fn=lambda: child_setup(parent))
        deadline = time.monotonic() + 15
        announced = False
        while not stopped:
            # EOF also handles abrupt shell death, including during capture.
            if select.select([0], [], [], .1)[0] and not os.read(0, 1024):
                break
            result = child.poll()
            if not announced:
                if result is not None:
                    if result != 0:
                        return 1
                    print(json.dumps({'url': (Path(runtime) / name).as_uri()}), flush=True)
                    announced = True
                elif time.monotonic() >= deadline:
                    return 1
        return 0
    except (OSError, ValueError):
        return 1
    finally:
        if child and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=1)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        if directory is not None:
            if name:
                try:
                    os.unlink(name, dir_fd=directory)
                except FileNotFoundError:
                    pass
            os.close(directory)


if __name__ == '__main__':
    sys.exit(main())
