import Foundation
import AppKit

/// Image conversion helpers. We normalize captured images to PNG so they can be
/// rendered, exported (base64) and re-copied consistently.
enum ImageHelper {

    /// Normalizes arbitrary image data (png/tiff/…) to PNG bytes.
    static func normalizedPNG(from data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return data }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return data
        }
        return png
    }

    static func image(from data: Data) -> NSImage? {
        NSImage(data: data)
    }

    /// Pixel dimensions of the image, if decodable.
    static func dimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return (rep.pixelsWide, rep.pixelsHigh)
    }
}
