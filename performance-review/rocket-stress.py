"""Muted, click-through rapid-fire stress test; requires desktop and NVIDIA access."""
import pathlib, subprocess, time, json, os, statistics, argparse
REPO = pathlib.Path(__file__).resolve().parent.parent
ns = {'__file__': str(REPO/'performance-review/implementation-benchmark.py')}
exec((REPO/'performance-review/implementation-benchmark.py').read_text().split('results=[]')[0], ns)
parser=argparse.ArgumentParser();parser.add_argument('--output',default='rocket-cooldown-measurements.json');parser.add_argument('--scenarios',default='rockets,destruction,rockets_vulkan');args=parser.parse_args()
results = []
for scenario in args.scenarios.split(','):
    d = ns['prepare']('rockets')
    code = (d/'Arena.qml').read_text()
    code = code.replace('if (!armed || simulationAwake) return', 'if (!armed || simulationAwake) return\n    benchLast = 0')
    (d/'Arena.qml').write_text(code)
    setup = 'arena.arm("thick-bazooka");'
    if scenario == 'destruction':
        setup = '''arena.destructionEnabled=true;
        arena.desktopSnapshot="file:///tmp/blow-off-some-steam-benchmark/snapshot.ppm";
        arena.wallpaperSource=arena.desktopSnapshot;
        arena.destructibles=[{id:"stress",kind:"window",x:1700,y:200,width:800,height:1300,hits:0,limit:120,destroyed:false}];
        arena.equip("thick-bazooka",false);'''
    (d/'shell.qml').write_text('''import Quickshell
import QtQuick
ShellRoot {
 Arena { id: arena }
 property double started: Date.now()
 property int elapsed: 0
 property int shots: 0
 property int attempts: 0
 property var shotTimes: []
 Timer { interval:300; running:true; onTriggered: { SETUP arena.gunPositioned=true;arena.gunX=1000;arena.gunY=850;arena.pointerX=1600;arena.pointerY=850; } }
 Timer { interval:100; running:elapsed>=3000 && elapsed<15000; repeat:true; onTriggered: { attempts++; if(arena.shoot(false)) { shots++;shotTimes.push(Date.now()-started); } } }
 Timer { interval:100; running:true; repeat:true; onTriggered: {
   elapsed=Date.now()-started;
   var counts={};for(var i=0;i<arena.particles.length;i++){var p=arena.particles[i];counts[p.kind]=(counts[p.kind]||0)+1;}
   console.log("SAMPLE "+JSON.stringify({ms:elapsed,shots:shots,counts:counts,awake:arena.simulationAwake}));
   if(elapsed>=21000 && arena.armed)arena.holster();
   if(elapsed>=23000){console.log("RESULT "+JSON.stringify({shots:shots,attempts:attempts,shotTimes:shotTimes,intervals:arena.benchIntervals,particles:arena.particles.length,awake:arena.simulationAwake,armed:arena.armed,falls:arena.benchFalls}));Qt.quit();}
 } }
}'''.replace('SETUP', setup))
    logpath=d/(scenario+'-stress.log'); gpupath=d/(scenario+'-stress.csv')
    env=os.environ.copy()
    if scenario.endswith('vulkan'): env['QSG_RHI_BACKEND']='vulkan'
    with logpath.open('w') as log,gpupath.open('w') as gpu:
        mon=subprocess.Popen(['nvidia-smi','--query-gpu=timestamp,utilization.gpu,clocks.gr,power.draw','--format=csv,noheader,nounits','--loop-ms=100'],stdout=gpu,stderr=subprocess.STDOUT)
        process=subprocess.Popen(['quickshell','-p',str(d/'shell.qml'),'--no-color'],stdout=log,stderr=subprocess.STDOUT,env=env)
        samples=[];start=time.monotonic()
        try:
            while process.poll() is None and time.monotonic()-start<35:
                lines=[x.split('SAMPLE ',1)[1] for x in logpath.read_text().splitlines() if 'SAMPLE ' in x]
                telemetry=gpupath.read_text().splitlines()
                if lines:
                    sample=json.loads(lines[-1]);sample['cpu']=ns['cpu'](process.pid);sample['wall']=time.monotonic()-start;sample['gpu']=telemetry[-1] if telemetry else '';samples.append(sample)
                time.sleep(.1)
        finally:
            if process.poll() is None: process.terminate();process.wait(timeout=3)
            mon.terminate();mon.wait(timeout=3)
    lines=logpath.read_text().splitlines()
    found=[x.split('RESULT ',1)[1] for x in lines if 'RESULT ' in x]
    if not found: raise RuntimeError('Stress test did not complete: '+str(logpath))
    result=json.loads(found[-1]);intervals=sorted(result.pop('intervals'))
    active=[x for x in samples if 5000<=x['ms']<15000]
    peak=max(sum(x['counts'].values()) for x in samples)
    result.update(scenario=scenario,peak_particles=peak,peak_rings=max(x['counts'].get('4',0) for x in samples),frame_p50=statistics.median(intervals),frame_p95=intervals[int(.95*(len(intervals)-1))],frame_max=max(intervals),frames_over_33ms=sum(x>33 for x in intervals),cpu_percent=round(100*(active[-1]['cpu']-active[0]['cpu'])/(active[-1]['wall']-active[0]['wall']),1),last_active_ms=max(x['ms'] for x in samples if x['awake']),gpu_peak=max(int(x['gpu'].split(',')[1]) for x in samples if x['gpu']),qml_errors=[x for x in lines if any(term in x for term in ['ReferenceError','TypeError','SyntaxError','Error loading QML'])])
    result['minimum_shot_gap']=min((b-a for a,b in zip(result['shotTimes'],result['shotTimes'][1:])),default=0)
    assert 15 <= result['shots'] <= 23 and result['minimum_shot_gap'] >= 550, result
    result['requested_shots_per_second']=10
    result['delivered_shots_per_second']=round(result['shots']/12,2)
    assert result['shots']>0 and not result['armed'] and not result['awake'] and result['particles']==0 and not result['qml_errors'],result
    print(json.dumps(result),flush=True)
    results.append(dict(summary=result,samples=samples))
    (REPO/'performance-review'/args.output).write_text(json.dumps(results,indent=2))
