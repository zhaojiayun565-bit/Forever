import Social
import SwiftData
import UIKit
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        Task { @MainActor in
            if let imageData = await extractImageData(from: extensionContext) {
                do {
                    let extractedText = try await VisionHelper.extractText(from: imageData)
                    let cherishedText = CherishedText(
                        imageData: imageData,
                        extractedText: extractedText
                    )

                    let context = SharedDatabase.context
                    context.insert(cherishedText)
                    try context.save()
                } catch {
                    // OCR or persistence failed; still dismiss the extension.
                }
            }

            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }

    /// Loads the first image attachment from the share extension context.
    @MainActor
    private func extractImageData(from extensionContext: NSExtensionContext?) async -> Data? {
        guard
            let inputItems = extensionContext?.inputItems as? [NSExtensionItem]
        else {
            return nil
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                do {
                    return try await provider.loadDataRepresentation(for: UTType.image)
                } catch {
                    continue
                }
            }
        }

        return nil
    }
}
