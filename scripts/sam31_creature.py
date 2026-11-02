#!/usr/bin/env python3
"""SAM 3.1 assisted nine-part mask candidates; never invent hidden anatomy.
Outputs masks and source-pixel RGBA cutouts; all require visual review.
"""
import argparse
import json
import hashlib
from pathlib import Path
import numpy as np
import torch
from PIL import Image,ImageDraw
from sam3.model_builder import build_sam3_image_model
from sam3.model.sam3_image_processor import Sam3Processor

# User reference 124072.png: 1536 x 1024. Manual approximate anatomy regions.
# Box prompts are guides only: overlapping limbs/ears still need correction.
PARTS = [
    ("torso", [0.18,0.34,0.72,0.75], "animal torso"),
    ("head", [0.72,0.30,0.94,0.57], "animal head"),
    ("ear_near", [0.57,0.01,0.76,0.39], "leaf shaped ear"),
    ("ear_far", [0.71,0.01,0.87,0.39], "leaf shaped ear"),
    ("tail", [0.02,0.36,0.28,0.59], "animal tail"),
    ("hind_leg_near", [0.23,0.52,0.43,0.97], "animal hind leg"),
    ("hind_leg_far", [0.13,0.52,0.29,0.95], "animal hind leg"),
    ("front_leg_near", [0.53,0.55,0.71,0.98], "animal front leg"),
    ("front_leg_far", [0.66,0.55,0.83,0.94], "animal front leg"),
]

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    source=a.input.read_bytes()
    image=Image.open(a.input).convert("RGB")
    width,height=image.size
    if width<256 or height<256: raise ValueError("Source too small")
    if not torch.cuda.is_available():
        raise RuntimeError("SAM 3.1 requires CUDA GPU for this workflow")
    model=build_sam3_image_model()
    processor=Sam3Processor(model)
    manifest={"model":"facebookresearch/sam3 (SAM 3.1 checkpoint selected by upstream)","input_sha256":hashlib.sha256(source).hexdigest(),"source_size":[width,height],"status":"candidates_require_manual_review","parts":[]}
    preview=Image.new("RGB",(width,height),image)
    draw=ImageDraw.Draw(preview)
    colors=["#ff8664","#c4e750","#53daec","#7269ff","#ffcc48","#f770ae","#bc7efa","#69cf91","#e4a36a"]
    for idx,(name,box,text_prompt) in enumerate(PARTS):
        # Prefer geometric box prompts to avoid ambiguous multiple instances.
        state=processor.set_image(image)
        cx=(box[0]+box[2])/2;cy=(box[1]+box[3])/2
        bw=box[2]-box[0];bh=box[3]-box[1]
        output=processor.add_geometric_prompt([cx,cy,bw,bh], True, state=state)
        scores=output["scores"]; masks=output["masks"]
        if hasattr(scores,"detach"):scores=scores.detach().cpu().numpy()
        if hasattr(masks,"detach"):masks=masks.detach().cpu().numpy()
        scores=np.asarray(scores).reshape(-1)
        masks=np.asarray(masks)
        if masks.ndim==4:masks=masks[:,0]
        if masks.ndim==2:masks=masks[None]
        if len(scores)==0 or len(masks)==0:
            raise RuntimeError("SAM returned no mask for "+name)
        best=int(np.argmax(scores))
        mask=masks[best]
        if mask.shape!=(height,width):
            mask=Image.fromarray((mask>0).astype(np.uint8)*255).resize((width,height),Image.Resampling.NEAREST)
            mask=np.asarray(mask)>127
        else:mask=mask>0
        area=int(mask.sum())
        if area<100:raise RuntimeError("Suspicious empty mask: "+name)
        alpha=Image.fromarray(np.uint8(mask)*255,"L")
        cut=Image.open(a.input).convert("RGBA")
        cut.putalpha(alpha)
        cut.save(a.output/(name+".png"))
        alpha.save(a.output/(name+"_mask.png"))
        bb=(round(box[0]*width),round(box[1]*height),round(box[2]*width),round(box[3]*height))
        draw.rectangle(bb,outline=colors[idx],width=3)
        draw.text((bb[0]+3,bb[1]+3),name,fill=colors[idx])
        manifest["parts"].append({"name":name,"score":float(scores[best]),"area":area,"box":box,"review_required":True})
        print("TAMU_SAM31_PART",name,area,float(scores[best]),flush=True)
    preview.save(a.output/"review_boxes.png")
    (a.output/"manifest.json").write_text(json.dumps(manifest,indent=2))
    print("TAMU_SAM31_CANDIDATES_OK",len(PARTS),flush=True)

if __name__=="__main__":main()
