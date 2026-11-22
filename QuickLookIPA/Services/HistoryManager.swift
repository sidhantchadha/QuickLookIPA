//
//  HistoryManager.swift
//  QuickLookIPA
//
//  Created by Claude Code on 11/21/26.
//  Persistent storage manager for inspection history with thread-safe operations
//  and automatic cleanup of old entries.
//

import Foundation

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var recentInspections: [IPAInfo] = []

    private let maxHistoryItems = 50
    private let historyFileURL: URL
    private let serialQueue = DispatchQueue(label: "com.quicklookipa.historymanager", qos: .userInitiated)

    private init() {
        // Safely create app support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not access application support directory")
        }

        let appDirectory = appSupport.appendingPathComponent("QuickLookIPA")

        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            // Directory creation failed, will use default location
        }

        historyFileURL = appDirectory.appendingPathComponent("history.json")

        loadHistory()
    }

    func addInspection(_ ipaInfo: IPAInfo) {
        // Ensure thread safety with main thread for @Published property
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove if already exists
            self.recentInspections.removeAll { $0.id == ipaInfo.id }

            // Add to beginning
            self.recentInspections.insert(ipaInfo, at: 0)

            // Limit size
            if self.recentInspections.count > self.maxHistoryItems {
                self.recentInspections = Array(self.recentInspections.prefix(self.maxHistoryItems))
            }

            // Save in background
            self.saveHistory()
        }
    }

    func removeInspection(id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentInspections.removeAll { $0.id == id }
            self.saveHistory()
        }
    }

    func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentInspections.removeAll()
            self.saveHistory()
        }
    }

    private func saveHistory() {
        // Save on background serial queue to avoid blocking UI
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601

                // Create a copy of the data on main thread
                var inspections: [IPAInfo] = []
                DispatchQueue.main.sync {
                    inspections = self.recentInspections
                }

                let data = try encoder.encode(inspections)
                try data.write(to: self.historyFileURL, options: .atomic)
            } catch {
                // History save failed - will retry on next change
            }
        }
    }

    private func loadHistory() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            guard FileManager.default.fileExists(atPath: self.historyFileURL.path) else { return }

            do {
                let data = try Data(contentsOf: self.historyFileURL)

                // Check if data is empty
                guard !data.isEmpty else { return }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let loadedInspections = try decoder.decode([IPAInfo].self, from: data)

                // Update on main thread
                DispatchQueue.main.async {
                    self.recentInspections = loadedInspections
                }
            } catch {
                // History corrupted - delete and start fresh
                try? FileManager.default.removeItem(at: self.historyFileURL)
            }
        }
    }
}
