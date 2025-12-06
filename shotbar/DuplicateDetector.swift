import Foundation
import CoreGraphics
import AppKit

/// Protocol for detecting duplicate images.
/// Designed to be portable and swappable for future implementations (e.g., AI/ML-based).
protocol DuplicateDetecting {
    /// Resets the internal state (e.g., clears the previous image reference).
    /// Should be called when starting a new capture session.
    func reset()

    /// Checks if the provided image is a duplicate of the previously processed image.
    /// - Parameter image: The new image to check.
    /// - Returns: `true` if the image is considered a duplicate, `false` otherwise.
    func isDuplicate(_ image: CGImage) async -> Bool
}

/// A duplicate detector that checks for an exact binary match of the PNG representation.
class ExactMatchDuplicateDetector: DuplicateDetecting {
    private var lastImageData: Data?

    func reset() {
        lastImageData = nil
    }

    func isDuplicate(_ image: CGImage) async -> Bool {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        // Convert to PNG data for exact comparison.
        // Note: This conversion is computationally expensive.
        guard let currentData = bitmapRep.representation(using: .png, properties: [:]) else {
            // If conversion fails, we assume it's not a duplicate to be safe.
            return false
        }

        if let lastData = lastImageData, lastData == currentData {
            return true
        }

        // Update state with the new image data
        lastImageData = currentData
        return false
    }
}
