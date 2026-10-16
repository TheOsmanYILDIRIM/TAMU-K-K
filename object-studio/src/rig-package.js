/* Mineclonie Rig Studio v1: dependency-free .mrig ZIP + validated atomic JSON patches.
   All exports are pure except the Blob/byte conversion helpers. */
export const PARTS=Object.freeze(['head','torso','armL','armR','legL','legR']);
export const VIEWS=Object.freeze(['front','back']);
const te=new TextEncoder(),td=new TextDecoder('utf-8',{fatal:true});
const fail=m=>{throw new Error(m)};
const isObj=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
const assert=(ok,msg)=>{if(!ok)fail(msg)};
const finite=x=>typeof x==='number'&&Number.isFinite(x);
const copy=x=>structuredClone(x);
const asBytes=async v=>v instanceof Uint8Array?v:v instanceof ArrayBuffer?new Uint8Array(v):v&&typeof v.arrayBuffer==='function'?new Uint8Array(await v.arrayBuffer()):fail('Binary sprite or package required');
const u16=(v,i)=>v[i]|(v[i+1]<<8);
const u32=(v,i)=>(v[i]|(v[i+1]<<8)|(v[i+2]<<16)|(v[i+3]<<24))>>>0;
const put16=(v,i,x)=>{v[i]=x&255;v[i+1]=(x>>>8)&255};
const put32=(v,i,x)=>{put16(v,i,x);put16(v,i+2,x>>>16)};
const crcTable=Array.from({length:256},(_,i)=>{for(let j=0;j<8;j++)i=i&1?0xedb88320^(i>>>1):i>>>1;return i>>>0});
export function crc32(data){let c=0xffffffff;for(let i=0;i<data.length;i++)c=crcTable[(c^data[i])&255]^(c>>>8);return(c^0xffffffff)>>>0}
function zipWrite(files){
 let offset=0,local=[],central=[];const entries=Object.entries(files);assert(entries.length<=96,'Too many ZIP entries');
 for(const [name,value] of entries){
  const path=te.encode(name),data=value instanceof Uint8Array?value:te.encode(value);
  assert(path.length>0&&path.length<180&&data.length<12_000_000,'ZIP filename or entry too large');
  const crc=crc32(data),lh=new Uint8Array(30+path.length),ch=new Uint8Array(46+path.length);
  put32(lh,0,0x04034b50);put16(lh,4,20);put32(lh,14,crc);put32(lh,18,data.length);put32(lh,22,data.length);put16(lh,26,path.length);lh.set(path,30);
  put32(ch,0,0x02014b50);put16(ch,4,20);put16(ch,6,20);put32(ch,16,crc);put32(ch,20,data.length);put32(ch,24,data.length);put16(ch,28,path.length);put32(ch,42,offset);ch.set(path,46);
  local.push(lh,data);central.push(ch);offset+=lh.length+data.length;
 }
 const centralStart=offset;for(const ch of central)offset+=ch.length;
 const end=new Uint8Array(22);put32(end,0,0x06054b50);put16(end,8,entries.length);put16(end,10,entries.length);put32(end,12,offset-centralStart);put32(end,16,centralStart);
 return new Blob([...local,...central,end],{type:'application/octet-stream'});
}
function zipRead(buf){
 const a=buf;assert(a.length>21&&a.length<=32_000_000,'Invalid ZIP size');
 let eocd=-1;for(let i=a.length-22;i>=Math.max(0,a.length-65557);i--)if(u32(a,i)===0x06054b50){eocd=i;break}
 assert(eocd>=0,'ZIP end record missing');const count=u16(a,eocd+10),start=u32(a,eocd+16),size=u32(a,eocd+12);
 assert(count>0&&count<=96&&start+size<=eocd,'Invalid ZIP directory');
 let pos=start,total=0;const files={};
 for(let j=0;j<count;j++){
  assert(pos+46<=a.length&&u32(a,pos)===0x02014b50,'Invalid ZIP central directory');
  const flags=u16(a,pos+8),method=u16(a,pos+10),crc=u32(a,pos+16),compressed=u32(a,pos+20),length=u32(a,pos+24),nl=u16(a,pos+28),extra=u16(a,pos+30),comment=u16(a,pos+32),off=u32(a,pos+42);
  assert(flags===0&&method===0,'Only uncompressed ZIP entries are supported');
  assert(length===compressed&&length<12_000_000,'ZIP entry size mismatch');
  assert(pos+46+nl+extra+comment<=a.length,'ZIP filename truncated');
  const name=td.decode(a.subarray(pos+46,pos+46+nl));
  assert(/^(?:manifest\.json|metadata\.json|rig\/(?:skeleton|meshes|pivots|depth)\.json|animations\/(?:idle|walk|chop)\.json|sprites\/(?:front|back)\/(?:head|torso|armL|armR|legL|legR)\.png)$/.test(name),'Unexpected ZIP path: '+name);
  assert(!Object.hasOwn(files,name),'Duplicate ZIP path '+name);
  assert(off+30<=a.length&&u32(a,off)===0x04034b50,'ZIP local header missing');
  const localNameLen=u16(a,off+26),localExtra=u16(a,off+28),from=off+30+localNameLen+localExtra;
  assert(from+length<=start,'ZIP entry runs outside data region');
  assert(td.decode(a.subarray(off+30,off+30+localNameLen))===name,'ZIP header path mismatch');
  const data=a.slice(from,from+length);
  assert(crc32(data)===crc,'ZIP CRC mismatch: '+name);
  files[name]=data;total+=length;assert(total<=24_000_000,'ZIP package exceeds size budget');
  pos+=46+nl+extra+comment;
 }
 assert(pos===start+size,'ZIP directory length mismatch');return files;
}
export function validatePNG(b,name='sprite'){
 assert(b instanceof Uint8Array&&b.length>=33&&b.length<=8_000_000,'Invalid PNG bytes: '+name);
 assert([137,80,78,71,13,10,26,10].every((v,i)=>b[i]===v),'PNG signature invalid: '+name);
 assert(u32(b,12)===0x52444849&&u32(b,8)===0x0d000000,'PNG IHDR missing: '+name); // IHDR length 13, big-endian
 const be=(i)=>((b[i]<<24)|(b[i+1]<<16)|(b[i+2]<<8)|b[i+3])>>>0;
 const w=be(16),h=be(20);assert(w>0&&h>0&&w<=4096&&h<=4096,'PNG dimensions invalid: '+name);
 assert(crc32(b.slice(12,29))===be(29),'PNG IHDR CRC invalid: '+name);return {width:w,height:h};
}
const defaultPivots=()=>({head:{x:0,y:-126,px:50,py:85},torso:{x:0,y:-25,px:50,py:28},armL:{x:-52,y:-45,px:60,py:12},armR:{x:52,y:-45,px:40,py:12},legL:{x:-24,y:62,px:50,py:12},legR:{x:24,y:62,px:50,py:12}});
const nodes={character_root:{parent:null,x:0,y:0,rotation:0,scale:1},body_root:{parent:'character_root',x:0,y:0,rotation:0,scale:1},torso:{parent:'body_root',x:0,y:0,rotation:0,scale:1},neck:{parent:'torso',x:0,y:-101,rotation:0,scale:1},head:{parent:'neck',x:0,y:0,rotation:0,scale:1},shoulderL:{parent:'torso',x:-53,y:-22,rotation:0,scale:1},shoulderR:{parent:'torso',x:53,y:-22,rotation:0,scale:1},armL:{parent:'shoulderL',x:0,y:0,rotation:0,scale:1},armR:{parent:'shoulderR',x:0,y:0,rotation:0,scale:1},hipL:{parent:'body_root',x:-24,y:87,rotation:0,scale:1},hipR:{parent:'body_root',x:24,y:87,rotation:0,scale:1},legL:{parent:'hipL',x:0,y:0,rotation:0,scale:1},legR:{parent:'hipR',x:0,y:0,rotation:0,scale:1}};
const animationDefaults={
 idle:{duration:3.2,loop:true,parameters:{breath:1.1,headFloat:.5,armSwing:0,hipBob:0,meshBend:.008}},
 walk:{duration:1.02,loop:true,parameters:{stepX:8,stepY:4,footLift:10.5,legRotation:.085,armSwing:.12,hipBob:1.3,hipSway:1,meshBend:.055,headStabilize:.6,footPlant:.27}},
 chop:{duration:1.3,loop:true,parameters:{armRaise:.22,armSwing:.32,torsoLean:.035,headCounter:.025,meshBend:.065}}
};
export function defaultDocument(characterId='mineclonie-human-001'){
 assert(/^[a-zA-Z0-9][\w-]{2,80}$/.test(characterId),'Invalid character ID');
 const mesh=()=>({cols:3,rows:5,weights:Array.from({length:24},(_,i)=>Math.pow(Math.floor(i/4)/5,2)),bendScale:1});
 return {manifest:{format:'mineclonie-character-rig',schemaVersion:1,characterId,revision:1,createdAt:new Date().toISOString(),spriteFormat:'png',viewMode:'two-plus-mirror'},skeleton:{nodes:copy(nodes)},meshes:Object.fromEntries(VIEWS.map(v=>[v,Object.fromEntries(PARTS.map(n=>[n,mesh()]))])),pivots:{front:defaultPivots(),back:defaultPivots()},depth:{front:['legR','armR','torso','legL','armL','head'],back:['legL','armL','torso','legR','armR','head']},animations:copy(animationDefaults),metadata:{name:'Mineclonie Human',author:'Mineclonie',source:'Reference preserving cutouts'},sprites:{front:{},back:{}}};
}
export function validateDocument(doc,{requireSprites=true}={}){
 assert(isObj(doc)&&isObj(doc.manifest)&&doc.manifest.format==='mineclonie-character-rig','Not a Mineclonie rig package');
 const m=doc.manifest;assert(m.schemaVersion===1,'Unsupported rig schema version '+m.schemaVersion);
 assert(typeof m.characterId==='string'&&/^[\w-]{3,80}$/.test(m.characterId),'Invalid character ID');
 assert(Number.isSafeInteger(m.revision)&&m.revision>=1,'Invalid revision');
 assert(isObj(doc.skeleton?.nodes),'Skeleton nodes missing');
 const ns=doc.skeleton.nodes;
 for(const [name,spec] of Object.entries(nodes)){
  const n=ns[name];assert(isObj(n)&&n.parent===spec.parent,'Skeleton hierarchy invalid: '+name);
  for(const k of ['x','y','rotation','scale'])assert(finite(n[k])&&Math.abs(n[k])<10000&&(k!=='scale'||n[k]>0),'Skeleton transform invalid: '+name+'.'+k);
 }
 // Prevent cycles or replacement of required nodes by a malicious patch.
 for(const key of Object.keys(ns)){const seen=new Set();let cur=key;while(cur!==null){assert(!seen.has(cur)&&isObj(ns[cur]),'Skeleton cycle or orphan: '+key);seen.add(cur);cur=ns[cur].parent;}}
 for(const view of VIEWS){
  assert(isObj(doc.pivots?.[view])&&isObj(doc.meshes?.[view]),'Rig view missing: '+view);
  const order=doc.depth?.[view];assert(Array.isArray(order)&&order.length===6&&new Set(order).size===6&&PARTS.every(n=>order.includes(n)),'Z order invalid: '+view);
  for(const n of PARTS){
   const p=doc.pivots[view][n],mesh=doc.meshes[view][n];
   assert(isObj(p),'Pivot missing: '+view+'/'+n);
   for(const k of ['x','y','px','py'])assert(finite(p[k])&&Math.abs(p[k])<=500,'Pivot invalid: '+view+'/'+n+'.'+k);
   assert(p.px>=0&&p.px<=100&&p.py>=0&&p.py<=100,'Pivot percentage invalid: '+view+'/'+n);
   assert(isObj(mesh)&&Number.isInteger(mesh.cols)&&mesh.cols>=1&&mesh.cols<=16&&Number.isInteger(mesh.rows)&&mesh.rows>=1&&mesh.rows<=24,'Mesh grid invalid: '+view+'/'+n);
   assert(Array.isArray(mesh.weights)&&mesh.weights.length===(mesh.cols+1)*(mesh.rows+1)&&mesh.weights.every(x=>finite(x)&&x>=0&&x<=1),'Mesh weights invalid: '+view+'/'+n);
   assert(finite(mesh.bendScale)&&mesh.bendScale>=0&&mesh.bendScale<=3,'Mesh bend scale invalid: '+view+'/'+n);
   if(requireSprites)validatePNG(doc.sprites?.[view]?.[n],view+'/'+n);
  }
 }
 for(const n of ['idle','walk','chop']){
  const a=doc.animations?.[n];assert(isObj(a)&&finite(a.duration)&&a.duration>.05&&a.duration<=30&&typeof a.loop==='boolean'&&isObj(a.parameters),'Animation invalid: '+n);
  for(const [key,val] of Object.entries(a.parameters))assert(/^[a-zA-Z][\w]{0,50}$/.test(key)&&finite(val)&&Math.abs(val)<200,'Animation parameter invalid: '+n+'.'+key);
 }
 assert(isObj(doc.metadata),'Metadata missing');return true;
}
export async function exportMrig(doc){validateDocument(doc);const files={};
 for(const n of ['manifest','metadata'])files[n+'.json']=JSON.stringify(doc[n]);
 for(const n of ['skeleton','meshes','pivots','depth'])files['rig/'+n+'.json']=JSON.stringify(doc[n]);
 for(const n of ['idle','walk','chop'])files['animations/'+n+'.json']=JSON.stringify(doc.animations[n]);
 for(const view of VIEWS)for(const part of PARTS)files[`sprites/${view}/${part}.png`]=await asBytes(doc.sprites[view][part]);
 return zipWrite(files);
}
export async function importMrig(input){const files=zipRead(await asBytes(input));
 const json=(path)=>{assert(files[path],`Missing file ${path}`);try{return JSON.parse(td.decode(files[path]))}catch{fail('Invalid JSON: '+path)}};
 const doc={manifest:json('manifest.json'),metadata:json('metadata.json'),skeleton:json('rig/skeleton.json'),meshes:json('rig/meshes.json'),pivots:json('rig/pivots.json'),depth:json('rig/depth.json'),animations:{},sprites:{front:{},back:{}}};
 for(const n of ['idle','walk','chop'])doc.animations[n]=json('animations/'+n+'.json');
 for(const view of VIEWS)for(const part of PARTS){const name=`sprites/${view}/${part}.png`;assert(files[name],`Missing PNG: ${name}`);doc.sprites[view][part]=files[name]}
 validateDocument(doc);return doc;
}
const merge=(base,update)=>{assert(isObj(update),'Patch update must be an object');for(const [key,value] of Object.entries(update)){assert(!['__proto__','constructor','prototype'].includes(key),'Forbidden patch key');base[key]=isObj(value)&&isObj(base[key])?merge(base[key],value):copy(value)}return base};
const allowed=new Set(['replaceAnimation','updateAnimation','setNode','setPivot','setMesh','setWeights','setDepthOrder','setAnimationParameters','replaceSprite']);
function spriteFromBase64(s){assert(typeof s==='string'&&s.length<11_000_000&&/^[A-Za-z0-9+/]+={0,2}$/.test(s),'Invalid base64 sprite');const binary=atob(s),b=new Uint8Array(binary.length);for(let i=0;i<b.length;i++)b[i]=binary.charCodeAt(i);return b}
export function applyRigPatch(doc,patch){
 validateDocument(doc);assert(isObj(patch)&&patch.format==='mineclonie-rig-patch'&&patch.schemaVersion===1,'Invalid patch format or schema');
 assert(patch.characterId===doc.manifest.characterId,'Character ID mismatch');
 assert(Number.isSafeInteger(patch.baseRevision)&&patch.baseRevision===doc.manifest.revision,'Patch base revision mismatch');
 assert(patch.targetRevision===patch.baseRevision+1,'Patch must advance exactly one revision');
 assert(Array.isArray(patch.operations)&&patch.operations.length>0&&patch.operations.length<=50,'Invalid patch operations');
 const next=copy(doc);
 for(const o of patch.operations){assert(isObj(o)&&allowed.has(o.op),'Unknown patch operation: '+o?.op);
  const view=o.view,part=o.part,name=o.name;
  if(['setPivot','setMesh','setWeights','setDepthOrder','replaceSprite'].includes(o.op))assert(VIEWS.includes(view),'Invalid view: '+view);
  if(['setPivot','setMesh','setWeights','replaceSprite'].includes(o.op))assert(PARTS.includes(part),'Invalid part: '+part);
  if(['replaceAnimation','updateAnimation','setAnimationParameters'].includes(o.op))assert(['idle','walk','chop'].includes(name),'Invalid animation: '+name);
  switch(o.op){
   case'replaceAnimation':next.animations[name]=copy(o.data);break;
   case'updateAnimation':merge(next.animations[name],o.values);break;
   case'setAnimationParameters':merge(next.animations[name].parameters,o.values);break;
   case'setNode':assert(typeof o.node==='string'&&Object.hasOwn(next.skeleton.nodes,o.node),'Unknown node');assert(!('parent'in (o.values||{})),'Parent changes not allowed');merge(next.skeleton.nodes[o.node],o.values);break;
   case'setPivot':merge(next.pivots[view][part],o.values);break;
   case'setMesh':next.meshes[view][part]=copy(o.data);break;
   case'setWeights':next.meshes[view][part].weights=copy(o.weights);break;
   case'setDepthOrder':next.depth[view]=copy(o.order);break;
   case'replaceSprite':next.sprites[view][part]=spriteFromBase64(o.pngBase64);break;
  }
 }
 next.manifest.revision=patch.targetRevision;
 validateDocument(next);return next; // atomic: original doc never mutated
}