import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..');
test('standalone mobile animation page preserves independent project storage',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ['ANIMATION STUDIO','OsmanAnimationStudioFramesV1','[data-rate]','100','50','25','loadPNG','loadZIP','loadSheet','replace','average','downloadAll','pngBytes','drawNoncontactGrid'])assert.ok(html.includes(key),'missing '+key);
 for(const dir of ['NE','NW','SE','SW'])assert.match(html,new RegExp('data-direction="'+dir+'"'),'missing direction '+dir);
 for(const key of ['importGroups(groups)','let groups={NE:[],NW:[],SE:[],SW:[]}','clearDirection(d)','slot:d+\':\'+i','moveEnabled=false','if(!moveEnabled||!frames[selected]'])assert.ok(html.includes(key),'missing '+key);
 for(const key of ['exportSheet','exportScope','exportSize','exportCols','sheetCols','sheetRows','max="60"'])assert.ok(html.includes(key),'missing '+key);
 assert.ok(!html.includes("$('moveToggle').onclick"),'preview dragging must stay disabled');
 assert.ok(!html.includes('let chosen=matches.filter'),'ZIP importer must not silently restrict to SE');
 assert.ok(html.includes('width=device-width'));
 assert.ok(!html.includes('OsmanTerrainStudioAssets')&&!html.includes('OsmanObjectStudioAssets'));
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(js);
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});assert.equal(syntax.status,0,syntax.stderr);
});
test('production build includes new animation page and both navigation links',()=>{
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 assert.match(fs.readFileSync(path.join(root,'dist/animation.html'),'utf8'),/ANIMATION STUDIO/);
 assert.match(fs.readFileSync(path.join(root,'dist/latest.html'),'utf8'),/href="\.\/animation\.html"/);
 assert.match(fs.readFileSync(path.join(root,'dist/terrain.html'),'utf8'),/href="\.\/animation\.html"/);
});

test('comparison page is packaged and preserves original frames',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['VARYANT KARŞILAŞTIRMA','OsmanAnimationStudioFramesV1','original','edited','addVariant','loadVariant','readwrite']) {
   if(key==='readwrite') assert.ok(!html.includes("transaction('frames','readwrite')"));
   else assert.ok(html.includes(key),'missing '+key);
 }
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 assert.ok(js);
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(syntax.status,0,syntax.stderr);
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 assert.ok(fs.existsSync(path.join(root,'dist/animation-compare.html')));
});

test('variant comparison has average, dynamic variants and focus controls',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['addVariant','focusTitle','back','Ortalama konum','Ortalama kare','loadVariant','rebuild()'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(js);
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});assert.equal(syntax.status,0,syntax.stderr);
});
