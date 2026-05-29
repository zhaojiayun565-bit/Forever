import Social
import SwiftData
import UIKit
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        guard let extensionContext else { return }

        guard let itemProvider = imageItemProvider(from: extensionContext) else {
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            guard error == nil, let imageData = Self.imageData(from: item) else {
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }

            Task { @MainActor in
                let cherishedText = CherishedText(
                    imageData: imageData,
                    extractedText: ""
                )

                let context = SharedDatabase.shared.mainContext
                context.insert(cherishedText)
                try? context.save()

                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
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

        if let url = item as? URL {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try? Data(contentsOf: url)
        }

        if let image = item as? UIImage {
            return image.jpegData(compressionQuality: 0.9)
        }

        return nil
    }
}
