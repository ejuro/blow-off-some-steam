import Quickshell.Io

// Desktop helpers need session socket locations, not arbitrary loader settings.
// Every caller must also use an absolute executable path and separate arguments.
Process {
  clearEnvironment: true
  environment: ({
    PATH: '/usr/bin',
    LANG: 'C.UTF-8',
    XDG_RUNTIME_DIR: null,
    WAYLAND_DISPLAY: null,
    HYPRLAND_INSTANCE_SIGNATURE: null
  })
}
