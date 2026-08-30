import SwiftUI
import UIKit
import Vision
import XCTest

@testable import Via

@MainActor
final class MeetupLayoutRenderTests: XCTestCase {
    func testComposerKeepsArrivalCopyReadableAtPhoneWidth() throws {
        let rendering = try render(
            MeetupComposeView(
                model: makeModel(),
                displayName: "Camille",
                savedOrigins: [],
                onCreated: { _ in }
            ),
            width: 390,
            height: 1_150
        )
        let lines = try recognizedLines(in: rendering.image)

        XCTAssertTrue(
            lines.contains { $0.localizedCaseInsensitiveContains("Heure cible") },
            "La carte horaire a comprimé son libellé. Texte reconnu : \(lines)"
        )
        XCTAssertTrue(
            lines.contains { $0.localizedCaseInsensitiveContains("Via remonte le temps") },
            "La description de l’heure cible n’est plus lisible. Texte reconnu : \(lines)"
        )
    }

    func testPlaceCardKeepsCopyReadableAtCompactAccessibilityWidth() throws {
        let rendering = try render(
            MeetupPlaceCard(
                title: "Votre départ",
                name: "Choisir une origine",
                detail: "Les autres ne verront jamais cette adresse.",
                systemImage: "location.fill",
                onCurrentLocation: {}
            ) {},
            width: 320,
            height: 520,
            dynamicTypeSize: .accessibility2
        )
        let lines = try recognizedLines(in: rendering.image)
        let text = lines.joined(separator: " ")

        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Votre départ"),
            "Le titre de la carte de lieu a été comprimé. Texte reconnu : \(lines)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Choisir une origine"),
            "Le lieu sélectionné a été comprimé. Texte reconnu : \(lines)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Les autres ne verront jamais"),
            "La confidentialité du lieu n’est plus lisible. Texte reconnu : \(lines)"
        )
    }

    func testDetailExposesAnExplicitCloseAction() throws {
        let meetup = makeMeetup()
        let rendering = try render(
            NavigationStack {
                MeetupDetailView(
                    model: makeModel(meetups: [meetup]),
                    friendsModel: FriendsModel(repository: InMemoryFriendsRepository()),
                    isSignedIn: true,
                    initialMeetup: meetup,
                    onClose: {}
                )
            },
            width: 390,
            height: 844
        )
        let lines = try recognizedLines(in: rendering.image)

        XCTAssertTrue(
            lines.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "X" },
            "Le bouton de fermeture du détail a disparu. Texte reconnu : \(lines)"
        )
    }

    func testFriendsSummaryAndRowRemainReadableAtAccessibilitySize() throws {
        let date = Date(timeIntervalSince1970: 1_788_115_200)
        let friends = [
            ViaFriend(id: "alex", displayName: "Alexandra Martin", initials: "AM", createdAt: date),
            ViaFriend(id: "sam", displayName: "Samuel Bernard", initials: "SB", createdAt: date),
            ViaFriend(id: "lea", displayName: "Léa Robert", initials: "LR", createdAt: date),
        ]
        let rendering = try render(
            VStack(spacing: 20) {
                FriendsSummaryView(friends: friends)
                FriendRowView(friend: friends[0])
            }
            .padding(20),
            width: 320,
            height: 900,
            dynamicTypeSize: .accessibility2
        )
        let text = try recognizedLines(in: rendering.image).joined(separator: " ")

        XCTAssertTrue(text.localizedCaseInsensitiveContains("3 amis"), "Résumé Amis illisible : \(text)")
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Des liens privés"),
            "Description Amis illisible : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Alexandra Martin"),
            "Ligne d’ami illisible : \(text)"
        )
    }

    func testMeetupCardRemainsReadableAtAccessibilitySize() throws {
        let rendering = try render(
            MeetupCardView(
                meetup: makeMeetup(
                    destinationName: "Bibliothèque François Mitterrand",
                    phase: .planning
                )
            )
            .padding(20),
            width: 320,
            height: 820,
            dynamicTypeSize: .accessibility2
        )
        let text = try recognizedLines(in: rendering.image).joined(separator: " ")

        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Calcul en cours"),
            "Le statut du rendez-vous a été comprimé : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("20:40"),
            "L’heure du rendez-vous a disparu : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Bibliothèque François Mitterrand"),
            "La destination du rendez-vous a été comprimée : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("1 participant"),
            "Le nombre de participants a été comprimé : \(text)"
        )
    }

    func testLiveActionBarKeepsItsPrimaryActionReadableAtAccessibilitySize() throws {
        let rendering = try render(
            MeetupLiveActionBar(
                isLive: false,
                includesLiveActivity: false,
                isDisabled: false,
                onToggleLiveActivity: {},
                onToggleLive: {}
            ),
            width: 320,
            height: 360,
            dynamicTypeSize: .accessibility2
        )
        let text = try recognizedLines(in: rendering.image).joined(separator: " ")

        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Lancer mon trajet"),
            "L’action live a été comprimée : \(text)"
        )
    }

    func testParticipantCardRemainsReadableAtAccessibilitySize() throws {
        let participant = makeParticipant(displayName: "Alexandra Martin")
        let rendering = try render(
            MeetupParticipantRow(participant: participant, live: nil, onRemove: {}),
            width: 320,
            height: 760,
            dynamicTypeSize: .accessibility2
        )
        let text = try recognizedLines(in: rendering.image).joined(separator: " ")

        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Alexandra Martin"),
            "Le nom du participant a été comprimé : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Progression seule"),
            "Le niveau de partage a été comprimé : \(text)"
        )
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("Prêt à partir"),
            "L’état du participant a été comprimé : \(text)"
        )
    }

    func testComposerKeepsArrivalCopyReadableInDarkAppearance() throws {
        let rendering = try render(
            MeetupComposeView(
                model: makeModel(),
                displayName: "Camille",
                savedOrigins: [],
                onCreated: { _ in }
            ),
            width: 390,
            height: 1_150,
            colorScheme: .dark
        )
        let lines = try recognizedLines(in: rendering.image)

        XCTAssertTrue(
            lines.contains { $0.localizedCaseInsensitiveContains("Heure cible") },
            "La carte horaire sombre a comprimé son libellé. Texte reconnu : \(lines)"
        )
        XCTAssertTrue(
            lines.contains { $0.localizedCaseInsensitiveContains("Via remonte le temps") },
            "La description sombre n’est plus lisible. Texte reconnu : \(lines)"
        )
    }

    private func makeModel(meetups: [Meetup] = []) -> MeetupsModel {
        MeetupsModel(
            repository: InMemoryMeetupRepository(meetups: meetups),
            searchRepository: InMemorySearchRepository(),
            locationModel: LocationModel(adapter: InMemoryLocationAdapter()),
            live: NoOpMeetupLiveSharing()
        )
    }

    private func render<Content: View>(
        _ content: Content,
        width: CGFloat,
        height: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .large,
        colorScheme: ColorScheme = .light
    ) throws -> Rendering {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let root = content
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.colorScheme, colorScheme)

        let host = UIHostingController(rootView: root)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        let expectation = XCTestExpectation(description: "SwiftUI layout")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true

        let attachment = XCTAttachment(image: image)
        attachment.name = "Rendu \(Int(width))pt – \(dynamicTypeSize)"
        attachment.lifetime = .keepAlways
        add(attachment)

        return Rendering(image: try XCTUnwrap(image.cgImage))
    }

    private func recognizedLines(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["fr-FR"]
        request.usesLanguageCorrection = true

        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    private func makeMeetup(
        destinationName: String = "Châtelet",
        phase: MeetupPhase = .ready
    ) -> Meetup {
        let date = Date(timeIntervalSince1970: 1_788_115_200)
        let participant = makeParticipant()
        return Meetup(
            id: "rendez-vous",
            destination: MeetupStation(
                id: "chatelet",
                name: destinationName,
                coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
            ),
            targetArrivalAt: date,
            phase: phase,
            revision: 1,
            keyRevision: 1,
            currentParticipantId: participant.id,
            isOrganizer: true,
            participants: [participant],
            plan: nil,
            invitations: [],
            createdAt: date.addingTimeInterval(-3_600),
            updatedAt: date
        )
    }

    private func makeParticipant(displayName: String = "Camille") -> MeetupParticipant {
        let date = Date(timeIntervalSince1970: 1_788_115_200)
        return MeetupParticipant(
            id: "organizer",
            displayName: displayName,
            role: .organizer,
            state: .ready,
            shareLevel: .progressOnly,
            zone: .middle,
            firstBoardingStation: nil,
            departureAt: date.addingTimeInterval(-1_800),
            arrivalAt: date,
            createdAt: date.addingTimeInterval(-3_600),
            updatedAt: date
        )
    }

    private struct Rendering {
        let image: CGImage
    }
}
