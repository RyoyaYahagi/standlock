import AppKit

@main
struct MenuBarIconChecks {
    @MainActor
    static func main() {
        let empty = pixels(progress: 0, isEnabled: true)
        let partial = pixels(progress: 0.5, isEnabled: true)
        let full = pixels(progress: 1, isEnabled: true)
        let disabled = pixels(progress: 0, isEnabled: false)

        precondition(empty != partial && partial != full, "Progress must change the icon")
        precondition(disabled != empty && disabled != full, "OFF must have its own icon")
        precondition(disabled == pixels(progress: 1, isEnabled: false), "OFF must ignore progress")
        precondition(empty == pixels(progress: -1, isEnabled: true), "Negative progress must clamp")
        precondition(full == pixels(progress: 2, isEnabled: true), "Overflow progress must clamp")
    }

    @MainActor
    private static func pixels(progress: Double, isEnabled: Bool) -> [UInt8] {
        // MenuBarExtra needs an Image label; a custom Shape hierarchy is not a
        // replacement for this template image, even when the app remains alive.
        let image: NSImage = MenuBarIcon.make(progress: progress, isEnabled: isEnabled)
        precondition(image.isTemplate, "The menu bar must adapt to light and dark appearances")
        precondition(image.size == NSSize(width: 18, height: 18), "Keep a standard menu bar size")
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            preconditionFailure("The icon must be renderable as an image")
        }

        var alpha: [UInt8] = []
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let opacity = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                alpha.append(UInt8((opacity * 255).rounded()))
            }
        }
        precondition(alpha.contains(where: { $0 > 0 }), "The icon must not be invisible")
        return alpha
    }
}
