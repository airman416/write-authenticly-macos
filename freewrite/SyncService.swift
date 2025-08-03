//
//  SyncService.swift
//  Offline-first sync service for Freewrite apps
//
//  Created by Backend Integration on 8/3/25.
//

import Foundation
import SwiftData

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    private let apiClient = APIClient.shared
    private var modelContext: ModelContext?
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // Sync configuration
    private let autoSyncInterval: TimeInterval = 300 // 5 minutes
    private var syncTimer: Timer?
    
    private init() {
        startAutoSync()
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Auto Sync Management
    
    private func startAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performFullSync()
            }
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Main Sync Operations
    
    func performFullSync() async {
        guard !isSyncing else { return }
        guard apiClient.isConnected else {
            syncError = "No internet connection"
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Step 1: Push local changes to server
            await pushLocalChanges()
            
            // Step 2: Pull server changes to local
            await pullServerChanges()
            
            lastSyncDate = Date()
            syncError = nil
            
            print("✅ Full sync completed successfully")
            
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("❌ Sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    func syncSingleEntry(_ entry: JournalEntry) async {
        guard apiClient.isConnected else { return }
        
        do {
            if entry.needsSync {
                // Check if entry exists on server
                let serverEntry = try? await apiClient.getJournal(id: entry.id.uuidString)
                
                if serverEntry != nil {
                    // Update existing entry
                    let _ = try await apiClient.updateJournal(
                        id: entry.id.uuidString,
                        content: entry.content
                    )
                } else {
                    // Create new entry
                    let _ = try await apiClient.createJournal(content: entry.content)
                }
                
                // Mark as synced
                entry.needsSync = false
                try? modelContext?.save()
                
                print("✅ Synced entry: \(entry.filename)")
            }
        } catch {
            print("❌ Failed to sync entry \(entry.filename): \(error)")
        }
    }
    
    // MARK: - Push Local Changes
    
    private func pushLocalChanges() async {
        guard let modelContext = modelContext else { return }
        
        do {
            // Get all entries that need syncing
            let unsyncedEntries = try modelContext.fetch(
                FetchDescriptor<JournalEntry>(
                    predicate: #Predicate { $0.needsSync == true }
                )
            )
            
            for entry in unsyncedEntries {
                await syncSingleEntry(entry)
            }
            
        } catch {
            print("❌ Failed to fetch unsynced entries: \(error)")
        }
    }
    
    // MARK: - Pull Server Changes
    
    private func pullServerChanges() async {
        guard let modelContext = modelContext else { return }
        
        do {
            // Get all entries from server
            let serverEntries = try await apiClient.getJournals(limit: 1000)
            
            // Get all local entries
            let localEntries = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            let localEntryIds = Set(localEntries.map { $0.id.uuidString })
            
            for serverEntry in serverEntries {
                if localEntryIds.contains(serverEntry.id) {
                    // Update existing local entry if server version is newer
                    if let localEntry = localEntries.first(where: { $0.id.uuidString == serverEntry.id }) {
                        await updateLocalEntry(localEntry, with: serverEntry)
                    }
                } else {
                    // Create new local entry
                    await createLocalEntry(from: serverEntry)
                }
            }
            
            try modelContext.save()
            
        } catch {
            print("❌ Failed to pull server changes: \(error)")
        }
    }
    
    private func updateLocalEntry(_ localEntry: JournalEntry, with serverEntry: APIJournalEntry) async {
        // Parse server timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        
        if let serverTimestamp = dateFormatter.date(from: serverEntry.timestamp),
           serverTimestamp > localEntry.timestamp {
            
            localEntry.content = serverEntry.content
            localEntry.date = serverEntry.date
            localEntry.filename = serverEntry.filename
            localEntry.timestamp = serverTimestamp
            localEntry.updatePreviewText()
            localEntry.needsSync = false
            
            print("📥 Updated local entry: \(localEntry.filename)")
        }
    }
    
    private func createLocalEntry(from serverEntry: APIJournalEntry) async {
        guard let modelContext = modelContext else { return }
        
        let localEntry = serverEntry.toJournalEntry()
        localEntry.needsSync = false
        
        modelContext.insert(localEntry)
        
        print("📥 Created local entry: \(localEntry.filename)")
    }
    
    // MARK: - Manual Sync Controls
    
    func forcePushEntry(_ entry: JournalEntry) async {
        entry.needsSync = true
        try? modelContext?.save()
        await syncSingleEntry(entry)
    }
    
    func refreshFromServer() async {
        await pullServerChanges()
    }
}

// MARK: - JournalEntry Extension for Sync

extension JournalEntry {
    private static let needsSyncKey = "needsSync"
    
    var needsSync: Bool {
        get {
            UserDefaults.standard.bool(forKey: "\(Self.needsSyncKey)_\(id.uuidString)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "\(Self.needsSyncKey)_\(id.uuidString)")
        }
    }
    
    func markForSync() {
        needsSync = true
    }
}