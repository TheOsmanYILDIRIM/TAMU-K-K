#!/usr/bin/env python3
"""Generate 102 RGBA video-derived optical plasma frames from the *authenticated*
original Drive ZIP supplied by the user. No download/upload or input mutations.

Dependencies: pip install opencv-python numpy pillow
Usage: python scripts/drive_optical_generate_frames.py ORIGINAL.zip OUT_DIR
"""
import hashlib
import io
import json
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile

import cv2
import numpy as np
from PIL import Image

EXPECTED_ZIP_SHA256 = "e54442ee8dcc7dde61bc8600ca4eb34eaf4a8ec05ea31271240a292b0035e4c3"
EXPECTED_VIDEO_SHA256 = "50b2d7a0c810206855ce5120010cf8fe10cd14661799b29ccfa7a345347a5bc6"
EXPECTED_CORE_SHA256 = "2c63bc1645ab1718e8f612f17a8821ed4f22cd557ffd66c2e506e8d46d2dcf0b"
VIDEO_NAME = "sources/veo/121246_orbit.mp4"
CORE_NAME = "sources/core/121222.png"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def warp(im, flow, t):
    h, w = im.shape[:2]
    xs, ys = np.meshgrid(np.arange(w), np.arange(h))
    return cv2.remap(im, (xs + flow[:, :, 0] * t).astype(np.float32),
                     (ys + flow[:, :, 1] * t).astype(np.float32),
                     cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def blend(a, b, t):
    a1 = cv2.cvtColor(a, cv2.COLOR_BGR2GRAY)
    b1 = cv2.cvtColor(b, cv2.COLOR_BGR2GRAY)
    f = cv2.calcOpticalFlowFarneback(a1, b1, None, .5, 3, 19, 3, 5, 1.1, 0)
    g = cv2.calcOpticalFlowFarneback(b1, a1, None, .5, 3, 19, 3, 5, 1.1, 0)
    return cv2.addWeighted(warp(a, f, -t), 1-t, warp(b, g, -(1-t)), t, 0)


def generate(archive, out):
    archive = Path(archive)
    content = archive.read_bytes()
    if sha(content) != EXPECTED_ZIP_SHA256:
        raise ValueError("Drive original archive SHA mismatch — refuse unapproved source")
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    with ZipFile(io.BytesIO(content)) as zipfile:
        video = zipfile.read(VIDEO_NAME)
        core = zipfile.read(CORE_NAME)
    if sha(video) != EXPECTED_VIDEO_SHA256 or sha(core) != EXPECTED_CORE_SHA256:
        raise ValueError("original video/core hash mismatch")
    (out / "core_original.png").write_bytes(core)
    loop = out / "loop"
    loop.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / "approved-orbit.mp4"
        source.write_bytes(video)
        cap = cv2.VideoCapture(str(source))
        frames = []
        while True:
            ok, raw = cap.read()
            if not ok:
                break
            frames.append(cv2.resize(raw, (384, 216), interpolation=cv2.INTER_AREA))
        cap.release()
    if len(frames) < 147:
        raise ValueError("video is missing approved 31..146 frame range")
    chosen = frames[31:147]
    transition = []
    k = 14
    for i in range(k):
        t = (i+1)/(k+1)
        t = t*t*(3-2*t)
        transition.append(blend(chosen[-k+i], chosen[i], t))
    images = chosen[k:-k] + transition
    if len(images) != 102:
        raise ValueError("invalid loop length")
    hashes = []
    for index, bgr in enumerate(images):
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
        lo, hi = rgb.min(2), rgb.max(2)
        alpha = np.clip((hi-9)/48, 0, 1) * np.clip((hi-lo-3)/15, 0, 1)
        alpha = np.clip(alpha**.88, 0, 1)
        straight = np.clip(rgb / np.maximum(alpha[..., None], .055), 0, 255).astype("uint8")
        aa = (alpha*255).astype("uint8")
        rgba = np.dstack((straight, aa))
        rgba[aa == 0, :3] = 0
        target = loop / ("frame_%03d.png" % index)
        Image.fromarray(rgba, "RGBA").save(target, optimize=True)
        hashes.append(sha(target.read_bytes()))
    if len(set(hashes)) != 102:
        raise ValueError("duplicate video frame hashes")
    # Accepted optical source is real Veo. A successful file gate does not prove
    # actual LÖVE engine rendering, Android FPS, user art approval or a perfect loop.
    results = {"archive_sha256": sha(content), "original_video_sha256": sha(video),
               "core_original_sha256": sha(core), "runtime_size": [384, 216],
               "source_range": [31, 146], "frames": 102, "sha256": hashes,
               "source_gate_pass": True, "visual_acceptance": "pending LÖVE/Xvfb"}
    (out / "drive_derived_manifest.json").write_text(json.dumps(results, indent=2)+"\n")
    print(json.dumps({k: v for k, v in results.items() if k != "sha256"}, indent=2))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    generate(sys.argv[1], sys.argv[2])
