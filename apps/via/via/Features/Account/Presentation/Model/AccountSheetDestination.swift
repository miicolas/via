enum AccountSheetDestination: String, Identifiable {
    case profile
    case settings

    var id: String { rawValue }
}
