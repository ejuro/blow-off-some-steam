import pathlib, subprocess, shutil, json
BASE=pathlib.Path('/tmp/blow-off-some-steam-visual'); BASE.mkdir(exist_ok=True)
fixture=BASE/'pattern.ppm'
rowdata=[]
for y in range(1728):
 rowdata.append(bytes(v for x in range(3072) for v in ((x//7+y//11)%256,(x//13+y//5)%256,180 if (x//32+y//32)%2 else 65)))
fixture.write_bytes(b'P6\n3072 1728\n255\n'+b''.join(rowdata))
REPO=pathlib.Path(__file__).resolve().parent.parent
for variant in ('before','after'):
 for scene in ('effects','revolver','terrain'):
  d=BASE/(variant+'-'+scene); d.mkdir(exist_ok=True)
  source=REPO
  for asset in ('assets','sounds'):
   if not (d/asset).exists(): (d/asset).symlink_to(REPO/asset)
  for component in list(source.glob('*.qml'))+list(source.glob('*.js')):
   if component.name!='Arena.qml': shutil.copyfile(component,d/component.name)
  original=subprocess.check_output(['git','-C',str(REPO),'show','cb8747d:Arena.qml'],text=True) if variant=='before' else (source/'Arena.qml').read_text()
  s=original.replace('import qs.Commons','').replace('Color.accent','"#aabbcc"').replace('WlrKeyboardFocus.Exclusive','WlrKeyboardFocus.None').replace('mask: Region {\n      width: window.width\n      height: window.height\n    }','mask: Region {}').replace('volume: ','muted: true; volume: ').replace('enabled: root.armed\n      hoverEnabled: true','enabled: false\n      hoverEnabled: true').replace('running: root.armed','running: false')
  s=s.replace('  id: root','  id: root\n  function capture(path) {\n    (destructionEnabled ? terrainCanvasLoader : canvas).grabToImage(function(result) { console.log("SAVED", result.saveToFile(path)); root.holster(); Qt.quit(); });\n  }\n  function scene(name) {\n    if (name === "terrain") {\n      holster();\n      destructionEnabled=true;\n      desktopSnapshot="file:///tmp/blow-off-some-steam-visual/pattern.ppm";\n      wallpaperSource=desktopSnapshot;\n    }\n    equip(name === "revolver" ? "revolver" : "glock",false);\n    gunX=750.25; gunY=580.75; gunPositioned=true;\n    aimAngle=name === "revolver" ? 157 : -24;\n    aimFlipped=name === "revolver";\n    recoil=8; flash=0.65;\n    targetX=1200.25; targetY=600.75; targetVisible=true;\n    var ps=[];\n    for (var k=1;k<=7;k++) {\n      for (var j=0;j<5;j++) ps.push({kind:k,x:400+j*160+0.25,y:200+k*140+0.75,vx:Math.cos(j)*10,vy:Math.sin(j)*10,size:k===3?8:3+j*2,life:0.15+j*0.2,angle:j*0.45,maxRadius:180});\n    }\n    // Overlapping translucent effects and initial life > 1 exercise blending.\n    ps.push({kind:7,x:1200.25,y:600.75,size:25,life:0.6});\n    ps.push({kind:1,x:1204.25,y:601.75,size:14,life:1.15});\n    particles=ps;\n    canvas.requestPaint();\n  }\n  function damageScene() {\n    if(!destructionEnabled) return;\n    var marks=[];\n    for(var i=0;i<10;i++) marks.push({regionId:"a",x:256*(i+1),y:256+(i%3)*256,radius:13+i*7,clipX:0,clipY:0,clipWidth:2800,clipHeight:1200});\n    carveMarks=marks;\n    terrainCanvasLoader.item.applyDamage(Qt.rect(0,0,3072,1728));\n  }\n',1)
  (d/'Arena.qml').write_text(s)
  (d/'shell.qml').write_text('import Quickshell\nimport QtQuick\nShellRoot {\n Arena { id: arena }\n Timer { interval: 200; running:true; onTriggered: arena.arm("glock") }\n Timer { interval: 500; running:true; onTriggered: arena.scene("SCENE") }\n Timer { interval: 1200; running:true; onTriggered: arena.damageScene() }\n Timer { interval: 2000; running:true; onTriggered: arena.capture("OUTPUT") }\n Timer { interval: 5000; running:true; onTriggered: Qt.quit() }\n}'.replace('SCENE',scene).replace('OUTPUT',str(d/'frame.png')))
  result=subprocess.run(['quickshell','-p',str(d/'shell.qml'),'--no-color'],capture_output=True,text=True,timeout=9)
  (d/'run.log').write_text(result.stdout+result.stderr)
  if not (d/'frame.png').exists(): raise RuntimeError(result.stdout+result.stderr)
  print(variant,scene,'captured',flush=True)
