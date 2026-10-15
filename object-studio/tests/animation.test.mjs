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

test('final variant editor exports individual PNG and splits 32 into chunks',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['editorExport','editorGeometry','pointermove','finalId','offsetX','offsetY'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(js);
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});assert.equal(syntax.status,0,syntax.stderr);
});

test('spritesheet chunk export belongs to main animation export',()=>{
 const main=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 const compare=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['exportChunk','exportChunkCustom','16 karelik parçalar','mineclonie_spritesheet_'])assert.ok(main.includes(key),'missing '+key);
 assert.ok(!compare.includes('id="chunkExport"'),'comparison must not have chunk export');
 const js=main.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(syntax.status,0,syntax.stderr);
});

test('comparison merges ordered spritesheet PNG parts',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['input.multiple=true','combineParts(v)','partOrder(parts)','partStart(name)','Birleşik varyant'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(syntax.status,0,syntax.stderr);
});

test('spritesheet export preserves a fixed coordinate system across chunks',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ['sourceW=Math.max','sourceH=Math.max','fx=f.original?.x','fy=f.original?.y','Math.round(cx*size/cols)','Math.round(cy*size/rows)'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(syntax.status,0,syntax.stderr);
});

test('animation pages expose stamped build and live freshness status',()=>{
 for(const page of ['animation.html','animation-compare.html']){
  const source=fs.readFileSync(path.join(root,'src',page),'utf8');
  for(const key of ['versionBar','pageBuild','versionState','versionRefresh','version_check=','cache:\'no-store\''])assert.ok(source.includes(key),'missing '+key+' in '+page);
 }
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 for(const page of ['animation.html','animation-compare.html']){
  const built=fs.readFileSync(path.join(root,'dist',page),'utf8');
  assert.ok(built.includes('0123456789abcdef0123456789abcdef01234567'));
  assert.ok(!built.includes('__ANIMATION_BUILD_SHA__'));
 }
});

test('all four Studio pages show shared build and refresh-all control',()=>{
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 for(const name of ['latest.html','terrain.html','animation.html','animation-compare.html']){
  const page=fs.readFileSync(path.join(root,'dist',name),'utf8');
  for(const key of ['studioBuildBar','studioRefreshAll','Tüm sayfaları güncelle','0123456789abcdef0123456789abcdef01234567'])assert.ok(page.includes(key),name+' missing '+key);
 }
});

test('final alignment has independent reference and variant scales',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['editorScale','autoScale','g.refScale','referenceScaleFactor','v.scale'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('sequential 16+16 variant uploads preserve 32 frame indices',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['const previous=v.parts||[]','assembleParts([...previous,...incoming])','v.ranges=merged.positions','editorIndex+1>=p.start'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('final alignment editor uses exact frame index and alpha bounds',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ["stored[dir][editorIndex]","id=\"editorJump\"","g.rx,g.ry","ib[0]+ib[2]/2"])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('comparison shows source and AI file names with selectable previous-frame ghost',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 const main=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ['ghostMode','ghostRecord(v,i,originalRef)','Nihai varyantın önceki karesi','AI çıktısı:','Dosyalar:','ghostInfo'])assert.ok(html.includes(key),'missing '+key);
 assert.ok(main.includes('editedName:file.name'),'AI replacement filename must be stored');
 for(const page of [html,main])for(const match of page.matchAll(/<script>([\s\S]*?)<\/script>/g)){
  const js=match[1].replaceAll('__ANIMATION_BUILD_SHA__','0123456789abcdef0123456789abcdef01234567');
  const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
  assert.equal(check.status,0,check.stderr);
 }
});

test('AI spritesheet parts retain upload order and support manual reordering',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['Parça sırası (elle değiştir)','p.manualOrder=true','part.manualOrder===true?null:partRange(part.name)','assembleParts([...previous,...incoming])'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('automatic silhouette registration and per-frame transforms are present',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['autoAlignOne','autoAlignAll','registerColor(moving,reference','registrationScore','alphaSample','off.scale=scale','runAutoAlignment(true)','autoIterations','colorWeight'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('color-aware iterative registration samples correct image source rectangle',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 assert.ok(html.includes('c.drawImage(image,b[0],b[1],Math.max(1,b[2]),Math.max(1,b[3]),0,0,N,N)'));
 assert.ok(html.includes('for(let iter=0;iter<iterations;iter++)'));
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});
