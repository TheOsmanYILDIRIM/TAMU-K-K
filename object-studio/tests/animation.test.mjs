import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..');
test('mobile animation is one preview, single-frame only, preserves IndexedDB records',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const k of ['ANIMATION STUDIO','OsmanAnimationStudioFramesV1','data-mode="compare"','id="stage"','id="sourceInput"','id="variantInput"','id="exportOriginal"','id="exportMask"','id="openBlender"','id="strip"','makeMask(','constrainVariant(','restore()','SE','SW','NE','NW'])assert.ok(html.includes(k),'missing '+k);
 for(const forbidden of ['spritesheet','Spritesheet','loadMasterMask','exportSheetMask','drawNoncontactGrid','drawDualMagentaGuide','sheetCols','JSZip'])assert.ok(!html.includes(forbidden),'retired UX remains: '+forbidden);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(js,'missing inline script');
 const run=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});assert.equal(run.status,0,run.stderr);
 assert.ok(html.includes("r.source instanceof Blob"),'legacy source must be read without modifying DB');
 assert.ok(html.includes("slot:d+':'+i"),'existing per-direction keys must stay compatible');
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

test('single PNG export preserves source, variant and auto mask without external atlas import',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ["makeMask(d,i)","255-data.data[k+3]","constrainVariant(file,src)","result.data[k+3]=alpha","frame_'+String(i+1).padStart(2,'0')","zipOriginal","zipMasks"]){
   assert.ok(html.includes(key),'missing mask safety '+key);
 }
 assert.ok(!html.includes("loadMasterMask"));
});
test('comparison merges ordered spritesheet PNG parts',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['input.multiple=true','combineParts(v)','partOrder(parts)','partStart(name)','Birleşik varyant'])assert.ok(html.includes(key),'missing '+key);
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const syntax=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(syntax.status,0,syntax.stderr);
});

test('single-frame ZIP input is bounded, verified and independent of page layout',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ['function unzip(file)','function crc32(data)','ZIP doğrulaması başarısız','File([data],name','function makeZip(files)','ZIP boyutu çok büyük'])
   assert.ok(html.includes(key),'missing '+key);
 assert.ok(html.includes("frameNumber(a.name)-frameNumber(b.name)"));
});
test('new animation is a standalone stamped build; archived variant keeps version guard',()=>{
 const source=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const key of ['__ANIMATION_BUILD_SHA__','buildBadge','version_check=','cache:\'no-store\'','id="refresh"'])assert.ok(source.includes(key),'missing '+key);
 const compare=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['versionBar','pageBuild','versionState','versionRefresh'])assert.ok(compare.includes(key),'archived screen lost '+key);
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 const built=fs.readFileSync(path.join(root,'dist/animation.html'),'utf8');
 assert.ok(built.includes('0123456789abcdef0123456789abcdef01234567'));
 assert.ok(!built.includes('__ANIMATION_BUILD_SHA__'));
});
test('shared build version remains on other pages without cluttering new animation stage',()=>{
 const run=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:'0123456789abcdef0123456789abcdef01234567'},encoding:'utf8'});
 assert.equal(run.status,0,run.stderr);
 for(const name of ['latest.html','terrain.html','animation-compare.html']){
   const page=fs.readFileSync(path.join(root,'dist',name),'utf8');
   assert.ok(page.includes('studioBuildBar')&&page.includes('0123456789abcdef0123456789abcdef01234567'));
 }
 const page=fs.readFileSync(path.join(root,'dist/animation.html'),'utf8');
 assert.ok(page.includes('id="stage"')&&page.includes('0123456789abcdef0123456789abcdef01234567'));
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
 for(const key of ["getOriginalDisplayReference(v,editorIndex)","id=\"editorJump\"","g.rx,g.ry","ib[0]+ib[2]/2"])assert.ok(html.includes(key),'missing '+key);
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
 for(const key of ['autoLockSize','autoAgain','off.registrationSeed','for(let p=0;p<passes;p++','if(onPass)onPass(p+1,best)','const scales=await buildScaleTargets(v)'])assert.ok(html.includes(key),'missing '+key);
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
 for(const key of ['id="autoScaleAll"','async function matchFrameSize(v,i,targets=null)','await executeAlignmentPlan(jobs','o.scale=factor','await matchFrameSize(v,job.index,targets)','await updateEditor()']){
  assert.ok(html.includes(key),'missing '+key);
 }
 const fn=html.slice(html.indexOf('async function matchFrameSize(v,i,targets=null)'),html.indexOf('let matchingAllSizes=',html.indexOf('async function matchFrameSize(v,i,targets=null)')));
 assert.ok(!fn.includes('o.x='),'matching size must not overwrite X');
 assert.ok(!fn.includes('o.y='),'matching size must not overwrite Y');
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const check=spawnSync(process.execPath,['--check'],{input:js,encoding:'utf8'});
 assert.equal(check.status,0,check.stderr);
});

test('a two-part 16+16 variant gets all 32 alignment jobs even if original has 16',async()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 const core=html.match(/\/\/ ALIGNMENT_SEQUENCE_BEGIN([\s\S]*?)\/\/ ALIGNMENT_SEQUENCE_END/)?.[1];
 assert.ok(core,'sequence alignment functions must be independently testable');
 const {buildAlignmentPlan,executeAlignmentPlan}=vm.runInNewContext(core+'\n({buildAlignmentPlan,executeAlignmentPlan})');
 const parts=[{start:1,end:16,name:'first_01-16.png'},{start:17,end:32,name:'second_17-32.png'}];
 const jobs=buildAlignmentPlan(32,16,'original',null,parts);
 assert.equal(jobs.length,32);
 assert.equal(jobs[0].referenceIndex,0);
 assert.equal(jobs[15].partName,'first_01-16.png');
 assert.equal(jobs[16].partName,'second_17-32.png');
 assert.equal(jobs[16].referenceIndex,8,'second half must use phase-mapped reference, not silently skip');
 assert.equal(jobs[31].referenceIndex,15);
 const touched=[];
 const result=await executeAlignmentPlan(jobs,async job=>{touched.push(job.index);return {score:1}});
 assert.equal(result.length,32);
 assert.deepEqual(touched,Array.from({length:32},(_,i)=>i),'both PNGs must be evaluated');
 const full=buildAlignmentPlan(32,32,'original',null,parts);
 assert.ok(full.every((job,i)=>job.type==='original-exact'&&job.referenceIndex===i));
 const noOriginal=buildAlignmentPlan(32,0,'original',null,parts);
 assert.equal(noOriginal[0].type,'anchor');
 assert.ok(noOriginal.slice(1).every((job,i)=>job.type==='previous'&&job.referenceIndex===i));
 const prev=buildAlignmentPlan(32,16,'previous',null,parts);
 assert.equal(prev[16].referenceIndex,15,'seam should see last frame of previous image');
});
test('size correction handles different resolutions in the two imported PNGs',async()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 const core=html.match(/\/\/ ALIGNMENT_SEQUENCE_BEGIN([\s\S]*?)\/\/ ALIGNMENT_SEQUENCE_END/)?.[1];
 const {buildAlignmentPlan}=vm.runInNewContext(core+'\n({buildAlignmentPlan})');
 const from=html.indexOf('async function buildScaleTargets(v){');
 const to=html.indexOf('\nasync function matchFrameSize(',from);
 assert.ok(from>=0&&to>from);
 const calc=html.slice(from,to);
 const medianOf=n=>n.length?[...n].sort((a,b)=>a-b)[Math.floor(n.length/2)]:null;
 const context={
  buildAlignmentPlan,stored:{SE:new Array(16).fill(true)},dir:'SE',
  getAlignmentReference:async()=>({h:100}),
  bounds:image=>[0,0,100,image.h],
  medianOf,Math
 };
 const {buildScaleTargets}=vm.runInNewContext(calc+'\n({buildScaleTargets})',context);
 const frames=Array.from({length:32},(_,i)=>({h:i<16?100:200}));
 const parts=[{start:1,end:16,name:'first'},{start:17,end:32,name:'second'}];
 const scales=await buildScaleTargets({frames,ranges:parts});
 assert.equal(scales.length,32);
 assert.ok(scales.slice(0,16).every(x=>Math.abs(x-1)<1e-8),'first PNG scale must remain 1x');
 assert.ok(scales.slice(16).every(x=>Math.abs(x-.5)<1e-8),'second PNG must be scaled independently');
});

test('editor, live preview and exports share the same mapped original geometry for all segments',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of [
  'g=editorGeometry(im,original,canvas.width',
  'prevRef=await getOriginalDisplayReference(v,editorIndex-1)',
  'const ref=await getOriginalDisplayReference(v,i);',
  'ref=await getOriginalDisplayReference(v,editorIndex)',
  'async function paintAlignedFrame'
 ])assert.ok(html.includes(key),'missing '+key);
 const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const result=spawnSync(process.execPath,['--check'],{input:script,encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);
});


test('animation no longer generates magenta guides or sprite atlas',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 for(const forbidden of ['drawDualMagentaGuide','drawNoncontactGrid','exportAIGrid','exportGridDensity','magenta grid','spritesheet']){
   assert.ok(!html.includes(forbidden),'legacy guide remains: '+forbidden)
 }
 assert.ok(html.includes('getImageData')&&html.includes('putImageData'));
});
test('3×3 PNGs preserve 8 real frames and omit trailing ninth blank slot when merging pages',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation-compare.html'),'utf8');
 for(const key of ['defaultFilledFrames','countInput.onchange','manualFrameCount','slots.slice(0,filled)']){
  assert.ok(html.includes(key),'missing per-part frame count logic: '+key);
 }
 const js=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
 const begin=js.indexOf('function partRange(name){'),end=js.indexOf('function combineParts(v){',begin);
 assert.ok(begin>=0&&end>begin);
 const {assembleParts}=vm.runInNewContext(js.slice(begin,end)+'\n({assembleParts})',{
  split:(image,cols,rows)=>Array.from({length:cols*rows},(_,i)=>image.tag+'-'+i)
 });
 const page1={name:'SE/sayfa_01_of_02_frames_01-08.png',image:{tag:'a'},cols:3,rows:3,order:0};
 const page2={name:'SE/sayfa_02_of_02_frames_09-16.png',image:{tag:'b'},cols:3,rows:3,order:1};
 const merged=assembleParts([page1,page2]);
 assert.equal(merged.frames.length,16);
 assert.equal(merged.frames[7],'a-7');
 assert.equal(merged.frames[8],'b-0');
 assert.equal(merged.positions[1].start,9);
 const renamed=assembleParts([{name:'AI_generated.png',image:{tag:'x'},cols:3,rows:3,usedFrames:8,manualFrameCount:true}]);
 assert.equal(renamed.frames.length,8);
 const nine=assembleParts([{name:'full_nine.png',image:{tag:'x'},cols:3,rows:3}]);
 assert.equal(nine.frames.length,9,'true 9-frame sheet must remain supported');
 assert.throws(()=>assembleParts([{name:'invalid.png',image:{tag:'x'},cols:3,rows:3,usedFrames:10}]));
});

test('AI variant is clipped to source silhouette and original is never silently replaced',()=>{
 const html=fs.readFileSync(path.join(root,'src/animation.html'),'utf8');
 assert.ok(html.includes("result.data[k+3]=alpha"),'variant alpha must equal canonical source alpha');
 assert.ok(html.includes("source:frame.source"),'original source Blob must be retained');
 assert.ok(html.includes("variant:blob"),'AI variant is stored separately');
 assert.ok(html.includes("const changed={...fr,variant:blob"),'variant write must retain source');
 assert.ok(html.includes("source:r.source"),'pre-existing records must restore');
 assert.ok(html.includes("new Blob([...parts,...central,end]"),'ZIP should be self-contained');
});
