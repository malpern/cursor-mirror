import Foundation
import AppKit
import CoreImage

/// Utility class for generating QR codes from text or URLs
class QRCodeGenerator {
    /// Generate an NSImage containing a QR code from the given text
    /// - Parameters:
    ///   - text: The text to encode in the QR code
    ///   - size: The desired size of the QR code image (default: 200)
    ///   - correctionLevel: The error correction level (L, M, Q, H - default: M)
    /// - Returns: An NSImage containing the QR code, or nil if generation failed
    static func generateQRCode(from text: String, size: CGFloat = 200, correctionLevel: String = "M") -> NSImage? {
        guard !text.isEmpty, let data = text.data(using: .utf8) else {
            return nil
        }
        
        // Create the QR code filter
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        
        // Set the filter inputs
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        
        // Get the output image
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // Calculate the scale to achieve desired size
        let scale = size / outputImage.extent.width
        
        // Scale the image
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Convert to NSImage
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        
        return nsImage
    }
    
    /// Generate an NSImage containing a QR code from the given URL
    /// - Parameters:
    ///   - url: The URL to encode in the QR code
    ///   - size: The desired size of the QR code image
    ///   - correctionLevel: The error correction level (L, M, Q, H)
    /// - Returns: An NSImage containing the QR code, or nil if generation failed
    static func generateQRCode(from url: URL, size: CGFloat = 200, correctionLevel: String = "M") -> NSImage? {
        return generateQRCode(from: url.absoluteString, size: size, correctionLevel: correctionLevel)
    }
    
    /// Generate a styled QR code with a logo overlay
    /// - Parameters:
    ///   - text: The text to encode in the QR code
    ///   - size: The desired size of the QR code image
    ///   - logo: An optional logo to place in the center of the QR code
    ///   - logoSize: The relative size of the logo (0.0-1.0)
    ///   - foregroundColor: The foreground color of the QR code
    ///   - backgroundColor: The background color of the QR code
    /// - Returns: An NSImage containing the styled QR code, or nil if generation failed
    static func generateStyledQRCode(
        from text: String,
        size: CGFloat = 200,
        logo: NSImage? = nil,
        logoSize: CGFloat = 0.2,
        foregroundColor: NSColor = .black,
        backgroundColor: NSColor = .white
    ) -> NSImage? {
        // Generate basic QR code
        guard let qrImage = generateQRCode(from: text, size: size) else {
            return nil
        }
        
        // Create a new image with the specified colors
        let imageSize = NSSize(width: size, height: size)
        let resultImage = NSImage(size: imageSize)
        
        resultImage.lockFocus()
        
        // Draw background
        backgroundColor.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        
        // Draw QR code with foreground color
        let qrImageRep = qrImage.bestRepresentation(for: NSRect(x: 0, y: 0, width: size, height: size), context: nil, hints: nil)
        foregroundColor.set()
        
        if let rep = qrImageRep {
            NSGraphicsContext.current?.imageInterpolation = .none
            rep.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        }
        
        // Add logo if provided
        if let logo = logo {
            let logoWidth = size * logoSize
            let logoHeight = size * logoSize
            let logoX = (size - logoWidth) / 2
            let logoY = (size - logoHeight) / 2
            
            // Draw white background behind logo
            NSColor.white.setFill()
            NSRect(x: logoX - 2, y: logoY - 2, width: logoWidth + 4, height: logoHeight + 4).fill()
            
            // Draw logo
            logo.draw(in: NSRect(x: logoX, y: logoY, width: logoWidth, height: logoHeight),
                      from: NSRect(x: 0, y: 0, width: logo.size.width, height: logo.size.height),
                      operation: .sourceOver,
                      fraction: 1.0)
        }
        
        resultImage.unlockFocus()
        
        return resultImage
    }
} 