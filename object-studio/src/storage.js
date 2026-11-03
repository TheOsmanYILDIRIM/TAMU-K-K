import {variantKey,slotKey,CATALOG} from './catalog.js';
const METADATA_KEY='osman:object-studio:v1:metadata';
const DB_NAME='OsmanObjectStudioAssets';
const STORE_NAME='png-assets';
const DEFAULTS=()=>({schema:1,selected:'T-01',biome:'forest',stage:'direction',preview:'world',viewGuide:true,viewShadow:true,selection:{},work:{}});
let dbPromise=null;
export function defaultEntry(){return {note:'',stages:{},scale:1,pivotX:.5,pivotY:.88,shadow:.48};}
export function readMetadata(){
  try{
    const parsed=JSON.parse(localStorage.getItem(METADATA_KEY));
    if(parsed?.schema===1&&parsed.work&&typeof parsed.work==='object'){
      const safe=DEFAULTS();
      return {...safe,...parsed,work:parsed.work,selection:parsed.selection||{}};
    }
  }catch{}
  return DEFAULTS();
}
export function writeMetadata(state){
  const meta={schema:1,selected:state.selected,biome:state.biome,stage:state.stage,preview:state.preview,viewGuide:state.viewGuide,viewShadow:state.viewShadow,selection:state.selection,work:state.work};
  localStorage.setItem(METADATA_KEY,JSON.stringify(meta));
}
export function variantEntry(state,assetId,formIndex,surfaceIndex){
  const key=variantKey(assetId,formIndex,surfaceIndex);
  if(!state.work[key])state.work[key]=defaultEntry();
  return state.work[key];
}
export async function openAssets(){
  if(!dbPromise){dbPromise=new Promise((resolve,reject)=>{
    if(!('indexedDB' in window)){reject(new Error('IndexedDB desteklenmiyor'));return;}
    const request=indexedDB.open(DB_NAME,1);
    request.onupgradeneeded=()=>{const d=request.result;if(!d.objectStoreNames.contains(STORE_NAME))d.createObjectStore(STORE_NAME,{keyPath:'key'});};
    request.onsuccess=()=>resolve(request.result);
    request.onerror=()=>reject(request.error||new Error('IndexedDB açılamadı'));
  }).catch(e=>{dbPromise=null;throw e});}
  return dbPromise;
}
async function transact(mode,callback){const db=await openAssets();return new Promise((resolve,reject)=>{
  const tx=db.transaction(STORE_NAME,mode),store=tx.objectStore(STORE_NAME);
  let result;try{result=callback(store)}catch(e){reject(e);tx.abort();return}
  tx.oncomplete=()=>resolve(result?.result??null);
  tx.onerror=()=>reject(tx.error||new Error('Depolama işlemi başarısız'));
  tx.onabort=()=>reject(tx.error||new Error('Depolama iptal edildi'));
});}
export async function putImage(key,blob,meta){return transact('readwrite',store=>store.put({key,blob,meta}));}
export async function removeImage(key){return transact('readwrite',store=>store.delete(key));}
export async function getImage(key){return transact('readonly',store=>store.get(key));}
export async function listImages(){return transact('readonly',store=>store.getAll());}
export function imageKey(asset,form,surface,slot){return slotKey(asset,form,surface,slot);}
export async function inspectPng(file,{alphaRequired=false}={}){
  if(!file||file.type!=='image/png')throw new Error('Yalnız PNG dosyaları kabul edilir.');
  if(file.size>18*1024*1024)throw new Error('PNG 18 MB sınırını aşıyor.');
  const bmp=await createImageBitmap(file);
  try{
    const w=bmp.width,h=bmp.height;
    if(w!==h)throw new Error('Kare format zorunlu: '+w+'×'+h+'.');
    if(w<256||w>4096)throw new Error('Kare kenarı 256–4096 piksel olmalı. Önerilen 1024.');
    const c=document.createElement('canvas');c.width=c.height=80;
    const cx=c.getContext('2d',{willReadFrequently:true});cx.clearRect(0,0,80,80);cx.drawImage(bmp,0,0,80,80);
    const data=cx.getImageData(0,0,80,80).data;let hasVisible=false,hasEmpty=false;
    for(let i=3;i<data.length;i+=4){if(data[i]>15)hasVisible=true;if(data[i]<245)hasEmpty=true;}
    if(!hasVisible)throw new Error('PNG tamamen boş/şeffaf.');
    if(alphaRequired&&!hasEmpty)throw new Error('Gerçek transparan alpha gerekli; düz arka plan kabul edilmez.');
    return {width:w,height:h,alpha:hasEmpty,bytes:file.size,name:file.name,uploadedAt:new Date().toISOString()};
  }finally{bmp.close()}
}
export function readAsDataURL(blob){return new Promise((resolve,reject)=>{
  const fr=new FileReader();fr.onload=()=>resolve(fr.result);fr.onerror=()=>reject(fr.error);fr.readAsDataURL(blob);
});}
export function blobFromDataURL(url){if(typeof url!=='string'||!/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(url))throw new Error('Geçersiz PNG yedeği');
  const raw=atob(url.slice(url.indexOf(',')+1)),arr=new Uint8Array(raw.length);for(let i=0;i<arr.length;i++)arr[i]=raw.charCodeAt(i);return new Blob([arr],{type:'image/png'});
}
export function validateBackup(data){
  if(data?.format!=='osman-object-studio-backup-v1'||data?.metadata?.schema!==1||!Array.isArray(data.images))throw new Error('Desteklenmeyen yedek biçimi');
  if(typeof data.metadata.work!=='object'||!data.metadata.work)throw new Error('Geçersiz çalışma bilgisi');
  if(data.images.length>400)throw new Error('Beklenmeyen görüntü sayısı');
  const allowed=new Set(CATALOG.map(a=>a.id));
  for(const image of data.images){const id=String(image.key||'').split('::')[0];if(!allowed.has(id)||!/^\w[\w-]*::\d+::\d+::[a-z]+$/.test(image.key))throw new Error('Beklenmeyen görsel anahtarı');if(typeof image.data!=='string')throw new Error('Eksik görsel');}
  return true;
}
