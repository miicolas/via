enum AccountSheetDestination: String, Identifiable {
    case profile
    case settings
    case notifications
    case favorites
    case meetups
    case friends

    var id: String { rawValue }
}
