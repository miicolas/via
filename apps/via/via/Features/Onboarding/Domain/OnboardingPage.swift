import SwiftUI
import UIKit

/// The screenshots the first-run carousel walks through, in order.
enum OnboardingPage: Int, CaseIterable, Hashable {
    case welcome
    case stations
    case disruptions
    case intelligentSearch
    case preferences
    case liveActivity

    var title: String {
        switch self {
        case .welcome: "Bienvenue dans Metyro"
        case .stations: "Tes stations en direct"
        case .disruptions: "Anticipe les perturbations"
        case .intelligentSearch: "Décris simplement ton trajet"
        case .preferences: "Tes préférences, ton trajet"
        case .liveActivity: "Gère ton trajet en direct"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "Tes trajets franciliens, plus simples et plus intelligents."
        case .stations:
            "Repère les stations proches et consulte les prochains passages."
        case .disruptions:
            "Visualise l’état des lignes et les travaux avant de partir."
        case .intelligentSearch:
            "Metyro comprend les lieux, l’heure et les transports à éviter."
        case .preferences:
            "Préfère ou évite certains transports et demande un trajet PMR via des stations accessibles."
        case .liveActivity:
            "Suis ta progression, les prochaines étapes et les correspondances jusqu’à l’arrivée."
        }
    }

    var assetName: String {
        switch self {
        case .welcome: "OnboardingWelcome"
        case .stations: "OnboardingStations"
        case .disruptions: "OnboardingDisruptions"
        case .intelligentSearch: "OnboardingAI"
        case .preferences: "OnboardingPreferences"
        case .liveActivity: "OnboardingLiveActivity"
        }
    }

    var screenshot: UIImage? {
        UIImage(named: assetName)
    }

    /// Every page is the same device capture, so the carousel can lay itself
    /// out from the ratio instead of measuring what it draws — a box that
    /// sizes itself from its own first layout pass freezes the plateau's
    /// height before the panel below has one.
    static let screenshotAspectRatio: CGFloat = {
        guard let size = OnboardingPage.welcome.screenshot?.size, size.height > 0 else { return 1 }
        return size.width / size.height
    }()

    /// The 180 pt of device corner the capture carries in its own pixel space,
    /// held as a fraction of its height so the clip follows however large the
    /// carousel ends up drawn.
    static let screenshotCornerRatio: CGFloat = {
        guard let size = OnboardingPage.welcome.screenshot?.size, size.height > 0 else { return 0 }
        return 180 / size.height
    }()

    var isFinal: Bool {
        self == Self.allCases.last
    }

    var zoomScale: CGFloat {
        switch self {
        case .welcome, .liveActivity: 1
        case .stations: 1.15
        case .disruptions: 1.2
        case .intelligentSearch, .preferences: 1.08
        }
    }

    var zoomAnchor: UnitPoint {
        switch self {
        case .welcome, .liveActivity: .center
        case .stations: UnitPoint(x: 0.5, y: 0.75)
        case .disruptions: UnitPoint(x: 0.5, y: 0.25)
        case .intelligentSearch: .center
        case .preferences: UnitPoint(x: 0.5, y: 0.38)
        }
    }
}
