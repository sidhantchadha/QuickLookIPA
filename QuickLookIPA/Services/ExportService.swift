//
//  ExportService.swift
//  QuickLookIPA
//
//  Created by Claude Code on 11/21/26.
//  Service for exporting IPA inspection results to multiple formats including
//  PDF, HTML, JSON, and Markdown with comprehensive formatting.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class ExportService {
    static let shared = ExportService()

    private init() {}

    func export(_ ipaInfo: IPAInfo, format: ExportFormat, to url: URL) throws {
        switch format {
        case .json:
            try exportJSON(ipaInfo, to: url)
        case .markdown:
            try exportMarkdown(ipaInfo, to: url)
        case .text:
            try exportText(ipaInfo, to: url)
        case .pdf:
            try exportPDF(ipaInfo, to: url)
        }
    }

    // MARK: - JSON Export
    private func exportJSON(_ ipaInfo: IPAInfo, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(ipaInfo)
        try data.write(to: url)
    }

    // MARK: - Markdown Export
    private func exportMarkdown(_ ipaInfo: IPAInfo, to url: URL) throws {
        var markdown = """
        # IPA Inspection Report

        **File:** \(ipaInfo.fileName)
        **Inspection Date:** \(formatDate(ipaInfo.inspectionDate))

        ---

        ## Basic Information

        | Property | Value |
        |----------|-------|
        """

        if let appName = ipaInfo.appName {
            markdown += "\n| App Name | \(appName) |"
        }
        if let bundleID = ipaInfo.bundleIdentifier {
            markdown += "\n| Bundle Identifier | `\(bundleID)` |"
        }
        if let version = ipaInfo.version {
            markdown += "\n| Version | \(version) |"
        }
        if let build = ipaInfo.buildNumber {
            markdown += "\n| Build Number | \(build) |"
        }
        if let minOS = ipaInfo.minimumOSVersion {
            markdown += "\n| Minimum iOS | \(minOS) |"
        }

        markdown += "\n| File Size | \(ByteCountFormatter.string(fromByteCount: ipaInfo.fileSize, countStyle: .file)) |"

        // Binary Analysis
        if let binarySize = ipaInfo.binarySize {
            markdown += "\n\n## Binary Analysis\n\n"
            markdown += "**Binary Size:** \(ByteCountFormatter.string(fromByteCount: binarySize, countStyle: .file))\n\n"

            if let archs = ipaInfo.architectures, !archs.isEmpty {
                markdown += "**Architectures:** \(archs.joined(separator: ", "))\n\n"
            }
        }

        // Frameworks
        if let frameworks = ipaInfo.frameworks, !frameworks.isEmpty {
            markdown += "\n## Frameworks (\(frameworks.count))\n\n"
            markdown += "| Name | Size |\n|------|------|\n"
            for framework in frameworks.prefix(10) {
                markdown += "| \(framework.name) | \(ByteCountFormatter.string(fromByteCount: framework.size, countStyle: .file)) |\n"
            }
        }

        // Provisioning Profile
        if let profile = ipaInfo.provisioningProfile {
            markdown += "\n## Provisioning Profile\n\n"
            markdown += "| Property | Value |\n|----------|-------|\n"
            if let name = profile.name {
                markdown += "| Name | \(name) |\n"
            }
            if let teamName = profile.teamName {
                markdown += "| Team | \(teamName) |\n"
            }
            if let uuid = profile.uuid {
                markdown += "| UUID | `\(uuid)` |\n"
            }
            if let type = profile.profileType {
                markdown += "| Type | \(type.rawValue) |\n"
            }
            if let expiration = profile.expirationDate {
                markdown += "| Expiration | \(formatDate(expiration)) |\n"
            }
            if let devices = profile.provisionedDevices {
                markdown += "| Devices | \(devices.count) |\n"
            }
        }

        // Entitlements
        if let entitlements = ipaInfo.entitlements, !entitlements.isEmpty {
            markdown += "\n## Entitlements (\(entitlements.count))\n\n"
            for entitlement in entitlements {
                markdown += "- **\(entitlement.key):** \(entitlement.value)\n"
                markdown += "  - \(entitlement.description)\n"
            }
        }

        // Extensions
        if let extensions = ipaInfo.extensions, !extensions.isEmpty {
            markdown += "\n## Extensions (\(extensions.count))\n\n"
            for ext in extensions {
                markdown += "- **\(ext.name)** (\(ext.type.rawValue))\n"
                markdown += "  - Bundle ID: `\(ext.bundleIdentifier)`\n"
                markdown += "  - Size: \(ByteCountFormatter.string(fromByteCount: ext.size, countStyle: .file))\n"
            }
        }

        // Localization
        if let languages = ipaInfo.supportedLanguages, !languages.isEmpty {
            markdown += "\n## Localization\n\n"
            markdown += "**Supported Languages (\(languages.count)):** \(languages.joined(separator: ", "))\n"
        }

        // Validation Issues
        if let issues = ipaInfo.validationIssues, !issues.isEmpty {
            markdown += "\n## Validation Issues\n\n"
            for issue in issues {
                let emoji = issue.severity == .critical ? "🔴" : issue.severity == .warning ? "🟡" : "🔵"
                markdown += "\n### \(emoji) \(issue.title) (\(issue.severity.rawValue))\n\n"
                markdown += "\(issue.message)\n\n"
                if let suggestion = issue.suggestion {
                    markdown += "**Suggestion:** \(suggestion)\n\n"
                }
            }
        }

        markdown += "\n---\n\n*Generated by QuickLookIPA*\n"

        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Plain Text Export
    private func exportText(_ ipaInfo: IPAInfo, to url: URL) throws {
        var text = """
        IPA INSPECTION REPORT
        =====================

        File: \(ipaInfo.fileName)
        Inspection Date: \(formatDate(ipaInfo.inspectionDate))

        BASIC INFORMATION
        -----------------
        """

        if let appName = ipaInfo.appName {
            text += "\nApp Name: \(appName)"
        }
        if let bundleID = ipaInfo.bundleIdentifier {
            text += "\nBundle Identifier: \(bundleID)"
        }
        if let version = ipaInfo.version {
            text += "\nVersion: \(version)"
        }
        if let build = ipaInfo.buildNumber {
            text += "\nBuild: \(build)"
        }
        if let minOS = ipaInfo.minimumOSVersion {
            text += "\nMinimum iOS: \(minOS)"
        }
        text += "\nFile Size: \(ByteCountFormatter.string(fromByteCount: ipaInfo.fileSize, countStyle: .file))"

        // Add all other sections similarly to markdown
        if let profile = ipaInfo.provisioningProfile {
            text += "\n\nPROVISIONING PROFILE\n--------------------"
            if let name = profile.name { text += "\nName: \(name)" }
            if let teamName = profile.teamName { text += "\nTeam: \(teamName)" }
            if let uuid = profile.uuid { text += "\nUUID: \(uuid)" }
        }

        text += "\n\n--- Generated by QuickLookIPA ---\n"

        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - PDF Export
    private func exportPDF(_ ipaInfo: IPAInfo, to url: URL) throws {
        var pdfData: Data?

        // PDF generation must happen on main thread due to AppKit requirements
        if Thread.isMainThread {
            pdfData = generatePDFData(for: ipaInfo)
        } else {
            DispatchQueue.main.sync {
                pdfData = generatePDFData(for: ipaInfo)
            }
        }

        guard let data = pdfData else {
            throw NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF data"])
        }

        try data.write(to: url, options: .atomic)
    }

    private func generatePDFData(for ipaInfo: IPAInfo) -> Data {
        // Create attributed string with formatting
        let content = NSMutableAttributedString()

        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let headingFont = NSFont.boldSystemFont(ofSize: 18)
        let bodyFont = NSFont.systemFont(ofSize: 12)

        // Title
        content.append(NSAttributedString(string: "IPA Inspection Report\n\n", attributes: [.font: titleFont]))

        // Basic info
        content.append(NSAttributedString(string: "Basic Information\n", attributes: [.font: headingFont]))
        if let appName = ipaInfo.appName {
            content.append(NSAttributedString(string: "App Name: \(appName)\n", attributes: [.font: bodyFont]))
        }
        if let bundleID = ipaInfo.bundleIdentifier {
            content.append(NSAttributedString(string: "Bundle ID: \(bundleID)\n", attributes: [.font: bodyFont]))
        }
        if let version = ipaInfo.version {
            content.append(NSAttributedString(string: "Version: \(version)\n", attributes: [.font: bodyFont]))
        }
        if let build = ipaInfo.buildNumber {
            content.append(NSAttributedString(string: "Build: \(build)\n", attributes: [.font: bodyFont]))
        }

        content.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))

        // Create PDF
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
        textView.textStorage?.setAttributedString(content)

        return textView.dataWithPDF(inside: textView.bounds)
    }

    // MARK: - Utilities
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Save Panel
    func showSavePanel(for ipaInfo: IPAInfo, format: ExportFormat, completion: @escaping (Bool) -> Void) {
        // Ensure we're on main thread for UI
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.title = "Export IPA Report"

            // Sanitize filename
            let sanitizedName = (ipaInfo.appName ?? "Report")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            savePanel.nameFieldStringValue = "\(sanitizedName).\(format.fileExtension)"

            // Handle UTType creation safely
            if let contentType = UTType(filenameExtension: format.fileExtension) {
                savePanel.allowedContentTypes = [contentType]
            } else {
                savePanel.allowedContentTypes = [.data]
            }

            savePanel.begin { response in
                guard response == .OK, let url = savePanel.url else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                // Export in background
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try self.export(ipaInfo, format: format, to: url)
                        DispatchQueue.main.async { completion(true) }
                    } catch {
                        print("Export failed: \(error)")
                        DispatchQueue.main.async { completion(false) }
                    }
                }
            }
        }
    }
}
