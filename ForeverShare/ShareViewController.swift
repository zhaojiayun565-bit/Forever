import Social
import SwiftData
import UIKit
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        // Prevent default dismissal; we complete the request manually after processing.
        guard let extensionContext else { return }

        guard let itemProvider = imageItemProvider(from: extensionContext) else {
            extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            Task { @MainActor in
                defer {
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }

                guard error == nil, let imageData = Self.imageData(from: item) else { return }

                do {
                    let extractedText = try await VisionHelper.extractText(from: imageData)
                    let cherishedText = CherishedText(
                        imageData: imageData,
                        extractedText: extractedText
                    )

                    let context = SharedDatabase.shared.mainContext
                    context.insert(cherishedText)
                    try context.save()
                } catch {
                    // OCR or persistence failed; defer still dismisses the extension.
                }
            }
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }

    /// Returns the first attachment that conforms to an image type.
    private func imageItemProvider(from extensionContext: NSExtensionContext) -> NSItemProvider? {
        guard let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return provider
            }
        }

        return nil
    }

    /// Normalizes share-sheet payloads into raw image bytes.
    private static func imageData(from item: NSSecureCoding?) -> Data? {
        if let data = item as? Data {
            return data
        }

        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return data
        }

        if let image = item as? UIImage {
            return image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        }

        return nil
    }
}
