enum AccountSheetDestination: String, Identifiable {
    case profile
    case settings
    case notifications
    case favorites

    var id: String { rawValue }
}
