import Foundation

/// How Via writes "when was this". Via's copy is French but the app ships no
/// localisation catalogue, so a phone set to another language renders a bare
/// `.relative` style in *that* language — "39 minutes ago" printed under
/// "Mis à jour". Freshness goes through here for the same reason a distance
/// goes through `DistanceFormatting`: the locale is the string's, not the
/// device's.
enum RelativeTimeFormatting {
  private static let locale = Locale(identifier: "fr_FR")

  /// "il y a 39 min" — short enough to ride at the end of a status line.
  static func short(_ date: Date) -> String {
    date.formatted(style(unitsStyle: .abbreviated))
  }

  /// "il y a 39 minutes" — spelled out, for VoiceOver and for prose.
  static func spelled(_ date: Date) -> String {
    date.formatted(style(unitsStyle: .wide))
  }

  private static func style(
    unitsStyle: Date.RelativeFormatStyle.UnitsStyle
  ) -> Date.RelativeFormatStyle {
    Date.RelativeFormatStyle(
      presentation: .numeric,
      unitsStyle: unitsStyle,
      locale: locale,
      capitalizationContext: .middleOfSentence
    )
  }
}
