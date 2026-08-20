import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let imageData: Data?
    let displayName: String
    var size: CGFloat = 36
    /// The ring separates the avatar from a photo or a colored header; over the
    /// glass of a toolbar it only adds a hard edge.
    var isBordered: Bool = true

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials {
                ZStack {
                    LinearGradient(
                        colors: [.blue.opacity(0.95), .cyan.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if isBordered {
                Circle().stroke(.background, lineWidth: size > 50 ? 3 : 1.5)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var initials: String? {
        let value = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? nil : value
    }

    private var accessibilityLabel: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Photo de profil non définie"
            : "Photo de profil de \(displayName)"
    }
}
