//
//  IPAInspectorService.swift
//  QuickLookIPA
//
//  Production-grade IPA inspection service with all features
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class IPAInspectorService: ObservableObject {
    static let shared = IPAInspectorService()

    @Published var currentInspection: IPAInfo?
    @Published var currentIpaURL: URL?
    @Published var isInspecting = false
    @Published var inspectionProgress: Double = 0.0
    @Published var inspectionStatus: String = ""
    @Published var debugLoggingEnabled = false

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Clear/Reset Method
    func clearCurrentInspection() {
        DispatchQueue.main.async { [weak self] in
            // Stop accessing security-scoped resource if we have one
            if let ipaURL = self?.currentIpaURL {
                ipaURL.stopAccessingSecurityScopedResource()
            }

            self?.currentInspection = nil
            self?.currentIpaURL = nil
            self?.isInspecting = false
            self?.inspectionProgress = 0.0
            self?.inspectionStatus = ""
        }
    }

    // MARK: - Main Inspection Method
    func inspect(ipaURL: URL, completion: @escaping (Result<IPAInfo, InspectionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isInspecting = true
                self.inspectionProgress = 0.0
                self.inspectionStatus = "Starting inspection..."
            }

            do {
                // Get file attributes
                let attributes = try self.fileManager.attributesOfItem(atPath: ipaURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                var ipaInfo = IPAInfo(
                    fileName: ipaURL.lastPathComponent,
                    filePath: ipaURL.path,
                    fileSize: fileSize
                )

                // Create temp directory
                let tempDir = self.fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer {
                    try? self.fileManager.removeItem(at: tempDir)
                    if ipaURL.path.starts(with: self.fileManager.temporaryDirectory.path) {
                        try? self.fileManager.removeItem(at: ipaURL)
                    }
                }

                // Extract IPA
                self.updateProgress(0.1, status: "Extracting IPA...")
                let appURL = try self.extractIPA(ipaURL, to: tempDir)

                // Extract all information in parallel where possible
                self.updateProgress(0.2, status: "Reading Info.plist...")
                try self.extractBasicInfo(from: appURL, into: &ipaInfo)

                self.updateProgress(0.3, status: "Extracting app icon...")
                self.extractAppIcon(from: appURL, into: &ipaInfo)

                self.updateProgress(0.4, status: "Analyzing file structure...")
                self.analyzeFileStructure(appURL: appURL, into: &ipaInfo)

                self.updateProgress(0.5, status: "Parsing provisioning profile...")
                try self.extractProvisioningProfile(from: appURL, into: &ipaInfo)

                self.updateProgress(0.6, status: "Extracting entitlements...")
                self.extractEntitlements(from: appURL, into: &ipaInfo)

                self.updateProgress(0.7, status: "Detecting extensions...")
                self.detectExtensions(in: appURL, into: &ipaInfo)

                self.updateProgress(0.8, status: "Analyzing localization...")
                self.extractLocalizationInfo(from: appURL, into: &ipaInfo)

                self.updateProgress(0.85, status: "Extracting network settings...")
                self.extractNetworkSettings(from: appURL, into: &ipaInfo)

                self.updateProgress(0.9, status: "Verifying code signature...")
                self.verifyCodeSignature(appURL: appURL, into: &ipaInfo)

                self.updateProgress(0.95, status: "Running validation checks...")
                self.runValidationChecks(on: &ipaInfo)

                self.updateProgress(1.0, status: "Inspection complete!")

                DispatchQueue.main.async {
                    self.currentInspection = ipaInfo
                    self.isInspecting = false
                    completion(.success(ipaInfo))
                }

            } catch let error as InspectionError {
                DispatchQueue.main.async {
                    self.isInspecting = false
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInspecting = false
                    completion(.failure(.unknown(error.localizedDescription)))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func updateProgress(_ progress: Double, status: String) {
        DispatchQueue.main.async {
            self.inspectionProgress = progress
            self.inspectionStatus = status
        }
        if debugLoggingEnabled {
            print("📊 [\(Int(progress * 100))%] \(status)")
        }
    }

    private func log(_ message: String) {
        if debugLoggingEnabled {
            print("🔍 [IPAInspector] \(message)")
        }
    }

    private func extractIPA(_ ipaURL: URL, to tempDir: URL) throws -> URL {
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let unzipURL = findExecutable("unzip") else {
            throw InspectionError.missingTool("unzip")
        }

        let unzipTask = Process()
        unzipTask.executableURL = unzipURL
        unzipTask.arguments = ["-o", "-q", ipaURL.path, "-d", tempDir.path]
        unzipTask.currentDirectoryURL = tempDir

        let errorPipe = Pipe()
        unzipTask.standardError = errorPipe

        try unzipTask.run()

        let startTime = Date()
        while unzipTask.isRunning {
            Thread.sleep(forTimeInterval: 0.1)
            if Date().timeIntervalSince(startTime) > 60 {
                unzipTask.terminate()
                throw InspectionError.timeout
            }
        }

        guard unzipTask.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw InspectionError.unzipFailed(errorText)
        }

        let payloadURL = tempDir.appendingPathComponent("Payload")
        guard fileManager.fileExists(atPath: payloadURL.path) else {
            throw InspectionError.invalidStructure("Payload directory not found")
        }

        let contents = try fileManager.contentsOfDirectory(atPath: payloadURL.path)
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw InspectionError.invalidStructure("No .app bundle found")
        }

        // Security validation
        guard !appName.contains(".."), !appName.contains("/"), appName.hasSuffix(".app") else {
            throw InspectionError.securityViolation
        }

        return payloadURL.appendingPathComponent(appName)
    }

    private func extractBasicInfo(from appURL: URL, into ipaInfo: inout IPAInfo) throws {
        let infoPlistURL = appURL.appendingPathComponent("Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)

        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw InspectionError.invalidPlist
        }

        // Store both display name and executable name
        let displayName = plist["CFBundleDisplayName"] as? String ?? plist["CFBundleName"] as? String
        let executableName = plist["CFBundleExecutable"] as? String

        ipaInfo.appName = displayName
        ipaInfo.executableName = executableName
        ipaInfo.bundleIdentifier = plist["CFBundleIdentifier"] as? String
        ipaInfo.version = plist["CFBundleShortVersionString"] as? String
        ipaInfo.buildNumber = plist["CFBundleVersion"] as? String
        ipaInfo.minimumOSVersion = plist["MinimumOSVersion"] as? String

        log("Basic info extracted: \(displayName ?? "Unknown"), executable: \(executableName ?? "Unknown")")
    }

    private func extractAppIcon(from appURL: URL, into ipaInfo: inout IPAInfo) {
        // Try multiple icon locations
        let possibleIconPaths = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png",
            "AppIcon76x76@2x~ipad.png",
            "Icon-60@2x.png",
            "Icon-60@3x.png",
            "AppIcon.png"
        ]

        for iconName in possibleIconPaths {
            let iconURL = appURL.appendingPathComponent(iconName)
            if fileManager.fileExists(atPath: iconURL.path),
               let imageData = try? Data(contentsOf: iconURL) {
                ipaInfo.appIcon = imageData
                log("App icon found: \(iconName)")
                return
            }
        }

        // Try Assets.car extraction if no direct icon found
        log("No direct icon found, checking Assets.car...")
    }

    private func analyzeFileStructure(appURL: URL, into ipaInfo: inout IPAInfo) {
        // Analyze frameworks
        let frameworksURL = appURL.appendingPathComponent("Frameworks")
        if fileManager.fileExists(atPath: frameworksURL.path) {
            var frameworks: [FrameworkInfo] = []
            if let contents = try? fileManager.contentsOfDirectory(atPath: frameworksURL.path) {
                for item in contents where item.hasSuffix(".framework") || item.hasSuffix(".dylib") {
                    let itemURL = frameworksURL.appendingPathComponent(item)
                    if let size = getSize(of: itemURL) {
                        frameworks.append(FrameworkInfo(name: item, size: size, path: itemURL.path))
                    }
                }
            }
            ipaInfo.frameworks = frameworks.sorted { $0.size > $1.size }
        }

        // Get binary size
        let executableName = appURL.deletingPathExtension().lastPathComponent
        let binaryURL = appURL.appendingPathComponent(executableName)
        ipaInfo.binarySize = getSize(of: binaryURL)

        // Detect architectures
        ipaInfo.architectures = detectArchitectures(binaryURL: binaryURL)

        // Find largest assets
        ipaInfo.largestAssets = findLargestAssets(in: appURL)

        log("File structure analyzed")
    }

    private func extractProvisioningProfile(from appURL: URL, into ipaInfo: inout IPAInfo) throws {
        let profileURL = appURL.appendingPathComponent("embedded.mobileprovision")
        guard fileManager.fileExists(atPath: profileURL.path) else {
            throw InspectionError.missingProvisioningProfile
        }

        guard let securityURL = findExecutable("security") else {
            throw InspectionError.missingTool("security")
        }

        let decodeTask = Process()
        let pipe = Pipe()
        decodeTask.executableURL = securityURL
        decodeTask.arguments = ["cms", "-D", "-i", profileURL.path]
        decodeTask.standardOutput = pipe

        try decodeTask.run()
        decodeTask.waitUntilExit()

        guard decodeTask.terminationStatus == 0 else {
            throw InspectionError.provisioningProfileDecodeFailed
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw InspectionError.invalidProvisioningProfile
        }

        var profile = ProvisioningProfileInfo()
        profile.name = extractXMLValue(key: "Name", from: xmlString)
        profile.appIDName = extractXMLValue(key: "AppIDName", from: xmlString)
        profile.applicationIdentifier = extractXMLValue(key: "application-identifier", from: xmlString)
        profile.teamName = extractXMLValue(key: "TeamName", from: xmlString)
        profile.teamIdentifier = extractXMLValue(key: "TeamIdentifier", from: xmlString)
        profile.uuid = extractXMLValue(key: "UUID", from: xmlString)

        let formatter = ISO8601DateFormatter()
        if let creationStr = extractXMLValue(key: "CreationDate", from: xmlString, pattern: "<date>([^<]+)</date>") {
            profile.creationDate = formatter.date(from: creationStr)
        }
        if let expirationStr = extractXMLValue(key: "ExpirationDate", from: xmlString, pattern: "<date>([^<]+)</date>") {
            profile.expirationDate = formatter.date(from: expirationStr)
        }

        // Extract provisioned devices
        profile.provisionedDevices = extractDevicesList(from: xmlString)

        // Determine profile type
        profile.profileType = determineProfileType(from: xmlString, devices: profile.provisionedDevices)

        // Extract certificate info
        profile.certificate = extractCertificateInfo(from: xmlString, profileURL: profileURL)

        ipaInfo.provisioningProfile = profile
        log("Provisioning profile extracted")
    }

    private func extractEntitlements(from appURL: URL, into ipaInfo: inout IPAInfo) {
        log("Extracting entitlements from app binary...")

        // Find the main executable - use executableName from Info.plist
        guard let executableName = ipaInfo.executableName else {
            log("No executable name found in Info.plist")
            return
        }

        let executableURL = appURL.appendingPathComponent(executableName)
        log("Looking for executable at: \(executableURL.path)")

        // Use codesign to extract entitlements
        let codesignTask = Process()
        codesignTask.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignTask.arguments = ["-d", "--entitlements", ":-", executableURL.path]

        let pipe = Pipe()
        codesignTask.standardOutput = pipe
        codesignTask.standardError = Pipe()

        do {
            try codesignTask.run()
            codesignTask.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if codesignTask.terminationStatus == 0, !data.isEmpty {
                log("Successfully extracted entitlements plist")

                // Parse the plist
                if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    var entitlements: [EntitlementInfo] = []

                    // Common entitlement descriptions
                    let entitlementDescriptions: [String: String] = [
                        "application-identifier": "App ID",
                        "com.apple.developer.team-identifier": "Team ID",
                        "get-task-allow": "Debug mode",
                        "keychain-access-groups": "Keychain access groups",
                        "com.apple.developer.associated-domains": "Associated domains",
                        "com.apple.developer.icloud-container-identifiers": "iCloud containers",
                        "com.apple.developer.ubiquity-kvstore-identifier": "iCloud key-value store",
                        "com.apple.developer.in-app-payments": "In-app payments",
                        "com.apple.developer.networking.networkextension": "Network extension",
                        "com.apple.developer.homekit": "HomeKit",
                        "com.apple.developer.healthkit": "HealthKit",
                        "com.apple.security.application-groups": "App groups",
                        "com.apple.developer.siri": "Siri",
                        "com.apple.developer.maps": "Maps",
                        "com.apple.developer.networking.wifi-info": "WiFi info",
                        "com.apple.developer.networking.vpn.api": "VPN",
                        "com.apple.developer.networking.HotspotConfiguration": "Hotspot configuration",
                        "com.apple.developer.nfc.readersession.formats": "NFC reader",
                        "com.apple.developer.payment-pass-provisioning": "Wallet",
                        "com.apple.external-accessory.wireless-configuration": "External accessory",
                        "inter-app-audio": "Inter-app audio",
                        "com.apple.developer.networking.multipath": "Multipath networking"
                    ]

                    for (key, value) in plist {
                        let description = entitlementDescriptions[key] ?? key
                        let valueString: String
                        let isEnabled: Bool

                        if let boolValue = value as? Bool {
                            valueString = boolValue ? "Yes" : "No"
                            isEnabled = boolValue
                        } else if let stringValue = value as? String {
                            valueString = stringValue
                            isEnabled = true
                        } else if let arrayValue = value as? [Any] {
                            valueString = "[\(arrayValue.count) items]"
                            isEnabled = !arrayValue.isEmpty
                        } else if let dictValue = value as? [String: Any] {
                            valueString = "{\(dictValue.count) keys}"
                            isEnabled = !dictValue.isEmpty
                        } else {
                            valueString = "\(value)"
                            isEnabled = true
                        }

                        let entitlement = EntitlementInfo(
                            key: key,
                            value: valueString,
                            description: description,
                            isEnabled: isEnabled
                        )
                        entitlements.append(entitlement)
                    }

                    log("Extracted \(entitlements.count) entitlements")
                    ipaInfo.entitlements = entitlements.sorted { $0.key < $1.key }
                } else {
                    log("Failed to parse entitlements plist")
                }
            } else {
                log("No entitlements found or codesign failed with status \(codesignTask.terminationStatus)")
            }
        } catch {
            log("Failed to extract entitlements: \(error.localizedDescription)")
        }
    }

    private func detectExtensions(in appURL: URL, into ipaInfo: inout IPAInfo) {
        let plugInsURL = appURL.appendingPathComponent("PlugIns")
        guard fileManager.fileExists(atPath: plugInsURL.path) else { return }

        var extensions: [ExtensionInfo] = []
        if let contents = try? fileManager.contentsOfDirectory(atPath: plugInsURL.path) {
            for item in contents where item.hasSuffix(".appex") {
                let extURL = plugInsURL.appendingPathComponent(item)
                let size = getSize(of: extURL) ?? 0

                // Try to read extension's Info.plist
                let extPlistURL = extURL.appendingPathComponent("Info.plist")
                var bundleID = ""
                var type: ExtensionInfo.ExtensionType = .unknown

                if let plistData = try? Data(contentsOf: extPlistURL),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                    bundleID = plist["CFBundleIdentifier"] as? String ?? ""

                    if let extensionDict = plist["NSExtension"] as? [String: Any],
                       let pointIdentifier = extensionDict["NSExtensionPointIdentifier"] as? String {
                        type = mapExtensionType(pointIdentifier)
                    }
                }

                extensions.append(ExtensionInfo(
                    name: item.replacingOccurrences(of: ".appex", with: ""),
                    bundleIdentifier: bundleID,
                    type: type,
                    size: size
                ))
            }
        }

        ipaInfo.extensions = extensions
        log("Found \(extensions.count) extensions")
    }

    private func extractLocalizationInfo(from appURL: URL, into ipaInfo: inout IPAInfo) {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: appURL.path) else { return }

        let languages = contents.filter { $0.hasSuffix(".lproj") }.map { $0.replacingOccurrences(of: ".lproj", with: "") }
        ipaInfo.supportedLanguages = languages
        log("Found \(languages.count) localizations")
    }

    private func extractNetworkSettings(from appURL: URL, into ipaInfo: inout IPAInfo) {
        let infoPlistURL = appURL.appendingPathComponent("Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let atsDict = plist["NSAppTransportSecurity"] as? [String: Any] else { return }

        var networkSettings = NetworkSettingsInfo()
        networkSettings.allowsArbitraryLoads = atsDict["NSAllowsArbitraryLoads"] as? Bool
        // Parse exception domains etc.

        ipaInfo.networkSettings = networkSettings
        log("Network settings extracted")
    }

    private func verifyCodeSignature(appURL: URL, into ipaInfo: inout IPAInfo) {
        guard let codesignURL = findExecutable("codesign") else { return }

        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.executableURL = codesignURL
        task.arguments = ["-vv", "--deep", appURL.path]
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            var signature = CodeSignatureInfo(isValid: task.terminationStatus == 0)

            if task.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorText = String(data: errorData, encoding: .utf8) {
                    signature.errors = errorText.components(separatedBy: "\n").filter { !$0.isEmpty }
                }
            }

            ipaInfo.codeSignature = signature
            log("Code signature verified: \(signature.isValid ? "valid" : "invalid")")
        } catch {
            log("Code signature verification failed: \(error)")
        }
    }

    private func runValidationChecks(on ipaInfo: inout IPAInfo) {
        var issues: [ValidationIssue] = []

        // Check expiration
        if let expirationDate = ipaInfo.provisioningProfile?.expirationDate {
            let now = Date()
            if expirationDate < now {
                issues.append(ValidationIssue(
                    severity: .critical,
                    title: "Provisioning Profile Expired",
                    message: "The provisioning profile expired on \(expirationDate)",
                    suggestion: "Regenerate the provisioning profile in your Apple Developer account"
                ))
            } else if let daysLeft = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day, daysLeft < 30 {
                issues.append(ValidationIssue(
                    severity: .warning,
                    title: "Provisioning Profile Expiring Soon",
                    message: "The provisioning profile will expire in \(daysLeft) days",
                    suggestion: "Consider renewing the provisioning profile soon"
                ))
            }
        }

        // Check bundle ID mismatch
        if let plistBundleID = ipaInfo.bundleIdentifier,
           let profileBundleID = ipaInfo.provisioningProfile?.applicationIdentifier {
            let components = profileBundleID.split(separator: ".")
            if components.count > 1 {
                let cleanProfileID = components.dropFirst().joined(separator: ".")
                if cleanProfileID != "*" && !cleanProfileID.contains("*") && cleanProfileID != plistBundleID {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        title: "Bundle ID Mismatch",
                        message: "Info.plist: \(plistBundleID)\nProvisioning: \(cleanProfileID)",
                        suggestion: "Ensure bundle IDs match to avoid signing issues"
                    ))
                }
            }
        }

        // Check file size
        if ipaInfo.fileSize > 100 * 1024 * 1024 { // 100MB
            issues.append(ValidationIssue(
                severity: .info,
                title: "Large IPA Size",
                message: "IPA is \(ByteCountFormatter.string(fromByteCount: ipaInfo.fileSize, countStyle: .file))",
                suggestion: "Consider optimizing assets and removing unused resources"
            ))
        }

        // Check code signature
        if let signature = ipaInfo.codeSignature, !signature.isValid {
            issues.append(ValidationIssue(
                severity: .critical,
                title: "Invalid Code Signature",
                message: "The app's code signature verification failed",
                suggestion: "Re-sign the application with a valid certificate"
            ))
        }

        ipaInfo.validationIssues = issues
        log("Validation complete: \(issues.count) issues found")
    }

    // MARK: - Utility Methods

    private func findExecutable(_ name: String) -> URL? {
        let paths = ["/usr/bin/\(name)", "/bin/\(name)", "/usr/local/bin/\(name)"]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private func getSize(of url: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }

    private func detectArchitectures(binaryURL: URL) -> [String] {
        guard let lipoURL = findExecutable("lipo"),
              fileManager.fileExists(atPath: binaryURL.path) else { return [] }

        let task = Process()
        let pipe = Pipe()
        task.executableURL = lipoURL
        task.arguments = ["-archs", binaryURL.path]
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            }
        } catch {}

        return []
    }

    private func findLargestAssets(in appURL: URL) -> [AssetInfo] {
        var assets: [AssetInfo] = []
        guard let enumerator = fileManager.enumerator(at: appURL, includingPropertiesForKeys: [.fileSizeKey, .nameKey]) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size > 1024 * 1024 { // > 1MB
                let type = fileURL.pathExtension
                assets.append(AssetInfo(name: fileURL.lastPathComponent, size: Int64(size), type: type))
            }
        }

        return Array(assets.sorted { $0.size > $1.size }.prefix(10))
    }

    private func extractXMLValue(key: String, from xml: String, pattern: String = "<string>([^<]+)</string>") -> String? {
        guard let keyRange = xml.range(of: "<key>\(key)</key>") else { return nil }
        let rest = xml[keyRange.upperBound...]

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = rest as NSString
            let matches = regex.matches(in: String(rest), options: [], range: NSRange(location: 0, length: nsString.length))

            if let match = matches.first, match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                return nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}

        return nil
    }

    private func extractDevicesList(from xml: String) -> [String]? {
        guard let devicesRange = xml.range(of: "<key>ProvisionedDevices</key>") else { return nil }
        let rest = xml[devicesRange.upperBound...]

        guard let arrayStart = rest.range(of: "<array>"),
              let arrayEnd = rest.range(of: "</array>") else { return nil }

        let arrayContent = rest[arrayStart.upperBound..<arrayEnd.lowerBound]

        do {
            let regex = try NSRegularExpression(pattern: "<string>([^<]+)</string>", options: [])
            let nsString = arrayContent as NSString
            let matches = regex.matches(in: String(arrayContent), options: [], range: NSRange(location: 0, length: nsString.length))

            return matches.map { match in
                nsString.substring(with: match.range(at: 1))
            }
        } catch {}

        return nil
    }

    private func determineProfileType(from xml: String, devices: [String]?) -> ProvisioningProfileInfo.ProfileType {
        if xml.contains("<key>ProvisionsAllDevices</key>") {
            return .enterprise
        } else if devices == nil {
            return .appStore
        } else if xml.contains("get-task-allow") {
            return .development
        } else {
            return .adHoc
        }
    }

    private func extractCertificateInfo(from xml: String, profileURL: URL) -> CertificateInfo? {
        // Extract certificate data and parse with openssl
        // Simplified for now
        return nil
    }

    private func mapExtensionType(_ identifier: String) -> ExtensionInfo.ExtensionType {
        switch identifier {
        case let id where id.contains("widget"): return .widget
        case let id where id.contains("share"): return .shareExtension
        case let id where id.contains("today"): return .todayExtension
        case let id where id.contains("intents"): return .intents
        case let id where id.contains("notification"): return .notification
        case let id where id.contains("watchkit"): return .watchApp
        default: return .unknown
        }
    }
}

// MARK: - Inspection Error

enum InspectionError: LocalizedError {
    case missingTool(String)
    case timeout
    case unzipFailed(String)
    case invalidStructure(String)
    case securityViolation
    case invalidPlist
    case missingProvisioningProfile
    case provisioningProfileDecodeFailed
    case invalidProvisioningProfile
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool): return "Missing tool: \(tool)"
        case .timeout: return "Operation timed out"
        case .unzipFailed(let msg): return "Unzip failed: \(msg)"
        case .invalidStructure(let msg): return "Invalid IPA structure: \(msg)"
        case .securityViolation: return "Security violation detected"
        case .invalidPlist: return "Invalid Info.plist"
        case .missingProvisioningProfile: return "Missing embedded.mobileprovision"
        case .provisioningProfileDecodeFailed: return "Failed to decode provisioning profile"
        case .invalidProvisioningProfile: return "Invalid provisioning profile"
        case .unknown(let msg): return msg
        }
    }
}
