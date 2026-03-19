import Foundation

struct ScreenshotItem: Codable, Hashable, Identifiable {
    let id: UUID
    var originalFilename: String
    var storedFilename: String
    var thumbnailFilename: String
    var importedAt: Date
    var pinned: Bool
    var dataHash: String

    var displayTitle: String {
        let rawName = URL(fileURLWithPath: originalFilename).deletingPathExtension().lastPathComponent
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return "Screenshot"
    }

    var displayTimestamp: String {
        Self.timestampFormatter.string(from: importedAt)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
