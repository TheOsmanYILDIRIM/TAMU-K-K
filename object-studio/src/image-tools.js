// Non-destructive black-matte removal: only border-connected dark pixels.
export function removeBorderBlack(imageData,tolerance=28){
 const {width:w,height:h,data:d}=imageData;
 const out=new Uint8ClampedArray(d),seen=new Uint8Array(w*h),stack=[];
 const lim=Math.max(0,Math.min(90,Number(tolerance)||0));
 const candidate=i=>d[4*i+3]>0 && Math.max(d[4*i],d[4*i+1],d[4*i+2])<=lim;
 function queue(i){if(!seen[i]&&candidate(i)){seen[i]=1;stack.push(i)}}
 for(let x=0;x<w;x++){queue(x);queue((h-1)*w+x)}
 for(let y=0;y<h;y++){queue(y*w);queue(y*w+w-1)}
 let removed=0;
 while(stack.length){
  const i=stack.pop(),x=i%w,y=Math.floor(i/w);
  out[4*i+3]=0;removed++;
  if(x>0)queue(i-1);if(x<w-1)queue(i+1);
  if(y>0)queue(i-w);if(y<h-1)queue(i+w);
 }
 return {data:out,width:w,height:h,removed};
}
export function materialPixels(albedo,normal,height,options={}){
 const width=albedo.width,h=albedo.height,src=albedo.data;
 const output=new Uint8ClampedArray(src);
 const angle=(Number(options.lightAngle)||0)*Math.PI/180;
 const lx=Math.cos(angle)*.65,ly=Math.sin(angle)*.65,lz=Math.sqrt(1-.65**2);
 const normalStrength=Math.max(0,Math.min(2,Number(options.normalStrength)||0));
 const heightStrength=Math.max(0,Math.min(3,Number(options.heightStrength)||0));
 const intensity=Math.max(0,Math.min(1,Number(options.intensity)||0));
 if(intensity===0||(!normal||normalStrength===0)&&(!height||heightStrength===0))return {data:output,width,height:h};
 const sample=(x,y)=>{x=Math.max(0,Math.min(width-1,x));y=Math.max(0,Math.min(h-1,y));const i=4*(y*width+x);return height?(height.data[i]+height.data[i+1]+height.data[i+2])/765:0};
 const pixel=(x,y)=>{const i=4*(y*width+x);if(src[i+3]===0)return;
  let nx=0,ny=0,nz=1;
  if(normal){nx=(normal.data[i]/255*2-1)*normalStrength;ny=(normal.data[i+1]/255*2-1)*normalStrength;nz=normal.data[i+2]/255*2-1}
  if(height&&heightStrength){nx-=(sample(x+1,y)-sample(x-1,y))*heightStrength;ny-=(sample(x,y+1)-sample(x,y-1))*heightStrength}
  const inv=1/(Math.hypot(nx,ny,nz)||1),diff=Math.max(0,(nx*lx+ny*ly+nz*lz)*inv);
  const bright=(1-intensity)+intensity*(.38+.88*diff);
  for(let k=0;k<3;k++)output[i+k]=Math.min(255,Math.max(0,src[i+k]*bright));
 };
 for(let y=0;y<h;y++)for(let x=0;x<width;x++)pixel(x,y);
 return {data:output,width,height:h};
}
