import AppKit

public enum FlickApp {
    public static let bundleID = "dev.abhijitsr.flick"
    public static let name = "Flick"

    /// Strong retain — `NSApplication.delegate` is weak.
    private static var delegate: AppDelegate?

    @MainActor
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
