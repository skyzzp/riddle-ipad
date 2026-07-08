import Foundation

/// Zhang-Suen thinning: reduce the mask to a 1px skeleton. Port of script.rs::thin.
public func thin(_ line: inout Line) {
    let w = line.width, h = line.height
    guard w >= 3, h >= 3 else { return }
    func idx(_ x: Int, _ y: Int) -> Int { y*w + x }
    while true {
        var changed = false
        for phase in 0..<2 {
            var toClear: [Int] = []
            for y in 1..<(h-1) {
                for x in 1..<(w-1) {
                    if !line.mask[idx(x, y)] { continue }
                    let p = [
                        line.mask[idx(x, y-1)], line.mask[idx(x+1, y-1)], line.mask[idx(x+1, y)],
                        line.mask[idx(x+1, y+1)], line.mask[idx(x, y+1)], line.mask[idx(x-1, y+1)],
                        line.mask[idx(x-1, y)], line.mask[idx(x-1, y-1)],
                    ]
                    let b = p.reduce(0) { $0 + ($1 ? 1 : 0) }
                    if b < 2 || b > 6 { continue }
                    var a = 0
                    for i in 0..<8 where !p[i] && p[(i+1) % 8] { a += 1 }
                    if a != 1 { continue }
                    let c1: Bool, c2: Bool
                    if phase == 0 { c1 = !(p[0] && p[2] && p[4]); c2 = !(p[2] && p[4] && p[6]) }
                    else          { c1 = !(p[0] && p[2] && p[6]); c2 = !(p[0] && p[4] && p[6]) }
                    if c1 && c2 { toClear.append(idx(x, y)) }
                }
            }
            if !toClear.isEmpty { changed = true; for i in toClear { line.mask[i] = false } }
        }
        if !changed { break }
    }
}
