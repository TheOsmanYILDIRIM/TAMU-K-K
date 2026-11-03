import {createRequire} from 'node:module';
import {deflateSync} from 'node:zlib';
import {readFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const require=createRequire(new URL('../../world-builder/package.json',import.meta.url));
const {chromium}=require('playwright');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const shotDir=path.join(root,'screenshots');mkdirSync(shotDir,{recursive:true});
const crcTable=new Uint32Array(256);for(let i=0;i<256;i++){let v=i;for(let j=0;j<8;j++)v=(v>>>1)^((v&1)?0xedb88320:0);crcTable[i]=v>>>0}
function crc(b){let v=0xffffffff;for(const c of b)v=(v>>>8)^crcTable[(v^c)&255];return(v^0xffffffff)>>>0}
function chunk(type,payload){const tag=Buffer.from(type),head=Buffer.alloc(8),tail=Buffer.alloc(4);head.writeUInt32BE(payload.length,0);tag.copy(head,4);tail.writeUInt32BE(crc(Buffer.concat([tag,payload])),0);return Buffer.concat([head,payload,tail])}
function png({shift=0,variant=false}={}){
 const w=128,h=128,header=Buffer.alloc(13);header.writeUInt32BE(w,0);header.writeUInt32BE(h,4);header[8]=8;header[9]=6;
 const rows=Buffer.alloc(h*(1+w*4));for(let y=0;y<h;y++)for(let x=0;x<w;x++){
   const k=y*(1+w*4)+1+x*4,body=variant||(x>=40+shift&&x<86+shift&&y>=18&&y<113);
   rows[k]=variant?16:60;rows[k+1]=variant?240:183;rows[k+2]=variant?40:196;rows[k+3]=body?255:0;
 }
 return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(rows)),chunk('IEND',Buffer.alloc(0))]);
}
async function pngPixelCheck(page,bytes){
 return page.evaluate(async b64=>{
   const bytes=Uint8Array.from(atob(b64),c=>c.charCodeAt(0));
   const bmp=await createImageBitmap(new Blob([bytes],{type:'image/png'}));
   const cv=document.createElement('canvas');cv.width=bmp.width;cv.height=bmp.height;
   const g=cv.getContext('2d',{willReadFrequently:true});g.drawImage(bmp,0,0);
   const a=g.getImageData(0,0,1,1).data,inside=g.getImageData(62,63,1,1).data;
   bmp.close();return {width:cv.width,height:cv.height,outer:[...a],inside:[...inside]};
 },bytes.toString('base64'));
}
const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{
 for(const [width,height] of [[360,780],[411,890]]){
   const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:2,isMobile:true,hasTouch:true,acceptDownloads:true});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push('PAGE '+e.message));
   page.on('console',m=>{if(m.type()==='error')errors.push('CONSOLE '+m.text())});
   await page.goto('http://127.0.0.1:8876/object-studio/dist/animation.html',{waitUntil:'networkidle'});
   assert.equal(await page.getByRole('button',{name:'Orijinal',exact:true}).count(),1);
   assert.equal(await page.getByRole('button',{name:'AI Varyantı',exact:true}).count(),1);
   assert.equal(await page.getByRole('button',{name:'Karşılaştır',exact:true}).count(),1);
   await page.locator('#sourceInput').setInputFiles([
     {name:'SE_01.png',mimeType:'image/png',buffer:png()},
     {name:'SE_02.png',mimeType:'image/png',buffer:png({shift:6})}
   ]);
   await page.waitForFunction(()=>document.querySelector('#frameMeta')?.textContent.includes('01 / 2'),null,{timeout:12000});
   await page.waitForFunction(()=>document.querySelector('#strip')?.querySelectorAll('.framechip').length===2);
   const colored=await page.evaluate(()=>{const d=document.querySelector('#stage').getContext('2d').getImageData(0,0,720,720).data;let n=0;for(let k=0;k<d.length;k+=4)if(d[k+1]>110&&d[k+2]>110&&d[k]<110)n++;return n});
   assert.ok(colored>3000,'PREVIEW_EMPTY '+colored);
   const maskPromise=page.waitForEvent('download');await page.locator('#exportMask').click();const mask=await maskPromise;
   assert.match(mask.suggestedFilename(),/SE_01_AI_EDIT_MASK.png$/);
   const test=await pngPixelCheck(page,readFileSync(await mask.path()));
   assert.deepEqual([test.width,test.height],[128,128]);
   assert.equal(test.outer[3],255,'Background must be opaque/protected for GPT Image API');
   assert.equal(test.inside[3],0,'Character must be transparent/editable in API mask');
   await page.locator('#variantInput').setInputFiles({name:'generated.png',mimeType:'image/png',buffer:png({variant:true})});
   await page.waitForFunction(()=>document.querySelector('#frameState')?.textContent.includes('AI varyantı var'),null,{timeout:12000});
   const variantPromise=page.waitForEvent('download');await page.locator('#exportVariant').click();const variant=await variantPromise;
   const cmp=await pngPixelCheck(page,readFileSync(await variant.path()));
   assert.equal(cmp.outer[3],255,'Independent AI RGBA must not be forcibly clipped to original silhouette');
   assert.equal(cmp.inside[3],255,'Variant must fill existing original shape');
   assert.equal(cmp.inside[1],240,'AI RGB transfer was not preserved');
   await page.getByRole('button',{name:'Karşılaştır',exact:true}).click();
   await page.screenshot({path:path.join(shotDir,'animation-scene-'+width+'x'+height+'.png'),fullPage:true});
   await page.reload({waitUntil:'networkidle'});
   await page.waitForFunction(()=>document.querySelector('#frameMeta')?.textContent.includes('01 / 2'),null,{timeout:12000});
   assert.match(await page.locator('#frameState').innerText(),/AI varyantı var/,'IndexedDB variant persist');
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+2),true,'mobile horizontal overflow');
   assert.deepEqual(errors,[],errors.join('\n'));
   await context.close();
 }
 console.log('ANIMATION_SCENE_MOBILE_OK: two viewports, original nonblank, inverse alpha mask, variant clipping, reload persists, compare');
}finally{await browser.close()}
