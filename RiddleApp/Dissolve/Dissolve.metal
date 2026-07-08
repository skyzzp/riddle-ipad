#include <metal_stdlib>
using namespace metal;

static uint px_hash(uint x, uint y) {
    uint h = (x * 0x9E3779B1u) ^ (y * 0x85EBCA6Bu);
    h ^= h >> 13;
    h = h * 0xC2B2AE35u;
    return h ^ (h >> 16);
}

// Shape the fade curve. `t` is 0..1; result is the mix amount toward the page.
static float ease(float t, int mode) {
    switch (mode) {
        case 1: return t * t * (3.0 - 2.0 * t);   // smooth — soft in and out
        case 2: return t * t;                     // ease-in — lingers dark, then fades
        case 3: return t * (2.0 - t);             // ease-out — fades early, settles gently
        case 4: return t * t * t;                 // hold -> vanish — holds, then rushes off
        default: return t;                        // linear
    }
}

// Fade her ink (dark pixels) toward the page colour as `progress` rises. Every
// pixel fades SMOOTHLY (never snaps), so the letters fade away instead of
// eroding into a stipple of dots. `stagger` (0..~0.8) optionally spreads the
// per-pixel start times so the ink drinks unevenly/organically; at 0 the whole
// mark fades as one. `easeMode` shapes the curve (see ease()).
kernel void dissolve(texture2d<float, access::read>  src [[texture(0)]],
                     texture2d<float, access::write> dst [[texture(1)]],
                     constant float& progress          [[buffer(0)]],
                     constant float4& page             [[buffer(1)]],
                     constant int&   easeMode          [[buffer(2)]],
                     constant float& stagger           [[buffer(3)]],
                     uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float4 c = src.read(gid);
    float luma = (c.r + c.g + c.b) / 3.0;
    // Per-pixel start offset in [0, stagger); every pixel still finishes by
    // progress=1 (its personal fade spans the remaining 1-stagger of the timeline).
    float r = (stagger > 0.0) ? float(px_hash(gid.x, gid.y) % 10000u) / 10000.0 : 0.0;
    float span = max(1.0 - stagger, 1e-3);
    float local = clamp((progress - r * stagger) / span, 0.0, 1.0);
    float t = ease(local, easeMode);
    // Ink (and its anti-aliased edges) fades; the cream page keeps its texture.
    if (luma < 0.6) { c = mix(c, page, t); }
    dst.write(c, gid);
}
