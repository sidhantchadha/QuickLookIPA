import SwiftUI
import UniformTypeIdentifiers

@main
struct IPAInspectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var ipaInfoSections: [(title: String, content: String, isWarning: Bool?)] = []
    @State private var isTargeted = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if ipaInfoSections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Drag and drop an .ipa file here")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(ipaInfoSections.indices, id: \ .self) { index in
                            let section = ipaInfoSections[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(section.content)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(section.isWarning == nil ? .primary : (section.isWarning! ? .red : .green))
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
                .padding(.top)
            
            Text("Built with ❤️ by Sidhant Chadha")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(isTargeted ? Color.gray.opacity(0.2) : Color.clear)
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let fileURL = url, fileURL.pathExtension == "ipa" {
                        inspectIPA(at: fileURL)
                    } else {
                        errorMessage = "Please drop a valid .ipa file."
                        ipaInfoSections = []
                    }
                }
                return true
            }
            return false
        }
        .padding()
    }
    
    func inspectIPA(at url: URL) {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        DispatchQueue.main.async {
            errorMessage = nil
            ipaInfoSections = []
        }

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let unzipTask = Process()
            unzipTask.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipTask.arguments = [url.path, "-d", tempDir.path]
            try unzipTask.run()
            unzipTask.waitUntilExit()

            let payloadURL = tempDir.appendingPathComponent("Payload")
            let appPaths = try fileManager.contentsOfDirectory(atPath: payloadURL.path)
            guard let appName = appPaths.first(where: { $0.hasSuffix(".app") }) else {
                DispatchQueue.main.async { errorMessage = "Could not find .app bundle inside the .ipa" }
                return
            }

            let appURL = payloadURL.appendingPathComponent(appName)
            let infoPlistURL = appURL.appendingPathComponent("Info.plist")

            if let plistData = try? Data(contentsOf: infoPlistURL),
               let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {

                // Extract version info
                if let bundleVersion = plist["CFBundleShortVersionString"] as? String,
                   let buildNumber = plist["CFBundleVersion"] as? String {
                    DispatchQueue.main.async {
                        ipaInfoSections.append(("App Version", "Version: \(bundleVersion) (Build \(buildNumber))", nil))
                    }
                }

                // Extract bundle ID
                if let bundleID = plist["CFBundleIdentifier"] as? String {
                    DispatchQueue.main.async {
                        ipaInfoSections.append(("Bundle ID (Info.plist)", bundleID, nil))
                    }
                }
            }

            let embeddedProfile = appURL.appendingPathComponent("embedded.mobileprovision")

            if fileManager.fileExists(atPath: embeddedProfile.path) {
                let decodeTask = Process()
                let pipe = Pipe()
                decodeTask.executableURL = URL(fileURLWithPath: "/usr/bin/security")
                decodeTask.arguments = ["cms", "-D", "-i", embeddedProfile.path]
                decodeTask.standardOutput = pipe
                try decodeTask.run()
                decodeTask.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let formattedSections = formatProvisioningProfile(output)
                    DispatchQueue.main.async {
                        ipaInfoSections.append(contentsOf: formattedSections)
                    }
                }
            } else {
                DispatchQueue.main.async { errorMessage = "No embedded.mobileprovision found." }
            }
        } catch {
            DispatchQueue.main.async { errorMessage = "Failed to inspect .ipa: \(error.localizedDescription)" }
        }
    }

    
    func extractDate(forKey key: String, from xml: String, using formatter: ISO8601DateFormatter) -> Date? {
        guard let keyRange = xml.range(of: "<key>\(key)</key>") else { return nil }
        let rest = xml[keyRange.upperBound...]
        if let dateRange = rest.range(of: "<date>(.*?)</date>", options: .regularExpression) {
            let rawDate = String(rest[dateRange])
                .replacingOccurrences(of: "<date>", with: "")
                .replacingOccurrences(of: "</date>", with: "")
            return formatter.date(from: rawDate)
        }
        return nil
    }
    
    func formatProvisioningProfile(_ rawXML: String) -> [(title: String, content: String, isWarning: Bool?)] {
        var sections: [(String, String, Bool?)] = []
        let keys = ["Name", "AppIDName", "application-identifier", "TeamName", "UUID"]

        for key in keys {
            if let keyRange = rawXML.range(of: "<key>\(key)</key>") {
                let rest = rawXML[keyRange.upperBound...]
                if let stringRange = rest.range(of: "<string>(.*?)</string>", options: .regularExpression) {
                    let value = String(rest[stringRange])
                        .replacingOccurrences(of: "<string>", with: "")
                        .replacingOccurrences(of: "</string>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // Format the display label for better readability
                    let displayKey = key == "application-identifier" ? "Application Identifier (Provisioning Profile)" : key
                    sections.append((displayKey, value, nil))
                }
            }
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let labelFormatter = DateFormatter()
        labelFormatter.dateStyle = .medium
        labelFormatter.timeStyle = .short
        
        let now = Date()
        if let creationDate = extractDate(forKey: "CreationDate", from: rawXML, using: dateFormatter) {
            let daysAgo = Calendar.current.dateComponents([.day], from: creationDate, to: now).day ?? 0
            let dateString = labelFormatter.string(from: creationDate) + " (\(daysAgo) days ago)"
            sections.append(("Provisioning Profile Creation Date", dateString, nil))
        }
        
        if let expirationDate = extractDate(forKey: "ExpirationDate", from: rawXML, using: dateFormatter) {
            let daysLeft = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0
            let dateString = labelFormatter.string(from: expirationDate) + " (\(daysLeft) days left)"
            let isWarning = daysLeft < 0
            sections.append(("Provisioning Profile Expiration Date", dateString, isWarning))
        }
        
        if let certDataRange = rawXML.range(of: "<data>([A-Za-z0-9+/=\n\r]+)</data>", options: .regularExpression) {
            let base64 = rawXML[certDataRange]
                .replacingOccurrences(of: "<data>", with: "")
                .replacingOccurrences(of: "</data>", with: "")
                .replacingOccurrences(of: "\n", with: "")
            if let certData = Data(base64Encoded: base64) {
                let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".cer")
                try? certData.write(to: tempPath)
                
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
                process.arguments = ["x509", "-inform", "DER", "-in", tempPath.path, "-noout", "-startdate"]
                process.standardOutput = pipe
                try? process.run()
                process.waitUntilExit()
                
                let certOutput = pipe.fileHandleForReading.readDataToEndOfFile()
                if let certText = String(data: certOutput, encoding: .utf8),
                   let startLine = certText.split(separator: "\n").first(where: { $0.contains("notBefore") }) ?? certText.split(separator: "\n").first {
                    let rawStartDate = startLine.replacingOccurrences(of: "notBefore=", with: "").trimmingCharacters(in: .whitespaces)
                    let opensslFormatter = DateFormatter()
                    opensslFormatter.dateFormat = "MMM d HH:mm:ss yyyy z"
                    if let parsedDate = opensslFormatter.date(from: rawStartDate) {
                        let certDaysAgo = Calendar.current.dateComponents([.day], from: parsedDate, to: now).day ?? 0
                        let certDisplay = labelFormatter.string(from: parsedDate) + " (\(certDaysAgo) days ago)"
                        sections.append(("Distribution Certificate Created", certDisplay, nil))
                    }
                }
            }
        }
        
        sections.append(("Raw XML", rawXML, nil))
        return sections
    }
}
