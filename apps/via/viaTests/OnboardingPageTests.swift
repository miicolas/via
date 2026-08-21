import UIKit
import XCTest
@testable import Via

final class OnboardingPageTests: XCTestCase {
    func testPagesUseTheExpectedOrderAndContent() {
        let pages = OnboardingPage.allCases

        XCTAssertEqual(
            pages,
            [.welcome, .stations, .disruptions, .intelligentSearch, .preferences, .liveActivity]
        )
        XCTAssertEqual(
            pages.map(\.title),
            [
                "Bienvenue dans Metyro",
                "Tes stations en direct",
                "Anticipe les perturbations",
                "Décris simplement ton trajet",
                "Tes préférences, ton trajet",
                "Gère ton trajet en direct",
            ]
        )
        XCTAssertEqual(
            pages.map(\.subtitle),
            [
                "Tes trajets franciliens, plus simples et plus intelligents.",
                "Repère les stations proches et consulte les prochains passages.",
                "Visualise l’état des lignes et les travaux avant de partir.",
                "Metyro comprend les lieux, l’heure et les transports à éviter.",
                "Préfère ou évite certains transports et demande un trajet PMR via des stations accessibles.",
                "Suis ta progression, les prochaines étapes et les correspondances jusqu’à l’arrivée.",
            ]
        )
    }

    func testEveryPageHasItsScreenshotAsset() {
        for page in OnboardingPage.allCases {
            XCTAssertNotNil(page.screenshot, "Asset manquant : \(page.assetName)")
        }
    }

    func testOnlyTheLastPageCompletesOnAdvance() {
        let pages = OnboardingPage.allCases

        XCTAssertTrue(pages.dropLast().allSatisfy { !$0.isFinal })
        XCTAssertTrue(pages.last?.isFinal == true)
    }
}
