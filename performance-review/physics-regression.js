const fs = require('fs');
const assert = require('assert');
const old = require('child_process').execFileSync('git',['show','cb8747d:Arena.qml'],{encoding:'utf8',cwd:require('path').resolve(__dirname,'..')});
const current = fs.readFileSync(require('path').resolve(__dirname,'../Arena.qml'),'utf8');
function functionBody(text, start) {
  let a=text.indexOf('{',start), depth=1, i=a+1;
  for(;depth;i++) {if(text[i]==='{')depth++; else if(text[i]==='}')depth--;}
  return text.slice(a+1,i-1);
}
const oldStart=old.indexOf('onTriggered:',old.indexOf('interval: 16\n    running: root.armed'));
const oldBody=functionBody(old,oldStart);
const newBody=functionBody(current,current.indexOf('function simulateStep()'));
const runOld=new Function('root','window','canvas','with(root){'+oldBody+'}');
const newFollow=functionBody(current,current.indexOf('function advanceWeapon('));
const runFollow=new Function('root','deltaSeconds','with(root){'+newFollow+'}');
const runNew=new Function('root','window','canvas','with(root){'+newBody+'}');
function state() {
  let r={gunX:200,gunY:200,pointerX:500,pointerY:400,gunPositioned:true,followDistance:135,aimAngle:0,aimFlipped:false,recoil:20,flash:1,particles:[],pendingEffects:[],particleBuffer:[],previousGunX:0,previousGunY:0,previousAimAngle:0,previousRecoil:0,previousFlash:0,events:[]};
  r.projectileHitsTarget=()=>false;
  r.targetWithinBlast=()=>false;
  r.carveRegion=(...a)=>r.events.push(['carve',...a]);
  r.carveRicochetImpact=(...a)=>r.events.push(['bounce',...a]);
  r.playRocketExplosion=()=>r.events.push(['explode']);
  r.damageDesktop=(...a)=>r.events.push(['damage',...a]);
  r.rocketBlastParticles=()=>[{kind:1,x:100,y:100,vx:2,vy:-4,life:.8,size:3}];
  r.appendParticles=(to,from)=>{for(const p of from)to.push(p)};
  return r;
}
const a=state(),b=state();
function normalized(r){return JSON.parse(JSON.stringify({gunX:r.gunX,gunY:r.gunY,aimAngle:r.aimAngle,aimFlipped:r.aimFlipped,recoil:r.recoil,flash:r.flash,particles:r.particles,pendingEffects:r.pendingEffects,events:r.events},(k,v)=>k.startsWith('previous')?undefined:v));}
for(let step=0;step<600;step++){
  if(step%25===0){
    const add=[];
    for(let kind=1;kind<=7;kind++)add.push({kind,x:590,y:380,vx:12,vy:8,life:1,size:5,bounces:0,angle:.3,spin:.2,impacted:true,age:0,explodeAt:1.52,boomScale:1,maxRadius:180});
    a.particles=a.particles.concat(structuredClone(add)); b.particles=b.particles.concat(structuredClone(add));
  }
  if(step%71===0){a.pendingEffects=[{kind:7,x:50,y:50,vx:1,vy:-1,life:.8,size:8}];b.pendingEffects=structuredClone(a.pendingEffects);}
  a.pointerX=b.pointerX=300+200*Math.sin(step/20); a.pointerY=b.pointerY=200+150*Math.cos(step/15);
  runOld(a,{width:600,height:400},{requestPaint(){}});runFollow(b,0.016);runNew(b,{width:600,height:400},{requestPaint(){}});
  const nb=normalized(b), na=normalized(a);
  for (const key of ['gunX','gunY','aimAngle']) {assert(Math.abs(nb[key]-na[key])<1e-8,'weapon drift '+key+' at step '+step);delete nb[key];delete na[key];}
  assert.deepStrictEqual(nb,na,'step '+step);
}
console.log('PASS: 600 fixed physics steps preserve all seven particle types, bounces, explosions, recoil, aim, and pending effects.');

// The exponential follower retains the same stationary-input response at
// different animation rates. Projectile physics is checked above at 16 ms.
const c=state(),d=state();
for(let i=0;i<50;i++){runFollow(c,.016);runFollow(d,.008);runFollow(d,.008);}
assert(Math.hypot(c.gunX-d.gunX,c.gunY-d.gunY)<1e-8);
console.log('PASS: follower response is invariant between 8 ms and 16 ms updates for stationary input.');
