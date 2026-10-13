import test from 'node:test';
import assert from 'node:assert/strict';
import {removeBorderBlack,materialPixels} from '../src/image-tools.js';
test('border black removal keeps enclosed black object details and original bytes',()=>{
 const w=5,h=5,data=new Uint8ClampedArray(w*h*4);
 for(let i=0;i<w*h;i++){data[i*4+3]=255;}
 for(let y=1;y<4;y++)for(let x=1;x<4;x++){const i=(y*w+x)*4;data[i]=120;data[i+1]=80;data[i+2]=60}
 const original=data.slice(),result=removeBorderBlack({width:w,height:h,data},28);
 assert.equal(result.removed,16);
 assert.equal(result.data[3],0);
 assert.equal(result.data[(2*w+2)*4+3],255);
 assert.deepEqual(data,original);
});
test('normal and height lighting is opt-in and keeps original alpha',()=>{
 const src={width:2,height:2,data:new Uint8ClampedArray([90,110,120,255, 90,110,120,0, 90,110,120,255, 90,110,120,255])};
 const n={width:2,height:2,data:new Uint8ClampedArray([255,128,255,255,255,128,255,255,255,128,255,255,255,128,255,255])};
 const baseline=materialPixels(src,n,null,{lightAngle:90,intensity:0,normalStrength:1});
 assert.deepEqual(baseline.data,src.data);
 const lit=materialPixels(src,n,null,{lightAngle:0,intensity:1,normalStrength:1});
 assert.notEqual(lit.data[0],src.data[0]);assert.equal(lit.data[7],0);
});
