import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
mkdirSync(resolve(root,'screenshots'),{recursive:true});
const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
try{
 for(const [width,height] of [[320,700],[360,780],[411,890]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:2,isMobile:true,hasTouch:true});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push('pageerror: '+e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push('console: '+m.text())});
  page.on('requestfailed',req=>errors.push('request: '+req.url()+' '+req.failure()?.errorText));
  await page.goto('http://127.0.0.1:8876/world-builder/r2.html',{waitUntil:'networkidle',timeout:45000});
  try{await page.waitForFunction(()=>document.querySelector('#stats')?.textContent.includes('6 bölge'),null,{timeout:12000})}
  catch(e){await page.screenshot({path:resolve(root,'screenshots','r2-failed-'+width+'.png'),fullPage:true});const summary=await page.evaluate(()=>({load:document.querySelector('#loadStatus')?.textContent,status:document.querySelector('#status')?.textContent,stats:document.querySelector('#stats')?.textContent,html:document.body?.innerText.slice(0,450)}));throw Error('MOBILE_INIT_FAILED '+JSON.stringify({summary,errors,cause:e.message}))}
  assert.match(await page.locator('#loadStatus').innerText(),/A teslimi|Yerel R2 taslağı/);
  assert.equal(await page.locator('[data-layer="sites"]').isChecked(),true);
  await page.locator('[data-layer="sites"]').uncheck();
  await page.locator('[data-layer="sites"]').check();
  await page.locator('#fitWorld').click();
  await page.locator('#fitAuthored').click();
  await page.locator('#zoomIn').click();
  await page.locator('#zoomOut').click();
  await page.screenshot({path:resolve(root,'screenshots','r2-loaded-'+width+'.png'),fullPage:true});
  await page.locator('#files').setInputFiles({name:'corrupt.json',mimeType:'application/json',buffer:Buffer.from('{"format":"osman-worldmap-v2","seed":-1}')});
  await page.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('İçe aktarma reddedildi'),null,{timeout:10000});
  assert.match(await page.locator('#status').innerText(),/İçe aktarma reddedildi/);
  assert.match(await page.locator('#stats').innerText(),/6 bölge/);
  await page.locator('#selection').selectOption('region:fisilti-giris');
  page.once('dialog',dialog=>dialog.accept('Giriş Çayırı Mobil Test'));
  await page.locator('#rename').click();
  await page.waitForFunction(()=>document.querySelector('#status')?.textContent.includes('kalıcı taslak doğrulandı'));
  await page.reload({waitUntil:'networkidle'});
  await page.waitForFunction(()=>document.querySelector('#selection')?.textContent.includes('Giriş Çayırı Mobil Test'));
  assert.ok(errors.length===0,'browser exceptions: '+errors.join(' | '));
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),true,'horizontal overflow');
  await page.screenshot({path:resolve(root,'screenshots','r2-mobile-'+width+'x'+height+'.png'),fullPage:true});
  await context.close();
 }
 console.log('R2_MOBILE_CHROMIUM_OK 320x700 360x780 411x890; import reject, layers, rename, IndexedDB reload');
}finally{await browser.close()}
