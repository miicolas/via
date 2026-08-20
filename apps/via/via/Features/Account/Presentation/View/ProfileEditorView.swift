import AVFoundation
import Contacts
import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditorView: View {
    @Bindable var model: ProfileModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isPhotosPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isContactPickerPresented = false
    @State private var presentedAlert: PresentedAlert?
    @State private var hasPreparedDraft = false
    /// The form is short, so the sheet is sized to it instead of opening on a
    /// mostly empty screen.
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ProfileHeroView()

                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Text("Modifier le profil")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)

                            Text("Personnalise la façon dont tu apparais dans Via.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        avatarMenu

                        TextField("Ton nom", text: $model.draftName)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .padding(.horizontal)

                        if let errorMessage = model.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            guard model.saveEditing() else { return }
                            dismiss()
                        } label: {
                            Text("Terminer")
                                .font(.headline)
                        }
                        .primaryAction()
                        .disabled(!model.canSaveDraft)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { close() }
                }
            }
        }
        .presentationDetents(detents)
        .onAppear {
            guard !hasPreparedDraft else { return }
            hasPreparedDraft = true
            model.beginEditing()
        }
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await importPhoto(item)
                // Remis à zéro pour que rechoisir la même photo redéclenche l'import.
                selectedPhoto = nil
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker { image in
                isCameraPresented = false
                guard let image, let data = ProfileImageProcessor.normalizedJPEG(from: image) else {
                    return
                }
                model.setAvatarData(data)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPicker { contact in
                isContactPickerPresented = false
                guard var contact else { return }
                if let data = contact.avatarData {
                    contact.avatarData = ProfileImageProcessor.normalizedJPEG(from: data)
                }
                model.importContact(contact)
            }
        }
        .alert(item: $presentedAlert) { alert in
            if alert.offersSettings {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Ouvrir Réglages")) { openAppSettings() },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(title: Text(alert.title), message: Text(alert.message))
            }
        }
    }

    /// `.large` stays in the set so the keyboard and the largest Dynamic Type
    /// sizes still have somewhere to grow.
    private var detents: Set<PresentationDetent> {
        contentHeight > 0 ? [.height(contentHeight), .large] : [.large]
    }

    private var avatarMenu: some View {
        Menu {
            Button(action: requestCamera) {
                Label("Prendre une photo", systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button {
                isPhotosPickerPresented = true
            } label: {
                Label("Choisir dans Photos", systemImage: "photo.on.rectangle.angled")
            }

            Button {
                requestContacts()
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Remplir depuis Contacts")
                        Text("Recommandé")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.text.rectangle")
                }
            }
        } label: {
            ProfileAvatarView(
                imageData: model.draftAvatarData,
                displayName: model.draftName,
                size: 104
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: model.draftAvatarData == nil ? "plus" : "pencil")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.blue, in: Circle())
                    .overlay(Circle().stroke(.background, lineWidth: 3))
            }
            .frame(minWidth: 112, minHeight: 112)
        }
        .accessibilityLabel("Modifier la photo de profil")
    }

    private func close() {
        model.discardEditing()
        dismiss()
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPresented = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    isCameraPresented = true
                } else {
                    presentedAlert = .cameraDenied
                }
            }
        case .denied, .restricted:
            presentedAlert = .cameraDenied
        @unknown default:
            presentedAlert = .cameraDenied
        }
    }

    private func requestContacts() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            isContactPickerPresented = true
        case .notDetermined:
            Task {
                do {
                    if try await CNContactStore().requestAccess(for: .contacts) {
                        isContactPickerPresented = true
                    } else {
                        presentedAlert = .contactsDenied
                    }
                } catch {
                    presentedAlert = .contactsDenied
                }
            }
        case .denied, .restricted:
            presentedAlert = .contactsDenied
        @unknown default:
            presentedAlert = .contactsDenied
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let normalized = ProfileImageProcessor.normalizedJPEG(from: data) else {
                presentedAlert = .invalidImage
                return
            }
            model.setAvatarData(normalized)
        } catch {
            presentedAlert = .invalidImage
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private enum PresentedAlert: String, Identifiable {
    case cameraDenied
    case contactsDenied
    case invalidImage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cameraDenied: "Accès à la caméra refusé"
        case .contactsDenied: "Accès aux contacts refusé"
        case .invalidImage: "Photo indisponible"
        }
    }

    var message: String {
        switch self {
        case .cameraDenied: "Autorise Via à utiliser la caméra dans les réglages iOS."
        case .contactsDenied: "Autorise Via à accéder aux contacts dans les réglages iOS."
        case .invalidImage: "Cette photo n’a pas pu être chargée. Choisis-en une autre."
        }
    }

    var offersSettings: Bool {
        switch self {
        case .cameraDenied, .contactsDenied: true
        case .invalidImage: false
        }
    }
}

#Preview("Profil vide") {
    let model: ProfileModel = {
        let model = ProfileModel(store: InMemoryProfileStore())
        model.activate(scope: .anonymous)
        return model
    }()
    ProfileEditorView(model: model)
}

#Preview("Profil rempli · texte agrandi") {
    let model: ProfileModel = {
        let model = ProfileModel(store: InMemoryProfileStore())
        model.activate(scope: .user("preview"), seedName: "Alex Martin")
        return model
    }()
    ProfileEditorView(model: model)
        .environment(\.dynamicTypeSize, .accessibility2)
}
