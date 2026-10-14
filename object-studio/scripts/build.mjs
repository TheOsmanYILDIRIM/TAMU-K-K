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
const dist=path.join(root,'dist');fs.mkdirSync(dist,{recursive:true});
fs.writeFileSync(path.join(dist,'index.html'),html);
fs.writeFileSync(path.join(dist,'latest.html'),html);
const terrain=fs.readFileSync(path.join(root,'src','terrain.html'),'utf8');
if(!terrain.includes('TERRAIN STUDIO')||!terrain.includes('osman-terrain-v1'))throw new Error('Terrain Studio contract missing');
fs.writeFileSync(path.join(dist,'terrain.html'),terrain);
const animation=fs.readFileSync(path.join(root,'src','animation.html'),'utf8');
if(!animation.includes('ANIMATION STUDIO')||!animation.includes('OsmanAnimationStudioFramesV1'))throw new Error('Animation Studio contract missing');
fs.writeFileSync(path.join(dist,'animation.html'),animation);
const comparison=fs.readFileSync(path.join(root,'src','animation-compare.html'),'utf8');
if(!comparison.includes('VARYANT KARŞILAŞTIRMA'))throw new Error('Animation comparison page missing');
fs.writeFileSync(path.join(dist,'animation-compare.html'),comparison);
fs.writeFileSync(path.join(dist,'build.json'),JSON.stringify({sha,kind:'object-studio',entry:'latest.html',content_sha256:crypto.createHash('sha256').update(html).digest('hex'),source_modules:moduleNames},null,2));
console.log('Bundled '+modules.length+' ES modules into stand-alone HTML ('+Buffer.byteLength(html)+' bytes) SHA '+sha);
