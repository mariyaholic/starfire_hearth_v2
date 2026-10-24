#!/usr/bin/env python3
"""Prepare the branching-campaign art for tools/import_assets.py: scenes to 3200x1200, portraits
keyed, despilled, headroom set to 10.3% (the shipped set) per character (shared by its expressions), 1024x1024.

Usage (DESIGN_LOG 108): git archive the art branch's assets/branching_campaign, then
  python3 tools/art/prep_branching_art.py <that folder> <out folder> [<batch> <id,id,...>]
and copy the sfh_*_batch<N>.zip files it writes into incoming/. With no batch and ids it builds
batch 2 (everything but HOLD); with them, only those ids (batch 3 is the redo of HOLD). An
expression always takes its character's headroom from the neutral, whether or not it is listed."""
import json, sys, pathlib, zipfile
import numpy as np
from PIL import Image, ImageFilter
SRC = pathlib.Path(sys.argv[1]); OUT = pathlib.Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
man = json.load(open(SRC / "manifest.json"))["items"]
BATCH = int(sys.argv[3]) if len(sys.argv) > 4 else 2
ONLY = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
HOLD = {"end_annexed", "gardener_ilyin__warm", "gardener_ilyin__worried", "gardener_ilyin__stern",
        "pell_okonkwo_dane", "pell_okonkwo_dane__warm", "pell_okonkwo_dane__worried", "pell_okonkwo_dane__stern"}
LIC = ("Generated using OpenAI built-in image generation in Codex on ChatGPT Plus (plan confirmed by commissioner). "
       "Commercial use permitted under OpenAI Terms of Use; as between the user and OpenAI, the user owns Output to the "
       "extent permitted by law. https://openai.com/policies/row-terms-of-use/")
SOURCE = "OpenAI built-in image_gen, ChatGPT Plus; original generated artwork prompted by Codex (branching campaign art run, October 15; redos October 24)."

def key(im):
    rgb = np.asarray(im.convert("RGB")).astype(np.float64)
    dist = np.abs(rgb - np.array([0, 255, 0])).sum(axis=2)
    a = np.clip((dist - 90) / 150, 0, 1)
    # Unmix the green background from edge pixels, then despill: green may not exceed the mean of red and blue by much.
    safe = np.maximum(a, 1e-3)[..., None]
    fg = np.clip((rgb - (1 - a)[..., None] * np.array([0, 255, 0])) / safe, 0, 255)
    near = np.asarray(Image.fromarray((255 * (1 - a)).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
    fg[..., 1] = np.where(near, np.minimum(fg[..., 1], (fg[..., 0] + fg[..., 2]) / 2 + 12), fg[..., 1])
    a8 = (a * 255).round().astype(np.uint8)
    out = np.dstack([fg.round().astype(np.uint8), a8])
    out[a8 == 0, :3] = 0
    return Image.fromarray(out, "RGBA")


def top_row(im):
    a = np.asarray(im)[..., 3]
    rows = np.where((a > 128).sum(axis=1) > 3)[0]
    return int(rows[0])

scenes, portraits = [], []
by_char = {}
for it in man:
    if (it["id"] not in ONLY) if ONLY is not None else (it["id"] in HOLD):
        continue
    f = SRC / it["file"]
    if it["file"].startswith("portraits"):
        by_char.setdefault(it["id"].split("__")[0], []).append(it)
    else:
        Image.open(f).convert("RGB").resize((3200, 1200), Image.LANCZOS).save(OUT / ("v_" + it["id"] + ".png"))
        scenes.append(it["id"])
for char, items in by_char.items():
    neutral = next((i for i in man if i["id"] == char), None)
    ref = key(Image.open(SRC / (neutral or items[0])["file"]))
    shift = round(0.103 * ref.height) - top_row(ref)
    for it in items:
        im = key(Image.open(SRC / it["file"]))
        w, h = im.size
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        canvas.paste(im, (0, shift))
        canvas.resize((1024, 1024), Image.LANCZOS).save(OUT / ("p_" + it["id"] + ".png"))
        portraits.append(it["id"])
        print(it["id"], "shift", shift, "top was %.1f%%" % (100 * top_row(im) / h))
for kind, ids, pre in (("vignette", scenes, "v_"), ("portrait", portraits, "p_")):
    if not ids:
        continue
    with zipfile.ZipFile(OUT / ("sfh_%s_batch%d.zip" % (kind, BATCH)), "w") as z:
        meta = {"kind": kind, "batch": BATCH, "licence": LIC, "source": SOURCE,
                "items": [{"id": i, "file": i + ".png"} for i in ids]}
        z.writestr("manifest.json", json.dumps(meta, indent=1))
        for i in ids:
            z.write(OUT / (pre + i + ".png"), i + ".png")
print(len(scenes), "scenes;", len(portraits), "portraits")
print(json.dumps({"scenes": scenes, "portraits": portraits}), file=open(OUT / "ids.json", "w"))
