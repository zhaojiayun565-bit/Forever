import Photos

/// Handles photo library permission for gallery uploads and GPS metadata access.
@MainActor
enum PhotoLibraryAuthorizationManager {
    /// Shows the system photo library prompt when status is not yet determined.
    static func requestIfNeeded() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
