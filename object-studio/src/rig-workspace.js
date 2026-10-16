/* Mineclonie browser workspace. Additive to the legacy Character Rig Studio UI. */
import {PARTS,VIEWS,defaultDocument,validateDocument,validatePNG,exportMrig,importMrig,applyRigPatch} from './rig-package.js';
const ui=window.MineclonieRigBridge;
if(!ui)throw Error('Character Rig Studio bridge is missing');
const {state,canvas,ctx,renderList,setStatus,layer,persist}=ui;
const el=id=>document.getElementById(id);
const trig=(t,phase=0)=>Math.sin(t+phase);
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
let current=null,checkpoint=null,db=null,currentImages={front:{},back:{}};
const identity=x=>x;
const bytesToImage=async b=>{validatePNG(b);const url=URL.createObjectURL(new Blob([b],{type:'image/png'}));try{const img=new Image();await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(Error('PNG decode failed'));img.src=url});return img}finally{URL.revokeObjectURL(url)}};
async function decodeSprites(doc){const result={front:{},back:{}};for(const v of VIEWS)for(const p of PARTS)result[v][p]=await bytesToImage(doc.sprites[v][p]);return result}
function showError(e){const msg=e instanceof Error?e.message:String(e);setStatus('HATA: '+msg);el('rigErrors').textContent=msg;el('rigErrors').hidden=false}
function success(s){el('rigErrors').hidden=true;el('rigErrors').textContent='';setStatus(s)}
const download=(blob,name)=>{const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),4000)};
async function storage(){return new Promise((resolve,reject)=>{const r=indexedDB.open('MineclonieCharacterPackagesV1',1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains('packages'))r.result.createObjectStore('packages')};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)})}
function idbPut(items){return new Promise((resolve,reject)=>{if(!db){resolve();return}const tx=db.transaction('packages','readwrite');const store=tx.objectStore('packages');for(const [k,v] of items)store.put(v,k);tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error)})}
function idbGet(k){return new Promise((resolve,reject)=>{if(!db){resolve(null);return}const tx=db.transaction('packages','readonly'),r=tx.objectStore('packages').get(k);r.onsuccess=()=>resolve(r.result||null);r.onerror=()=>reject(r.error)})}
const views=['front','frontMirror','back','backMirror'];
function spriteLayout(view,p){const layout=current?.metadata?.spriteLayout||{};return layout?.parts?.[view]?.[p]||null}
function nodeWorld(nodes,key,cache=new Map()){
 if(cache.has(key))return cache.get(key);
 const n=nodes[key];if(!n)return {x:0,y:0,r:0,s:1};
 const q=n.parent?nodeWorld(nodes,n.parent,cache):{x:0,y:0,r:0,s:1};
 const c=Math.cos(q.r),s=Math.sin(q.r),a={x:q.x+q.s*(n.x*c-n.y*s),y:q.y+q.s*(n.x*s+n.y*c),r:q.r+n.rotation,s:q.s*n.scale};cache.set(key,a);return a;
}
function render(ctx2,doc,images,view,anim,time,{grid=false,mesh=false,nodes=false,scale=1}={}){
 const C=ctx2.canvas,width=C.width,height=C.height,k=Math.min(width,height)/640;
 ctx2.save();ctx2.clearRect(0,0,width,height);ctx2.scale(k,k);ctx2.translate(320,320);
 const v=view.startsWith('back')?'back':'front',mirror=view.endsWith('Mirror');
 ctx2.scale(scale*(mirror?-1:1),scale);
 if(grid){ctx2.strokeStyle='rgba(164,195,162,.18)';ctx2.lineWidth=.8/scale;for(let i=-8;i<=8;i++){const y=190+i*19;ctx2.beginPath();ctx2.moveTo(-300,y-150);ctx2.lineTo(300,y+150);ctx2.stroke();ctx2.beginPath();ctx2.moveTo(-300,y+150);ctx2.lineTo(300,y-150);ctx2.stroke()}}
 const layout=doc.metadata?.spriteLayout;
 const restNodes=doc.metadata?.restNodes||doc.skeleton.nodes;
 const world=new Map(),rest=new Map();const a=doc.animations[anim]||doc.animations.idle;
 const phase=((time/a.duration)%1+1)%1,theta=phase*2*Math.PI,p=a.parameters;
 const walk=anim==='walk',chop=anim==='chop';
 const walkPhase=n=>(phase+(n.endsWith('R')?.5:0))%1;
 const liftPhase=f=>f>.5?Math.sin((f-.5)*Math.PI*2):0;
 const bob=walk?(p.hipBob||0)*Math.abs(Math.sin(theta)):anim==='idle'?(p.breath||0)*Math.sin(theta):chop?Math.sin(theta)*(p.torsoLean||0)*7:0;
 const drift=walk?(p.hipSway||0)*Math.sin(theta):0;
 function motion(name){let dx=drift,dy=bob,r=0,bend=0;
  if(walk){if(name.startsWith('leg')){
    const f=walkPhase(name),s=f<.5?.5-f*2:-.5+(f-.5)*2,along=s*2;
    const sign=v==='front'?1:-1;
    dx+=sign*along*(p.stepX||0);dy+=sign*along*(p.stepY||0)-liftPhase(f)*(p.footLift||0);
    r=(p.legRotation||0)*trig(theta,name.endsWith('R')?Math.PI:0);bend=(p.meshBend||0)*trig(theta,name.endsWith('R')?Math.PI:0);
  }else if(name.startsWith('arm')){r=(p.armSwing||0)*trig(theta,name.endsWith('R')?0:Math.PI);bend=r*.45}
  else if(name==='head'){dy-=bob*(p.headStabilize||0);r=-.015*Math.sin(theta)}
  }else if(chop){const strike=Math.sin(theta);if(name.startsWith('arm')){r=-(p.armRaise||0)-(p.armSwing||0)*strike*(name.endsWith('R')?1:.85);bend=(p.meshBend||0)*strike}
   else if(name==='torso'){r=(p.torsoLean||0)*strike;dy+=2*strike}
   else if(name==='head')r=-(p.headCounter||0)*strike;
  }else if(name==='head')dy-=(p.headFloat||0)*Math.sin(theta);
  return {dx,dy,r,bend};
 }
 function triangle(img,src,dst){const [a,b,c]=src,[A,B,C]=dst;
  const det=a.x*(b.y-c.y)+b.x*(c.y-a.y)+c.x*(a.y-b.y);if(Math.abs(det)<1e-5)return;
  const a1=(A.x*(b.y-c.y)+B.x*(c.y-a.y)+C.x*(a.y-b.y))/det;
  const b1=(A.y*(b.y-c.y)+B.y*(c.y-a.y)+C.y*(a.y-b.y))/det;
  const c1=(A.x*(c.x-b.x)+B.x*(a.x-c.x)+C.x*(b.x-a.x))/det;
  const d1=(A.y*(c.x-b.x)+B.y*(a.x-c.x)+C.y*(b.x-a.x))/det;
  const e1=(A.x*(b.x*c.y-c.x*b.y)+B.x*(c.x*a.y-a.x*c.y)+C.x*(a.x*b.y-b.x*a.y))/det;
  const f1=(A.y*(b.x*c.y-c.x*b.y)+B.y*(c.x*a.y-a.x*c.y)+C.y*(a.x*b.y-b.x*a.y))/det;
  ctx2.save();ctx2.beginPath();ctx2.moveTo(A.x,A.y);ctx2.lineTo(B.x,B.y);ctx2.lineTo(C.x,C.y);ctx2.closePath();ctx2.clip();ctx2.transform(a1,b1,c1,d1,e1,f1);ctx2.drawImage(img,0,0);ctx2.restore();
 }
 for(const name of doc.depth[v]){
  const sprite=images[v][name];if(!sprite)continue;
  const joint=doc.pivots[v][name],spec=doc.meshes[v][name],m=motion(name);
  const nd=nodeWorld(doc.skeleton.nodes,name,world),base=nodeWorld(restNodes,name,rest);
  const sx=layout?.scale||.63,origin=layout?.origin||[135,305],entry=layout?.parts?.[v]?.[name];
  const box=entry?.crop||[0,0,sprite.width,sprite.height],pixelJoint=entry?.joint;
  // Complete source-coordinate registration guarantees identical neutral assembly.
  const pivotX=pixelJoint?(pixelJoint[0]-box[0])/box[2]:joint.px/100;
  const pivotY=pixelJoint?(pixelJoint[1]-box[1])/box[3]:joint.py/100;
  const x=joint.x+(nd.x-base.x)+m.dx,y=joint.y+(nd.y-base.y)+m.dy;
  const angle=(joint.angle||0)*Math.PI/180+(nd.r-base.r)+m.r;
  ctx2.save();ctx2.translate(x,y);ctx2.rotate(angle);const W=sprite.width*sx,H=sprite.height*sx;
  const verts=[],uv=[],cols=spec.cols,rows=spec.rows;
  for(let j=0;j<=rows;j++){const rr=[],ss=[];for(let i=0;i<=cols;i++){
   const u=i/cols,vv=j/rows,weight=spec.weights[j*(cols+1)+i],ax=(u-pivotX)*W,ay=(vv-pivotY)*H;
   const b=clamp(m.bend*spec.bendScale+(joint.bend||0)*Math.PI/180,-.26,.26);
   rr.push({x:ax+b*weight*H*.34,y:ay+b*(u-.5)*weight*W*.14});ss.push({x:u*sprite.width,y:vv*sprite.height});
  }verts.push(rr);uv.push(ss)}
  // Non-deformed meshes are drawn as one image to avoid hairline seams.
  const deform=Math.abs(m.bend*spec.bendScale+(joint.bend||0)*Math.PI/180)>.0003;
  if(!deform)ctx2.drawImage(sprite,-pivotX*W,-pivotY*H,W,H);
  else for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){
   triangle(sprite,[uv[j][i],uv[j][i+1],uv[j+1][i]],[verts[j][i],verts[j][i+1],verts[j+1][i]]);
   triangle(sprite,[uv[j][i+1],uv[j+1][i+1],uv[j+1][i]],[verts[j][i+1],verts[j+1][i+1],verts[j+1][i]]);
  }
  if(mesh){ctx2.strokeStyle='#7df5e0';ctx2.lineWidth=.7;for(let j=0;j<=rows;j++)for(let i=0;i<=cols;i++){if(i<cols){const A=verts[j][i],B=verts[j][i+1];ctx2.beginPath();ctx2.moveTo(A.x,A.y);ctx2.lineTo(B.x,B.y);ctx2.stroke()}if(j<rows){const A=verts[j][i],B=verts[j+1][i];ctx2.beginPath();ctx2.moveTo(A.x,A.y);ctx2.lineTo(B.x,B.y);ctx2.stroke()}}}
  if(nodes){ctx2.fillStyle='#fff5a9';ctx2.beginPath();ctx2.arc(0,0,3,0,Math.PI*2);ctx2.fill()}
  ctx2.restore();
 }
 ctx2.restore();
}
function drawModern(){if(!current)return false;render(ctx,current,currentImages,state.view,state.anim,state.time,{grid:el('gridOn').checked,mesh:el('meshOn').checked,nodes:el('nodesOn').checked,scale:state.scale});return true}
function syncRigToLegacy(doc,images){
 state.rigDocument=doc;current=doc;currentImages=images;
 for(const v of VIEWS){for(const n of PARTS){state.images[v][n]=images[v][n];state.parts[v][n]={...doc.pivots[v][n]}}}
 renderList();el('rigInfo').textContent=`${doc.manifest.characterId} · rev ${doc.manifest.revision} · ${doc.manifest.schemaVersion}. şema`;
 drawModern();
}
function documentFromLegacy(){const doc=defaultDocument();for(const v of VIEWS)for(const p of PARTS){
 const a=layer(v,p);doc.pivots[v][p]={...doc.pivots[v][p],...a};
 }return doc}
async function importPackage(blob,{save=true}={}){
 const doc=await importMrig(blob);const images=await decodeSprites(doc); // validate all before touching current character
 syncRigToLegacy(doc,images);checkpoint=null;
 if(save)await idbPut([['current:'+doc.manifest.characterId,doc],['last',doc.manifest.characterId]]);
 success('Karakter paketi yüklendi: '+doc.manifest.characterId+' r'+doc.manifest.revision+' · Idle');state.anim='idle';state.time=0;document.querySelectorAll('.anim').forEach(x=>x.classList.toggle('active',x.dataset.anim==='idle'));
}
async function snapshot(doc,images,view,anim,time){const test=document.createElement('canvas');test.width=640;test.height=640;render(test.getContext('2d'),doc,images,view,anim,time,{scale:1});return test.toDataURL('image/png')}
async function preparePatch(){
 if(!current)throw Error('Önce bir .mrig paketi yükleyin');
 let patch;try{patch=JSON.parse(el('rigPatchText').value)}catch{throw Error('Patch geçerli JSON değil')}
 const candidate=applyRigPatch(current,patch);const imgs=patch.operations.some(o=>o.op==='replaceSprite')?await decodeSprites(candidate):currentImages;
 const touched=patch.operations.find(o=>o.name)?.name||state.anim;
 const t=candidate.animations[touched]?.duration*.3||.3;
 el('rigBefore').src=await snapshot(current,currentImages,state.view,touched,t);
 el('rigAfter').src=await snapshot(candidate,imgs,state.view,touched,t);
 el('rigPatchDiff').textContent=`${patch.operations.length} işlem · revision ${current.manifest.revision} → ${candidate.manifest.revision} · ${touched}`;
 return {candidate,imgs};
}
async function applyPatch(){const {candidate,imgs}=await preparePatch();checkpoint=current;
 if(db)await idbPut([['undo:'+current.manifest.characterId,current],['current:'+current.manifest.characterId,candidate],['last',current.manifest.characterId]]);
 syncRigToLegacy(candidate,imgs);success('Patch atomik uygulandı · r'+current.manifest.revision);}
async function undo(){if(!current)throw Error('Yüklü karakter yok');const old=checkpoint||await idbGet('undo:'+current.manifest.characterId);
 if(!old)throw Error('Geri alınacak güncelleme yok');validateDocument(old);const images=await decodeSprites(old);
 if(db)await idbPut([['current:'+old.manifest.characterId,old],['last',old.manifest.characterId],['undo:'+old.manifest.characterId,null]]);
 syncRigToLegacy(old,images);checkpoint=null;success('Güncelleme geri alındı');}
async function exportPackage(){if(!current)throw Error('Önce bir karakter paketi yükleyin');download(await exportMrig(current),`${current.manifest.characterId}-r${current.manifest.revision}.mrig`);success('İndirilecek .mrig paketi oluşturuldu')}
function bind(id,fn){el(id).addEventListener('click',()=>Promise.resolve().then(fn).catch(showError))}
ui.drawModern=drawModern;ui.renderDocument=render;
const input=el('rigPackageFile');input.addEventListener('change',()=>{const f=input.files?.[0];if(f)importPackage(f).catch(showError);input.value=''});
bind('rigExport',exportPackage);bind('rigPatchValidate',async()=>{await preparePatch();success('Patch doğrulandı; öncesi/sonrası hazır')});bind('rigPatchApply',applyPatch);bind('rigUndo',undo);
bind('rigLoadSaved',async()=>{const id=await idbGet('last');if(!id)throw Error('Kayıtlı .mrig bulunamadı');const doc=await idbGet('current:'+id);if(!doc)throw Error('Kayıtlı karakter içeriği bulunamadı');validateDocument(doc);const images=await decodeSprites(doc);syncRigToLegacy(doc,images);success('Yerel karakter açıldı')});
// Example patch always uses the loaded character's exact identity and revision.
bind('rigSamplePatch',async()=>{if(!current)throw Error('Önce .mrig yükleyin');el('rigPatchText').value=JSON.stringify({format:'mineclonie-rig-patch',schemaVersion:1,characterId:current.manifest.characterId,baseRevision:current.manifest.revision,targetRevision:current.manifest.revision+1,operations:[{op:'setAnimationParameters',name:'walk',values:{stepX:6.7,footLift:10.2,armSwing:.105}}]},null,2);success('Örnek patch hazır')});
storage().then(async d=>{db=d;const id=await idbGet('last');if(id)el('rigInfo').textContent='Kayıtlı karakter: '+id+' · Açmak için “Kayıtlı Aç”';}).catch(e=>{setStatus('Paket depolaması kullanılamıyor: '+e.message)});