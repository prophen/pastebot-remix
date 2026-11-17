import Foundation
import ClipboardCore

func testPaletteGeometry() {
    let main = CGRect(x: 0, y: 30, width: 1440, height: 870)
    let second = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    let saved = CGRect(x: -1800, y: 100, width: 1000, height: 700)
    expectEqual(PaletteGeometry.restore(saved, screens: [main, second]), saved)
    let recovered = PaletteGeometry.restore(saved, screens: [main])!
    expectTrue(main.contains(recovered))
    expectEqual(recovered.size, saved.size)
    expectEqual(PaletteGeometry.restore(recovered, screens: [main]), recovered)
    let first = PaletteGeometry.restore(nil, screens: [main])!
    expectEqual(first.midX, main.midX); expectEqual(first.midY, main.midY)
    let oversized = CGRect(x: 1200, y: 800, width: 3000, height: 2000)
    expectEqual(PaletteGeometry.restore(oversized, screens: [main]), main)
    let small = CGRect(x: 0, y: 0, width: 640, height: 400)
    expectEqual(PaletteGeometry.restore(saved, screens: [small]), small)
    let invalid = CGRect(x: CGFloat.nan, y: 0, width: 0, height: 20)
    expectEqual(PaletteGeometry.restore(invalid, screens: [main]), first)
    expectEqual(PaletteGeometry.restore(saved, screens: []), nil)
}
