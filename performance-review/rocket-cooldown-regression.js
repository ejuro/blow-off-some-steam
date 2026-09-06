const fs = require('fs');
const assert = require('assert');
const source = fs.readFileSync(require('path').join(__dirname, '../Arena.qml'), 'utf8');
const start = source.indexOf('function shoot(withSound) {');
let begin = source.indexOf('{', start), end = begin + 1, depth = 1;
for (; depth; end++) { if (source[end] === '{') depth++; else if (source[end] === '}') depth--; }
const shoot = new Function('root', 'rocketCooldown', 'withSound', 'with(root){' + source.slice(begin + 1, end - 1) + '}');
const cooldown = {running:false, interval:0, start(){this.running=true;}};
const root = {
  armed:true, weapon:'thick-bazooka', spec:{interval:550,recoil:32,scale:1.65,muzzleX:147,muzzleY:10.5,gripX:66,gripY:24,particles:52,power:2.1,ejectsCase:false},
  gunX:300,gunY:300,aimAngle:0,aimFlipped:false,particles:[],recoil:0,flash:0,previousRecoil:0,previousFlash:0,
  sounds:0,wakes:0,playWeaponSound(){this.sounds++;},wakeSimulation(){this.wakes++;},firstDesktopImpact(){return null;}
};
assert.strictEqual(shoot(root,cooldown,true),true);
assert.strictEqual(cooldown.interval,550);
assert.strictEqual(root.particles.filter(p=>p.kind===3).length,1);
const snapshot = JSON.stringify(root);
for(let i=0;i<100;i++)assert.strictEqual(shoot(root,cooldown,true),false);
assert.strictEqual(JSON.stringify(root),snapshot,'Rejected clicks must have no shot side effects');
root.weapon='bazooka';root.spec.interval=500;
assert.strictEqual(shoot(root,cooldown,true),false,'Switching launcher cannot bypass cooldown');
assert.strictEqual(cooldown.interval,550,'Switching launcher cannot shorten an active cooldown');
root.weapon='glock';
assert.strictEqual(shoot(root,cooldown,false),true,'Other weapons remain usable during rocket cooldown');
root.weapon='bazooka';cooldown.running=false;
assert.strictEqual(shoot(root,cooldown,false),true);
assert.strictEqual(cooldown.interval,500,'Regular launcher retains its configured interval');
root.armed=false;cooldown.running=false;
assert.strictEqual(shoot(root,cooldown,true),false);
assert.strictEqual(cooldown.running,false);
console.log('PASS: rejected clicks have no effects; launchers share cooldown; other weapons are unaffected; configured intervals and unarmed behavior hold.');
