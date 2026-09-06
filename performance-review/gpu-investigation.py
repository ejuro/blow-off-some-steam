import pathlib, subprocess, time, os, json, argparse
REPO=pathlib.Path(__file__).resolve().parent.parent
ns={'__file__':str(REPO/'performance-review/implementation-benchmark.py')}
exec((REPO/'performance-review/implementation-benchmark.py').read_text().split('results=[]')[0],ns)
parser=argparse.ArgumentParser();parser.add_argument('--output',default='/tmp/steam-gpu-results.json');parser.add_argument('--scenarios',default='auto,rockets,rockets_no_effects');args=parser.parse_args()
results=[]
for name in args.scenarios.split(','):
 d=ns['prepare']('rockets' if name.startswith('rockets') else 'auto')
 code=(d/'Arena.qml').read_text().replace('id: root\n','id: root\n property double gpuPixels:0\n property int gpuResizes:0\n',1)
 effects=(d/'EffectsLayer.qml').read_text()
 if name.endswith('stable'):
  effects=effects.replace('var alpha = 1', '''var free = {}
    for (var n=0;n<pool.length;n++) pool[n].claimed=false
    for (var n=0;n<particles.length;n++) if(particles[n]._slot) particles[n]._slot.claimed=true
    for (var n=0;n<pool.length;n++) {
      var slot=pool[n]
      if(!slot.claimed) {
        if(slot.owner) slot.owner._slot=null
        slot.owner=null; slot.visible=false
        var kind=slot.particle ? slot.particle.kind : 0
        if(!free[kind])free[kind]=[]
        free[kind].push(slot)
      }
    }
    var alpha = 1''')
  effects=effects.replace('if (i >= pool.length) pool.push(particleComponent.createObject(particleLayer))','')
  effects=effects.replace('var p = particles[i]', '''var p = particles[i]
      if(!p._slot) {
        var available=free[p.kind]
        var slot=available && available.length ? available.pop() : particleComponent.createObject(particleLayer)
        if(!slot.owner && pool.indexOf(slot)<0)pool.push(slot)
        slot.owner=p; p._slot=slot
      }''')
  effects=effects.replace('pool[i].sync(p, i, alpha, blend)', 'p._slot.sync(p, i, alpha, blend)')
  effects=effects.replace('for (var j = particles.length; j < used; j++) pool[j].visible = false','')
  particle=(d/'EffectParticle.qml').read_text().replace('id: sprite','id: sprite\n property bool claimed:false\n property var owner:null')
  (d/'EffectParticle.qml').write_text(particle)
 effects=effects.replace('pool[i].sync(p, i, alpha, blend)', 'var oldWidth=pool[i].width; pool[i].sync(p,i,alpha,blend); arena.gpuPixels += pool[i].width*pool[i].height; if(oldWidth !== pool[i].width) arena.gpuResizes++')
 effects=effects.replace('p._slot.sync(p, i, alpha, blend)', 'var oldWidth=p._slot.width; p._slot.sync(p,i,alpha,blend); arena.gpuPixels += p._slot.width*p._slot.height; if(oldWidth !== p._slot.width) arena.gpuResizes++')
 (d/'EffectsLayer.qml').write_text(effects)
 if name.endswith('no_effects'): code=code.replace('canvas.requestPaint()', 'void 0')
 (d/'Arena.qml').write_text(code)
 (d/'shell.qml').write_text('''import Quickshell
import QtQuick
ShellRoot {
 Arena { id: arena }
 property int elapsed: 0
 Timer { interval: 300; running: true; onTriggered: { arena.arm("WEAPON"); arena.gunPositioned=true; arena.gunX=1100; arena.gunY=800; arena.pointerX=1600; arena.pointerY=800; } }
 Timer { interval: SHOT; running: elapsed>=3000 && elapsed<11000; repeat:true; onTriggered: arena.shoot(false) }
 Timer { interval:100; running:true; repeat:true; onTriggered: {
 elapsed+=100;
 var counts={}, area=0;
 for(var i=0;i<arena.particles.length;i++) {var p=arena.particles[i];counts[p.kind]=(counts[p.kind]||0)+1;if(p.kind===4)area+=Math.pow(Math.ceil((p.maxRadius+10)/8)*16,2);}
 console.log("SAMPLE "+JSON.stringify({ms:elapsed,phase:elapsed<3000?"idle":elapsed<11000?"fire":elapsed<17000?"release":"holstered",counts:counts,ringPixels:area,awake:arena.simulationAwake,ticks:arena.benchTicks,paintPixels:arena.gpuPixels,resizes:arena.gpuResizes,maxFrameGap:Math.max.apply(null,arena.benchIntervals)}));
 if(elapsed===17000)arena.holster();
 if(elapsed>=21000)Qt.quit();
 } }
}'''.replace('WEAPON','thick-bazooka' if name.startswith('rockets') else 'mp5a3').replace('SHOT','550' if name.startswith('rockets') else '66'))
 logpath=d/(name+'-gpu.log'); gpupath=d/(name+'-telemetry.csv')
 with logpath.open('w') as log, gpupath.open('w') as gpu:
  mon=subprocess.Popen(['nvidia-smi','--query-gpu=timestamp,utilization.gpu,utilization.memory,clocks.gr,power.draw','--format=csv,noheader,nounits','--loop-ms=100'],stdout=gpu,stderr=subprocess.STDOUT)
  p=subprocess.Popen(['quickshell','-p',str(d/'shell.qml'),'--no-color'],stdout=log,stderr=subprocess.STDOUT)
  start=time.monotonic(); samples=[]
  try:
   while p.poll() is None and time.monotonic()-start<28:
    lines=logpath.read_text().splitlines(); q=[x.split('SAMPLE ',1)[1] for x in lines if 'SAMPLE ' in x];g=gpupath.read_text().splitlines()
    if q and g:
     try:
      sample=json.loads(q[-1]);sample['gpu']=g[-1];sample['wall']=time.monotonic()-start;sample['cpuSeconds']=ns['cpu'](p.pid);samples.append(sample)
     except ValueError:pass
    time.sleep(.1)
  finally:
   if p.poll() is None:p.terminate();p.wait(timeout=3)
   mon.terminate();mon.wait(timeout=3)
 result={'name':name,'samples':samples};results.append(result)
 for phase in ['idle','fire','release','holstered']:
  selected=[s for s in samples if s['phase']==phase]
  vals=[]
  for s in selected:
   try:vals.append(float(s['gpu'].split(',')[1]))
   except (ValueError,IndexError):pass
  print(name,phase,'GPU mean/max',round(sum(vals)/max(1,len(vals)),1),max(vals,default=0),'active samples',sum(s['awake'] for s in selected),flush=True)
 pathlib.Path(args.output).write_text(json.dumps(results,indent=2))
