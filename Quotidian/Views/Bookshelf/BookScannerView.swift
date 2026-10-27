import SwiftUI
import UIKit
import Vision
import VisionKit

/// Point the camera at a book's barcode to add it to your shelf.
/// Looks the ISBN up on Open Library, then hands back the result.
struct BookScannerView: View {
    let onFound: (BookSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status: Status = .scanning
    @State private var lastISBN: String?

    enum Status: Equatable {
        case scanning
        case lookingUp
        case notFound
        case failed
    }

    private var canScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if canScan {
                    BarcodeScanner { code in handle(code) }
                        .ignoresSafeArea()

                    VStack {
                        Spacer()
                        statusCard
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                    }
                } else {
                    unavailable
                }
            }
            .navigationTitle("Scan a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            switch status {
            case .scanning:
                Image(systemName: "barcode.viewfinder")
                Text("Point at the barcode on the back of the book.")
            case .lookingUp:
                ProgressView().tint(Theme.accent)
                Text("Looking it up\u{2026}")
            case .notFound:
                Image(systemName: "questionmark.circle")
                Text("Couldn't find that book. Try another barcode, or use Search instead.")
            case .failed:
                Image(systemName: "wifi.exclamationmark")
                Text("Couldn't look that up. Check your connection and scan again.")
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.textPrimary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface.opacity(0.95)))
    }

    private var unavailable: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accentDim)
            Text("Scanning isn't available")
                .font(Theme.Font.serif(20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("This needs the camera on an iPhone (it doesn't work in the Simulator). If you turned off camera access, you can turn it back on in Settings \u{2192} Quotidian. You can always add books with Search.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    /// Book barcodes are EAN-13 codes starting 978 or 979 (the ISBN).
    private func handle(_ code: String) {
        let digits = code.filter(\.isNumber)
        guard status != .lookingUp,
              digits.count == 13,
              digits.hasPrefix("978") || digits.hasPrefix("979"),
              digits != lastISBN else { return }
        lastISBN = digits
        status = .lookingUp
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            do {
                if let result = try await BookSearch.lookup(isbn: digits) {
                    onFound(result)
                    dismiss()
                } else {
                    status = .notFound
                    lastISBN = nil
                }
            } catch {
                status = .failed
                lastISBN = nil
            }
        }
    }
}

/// VisionKit's live barcode scanner, wrapped for SwiftUI.
private struct BarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !controller.isScanning { try? controller.startScanning() }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    onCode(value)
                    return
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                onCode(value)
            }
        }
    }
}
