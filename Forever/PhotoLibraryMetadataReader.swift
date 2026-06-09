import CoreLocation
import Photos

struct PhotoLibraryAssetMetadata {
    var coordinate: CLLocationCoordinate2D?
    var creationDate: Date?
}

enum PhotoLibraryMetadataReader {
    /// Reads location and capture date from the first asset matching a picker item identifier.
    static func metadata(forItemIdentifiers identifiers: [String]) -> PhotoLibraryAssetMetadata {
        for localId in identifiers {
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil).firstObject
            guard let asset else { continue }

            return PhotoLibraryAssetMetadata(
                coordinate: asset.location?.coordinate,
                creationDate: asset.creationDate
            )
        }
        return PhotoLibraryAssetMetadata()
    }
}
