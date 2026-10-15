import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
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
 assert.ok(html.includes('N/2-b[2]*factor/2,N/2-b[3]*factor/2'),'visual sprite must preserve natural aspect ratio');
 assert.ok(html.includes('for(let p=0;p<passes;p++'));
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('iterative registration keeps alpha-derived size stable and supports repeat passes',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['autoLockSize','autoAgain','off.registrationSeed','for(let p=0;p<passes;p++','if(onPass)onPass(p+1,best)','const globalScale=ratios.length'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('registration optimizer really improves across passes and ignores nearly-transparent RGB halos',async()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 const core=html.match(/\/\/ ALIGNMENT_CORE_BEGIN([\s\S]*?)\/\/ ALIGNMENT_CORE_END/)?.[1];
 assert.ok(core,'registration functions must be independently testable');
 const {registrationScore,optimizeDescriptors}=vm.runInNewContext(core+'\n({registrationScore,optimizeDescriptors})',{setTimeout});
 const n=64;
 function fixture(tx=0,ty=0){
  const alpha=new Uint8Array(n*n),rgb=new Uint8Array(n*n*3);
  for(let y=0;y<n;y++)for(let x=0;x<n;x++){
   const px=x-tx,py=y-ty,inside=((px-32)**2/250+(py-30)**2/400<1)||(px>16&&px<29&&py>32&&py<58);
   if(inside){const i=y*n+x;alpha[i]=255;rgb[i*3]=px>32?110:205;rgb[i*3+1]=py>35?150:83;rgb[i*3+2]=px>30?73:140;}
  }
  return {n,alpha,rgb};
 }
 const ref=fixture(),moved=fixture(23,-11);
 const first=await optimizeDescriptors(ref,moved,1,.7,{tx:0,ty:0,scale:1},true);
 const refined=await optimizeDescriptors(ref,moved,12,.7,{tx:0,ty:0,scale:1},true);
 assert.ok(refined.score>=first.score+.03,'additional iterations must materially improve overlap');
 assert.ok(Math.abs(refined.tx+23)<2&&Math.abs(refined.ty-11)<2,'known movement should be recovered');
 assert.equal(refined.scale,1,'locked scale must not drift');
 const clean=registrationScore(ref,moved,-23,11,1,.7);
 moved.alpha[0]=1;moved.rgb[0]=255;
 assert.equal(registrationScore(ref,moved,-23,11,1,.7),clean,'alpha=1 RGB halo must not affect matching');
});

test('aligned variant preview uses the editor transform and can export PNG and ZIP',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['paintEntry(ctx,e','finalId===e.id','editorGeometry(im,ref,ctx.canvas.width','draw(); // The selected variant preview','alignedSheetExport','alignedZipExport','paintAlignedFrame(sheet','zipStored(files)','manifest.json']){
  assert.ok(html.includes(key),'missing '+key);
 }
 const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
 for(const match of scripts){const check=spawnSync(process.execPath,['--check'],{input:match[1],encoding:'utf8'});assert.equal(check.status,0,check.stderr)}
});

test('aligned sprite ZIP writer creates a valid local and central directory',async()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(js);
 const begin=js.indexOf('function zipStored(files){'),end=js.indexOf('\nasync function exportAligned(',begin);
 assert.ok(begin>=0&&end>begin,'ZIP writer source missing');
 const src=js.slice(begin,end);
 const zipStored=vm.runInNewContext(src+'\nzipStored',{Blob,TextEncoder,Uint8Array,DataView,ArrayBuffer});
 const blob=zipStored([{name:'SE/frame_01.png',data:Uint8Array.from([137,80,78,71])},{name:'manifest.json',data:new TextEncoder().encode('{}')}]);
 const bytes=Buffer.from(await blob.arrayBuffer());
 assert.equal(bytes.readUInt32LE(0),0x04034b50);
 assert.equal(bytes.readUInt32LE(bytes.length-22),0x06054b50);
 assert.equal(bytes.readUInt16LE(bytes.length-12),2,'ZIP end record entry count');
 assert.equal(bytes.readUInt16LE(bytes.length-14),2,'ZIP entry count on disk');
 assert.ok(bytes.readUInt32LE(bytes.length-10)>0,'Central directory must not be empty');
});

test('size matching applies to every final variant frame and retains X/Y offsets',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['id="autoScaleAll"','async function matchFrameSize(v,i)','for(let i=0;i<v.frames.length;i++)','o.scale=factor','await matchFrameSize(v,i)','await updateEditor()']){
  assert.ok(html.includes(key),'missing '+key);
 }
 const fn=html.slice(html.indexOf('async function matchFrameSize(v,i)'),html.indexOf('let matchingAllSizes=',html.indexOf('async function matchFrameSize(v,i)')));
 assert.ok(!fn.includes('o.x='),'matching size must not overwrite X');
 assert.ok(!fn.includes('o.y='),'matching size must not overwrite Y');
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});
