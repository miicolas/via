enum AccountSheetDestination: String, Identifiable {
    case profile
    case settings
    case notifications

    var id: String { rawValue }
}
