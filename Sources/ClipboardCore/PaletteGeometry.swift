import Foundation
import CoreGraphics

/// Pure geometry policy, also used when the display arrangement changes.
public enum PaletteGeometry {
    public static func restore(_ saved: CGRect?, screens: [CGRect], minimum: CGSize = CGSize(width: 740, height: 490)) -> CGRect? {
        let screens = screens.filter { $0.width > 0 && $0.height > 0 }
        guard let primary = screens.first else { return nil }
        let valid = saved.flatMap { frame -> CGRect? in
            guard [frame.origin.x, frame.origin.y, frame.width, frame.height].allSatisfy({ $0.isFinite }),
                  frame.width > 0, frame.height > 0 else { return nil }
            return frame
        }
        let screen = valid.flatMap { frame in
            screens.max { a, b in
                let ai = a.intersection(frame), bi = b.intersection(frame)
                return (ai.isNull ? 0 : ai.width * ai.height) < (bi.isNull ? 0 : bi.width * bi.height)
            }.flatMap { $0.intersects(frame) ? $0 : nil }
        } ?? primary
        let size = CGSize(width: min(screen.width, max(minimum.width, valid?.width ?? 800)),
                          height: min(screen.height, max(minimum.height, valid?.height ?? 552)))
        let origin = valid?.origin ?? CGPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        return CGRect(x: min(max(origin.x, screen.minX), screen.maxX - size.width),
                      y: min(max(origin.y, screen.minY), screen.maxY - size.height),
                      width: size.width, height: size.height)
    }
}
