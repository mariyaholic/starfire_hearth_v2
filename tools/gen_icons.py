#!/usr/bin/env python3
"""Authoring helper for the Starfire Hearth icon family.
Run from the repository root:  python3 tools/gen_icons.py assets/icons
The SVG files it writes are the committed source; this script only keeps them consistent.
Each icon is a list of (role, element) pairs on a 24x24 grid with 2 px strokes.
Roles:
  shape  closed outline. Outline variant: stroked. Filled variant: filled and stroked.
  knock  detail line. Outline variant: stroked. Filled variant: cut out of the shapes.
  hole   closed detail. Outline variant: stroked. Filled variant: cut out (filled) of the shapes.
  line   stroked in both variants, drawn on top, never cut.
  dot    filled in both variants.
  oline  outline variant only (stroked).
  fdot   filled variant only (filled).
"""
import math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
W = 2

def f(x):
    s = ("%.2f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pts(points):
    return " ".join("%s %s" % (f(x), f(y)) for x, y in points)

def poly(points):
    return 'path', 'd="M%s Z"' % " L".join("%s %s" % (f(x), f(y)) for x, y in points)

def path(d):
    return 'path', 'd="%s"' % d

def circle(cx, cy, r):
    return 'circle', 'cx="%s" cy="%s" r="%s"' % (f(cx), f(cy), f(r))

def ellipse(cx, cy, rx, ry, rot=0):
    t = ' transform="rotate(%s %s %s)"' % (f(rot), f(cx), f(cy)) if rot else ""
    return 'ellipse', 'cx="%s" cy="%s" rx="%s" ry="%s"%s' % (f(cx), f(cy), f(rx), f(ry), t)

def rect(x, y, w, h, r=0):
    return 'rect', 'x="%s" y="%s" width="%s" height="%s" rx="%s"' % (f(x), f(y), f(w), f(h), f(r))

def star(cx, cy, n, r_out, r_in, rot=-90):
    p = []
    for i in range(2 * n):
        a = math.radians(rot + i * 180.0 / n)
        r = r_out if i % 2 == 0 else r_in
        p.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(p)

def gear(cx, cy, teeth, r_out, r_in, tooth_frac=0.45):
    p = []
    step = 360.0 / teeth
    for i in range(teeth):
        a0 = i * step
        half = step * tooth_frac / 2
        for a, r in ((a0 - step / 2 + (step / 2 - half) * 0.2, r_in), (a0 - half, r_out), (a0 + half, r_out), (a0 + step / 2 - (step / 2 - half) * 0.2, r_in)):
            ar = math.radians(a - 90)
            p.append((cx + r * math.cos(ar), cy + r * math.sin(ar)))
    return poly(p)

def sector(cx, cy, r0, r1, a0, a1):
    def pt(r, a):
        ar = math.radians(a)
        return cx + r * math.cos(ar), cy + r * math.sin(ar)
    x0, y0 = pt(r1, a0); x1, y1 = pt(r1, a1); x2, y2 = pt(r0, a1); x3, y3 = pt(r0, a0)
    return path("M%s %s A%s %s 0 0 1 %s %s L%s %s A%s %s 0 0 0 %s %s Z" % (f(x0), f(y0), f(r1), f(r1), f(x1), f(y1), f(x2), f(y2), f(r0), f(r0), f(x3), f(y3)))

def arc(cx, cy, r, a0, a1):
    ar0, ar1 = math.radians(a0), math.radians(a1)
    x0, y0 = cx + r * math.cos(ar0), cy + r * math.sin(ar0)
    x1, y1 = cx + r * math.cos(ar1), cy + r * math.sin(ar1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return path("M%s %s A%s %s 0 %d 1 %s %s" % (f(x0), f(y0), f(r), f(r), large, f(x1), f(y1)))

I = {}

# ---------------------------------------------------------------- resources
I["res_food"] = [("shape", path("M5 19 C5 10.5 10.5 5 19 5 C19 13.5 13.5 19 5 19 Z")), ("knock", path("M5 19 L13.5 10.5"))]
I["res_energy"] = [("shape", poly([(13.5, 3), (5, 13.5), (11, 13.5), (10.5, 21), (19, 10.5), (13, 10.5)]))]
I["res_minerals"] = [("shape", poly([(8, 4), (16, 4), (20.5, 9.5), (12, 20.5), (3.5, 9.5)])), ("knock", path("M3.5 9.5 H20.5")), ("knock", path("M9.5 9.5 L12 20.5 L14.5 9.5"))]
I["res_alloys"] = [("shape", poly([(3, 20), (5.5, 15), (18.5, 15), (21, 20)])), ("shape", poly([(6.5, 11.5), (9, 6.5), (15, 6.5), (17.5, 11.5)]))]
I["res_research"] = [("shape", path("M10 3.5 V9 L4.6 18.4 A1.8 1.8 0 0 0 6.2 21 H17.8 A1.8 1.8 0 0 0 19.4 18.4 L14 9 V3.5 Z")), ("line", path("M8.5 3.5 H15.5")), ("knock", path("M7.2 15 H16.8"))]
I["res_influence"] = [("shape", circle(12, 9.5, 6)), ("shape", poly([(8.4, 14.2), (6.8, 21), (12, 18.6), (17.2, 21), (15.6, 14.2)])), ("hole", circle(12, 9.5, 2.2))]

# ---------------------------------------------------------------- research branches
I["branch_physics"] = [("line", ellipse(12, 12, 9.5, 3.8, 0)), ("line", ellipse(12, 12, 9.5, 3.8, 60)), ("line", ellipse(12, 12, 9.5, 3.8, -60)), ("dot", circle(12, 12, 2))]
I["branch_society"] = [("shape", circle(9, 8, 3.2)), ("shape", path("M3 20 C3 15.6 5.7 13.3 9 13.3 C12.3 13.3 15 15.6 15 20 Z")), ("line", path("M15.2 5.2 A3 3 0 0 1 15.2 10.8")), ("line", path("M17.2 13.6 C19.5 14.4 21 16.6 21 20"))]
I["branch_engineering"] = [("shape", gear(12, 12, 8, 9.2, 7)), ("hole", circle(12, 12, 3))]

# ---------------------------------------------------------------- districts
I["district_habitation"] = [("shape", poly([(4, 11), (12, 4), (20, 11), (20, 20.5), (4, 20.5)])), ("knock", path("M10 20.5 V15 H14 V20.5"))]
wheat = [("line", path("M12 21 V7.5"))]
for y in (9.2, 13.2, 17.2):
    wheat.append(("shape", ellipse(9.3, y, 1.7, 2.9, -38)))
    wheat.append(("shape", ellipse(14.7, y, 1.7, 2.9, 38)))
wheat.append(("shape", ellipse(12, 4.6, 1.6, 2.4, 0)))
I["district_agriculture"] = wheat
I["district_energy"] = [("line", path("M12 11 V21")), ("line", path("M8.5 21 H15.5")), ("shape", path("M12 9 C11 6.5 11 4 12 2.8 C13 4 13 6.5 12 9 Z")), ("shape", path("M12 9 C14.5 9.6 16.8 10.8 17.6 12.4 C15.9 12.8 13.8 11.4 12 9 Z")), ("shape", path("M12 9 C9.5 9.6 7.2 10.8 6.4 12.4 C8.1 12.8 10.2 11.4 12 9 Z")), ("dot", circle(12, 9, 1.6))]
I["district_mining"] = [("shape", poly([(3, 8), (21, 8), (18.8, 15.5), (5.2, 15.5)])), ("shape", circle(8, 19, 1.9)), ("shape", circle(16, 19, 1.9)), ("knock", path("M8 11.5 H16"))]
I["district_industry"] = [("shape", poly([(3, 20.5), (3, 11), (8, 14), (8, 11), (13, 14), (13, 11), (17, 13.4), (17, 4), (20.5, 4), (20.5, 20.5)])), ("knock", path("M6.5 17.5 H8.5 M11 17.5 H13"))]
I["district_research"] = [("shape", path("M4 20.5 V14 A8 8 0 0 1 20 14 V20.5 Z")), ("knock", path("M12 6.5 V13")), ("line", path("M2.5 20.5 H21.5"))]

# ---------------------------------------------------------------- planet types
P = circle(12, 12, 9)
I["planet_continental"] = [("shape", P), ("hole", path("M6.4 8.6 C8 6.6 10.6 6.4 11.8 8 C12.8 9.4 11.6 11.2 9.8 11.6 C8.4 12 8.6 13.8 7 13.6 C5.6 13.4 5.2 10.2 6.4 8.6 Z")), ("hole", path("M13.6 13.2 C15 12 17.6 12.2 18 14 C18.4 15.8 16.8 17.8 14.8 17.8 C13.2 17.8 12.4 14.4 13.6 13.2 Z"))]
I["planet_ocean"] = [("shape", P), ("knock", path("M5.5 10.5 Q7.8 8.8 10 10.5 T14.4 10.5 T18.6 10.5")), ("knock", path("M5.8 14.8 Q8 13.1 10.2 14.8 T14.6 14.8 T18.2 14.8"))]
I["planet_arid"] = [("shape", P), ("knock", path("M8 4.6 L9.8 9.6 L5.2 12.4 M9.8 9.6 L15 10.8 L17.8 6.4 M15 10.8 L14.2 16 L8.6 17.6 M14.2 16 L19.6 15"))]
I["planet_ice"] = [("shape", P), ("knock", path("M12 6.5 V17.5 M7.24 9.25 L16.76 14.75 M7.24 14.75 L16.76 9.25"))]
I["planet_barren"] = [("shape", P), ("hole", circle(9, 9.2, 2.2)), ("hole", circle(15.2, 13.6, 2.6)), ("hole", circle(9.6, 16, 1.2))]
def drop(cx, cy, h):
    w = h * 0.62
    return path("M%s %s C%s %s %s %s %s %s A%s %s 0 1 1 %s %s C%s %s %s %s %s %s Z" % (f(cx), f(cy - h), f(cx + w * 0.3), f(cy - h * 0.55), f(cx + w), f(cy - h * 0.25), f(cx + w), f(cy + h * 0.15), f(w), f(w), f(cx - w), f(cy + h * 0.15), f(cx - w), f(cy - h * 0.25), f(cx - w * 0.3), f(cy - h * 0.55), f(cx), f(cy - h)))
I["planet_toxic"] = [("shape", P), ("hole", drop(8.4, 10, 3.4)), ("hole", drop(15.2, 9, 2.6)), ("hole", drop(13, 15.8, 2.8))]
I["planet_gas_giant"] = [("shape", circle(12, 12, 6.8)), ("knock", path("M6 11.5 H18")), ("line", ellipse(12, 12, 10.6, 3.4, -18))]
I["planet_asteroid_belt"] = [("dot", poly([(3.2, 16.2), (5.2, 13.6), (7.6, 14.4), (7.6, 17.4), (5, 18.6)])), ("dot", poly([(9, 10.6), (11.8, 8.8), (14, 10.4), (13.2, 13.4), (10, 13.4)])), ("dot", circle(17.2, 7.6, 2)), ("dot", circle(20.2, 4.4, 1.2)), ("dot", circle(15.2, 15, 1.5)), ("dot", circle(10.2, 18.4, 1.3))]

# ---------------------------------------------------------------- traits
I["trait_fertile"] = [("shape", path("M3 20.5 Q12 12.5 21 20.5 Z")), ("line", path("M12 16.5 V10")), ("shape", path("M12 12 C12 8.2 14.8 5.6 18.6 5.6 C18.6 9.4 15.8 12 12 12 Z")), ("shape", path("M12 10.6 C12 7.8 9.9 6 7 6 C7 8.8 9.1 10.6 12 10.6 Z"))]
I["trait_veins"] = [("shape", poly([(4, 16), (6.8, 7), (13.6, 3.8), (20, 8.8), (19.2, 18), (10, 20.4)])), ("knock", path("M6.8 10.6 L11 12.4 L10 15.6 L15.6 16.6 M11 12.4 L15.4 9.4"))]
I["trait_geothermal"] = [("line", path("M3.5 20.5 H20.5")), ("line", path("M7 17 C5.5 15 8.5 13.5 7 11.5 C5.5 9.5 8.5 8 7 6")), ("line", path("M12 17 C10.5 14.5 13.5 12.5 12 10 C10.5 7.5 13.5 5.5 12 3.5")), ("line", path("M17 17 C15.5 15 18.5 13.5 17 11.5 C15.5 9.5 18.5 8 17 6"))]
I["trait_locked"] = [("oline", P), ("dot", path("M12 3 A9 9 0 0 0 12 21 Z")), ("fdot", path("M12 3 A9 9 0 0 0 12 21 Z")), ("line", path("M12 3 A9 9 0 0 1 12 21"))]
I["trait_toxic"] = [("shape", path("M7.2 15.5 A4 4 0 0 1 7.6 7.6 A5.2 5.2 0 0 1 17.2 8.2 A3.7 3.7 0 0 1 16.8 15.5 Z")), ("line", path("M8.5 18.2 L7.7 20.4 M12.5 18.2 L11.7 20.4 M16.5 18.2 L15.7 20.4"))]
I["trait_low_gravity"] = [("shape", path("M20 4 C12.4 4 7.2 9 7.2 16 L7.2 16.8 L8 16.8 C15 16.8 20 11.6 20 4 Z")), ("line", path("M4 20 L14.5 9.5")), ("knock", path("M10.4 13.6 H14.6 M12.4 11.6 H17"))]
I["trait_ruins"] = [("line", path("M3 20.5 H21")), ("shape", rect(5, 9.5, 4, 11, 0.5)), ("shape", rect(15, 13, 4, 7.5, 0.5)), ("shape", poly([(4, 8), (4.8, 5.4), (13, 5.4), (11.6, 8)])), ("line", path("M15.4 5.4 L18.6 5.4 L20 8"))]
I["trait_radiation"] = [("dot", circle(12, 12, 2)), ("shape", sector(12, 12, 4, 9, -120, -60)), ("shape", sector(12, 12, 4, 9, 0, 60)), ("shape", sector(12, 12, 4, 9, 120, 180))]

# ---------------------------------------------------------------- faction emblems
hexp = [(12 + 9.6 * math.cos(math.radians(a)), 12 + 9.6 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
I["emblem_hearth"] = [("shape", poly(hexp)), ("hole", path("M12 6.4 C12.6 8.8 15.8 10.2 15.8 13.6 A3.8 3.8 0 0 1 8.2 13.6 C8.2 11.6 9.4 10.6 10.2 9.6 C10.4 11 11 11.6 11.6 11.8 C11.2 10 11.2 8 12 6.4 Z"))]
I["emblem_compass"] = [("shape", star(12, 12, 4, 10, 2.6)), ("oline", circle(12, 12, 6.2)), ("line", path("M12 12 L12 12"))]
spiral = []
for i in range(7):
    a = math.radians(180 + i * 58)
    r = 1.4 + i * 1.2
    spiral.append(("dot", circle(12 + r * math.cos(a), 12 + r * math.sin(a), 0.8 + i * 0.25)))
I["emblem_spiral"] = spiral
I["emblem_broken_circle"] = [("line", arc(11.2, 12.8, 8, -40, 245)), ("line", arc(13.6, 10.2, 8, 262, 298))]

# ---------------------------------------------------------------- fleet stances
SHIELD = "M12 3 L19.5 6 V11.2 C19.5 15.9 16.4 19.4 12 21 C7.6 19.4 4.5 15.9 4.5 11.2 V6 Z"
I["stance_cautious"] = [("shape", path(SHIELD)), ("knock", path("M12 6.4 V17.6"))]
I["stance_balanced"] = [("shape", path("M9.5 7.5 L15 9.6 V13 C15 16.3 12.8 18.7 9.5 20 C6.2 18.7 4 16.3 4 13 V9.6 Z")), ("line", path("M11.5 12.5 L20.5 3.5 M18 3.5 H20.5 V6 M13.2 8.8 L15.2 10.8"))]
I["stance_aggressive"] = [("line", path("M4.5 19.5 L17.5 6.5 M15 4 H20 V9 M6.5 14.5 L9.5 17.5")), ("line", path("M19.5 19.5 L6.5 6.5 M9 4 H4 V9 M17.5 14.5 L14.5 17.5"))]
I["stance_last_stand"] = [("shape", poly([(6, 21), (6, 9), (4.5, 9), (4.5, 4), (7.5, 4), (7.5, 6.2), (10.5, 6.2), (10.5, 4), (13.5, 4), (13.5, 6.2), (16.5, 6.2), (16.5, 4), (19.5, 4), (19.5, 9), (18, 9), (18, 21)])), ("knock", path("M10.5 21 V16.5 A1.5 1.5 0 0 1 13.5 16.5 V21"))]

# ---------------------------------------------------------------- alerts
I["alert_info"] = [("shape", circle(12, 12, 9)), ("knock", path("M12 11 V16.5")), ("hole", circle(12, 7.6, 0.4))]
I["alert_warning"] = [("shape", path("M10.3 4.2 A2 2 0 0 1 13.7 4.2 L21 17.4 A2 2 0 0 1 19.3 20.4 H4.7 A2 2 0 0 1 3 17.4 Z")), ("knock", path("M12 9 V13.6")), ("hole", circle(12, 16.8, 0.4))]
octo = [(12 + 9.4 * math.cos(math.radians(a)), 12 + 9.4 * math.sin(math.radians(a))) for a in range(-112, 248, 45)]
I["alert_critical"] = [("shape", poly([(round(x, 2), round(y, 2)) for x, y in [(12 + 9.4 * math.cos(math.radians(22.5 + i * 45)), 12 + 9.4 * math.sin(math.radians(22.5 + i * 45))) for i in range(8)]])), ("knock", path("M12 7.4 V12.6")), ("hole", circle(12, 16.2, 0.4))]
I["alert_success"] = [("shape", circle(12, 12, 9)), ("knock", path("M7.8 12.4 L10.6 15.2 L16.4 9.2"))]

# ---------------------------------------------------------------- treaties
I["treaty_nap"] = [("shape", path(SHIELD)), ("knock", path("M12 6.6 V15.2 M9.8 13 L14.2 13 M12 15.2 L12 17.4"))]
I["treaty_trade"] = [("line", path("M4 8 H18.5 M15 4.5 L18.5 8 L15 11.5")), ("line", path("M20 16 H5.5 M9 12.5 L5.5 16 L9 19.5"))]
I["treaty_research"] = [("shape", path("M12 6 C9.6 4.6 6.6 4.1 3 4.6 V19 C6.6 18.5 9.6 19 12 20.4 C14.4 19 17.4 18.5 21 19 V4.6 C17.4 4.1 14.4 4.6 12 6 Z")), ("knock", path("M12 6 V20.4"))]
I["treaty_open_borders"] = [("line", path("M12 3 V5.5 M12 8.5 V9.5 M12 14.5 V15.5 M12 18.5 V21")), ("line", path("M3.5 12 H19.5 M16 8.5 L19.5 12 L16 15.5"))]
peace = [("line", path("M4 20.5 C7 17.5 11 12 19.5 4.5"))]
for (x, y, ang) in ((7.4, 17.1, -80), (10.3, 13.9, 10), (12.9, 11.1, -80), (15.6, 8.4, 10), (18.3, 5.8, -35)):
    peace.append(("shape", ellipse(x + 2.3 * math.cos(math.radians(ang)), y + 2.3 * math.sin(math.radians(ang)), 2.5, 1.35, ang)))
I["treaty_peace"] = peace

# ---------------------------------------------------------------- damage types
I["dmg_kinetic"] = [("shape", path("M8 8.5 H16.5 C19 8.5 21 10.1 21 12 C21 13.9 19 15.5 16.5 15.5 H8 Z")), ("line", path("M3 9.5 H5 M2.5 12 H5 M3 14.5 H5"))]
I["dmg_thermal"] = [("line", path("M7 20 C5 17.5 9 15 7 12.5 C5 10 9 7.5 7 5")), ("line", path("M12 20 C10 17.5 14 15 12 12.5 C10 10 14 7.5 12 5")), ("line", path("M17 20 C15 17.5 19 15 17 12.5 C15 10 19 7.5 17 5"))]
I["dmg_explosive"] = [("shape", star(12, 12, 8, 9.6, 5.2, -90))]

# ---------------------------------------------------------------- stats
I["stat_stability"] = [("line", circle(12, 5.2, 2)), ("line", path("M12 7.2 V20.5 M8 11 H16")), ("line", path("M4.8 14 C5.4 18 8.4 20.5 12 20.5 C15.6 20.5 18.6 18 19.2 14 M3.4 15.8 L4.8 14 L6.8 15.2 M20.6 15.8 L19.2 14 L17.2 15.2"))]
I["stat_pops"] = [("shape", circle(12, 7.5, 3.6)), ("shape", path("M4.5 20.5 C4.5 15.6 7.8 13 12 13 C16.2 13 19.5 15.6 19.5 20.5 Z"))]
I["stat_housing"] = [("line", path("M3 19.5 V6 M3 15 H21 V19.5")), ("shape", rect(10, 10, 11, 5, 1.2)), ("shape", circle(6.6, 11.6, 1.9))]
I["stat_noise"] = [("line", path("M2.5 12 H5.5 L7.5 6 L10.5 18.5 L13 8.5 L15 14.5 L16.8 12 H21.5"))]
I["stat_growth"] = [("line", path("M3 17.5 L9 11.5 L13 15.5 L20.5 8")), ("line", path("M15 8 H20.5 V13.5"))]

# ---------------------------------------------------------------- ships
I["ship_survey"] = [("shape", path("M5.4 7.8 A7 7 0 0 0 15.4 17.8 Z")), ("line", path("M10.4 12.8 L14.6 8.6")), ("dot", circle(15.4, 7.8, 1.6)), ("line", path("M17.6 3.6 A4.6 4.6 0 0 1 19.6 5.6 M17.4 1.4 A7.6 7.6 0 0 1 21.8 5.8"))]
I["ship_construction"] = [("shape", path("M14.8 3.4 A5 5 0 0 0 10.3 10.3 L3.8 16.8 A2.2 2.2 0 0 0 7 20 L13.5 13.5 A5 5 0 0 0 20.4 9 L17.2 12 L13.6 10.2 L12 6.6 Z"))]
I["ship_colony"] = [("shape", path("M3.5 12 C3.5 8.4 7.4 6.5 12 6.5 H17.5 L21 12 L17.5 17.5 H12 C7.4 17.5 3.5 15.6 3.5 12 Z")), ("hole", circle(9, 12, 1.1)), ("hole", circle(13, 12, 1.1)), ("hole", circle(17, 12, 1.1))]
I["ship_fleet"] = [("shape", poly([(12, 3), (20, 20.5), (12, 16), (4, 20.5)]))]
I["ship_starbase"] = [("shape", rect(2.5, 7.5, 5.5, 9, 0.8)), ("shape", rect(16, 7.5, 5.5, 9, 0.8)), ("knock", path("M5.25 7.5 V16.5 M18.75 7.5 V16.5")), ("line", path("M8 12 H16")), ("shape", circle(12, 12, 3)), ("line", path("M12 9 V4.5"))]

# ---------------------------------------------------------------- map
I["map_beacon"] = [("shape", poly([(9.2, 21), (11.2, 11.5), (12.8, 11.5), (14.8, 21)])), ("dot", circle(12, 9, 2)), ("line", path("M8.2 5.6 A5 5 0 0 0 8.2 12.4 M15.8 5.6 A5 5 0 0 1 15.8 12.4")), ("line", path("M5.2 3 A8.6 8.6 0 0 0 5.2 15 M18.8 3 A8.6 8.6 0 0 1 18.8 15"))]
I["map_outpost"] = [("line", path("M7 21 V3.5")), ("shape", poly([(7, 4), (18.5, 4), (16, 8), (18.5, 12), (7, 12)])), ("line", path("M3.5 21 H13.5"))]
I["map_anomaly"] = [("shape", poly([(12, 2.8), (21.2, 12), (12, 21.2), (2.8, 12)])), ("knock", path("M9.6 10 A2.4 2.4 0 1 1 13.2 12.1 C12.4 12.6 12 13.1 12 14")), ("hole", circle(12, 16.8, 0.4))]

# ---------------------------------------------------------------- UI
I["ui_menu"] = [("line", path("M4 6.5 H20 M4 12 H20 M4 17.5 H20"))]
I["ui_settings"] = [("line", path("M4 7 H20 M4 12 H20 M4 17 H20")), ("dot", circle(15, 7, 2.4)), ("dot", circle(8.5, 12, 2.4)), ("dot", circle(13, 17, 2.4))]
I["ui_close"] = [("line", path("M6 6 L18 18 M18 6 L6 18"))]
I["ui_back"] = [("line", path("M20 12 H4.5 M10.5 6 L4.5 12 L10.5 18"))]
I["ui_search"] = [("shape", circle(10.5, 10.5, 6)), ("line", path("M15 15 L20.5 20.5")), ("knock", path("M8 9 A3 3 0 0 1 10.5 7.5"))]
I["ui_undo"] = [("line", path("M9 5 L4.5 9.5 L9 14 M4.5 9.5 H14 A5.5 5.5 0 0 1 14 20.5 H9"))]
I["ui_pin"] = [("shape", path("M9 3.5 H15 L14 9 L17.5 13 H6.5 L10 9 Z")), ("line", path("M12 13 V21"))]
I["ui_why"] = [("shape", circle(12, 12, 9)), ("knock", path("M9.4 9.6 A2.6 2.6 0 1 1 13.3 11.9 C12.5 12.4 12 13 12 14")), ("hole", circle(12, 17, 0.4))]
I["ui_end_turn"] = [("shape", poly([(5, 5), (15.5, 12), (5, 19)])), ("shape", rect(17.5, 5, 2, 14, 0.6))]
I["ui_codex"] = [("shape", path("M5 4.5 A1.5 1.5 0 0 1 6.5 3 H19 V18 H6.5 A1.5 1.5 0 0 0 5 19.5 Z")), ("line", path("M5 19.5 A1.5 1.5 0 0 0 6.5 21 H19 V18")), ("knock", path("M13 3 V9.5 L15 8 L17 9.5 V3"))]
I["ui_report"] = [("shape", rect(5, 4.5, 14, 16.5, 1.8)), ("line", rect(9, 2.8, 6, 3.4, 1)), ("knock", path("M8.5 10.5 H15.5 M8.5 14 H15.5 M8.5 17.5 H12.5"))]
I["ui_lock"] = [("shape", rect(4.5, 10.5, 15, 10.5, 2)), ("line", path("M8 10.5 V7.5 A4 4 0 0 1 16 7.5 V10.5")), ("knock", path("M12 14.5 V17"))]
I["ui_check"] = [("line", path("M5 12.5 L9.8 17.2 L19 7.2"))]
I["ui_chevron_right"] = [("line", path("M9 5 L16 12 L9 19"))]
I["ui_plus"] = [("line", path("M12 5 V19 M5 12 H19"))]
I["ui_minus"] = [("line", path("M5 12 H19"))]
I["ui_diplomacy"] = [("shape", path("M3.5 5.5 A1.5 1.5 0 0 1 5 4 H14 A1.5 1.5 0 0 1 15.5 5.5 V11.5 A1.5 1.5 0 0 1 14 13 H8.5 L5 16 V13 A1.5 1.5 0 0 1 3.5 11.5 Z")), ("line", path("M18.5 8.5 H19 A1.5 1.5 0 0 1 20.5 10 V16 A1.5 1.5 0 0 1 19 17.5 V20 L15.5 17.5 H11 A1.5 1.5 0 0 1 9.5 16 V15.8"))]
I["ui_save"] = [("line", path("M12 3.5 V14 M7.5 9.5 L12 14 L16.5 9.5")), ("line", path("M4 14.5 V19 A1.5 1.5 0 0 0 5.5 20.5 H18.5 A1.5 1.5 0 0 0 20 19 V14.5"))]
I["ui_event"] = [("shape", path("M6 3.5 H16 A2 2 0 0 1 18 5.5 V18.5 A2 2 0 0 0 20 20.5 H8 A2 2 0 0 1 6 18.5 Z")), ("knock", path("M9.5 8 H14.5 M9.5 11.5 H14.5 M9.5 15 H12.5"))]
I["ui_governor"] = [("line", circle(12, 12, 6.2)), ("dot", circle(12, 12, 2)), ("line", path("M12 2.6 V21.4 M2.6 12 H21.4 M5.4 5.4 L18.6 18.6 M18.6 5.4 L5.4 18.6"))]
I["ui_edict"] = [("shape", poly([(9.2, 3.5), (15.8, 10.1), (13, 12.9), (6.4, 6.3)])), ("line", path("M13 9.1 L20.5 16.6")), ("line", path("M3.5 20.5 H13.5"))]
I["ui_colony"] = [("shape", circle(12, 12, 9)), ("hole", poly([(12, 7), (16.2, 10.4), (16.2, 16), (7.8, 16), (7.8, 10.4)]))]
I["ui_fleet_move"] = [("line", path("M4 18 C8 18 9 6 13 6 H20 M16.5 2.5 L20 6 L16.5 9.5")), ("dot", circle(4.5, 18, 2))]

# ---------------------------------------------------------------- buildings (M1)
I["bld_ark_hull"] = [("shape", path("M9 20.5 V8.5 C9 5.4 10.4 3 12 3 C13.6 3 15 5.4 15 8.5 V20.5 Z")), ("knock", path("M12 8 V13")), ("line", path("M4.5 20.5 H19.5")), ("line", path("M9 16 L6.5 18.5 M15 16 L17.5 18.5"))]
I["bld_storehouse"] = [("shape", rect(3.5, 6, 17, 14.5, 1.5)), ("knock", path("M3.5 10.5 H20.5")), ("knock", path("M10 14 H14"))]
I["bld_hydroponics_bay"] = [("shape", poly([(3, 15), (21, 15), (19, 20.5), (5, 20.5)])), ("line", path("M12 15 V10")), ("shape", path("M12 11 C12 7 14.8 4.4 18.6 4.4 C18.6 8.4 15.8 11 12 11 Z")), ("shape", path("M12 10 C12 7.4 10 5.6 7.2 5.6 C7.2 8.2 9.2 10 12 10 Z"))]
I["bld_fusion_plant"] = [("shape", circle(12, 12, 3.6)), ("line", ellipse(12, 12, 9.6, 3.6, 30)), ("line", ellipse(12, 12, 9.6, 3.6, -30))]
I["bld_foundry"] = [("shape", poly([(4.5, 5.5), (16.5, 5.5), (14.5, 13.5), (6.5, 13.5)])), ("line", path("M16 9.5 C19 10.5 19.6 13.6 19 18")), ("line", path("M3.5 20.5 H20.5")), ("line", path("M10.5 13.5 V17"))]
I["bld_research_institute"] = [("shape", path("M4 20.5 V11 H20 V20.5 Z")), ("shape", path("M7 11 A5 5 0 0 1 17 11 Z")), ("knock", path("M8 13.5 V18.5 M12 13.5 V18.5 M16 13.5 V18.5"))]
I["bld_civic_hall"] = [("shape", poly([(3, 9.5), (12, 3.5), (21, 9.5)])), ("shape", rect(3.5, 18.5, 17, 2.2, 0.5)), ("line", path("M7 11.8 V16.5 M12 11.8 V16.5 M17 11.8 V16.5"))]
I["bld_park_commons"] = [("shape", circle(12, 9, 6)), ("line", path("M12 15 V20.5")), ("line", path("M5 20.5 H19")), ("knock", path("M12 12.5 L14.2 10.3"))]
I["bld_clinic"] = [("shape", circle(12, 12, 9)), ("knock", path("M12 7.5 V16.5 M7.5 12 H16.5"))]
I["bld_spaceport"] = [("shape", path("M12 3 C14.5 5 15 8.5 15 12 V16 H9 V12 C9 8.5 9.5 5 12 3 Z")), ("hole", circle(12, 9, 1.3)), ("line", path("M9 13 L6.5 16 V18 M15 13 L17.5 16 V18")), ("line", path("M4 20.5 H20"))]
I["bld_planetary_shield"] = [("shape", path("M6 20.5 A6 6 0 0 1 18 20.5 Z")), ("line", path("M2.5 20.5 A9.5 9.5 0 0 1 21.5 20.5")), ("line", path("M8 9.6 L12 7.4 L16 9.6"))]
I["bld_market_exchange"] = [("line", path("M12 4 V20 M7 20.5 H17 M5 7 H19")), ("shape", poly([(5, 7), (2.5, 12.5), (7.5, 12.5)])), ("shape", poly([(19, 7), (16.5, 12.5), (21.5, 12.5)]))]
I["bld_archive_of_sol"] = [("shape", rect(6, 3.5, 12, 17, 2)), ("knock", path("M6 8 H18 M6 16 H18")), ("hole", circle(12, 12, 1.8))]
I["bld_listening_post"] = [("shape", path("M4 9 A8 8 0 0 0 15 20 Z")), ("line", path("M9.5 14.5 L16 8")), ("dot", circle(16.8, 7.2, 1.5)), ("line", path("M15 20.5 H20.5 M17.8 20.5 V17"))]
I["bld_habitat_dome"] = [("shape", path("M3 19 A9 9 0 0 1 21 19 Z")), ("line", path("M2 20.5 H22")), ("knock", path("M12 10.2 V19 M7.2 12.6 C8.6 14.6 9 17 9 19 M16.8 12.6 C15.4 14.6 15 17 15 19"))]

# ---------------------------------------------------------------- UI (M1)
I["ui_play"] = [("shape", poly([(7, 4.5), (19, 12), (7, 19.5)]))]
I["ui_upgrade"] = [("line", path("M12 18 V5 M6.5 10.5 L12 5 L17.5 10.5")), ("line", path("M6 20.5 H18"))]
I["ui_demolish"] = [("shape", path("M6 7.5 H18 L17 20.5 H7 Z")), ("line", path("M4 7.5 H20 M9.5 4 H14.5")), ("knock", path("M10 10.5 V17 M14 10.5 V17"))]
I["ui_objective"] = [("line", circle(12, 12, 9)), ("line", circle(12, 12, 5)), ("dot", circle(12, 12, 1.7))]
I["ui_advisor"] = [("shape", path("M8 20.5 H16 L15 15.5 H9 Z")), ("shape", path("M9 15.5 C7.5 12.5 8.4 7.6 12 5.4 C15.6 7.6 16.5 12.5 15 15.5 Z")), ("line", path("M12 2.8 V5.4")), ("hole", path("M12 9.2 C13.2 10.6 13.2 12.2 12 13 C10.8 12.2 10.8 10.6 12 9.2 Z"))]
I["ui_legacy"] = [("shape", star(12, 9.5, 5, 6.6, 2.8)), ("line", path("M9 15 L7.5 21 L12 18.8 L16.5 21 L15 15"))]
I["ui_queue"] = [("line", path("M9 6.5 H20.5 M9 12 H20.5 M9 17.5 H20.5")), ("dot", circle(4.8, 6.5, 1.5)), ("dot", circle(4.8, 12, 1.5)), ("dot", circle(4.8, 17.5, 1.5))]
I["ui_reroll"] = [("line", path("M19.5 12 A7.5 7.5 0 1 1 17.3 6.7")), ("line", path("M18 2.8 L17.6 7 L13.4 7.2"))]
I["ui_tree"] = [("shape", circle(6, 12, 2.6)), ("shape", circle(18, 6, 2.6)), ("shape", circle(18, 18, 2.6)), ("line", path("M8.4 11 L15.6 7 M8.4 13 L15.6 17"))]
I["ui_sound"] = [("shape", poly([(3.5, 9), (7.5, 9), (12.5, 4.5), (12.5, 19.5), (7.5, 15), (3.5, 15)])), ("line", path("M15.5 9 A4 4 0 0 1 15.5 15 M18 6.5 A7.5 7.5 0 0 1 18 17.5"))]
I["ui_star"] = [("shape", star(12, 12, 5, 9.4, 4))]
I["ui_load"] = [("shape", path("M3 6.5 A1.5 1.5 0 0 1 4.5 5 H9.5 L11.5 7 H19.5 A1.5 1.5 0 0 1 21 8.5 V18.5 A1.5 1.5 0 0 1 19.5 20 H4.5 A1.5 1.5 0 0 1 3 18.5 Z")), ("knock", path("M3 10.5 H21"))]
I["ui_checkpoint"] = [("shape", path("M7 3.5 H17 V20.5 L12 16.6 L7 20.5 Z"))]
I["ui_display"] = [("shape", rect(3, 4.5, 18, 12, 1.5)), ("line", path("M9 20.5 H15 M12 16.5 V20.5"))]
I["ui_accessibility"] = [("shape", circle(12, 4.8, 1.9)), ("line", path("M5 8.8 L12 10.2 L19 8.8 M12 10.2 V14.2 L8.6 20.6 M12 14.2 L15.4 20.6"))]

def render(name, spec, filled):
    body = []
    mask = []
    if filled:
        for role, (tag, attrs) in spec:
            if role in ("knock",):
                mask.append('<%s %s fill="none" stroke="#000" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (tag, attrs, W))
            elif role == "hole":
                mask.append('<%s %s fill="#000" stroke="#000" stroke-width="1"/>' % (tag, attrs))
        shapes = []
        tops = []
        for role, (tag, attrs) in spec:
            if role == "shape":
                shapes.append('<%s %s fill="#fff" stroke="#fff" stroke-width="%s" stroke-linejoin="round"/>' % (tag, attrs, W))
            elif role in ("dot", "fdot"):
                tops.append('<%s %s fill="#fff"/>' % (tag, attrs))
            elif role == "line":
                tops.append('<%s %s fill="none" stroke="#fff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (tag, attrs, W))
        if mask:
            body.append('<defs><mask id="k" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24"><rect width="24" height="24" fill="#fff"/>%s</mask></defs>' % "".join(mask))
            body.append('<g mask="url(#k)">%s</g>' % "".join(shapes))
        else:
            body.extend(shapes)
        body.extend(tops)
    else:
        strokes = []
        dots = []
        for role, (tag, attrs) in spec:
            if role in ("shape", "knock", "hole", "line", "oline"):
                strokes.append('<%s %s/>' % (tag, attrs))
            elif role == "dot":
                dots.append('<%s %s fill="#fff"/>' % (tag, attrs))
        body.append('<g fill="none" stroke="#fff" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</g>' % (W, "".join(strokes)))
        body.extend(dots)
    return '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>\n' % "".join(body)

os.makedirs(OUT, exist_ok=True)
for name, spec in I.items():
    for filled in (True, False):
        fn = name + ("" if filled else "_outline") + ".svg"
        with open(os.path.join(OUT, fn), "w") as fh:
            fh.write(render(name, spec, filled))
        with open(os.path.join(OUT, fn + ".import"), "w") as fh:
            fh.write('[remap]\n\nimporter="keep"\n')
print(len(I), "icons,", 2 * len(I), "svg files")
