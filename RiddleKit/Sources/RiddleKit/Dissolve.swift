import Foundation

/// Deterministic per-pixel hash for the dissolve pattern. Port of ink.rs::px_hash.
public func pxHash(_ x: Int, _ y: Int) -> UInt32 {
    var h = UInt32(truncatingIfNeeded: x) &* 0x9E3779B1 ^ UInt32(truncatingIfNeeded: y) &* 0x85EBCA6B
    h ^= h >> 13
    h = h &* 0xC2B2AE35
    return h ^ (h >> 16)
}

/// Whether pixel (x,y) is scheduled to evaporate by `stage` of `stages`, from its
/// hash alone. This is the *pattern* half of ink.rs's dissolve_pass condition; the
/// caller ALSO gates on ink-ness (the Rust `luma < 250` — skip near-white pixels).
/// In this app that luma gate lives in the Metal shader (Dissolve.metal), so only
/// actual ink dissolves. Kept coordinate-only here so the speckle schedule stays
/// pure and unit-testable.
public func dissolves(x: Int, y: Int, stage: UInt32, stages: UInt32) -> Bool {
    pxHash(x, y) % stages <= stage
}
