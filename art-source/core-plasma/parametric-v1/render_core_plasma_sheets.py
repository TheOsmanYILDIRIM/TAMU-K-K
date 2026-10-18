#!/usr/bin/env python3
"""Render RGBA front/back sprite sheets using the embedded V4 browser renderer.

Requires: pip install playwright pillow; playwright chromium installation.
Source HTML embeds all four original brush images. Core PNG is preview-only.
"""
import argparse, asyncio, base64, io, json
from pathlib import Path
from PIL import Image

async def run(args):
    from playwright.async_api import async_playwright
    src = Path(args.html).read_text(encoding="utf-8")
    settings = json.loads(Path(args.settings).read_text(encoding="utf-8"))
    output = Path(args.output); output.mkdir(parents=True, exist_ok=True)
    count = args.frames
    size = args.size
    cols = args.columns
    rows = (count + cols - 1)//cols
    layers = {k: Image.new("RGBA",(size*cols,size*rows)) for k in ("front","back")}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True, executable_path=args.chromium or None, args=["--no-sandbox"])
        page = await browser.new_page()
        await page.set_content(src, wait_until="load")
        await page.wait_for_function("Object.keys(assets).length===5")
        await page.evaluate("(v)=>{playing=false;apply(v)}",settings)
        for i in range(count):
            # Same time samples as the approved 32-frame test; not a guaranteed seamless loop.
            await page.evaluate("(v)=>{t=v;render()}",i*args.time_step)
            for layer in layers:
                encoded=await page.evaluate(
                    "(key)=>(key==='front'?front:back).toDataURL('image/png').split(',')[1]",layer)
                im=Image.open(io.BytesIO(base64.b64decode(encoded))).convert("RGBA")
                im=im.resize((size,size),Image.Resampling.LANCZOS)
                layers[layer].paste(im,((i%cols)*size,(i//cols)*size))
        await browser.close()
    for layer,im in layers.items():
        path=output/f"core_plasma_{layer}_spritesheet_{count}x{size}.png"
        im.save(path)
        print(path)
    (output/"render_metadata.json").write_text(json.dumps({
        "frame_count":count,"frame_width":size,"frame_height":size,
        "columns":cols,"rows":rows,"time_step":args.time_step,
        "source":"core_plasma_generator_v4.html",
        "note":"Loop seam and game runtime not verified."
    },indent=2)+"\n",encoding="utf-8")

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--chromium", default=None, help="Optional local Chromium executable path")
    ap.add_argument("--html",default="core_plasma_generator_v4.html")
    ap.add_argument("--settings",default="core_plasma_settings.json")
    ap.add_argument("--output",default="rendered")
    ap.add_argument("--frames",type=int,default=32)
    ap.add_argument("--size",type=int,default=512)
    ap.add_argument("--columns",type=int,default=8)
    ap.add_argument("--time-step",type=float,default=.42)
    asyncio.run(run(ap.parse_args()))
