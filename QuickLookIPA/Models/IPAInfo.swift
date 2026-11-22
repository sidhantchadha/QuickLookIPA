//
//  IPAInfo.swift
//  QuickLookIPA
//
//  Complete data model for IPA inspection results
//

import Foundation
import SwiftUI

// MARK: - Main IPA Information Model
struct IPAInfo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: String
    let fileSize: Int64
    let inspectionDate: Date

    // Basic Info
    var appName: String?
    var executableName: String?
    var bundleIdentifier: String?
    var version: String?
    var buildNumber: String?
    var minimumOSVersion: String?
    var appIcon: Data?

    // File Analysis
    var binarySize: Int64?
    var architectures: [String]?
    var frameworks: [FrameworkInfo]?
    var largestAssets: [AssetInfo]?

    // Provisioning Profile
    var provisioningProfile: ProvisioningProfileInfo?

    // Entitlements
    var entitlements: [EntitlementInfo]?

    // Extensions
    var extensions: [ExtensionInfo]?

    // Localization
    var supportedLanguages: [String]?

    // Network Settings
    var networkSettings: NetworkSettingsInfo?

    // Privacy Manifest
    var privacyManifest: PrivacyManifestInfo?

    // Code Signature
    var codeSignature: CodeSignatureInfo?

    // Validation Issues
    var validationIssues: [ValidationIssue]?

    init(id: UUID = UUID(), fileName: String, filePath: String, fileSize: Int64) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.inspectionDate = Date()
    }
}

// MARK: - Supporting Models

struct FrameworkInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: Int64
    let path: String

    init(id: UUID = UUID(), name: String, size: Int64, path: String) {
        self.id = id
        self.name = name
        self.size = size
        self.path = path
    }
}

struct AssetInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: Int64
    let type: String

    init(id: UUID = UUID(), name: String, size: Int64, type: String) {
        self.id = id
        self.name = name
        self.size = size
        self.type = type
    }
}

struct ProvisioningProfileInfo: Codable {
    var name: String?
    var appIDName: String?
    var applicationIdentifier: String?
    var teamName: String?
    var teamIdentifier: String?
    var uuid: String?
    var creationDate: Date?
    var expirationDate: Date?
    var provisionedDevices: [String]?
    var certificate: CertificateInfo?
    var profileType: ProfileType?

    enum ProfileType: String, Codable {
        case development = "Development"
        case adHoc = "Ad Hoc"
        case appStore = "App Store"
        case enterprise = "Enterprise"
        case unknown = "Unknown"
    }
}

struct CertificateInfo: Codable {
    var subject: String?
    var issuer: String?
    var serialNumber: String?
    var notBefore: Date?
    var notAfter: Date?
    var fingerprint: String?
}

struct EntitlementInfo: Identifiable, Codable {
    let id: UUID
    let key: String
    let value: String
    let description: String
    var isEnabled: Bool

    init(id: UUID = UUID(), key: String, value: String, description: String, isEnabled: Bool) {
        self.id = id
        self.key = key
        self.value = value
        self.description = description
        self.isEnabled = isEnabled
    }
}

struct ExtensionInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let type: ExtensionType
    let size: Int64

    init(id: UUID = UUID(), name: String, bundleIdentifier: String, type: ExtensionType, size: Int64) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.type = type
        self.size = size
    }

    enum ExtensionType: String, Codable {
        case widget = "Widget"
        case shareExtension = "Share Extension"
        case todayExtension = "Today Extension"
        case intents = "Intents Extension"
        case notification = "Notification Extension"
        case watchApp = "Watch App"
        case unknown = "Unknown Extension"
    }
}

struct NetworkSettingsInfo: Codable {
    var allowsArbitraryLoads: Bool?
    var allowedDomains: [String]?
    var exceptionDomains: [String]?
}

struct PrivacyManifestInfo: Codable {
    var trackingDomains: [String]?
    var collectedDataTypes: [String]?
    var accessedAPITypes: [String]?
}

struct CodeSignatureInfo: Codable {
    var isValid: Bool
    var signingIdentity: String?
    var teamIdentifier: String?
    var errors: [String]?
}

struct ValidationIssue: Identifiable, Codable {
    let id: UUID
    let severity: Severity
    let title: String
    let message: String
    let suggestion: String?

    init(id: UUID = UUID(), severity: Severity, title: String, message: String, suggestion: String? = nil) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.suggestion = suggestion
    }

    enum Severity: String, Codable {
        case critical = "Critical"
        case warning = "Warning"
        case info = "Info"
    }

    var color: Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var icon: String {
        switch severity {
        case .critical: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case markdown = "Markdown"
    case text = "Plain Text"
    case pdf = "PDF"

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        case .text: return "txt"
        case .pdf: return "pdf"
        }
    }
}
