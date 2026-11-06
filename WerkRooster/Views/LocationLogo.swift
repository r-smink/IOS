import SwiftUI
import UIKit

/// Brand logo for a location, based on its name (e.g. "Esso Isselt", "Shell Serva").
/// Renders nothing when the location has no known brand.
struct LocationLogo: View {
    let locationName: String?
    var size: CGFloat = 20

    static func imageName(for locationName: String?) -> String? {
        guard let name = locationName?.lowercased() else { return nil }
        if name.contains("esso") { return "logo_esso" }
        if name.contains("shell") { return "logo_shell" }
        return nil
    }

    var body: some View {
        if let name = Self.imageName(for: locationName), let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(locationName ?? "")
        }
    }
}
