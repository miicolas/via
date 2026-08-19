import SwiftUI

/// Owns when a skeleton is on screen, which is the only place that can keep it
/// there a little longer than the request itself.
///
/// A response that lands within `delay` shows nothing at all; once shown, the
/// skeleton stays for `minimumDuration` so a near-instant answer cannot flash a
/// placeholder and rip it away.
struct SkeletonGate<Placeholder: View, Content: View>: View {
    let isLoading: Bool
    var delay: Duration = .milliseconds(200)
    var minimumDuration: Duration = .milliseconds(400)
    @ViewBuilder let skeleton: () -> Placeholder
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSkeleton = false

    var body: some View {
        ZStack {
            if isShowingSkeleton {
                skeleton()
                    .transition(.opacity)
            } else {
                content()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isShowingSkeleton)
        .task(id: isLoading) {
            if isLoading {
                guard !isShowingSkeleton else { return }
                guard (try? await Task.sleep(for: delay)) != nil else { return }
                isShowingSkeleton = true
            } else {
                guard isShowingSkeleton else { return }
                guard (try? await Task.sleep(for: minimumDuration)) != nil else { return }
                isShowingSkeleton = false
            }
        }
    }
}

extension SkeletonGate where Content == EmptyView {
    init(
        isLoading: Bool,
        delay: Duration = .milliseconds(200),
        minimumDuration: Duration = .milliseconds(400),
        @ViewBuilder skeleton: @escaping () -> Placeholder
    ) {
        self.init(
            isLoading: isLoading,
            delay: delay,
            minimumDuration: minimumDuration,
            skeleton: skeleton,
            content: { EmptyView() }
        )
    }
}

#Preview {
    @Previewable @State var isLoading = true

    VStack(spacing: 24) {
        SkeletonGate(isLoading: isLoading) {
            SkeletonList(
                count: 3,
                label: "Recherche…",
                row: SkeletonList.Row(leading: .circle(46), lines: [.title, .caption]),
                separator: .divider(leadingInset: 60)
            )
        } content: {
            Text("Contenu chargé")
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        Button(isLoading ? "Terminer le chargement" : "Recharger") {
            isLoading.toggle()
        }
    }
    .padding()
}
