// Tiny strict offline ES Module bundler for this fixed first-party app graph.
// No dynamic imports, eval, external scripts or build-time network calls.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=path.resolve(import.meta.dirname,'..');
const modules=['catalog.js','prompts.js','storage.js','image-tools.js','preview.js','app.js'];
const declared=new Set();
let output='"use strict";\n';
const moduleNames=[];
for(const filename of modules){
  let source=fs.readFileSync(path.join(root,'src',filename),'utf8');
  const importLines=source.match(/^import\s+\{[^}]+\}\s+from\s+['"]\.\/[\w.-]+\.js['"];?\s*$/gm)||[];
  for(const line of importLines){
    const names=line.match(/\{([^}]+)\}/)[1].split(',').map(x=>x.trim());
    for(const name of names)if(!declared.has(name))throw new Error(filename+': unknown/imported before export '+name);
  }
  source=source.replace(/^import\s+\{[^}]+\}\s+from\s+['"]\.\/[\w.-]+\.js['"];?\s*$/gm,'');
  if(/\bimport\s*\(|\bexport\s+(?:default|\{)|^import\s/m.test(source))throw new Error('Unsupported module syntax: '+filename);
  const regex=/\bexport\s+(?:async\s+)?(?:function|const|let|class)\s+([A-Za-z_$][\w$]*)/g;
  for(const match of source.matchAll(regex))declared.add(match[1]);
  source=source.replace(/^export\s+(?=(?:async\s+)?(?:function|const|let|class)\s+)/gm,'');
  output+='\n// MODULE '+filename+'\n'+source+'\n';moduleNames.push(filename);
}
const sha=process.env.BUILD_SHA||'local-dev';
if(!/^[\w.-]{5,64}$/.test(sha))throw new Error('Invalid BUILD_SHA');
if(!output.includes('__BUILD_SHA__'))throw new Error('Missing build marker');
output=output.replaceAll('__BUILD_SHA__',sha);
const escaped=output.replaceAll('</script','<\\/script');
const css=fs.readFileSync(path.join(root,'src','styles.css'),'utf8');
const template=fs.readFileSync(path.join(root,'src','index.html'),'utf8');
if(!template.includes('<!-- INLINE_SCRIPT -->')||!template.includes('<!-- INLINE_STYLES -->'))throw new Error('Bad template');
const html=template.replace('<!-- INLINE_STYLES -->','<style>'+css+'</style>').replace('<!-- INLINE_SCRIPT -->','<script>'+escaped+'</script>');

const sharedVersionUI=(page,commit,base='./')=>{
 const pages=[['Obje','latest.html'],['Terrain','terrain.html'],['Animasyon','animation.html'],['Varyant','animation-compare.html']];
 const nav=pages.map(([label,file])=>'<a href="'+base+file+'?build='+commit+'" style="color:#d8edc0;margin-right:9px">'+label+'</a>').join('');
 const bar='<div id="studioBuildBar" style="position:relative;z-index:9999;padding:9px 12px;background:#142b21;color:#ecf7e6;font:12px system-ui;border-bottom:2px solid #7c9e74;display:flex;flex-wrap:wrap;align-items:center;gap:8px"><b>BUILD '+commit.slice(0,10)+'</b><span id="studioBuildState">Yayın kontrol ediliyor…</span><button id="studioRefreshAll" style="padding:7px;border-radius:7px;background:#c8dfa5;color:#102219;border:0;font-weight:700">Tüm sayfaları güncelle ↻</button><nav>'+nav+'</nav></div>';
 const script=`<script>(()=>{const current=${JSON.stringify(commit)},files=['latest.html','terrain.html','animation.html','animation-compare.html'],state=document.getElementById('studioBuildState'),button=document.getElementById('studioRefreshAll');async function live(){try{const r=await fetch('./build.json?verify='+Date.now(),{cache:'no-store'});if(!r.ok)throw Error('HTTP '+r.status);const sha=(await r.json()).sha;if(sha===current){state.textContent='✓ Güncel yayın';state.style.color='#b9e9a9'}else{state.textContent='⚠ Önbellekte eski sürüm · yayın '+sha.slice(0,10);state.style.color='#ffd38d'}return sha}catch(e){state.textContent='Sürüm doğrulanamadı';return null}}button.addEventListener('click',async()=>{button.disabled=true;state.textContent='Sayfalar yenileniyor…';const sha=await live();const tag=sha||Date.now().toString();await Promise.allSettled(files.map(f=>fetch('./'+f+'?refresh='+tag+'-'+Date.now(),{cache:'reload'})));const url=new URL(location.href);url.searchParams.set('build',tag);url.searchParams.set('refresh',Date.now().toString());location.replace(url.href)});live()})();</script>`;
 return page.replace(/<div id="versionBar"[\\s\\S]*?<\\/div>/,'').replace(/<script>\\s*\\(\\(\\)=>\\{const stamp='__ANIMATION_BUILD_SHA__'[\\s\\S]*?<\\/script>/,'').replace(/<body([^>]*)>/i,(m)=>m+bar).replace('</body>',script+'</body>');
};

const dist=path.join(root,'dist');fs.mkdirSync(dist,{recursive:true});
fs.writeFileSync(path.join(dist,'index.html'),sharedVersionUI(html,sha));
fs.writeFileSync(path.join(dist,'latest.html'),sharedVersionUI(html,sha));
const terrain=fs.readFileSync(path.join(root,'src','terrain.html'),'utf8');
if(!terrain.includes('TERRAIN STUDIO')||!terrain.includes('osman-terrain-v1'))throw new Error('Terrain Studio contract missing');
fs.writeFileSync(path.join(dist,'terrain.html'),sharedVersionUI(terrain,sha));
const animation=fs.readFileSync(path.join(root,'src','animation.html'),'utf8');
if(!animation.includes('ANIMATION STUDIO')||!animation.includes('OsmanAnimationStudioFramesV1'))throw new Error('Animation Studio contract missing');
fs.writeFileSync(path.join(dist,'animation.html'),sharedVersionUI(animation.replaceAll('__ANIMATION_BUILD_SHA__',sha),sha));
const comparison=fs.readFileSync(path.join(root,'src','animation-compare.html'),'utf8');
if(!comparison.includes('VARYANT KARŞILAŞTIRMA'))throw new Error('Animation comparison page missing');
fs.writeFileSync(path.join(dist,'animation-compare.html'),sharedVersionUI(comparison.replaceAll('__ANIMATION_BUILD_SHA__',sha),sha));
fs.writeFileSync(path.join(dist,'build.json'),JSON.stringify({sha,kind:'object-studio',entry:'latest.html',content_sha256:crypto.createHash('sha256').update(html).digest('hex'),source_modules:moduleNames},null,2));
console.log('Bundled '+modules.length+' ES modules into stand-alone HTML ('+Buffer.byteLength(html)+' bytes) SHA '+sha);
