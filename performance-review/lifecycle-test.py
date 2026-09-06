import pathlib, subprocess, shutil
source=pathlib.Path(__file__).resolve().parent.parent
base=pathlib.Path('/tmp/blow-off-some-steam-lifecycle');base.mkdir(exist_ok=True)
for mode in ('capture','capture-failure'):
 d=base/mode;d.mkdir(exist_ok=True)
 for component in list(source.glob('*.qml'))+list(source.glob('*.js')):
  if component.name not in ('Arena.qml','BarWidget.qml','WeaponCase.qml'):shutil.copyfile(component,d/component.name)
 for asset in ('assets','sounds'):
  if not (d/asset).exists():(d/asset).symlink_to(source/asset)
 s=(source/'Arena.qml').read_text().replace('import qs.Commons','').replace('Color.accent','"#aabbcc"').replace('Util.fileUrl(String(text || "").trim())','"file://" + String(text || "").trim()').replace('WlrKeyboardFocus.Exclusive','WlrKeyboardFocus.None').replace('mask: Region {\n      width: window.width\n      height: window.height\n    }','mask: Region {}').replace('volume: ','muted: true; volume: ').replace('enabled: root.armed\n      hoverEnabled: true','enabled: false\n      hoverEnabled: true')
 if mode=='capture-failure':s=s.replace('captureProcess.exec(command)','captureProcess.exec(["false"])')
 s=s.replace('  id: root','''  id: root
  function verifySession(expectCapture) {
    if (!armed || captureInProgress || (expectCapture && (!terrainReady || !destructionEnabled)) || (!expectCapture && destructionEnabled)) throw new Error("capture state incorrect");
    console.log("CAPTURE_PATH",capturePath);
    var snapshot=desktopSnapshot;
    gunX=300;gunY=300;gunPositioned=true;pointerX=800;pointerY=500;
    shoot(false);
    var count=particles.length;
    arm("ak47");
    if (weapon!=="ak47" || particles.length!==count || desktopSnapshot!==snapshot) throw new Error("swap reset session");
    openWeaponWheel(500,500);weaponWheelSelection=3;closeWeaponWheel(true);
    if(weapon!=="mp5a3" || weaponWheelOpen) throw new Error("wheel swap failed");
    holster();
    console.log("CLEAN_STATE",armed,particles.length,canvas.pool.length,simulationAwake,String(desktopSnapshot),fallingPieces.count,destroyedRegions.count);
    if(armed || particles.length || canvas.pool.length || simulationAwake || String(desktopSnapshot)!=="" || fallingPieces.count || destroyedRegions.count) throw new Error("holster cleanup failed");
    setDestructionEnabled(false);setTargetsEnabled(true);arm("revolver");spawnTarget();
    if(!armed || !targetVisible) throw new Error("rearm target failed");
    hitTarget();
    if(targetVisible || !pendingEffects.length || !simulationAwake) throw new Error("target effects failed");
    holster();
    console.log("LIFECYCLE_PASS");
  }
''',1)
 (d/'Arena.qml').write_text(s)
 (d/'shell.qml').write_text('''import Quickshell
import QtQuick
ShellRoot {
 Arena { id: arena }
 Timer { interval:300;running:true;onTriggered:{arena.targetScreen=Quickshell.screens[0];arena.setDestructionEnabled(true);arena.arm("glock");} }
 Timer { interval:2500;running:true;onTriggered:{try {arena.verifySession(EXPECT);} catch(e) {console.log("LIFECYCLE_FAIL",String(e));arena.holster();}} }
 Timer { interval:3500;running:true;onTriggered:Qt.quit() }
}'''.replace('EXPECT','true' if mode=='capture' else 'false'))
 r=subprocess.run(['quickshell','-p',str(d/'shell.qml'),'--no-color'],capture_output=True,text=True,timeout=8)
 log=r.stdout+r.stderr;(d/'run.log').write_text(log)
 if 'LIFECYCLE_PASS' not in log or 'LIFECYCLE_FAIL' in log:raise RuntimeError(log)
 for line in log.splitlines():
  if 'CAPTURE_PATH ' in line:
   path=line.split('CAPTURE_PATH ',1)[1].strip()
   if path and pathlib.Path(path).exists():raise RuntimeError('capture file not removed')
 print(mode,'PASS: swap, wheel, holster, rearm, target effects, snapshot cleanup',flush=True)
