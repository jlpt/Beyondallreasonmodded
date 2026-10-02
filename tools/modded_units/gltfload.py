import json, os, struct
import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def node_matrix(nd):
    if "matrix" in nd:
        return np.array(nd["matrix"], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in nd:
        m = np.diag(list(nd["scale"]) + [1.0]) @ m
    if "rotation" in nd:
        x, y, z, w = nd["rotation"]
        r = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ])
        rm = np.eye(4)
        rm[:3, :3] = r
        m = rm @ m
    if "translation" in nd:
        t = np.eye(4)
        t[:3, 3] = nd["translation"]
        m = t @ m
    return m


def load(path):
    base = os.path.dirname(path)
    g = json.load(open(path))
    bufs = [open(os.path.join(base, b["uri"]), "rb").read() for b in g["buffers"]]

    def acc(i):
        a = g["accessors"][i]
        bv = g["bufferViews"][a["bufferView"]]
        dt = CT[a["componentType"]]
        n = NC[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        isz = np.dtype(dt).itemsize * n
        buf = bufs[bv["buffer"]]
        if stride and stride != isz:
            out = np.empty((a["count"], n), dtype=dt)
            for k in range(a["count"]):
                out[k] = np.frombuffer(buf, dtype=dt, count=n, offset=off + k * stride)
            return out
        return np.frombuffer(buf, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)

    prims = []

    def walk(ni, parent):
        nd = g["nodes"][ni]
        m = parent @ node_matrix(nd)
        if "mesh" in nd:
            for p in g["meshes"][nd["mesh"]]["primitives"]:
                pos = acc(p["attributes"]["POSITION"]).astype(np.float64)
                nrm = acc(p["attributes"]["NORMAL"]).astype(np.float64)
                uv = acc(p["attributes"]["TEXCOORD_0"]).astype(np.float64)
                idx = acc(p["indices"]).reshape(-1).astype(np.int64) if "indices" in p else np.arange(len(pos))
                ph = np.c_[pos, np.ones(len(pos))] @ m.T
                nm = np.linalg.inv(m[:3, :3]).T
                n2 = nrm @ nm.T
                n2 /= np.maximum(np.linalg.norm(n2, axis=1, keepdims=True), 1e-12)
                mat = g["materials"][p["material"]]
                img = None
                bct = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
                if bct is not None:
                    img = os.path.join(base, g["images"][g["textures"][bct["index"]]["source"]]["uri"])
                prims.append({"pos": ph[:, :3], "nrm": n2, "uv": uv, "idx": idx.reshape(-1, 3), "image": img,
                              "material": mat.get("name"), "node": nd.get("name")})
        for c in nd.get("children", []):
            walk(c, m)

    for r in g["scenes"][g.get("scene", 0)]["nodes"]:
        walk(r, np.eye(4))
    return prims
