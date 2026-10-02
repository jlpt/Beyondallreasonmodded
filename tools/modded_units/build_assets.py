"""Builds the S3O models, textures and build pictures for the Sukuna and Steve units.

Run from the repository root:  python3 tools/modded_units/build_assets.py
Requires numpy and Pillow. Source models live in tools/modded_units/source (CC-BY-4.0, see CREDITS.md).
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import s3o  # noqa: E402
from gltfload import load  # noqa: E402
from raster import render  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "source")
OBJ_DIR = os.path.join(ROOT, "objects3d", "Modded")
TEX_DIR = os.path.join(ROOT, "unittextures")
PIC_DIR = os.path.join(ROOT, "unitpics", "modded")
TEAM_RGB = np.array([0.15, 0.35, 0.95])  # team colour used for the build pictures


# ---------------------------------------------------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------------------------------------------------


def write_dds(path, img):
    """Uncompressed A8R8G8B8 DDS with a full mip chain, the same layout the existing unitpics use."""
    img = img.convert("RGBA")
    w, h = img.size
    levels = []
    lw, lh, cur = w, h, img
    while True:
        levels.append(cur)
        if lw == 1 and lh == 1:
            break
        lw, lh = max(1, lw // 2), max(1, lh // 2)
        cur = cur.resize((lw, lh), Image.LANCZOS)
    header = struct.pack(
        "<4sIIIIIII44xII4sIIIIIIIIII",
        b"DDS ",
        124,
        0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x8,  # caps, height, width, pixelformat, mipmapcount, pitch
        h,
        w,
        w * 4,
        0,
        len(levels),
        32,
        0x1 | 0x40,  # alphapixels | rgb
        b"\0\0\0\0",
        32,
        0x00FF0000,
        0x0000FF00,
        0x000000FF,
        0xFF000000,
        0x1000 | 0x8 | 0x400000,  # texture | complex | mipmap
        0,
        0,
        0,
        0,
    )
    with open(path, "wb") as f:
        f.write(header)
        for lv in levels:
            r, g, b, a = lv.split()
            f.write(Image.merge("RGBA", (b, g, r, a)).tobytes())


def save_png(img, name):
    img.save(os.path.join(TEX_DIR, name), optimize=True)


def make_other_tex(size, emissive=None, roughness=0.8, metal=0.0):
    """texture2: R emissive, G metalness, B roughness, A opacity."""
    w, h = size
    arr = np.zeros((h, w, 4), np.float64)
    arr[..., 1] = metal
    arr[..., 2] = roughness
    arr[..., 3] = 1.0
    if emissive is not None:
        arr[..., 0] = emissive
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------------------------------------------------


class Part:
    """Triangles in model space (before scaling) that belong to one piece."""

    def __init__(self):
        self.pos, self.nrm, self.uv = [], [], []

    def add(self, pos, nrm, uv):
        self.pos.append(np.asarray(pos, np.float64))
        self.nrm.append(np.asarray(nrm, np.float64))
        self.uv.append(np.asarray(uv, np.float64))

    def arrays(self):
        if not self.pos:
            return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 2))
        return np.concatenate(self.pos), np.concatenate(self.nrm), np.concatenate(self.uv)


def split_prims(prims, classify, uv_map):
    """Assigns every triangle of every primitive to a part. uv_map(prim_index, uv) -> atlas uv (glTF convention)."""
    parts = {}
    for pi, p in enumerate(prims):
        tri = p["idx"]
        cent = p["pos"][tri].mean(axis=1)
        tnrm = p["nrm"][tri].mean(axis=1)
        uv = uv_map(pi, p["uv"])
        for t in range(len(tri)):
            name = classify(pi, cent[t], tnrm[t])
            part = parts.setdefault(name, Part())
            ids = tri[t]
            part.add(p["pos"][ids], p["nrm"][ids], uv[ids])
    return parts


def build_model(path, hierarchy, parts, scale, tex1, tex2, ground_offset=0.0):
    """hierarchy: list of (name, parent, absolute pivot in source units). Writes an S3O scaled by `scale`."""
    pieces = {}
    pivots = {}
    for name, parent, pivot in hierarchy:
        pv = np.array(pivot, np.float64)
        pv[1] += ground_offset
        pv *= scale
        pivots[name] = pv
        offset = pv - (pivots[parent] if parent else np.zeros(3))
        piece = s3o.Piece(name, offset)
        pieces[name] = piece
        if parent:
            pieces[parent].children.append(piece)
        pos, nrm, uv = parts[name].arrays() if name in parts else (np.zeros((0, 3)), None, None)
        if len(pos):
            pos = pos.copy()
            pos[:, 1] += ground_offset
            pos *= scale
            local = pos - pv
            # deduplicate identical vertices so the piece stays indexed
            key = np.round(np.c_[local, nrm, uv], 5)
            uniq, inv = np.unique(key, axis=0, return_inverse=True)
            inv = inv.reshape(-1)
            piece.verts = [(r[0], r[1], r[2], r[3], r[4], r[5], r[6], 1.0 - r[7]) for r in uniq]
            piece.tris = inv.tolist()
    root = pieces[hierarchy[0][0]]
    allpos = np.concatenate([(parts[n].arrays()[0] + [0, ground_offset, 0]) * scale for n in parts if n in pieces])
    height = float(allpos[:, 1].max())
    radius = float(np.linalg.norm(allpos - [0, height / 2, 0], axis=1).max())
    s3o.write(path, root, tex1, tex2, radius, height, (0.0, height / 2, 0.0))
    return allpos


def box(part, lo, hi, uv_rect, uv_rects=None):
    """Adds an axis aligned box. uv_rect (u0, v0, u1, v1) in glTF convention, or per face via uv_rects dict."""
    lo, hi = np.array(lo, np.float64), np.array(hi, np.float64)
    faces = {
        "+x": ([hi[0], lo[1], hi[2]], [hi[0], lo[1], lo[2]], [hi[0], hi[1], lo[2]], [hi[0], hi[1], hi[2]], [1, 0, 0]),
        "-x": ([lo[0], lo[1], lo[2]], [lo[0], lo[1], hi[2]], [lo[0], hi[1], hi[2]], [lo[0], hi[1], lo[2]], [-1, 0, 0]),
        "+y": ([lo[0], hi[1], hi[2]], [hi[0], hi[1], hi[2]], [hi[0], hi[1], lo[2]], [lo[0], hi[1], lo[2]], [0, 1, 0]),
        "-y": ([lo[0], lo[1], lo[2]], [hi[0], lo[1], lo[2]], [hi[0], lo[1], hi[2]], [lo[0], lo[1], hi[2]], [0, -1, 0]),
        "+z": ([lo[0], lo[1], hi[2]], [hi[0], lo[1], hi[2]], [hi[0], hi[1], hi[2]], [lo[0], hi[1], hi[2]], [0, 0, 1]),
        "-z": ([hi[0], lo[1], lo[2]], [lo[0], lo[1], lo[2]], [lo[0], hi[1], lo[2]], [hi[0], hi[1], lo[2]], [0, 0, -1]),
    }
    for key, (a, b, c, d, n) in faces.items():
        r = (uv_rects or {}).get(key, uv_rect)
        if r is None:
            continue
        u0, v0, u1, v1 = r
        # quad corners: a bottom-left, b bottom-right, c top-right, d top-left (as seen from outside)
        uvs = {"a": (u0, v1), "b": (u1, v1), "c": (u1, v0), "d": (u0, v0)}
        for tri in (("a", "b", "c"), ("a", "c", "d")):
            pts = {"a": a, "b": b, "c": c, "d": d}
            part.add([pts[k] for k in tri], [n] * 3, [uvs[k] for k in tri])


def quad(part, a, b, c, d, n, r):
    u0, v0, u1, v1 = r
    uvs = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
    pts = [a, b, c, d]
    for tri in ((0, 1, 2), (0, 2, 3)):
        part.add([pts[i] for i in tri], [n] * 3, [uvs[i] for i in tri])


# ---------------------------------------------------------------------------------------------------------------------
# Build pictures
# ---------------------------------------------------------------------------------------------------------------------


def sand_background(size, seed):
    rng = np.random.default_rng(seed)
    base = np.array([0.62, 0.50, 0.38])
    noise = rng.normal(0, 1, (size // 8, size // 8))
    noise = np.asarray(Image.fromarray(((noise + 3) * 40).clip(0, 255).astype(np.uint8)).resize((size, size),
                                                                                                   Image.BICUBIC))
    fine = rng.normal(0, 0.04, (size, size))
    shade = (noise / 255.0 - 0.45) * 0.25 + fine
    yy, xx = np.mgrid[0:size, 0:size] / size
    vignette = 1.0 - 0.35 * ((xx - 0.5) ** 2 + (yy - 0.55) ** 2)
    img = (base[None, None, :] + shade[..., None]) * vignette[..., None]
    return np.clip(img, 0, 1)


def buildpic(meshes, name, yaw=-35, pitch=22, seed=1, zoom_margin=0.1):
    size = 256
    fg = render(meshes, size=size, yaw=yaw, pitch=pitch, margin=zoom_margin, ss=3).astype(np.float64) / 255
    bg = sand_background(size, seed)
    alpha = fg[..., 3:4]
    # soft drop shadow under the unit
    sh = Image.fromarray((alpha[..., 0] * 255).astype(np.uint8)).resize((size, size // 3)).resize((size, size))
    sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(10)), np.float64) / 255
    shift = int(size * 0.22)
    sh = np.concatenate([np.zeros((shift, size)), sh[:-shift]]) * 0.5
    bg = bg * (1 - sh[..., None])
    out = bg * (1 - alpha) + fg[..., :3] * alpha
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    write_dds(os.path.join(PIC_DIR, name + ".dds"), img)
    img.save(os.path.join(HERE, "previews", name + ".png"))


def meshes_from_parts(parts, tex1_img, scale=1.0, hide=()):
    tex = np.asarray(tex1_img.convert("RGBA"), np.float64) / 255
    shown = tex[..., :3] * (1 - tex[..., 3:4]) + TEAM_RGB * tex[..., 3:4]
    shown = np.dstack([shown, np.ones(tex.shape[:2])])
    out = []
    for name, part in parts.items():
        if name in hide:
            continue
        pos, nrm, uv = part.arrays()
        if not len(pos):
            continue
        n = len(pos)
        out.append(dict(pos=pos * scale, nrm=nrm, uv=uv, idx=np.arange(n).reshape(-1, 3), tex=shown))
    return out


# ---------------------------------------------------------------------------------------------------------------------
# Sukuna
# ---------------------------------------------------------------------------------------------------------------------

SUKUNA_ATLAS = 1024
# source material index -> (x, y, size) in the atlas
SUKUNA_LAYOUT = {0: (0, 512, 256), 1: (0, 0, 512), 2: (512, 0, 512), 3: (256, 512, 256), 4: (512, 512, 256)}
FIRE_RECT = (768, 512, 128)  # emissive fire patch used by the Fuga arrow piece
HIP_Y = 29.5


def sukuna_classify(pi, c, n):
    x, y = c[0], c[1]
    if pi in (3, 4):
        return "head"
    if pi == 0:
        return "lleg" if x > 0 else "rleg"
    if pi == 1:
        if y > HIP_Y:
            return "pelvis"
        return "lleg" if x > 0 else "rleg"
    boundary = 6.6 if y >= 42 else 6.4 + (42 - y) * 0.15
    if abs(x) > boundary:
        return "larm" if x > 0 else "rarm"
    return "torso"


def sukuna_textures(prims):
    atlas = Image.new("RGBA", (SUKUNA_ATLAS, SUKUNA_ATLAS), (0, 0, 0, 0))
    for pi, (x, y, s) in SUKUNA_LAYOUT.items():
        im = Image.open(prims[pi]["image"]).convert("RGB").resize((s, s), Image.LANCZOS)
        alpha = 0
        if pi == 1:  # trousers carry the team colour
            alpha = 140
        im = im.convert("RGBA")
        im.putalpha(alpha)
        atlas.paste(im, (x, y))
    fx, fy, fs = FIRE_RECT
    yy, xx = np.mgrid[0:fs, 0:fs] / fs
    fire = np.zeros((fs, fs, 4))
    fire[..., 0] = 1.0
    fire[..., 1] = 0.35 + 0.6 * (1 - yy) ** 2
    fire[..., 2] = 0.05 + 0.5 * (1 - yy) ** 6
    fire[..., 3] = 0
    atlas.paste(Image.fromarray((fire * 255).astype(np.uint8), "RGBA"), (fx, fy))
    base = np.asarray(atlas, np.float64) / 255

    # tattoo mask: dark strokes on the skin and face textures
    lum = base[..., :3] @ np.array([0.3, 0.59, 0.11])
    tattoo = np.zeros(lum.shape, bool)
    for pi in (2, 4):
        x, y, s = SUKUNA_LAYOUT[pi]
        region = lum[y:y + s, x:x + s]
        tattoo[y:y + s, x:x + s] = region < 0.28

    results = {}
    for tier, glow in ((1, 0.0), (2, 0.45), (3, 1.0)):
        col = base.copy()
        if glow > 0:
            red = np.array([0.55, 0.02, 0.02]) * (0.6 + 0.4 * glow)
            col[tattoo, :3] = col[tattoo, :3] * (1 - glow * 0.85) + red * glow * 0.85
        emissive = np.zeros(lum.shape)
        emissive[tattoo] = glow
        emissive[fy:fy + fs, fx:fx + fs] = 1.0
        other = np.zeros(base.shape)
        other[..., 0] = emissive
        other[..., 1] = 0.0
        other[..., 2] = 0.75
        other[..., 3] = 1.0
        c_img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGBA")
        o_img = Image.fromarray((np.clip(other, 0, 1) * 255).astype(np.uint8), "RGBA")
        save_png(c_img, "modded_sukuna_t%d_color.png" % tier)
        save_png(o_img, "modded_sukuna_t%d_other.png" % tier)
        results[tier] = c_img
    return results


def sukuna_uv_map(pi, uv):
    x, y, s = SUKUNA_LAYOUT[pi]
    out = uv.copy()
    out[:, 0] = (x + uv[:, 0] * s) / SUKUNA_ATLAS
    out[:, 1] = (y + uv[:, 1] * s) / SUKUNA_ATLAS
    return out


def fuga_arrow(part):
    """Flaming arrow pointing down +Z, built around the origin (source units)."""
    fx, fy, fs = FIRE_RECT
    r = ((fx + 4) / SUKUNA_ATLAS, (fy + 4) / SUKUNA_ATLAS, (fx + fs - 4) / SUKUNA_ATLAS, (fy + fs - 4) / SUKUNA_ATLAS)
    box(part, (-0.35, -0.35, -9.0), (0.35, 0.35, 7.0), r)
    tip = np.array([0, 0, 11.0])
    ring = [np.array([1.6, 0, 7.0]), np.array([0, 1.6, 7.0]), np.array([-1.6, 0, 7.0]), np.array([0, -1.6, 7.0])]
    for i in range(4):
        a, b = ring[i], ring[(i + 1) % 4]
        n = np.cross(b - a, tip - a)
        n /= np.linalg.norm(n)
        part.add([a, b, tip], [n] * 3, [(r[0], r[3]), (r[2], r[3]), ((r[0] + r[2]) / 2, r[1])])
        part.add([b, a, np.array([0, 0, 6.0])], [-n] * 3, [(r[2], r[3]), (r[0], r[3]), ((r[0] + r[2]) / 2, r[1])])
    for sx, sy in ((1, 0), (0, 1)):
        for sign in (1, -1):
            a = np.array([0, 0, -9.0])
            b = np.array([sign * 1.4 * sx, sign * 1.4 * sy, -10.5])
            c = np.array([sign * 1.4 * sx, sign * 1.4 * sy, -7.0])
            d = np.array([0, 0, -6.5])
            n = np.cross(b - a, c - a)
            n /= max(np.linalg.norm(n), 1e-9)
            quad(part, a, b, c, d, n, r)
            quad(part, d, c, b, a, -n, r)


def build_sukuna():
    prims = load(os.path.join(SRC, "sukuna", "scene.gltf"))
    textures = sukuna_textures(prims)
    parts = split_prims(prims, sukuna_classify, sukuna_uv_map)
    ground = -min(float(p["pos"][:, 1].min()) for p in prims)

    def zmid(part_names, ylo, yhi):
        pts = np.concatenate([parts[n].arrays()[0] for n in part_names])
        sel = pts[(pts[:, 1] > ylo) & (pts[:, 1] < yhi)]
        return float((sel[:, 2].min() + sel[:, 2].max()) / 2)

    hip_z = zmid(["pelvis", "lleg", "rleg"], HIP_Y - 2, HIP_Y + 2)
    shoulder_z = zmid(["torso", "larm", "rarm"], 44, 47)
    neck_z = zmid(["head"], 49, 51)
    hands = {}
    for side in ("larm", "rarm"):
        pts = parts[side].arrays()[0]
        low = pts[pts[:, 1] < pts[:, 1].min() + 2.5]
        hands[side] = low.mean(axis=0)

    fuga = Part()
    fuga_arrow(fuga)
    parts["fuga"] = fuga

    hierarchy = [
        ("base", None, (0, -ground, 0)),
        ("pelvis", "base", (0, HIP_Y, hip_z)),
        ("torso", "pelvis", (0, 34.0, hip_z)),
        ("head", "torso", (0, 49.4, neck_z)),
        ("larm", "torso", (6.8, 45.6, shoulder_z)),
        ("lhand", "larm", tuple(hands["larm"])),
        ("rarm", "torso", (-6.8, 45.6, shoulder_z)),
        ("rhand", "rarm", tuple(hands["rarm"])),
        ("aimpoint", "torso", (0, 43.0, 4.0)),
        ("fuga", "torso", (0, 43.0, 9.0)),
        ("lleg", "pelvis", (2.6, HIP_Y, hip_z)),
        ("rleg", "pelvis", (-2.6, HIP_Y, hip_z)),
    ]
    # the arrow piece is authored around its own origin; shift it to the pivot
    fp, fn, fu = parts["fuga"].arrays()
    parts["fuga"] = Part()
    parts["fuga"].add(fp + np.array([0, 43.0, 9.0]), fn, fu)

    projectile = Part()
    fuga_arrow(projectile)
    build_model(os.path.join(OBJ_DIR, "sukuna_fuga.s3o"), [("arrow", None, (0, 0, 0))], {"arrow": projectile}, 1.6,
                "modded_sukuna_t3_color.png", "modded_sukuna_t3_other.png")

    scales = {1: 0.62, 2: 0.86, 3: 1.18}
    for tier, scale in scales.items():
        build_model(os.path.join(OBJ_DIR, "sukuna_t%d.s3o" % tier), hierarchy, parts, scale,
                    "modded_sukuna_t%d_color.png" % tier, "modded_sukuna_t%d_other.png" % tier, ground)
        meshes = meshes_from_parts(parts, textures[tier], hide=("fuga",) if tier < 3 else ())
        buildpic(meshes, "sukuna_t%d" % tier, yaw=-28, pitch=14, seed=10 + tier)
    return parts


# ---------------------------------------------------------------------------------------------------------------------
# Steve
# ---------------------------------------------------------------------------------------------------------------------

STEVE_TEX = 512
STEVE_SRC = 64


def steve_classify(pi, c, n):
    p = c - 0.01 * n
    x, y = p[0], p[1]
    if y > 8:
        return "head"
    if y < -4:
        return "lleg" if x > 0 else "rleg"
    if abs(x) > 4:
        return "larm" if x > 0 else "rarm"
    return "torso"


def unused_texels(prims):
    used = np.zeros((STEVE_SRC, STEVE_SRC), bool)
    p = prims[0]
    for tri in p["idx"]:
        uv = p["uv"][tri] * STEVE_SRC
        lo = np.floor(uv.min(0)).astype(int)
        hi = np.ceil(uv.max(0)).astype(int)
        used[max(lo[1], 0):min(hi[1], STEVE_SRC), max(lo[0], 0):min(hi[0], STEVE_SRC)] = True
    return ~used


def find_free_block(free, size, taken):
    for y in range(0, STEVE_SRC - size + 1, size):
        for x in range(0, STEVE_SRC - size + 1, size):
            if free[y:y + size, x:x + size].all() and (x, y) not in taken:
                taken.add((x, y))
                return x, y
    raise RuntimeError("no free texture space")


def steve_textures(prims):
    src = Image.open(prims[0]["image"]).convert("RGBA")
    arr = np.asarray(src, np.float64) / 255
    free = unused_texels(prims)
    taken = set()
    swatches = {}
    for name, rgb in (("wood", (0.47, 0.31, 0.16)), ("wood_dark", (0.33, 0.21, 0.10)), ("string", (0.85, 0.85, 0.85)),
                      ("iron", (0.85, 0.85, 0.85)), ("flint", (0.25, 0.25, 0.27)), ("feather", (0.95, 0.95, 0.95)),
                      ("enchant", (0.75, 0.45, 1.0))):
        x, y = find_free_block(free, 2, taken)
        arr[y:y + 2, x:x + 2, :3] = rgb
        arr[y:y + 2, x:x + 2, 3] = 1
        swatches[name] = ((x + 0.25) / STEVE_SRC, (y + 0.25) / STEVE_SRC, (x + 1.75) / STEVE_SRC,
                          (y + 1.75) / STEVE_SRC)
    rgb = arr[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    shirt = (g > r + 0.15) & (b > r + 0.15) & (np.abs(g - b) < 0.3)
    pants = (b > r + 0.12) & (b > g + 0.12)

    results = {}
    for tier in (1, 2, 3):
        col = rgb.copy()
        lum = rgb @ np.array([0.3, 0.59, 0.11])
        if tier == 2:  # iron leggings
            col[pants] = (0.55 + 0.9 * lum[pants, None]) * np.array([0.82, 0.82, 0.85])
        elif tier == 3:  # diamond leggings
            col[pants] = (0.45 + 1.2 * lum[pants, None]) * np.array([0.35, 0.9, 0.85])
        alpha = np.where(shirt, 0.7, 0.0)
        out = np.dstack([np.clip(col, 0, 1), alpha])
        emissive = np.zeros(lum.shape)
        if tier == 3:
            x0, y0, x1, y1 = swatches["enchant"]
            ex, ey = int(x0 * STEVE_SRC), int(y0 * STEVE_SRC)
            emissive[ey:ey + 2, ex:ex + 2] = 0.9
        other = np.dstack([emissive, np.zeros(lum.shape), np.full(lum.shape, 0.85), np.ones(lum.shape)])
        c_img = Image.fromarray((out * 255).astype(np.uint8), "RGBA").resize((STEVE_TEX, STEVE_TEX), Image.NEAREST)
        o_img = Image.fromarray((other * 255).astype(np.uint8), "RGBA").resize((STEVE_TEX, STEVE_TEX), Image.NEAREST)
        save_png(c_img, "modded_steve_t%d_color.png" % tier)
        save_png(o_img, "modded_steve_t%d_other.png" % tier)
        results[tier] = c_img
    return results, swatches


def steve_bow(swatches, tier):
    """Pixel bow in the left hand. Rest pose: long axis along Z, belly towards -Y (forward once the arm is raised)."""
    part = Part()
    wood = swatches["enchant"] if tier == 3 else swatches["wood"]
    for i, t in enumerate(range(-6, 7)):
        y = 3.0 * (t / 6.0) ** 2
        rect = swatches["wood_dark"] if i % 4 == 0 else wood
        box(part, (-0.5, y - 0.5, t - 0.5), (0.5, y + 0.5, t + 0.5), rect)
    box(part, (-0.15, 2.85, -6.0), (0.15, 3.15, 6.0), swatches["string"])
    return part


def steve_arrow(swatches):
    """Projectile model: arrow pointing down +Z."""
    part = Part()
    box(part, (-0.35, -0.35, -7.0), (0.35, 0.35, 5.0), swatches["wood"])
    box(part, (-0.9, -0.9, 5.0), (0.9, 0.9, 6.2), swatches["flint"])
    box(part, (-0.45, -0.45, 6.2), (0.45, 0.45, 7.4), swatches["flint"])
    box(part, (-1.4, -0.12, -7.0), (1.4, 0.12, -4.5), swatches["feather"])
    box(part, (-0.12, -1.4, -7.0), (0.12, 1.4, -4.5), swatches["feather"])
    return part


def build_steve():
    prims = load(os.path.join(SRC, "steve", "scene.gltf"))
    textures, swatches = steve_textures(prims)
    parts = split_prims(prims, steve_classify, lambda pi, uv: uv)
    ground = 16.0
    hand = (6.0, 13.0 - ground, 0.0)
    hierarchy = [
        ("base", None, (0, -ground, 0)),
        ("pelvis", "base", (0, -4.0, 0)),
        ("torso", "pelvis", (0, -4.0, 0)),
        ("head", "torso", (0, 8.0, 0)),
        ("larm", "torso", (6.0, 6.0, 0)),
        ("bow", "larm", hand),
        ("flare", "bow", hand),
        ("rarm", "torso", (-6.0, 6.0, 0)),
        ("nano", "rarm", (-6.0, hand[1], 0.0)),
        ("lleg", "pelvis", (2.0, -4.0, 0)),
        ("rleg", "pelvis", (-2.0, -4.0, 0)),
    ]
    scales = {1: 1.1, 2: 1.5, 3: 1.95}
    for tier, scale in scales.items():
        bow = steve_bow(swatches, tier)
        bp, bn, bu = bow.arrays()
        parts["bow"] = Part()
        parts["bow"].add(bp + np.array(hand), bn, bu)
        build_model(os.path.join(OBJ_DIR, "steve_t%d.s3o" % tier), hierarchy, parts, scale,
                    "modded_steve_t%d_color.png" % tier, "modded_steve_t%d_other.png" % tier, ground)
        buildpic(meshes_from_parts(parts, textures[tier]), "steve_t%d" % tier, yaw=-30, pitch=16, seed=20 + tier)

    arrow = steve_arrow(swatches)
    build_model(os.path.join(OBJ_DIR, "mc_arrow.s3o"), [("arrow", None, (0, 0, 0))], {"arrow": arrow}, 1.0,
                "modded_steve_t1_color.png", "modded_steve_t1_other.png")
    return swatches


# ---------------------------------------------------------------------------------------------------------------------
# Minecraft blocks: dirt, cobblestone, TNT and the nether portal
# ---------------------------------------------------------------------------------------------------------------------

TILE = 16
TILE_SCALE = 8
BLOCK_ATLAS_TILES = 4


def tile_noise(seed):
    return np.random.default_rng(seed).random((TILE, TILE))


def make_block_tiles():
    tiles = {}
    n = tile_noise(1)
    dirt = np.array([0.53, 0.38, 0.26])[None, None, :] * (0.78 + 0.35 * n[..., None])
    dark = tile_noise(2) > 0.86
    dirt[dark] *= 0.7
    tiles["dirt"] = dirt
    g = tile_noise(3)
    grass_top = np.array([0.36, 0.62, 0.22])[None, None, :] * (0.8 + 0.3 * g[..., None])
    tiles["grass_top"] = grass_top
    side = dirt.copy()
    depth = 3 + (tile_noise(4)[0] * 2.5).astype(int)
    for x in range(TILE):
        side[:depth[x], x] = grass_top[:depth[x], x]
    tiles["grass_side"] = side

    c = tile_noise(5)
    cobble = np.array([0.5, 0.5, 0.5])[None, None, :] * (0.75 + 0.4 * c[..., None])
    for (y0, x0, h, w) in ((0, 0, 5, 7), (0, 8, 4, 8), (5, 1, 5, 6), (4, 9, 6, 6), (10, 0, 6, 8), (11, 9, 5, 7)):
        cobble[y0:y0 + h, x0] *= 0.55
        cobble[y0, x0:x0 + w] *= 0.55
        cobble[min(y0 + h, TILE - 1), x0:x0 + w] *= 0.75
    tiles["cobble"] = cobble

    o = tile_noise(6)
    obsidian = np.array([0.08, 0.05, 0.13])[None, None, :] * (0.7 + 0.6 * o[..., None])
    obsidian[tile_noise(7) > 0.9] = (0.35, 0.22, 0.5)
    tiles["obsidian"] = obsidian

    yy, xx = np.mgrid[0:TILE, 0:TILE] / TILE
    swirl = 0.5 + 0.5 * np.sin(10 * xx + 6 * np.sin(6 * yy) + 3 * tile_noise(8))
    portal = np.dstack([0.45 + 0.35 * swirl, 0.05 + 0.15 * swirl, 0.75 + 0.25 * swirl])
    tiles["portal"] = portal

    tnt = np.zeros((TILE, TILE, 3))
    tnt[:] = (0.82, 0.18, 0.12)
    tnt[:, ::4] *= 0.8
    tnt[5:11] = (0.95, 0.95, 0.95)
    letters = [" TTT N  N TTT ", "  T  NN N  T  ", "  T  N NN  T  ", "  T  N  N  T  "]
    for row, line in enumerate(letters):
        for col, ch in enumerate(line):
            if ch != " ":
                tnt[6 + row, 1 + col] = (0.1, 0.1, 0.1)
    tiles["tnt_side"] = tnt
    top = np.zeros((TILE, TILE, 3))
    top[:] = (0.75, 0.2, 0.15)
    top[2:14, 2:14] = (0.85, 0.82, 0.78)
    top[6:10, 6:10] = (0.15, 0.15, 0.15)
    top[7:9, 7:9] = (0.9, 0.85, 0.3)
    tiles["tnt_top"] = top
    bottom = top.copy()
    bottom[6:10, 6:10] = (0.85, 0.82, 0.78)
    tiles["tnt_bottom"] = bottom
    tiles["tnt_flash"] = np.full((TILE, TILE, 3), 0.95)
    return tiles


def build_blocks():
    tiles = make_block_tiles()
    order = ["dirt", "grass_top", "grass_side", "cobble", "obsidian", "portal", "tnt_side", "tnt_top", "tnt_bottom",
             "tnt_flash"]
    px = TILE * TILE_SCALE
    size = px * BLOCK_ATLAS_TILES
    color = np.zeros((size, size, 4))
    other = np.zeros((size, size, 4))
    other[..., 2] = 0.9
    other[..., 3] = 1
    rects = {}
    for i, name in enumerate(order):
        tx, ty = (i % BLOCK_ATLAS_TILES) * px, (i // BLOCK_ATLAS_TILES) * px
        big = np.kron(np.clip(tiles[name], 0, 1), np.ones((TILE_SCALE, TILE_SCALE, 1)))
        color[ty:ty + px, tx:tx + px, :3] = big
        if name == "portal":
            other[ty:ty + px, tx:tx + px, 0] = 0.85
        if name == "obsidian":
            other[ty:ty + px, tx:tx + px, 2] = 0.3
            other[ty:ty + px, tx:tx + px, 1] = 0.2
        if name == "tnt_flash":
            other[ty:ty + px, tx:tx + px, 0] = 1.0
        pad = 2
        rects[name] = ((tx + pad) / size, (ty + pad) / size, (tx + px - pad) / size, (ty + px - pad) / size)
    c_img = Image.fromarray((color * 255).astype(np.uint8), "RGBA")
    o_img = Image.fromarray((other * 255).astype(np.uint8), "RGBA")
    save_png(c_img, "modded_blocks_color.png")
    save_png(o_img, "modded_blocks_other.png")

    half = 8.0
    blocks = {
        "mc_dirt": {"+y": rects["grass_top"], "-y": rects["dirt"], "+x": rects["grass_side"],
                    "-x": rects["grass_side"], "+z": rects["grass_side"], "-z": rects["grass_side"]},
        "mc_cobble": {k: rects["cobble"] for k in ("+x", "-x", "+y", "-y", "+z", "-z")},
        "mc_tnt": {"+y": rects["tnt_top"], "-y": rects["tnt_bottom"], "+x": rects["tnt_side"], "-x": rects["tnt_side"],
                   "+z": rects["tnt_side"], "-z": rects["tnt_side"]},
    }
    for seed, (name, faces) in enumerate(blocks.items()):
        block = Part()
        box(block, (-half, 0, -half), (half, 2 * half, half), None, faces)
        parts = {"block": block}
        hierarchy = [("base", None, (0, 0, 0)), ("block", "base", (0, 0, 0))]
        if name == "mc_tnt":
            flash = Part()
            e = 0.15
            box(flash, (-half - e, -e, -half - e), (half + e, 2 * half + e, half + e), rects["tnt_flash"])
            parts["flash"] = flash
            hierarchy.append(("flash", "base", (0, 0, 0)))
        build_model(os.path.join(OBJ_DIR, name + ".s3o"), hierarchy, parts, 1.0, "modded_blocks_color.png",
                    "modded_blocks_other.png")
        buildpic(meshes_from_parts({"block": block}, c_img), name, yaw=-35, pitch=28, seed=40 + seed,
                 zoom_margin=0.25)

    # Nether portal: 4 x 5 obsidian frame of 8 elmo blocks around a 2 x 3 portal sheet, facing +Z
    frame = Part()
    sheet = Part()
    b = 8.0
    for col in range(4):
        for row in range(5):
            if 0 < col < 3 and 0 < row < 4:
                continue
            x0 = -16 + col * b
            y0 = row * b
            box(frame, (x0, y0, -b / 2), (x0 + b, y0 + b, b / 2), rects["obsidian"])
    r = rects["portal"]
    for row in range(3):
        for col in range(2):
            x0, y0 = -8 + col * b, b + row * b
            a, bb, c, d = [x0, y0, 0.5], [x0 + b, y0, 0.5], [x0 + b, y0 + b, 0.5], [x0, y0 + b, 0.5]
            quad(sheet, a, bb, c, d, [0, 0, 1], r)
            a2, b2, c2, d2 = [x0 + b, y0, -0.5], [x0, y0, -0.5], [x0, y0 + b, -0.5], [x0 + b, y0 + b, -0.5]
            quad(sheet, a2, b2, c2, d2, [0, 0, -1], r)
    parts = {"frame": frame, "sheet": sheet}
    hierarchy = [("base", None, (0, 0, 0)), ("frame", "base", (0, 0, 0)), ("sheet", "base", (0, 20, 0)),
                 ("exit", "base", (0, 0, 28)), ("ambient", "base", (0, 20, 0))]
    build_model(os.path.join(OBJ_DIR, "mc_nether_portal.s3o"), hierarchy, parts, 1.0, "modded_blocks_color.png",
                "modded_blocks_other.png")
    buildpic(meshes_from_parts(parts, c_img), "mc_nether_portal", yaw=-30, pitch=12, seed=77, zoom_margin=0.12)


# ---------------------------------------------------------------------------------------------------------------------
# Raptor factories: scaled, recoloured copies of the raptor hive with a build pad at ground level
# ---------------------------------------------------------------------------------------------------------------------

BROOD_FACTORIES = {
    "brood_nest": (0.72, "chicken_brown_l_color.dds"),
    "brood_roost": (0.72, "chicken_purple_l_color.dds"),
    "brood_lair": (0.92, "chicken_crimson_l_color.dds"),
    "brood_throne": (1.15, "chicken_black_l_color.dds"),
}


def scaled_copy(piece, scale):
    out = s3o.Piece(piece.name, tuple(np.array(piece.offset) * scale))
    out.verts = [(v[0] * scale, v[1] * scale, v[2] * scale) + tuple(v[3:]) for v in piece.verts]
    out.tris = list(piece.tris)
    out.children = [scaled_copy(c, scale) for c in piece.children]
    return out


def build_brood_factories():
    hive = s3o.read(os.path.join(ROOT, "objects3d", "Raptors", "raptor_hive.s3o"))
    for seed, (name, (scale, tex1)) in enumerate(BROOD_FACTORIES.items()):
        root = scaled_copy(hive["root"], scale)
        root.children.append(s3o.Piece("pad", (0.0, -root.offset[1], 0.0)))
        s3o.write(os.path.join(OBJ_DIR, name + ".s3o"), root, tex1, hive["tex2"], hive["radius"] * scale,
                  hive["height"] * scale, tuple(np.array(hive["mid"]) * scale))

        tex = Image.open(os.path.join(TEX_DIR, tex1)).convert("RGBA")
        tex_arr = np.asarray(tex, np.float64) / 255
        shown = tex_arr[..., :3] * (1 - tex_arr[..., 3:4]) + TEAM_RGB * tex_arr[..., 3:4]
        shown = np.dstack([shown, np.ones(tex_arr.shape[:2])])
        meshes = []
        for piece, origin in s3o.flatten(root):
            if len(piece.tris) < 3:
                continue
            v = np.array(piece.verts)
            uv = v[:, 6:8].copy()
            uv[:, 1] = 1 - uv[:, 1]
            meshes.append(dict(pos=v[:, :3] + origin, nrm=v[:, 3:6], uv=uv, idx=np.array(piece.tris).reshape(-1, 3),
                               tex=shown))
        buildpic(meshes, name, yaw=-30, pitch=25, seed=60 + seed, zoom_margin=0.08)


def build_missing_raptor_pics():
    """Raptor defs that point at portraits which were never added; they show up once raptors are buildable."""
    raptor_pics = os.path.join(ROOT, "unitpics", "raptors")
    worm = s3o.read(os.path.join(ROOT, "objects3d", "Raptors", "raptor_worm_green.s3o"))
    tex_arr = np.asarray(Image.open(os.path.join(TEX_DIR, worm["tex1"])).convert("RGBA"), np.float64) / 255
    shown = np.dstack([tex_arr[..., :3] * (1 - tex_arr[..., 3:4]) + TEAM_RGB * tex_arr[..., 3:4],
                       np.ones(tex_arr.shape[:2])])
    meshes = []
    for piece, origin in s3o.flatten(worm["root"]):
        if len(piece.tris) < 3:
            continue
        v = np.array(piece.verts)
        uv = v[:, 6:8].copy()
        uv[:, 1] = 1 - uv[:, 1]
        meshes.append(dict(pos=v[:, :3] + origin, nrm=v[:, 3:6], uv=uv, idx=np.array(piece.tris).reshape(-1, 3),
                           tex=shown))
    global PIC_DIR
    saved, PIC_DIR = PIC_DIR, raptor_pics
    buildpic(meshes, "raptor_worm_green", yaw=-30, pitch=25, seed=90)
    PIC_DIR = saved
    with open(os.path.join(raptor_pics, "raptor_turrets.dds"), "rb") as src:
        data = src.read()
    with open(os.path.join(raptor_pics, "raptor_turrets_burrow.dds"), "wb") as dst:
        dst.write(data)


def main():
    for d in (OBJ_DIR, PIC_DIR, os.path.join(HERE, "previews")):
        os.makedirs(d, exist_ok=True)
    build_sukuna()
    build_steve()
    build_blocks()
    build_brood_factories()
    build_missing_raptor_pics()
    print("assets written")


if __name__ == "__main__":
    main()
