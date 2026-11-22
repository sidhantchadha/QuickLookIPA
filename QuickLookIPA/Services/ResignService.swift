//
//  ResignService.swift
//  QuickLookIPA
//
//  Created by Claude Code on 11/21/26.
//  Service for resigning IPA files with new provisioning profiles and certificates,
//  including security-scoped resource handling and comprehensive error reporting.
//

import Foundation
import AppKit

class ResignService {
    static let shared = ResignService()

    private init() {}

    enum ResignError: Error, LocalizedError {
        case invalidIPA
        case missingProvisioningProfile
        case missingCertificate
        case unzipFailed
        case codesignFailed(String)
        case zipFailed
        case fileSystemError(String)

        var errorDescription: String? {
            switch self {
            case .invalidIPA:
                return "Invalid IPA file"
            case .missingProvisioningProfile:
                return "Provisioning profile not found"
            case .missingCertificate:
                return "Signing certificate not found"
            case .unzipFailed:
                return "Failed to extract IPA"
            case .codesignFailed(let message):
                return "Code signing failed: \(message)"
            case .zipFailed:
                return "Failed to create resigned IPA"
            case .fileSystemError(let message):
                return "File system error: \(message)"
            }
        }
    }

    struct ResignOptions {
        let ipaURL: URL
        let provisioningProfileURL: URL
        let certificateName: String
        let bundleIdentifier: String?
        let outputURL: URL

        init(ipaURL: URL, provisioningProfileURL: URL, certificateName: String, bundleIdentifier: String? = nil, outputURL: URL) {
            self.ipaURL = ipaURL
            self.provisioningProfileURL = provisioningProfileURL
            self.certificateName = certificateName
            self.bundleIdentifier = bundleIdentifier
            self.outputURL = outputURL
        }
    }

    // MARK: - Main Resign Method
    func resign(options: ResignOptions, progress: @escaping (String, Double) -> Void, completion: @escaping (Result<URL, ResignError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Start accessing security-scoped resources
            let ipaAccessGranted = options.ipaURL.startAccessingSecurityScopedResource()
            let profileAccessGranted = options.provisioningProfileURL.startAccessingSecurityScopedResource()

            defer {
                if ipaAccessGranted {
                    options.ipaURL.stopAccessingSecurityScopedResource()
                }
                if profileAccessGranted {
                    options.provisioningProfileURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // Create temp directory
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                defer {
                    try? FileManager.default.removeItem(at: tempDir)
                }

                // Step 1: Extract IPA
                progress("Extracting IPA...", 0.1)
                let payloadDir = try self.extractIPA(options.ipaURL, to: tempDir)

                // Step 2: Find .app directory
                progress("Locating app bundle...", 0.2)
                guard let appDir = try self.findAppDirectory(in: payloadDir) else {
                    throw ResignError.invalidIPA
                }

                // Step 3: Replace provisioning profile
                progress("Replacing provisioning profile...", 0.3)
                try self.replaceProvisioningProfile(in: appDir, with: options.provisioningProfileURL)

                // Step 4: Update bundle identifier if provided
                if let bundleID = options.bundleIdentifier {
                    progress("Updating bundle identifier...", 0.4)
                    try self.updateBundleIdentifier(in: appDir, to: bundleID)
                }

                // Step 5: Remove old code signature
                progress("Removing old code signature...", 0.5)
                try self.removeCodeSignature(from: appDir)

                // Step 6: Sign frameworks and plugins
                progress("Signing frameworks...", 0.6)
                try self.signFrameworksAndPlugins(in: appDir, certificate: options.certificateName)

                // Step 7: Sign main app
                progress("Signing application...", 0.7)
                try self.signApp(appDir, certificate: options.certificateName)

                // Step 8: Repackage IPA
                progress("Creating resigned IPA...", 0.9)
                try self.repackageIPA(payloadDir: payloadDir, outputURL: options.outputURL)

                progress("Resign complete!", 1.0)

                DispatchQueue.main.async {
                    completion(.success(options.outputURL))
                }
            } catch let error as ResignError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.fileSystemError(error.localizedDescription)))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func extractIPA(_ ipaURL: URL, to tempDir: URL) throws -> URL {
        // Verify IPA file exists and is readable
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            throw ResignError.fileSystemError("IPA file not found at: \(ipaURL.path)")
        }

        guard FileManager.default.isReadableFile(atPath: ipaURL.path) else {
            throw ResignError.fileSystemError("IPA file is not readable: \(ipaURL.path)")
        }

        let unzipTask = Process()
        unzipTask.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipTask.arguments = ["-q", ipaURL.path, "-d", tempDir.path]

        let pipe = Pipe()
        unzipTask.standardError = pipe

        try unzipTask.run()
        unzipTask.waitUntilExit()

        guard unzipTask.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ResignError.fileSystemError("Failed to extract IPA: \(errorMessage)")
        }

        let payloadDir = tempDir.appendingPathComponent("Payload")
        guard FileManager.default.fileExists(atPath: payloadDir.path) else {
            throw ResignError.fileSystemError("Payload directory not found after extraction")
        }

        return payloadDir
    }

    private func findAppDirectory(in payloadDir: URL) throws -> URL? {
        let contents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        return contents.first { $0.pathExtension == "app" }
    }

    private func replaceProvisioningProfile(in appDir: URL, with profileURL: URL) throws {
        let embeddedProfile = appDir.appendingPathComponent("embedded.mobileprovision")

        // Remove old profile if exists
        try? FileManager.default.removeItem(at: embeddedProfile)

        // Copy new profile
        try FileManager.default.copyItem(at: profileURL, to: embeddedProfile)
    }

    private func updateBundleIdentifier(in appDir: URL, to bundleID: String) throws {
        let infoPlistURL = appDir.appendingPathComponent("Info.plist")

        // Read plist
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw ResignError.fileSystemError("Could not read Info.plist")
        }

        // Update bundle identifier
        plist["CFBundleIdentifier"] = bundleID

        // Write back
        let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try updatedData.write(to: infoPlistURL)
    }

    private func removeCodeSignature(from appDir: URL) throws {
        let codeSignatureDir = appDir.appendingPathComponent("_CodeSignature")
        try? FileManager.default.removeItem(at: codeSignatureDir)
    }

    private func signFrameworksAndPlugins(in appDir: URL, certificate: String) throws {
        // Sign Frameworks
        let frameworksDir = appDir.appendingPathComponent("Frameworks")
        if FileManager.default.fileExists(atPath: frameworksDir.path) {
            let frameworks = try FileManager.default.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil)
            for framework in frameworks {
                try signBundle(framework, certificate: certificate)
            }
        }

        // Sign PlugIns
        let pluginsDir = appDir.appendingPathComponent("PlugIns")
        if FileManager.default.fileExists(atPath: pluginsDir.path) {
            let plugins = try FileManager.default.contentsOfDirectory(at: pluginsDir, includingPropertiesForKeys: nil)
            for plugin in plugins {
                try signBundle(plugin, certificate: certificate)
            }
        }
    }

    private func signApp(_ appDir: URL, certificate: String) throws {
        try signBundle(appDir, certificate: certificate)
    }

    private func signBundle(_ bundleURL: URL, certificate: String) throws {
        let codesignTask = Process()
        codesignTask.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignTask.arguments = [
            "-f",
            "-s", certificate,
            "--generate-entitlement-der",
            bundleURL.path
        ]

        let pipe = Pipe()
        codesignTask.standardError = pipe

        try codesignTask.run()
        codesignTask.waitUntilExit()

        if codesignTask.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ResignError.codesignFailed(errorMessage)
        }
    }

    private func repackageIPA(payloadDir: URL, outputURL: URL) throws {
        let parentDir = payloadDir.deletingLastPathComponent()

        let zipTask = Process()
        zipTask.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zipTask.arguments = [
            "-c", "-k",
            "--sequesterRsrc",
            "--keepParent",
            "Payload",
            outputURL.path
        ]
        zipTask.currentDirectoryURL = parentDir

        try zipTask.run()
        zipTask.waitUntilExit()

        guard zipTask.terminationStatus == 0 else {
            throw ResignError.zipFailed
        }
    }

    // MARK: - Get Available Certificates
    func getAvailableCertificates() -> [String] {
        let securityTask = Process()
        securityTask.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        securityTask.arguments = ["find-identity", "-v", "-p", "codesigning"]

        let pipe = Pipe()
        securityTask.standardOutput = pipe

        do {
            try securityTask.run()
            securityTask.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse certificate names
                let lines = output.components(separatedBy: "\n")
                var certificates: [String] = []

                for line in lines {
                    if line.contains("\"") {
                        let parts = line.components(separatedBy: "\"")
                        if parts.count >= 2 {
                            certificates.append(parts[1])
                        }
                    }
                }

                return certificates
            }
        } catch {
            print("Failed to get certificates: \(error)")
        }

        return []
    }
}
