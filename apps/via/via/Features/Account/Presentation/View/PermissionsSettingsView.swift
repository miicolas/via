import AVFoundation
import Contacts
import SwiftUI
import UIKit

struct PermissionsSettingsView: View {
    let locationModel: LocationModel
    let journeyNotificationCoordinator: JourneyNotificationCoordinator

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                permissionRow(
                    title: "Localisation",
                    systemImage: "location.fill",
                    status: locationStatus
                )
                permissionRow(
                    title: "Caméra",
                    systemImage: "camera.fill",
                    status: cameraStatus
                )
                permissionRow(
                    title: "Contacts",
                    systemImage: "person.crop.rectangle.stack.fill",
                    status: contactsStatus
                )
                permissionRow(
                    title: "Notifications",
                    systemImage: "bell.fill",
                    status: notificationStatus
                )
            } footer: {
                Text("Metyro demande chaque autorisation uniquement au moment où la fonctionnalité en a besoin.")
            }

            if journeyNotificationCoordinator.authorizationStatus == .notDetermined {
                Section {
                    Button("Autoriser les notifications", systemImage: "bell.badge") {
                        Task { await journeyNotificationCoordinator.requestAuthorization() }
                    }
                    .primaryAction()
                }
            }

            Section {
                Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                    openSettings()
                }
            }
        }
        .navigationTitle("Autorisations iOS")
        .navigationBarTitleDisplayMode(.large)
        .id(scenePhase)
        .task { await journeyNotificationCoordinator.refreshAuthorizationStatus() }
    }

    private func permissionRow(title: String, systemImage: String, status: PermissionStatus) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .frame(width: 26)
            Text(title)
            Spacer()
            Text(status.title)
                .foregroundStyle(status.color)
        }
        .frame(minHeight: 44)
    }

    private var locationStatus: PermissionStatus {
        switch locationModel.authorization {
        case .authorized: .authorized
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    private var cameraStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    private var contactsStatus: PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: .authorized
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    private var notificationStatus: PermissionStatus {
        switch journeyNotificationCoordinator.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .authorized
        case .notDetermined: .notRequested
        case .denied: .denied
        @unknown default: .restricted
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private enum PermissionStatus {
    case authorized
    case notRequested
    case denied
    case restricted

    var title: String {
        switch self {
        case .authorized: "Autorisé"
        case .notRequested: "Non demandé"
        case .denied: "Refusé"
        case .restricted: "Limité"
        }
    }

    var color: Color {
        switch self {
        case .authorized: .green
        case .notRequested: .secondary
        case .denied, .restricted: .orange
        }
    }
}
