import Foundation

/// External support links are injected at the composition root so views never
/// need to know deployment configuration or expose `VIA_API_BASE_URL`.
struct SupportDestinations: Sendable {
    let faq: URL?
    let feedback: URL?
    let privacy: URL?
    let terms: URL?

    init(faq: URL?, feedback: URL?, privacy: URL?, terms: URL?) {
        self.faq = faq
        self.feedback = feedback
        self.privacy = privacy
        self.terms = terms
    }

    static let preview = SupportDestinations(
        faq: URL(string: "https://via.example.com/faq"),
        feedback: URL(string: "mailto:bonjour@via.example.com"),
        privacy: URL(string: "https://via.example.com/confidentialite"),
        terms: URL(string: "https://via.example.com/conditions")
    )

    static let app = SupportDestinations(
        faq: URL(string: "https://via.app/faq"),
        feedback: URL(string: "mailto:bonjour@via.app"),
        privacy: URL(string: "https://via.app/confidentialite"),
        terms: URL(string: "https://via.app/conditions")
    )
}
