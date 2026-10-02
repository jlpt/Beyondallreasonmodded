"""Minimal Spring/Recoil S3O reader and writer."""
import struct

import numpy as np

HEADER = struct.Struct("<12si5f4i")
PIECE = struct.Struct("<10i3f")
VERTEX = struct.Struct("<8f")


class Piece:
    def __init__(self, name, offset=(0.0, 0.0, 0.0)):
        self.name = name
        self.offset = tuple(float(v) for v in offset)  # relative to parent
        self.verts = []  # (x, y, z, nx, ny, nz, u, v), piece-local
        self.tris = []  # flat index list
        self.children = []


def _cstr(buf, off):
    end = buf.index(b"\0", off)
    return buf[off:end].decode("latin-1")


def read(path):
    buf = open(path, "rb").read()
    magic, ver, radius, height, mx, my, mz, root, coll, t1, t2 = HEADER.unpack_from(buf, 0)

    def rp(off):
        (name, nch, chofs, nv, vofs, vtype, ptype, vts, vtofs, coll, x, y, z) = PIECE.unpack_from(buf, off)
        p = Piece(_cstr(buf, name), (x, y, z))
        p.ptype = ptype
        for i in range(nv):
            p.verts.append(VERTEX.unpack_from(buf, vofs + i * 32))
        p.tris = list(struct.unpack_from("<%di" % vts, buf, vtofs))
        for i in range(nch):
            (co,) = struct.unpack_from("<i", buf, chofs + 4 * i)
            p.children.append(rp(co))
        return p

    model = {"radius": radius, "height": height, "mid": (mx, my, mz), "root": rp(root),
             "tex1": _cstr(buf, t1) if t1 else "", "tex2": _cstr(buf, t2) if t2 else ""}
    return model


def write(path, root, tex1, tex2, radius, height, mid):
    out = bytearray(HEADER.size)

    def put(b):
        off = len(out)
        out.extend(b)
        return off

    def wp(p):
        off = put(bytes(PIECE.size))
        name = put(p.name.encode("latin-1") + b"\0")
        vofs = put(b"".join(VERTEX.pack(*v) for v in p.verts)) if p.verts else 0
        vtofs = put(struct.pack("<%di" % len(p.tris), *p.tris)) if p.tris else 0
        child_offs = [wp(c) for c in p.children]
        chofs = put(struct.pack("<%di" % len(child_offs), *child_offs)) if child_offs else 0
        PIECE.pack_into(out, off, name, len(p.children), chofs, len(p.verts), vofs, 0, 0, len(p.tris), vtofs, 0,
                        *p.offset)
        return off

    rootofs = wp(root)
    t1 = put(tex1.encode("latin-1") + b"\0")
    t2 = put(tex2.encode("latin-1") + b"\0")
    HEADER.pack_into(out, 0, b"Spring unit\0", 0, radius, height, mid[0], mid[1], mid[2], rootofs, 0, t1, t2)
    open(path, "wb").write(bytes(out))


def flatten(root):
    """Yield (piece, absolute_origin) for every piece."""
    stack = [(root, np.zeros(3))]
    while stack:
        p, parent = stack.pop()
        o = parent + np.array(p.offset)
        yield p, o
        for c in p.children:
            stack.append((c, o))
