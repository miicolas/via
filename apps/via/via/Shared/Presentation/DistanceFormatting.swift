import Foundation

/// How Via writes a walking distance. One definition so a metre count does not
/// come back as `1.2 km` on one screen and `1,2 km` on the next — the unit and
/// the decimal separator are the locale's to choose, never a literal's.
enum DistanceFormatting {
  private static let locale = Locale(identifier: "fr_FR")

  /// A `FormatStyle` rather than a `MeasurementFormatter`: these are read from
  /// view bodies — every exit row of every timeline pass — and a formatter
  /// builds an ICU instance on `init`, where Foundation caches a style. It is
  /// also `Sendable`, which a formatter held as a shared `static` is not.
  static func text(meters: Double) -> String {
    meters >= 1_000
      ? Measurement(value: meters / 1_000, unit: UnitLength.kilometers)
        .formatted(style(fractionDigits: 1))
      : Measurement(value: meters, unit: UnitLength.meters)
        .formatted(style(fractionDigits: 0))
  }

  private static func style(
    fractionDigits: Int
  ) -> Measurement<UnitLength>.FormatStyle {
    .measurement(
      width: .abbreviated,
      usage: .asProvided,
      numberFormatStyle: .number
        .precision(.fractionLength(0...fractionDigits))
        .locale(locale)
    )
    .locale(locale)
  }
}
