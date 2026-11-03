import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..');
test('self-contained build is stamped and has no external runtime scripts',()=>{
 const sha='0123456789abcdef0123456789abcdef01234567';
 const p=spawnSync(process.execPath,['scripts/build.mjs'],{cwd:root,env:{...process.env,BUILD_SHA:sha},encoding:'utf8'});
 assert.equal(p.status,0,p.stderr);
 const html=fs.readFileSync(path.join(root,'dist/index.html'),'utf8');
 assert(html.length>32000);
 assert(html.includes(sha));
 assert(!html.includes('__BUILD_SHA__'));
 assert(!/<script[^>]*src=/i.test(html));
 assert(!/<link[^>]*href=["'].*\.css/i.test(html));
 assert.equal((html.match(/<script>/g)||[]).length,2);
 for(const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g)){
  const check=spawnSync(process.execPath,['--check','--input-type=commonjs'],{input:match[1],encoding:'utf8'});
  assert.equal(check.status,0,check.stderr);
 }
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'dist/build.json'),'utf8'));
 assert.equal(manifest.sha,sha);assert.equal(manifest.source_modules.length,6);assert(manifest.source_modules.includes('image-tools.js'));
});
