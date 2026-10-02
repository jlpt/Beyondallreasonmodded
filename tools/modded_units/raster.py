"""Tiny numpy software rasterizer used for previews and build pictures."""
import numpy as np


def look_rotation(yaw_deg, pitch_deg):
    y, p = np.radians(yaw_deg), np.radians(pitch_deg)
    ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    rx = np.array([[1, 0, 0], [0, np.cos(p), -np.sin(p)], [0, np.sin(p), np.cos(p)]])
    return rx @ ry


def render(meshes, size=256, yaw=30, pitch=20, light=(0.4, 0.8, 0.6), bg=(0, 0, 0, 0), margin=0.08, ss=2,
           fit=None):
    """meshes: list of dicts with pos (N,3), nrm (N,3), uv (N,2), idx (M,3), tex (H,W,4 float) and optional
    tint (callable rgba->rgba). Camera looks down -Z of view space after rotation; +Y is up."""
    R = look_rotation(yaw, pitch)
    allp = np.concatenate([m["pos"] for m in meshes]) @ R.T
    if fit is None:
        lo, hi = allp[:, :2].min(0), allp[:, :2].max(0)
    else:
        lo, hi = fit
    W = size * ss
    span = (hi - lo).max() * (1 + 2 * margin)
    center = (hi + lo) / 2
    scale = W / span
    color = np.zeros((W, W, 4), np.float64)
    color[:] = np.array(bg, np.float64) / 255.0
    depth = np.full((W, W), -np.inf)
    L = np.array(light, np.float64)
    L /= np.linalg.norm(L)
    L = L @ R.T  # light fixed relative to the camera
    for m in meshes:
        p = m["pos"] @ R.T
        n = m["nrm"] @ R.T
        sx = (p[:, 0] - center[0]) * scale + W / 2
        sy = W / 2 - (p[:, 1] - center[1]) * scale
        sz = p[:, 2]
        tex = m["tex"]
        th, tw = tex.shape[:2]
        uv = m["uv"]
        for a, b, c in m["idx"]:
            x0, x1, x2 = sx[a], sx[b], sx[c]
            y0, y1, y2 = sy[a], sy[b], sy[c]
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-12:
                continue
            minx, maxx = int(max(min(x0, x1, x2), 0)), int(min(max(x0, x1, x2) + 1, W))
            miny, maxy = int(max(min(y0, y1, y2), 0)), int(min(max(y0, y1, y2) + 1, W))
            if minx >= maxx or miny >= maxy:
                continue
            gx, gy = np.meshgrid(np.arange(minx, maxx) + 0.5, np.arange(miny, maxy) + 0.5)
            w0 = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / den
            w1 = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / den
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any():
                continue
            z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
            sub = depth[miny:maxy, minx:maxx]
            upd = inside & (z > sub)
            if not upd.any():
                continue
            u = w0 * uv[a, 0] + w1 * uv[b, 0] + w2 * uv[c, 0]
            v = w0 * uv[a, 1] + w1 * uv[b, 1] + w2 * uv[c, 1]
            ti = np.clip((v * th).astype(int), 0, th - 1)
            tj = np.clip((u * tw).astype(int), 0, tw - 1)
            texel = tex[ti, tj]
            nn = w0[..., None] * n[a] + w1[..., None] * n[b] + w2[..., None] * n[c]
            nn /= np.maximum(np.linalg.norm(nn, axis=-1, keepdims=True), 1e-9)
            diff = np.clip((nn @ L), 0, 1)
            shade = 0.45 + 0.65 * diff
            rgb = np.clip(texel[..., :3] * shade[..., None], 0, 1)
            sub[upd] = z[upd]
            cs = color[miny:maxy, minx:maxx]
            cs[upd, :3] = rgb[upd]
            cs[upd, 3] = 1.0
    if ss > 1:
        color = color.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
    return (np.clip(color, 0, 1) * 255).astype(np.uint8)
