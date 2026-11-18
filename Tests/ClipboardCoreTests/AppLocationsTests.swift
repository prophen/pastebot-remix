import Foundation
import ClipboardCore

func testPortableLocations() async throws {
    let fixture = checkTemporaryDirectory.appendingPathComponent("portable-locations-\(UUID())", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: fixture) }
    let home = fixture.appendingPathComponent("Different User", isDirectory: true)
    let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
    let expectedData = support.appendingPathComponent("ClipboardRemix", isDirectory: true)
    expectEqual(AppLocations.dataDirectory(applicationSupport: support), expectedData)
    expectTrue(AppLocations.supportsLogin(bundleURL: URL(fileURLWithPath: "/Applications/Clipboard Remix.app"), home: home))
    expectTrue(AppLocations.supportsLogin(bundleURL: home.appendingPathComponent("Applications/Clipboard Remix.app"), home: home))
    for path in ["Downloads/Clipboard Remix.app", "Applications Backup/Clipboard Remix.app",
                 "Applications/Clipboard Remix.app/Contents", "Applications/not-an-app",
                 "Applications/nested/Clipboard Remix.app"] {
        expectFalse(AppLocations.supportsLogin(bundleURL: home.appendingPathComponent(path), home: home))
    }
    expectFalse(AppLocations.supportsLogin(bundleURL: fixture.appendingPathComponent("Other User/Applications/Clipboard Remix.app"), home: home))
    let exports = PNGDragExportStore(root: expectedData.appendingPathComponent("DragExports", isDirectory: true), createParentDirectory: true)
    let png = try HistoryStoreTests().png()
    let first = try await exports.export(png)
    let second = try await exports.export(png)
    expectEqual(try Data(contentsOf: first), png)
    expectEqual(try Data(contentsOf: second), png)
    expectTrue(first.path.hasPrefix(expectedData.path + "/DragExports/"))
    await exports.finish(first)
    await exports.finish(second)
}
