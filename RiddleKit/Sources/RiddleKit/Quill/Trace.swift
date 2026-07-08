import Foundation

/// Trace the skeleton into polyline strokes, ordered left-to-right so the
/// animation writes like a hand. Port of script.rs::trace.
public func trace(_ line: Line) -> [[(Int, Int)]] {
    let w = line.width, h = line.height
    func at(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && line.mask[y*w + x] }
    func nbrs(_ x: Int, _ y: Int) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for dy in -1...1 { for dx in -1...1 where dx != 0 || dy != 0 {
            if at(x+dx, y+dy) { out.append((x+dx, y+dy)) }
        } }
        return out
    }
    var visited = [Bool](repeating: false, count: w*h)
    var starts: [(Int, Int)] = []
    for y in 0..<h { for x in 0..<w where at(x, y) && nbrs(x, y).count == 1 { starts.append((x, y)) } }
    for y in 0..<h { for x in 0..<w where at(x, y) { starts.append((x, y)) } }

    var strokes: [[(Int, Int)]] = []
    for (sx, sy) in starts {
        if visited[sy*w + sx] { continue }
        var path = [(sx, sy)]; visited[sy*w + sx] = true
        var cx = sx, cy = sy
        while true {
            if let (nx, ny) = nbrs(cx, cy).first(where: { !visited[$0.1*w + $0.0] }) {
                visited[ny*w + nx] = true; path.append((nx, ny)); cx = nx; cy = ny
            } else { break }
        }
        if path.count >= 3 { strokes.append(path) }
    }
    strokes.sort { ($0.map { $0.0 }.min() ?? 0) < ($1.map { $0.0 }.min() ?? 0) }
    return strokes
}
