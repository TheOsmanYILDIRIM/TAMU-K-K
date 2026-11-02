#!/usr/bin/env python3
"""MobileSAM CPU anatomical mask candidates (source pixels, non-destructive)."""
import argparse,hashlib,json
from pathlib import Path
import cv2,numpy as np,torch
from PIL import Image,ImageDraw
from mobile_sam import sam_model_registry,SamPredictor
PARTS=[
("torso",(0.19,.33,.73,.73),(.46,.52)),
("head",(.72,.31,.94,.57),(.85,.43)),
("ear_near",(.57,.01,.77,.38),(.66,.17)),
("ear_far",(.71,.01,.88,.37),(.78,.18)),
("tail",(.02,.35,.29,.58),(.13,.48)),
("hind_leg_near",(.24,.54,.44,.97),(.33,.8)),
("hind_leg_far",(.15,.55,.30,.95),(.20,.79)),
("front_leg_near",(.52,.55,.71,.98),(.61,.83)),
("front_leg_far",(.66,.54,.83,.95),(.73,.78)),
]
def main():
 p=argparse.ArgumentParser()
 p.add_argument("--input",required=True,type=Path)
 p.add_argument("--output",required=True,type=Path)
 p.add_argument("--checkpoint",required=True,type=Path)
 a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 im=Image.open(a.input).convert("RGB");w,h=im.size
 assert w>=256 and h>=256
 torch.set_num_threads(2)
 model=sam_model_registry["vit_t"](checkpoint=str(a.checkpoint));model.to(device="cpu").eval()
 predictor=SamPredictor(model)
 predictor.set_image(np.asarray(im))
 overview=im.copy();draw=ImageDraw.Draw(overview)
 report={"model":"MobileSAM vit_t CPU","source_sha256":hashlib.sha256(a.input.read_bytes()).hexdigest(),
         "checkpoint_sha256":hashlib.sha256(a.checkpoint.read_bytes()).hexdigest(),"source_size":[w,h],
         "warning":"These are overlapping mask candidates; hidden anatomy cannot be recovered by SAM.","parts":[]}
 rgba=Image.open(a.input).convert("RGBA")
 for name,box,point in PARTS:
  x1,y1,x2,y2=box
  coords=np.array([x1*w,y1*h,x2*w,y2*h],dtype=np.float32)
  seed=np.array([[point[0]*w,point[1]*h]],dtype=np.float32)
  masks,scores,_=predictor.predict(point_coords=seed,point_labels=np.array([1]),box=coords,multimask_output=True)
  best=int(np.argmax(scores));mask=masks[best].astype(np.uint8)
  # Restrict candidate to requested anatomy area, to prevent stealing neighboring parts.
  window=np.zeros_like(mask);window[max(0,int(y1*h)):min(h,int(y2*h)),max(0,int(x1*w)):min(w,int(x2*w))]=1
  mask*=window
  count=int(mask.sum())
  if count<100: raise ValueError(f"Empty mask {name}: {count}")
  alpha=Image.fromarray(mask*255,"L")
  cut=rgba.copy();cut.putalpha(alpha);cut.save(a.output/(name+".png"))
  alpha.save(a.output/(name+"_mask.png"))
  draw.rectangle((x1*w,y1*h,x2*w,y2*h),outline="#00ffae",width=3)
  draw.text((x1*w,y1*h),name,fill="#f0ff00")
  report["parts"].append({"name":name,"score":float(scores[best]),"pixels":count,"box":box,"review_required":True})
  print("TAMU_MOBILESAM_PART",name,count,flush=True)
 overview.save(a.output/"review_boxes.png")
 (a.output/"manifest.json").write_text(json.dumps(report,indent=2))
 print("TAMU_MOBILESAM_NINE_PARTS_OK",flush=True)
if __name__=="__main__":main()
