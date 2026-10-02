import numpy as np


def components(pos, idx, weld=1e-4):
    """Connected components of triangles, welding vertices by position."""
    key = np.round(pos / weld).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    parent = np.arange(inv.max() + 1)

    def find(a):
        root = a
        while parent[root] != root:
            root = parent[root]
        while parent[a] != root:
            parent[a], a = root, parent[a]
        return root

    for a, b, c in inv[idx]:
        ra, rb, rc = find(a), find(b), find(c)
        parent[rb] = ra
        parent[find(rc)] = ra
    roots = np.array([find(inv[t[0]]) for t in idx])
    labels = {r: i for i, r in enumerate(dict.fromkeys(roots.tolist()))}
    return np.array([labels[r] for r in roots.tolist()])
