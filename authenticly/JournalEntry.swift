//
//  JournalEntry.swift
//  authenticly
//
//  Created by Armaan Agrawal on 8/2/25.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: String
    var filename: String
    var content: String
    var previewText: String
    var timestamp: Date
    
    init(id: UUID = UUID(), date: String, filename: String, content: String = "", timestamp: Date = Date()) {
        self.id = id
        self.date = date
        self.filename = filename
        self.content = content
        self.timestamp = timestamp
        let trimmed = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            self.previewText = "Empty entry"
        } else if trimmed.count > 50 {
            self.previewText = String(trimmed.prefix(50)) + "..."
        } else {
            self.previewText = trimmed
        }
    }
    
    func updatePreviewText() {
        let trimmed = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            self.previewText = "Empty entry"
        } else if trimmed.count > 50 {
            self.previewText = String(trimmed.prefix(50)) + "..."
        } else {
            self.previewText = trimmed
        }
    }
    
    static func createNew() -> JournalEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)
        
        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)
        
        return JournalEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            content: "",
            timestamp: now
        )
    }
}
