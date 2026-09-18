import AppKit

enum BrandImages {
    static func image(named name: String) -> NSImage? {
        Bundle.main.image(forResource: name)
    }

    static func template(named name: String, size: NSSize) -> NSImage? {
        guard let image = image(named: name) else { return nil }
        image.size = size
        image.isTemplate = true
        return image
    }
}
