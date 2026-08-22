import SwiftUI
import UIKit
import UserNotifications

/// The single place Via asks iOS for the notification permission.
///
/// Apple shows the system alert once per install and records the answer:
/// "Subsequent authorization requests don't prompt the person." So the ask has to
/// land where someone expresses the intent — Apple's own example is "after the
/// person schedules a first task" — and a refusal has to be named on the spot,
/// because no later call can bring the prompt back.
///
/// Granting also has to reach `PushNotificationManager` on the same turn. Routing
/// every ask through here is what registers the APNs token on the grant itself
/// rather than on the next foreground, which is the difference between a follow
/// that starts working and one that waits for the app to be backgrounded.
enum NotificationAuthorization {
    /// `false` means iOS will not deliver: either the person just declined, or the
    /// status was already denied and the prompt can no longer be shown.
    @MainActor
    @discardableResult
    static func request(
        center: any JourneyNotificationCenterClient = SystemJourneyNotificationCenter(),
        push: PushNotificationManager = .shared
    ) async -> Bool {
        let granted: Bool
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .notDetermined:
            granted = (try? await center.requestAuthorization()) ?? false
        default:
            granted = false
        }
        await push.setNotificationsAuthorized(granted)
        return granted
    }
}

/// The one way a screen offers the ask. The wording, the glyph and the style
/// live here so three settings screens cannot word the same offer differently,
/// and `refresh` is what each screen does with the answer — the ask itself is
/// never the caller's to spell.
struct NotificationAuthorizationButton: View {
    var refresh: () async -> Void = {}

    var body: some View {
        Button("Autoriser les notifications", systemImage: "bell.badge") {
            Task {
                await NotificationAuthorization.request()
                await refresh()
            }
        }
        .primaryAction()
    }
}

/// Raises the prompt when `isRequested` flips true, and names the dead end when
/// the answer is no. The way out is iOS Settings — there is no in-app second ask.
private struct NotificationAuthorizationModifier: ViewModifier {
    @Binding var isRequested: Bool
    let message: String

    @Environment(\.openURL) private var openURL
    @State private var isDeniedPresented = false

    func body(content: Content) -> some View {
        content
            .task(id: isRequested) {
                guard isRequested else { return }
                isRequested = false
                isDeniedPresented = await NotificationAuthorization.request() == false
            }
            .alert("Notifications désactivées", isPresented: $isDeniedPresented) {
                Button("Ouvrir les réglages iOS") { openURL.systemSettings() }
                Button("OK", role: .cancel) {}
            } message: {
                Text(message)
            }
    }
}

extension OpenURLAction {
    /// Via's page in iOS Settings — the only way back once iOS has recorded a
    /// refusal, and so the same two lines at every dead end that names it.
    func systemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        callAsFunction(url)
    }
}

extension View {
    /// Attach to any control that turns a Via notification on.
    func notificationAuthorization(
        isRequested: Binding<Bool>,
        message: String
    ) -> some View {
        modifier(NotificationAuthorizationModifier(isRequested: isRequested, message: message))
    }
}
