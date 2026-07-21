import SwiftUI

extension String {
    /// Builds an AttributedString with every case-insensitive occurrence of `query`
    /// colored `highlightColor` and the rest colored `baseColor`. Returns the string
    /// uncolored-but-based if `query` is empty.
    func highlighted(matching query: String, baseColor: Color, highlightColor: Color) -> AttributedString {
        var attributed = AttributedString(self)
        attributed.foregroundColor = baseColor

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return attributed }

        var searchRange = startIndex..<endIndex
        while let found = range(of: trimmedQuery, options: .caseInsensitive, range: searchRange) {
            if let attrRange = Range(found, in: attributed) {
                attributed[attrRange].foregroundColor = highlightColor
            }
            searchRange = found.upperBound..<endIndex
        }
        return attributed
    }
}
