import AVFoundation
import Contacts
import SwiftUI

struct PermissionsSettingsView: View {
    let locationModel: LocationModel

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
            } footer: {
                Text("Metyro demande chaque autorisation uniquement au moment où la fonctionnalité en a besoin.")
            }

            Section {
                Button("Ouvrir les réglages iOS", systemImage: "gearshape") {
                    openURL.systemSettings()
                }
                .secondaryAction()
            }
        }
        .navigationTitle("Autorisations iOS")
        .toolbarTitleDisplayMode(.inlineLarge)
        .id(scenePhase)
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
