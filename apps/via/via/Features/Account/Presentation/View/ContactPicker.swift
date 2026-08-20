import Contacts
import ContactsUI
import SwiftUI

struct ContactPicker: UIViewControllerRepresentable {
    let onContact: (ProfileContact?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onContact: onContact) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        controller.displayedPropertyKeys = [CNContactImageDataKey, CNContactGivenNameKey, CNContactFamilyNameKey]
        return controller
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onContact: (ProfileContact?) -> Void

        init(onContact: @escaping (ProfileContact?) -> Void) {
            self.onContact = onContact
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onContact(nil)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            onContact(ProfileContact(displayName: name, avatarData: contact.imageData))
        }
    }
}
