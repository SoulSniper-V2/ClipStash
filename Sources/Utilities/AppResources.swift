import AppKit
import Foundation

/// Xcode compiles the catalog; the SwiftPM command-line build copies the catalog.
enum AppResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    static var logo: NSImage? {
        #if SWIFT_PACKAGE
        guard let url = bundle.url(
            forResource: "app-logo@2x",
            withExtension: "png",
            subdirectory: "Assets.xcassets/AppLogo.imageset"
        ) else { return nil }
        return NSImage(contentsOf: url)
        #else
        return bundle.image(forResource: "AppLogo")
        #endif
    }
}
