import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Wraps a rendered quote card so it can be handed to `ShareLink`.
struct ShareableQuoteImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            shareable.image.pngData() ?? Data()
        }
    }
}

@MainActor
enum QuoteCardRenderer {
    /// Renders the premium quote card to a UIImage, or nil if rendering fails.
    static func render(_ quote: Quote) -> UIImage? {
        let renderer = ImageRenderer(content: QuoteCardView(quote: quote))
        renderer.scale = 2
        return renderer.uiImage
    }
}
