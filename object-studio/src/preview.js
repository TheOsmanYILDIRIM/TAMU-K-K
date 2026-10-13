// Canvas-only schematic/asset preview. No texture is substituted for missing art.
const TAU=Math.PI*2;
const silhouetteCache=new WeakMap();
export function drawPreview(canvas,options){
  const {asset,mode,biome,bitmaps,entry,showGuide=true,showShadow=true}=options;
  const ctx=canvas.getContext('2d',{alpha:false});const bounds=canvas.getBoundingClientRect(),size=Math.max(320,Math.min(1000,Math.round(bounds.width||600)));
  const dpr=Math.min(2,window.devicePixelRatio||1),pixel=Math.round(size*dpr);
  if(canvas.width!==pixel||canvas.height!==pixel){canvas.width=pixel;canvas.height=pixel;}
  ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,size,size);
  if(mode==='normal'||mode==='height'){
    ctx.fillStyle='#293730';ctx.fillRect(0,0,size,size);
    const img=bitmaps.get(mode);
    if(img)ctx.drawImage(img,size*.07,size*.07,size*.86,size*.86);
    else centerText(ctx,size,mode==='normal'?'Normal map yüklenmedi':'Height map yüklenmedi');
    label(ctx,size,mode==='normal'?'NORMAL / tangent-space':'HEIGHT / geometry source');return;
  }
  if(mode==='square'){
    checker(ctx,size);
    const side=size*.86,ox=(size-side)/2,oy=(size-side)/2;
    ctx.strokeStyle='#d8d2af55';ctx.setLineDash([6,8]);ctx.strokeRect(ox,oy,side,side);ctx.setLineDash([]);
    paintSprite(ctx,{asset,bitmaps,entry,anchorX:size*.5,anchorY:size*.83,width:side,schematicScale:size*.52});
    if(showGuide){const pivotX=ox+side*entry.pivotX,pivotY=oy+side*entry.pivotY;
      ctx.strokeStyle='#e9b976b9';ctx.lineWidth=1.4;ctx.beginPath();ctx.moveTo(pivotX-11,pivotY);ctx.lineTo(pivotX+11,pivotY);ctx.moveTo(pivotX,pivotY-11);ctx.lineTo(pivotX,pivotY+11);ctx.stroke();}
    label(ctx,size,'1:1 • RGBA / 1024×1024 hedef');return;
  }
  const bg=ctx.createLinearGradient(0,0,0,size);bg.addColorStop(0,'#23392f');bg.addColorStop(1,'#182720');ctx.fillStyle=bg;ctx.fillRect(0,0,size,size);
  for(let i=0;i<22;i++){
    ctx.strokeStyle='#91af8a12';ctx.lineWidth=1;
    ctx.beginPath();ctx.moveTo(0,size*.19+i*size*.038);ctx.lineTo(size,size*.19+i*size*.038);ctx.stroke();
  }
  const cx=size*.5,cy=size*.715,gw=size*.42,gh=size*.205;
  ctx.fillStyle='#111d1a99';ctx.beginPath();ctx.ellipse(cx,cy+size*.084,gw*.96,gh*.74,0,0,TAU);ctx.fill();
  ctx.beginPath();ctx.moveTo(cx,cy-gh);ctx.lineTo(cx+gw,cy);ctx.lineTo(cx,cy+gh);ctx.lineTo(cx-gw,cy);ctx.closePath();
  const tones={meadow:['#879b78','#637f62'],forest:['#5d8064','#3d654e'],rocky:['#879287','#64786c']};
  const colors=tones[biome]||tones.meadow,grad=ctx.createLinearGradient(cx,cy-gh,cx,cy+gh);grad.addColorStop(0,colors[0]);grad.addColorStop(1,colors[1]);ctx.fillStyle=grad;ctx.fill();ctx.lineWidth=2;ctx.strokeStyle='#c2d3ac55';ctx.stroke();
  if(showGuide){ctx.strokeStyle='#d2debb20';ctx.lineWidth=1;
    for(let i=-3;i<=3;i++){ctx.beginPath();ctx.moveTo(cx+i*gw/4,cy-gh+Math.abs(i)*gh/4);ctx.lineTo(cx+i*gw/4,cy+gh-Math.abs(i)*gh/4);ctx.stroke();}}
  if(showShadow)paintProjectedShadow(ctx,{bitmaps,entry,asset,anchorX:cx,anchorY:cy,width:size*.59*entry.scale,size});
  paintSprite(ctx,{asset,bitmaps,entry,anchorX:cx,anchorY:cy,width:size*.59*entry.scale,schematicScale:size*.54*entry.scale});
  ctx.fillStyle='#cdd9bc88';ctx.beginPath();ctx.arc(cx,cy,2.8,0,TAU);ctx.fill();
  label(ctx,size,'45° izometrik / şematik zemin');
}
function checker(ctx,size){const s=size/16;ctx.fillStyle='#45574a';ctx.fillRect(0,0,size,size);for(let y=0;y<16;y++)for(let x=0;x<16;x++){if((x+y)%2===0){ctx.fillStyle='#576a58';ctx.fillRect(x*s,y*s,s,s)}}}
function paintSprite(ctx,{asset,bitmaps,entry,anchorX,anchorY,width,schematicScale}){
  const single=bitmaps.get('corrected')||bitmaps.get('creative');
  if(single){blit(ctx,single,anchorX,anchorY,width,entry);return;}
  schematic(ctx,asset,anchorX,anchorY,schematicScale);
}
// Project the real sprite alpha silhouette onto the 45° isometric floor.
// No synthetic ellipse, baked shadow PNG or extra source-art stage.
function getSilhouetteMask(image){
  if(silhouetteCache.has(image))return silhouetteCache.get(image);
  const side=256,buffer=document.createElement('canvas');buffer.width=side;buffer.height=side;
  const ink=buffer.getContext('2d');if(!ink)return null;
  ink.clearRect(0,0,side,side);
  ink.drawImage(image,0,0,side,side);
  ink.globalCompositeOperation='source-in';
  ink.fillStyle='#101913';ink.fillRect(0,0,side,side);
  ink.globalCompositeOperation='source-over';
  silhouetteCache.set(image,buffer);
  return buffer;
}
function paintProjectedShadow(ctx,{bitmaps,entry,asset,anchorX,anchorY,width,size}){
  const image=bitmaps.get('corrected')||bitmaps.get('creative');
  if(!image)return; // schematic outlines must not masquerade as real silhouette data
  const mask=getSilhouetteMask(image);if(!mask)return;
  const height=width*image.height/image.width;
  const tree=asset.family==='tree';
  // Taller trees cast longer directional ground projections; low rocks remain compact.
  const shear=tree?-.44:-.18,flatten=tree?-.19:-.11,across=tree?.54:.68;
  ctx.save();
  ctx.globalAlpha=Math.max(.08,Math.min(.65,entry.shadow));
  ctx.filter='blur('+Math.max(2,Math.round(size*.012))+'px)';
  ctx.translate(anchorX+size*.016,anchorY+size*.013);
  ctx.transform(across,.10,shear,flatten,0,0);
  ctx.drawImage(mask,-width*entry.pivotX,-height*entry.pivotY,width,height);
  ctx.restore();
}
function blit(ctx,image,ax,ay,width,entry){const height=width*image.height/image.width;ctx.drawImage(image,ax-width*entry.pivotX,ay-height*entry.pivotY,width,height);}
function schematic(ctx,asset,x,y,scale){
  ctx.save();ctx.translate(x,y);ctx.scale(scale/250,scale/250);ctx.lineWidth=2.8;ctx.setLineDash([7,5]);ctx.strokeStyle='#cadab2be';ctx.fillStyle='#6b806b38';
  if(asset.family==='tree'){
    ctx.beginPath();ctx.moveTo(-11,0);ctx.lineTo(-12,-109);ctx.quadraticCurveTo(-24,-148,-25,-165);ctx.moveTo(7,0);ctx.lineTo(11,-113);ctx.quadraticCurveTo(26,-146,38,-156);ctx.stroke();
    for(const [cx,cy,rx,ry] of [[-45,-171,58,54],[26,-176,62,57],[-4,-212,61,62]]){
      ctx.beginPath();ctx.ellipse(cx,cy,rx,ry,-.12,0,TAU);ctx.fill();ctx.stroke();
    }
  }else{
    ctx.beginPath();ctx.moveTo(-102,-4);ctx.lineTo(-85,-88);ctx.lineTo(-32,-121);ctx.lineTo(66,-102);ctx.lineTo(106,-29);ctx.lineTo(85,0);ctx.closePath();ctx.fill();ctx.stroke();
    ctx.beginPath();ctx.moveTo(-85,-88);ctx.lineTo(3,-42);ctx.lineTo(66,-102);ctx.moveTo(3,-42);ctx.lineTo(15,-3);ctx.stroke();
  }
  ctx.restore();ctx.fillStyle='#e4eecb';ctx.font='600 12px system-ui';ctx.textAlign='center';ctx.fillText('ŞEMATİK • PNG HENÜZ YOK',x,y+27);
}
function label(ctx,size,text){ctx.fillStyle='#e7eee4a8';ctx.textAlign='left';ctx.font='500 12px system-ui';ctx.fillText(text,17,size-20);}
function centerText(ctx,size,text){ctx.fillStyle='#c3d0bd';ctx.textAlign='center';ctx.font='500 16px system-ui';ctx.fillText(text,size*.5,size*.5);}
