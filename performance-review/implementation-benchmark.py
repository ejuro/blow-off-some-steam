import pathlib, subprocess, time, os, json, statistics, argparse

BASE = pathlib.Path('/tmp/blow-off-some-steam-benchmark'); BASE.mkdir(exist_ok=True)
REPO = pathlib.Path(__file__).resolve().parent.parent
src = (REPO / 'Arena.qml').read_text()
src = src.replace('import qs.Commons', '').replace('Color.accent', '"#aabbcc"')
src = src.replace('WlrKeyboardFocus.Exclusive', 'WlrKeyboardFocus.None')
src = src.replace('width: window.width\n      height: window.height\n    }', '') if False else src
src = src.replace('mask: Region {\n      width: window.width\n      height: window.height\n    }', 'mask: Region {}')
src = src.replace('enabled: root.armed\n      hoverEnabled: true', 'enabled: false\n      hoverEnabled: true')
# Silence test playback only; retain all SoundEffect objects and real simulation.
src = src.replace('volume: ', 'muted: true; volume: ')
src = src.replace('id: root\n', '''id: root
  property int benchTicks: 0
  property int benchPaints: 0
  property double benchLast: 0
  property var benchIntervals: []
  property int benchMaxParticles: 0
  property int benchTerrainPaints: 0
  property int benchFalls: 0
''', 1)
src = src.replace('var oldGunX = root.gunX', '''var now = Date.now()
      if (root.benchLast) root.benchIntervals.push(now-root.benchLast)
      root.benchLast = now
      root.benchTicks++
      root.benchMaxParticles = Math.max(root.benchMaxParticles, root.particles.length)
      var oldGunX = root.gunX''')
src = src.replace('      // Bound catch-up', '      var now = Date.now()\n      if (root.benchLast) root.benchIntervals.push(now-root.benchLast)\n      root.benchLast = now\n      root.benchTicks++\n      root.benchMaxParticles = Math.max(root.benchMaxParticles, root.particles.length)\n      // Bound catch-up')
src = src.replace('var c = getContext("2d")\n        c.clearRect', 'root.benchPaints++\n        var c = getContext("2d")\n        c.clearRect')
src = src.replace('if (!root.armed) return\n          var c', 'if (!root.armed) return\n          root.benchTerrainPaints++\n          var c')
src = src.replace('region.destroyed = true', 'root.benchFalls++\n    region.destroyed = true')
BASE.joinpath('snapshot.ppm').write_bytes(b'P6\n3072 1728\n255\n' + bytes([45,55,65]) * (3072*1728))

def prepare(name):
    d = BASE / name
    d.mkdir(exist_ok=True)
    for asset in ('assets', 'sounds'):
        if not (d/asset).exists(): (d/asset).symlink_to(REPO/asset)
    for component in list(REPO.glob('*.qml')) + list(REPO.glob('*.js')):
        if component.name != 'Arena.qml': (d/component.name).write_text(component.read_text())
    code = src
    if name == 'aim_no_effects': code = code.replace('canvas.requestPaint()', 'void 0')
    if name in ('aim_dirty', 'aim_dirty_clear'): code = code.replace('canvas.requestPaint()', 'canvas.markDirty(Qt.rect(root.gunX-150, root.gunY-150, 300, 300))')
    if name == 'aim_dirty_clear':
        code = code.replace('root.benchPaints++', 'var dirty = region\n        root.benchPaints++').replace('c.clearRect(0, 0, width, height)\n        c.globalAlpha', 'c.clearRect(dirty.x, dirty.y, dirty.width, dirty.height)\n        c.globalAlpha')
    if name == 'aim_small_canvas': code = code.replace('id: canvas\n      anchors.fill: parent', 'id: canvas\n      width: 400; height: 300')
    if name == 'destruction_no_terrain': code = code.replace('markDirty(dirtyArea)', 'void 0')
    (d/'Arena.qml').write_text(code)
    moving = name not in ('idle', 'holstered')
    firing = name in ('auto', 'auto_no_effects', 'destruction', 'rockets', 'falling', 'destruction_no_effects', 'destruction_no_terrain')
    if name in ('auto_no_effects','destruction_no_effects'):
        (d/'Arena.qml').write_text(code.replace('canvas.requestPaint()', 'void 0'))
    setup = 'arena.arm("%s");' % ('thick-bazooka' if name == 'rockets' else 'mp5a3')
    if name == 'holstered': setup = ''
    if name in ('destruction','falling','destruction_no_effects','destruction_no_terrain'):
        setup = '''arena.destructionEnabled = true;
        arena.desktopSnapshot = "file:///tmp/blow-off-some-steam-benchmark/snapshot.ppm";
        arena.wallpaperSource = arena.desktopSnapshot;
        var regions = [];
        for (var i=0; i<12; i++) regions.push({id:"r"+i,kind:"window",x:600+(i%4)*500,y:100+Math.floor(i/4)*480,width:460,height:440,hits:0,limit:120,destroyed:false});
        arena.destructibles = regions;
        arena.equip("mp5a3",false);'''

    (d/'shell.qml').write_text('''import Quickshell
import QtQuick
ShellRoot {
  Arena { id: arena }
  property int step: 0
  property int fallIndex: 0
  Timer { interval: 650; running: FALLING; repeat: true; onTriggered: { if(arena.armed && fallIndex < arena.destructibles.length) { var r=arena.destructibles[fallIndex++]; if (!r.destroyed) arena.destroyRegion(r); } } }
  Timer { interval: 300; running: true; onTriggered: { SETUP arena.gunPositioned=true; arena.gunX=300; arena.gunY=700; } }
  Timer { interval: 16; running: MOVING; repeat: true; onTriggered: {
    step++; arena.pointerX=1500+900*Math.sin(step*0.013); arena.pointerY=800+500*Math.cos(step*0.017);
  } }
  Timer { interval: SHOT_INTERVAL; running: FIRING; repeat: true; onTriggered: if(arena.armed) arena.shoot(false) }
  Timer { interval: 2300; running: true; onTriggered: {
    arena.benchTicks=0; arena.benchPaints=0; arena.benchIntervals=[]; arena.benchMaxParticles=0; arena.benchTerrainPaints=0; arena.benchFalls=0;
    console.log("BENCH_START");
  } }
  Timer { interval: 8300; running: true; onTriggered: {
    console.log("BENCH_RESULT " + JSON.stringify({ticks:arena.benchTicks,paints:arena.benchPaints,intervals:arena.benchIntervals,maxParticles:arena.benchMaxParticles,terrainPaints:arena.benchTerrainPaints,falls:arena.benchFalls}));
    arena.holster(); Qt.quit();
  } }
}'''.replace('FALLING',str(name=='falling').lower()).replace('SETUP',setup).replace('MOVING',str(moving).lower()).replace('FIRING',str(firing).lower()).replace('SHOT_INTERVAL','550' if name=='rockets' else '66'))
    return d

def cpu(pid):
    fields = pathlib.Path(f'/proc/{pid}/stat').read_text().split(') ')[1].split()
    return (int(fields[11])+int(fields[12])) / os.sysconf('SC_CLK_TCK')

results=[]
names=['holstered','idle','aim','auto','rockets','destruction','falling']
parser=argparse.ArgumentParser(); parser.add_argument('--scenarios'); parser.add_argument('--passes',type=int,default=2); parser.add_argument('--output',default='results.json'); args=parser.parse_args()
if args.scenarios:
  selected=args.scenarios.split(',')
  if not set(selected).issubset(names): parser.error('Use only: '+','.join(names))
  names=selected
for passnum in range(args.passes):
  for name in names:
    d=prepare(name)
    logfile=d/f'pass{passnum}.log'
    with logfile.open('w') as log:
      p=subprocess.Popen(['quickshell','-p',str(d/'shell.qml'),'--no-color'],stdout=log,stderr=subprocess.STDOUT)
      try:
        start=time.monotonic(); sample=None
        while p.poll() is None and time.monotonic()-start<14:
          if sample is None and 'BENCH_START' in logfile.read_text(): sample=(time.monotonic(),cpu(p.pid))
          if sample: last=(time.monotonic(),cpu(p.pid))
          time.sleep(.1)
        if p.poll() is None: p.terminate(); p.wait(timeout=3)
      finally:
        if p.poll() is None: p.kill(); p.wait()
    lines=logfile.read_text().splitlines()
    found=[x.split('BENCH_RESULT ',1)[1] for x in lines if 'BENCH_RESULT ' in x]
    if not found:
      print('\n'.join(lines[-15:]),flush=True); raise SystemExit('Harness failed')
    result=json.loads(found[-1]); intervals=sorted(result.pop('intervals'))
    result.update(name=name,passnum=passnum,cpu_percent=round(100*(last[1]-sample[1])/(last[0]-sample[0]),1),tick_p50=statistics.median(intervals) if intervals else 0,tick_p95=intervals[int(.95*(len(intervals)-1))] if intervals else 0,tick_max=max(intervals,default=0))
    results.append(result); print(json.dumps(result),flush=True)
    (BASE/args.output).write_text(json.dumps(results,indent=2))
