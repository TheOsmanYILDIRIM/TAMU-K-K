import {CATALOG,BIOMES,STAGES,SLOTS,STYLE,assetById,stageSlots,variantKey} from './catalog.js';
import {promptFor,stageGuide} from './prompts.js';
import {readMetadata,writeMetadata,variantEntry,getImage,putImage,removeImage,listImages,inspectPng,readAsDataURL,blobFromDataURL,validateBackup,imageKey} from './storage.js';
import {drawPreview} from './preview.js';
const BUILD='__BUILD_SHA__';
const $=id=>document.getElementById(id);
const state=readMetadata();
let filterFamily='all',query='',images=new Map(),bitmaps=new Map(),imageURLs=[],busy=false,pendingSlot=null,toastTimer=null,selectionCycle=0;
if(!assetById(state.selected))state.selected='T-01';
if(!STAGES.some(s=>s.id===state.stage))state.stage='direction';
function toast(text,isError=false){const el=$('toast');el.textContent=text;el.style.background=isError?'#edd5bc':'#d1e3ac';el.classList.add('visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('visible'),4600);}
function persist(){try{writeMetadata(state)}catch(e){toast('Yerel ayarlar kaydedilemedi. Yedek al.',true)}}
function selectedAsset(){return assetById(state.selected)}
function variant(){const a=selectedAsset();const v=state.selection[a.id]||{};return {form:Math.max(0,Math.min(a.forms.length-1,Number(v.form)||0)),surface:Math.max(0,Math.min(a.surfaces.length-1,Number(v.surface)||0))};}
function entry(){const v=variant();return variantEntry(state,state.selected,v.form,v.surface)}
function imageKeyFor(slot){const v=variant();return imageKey(state.selected,v.form,v.surface,slot)}
function releaseImages(){for(const bm of bitmaps.values())try{bm.close()}catch{}bitmaps.clear();images.clear();for(const u of imageURLs)URL.revokeObjectURL(u);imageURLs=[];}
async function loadVariant(){const generation=++selectionCycle;releaseImages();const results=await Promise.all(SLOTS.map(async slot=>{
 try{return [slot.id,await getImage(imageKeyFor(slot.id))]}catch(e){return [slot.id,null]}
 }));if(generation!==selectionCycle)return;
 for(const [slot,record] of results){if(!record)continue;images.set(slot,record);try{bitmaps.set(slot,await createImageBitmap(record.blob))}catch{toast(slot+' görseli okunamadı.',true)}}
 if(generation!==selectionCycle)return;renderSlots();updatePreview();renderCatalog();updateStageButton();}
function setVariant(kind,value){const a=selectedAsset();const v=variant();v[kind]=value;state.selection[a.id]=v;persist();renderAll();loadVariant();}
function changedAsset(id){if(state.selected===id)return;state.selected=id;state.stage='direction';persist();renderAll();loadVariant();}
function completedCount(a){const v=state.selection[a.id]||{},e=state.work[variantKey(a.id,Number(v.form)||0,Number(v.surface)||0)];return STAGES.filter(s=>e?.stages?.[s.id]).length;}
function renderCatalog(){const box=$('catalogList');const src=CATALOG.filter(a=>(filterFamily==='all'||a.family===filterFamily)&&[a.name,a.id,a.species].join(' ').toLocaleLowerCase('tr').includes(query));
 box.innerHTML=src.map(a=>{const progress=completedCount(a);return `<button class="assetCard ${a.id===state.selected?'active':''}" data-asset="${a.id}" aria-pressed="${a.id===state.selected}"><span class="assetSymbol" style="--symbol-bg:${a.color}55">${a.symbol}</span><span class="assetInfo"><strong>${a.id} · ${a.name}</strong><small>${a.family==='tree'?'Ağaç':'Kaya'} / ${a.forms.length} biçim × ${a.surfaces.length} yüzey</small><span class="progressBar"><i style="width:${Math.round(progress/STAGES.length*100)}%"></i></span></span></button>`}).join('')||'<p class="footerHint">Eşleşen obje yok.</p>';
 const complete=CATALOG.filter(a=>completedCount(a)===STAGES.length).length;$('totalProgress').textContent=complete+' / 7 onay';}
function renderSelects(){const a=selectedAsset(),v=variant();$('biome').innerHTML=BIOMES.map(b=>`<option value="${b.id}">${b.name}${a.roles.includes(b.id)?'':' · seyrek'}</option>`).join('');$('biome').value=state.biome;
 $('formVariant').innerHTML=a.forms.map((f,i)=>`<option value="${i}">${f}</option>`).join('');$('formVariant').value=v.form;
 $('surfaceVariant').innerHTML=a.surfaces.map((f,i)=>`<option value="${i}">${f}</option>`).join('');$('surfaceVariant').value=v.surface;}
function renderStage(){const a=selectedAsset(),v=variant(),e=entry(),st=STAGES.find(x=>x.id===state.stage);
 $('stageCount').textContent=completedCount(a)+' / '+STAGES.length;
 $('stageRail').innerHTML=STAGES.map(s=>`<button data-stage="${s.id}" class="${s.id===state.stage?'active':''} ${e.stages?.[s.id]?'done':''}" aria-pressed="${s.id===state.stage}"><span class="stageNo">${s.number}${e.stages?.[s.id]?' ✓':''}</span>${s.name}</button>`).join('');
 $('stageLabel').textContent='AŞAMA '+st.number;
 $('stageTitle').textContent=st.name;
 $('stageDescription').textContent=st.description;
 const prompt=promptFor(a,state.stage,v.form,v.surface,state.biome),guide=stageGuide(state.stage,a);
 $('promptLabel').textContent=prompt?'Özgün üretim promptu':'Üretim / kabul notları';
 $('promptText').value=prompt||guide||'';
 $('copyPrompt').disabled=!(prompt||guide);
 $('directorNote').value=e.notes?.[state.stage]||'';
 updateStageButton();renderSlots();}
function updateStageButton(){const e=entry(),done=!!e.stages?.[state.stage];const btn=$('approveStage');btn.classList.toggle('done',done);btn.textContent=done?'✓ Onaylandı · geri al':'✓ Bu aşamayı onayla';$('statusTag').textContent=e.stages?.approval?'Oyun kabulü':e.stages?.correction?'Düzeltilmiş':'Taslak';}
function updateContract(){const a=selectedAsset(),v=variant(),e=entry();$('previewTitle').textContent=a.name;
 $('contract').textContent=`${a.id} · ${a.species}\nBiçim: ${a.forms[v.form]}  ·  Yüzey: ${a.surfaces[v.surface]}\nBiyom: ${BIOMES.find(b=>b.id===state.biome)?.name||'—'}  ·  Engel: ${a.collider}\nBoy: ${a.height} ölçek birimi  ·  Ayak izi: ${a.footprint[0]} × ${a.footprint[1]}\n${a.placement}`;
 for(const id of ['scale','pivotX','pivotY','shadow']){$(id).value=e[id];}
 $('scaleOut').textContent=Math.round(e.scale*100)+'%';$('pivotXOut').textContent=Math.round(e.pivotX*100)+'%';$('pivotYOut').textContent=Math.round(e.pivotY*100)+'%';$('shadowOut').textContent=Math.round(e.shadow*100)+'%';}
function renderSlots(){const slots=stageSlots(state.stage),box=$('slotGrid');if(!slots.length){box.innerHTML='<div class="slotEmpty">Bu aşamada resim yükleme yok. Yönergeyi değerlendirip elle onaylayabilirsin.</div>';return;}
 for(const u of imageURLs)URL.revokeObjectURL(u);imageURLs=[];
 box.innerHTML=slots.map(slot=>{const record=images.get(slot.id),meta=record?.meta;let thumb=record?URL.createObjectURL(record.blob):null;if(thumb)imageURLs.push(thumb);
 return `<div class="slotCard"><div class="slotThumb">${thumb?`<img src="${thumb}" alt="${slot.name} görseli" loading="lazy">`:'<span>PNG YOK</span>'}</div><div class="slotMeta"><strong>${slot.name}</strong><small>${meta?`${meta.width}×${meta.height} · ${Math.round(meta.bytes/1024)} KB`:slot.description}</small><div class="slotButtons"><button data-upload="${slot.id}">${record?'Değiştir':'PNG yükle'}</button>${record?`<button class="remove" data-remove="${slot.id}" aria-label="${slot.name} kaldır">×</button>`:''}</div></div></div>`}).join('');}
function updatePreview(){const e=entry();$('previewChip').textContent=images.size?`${images.size} görsel / ${state.preview==='world'?'oyun':'kontrol'}`:'Şematik · doku yok';
 drawPreview($('previewCanvas'),{asset:selectedAsset(),mode:state.preview,biome:state.biome,bitmaps,entry:e,showGuide:state.viewGuide,showShadow:state.viewShadow});}
function renderAll(){renderCatalog();renderSelects();renderStage();updateContract();document.querySelectorAll('[data-preview]').forEach(b=>b.classList.toggle('active',b.dataset.preview===state.preview));$('viewGuide').checked=state.viewGuide;$('viewShadow').checked=state.viewShadow;updatePreview();}
async function onUpload(slot){const spec=SLOTS.find(s=>s.id===slot);if(!spec)return;pendingSlot=spec;$('assetFile').value='';$('assetFile').click();}
async function processUpload(file){if(!pendingSlot||!file)return;const spec=pendingSlot;pendingSlot=null;try{
 const meta=await inspectPng(file,{alphaRequired:spec.alpha});
 if(meta.width!==1024)toast(`Kare PNG kabul edildi (${meta.width}). Üretim standardımız 1024×1024.`);
 if(['base','body','upper','front'].includes(spec.id)){
   const other=['base','body','upper','front','corrected'].map(x=>images.get(x)?.meta).filter(Boolean)[0];
   if(other&&other.width!==meta.width)throw new Error('Katmanlar aynı çözünürlükte olmalı: '+other.width+'.');
 }
 if(images.has(spec.id)&&!confirm(spec.name+' görseli bu varyantta değiştirilecek. Önce yedek almak ister misin?'))return;
 const key=imageKeyFor(spec.id);await putImage(key,file,meta);await loadVariant();toast(spec.name+' kaydedildi · '+meta.width+'×'+meta.height);
 }catch(e){toast('PNG yüklenemedi: '+e.message,true)}}
async function onRemove(slot){const spec=SLOTS.find(s=>s.id===slot);if(!spec)return;if(!confirm(spec.name+' yalnız seçili varyanttan silinsin mi?'))return;
 try{await removeImage(imageKeyFor(slot));await loadVariant();toast('Görsel kaldırıldı. Diğer varyantlar korundu.')}catch(e){toast(e.message,true)}}
function canComplete(stage){if(stage==='direction')return true;
 const record=images.has.bind(images);
 if(stage==='reference')return record('reference');
 if(stage==='creative')return record('creative');
 if(stage==='correction')return record('corrected');
 if(stage==='maps')return record('normal')||record('height');
 if(stage==='approval')return record('corrected');
 return false;}
function approve(){const e=entry();e.stages||={};if(e.stages[state.stage]){delete e.stages[state.stage];toast('Onay geri alındı.');}
 else{if(!canComplete(state.stage)){toast('Bu aşamayı onaylamak için ilgili PNG gerekli. Eksik görüntü yerine sahte kabul yapmıyoruz.',true);return;}e.stages[state.stage]={at:new Date().toISOString(),manuallyApproved:true};toast('Aşama elle onaylandı.');}
 persist();renderCatalog();renderStage();}
function saveFile(filename,blob){const a=document.createElement('a'),url=URL.createObjectURL(blob);a.href=url;a.download=filename;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1500)}
async function exportBackup(){if(busy)return;busy=true;$('exportBackup').disabled=true;try{
 const records=await listImages();const images=[];
 for(const item of records){images.push({key:item.key,meta:item.meta,data:await readAsDataURL(item.blob)});}
 const payload={format:'osman-object-studio-backup-v1',exportedAt:new Date().toISOString(),metadata:{schema:1,selected:state.selected,biome:state.biome,stage:state.stage,preview:state.preview,viewGuide:state.viewGuide,viewShadow:state.viewShadow,selection:state.selection,work:state.work},images};
 saveFile('osman-object-studio-'+new Date().toISOString().slice(0,10)+'.json',new Blob([JSON.stringify(payload)],{type:'application/json'}));toast('Tam yedek oluşturuldu: '+records.length+' PNG + üretim kayıtları.');
 }catch(e){toast('Yedek başarısız: '+e.message,true)}finally{busy=false;$('exportBackup').disabled=false}}
async function importBackup(file){if(busy||!file)return;busy=true;try{
 if(file.size>120*1024*1024)throw new Error('Yedek 120 MB sınırını aşıyor.');
 const data=JSON.parse(await file.text());validateBackup(data);
 if(!confirm(`Yedekte ${data.images.length} PNG var. Mevcut çalışma korunarak birleştirilecek; çakışan varyantlar yedektekilerle değiştirilecek. Devam?`))return;
 for(const item of data.images){const blob=blobFromDataURL(item.data);const slot=item.key.split('::')[3],spec=SLOTS.find(x=>x.id===slot);const legacyLayer=['base','body','upper','front'].includes(slot);if(!spec&&!legacyLayer)throw new Error('Bilinmeyen slot: '+slot);const meta=await inspectPng(blob,{alphaRequired:spec?.alpha??true});await putImage(item.key,blob,{...meta,...item.meta});}
 Object.assign(state.work,data.metadata.work);Object.assign(state.selection,data.metadata.selection||{});persist();renderAll();await loadVariant();toast(data.images.length+' PNG ve üretim kayıtları birleştirildi.');
 }catch(e){toast('Yedek yüklenemedi: '+e.message,true)}finally{busy=false;$('backupFile').value=''}}
function wire(){
 $('catalogList').addEventListener('click',e=>{const card=e.target.closest('[data-asset]');if(card)changedAsset(card.dataset.asset)});
 $('search').addEventListener('input',e=>{query=e.target.value.toLocaleLowerCase('tr');renderCatalog()});
 $('familyFilter').addEventListener('click',e=>{const b=e.target.closest('[data-family]');if(!b)return;filterFamily=b.dataset.family;document.querySelectorAll('[data-family]').forEach(x=>x.classList.toggle('active',x===b));renderCatalog()});
 $('biome').onchange=e=>{state.biome=e.target.value;persist();renderStage();updateContract();updatePreview()};
 $('formVariant').onchange=e=>setVariant('form',+e.target.value);
 $('surfaceVariant').onchange=e=>setVariant('surface',+e.target.value);
 $('stageRail').addEventListener('click',e=>{const b=e.target.closest('[data-stage]');if(!b)return;state.stage=b.dataset.stage;persist();renderStage()});
 $('previewTabs').addEventListener('click',e=>{const b=e.target.closest('[data-preview]');if(!b)return;state.preview=b.dataset.preview;persist();renderAll()});
 $('viewGuide').onchange=e=>{state.viewGuide=e.target.checked;persist();updatePreview()};
 $('viewShadow').onchange=e=>{state.viewShadow=e.target.checked;persist();updatePreview()};
 for(const id of ['scale','pivotX','pivotY','shadow'])$(id).oninput=e=>{entry()[id]=Number(e.target.value);persist();updateContract();updatePreview()};
 $('slotGrid').addEventListener('click',e=>{const upload=e.target.closest('[data-upload]'),remove=e.target.closest('[data-remove]');if(upload)onUpload(upload.dataset.upload);if(remove)onRemove(remove.dataset.remove)});
 $('assetFile').onchange=e=>processUpload(e.target.files?.[0]);
 $('directorNote').oninput=e=>{const v=entry();v.notes||={};v.notes[state.stage]=e.target.value;persist()};
 $('copyPrompt').onclick=async()=>{try{await navigator.clipboard.writeText($('promptText').value);toast('Üretim promptu kopyalandı.')}catch{toast('Kopyalama izni yok. Metni elle seç.',true)}};
 $('approveStage').onclick=approve;
 $('exportBackup').onclick=exportBackup;
 $('importBackup').onclick=()=>$('backupFile').click();
 $('backupFile').onchange=e=>importBackup(e.target.files?.[0]);
 $('buildTag').textContent='build '+BUILD.slice(0,9);
 $('updateBtn').onclick=async()=>{try{const response=await fetch('./build.json?probe='+Date.now(),{cache:'no-store'});if(!response.ok)throw new Error('HTTP '+response.status);const data=await response.json();if(data.sha&&data.sha!==BUILD){if(confirm('Yeni sürüm mevcut. Kaydedilmiş görseller korunarak açılacak.'))location.href='./latest.html?build='+encodeURIComponent(data.sha)+'&_='+Date.now();}else toast('Güncel üretim: '+BUILD.slice(0,9));}catch(e){toast('Sürüm kontrolü başarısız: '+e.message,true)}};
 const observer=new ResizeObserver(()=>updatePreview());observer.observe($('previewCanvas'));
}
wire();renderAll();loadVariant().catch(e=>toast('Yerel görsel deposu açılamadı: '+e.message,true));
