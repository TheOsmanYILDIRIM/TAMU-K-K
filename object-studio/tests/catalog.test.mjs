import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {CATALOG,BIOMES,STAGES,SLOTS,STYLE,assetById,slotKey} from '../src/catalog.js';
import {promptFor} from '../src/prompts.js';
test('minimal biome and core model contract',()=>{
 assert.deepEqual(BIOMES.map(b=>b.id),['meadow','forest','rocky']);
 assert.equal(CATALOG.length,7);
 assert.deepEqual(CATALOG.filter(a=>a.family==='tree').map(a=>a.id),['T-01','T-02','T-03']);
 assert.deepEqual(CATALOG.filter(a=>a.family==='rock').map(a=>a.id),['R-01','R-02','R-03','R-04']);
 assert.equal(new Set(CATALOG.map(a=>a.id)).size,7);
 assert.equal(STAGES.length,6);
 assert(!STAGES.some(s=>s.id==='layers'));
 assert(!SLOTS.some(s=>['base','body','upper','front'].includes(s.id)));
 assert.equal(new Set(SLOTS.map(x=>x.id)).size,SLOTS.length);
 assert.match(STYLE.target,/dark-fantasy/);
 for(const a of CATALOG){
  assert.deepEqual(a.forms.length>=3,true);assert.deepEqual(a.surfaces.length>=3,true);
  assert(a.footprint.every(n=>n>0));assert(a.roles.every(r=>BIOMES.some(b=>b.id===r)));
  assert.equal(assetById(a.id),a);
  for(const stage of ['reference','creative','correction','maps']){
   const prompt=promptFor(a,stage,0,0,a.roles[0]);
   assert(prompt?.includes(a.id));assert(prompt.length>420);
  }
  assert.equal(promptFor(a,'unknown',0,0,'forest'),null);
 }
 assert.equal(promptFor(null,'creative',0,0,'meadow'),null);
 assert.equal(slotKey('T-01',0,2,'corrected'),'T-01::0::2::corrected');
});
test('stage prompts enforce square alpha and locked composition',()=>{
 const a=CATALOG[0];
 assert.match(promptFor(a,'creative',0,0,'forest'),/1024×1024/);
 assert.match(promptFor(a,'creative',0,0,'forest'),/transparen/i);
 assert.match(promptFor(a,'correction',0,0,'forest'),/Image A = approved creative design/i);
 assert.match(promptFor(a,'correction',0,0,'forest'),/Image A is NOT the style source/i);
 assert.match(promptFor(a,'correction',0,0,'forest'),/Image B's object language/i);
 assert.match(promptFor(a,'correction',0,0,'forest'),/Image B = approved MATERIAL AND STYLE MASTER/i);
 assert.match(promptFor(a,'maps',0,0,'forest'),/Normal encodes surface lighting detail only/i);
 assert.equal(promptFor(a,'layers',0,0,'forest'),null);
});
test('one sprite and preserved legacy data policy',()=>{
 const preview=fs.readFileSync(new URL('../src/preview.js',import.meta.url),'utf8');
 const app=fs.readFileSync(new URL('../src/app.js',import.meta.url),'utf8');
 assert.match(preview,/getSilhouetteMask/);
 assert.match(preview,/globalCompositeOperation='source-in'/);
 assert.match(preview,/paintProjectedShadow/);
 assert(!preview.includes('gw*.27,gh*.40'));
 assert(!app.includes('layerPromptPicker'));
 assert.match(app,/legacyLayer/);
 assert.match(app,/\['base','body','upper','front'\]/);
});
test('browser imports and user data safety boundaries',()=>{
 const app=fs.readFileSync(new URL('../src/app.js',import.meta.url),'utf8');
 const storage=fs.readFileSync(new URL('../src/storage.js',import.meta.url),'utf8');
 assert.match(app,/const BUILD='__BUILD_SHA__'/);
 assert.match(app,/cache:'no-store'/);
 assert.match(storage,/OsmanObjectStudioAssets/);
 assert.match(storage,/osman:object-studio:v1:metadata/);
 assert(!storage.includes('MinecloniaTextureStudio'));
 assert.match(storage,/validateBackup/);
 assert.match(storage,/inspectPng/);
});
