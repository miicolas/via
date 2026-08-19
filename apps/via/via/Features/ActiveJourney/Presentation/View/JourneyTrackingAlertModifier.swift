import SwiftUI

struct JourneyTrackingAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onStart: (Bool) -> Void

    func body(content: Content) -> some View {
        content.alert("Suivre ce trajet en temps réel ?", isPresented: $isPresented) {
            Button("Autoriser en arrière-plan") { onStart(true) }
            Button("Continuer avec l’app ouverte") { onStart(false) }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Via utilise votre position pendant le trajet pour afficher la bonne étape, " +
                    "détecter l’arrivée et proposer rapidement un nouvel itinéraire. " +
                    "Le suivi en arrière-plan fonctionne aussi lorsque l’écran est verrouillé. " +
                    "Vous pourrez toujours avancer manuellement si vous refusez."
            )
        }
    }
}

extension View {
    func journeyTrackingAlert(
        isPresented: Binding<Bool>,
        onStart: @escaping (Bool) -> Void
    ) -> some View {
        modifier(JourneyTrackingAlertModifier(isPresented: isPresented, onStart: onStart))
    }
}
