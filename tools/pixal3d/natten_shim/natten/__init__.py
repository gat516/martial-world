"""Pure-PyTorch stand-in for NATTEN's `na2d`, the only call NAF makes.

NATTEN has no Windows build for Turing cards, so gen.py puts this on sys.path
when the real package is missing. Same semantics as natten.na2d: tensors are
[B, H, W, heads, D]; each query attends to the kernel_size window around it,
clamped to stay inside the image (not zero-padded); with dilation d the window
is taken within the pixels that share the query's position mod d.

It's slower and uses more memory than the fused kernels, so it works in row
chunks sized by CHUNK_ELEMENTS.
"""
import torch

__version__ = "0.0.0-shim"
CHUNK_ELEMENTS = 1 << 26  # gathered key elements per chunk (~128 MB in fp16)


def _pair(x):
    return (x, x) if isinstance(x, int) else tuple(x)


def _starts(n, k, device):
    return (torch.arange(n, device=device) - k // 2).clamp(0, n - k)


def _na(q, k, v, kh, kw, scale):
    B, H, W, N, D = q.shape
    assert H >= kh and W >= kw, f"window {kh}x{kw} larger than input {H}x{W}"
    rows = _starts(H, kh, q.device)[:, None] + torch.arange(kh, device=q.device)  # (H, kh)
    cols = _starts(W, kw, q.device)[:, None] + torch.arange(kw, device=q.device)  # (W, kw)
    out = torch.empty_like(q)
    per_row = B * kh * W * kw * N * D
    step = max(1, CHUNK_ELEMENTS // per_row)
    for r0 in range(0, H, step):
        r1 = min(H, r0 + step)
        idx = rows[r0:r1]
        # (B, R, kh, W, N, D) -> (B, R, kh, W, kw, N, D)
        kk = k[:, idx][:, :, :, cols]
        vv = v[:, idx][:, :, :, cols]
        qq = q[:, r0:r1]
        s = torch.einsum("brwnd,brawcnd->brwnac", qq.float(), kk.float()) * scale
        s = s.flatten(-2).softmax(-1).view(*s.shape)
        out[:, r0:r1] = torch.einsum("brwnac,brawcnd->brwnd", s, vv.float()).to(q.dtype)
    return out


def na2d(query, key, value, kernel_size, stride=1, dilation=1, is_causal=False, scale=None, **_):
    assert _pair(stride) == (1, 1) and not is_causal, "shim supports stride 1, non-causal only"
    kh, kw = _pair(kernel_size)
    dh, dw = _pair(dilation)
    B, H, W, N, D = query.shape
    scale = D ** -0.5 if scale is None else scale
    if (dh, dw) == (1, 1):
        return _na(query, key, value, kh, kw, scale)
    if H % dh == 0 and W % dw == 0:
        # Fold each dilation group into the batch: (B*dh*dw, H/dh, W/dw, N, D).
        def fold(x):
            x = x.view(B, H // dh, dh, W // dw, dw, N, D).permute(0, 2, 4, 1, 3, 5, 6)
            return x.reshape(B * dh * dw, H // dh, W // dw, N, D)

        o = _na(fold(query), fold(key), fold(value), kh, kw, scale)
        o = o.view(B, dh, dw, H // dh, W // dw, N, D).permute(0, 3, 1, 4, 2, 5, 6)
        return o.reshape(B, H, W, N, D)
    out = torch.empty_like(query)
    for a in range(dh):
        for b in range(dw):
            out[:, a::dh, b::dw] = _na(query[:, a::dh, b::dw], key[:, a::dh, b::dw],
                                       value[:, a::dh, b::dw], kh, kw, scale)
    return out
