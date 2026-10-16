import test from 'node:test';
import assert from 'node:assert/strict';
import {PARTS,VIEWS,defaultDocument,validateDocument,importMrig,exportMrig,applyRigPatch} from '../src/rig-package.js';
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGPM7474z8DAwMDEAAUAI18CVaxRIwoAAAAASUVORK5CYII=','base64');
function fixture(){const doc=defaultDocument('mineclonie-test-001');for(const view of VIEWS)for(const name of PARTS)doc.sprites[view][name]=new Uint8Array(png);return doc}
const basePatch={format:'mineclonie-rig-patch',schemaVersion:1,characterId:'mineclonie-test-001',baseRevision:1,targetRevision:2};
test('MRIG round-trip preserves all 12 PNGs, anatomical IDs, meshes, and animation data',async()=>{
 const d=fixture();const b=await exportMrig(d),read=await importMrig(b);validateDocument(read);
 for(const view of VIEWS)for(const part of PARTS){assert.equal(Buffer.compare(Buffer.from(read.sprites[view][part]),png),0);assert.equal(read.meshes[view][part].weights.length,24)}
 assert.equal(read.skeleton.nodes.armL.parent,'shoulderL');assert.equal(read.skeleton.nodes.armR.parent,'shoulderR');
 assert.equal(read.skeleton.nodes.legL.parent,'hipL');assert.equal(read.skeleton.nodes.legR.parent,'hipR');
 assert.equal(new Set(read.depth.front).size,6);assert.equal(new Set(read.depth.back).size,6);
});
test('corrupted sprite or ZIP central directory fails closed',async()=>{
 const a=new Uint8Array(await(await exportMrig(fixture())).arrayBuffer());
 const broken=new Uint8Array(a);broken[220]^=57;await assert.rejects(importMrig(broken),/CRC mismatch/i);
 const tail=new Uint8Array(a);tail[tail.length-70]^=11;await assert.rejects(importMrig(tail),/Invalid|ZIP|Mismatch|path/i);
});
test('patch is atomic, preserves untouched animation/sprites and rejects duplicate revisions',async()=>{
 const d=fixture(),patch={...basePatch,operations:[{op:'setAnimationParameters',name:'walk',values:{stepX:5.25,footLift:7.1}}]};
 const changed=applyRigPatch(d,patch);assert.equal(changed.manifest.revision,2);assert.equal(d.manifest.revision,1);
 assert.equal(changed.animations.walk.parameters.stepX,5.25);assert.deepEqual(changed.animations.idle,d.animations.idle);
 assert.equal(Buffer.compare(Buffer.from(changed.sprites.front.head),Buffer.from(d.sprites.front.head)),0);
 assert.throws(()=>applyRigPatch(changed,patch),/base revision/i);
 assert.throws(()=>applyRigPatch(d,{...patch,characterId:'someone-else'}),/Character ID/);
 assert.throws(()=>applyRigPatch(d,{...patch,baseRevision:0}),/base revision/);
});
test('all supported patch operations validate completely before producing a new document',()=>{
 const d=fixture(),operations=[
 {op:'replaceAnimation',name:'idle',data:{duration:3,loop:true,parameters:{breath:.8}}},
 {op:'updateAnimation',name:'walk',values:{parameters:{stepY:4.2}}},
 {op:'setNode',node:'shoulderL',values:{rotation:.08}},
 {op:'setPivot',view:'back',part:'armR',values:{x:18}},
 {op:'setMesh',view:'front',part:'armL',data:{cols:1,rows:1,weights:[0,.25,.6,1],bendScale:1}},
 {op:'setWeights',view:'front',part:'armL',weights:[0,0,1,1]},
 {op:'setDepthOrder',view:'front',order:['legL','legR','armL','torso','armR','head']},
 {op:'setAnimationParameters',name:'chop',values:{armRaise:.34}},
 {op:'replaceSprite',view:'back',part:'torso',pngBase64:png.toString('base64')}
 ];const next=applyRigPatch(d,{...basePatch,operations});assert.equal(next.skeleton.nodes.shoulderL.rotation,.08);assert.equal(next.animations.walk.parameters.stepY,4.2);
 assert.deepEqual(next.meshes.front.armL.weights,[0,0,1,1]);assert.equal(d.skeleton.nodes.shoulderL.rotation,0);
 const corrupt={...basePatch,operations:[{op:'setWeights',view:'front',part:'armL',weights:[2]}]};
 assert.throws(()=>applyRigPatch(d,corrupt),/Mesh weights/);assert.equal(d.manifest.revision,1);
});
test('deployed module JavaScript must remain syntactically valid',async()=>{
 // This test is run alongside build.mjs, which copies these files unchanged to Pages.
 const cp=await import('node:child_process'),path=await import('node:path');const root=path.resolve(import.meta.dirname,'..');
 for(const s of ['rig-package.js','rig-workspace.js']){
  const c=cp.spawnSync(process.execPath,['--check','src/'+s],{cwd:root,encoding:'utf8'});
  assert.equal(c.status,0,s+': '+c.stderr);
 }
});