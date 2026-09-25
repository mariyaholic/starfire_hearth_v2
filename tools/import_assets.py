#!/usr/bin/env python3
"""Asset intake for outsourced batches (§15.2 of docs/BUILD_PROMPT.md).

Run from the repository root:
  python3 tools/import_assets.py --zip incoming/sfh_sfx_batch1.zip [--zip ...] [--check] [--replace]
then import the new files with Godot (godot --headless --path . --import) and commit them.

For each batch zip it checks the manifest, the licence and every item against the briefs of
§15.4-§15.9, converts what needs converting, copies the result under assets/delivered/<kind>/,
writes the Godot import settings those files need, marks each id "delivered" in
data/asset_manifest.json, records the batch in CREDITS.md and prints a PASS, WARN or FAIL line per
item. A FAIL item is not ingested and keeps its fallback. --check writes nothing. A delivered
asset is never replaced without --replace. Reports and contact sheets go to reports/assets/
(git-ignored).

Conversions: music to Ogg Vorbis (quality 6); sounds to 16-bit WAV (a looping bed to Ogg);
scenes, portraits and key art to lossy WebP at display size; ships and VFX stay PNG; store art is
kept as delivered in a folder Godot ignores, so it never ships inside the game.

It is Python rather than a Godot tool because Godot can neither encode Ogg Vorbis nor measure
loudness fast enough (DESIGN_LOG 93). It needs: pip install -r tools/requirements-assets.txt
"""
import argparse, colorsys, datetime, io, json, math, pathlib, re, sys, textwrap, zipfile
import xml.etree.ElementTree as ET

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "data/asset_manifest.json"
DELIVERED = ROOT / "assets/delivered"
CREDITS = ROOT / "CREDITS.md"
REPORTS = ROOT / "reports/assets"
TOKENS = ROOT / "ui/theme/tokens.gd"

# ---------------------------------------------------------------------------------------------
# The briefs (§15.4-§15.9) as data.

# §15.4: id -> (shortest ms, longest ms, stereo allowed, variants, loops).
SFX = {
    "ui_click": (30, 80, False, 3, False), "ui_hover": (20, 50, False, 1, False),
    "ui_confirm": (120, 250, False, 1, False), "ui_cancel": (80, 200, False, 1, False),
    "ui_error": (150, 400, False, 1, False), "ui_toggle_on": (60, 120, False, 1, False),
    "ui_toggle_off": (60, 120, False, 1, False), "ui_panel_open": (120, 250, False, 1, False),
    "ui_panel_close": (100, 200, False, 1, False), "ui_tooltip_pin": (40, 100, False, 1, False),
    "ui_end_turn": (400, 900, False, 1, False), "ui_alert": (250, 500, False, 1, False),
    "ui_alert_critical": (500, 900, False, 1, False), "ui_event_open": (400, 800, False, 1, False),
    "ui_choice_made": (300, 700, False, 1, False), "ui_page_turn": (150, 300, False, 3, False),
    "ui_research_done": (400, 800, False, 1, False), "ui_build_done": (300, 600, False, 1, False),
    "ui_place_district": (150, 300, False, 3, False), "ui_demolish": (300, 500, False, 1, False),
    "ui_pop_growth": (200, 400, False, 1, False), "ui_overflow_warn": (200, 400, False, 1, False),
    "ship_move_order": (150, 300, False, 1, False), "ship_arrive": (200, 400, False, 1, False),
    "survey_ping": (400, 800, True, 1, False), "beacon_activate": (1500, 3000, True, 1, False),
    "jump_transit": (800, 1500, True, 1, False), "noise_threshold": (1000, 2000, False, 1, False),
    "hit_kinetic": (80, 200, False, 3, False), "hit_thermal": (100, 250, False, 3, False),
    "hit_explosive": (200, 400, False, 3, False), "shield_hit": (150, 300, False, 3, False),
    "pd_intercept": (60, 150, False, 1, False), "ship_destroyed": (800, 1500, True, 1, False),
    "battle_won": (1000, 2000, False, 1, False), "battle_lost": (1000, 2000, False, 1, False),
    "treaty_signed": (800, 1500, False, 1, False), "war_declared": (1000, 2000, False, 1, False),
    "vael_voice": (1000, 2000, False, 3, False), "ambient_ui_room": (20000, 40000, True, 1, True),
}
# Target loudness (LUFS over the sound): UI sounds about -20, game sounds about -16; the hover
# tick and the room bed about -30. Loudness is "about" in the brief, so it only warns.
SFX_LOUDNESS = {"ui_hover": -30.0, "ambient_ui_room": -30.0}
SFX_LOUDNESS_TOLERANCE = 6.0

# §15.5: id prefix or id -> (shortest s, longest s). Everything but the stings loops.
MUSIC_LENGTH = {
    "mus_battle": (90, 120), "sting_victory": (10, 20), "sting_defeat": (10, 20),
    "mus_": (120, 180), "theme_": (90, 150), "mood_": (90, 150), "sting_": (45, 90),
}
MUSIC_LUFS, MUSIC_LUFS_TOLERANCE = -18.0, 1.0
PEAK_MAX_DBTP = -1.0

# §15.6: id -> (width, height, flipbook grid (columns, rows) or None, fps, loops).
VFX = {
    "fx_dot_soft": (64, 64, None, 0, False), "fx_dot_hard": (64, 64, None, 0, False),
    "fx_spark": (64, 64, None, 0, False), "fx_shard": (64, 64, None, 0, False),
    "fx_ring": (128, 128, None, 0, False), "fx_glow": (256, 256, None, 0, False),
    "fx_hex_shield": (256, 256, None, 0, False), "fx_tracer": (128, 16, None, 0, False),
    "fx_sparkle": (64, 64, None, 0, False), "fx_smoke_puff": (128, 128, None, 0, False),
    "fx_light_shaft": (256, 1024, None, 0, False),
    "fx_explosion_small": (512, 512, (4, 4), 24, False),
    "fx_explosion_large": (1024, 1024, (4, 4), 24, False),
    "fx_shield_ripple": (512, 256, (4, 2), 24, False),
    "fx_beacon_pulse": (1024, 1024, (4, 4), 12, True),
    "fx_jump_flash": (1024, 1024, (4, 4), 24, False),
    "fx_survey_sweep": (1024, 1024, (4, 4), 12, True),
}

# §15.7-§15.9: the delivered size, whether it must be transparent, and what the game ships.
# ship: (width, height) of the WebP written, or None to keep the PNG as delivered.
VIGNETTE = {"size": (3200, 1200), "ship": (2400, 900)}
PORTRAIT = {"size": (1024, 1024), "ship": (768, 768)}
SHIP = {"size": (512, 512)}
ART = {
    "title": {"size": (3840, 2160), "alpha": False, "ship": (2560, 1440)},
    "title_cast": {"size": (3840, 2160), "alpha": False, "ship": (2560, 1440)},
    "logo_title": {"size": (2048, 1024), "alpha": True, "ship": (1536, 768)},
}
LOGO_SVGS = {"logo_light_on_dark", "logo_dark_on_light", "logo_mono_white", "emblem_mark"}
STORE = {
    "app_icon": ((1024, 1024), False), "android_adaptive_fg": ((432, 432), True),
    "android_adaptive_bg": ((432, 432), False), "play_feature": ((1024, 500), False),
    "store_header": ((920, 430), False), "store_capsule_main": ((1232, 706), False),
    "store_capsule_small": ((462, 174), False), "store_capsule_vertical": ((748, 896), False),
    "library_capsule": ((600, 900), False), "library_hero": ((3840, 1240), False),
    "library_logo": ((1280, 720), True),
}

WEBP_QUALITY = 88
# Godot re-encodes every texture on import; painted art is stored lossy in the game's pack
# (lossless would be several times larger) and gets mipmaps, as it is drawn at many sizes.
PAINTED_IMPORT = {"compress/mode": 1, "compress/lossy_quality": 0.85, "mipmaps/generate": True}
# Vorbis quality 6. The budget (§9.11) allows about 112 kbps on average; this sparse, clean music
# needs far less at any quality, so it gets a high one (batch 1 averages about 70 kbps).
OGG_QUALITY_MUSIC = 0.6
OGG_QUALITY_BED = 0.4

# §9.11: what the game may add to the web download.
BUDGET_MB = {"music": 70.0, "sfx": 5.0, "painted": 40.0}

LICENCE_OK = re.compile(r"cc0|public domain|work[- ]for[- ]hire|all rights (assigned )?to the owner|"
                        r"commercial use (is )?(permitted|allowed)", re.I)
LICENCE_BANNED = re.compile(r"non-?commercial|\bnc\b|share-?alike|\bby-sa\b|\bby-nc\b|\bcc[- ]by\b", re.I)


# ---------------------------------------------------------------------------------------------
# Results.

class Item:
    """One id of a batch: its checks, the files to write and the manifest fields to set."""

    def __init__(self, kind, asset_id):
        self.kind, self.id = kind, asset_id
        self.fails, self.warns, self.facts = [], [], []
        self.outputs = []        # (path relative to assets/delivered, bytes, import params or None)
        self.record = {}         # manifest fields besides status
        self.thumb = None        # a PIL image for the contact sheet
        self.hues = ""

    def fail(self, msg):
        self.fails.append(msg)

    def warn(self, msg):
        self.warns.append(msg)

    @property
    def verdict(self):
        return "FAIL" if self.fails else ("WARN" if self.warns else "PASS")

    def line(self):
        notes = self.fails + self.warns + self.facts
        return "%s  %-8s %-24s %s" % (self.verdict, self.kind, self.id, "; ".join(notes))


# ---------------------------------------------------------------------------------------------
# Audio measurement: ITU-R BS.1770-4 loudness and true peak.

def _biquads(sr):
    """The K-weighting filter (a high shelf, then a high pass) for any sample rate."""
    out = []
    # High shelf: +4 dB above about 1.7 kHz.
    g, q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    a = 10 ** (g / 40.0)
    w0 = 2 * math.pi * fc / sr
    alpha = math.sin(w0) / (2 * q)
    cw, sa = math.cos(w0), 2 * math.sqrt(a) * alpha
    b = [a * ((a + 1) + (a - 1) * cw + sa), -2 * a * ((a - 1) + (a + 1) * cw), a * ((a + 1) + (a - 1) * cw - sa)]
    den = [(a + 1) - (a - 1) * cw + sa, 2 * ((a - 1) - (a + 1) * cw), (a + 1) - (a - 1) * cw - sa]
    out.append((np.array(b) / den[0], np.array(den) / den[0]))
    # High pass at about 38 Hz.
    q, fc = 0.5003270373238773, 38.13547087602444
    w0 = 2 * math.pi * fc / sr
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    den = [1 + alpha, -2 * cw, 1 - alpha]
    out.append((np.array(b) / den[0], np.array(den) / den[0]))
    return out


def _k_power(x, sr):
    """K-weighted squared signal summed over the channels (all weighted 1.0: mono or stereo)."""
    y = x.astype(np.float64)
    for b, a in _biquads(sr):
        y = signal.lfilter(b, a, y, axis=0)
    return np.sum(y * y, axis=1)


def _lufs(mean_power):
    return -0.691 + 10 * math.log10(mean_power) if mean_power > 0 else -math.inf


def integrated_lufs(x, sr):
    """Gated integrated loudness: 400 ms blocks, 75% overlap, -70 LUFS and -10 LU gates."""
    p = _k_power(x, sr)
    block, hop = int(0.4 * sr), int(0.1 * sr)
    if len(p) < block:
        return _lufs(float(np.mean(p)))
    c = np.concatenate([[0.0], np.cumsum(p)])
    starts = np.arange(0, len(p) - block + 1, hop)
    z = (c[starts + block] - c[starts]) / block
    loud = np.array([_lufs(v) for v in z])
    z = z[loud > -70.0]
    if len(z) == 0:
        return -math.inf
    rel = _lufs(float(np.mean(z))) - 10.0
    z2 = z[np.array([_lufs(v) for v in z]) > rel]
    return _lufs(float(np.mean(z2))) if len(z2) else -math.inf


def clip_lufs(x, sr):
    """Loudness over a short sound's own length (ungated): the brief's level for sounds."""
    return _lufs(float(np.mean(_k_power(x, sr))))


def true_peak_db(x, chunk=48000 * 5):
    """The peak after 4x oversampling, in dBTP."""
    peak = 0.0
    for start in range(0, len(x), chunk):
        seg = x[max(0, start - 64):start + chunk + 64]
        up = signal.resample_poly(seg.astype(np.float64), 4, 1, axis=0)
        peak = max(peak, float(np.max(np.abs(up))))
    return 20 * math.log10(peak) if peak > 0 else -math.inf


def lead_silence_ms(x, sr, floor_db=-60.0):
    level = np.max(np.abs(x), axis=1)
    loud = np.nonzero(level > 10 ** (floor_db / 20))[0]
    return 1000.0 * (loud[0] if len(loud) else len(level)) / sr


def tail_db(x, sr):
    """The level of the last 5 ms relative to the loudest sample: high means a hard cut."""
    level = np.max(np.abs(x), axis=1)
    top = float(np.max(level))
    end = float(np.max(level[-max(1, int(0.005 * sr)):]))
    return 20 * math.log10(end / top) if end > 0 and top > 0 else -math.inf


def seam_ratio(x, a, b):
    """How big the jump at a loop seam is (end sample b-1 to start sample a) against the largest
    ordinary sample-to-sample step: above 1 it can click."""
    steps = np.abs(np.diff(x[a:b], axis=0)).max(axis=1)
    typical = float(np.percentile(steps, 99.9)) or 1e-9
    return float(np.max(np.abs(x[b - 1] - x[a]))) / typical


def _read_audio(data):
    x, sr = sf.read(io.BytesIO(data), dtype="float32", always_2d=True)
    info = sf.info(io.BytesIO(data))
    return x, sr, info


def _encode(x, sr, fmt, subtype, quality=None):
    """Encodes in blocks: libsndfile's Vorbis encoder overflows its stack on one long write."""
    buf = io.BytesIO()
    level = 1.0 - quality if quality is not None else None
    with sf.SoundFile(buf, "w", sr, x.shape[1], subtype=subtype, format=fmt, compression_level=level) as out:
        for start in range(0, len(x), 1 << 15):
            out.write(x[start:start + (1 << 15)])
    return buf.getvalue()


# ---------------------------------------------------------------------------------------------
# Image checks.

def _palette():
    """The design tokens of §8.2 (ui/theme/tokens.gd), plus pure white and black."""
    hexes = set(re.findall(r'Color\("(#[0-9A-Fa-f]{6})"\)', TOKENS.read_text()))
    return {h.upper() for h in hexes} | {"#FFFFFF", "#000000"}


def _transparent_border(im):
    """True when the image's edges are mostly see-through (a cut-out on transparency)."""
    if im.mode != "RGBA":
        return False
    a = np.asarray(im.getchannel("A"))
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    return float(np.mean(edge < 16)) > 0.5


def _key_green(im):
    """A flat #00FF00 background turned into transparency (§15.7), or None if there is none."""
    rgb = np.asarray(im.convert("RGB")).astype(np.int16)
    edge = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    green = (edge[:, 1] > 200) & (edge[:, 0] < 60) & (edge[:, 2] < 60)
    if float(np.mean(green)) < 0.5:
        return None
    dist = np.abs(rgb - np.array([0, 255, 0])).sum(axis=2)
    alpha = np.clip((dist - 60) * 255 // 120, 0, 255).astype(np.uint8)
    out = im.convert("RGBA")
    out.putalpha(Image.fromarray(alpha))
    return out


def dominant_hues(im, n=3):
    """The strongest hue families of an image, for the visual check (§15.1 rule 6)."""
    small = im.convert("RGBA").resize((96, max(1, 96 * im.height // im.width)))
    px = np.asarray(small).reshape(-1, 4).astype(np.float64) / 255.0
    px = px[px[:, 3] > 0.5]
    if len(px) == 0:
        return "transparent"
    hsv = np.array([colorsys.rgb_to_hsv(*p[:3]) for p in px])
    weight = hsv[:, 1] * hsv[:, 2]
    if weight.sum() < 1e-6:
        return "greyscale"
    bins = np.bincount((hsv[:, 0] * 12).astype(int) % 12, weights=weight, minlength=12)
    names = ["red", "orange", "yellow", "lime", "green", "spring", "cyan", "azure", "blue",
             "violet", "magenta", "rose"]
    order = np.argsort(bins)[::-1][:n]
    total = bins.sum()
    return ", ".join("%s %d%%" % (names[i], round(100 * bins[i] / total)) for i in order if bins[i] > 0)


def _webp(im, size, quality=WEBP_QUALITY):
    im = im.resize(size, Image.LANCZOS) if im.size != size else im
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=quality, method=6, alpha_quality=100)
    return buf.getvalue()


def _png(im):
    """The image as an optimised PNG; a fully opaque alpha channel is dropped (same pixels)."""
    if im.mode == "RGBA" and im.getchannel("A").getextrema() == (255, 255):
        im = im.convert("RGB")
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def _thumb(im, box=200):
    t = im.convert("RGBA")
    t.thumbnail((box, box), Image.LANCZOS)
    return t


# ---------------------------------------------------------------------------------------------
# One handler per kind: check the files of one id and plan what to write.

def _variant_names(asset_id, files, variants, item):
    """Checks the file names: <id>.<ext>, or <id>_1..<id>_3 for a sound with variants."""
    names = [pathlib.PurePosixPath(f).name for f in files]
    stems = [n.rsplit(".", 1)[0] for n in names]
    if variants == 1:
        if stems != [asset_id]:
            item.fail("file must be named %s.<ext>, got %s" % (asset_id, ", ".join(names)))
    else:
        ok = {"%s_%d" % (asset_id, i) for i in range(1, variants + 1)}
        bad = [n for n, s in zip(names, stems) if s not in ok]
        if bad:
            item.fail("variant files are %s_1..%s_%d, got %s" % (asset_id, asset_id, variants, ", ".join(bad)))
        elif len(files) < variants:
            item.warn("%d of %d variants" % (len(files), variants))
    return names


def handle_sfx(item, files, z, notes):
    shortest, longest, stereo_ok, variants, loops = SFX[item.id]
    names = _variant_names(item.id, files, variants, item)
    written = []
    for f, name in zip(files, names):
        if not name.lower().endswith(".wav"):
            item.fail("%s: WAV expected" % name)
            continue
        x, sr, info = _read_audio(z.read(f))
        ms = 1000.0 * len(x) / sr
        if sr not in (48000, 44100):
            item.fail("%s: %d Hz, the brief asks for 48 kHz" % (name, sr))
        if info.subtype not in ("PCM_16", "PCM_24"):
            item.fail("%s: %s, the brief asks for 24-bit (or 16-bit) PCM" % (name, info.subtype))
        if x.shape[1] == 2 and not stereo_ok:
            item.fail("%s: stereo, the brief asks for mono" % name)
        if x.shape[1] > 2:
            item.fail("%s: %d channels" % (name, x.shape[1]))
        if ms < shortest or ms > longest:
            item.fail("%s: %.0f ms, the brief asks for %d-%d ms" % (name, ms, shortest, longest))
        lead = lead_silence_ms(x, sr)
        if lead > 5.0:
            # A sound must start at once; near-silence before it is trimmed rather than rejected.
            x = x[int(lead * sr / 1000):]
            ms = 1000.0 * len(x) / sr
            item.warn("%s: %.1f ms of silence at the start trimmed (max is 5 ms)" % (name, lead))
        peak = true_peak_db(x)
        if peak > PEAK_MAX_DBTP:
            item.fail("%s: peak %.1f dBTP, max is %.1f" % (name, peak, PEAK_MAX_DBTP))
        if not loops and tail_db(x, sr) > -30.0:
            item.warn("%s: ends %.0f dB below its peak, which may be a hard cut" % (name, tail_db(x, sr)))
        target = SFX_LOUDNESS.get(item.id, -20.0 if item.id.startswith("ui_") else -16.0)
        lufs = integrated_lufs(x, sr) if loops else clip_lufs(x, sr)
        if abs(lufs - target) > SFX_LOUDNESS_TOLERANCE:
            item.warn("%s: %.1f LUFS, the brief says about %.0f" % (name, lufs, target))
        if loops:
            ratio = seam_ratio(x, 0, len(x))
            if ratio > 1.0:
                item.warn("%s: the loop seam jumps %.1fx the largest ordinary step" % (name, ratio))
            data = _encode(x, sr, "OGG", "VORBIS", OGG_QUALITY_BED)
            out = "sfx/%s.ogg" % name.rsplit(".", 1)[0]
            written.append((out, data, ("oggvorbisstr", "AudioStreamOggVorbis", {"loop": True, "loop_offset": 0})))
        else:
            data = _encode(x, sr, "WAV", "PCM_16")
            out = "sfx/%s" % name
            # Short sounds stay uncompressed in the pack: they are small and must start at once.
            written.append((out, data, ("wav", "AudioStreamWAV", {"compress/mode": 0})))
        item.facts.append("%s %.0f ms %s %.1f LUFS %.1f dBTP" % (name, ms, "stereo" if x.shape[1] == 2 else "mono", lufs, peak))
    item.outputs = written
    if len(written) == 1:
        item.record["file"] = written[0][0]
    elif written:
        item.record["files"] = [w[0] for w in written]
    if loops:
        item.record["loop"] = True


def _music_length(asset_id):
    for key in (asset_id, *[k for k in MUSIC_LENGTH if k.endswith("_")]):
        if key in MUSIC_LENGTH and (key == asset_id or asset_id.startswith(key)):
            return MUSIC_LENGTH[key]
    return (0, 10 ** 6)


def handle_music(item, files, z, notes):
    names = _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    name = names[0]
    if not name.lower().endswith((".wav", ".flac")):
        item.fail("%s: WAV or FLAC expected (Ogg or MP3 only as a last resort)" % name)
        return
    x, sr, info = _read_audio(z.read(files[0]))
    secs = len(x) / sr
    loops = not item.id.startswith("sting_")
    if sr != 48000:
        item.fail("%d Hz, the brief asks for 48 kHz" % sr)
    if x.shape[1] != 2:
        item.fail("%d channel(s), the brief asks for stereo" % x.shape[1])
    shortest, longest = _music_length(item.id)
    if secs < shortest or secs > longest:
        item.fail("%.1f s, the brief asks for %d-%d s" % (secs, shortest, longest))
    lufs = integrated_lufs(x, sr)
    if abs(lufs - MUSIC_LUFS) > MUSIC_LUFS_TOLERANCE:
        item.fail("%.2f LUFS, the brief asks for %.0f +/- %.0f" % (lufs, MUSIC_LUFS, MUSIC_LUFS_TOLERANCE))
    peak = true_peak_db(x)
    if peak > PEAK_MAX_DBTP:
        item.fail("peak %.2f dBTP, max is %.1f" % (peak, PEAK_MAX_DBTP))
    start, end = 0, len(x)
    m = re.search(r"loop (\d+)-(\d+)", notes)
    if loops:
        if m:
            start, end = int(m.group(1)), int(m.group(2))
            if not 0 <= start < end <= len(x):
                item.fail("loop %d-%d is outside the %d samples" % (start, end, len(x)))
                return
        else:
            item.warn("no loop points in the notes: the whole file loops")
        ratio = seam_ratio(x, start, end)
        if ratio > 1.0:
            item.warn("the loop seam jumps %.1fx the largest ordinary step" % ratio)
    elif m:
        item.warn("a sting does not loop; its loop points are ignored")
    # The loop's end is the file's end: anything after it is cut.
    data = _encode(x[:end], sr, "OGG", "VORBIS", OGG_QUALITY_MUSIC)
    out = "music/%s.ogg" % item.id
    params = {"loop": loops, "loop_offset": round(start / sr, 6) if loops else 0}
    item.outputs = [(out, data, ("oggvorbisstr", "AudioStreamOggVorbis", params))]
    item.record["file"] = out
    item.facts.append("%.1f s, %.2f LUFS, %.2f dBTP, %s, %.0f kbps Ogg" % (
        end / sr, lufs, peak, "loops %d-%d" % (start, end) if loops else "no loop", len(data) * 8 / (end / sr) / 1000))


def _image(item, z, f):
    try:
        im = Image.open(io.BytesIO(z.read(f)))
        im.load()
        return im
    except Exception as e:  # noqa: BLE001 - any decoder error is a rejected file
        item.fail("%s: not a readable image (%s)" % (f, e))
        return None


def _check_size(item, im, size):
    if im.size != tuple(size):
        item.fail("%dx%d, the brief asks for %dx%d" % (im.size[0], im.size[1], size[0], size[1]))


def _cut_out(item, im):
    """A portrait or ship on transparency: straight alpha, or a #00FF00 background keyed out."""
    if im.mode == "RGBA" and _transparent_border(im):
        return im
    keyed = _key_green(im)
    if keyed is not None:
        item.warn("background keyed out from #00FF00")
        return keyed
    item.fail("needs a transparent background (or flat #00FF00)")
    return im


def handle_vfx(item, files, z, notes):
    names = _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    im = _image(item, z, files[0])
    if im is None:
        return
    w, h, grid, fps, loops = VFX[item.id]
    _check_size(item, im, (w, h))
    if im.mode != "RGBA":
        item.fail("RGBA expected, got %s" % im.mode)
        return
    px = np.asarray(im).reshape(-1, 4).astype(np.int16)
    seen = px[px[:, 3] > 8]
    if len(seen) and int(np.max(seen[:, :3].max(axis=1) - seen[:, :3].min(axis=1))) > 24:
        item.fail("coloured pixels: VFX are white or greyscale, tinted by the engine")
    if grid:
        m = re.search(r"(\d+)x(\d+)\s+(\d+) frames\s+(\d+)\s*fps\s+(non-loop|no loop|loop)", notes)
        if m:
            got = ((int(m.group(1)), int(m.group(2))), int(m.group(4)), m.group(5) == "loop")
            if got != (grid, fps, loops):
                item.warn("notes say %dx%d %d fps%s; the brief says %dx%d %d fps%s" % (
                    got[0][0], got[0][1], got[1], " loop" if got[2] else "", grid[0], grid[1], fps, " loop" if loops else ""))
        else:
            item.warn("no flipbook grid in the notes: the brief's %dx%d at %d fps is used" % (grid[0], grid[1], fps))
        item.record.update({"grid": list(grid), "fps": fps, "loop": loops})
    out = "vfx/%s.png" % item.id
    item.outputs = [(out, _png(im), None)]
    item.record["file"] = out
    item.thumb = _thumb(im)
    item.facts.append("%dx%d%s" % (w, h, " flipbook %dx%d %d fps" % (grid[0], grid[1], fps) if grid else ""))


def _painted(item, im, ship_size, alpha):
    """Scenes, portraits and key art: lossy WebP at display size, with painted-art import."""
    out = "%s/%s.webp" % (item.kind, item.id)
    item.outputs = [(out, _webp(im.convert("RGBA" if alpha else "RGB"), ship_size), ("texture", "CompressedTexture2D", PAINTED_IMPORT))]
    item.record["file"] = out
    item.thumb = _thumb(im)
    item.hues = dominant_hues(im)
    item.facts.append("%dx%d -> %dx%d WebP; hues %s" % (im.size[0], im.size[1], ship_size[0], ship_size[1], item.hues))


def handle_vignette(item, files, z, notes):
    _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    im = _image(item, z, files[0])
    if im is None:
        return
    w, h = im.size
    if (w, h) != VIGNETTE["size"]:
        # §15.7: 21:9 or 16:9 is accepted and cropped to 8:3 around the centre.
        if abs(w / h - 8 / 3) > 0.01 and w / h < 8 / 3:
            nh = round(w * 3 / 8)
            top = (h - nh) // 2
            im = im.crop((0, top, w, top + nh))
            item.warn("%dx%d cropped to 8:3" % (w, h))
        if im.size[0] < VIGNETTE["ship"][0]:
            item.fail("%dx%d is smaller than the %dx%d the game shows" % (im.size[0], im.size[1], *VIGNETTE["ship"]))
            return
    _painted(item, im, VIGNETTE["ship"], False)


def handle_portrait(item, files, z, notes):
    _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    im = _image(item, z, files[0])
    if im is None:
        return
    _check_size(item, im, PORTRAIT["size"])
    im = _cut_out(item, im)
    if not item.fails:
        _painted(item, im, PORTRAIT["ship"], True)


def handle_ship(item, files, z, notes):
    _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    im = _image(item, z, files[0])
    if im is None:
        return
    _check_size(item, im, SHIP["size"])
    im = _cut_out(item, im)
    if item.fails:
        return
    out = "ship/%s.png" % item.id
    # Ships are drawn small on the map and larger in battle: lossless, with mipmaps.
    item.outputs = [(out, _png(im), ("texture", "CompressedTexture2D", {"compress/mode": 0, "mipmaps/generate": True}))]
    item.record["file"] = out
    item.thumb = _thumb(im)
    item.hues = dominant_hues(im)
    item.facts.append("512x512 PNG; hues %s" % item.hues)


def check_svg(item, data, palette):
    """§15.1 rule 7 and §15.2: paths only, fills as attributes, palette colours, no raster,
    filter, text, style or script."""
    try:
        root = ET.fromstring(data)
    except ET.ParseError as e:
        item.fail("not valid SVG (%s)" % e)
        return
    off = set()
    for el in root.iter():
        tag = el.tag.split("}")[-1]
        if tag not in ("svg", "g", "path"):
            item.fail("<%s> is not allowed: paths only" % tag)
        for attr, value in el.attrib.items():
            a = attr.split("}")[-1]
            if a in ("style", "href", "filter", "mask", "clip-path") or a.startswith("on"):
                item.fail("attribute %s is not allowed" % a)
            if a in ("fill", "stroke", "stop-color", "color") and value.lower() not in ("none", "currentcolor"):
                if value.upper() not in palette:
                    off.add(value.upper())
    if off:
        item.warn("colours outside the palette: %s" % ", ".join(sorted(off)))


def handle_art(item, files, z, notes):
    _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    name = pathlib.PurePosixPath(files[0]).name
    if item.id in LOGO_SVGS:
        if not name.endswith(".svg"):
            item.fail("an SVG file is expected")
            return
        data = z.read(files[0])
        check_svg(item, data, _palette())
        out = "art/%s" % name
        # The logo is drawn at several sizes: rasterised at twice its size, with mipmaps.
        item.outputs = [(out, data, ("texture", "CompressedTexture2D", {"compress/mode": 0, "mipmaps/generate": True, "svg/scale": 2.0}))]
        item.record["file"] = out
        root = ET.fromstring(data)
        item.facts.append("SVG %sx%s" % (root.get("width"), root.get("height")))
        return
    spec = ART[item.id]
    im = _image(item, z, files[0])
    if im is None:
        return
    _check_size(item, im, spec["size"])
    if spec["alpha"]:
        im = _cut_out(item, im)
    if not item.fails:
        _painted(item, im, spec["ship"], spec["alpha"])


def handle_store(item, files, z, notes):
    _variant_names(item.id, files, 1, item)
    if item.fails:
        return
    im = _image(item, z, files[0])
    if im is None:
        return
    size, alpha = STORE[item.id]
    _check_size(item, im, size)
    if alpha and not _transparent_border(im):
        item.fail("needs a transparent background")
    out = "store/%s.png" % item.id
    item.outputs = [(out, _png(im), None)]
    item.record["file"] = out
    item.thumb = _thumb(im)
    item.facts.append("%dx%d PNG, kept out of the game's pack" % size)


HANDLERS = {
    "sfx": handle_sfx, "music": handle_music, "vfx": handle_vfx, "vignette": handle_vignette,
    "portrait": handle_portrait, "ship": handle_ship, "art": handle_art, "store": handle_store,
}


# ---------------------------------------------------------------------------------------------
# The repository side: manifest, import settings, credits, reports.

def load_manifest():
    return json.loads(MANIFEST.read_text())


RECORD_ORDER = ["id", "kind", "status", "priority", "optional", "file", "files", "loop", "grid", "fps", "batch"]


def save_manifest(m):
    """Keeps the file's layout: one record per line, fields in a fixed order."""
    lines = ['{', '  "version": %d,' % m["version"], '  "assets": [']
    recs = m["assets"]
    for i, r in enumerate(recs):
        r = {k: r[k] for k in sorted(r, key=lambda k: RECORD_ORDER.index(k) if k in RECORD_ORDER else len(RECORD_ORDER))}
        lines.append("    " + json.dumps(r, ensure_ascii=False) + ("," if i < len(recs) - 1 else ""))
    lines += ["  ]", "}", ""]
    MANIFEST.write_text("\n".join(lines))


def _godot_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return json.dumps(v)
    return repr(v)


def write_import(path, importer, res_type, params):
    """Import settings Godot keeps when it imports the file (it fills in the rest)."""
    lines = ["[remap]", "", 'importer="%s"' % importer, 'type="%s"' % res_type, "", "[params]", ""]
    lines += ["%s=%s" % (k, _godot_value(v)) for k, v in params.items()]
    pathlib.Path(str(path) + ".import").write_text("\n".join(lines) + "\n")


def record_credits(kind, batch, meta, ids, today):
    """One entry per batch under "Outsourced assets"; a re-imported batch replaces its entry."""
    text = CREDITS.read_text()
    head = "## Outsourced assets"
    if head not in text:
        text = text.rstrip("\n") + "\n\n%s\n\nDelivered batches (§15 of `docs/BUILD_PROMPT.md`), ingested by " \
            "`tools/import_assets.py`.\nEach item replaces its code fallback; the files are under " \
            "`assets/delivered/`.\n" % head
    tag = "- **%s batch %s**" % (kind, batch)
    entry = textwrap.fill("%s (%d ids, ingested %s). Licence: %s Source: %s" % (
        tag, len(ids), today, _sentence(meta.get("licence", "")), _sentence(meta.get("source", ""))),
        width=100, subsequent_indent="  ", break_long_words=False, break_on_hyphens=False)
    # Drop this batch's old entry: its first line and the indented lines that continue it.
    lines, skipping = [], False
    for line in text.rstrip("\n").split("\n"):
        if line.startswith(tag + " "):
            skipping = True
            continue
        if skipping and line.startswith("  "):
            continue
        skipping = False
        lines.append(line)
    sep = "\n" if lines and (lines[-1].startswith("- **") or lines[-1].startswith("  ")) else "\n\n"
    CREDITS.write_text("\n".join(lines) + sep + entry + "\n")


def _sentence(s):
    s = " ".join(str(s).split())
    return s if s.endswith(".") else s + "."


def contact_sheet(items, path):
    shown = [i for i in items if i.thumb is not None]
    if not shown:
        return
    cols = min(6, len(shown))
    rows = (len(shown) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 210, rows * 230), (19, 38, 58))
    d = ImageDraw.Draw(sheet)
    for n, it in enumerate(shown):
        x, y = (n % cols) * 210 + 5, (n // cols) * 230 + 5
        sheet.paste(it.thumb, (x + (200 - it.thumb.width) // 2, y + (200 - it.thumb.height) // 2), it.thumb)
        d.text((x, y + 205), "%s %s" % (it.verdict, it.id), fill=(234, 242, 248))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def check_licence(meta):
    lic, src = str(meta.get("licence", "")), str(meta.get("source", ""))
    fails, warns = [], []
    if not lic.strip():
        fails.append("the manifest names no licence")
    elif LICENCE_BANNED.search(lic) or not LICENCE_OK.search(lic):
        fails.append("licence not accepted (§15.1 rule 3): %s" % lic)
    if not src.strip():
        fails.append("the manifest names no source")
    generated = re.search(r"image_gen|generated (using|with|by)|midjourney|stable diffusion|dall-?e", lic + " " + src, re.I)
    if generated and not re.search(r"\bplus\b|\bpro\b|\bteam\b|\benterprise\b|\bplan\b", lic + " " + src, re.I):
        warns.append("generated art, but the plan whose terms allow commercial use is not named (§15.1 rule 3)")
    return fails, warns


def ingest(zip_path, args, index, today):
    """Checks and (unless --check) writes one batch. Returns its items."""
    z = zipfile.ZipFile(zip_path)
    try:
        meta = json.loads(z.read("manifest.json"))
    except (KeyError, json.JSONDecodeError) as e:
        print("FAIL  batch    %-24s no readable manifest.json (%s)" % (zip_path.name, e))
        return []
    kind, batch = meta.get("kind"), meta.get("batch")
    print("\n== %s: %s batch %s" % (zip_path.name, kind, batch))
    if kind not in HANDLERS:
        print("FAIL  batch    %-24s unknown kind %r" % (zip_path.name, kind))
        return []
    if zip_path.name != "sfh_%s_batch%s.zip" % (kind, batch):
        print("WARN  batch    %-24s the zip should be named sfh_%s_batch%s.zip" % (zip_path.name, kind, batch))
    fails, warns = check_licence(meta)
    for w in warns:
        print("WARN  batch    %-24s %s" % (zip_path.name, w))
    if fails:
        for f in fails:
            print("FAIL  batch    %-24s %s" % (zip_path.name, f))
        return []
    groups, notes = {}, {}
    in_zip = set(z.namelist())
    items = []
    for it in meta.get("items", []):
        asset_id, f = str(it.get("id", "")), str(it.get("file", ""))
        if f not in in_zip:
            bad = Item(kind, asset_id)
            bad.fail("%s is not in the zip" % f)
            items.append(bad)
            continue
        groups.setdefault(asset_id, []).append(f)
        notes[asset_id] = " ".join(filter(None, [notes.get(asset_id, ""), str(it.get("notes", ""))]))
    for asset_id, files in groups.items():
        item = Item(kind, asset_id)
        items.append(item)
        rec = index.get(asset_id)
        if rec is None or rec["kind"] != kind:
            item.fail("unknown id: not a %s id in data/asset_manifest.json" % kind)
        elif rec["status"] == "delivered" and not args.replace:
            item.fail("already delivered: run with --replace to overwrite")
        if item.fails:
            print(item.line())
            continue
        HANDLERS[kind](item, files, z, notes.get(asset_id, ""))
        print(item.line())
        if item.fails or args.check:
            continue
        for rel, data, imp in item.outputs:
            dest = DELIVERED / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            if imp:
                write_import(dest, *imp)
        rec = index[asset_id]
        for k in ("file", "files", "loop", "grid", "fps", "batch"):
            rec.pop(k, None)
        rec["status"] = "delivered"
        rec.update(item.record)
        rec["batch"] = int(batch)
    ok = [i.id for i in items if not i.fails]
    if ok and not args.check:
        record_credits(kind, batch, meta, ok, today)
    contact_sheet(items, REPORTS / ("%s_batch%s_contact.png" % (kind, batch)))
    return items


def budget_report():
    """What the delivered files add to the web download, against §9.11."""
    def mb(paths):
        return sum(p.stat().st_size for p in paths) / 1e6
    music = mb((DELIVERED / "music").glob("*.ogg")) if (DELIVERED / "music").exists() else 0.0
    sfx = mb([p for p in (DELIVERED / "sfx").glob("*") if p.suffix in (".wav", ".ogg")]) if (DELIVERED / "sfx").exists() else 0.0
    painted = sum(mb((DELIVERED / k).glob("*.webp")) for k in ("vignette", "portrait", "art") if (DELIVERED / k).exists())
    print("\nBudget (§9.11): music %.1f of %.0f MB; effects %.1f of %.0f MB (before Godot's import); painted art %.1f of %.0f MB (sources; Godot re-encodes)" % (
        music, BUDGET_MB["music"], sfx, BUDGET_MB["sfx"], painted, BUDGET_MB["painted"]))
    return music <= BUDGET_MB["music"] and sfx <= BUDGET_MB["sfx"] and painted <= BUDGET_MB["painted"]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--zip", action="append", required=True, type=pathlib.Path, help="a batch zip (repeatable)")
    ap.add_argument("--check", action="store_true", help="check and report only; write nothing")
    ap.add_argument("--replace", action="store_true", help="overwrite ids already delivered")
    args = ap.parse_args()
    manifest = load_manifest()
    index = {r["id"]: r for r in manifest["assets"]}
    today = datetime.date.today().isoformat()
    every = []
    for zp in args.zip:
        every += ingest(zp, args, index, today)
    if not args.check:
        save_manifest(manifest)
        (DELIVERED / "store").mkdir(parents=True, exist_ok=True)
        (DELIVERED / "store" / ".gdignore").touch()
    counts = {v: sum(1 for i in every if i.verdict == v) for v in ("PASS", "WARN", "FAIL")}
    print("\nimport_assets: %d item(s): %d pass, %d warn, %d fail%s" % (
        len(every), counts["PASS"], counts["WARN"], counts["FAIL"], " (check only: nothing written)" if args.check else ""))
    within = budget_report()
    REPORTS.mkdir(parents=True, exist_ok=True)
    (REPORTS / "last_report.txt").write_text("\n".join(i.line() for i in every) + "\n")
    sys.exit(1 if counts["FAIL"] or not within else 0)


if __name__ == "__main__":
    main()
