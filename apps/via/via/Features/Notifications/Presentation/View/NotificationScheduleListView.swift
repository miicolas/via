import SwiftUI

struct NotificationScheduleListView: View {
    let accountModel: AccountModel
    let coordinator: NotificationScheduleCoordinator

    @State private var isAddingSchedule = false

    var body: some View {
        List {
            let schedules = accountModel.notificationSchedules.filter { $0.deletedAt == nil }
            if schedules.isEmpty {
                EmptyStateView(.noNotificationSchedules) {
                    Button("Ajouter une programmation", systemImage: "plus") {
                        isAddingSchedule = true
                    }
                    .primaryAction()
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(schedules) { schedule in
                        NavigationLink {
                            NotificationScheduleEditorView(
                                accountModel: accountModel,
                                coordinator: coordinator,
                                schedule: schedule
                            )
                        } label: {
                            NotificationScheduleRow(schedule: schedule)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                accountModel.removeNotificationSchedule(id: schedule.id)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Programmations")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingSchedule = true
                } label: {
                    Image(systemName: "plus")
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Ajouter une programmation")
            }
        }
        .sheet(isPresented: $isAddingSchedule) {
            NavigationStack {
                NotificationScheduleEditorView(
                    accountModel: accountModel,
                    coordinator: coordinator,
                    schedule: nil
                )
            }
        }
    }
}
