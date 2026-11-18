import Foundation

/// Runtime locations are account-relative, independent of the source/build volume.
public enum AppLocations {
    public static var dataDirectory: URL {
        dataDirectory(applicationSupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
    }
    public static func dataDirectory(applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent("ClipboardRemix", isDirectory: true)
    }
    public static var dragExportDirectory: URL {
        dataDirectory.appendingPathComponent("DragExports", isDirectory: true)
    }
    public static func supportsLogin(bundleURL: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let bundle = bundleURL.resolvingSymlinksInPath().standardizedFileURL
        guard bundle.pathExtension.lowercased() == "app" else { return false }
        let parent = bundle.deletingLastPathComponent().path
        return [URL(fileURLWithPath: "/Applications", isDirectory: true),
                home.appendingPathComponent("Applications", isDirectory: true)].contains {
            $0.resolvingSymlinksInPath().standardizedFileURL.path == parent
        }
    }
}
