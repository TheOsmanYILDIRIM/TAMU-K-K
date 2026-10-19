import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';
import {spawnSync} from 'node:child_process';
import {BUNDLE_FORMAT,clone,validateBundle,modify,moveSharedVertex,location,parseBundle} from '../r2-core.mjs';
const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const data=p=>JSON.parse(readFileSync(resolve(ROOT,'data/worldbuild',p),'utf8'));
const source={format:BUNDLE_FORMAT,schema_version:1,manifest:data('osman_overworld.v2.json'),authored:data('fisilti_ormani.r2.v1.json')};
const PY=[
 'import json,sys',
 "sys.path.insert(0,'scripts')",
 'from validate_worldbuild_map_v2 import validate_map',
 'b=json.load(sys.stdin)',
 "validate_map(b['manifest'],overrides={'data/worldbuild/fisilti_ormani.r2.v1.json': b['authored']})",
 "print('OK')"
].join('\n');
function pythonOk(d){const r=spawnSync('python3',['-c',PY],{input:JSON.stringify(d),cwd:ROOT,encoding:'utf8'});if(r.error)throw r.error;return r.status===0}
function jsOk(d){try{validateBundle(d);return true}catch{return false}}
test('source R2 A manifest and v1 nested authored pass independent JS and Python',()=>{assert.equal(jsOk(source),true);assert.equal(pythonOk(source),true)});
test('no implicit version/format migration',()=>{for(const mutate of [
 d=>d.authored.format='osman-worldbuild-v2',
 d=>d.manifest.generator_version=2,
 d=>d.manifest.seed++,
 d=>d.manifest.generation.fallback='generator-v2',
 d=>d.manifest.bounds.enforcement='runtime',
 d=>d.authored.regions[0].id='region:renamed',
 d=>d.manifest.routes[0].sites.reverse(),
 d=>d.manifest.sites[0].anchor=[999,999],
 d=>d.manifest.sites.push(clone(d.manifest.sites[0])),
 d=>d.authored.features[0].points[0]=[9999,9999],
 d=>d.authored.regions[0].polygon.reverse(),
 d=>d.authored.connectors[0].anchor=[8000,8000],
 d=>d.authored.regions[0].variant='nonexistent',
 d=>d.authored.intruder=true,
 d=>d.manifest.authored_maps[0].path='../../secrets.json',
 d=>d.manifest.areas[0].polygon=[[1,1],[2,1],[2,2],[1,2]]
 ]){const d=clone(source);mutate(d);const j=jsOk(d),p=pythonOk(d);assert.equal(j,p,'JS/Python disagreement '+JSON.stringify(d.manifest.bounds));assert.equal(j,false,'expected fail closed')}
});
test('bundle envelope is never silently rewritten',()=>{for(const mutate of [d=>d.format='osman-worldmap-v2',d=>d.schema_version=2]){const x=clone(source);mutate(x);assert.equal(jsOk(x),false)}});
test('valid nonbreaking edits and independent Python parity',()=>{const d=modify(source,b=>b.authored.regions[0].name='Yeni Giriş');assert.equal(d.authored.regions[0].name,'Yeni Giriş');assert.equal(source.authored.regions[0].name,'Giriş Çayırı');assert.ok(pythonOk(d))});
test('shared vertex edit preserves ID and refuses malformed portal',()=>{const d=source;const sourcePoint=d.authored.regions[0].polygon.find(x=>x[0]===256&&x[1]===110);assert.ok(sourcePoint);assert.throws(()=>moveSharedVertex(d,'region:fisilti-giris',d.authored.regions[0].polygon.indexOf(sourcePoint),[5000,5000]));assert.deepEqual(source.authored.regions[0].polygon.find(x=>x[0]===256&&x[1]===110),[256,110])});
test('import rejects malformed, never upgrades legacy scene silently',()=>{assert.deepEqual(parseBundle(JSON.stringify(source)),source);for(const bad of ['{bad','{"version":2,"modules":[],"paths":[],"objects":[]}',JSON.stringify({...source,manifest:{...source.manifest,seed:-1}})])assert.throws(()=>parseBundle(bad))});
test('boundary tie and authored fallback remain deterministic',()=>{const r=source.authored.regions;const p=[256,128];const hits=r.filter(q=>location(q.polygon,p)>=0).map(x=>x.id).sort();assert.deepEqual(hits,['region:fisilti-giris','region:fisilti-koruluk']);assert.equal(r.some(q=>location(q.polygon,[4000,4000])>=0),false)});
test('save and runtime directories are not accessed by model',()=>{assert.ok(!Object.keys(source.manifest).some(x=>x==='save'));assert.equal(source.manifest.generation.map_activation,'opt_in_future_adapter')});
