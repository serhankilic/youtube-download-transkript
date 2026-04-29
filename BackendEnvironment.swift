import Foundation

enum BackendEnvironment {
    static let appFolderName = "LocalTranscript"
    static let huggingFaceTokenEnvironmentKeys = ["HF_TOKEN", "HUGGING_FACE_HUB_TOKEN"]

    static func runtimeRootURL(fileManager: FileManager = .default) throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BackendEnvironmentError.applicationSupportUnavailable
        }

        let rootURL = baseURL.appendingPathComponent(appFolderName, isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    static func runtimeBackendURL(fileManager: FileManager = .default) throws -> URL {
        try runtimeRootURL(fileManager: fileManager).appendingPathComponent("Backend", isDirectory: true)
    }

    static func outputsDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        try runtimeRootURL(fileManager: fileManager).appendingPathComponent("outputs", isDirectory: true)
    }

    static func huggingFaceToken(fileManager: FileManager = .default) -> String? {
        for key in huggingFaceTokenEnvironmentKeys {
            if let token = ProcessInfo.processInfo.environment[key]?.trimmedToken, !token.isEmpty {
                return token
            }
        }

        let runtimeRoot = try? runtimeRootURL(fileManager: fileManager)
        let candidateFiles = [
            runtimeRoot?.appendingPathComponent(".env"),
            runtimeRoot?.appendingPathComponent("hf_token"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache/huggingface/token"),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".huggingface/token")
        ].compactMap { $0 }

        for candidateFile in candidateFiles {
            if candidateFile.lastPathComponent == ".env",
               let token = dotenvToken(at: candidateFile),
               !token.isEmpty {
                return token
            }

            if candidateFile.lastPathComponent != ".env",
               let token = plainToken(at: candidateFile),
               !token.isEmpty {
                return token
            }
        }

        return nil
    }

    static func environmentWithHuggingFaceToken(
        fileManager: FileManager = .default,
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = baseEnvironment
        guard let token = huggingFaceToken(fileManager: fileManager) else {
            return environment
        }

        for key in huggingFaceTokenEnvironmentKeys where environment[key]?.isEmpty ?? true {
            environment[key] = token
        }

        return environment
    }

    static func prepareRuntimeBackend(fileManager: FileManager = .default) throws -> URL {
        let sourceURL = try sourceBackendURL(fileManager: fileManager)
        let targetURL = try runtimeBackendURL(fileManager: fileManager)

        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try syncBackendFiles(from: sourceURL, to: targetURL, fileManager: fileManager)

        return targetURL
    }

    static func runtimeScriptURL(fileManager: FileManager = .default) throws -> URL {
        try prepareRuntimeBackend(fileManager: fileManager).appendingPathComponent("transcriber.py")
    }

    static func requirementsURL(fileManager: FileManager = .default) throws -> URL {
        try prepareRuntimeBackend(fileManager: fileManager).appendingPathComponent("requirements.txt")
    }

    static func runtimePythonExecutableURL(fileManager: FileManager = .default) throws -> URL {
        let backendURL = try prepareRuntimeBackend(fileManager: fileManager)
        let venvPythonURL = backendURL.appendingPathComponent(".venv/bin/python3")
        return try PythonLocator.preferredPythonURL(
            fileManager: fileManager,
            virtualEnvironmentPythonURL: venvPythonURL
        )
    }

    private static func sourceBackendURL(fileManager: FileManager) throws -> URL {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("Backend", isDirectory: true),
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Backend", isDirectory: true)
        ]

        for candidate in candidates.compactMap({ $0 }) where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        throw BackendEnvironmentError.bundledBackendMissing
    }

    private static func syncBackendFiles(from sourceURL: URL, to targetURL: URL, fileManager: FileManager) throws {
        let sourceContents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for sourceItemURL in sourceContents {
            let targetItemURL = targetURL.appendingPathComponent(sourceItemURL.lastPathComponent, isDirectory: false)
            if fileManager.fileExists(atPath: targetItemURL.path) {
                try fileManager.removeItem(at: targetItemURL)
            }
            try fileManager.copyItem(at: sourceItemURL, to: targetItemURL)
        }
    }

    private static func dotenvToken(at url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
                continue
            }

            let parts = trimmedLine.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  huggingFaceTokenEnvironmentKeys.contains(String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)) else {
                continue
            }

            return String(parts[1]).trimmedToken
        }

        return nil
    }

    private static func plainToken(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8).trimmedToken
    }
}

private extension String {
    var trimmedToken: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}

enum BackendEnvironmentError: LocalizedError {
    case bundledBackendMissing
    case applicationSupportUnavailable
    case unsupportedPythonVersion

    var errorDescription: String? {
        switch self {
        case .bundledBackendMissing:
            return "Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas."
        case .applicationSupportUnavailable:
            return "Uygulama veri klasörü hazırlanamadı."
        case .unsupportedPythonVersion:
            return "Python 3.10 veya üstü bulunamadı. Lütfen Homebrew ya da python.org ile Python 3.10+ kurup tekrar dene."
        }
    }
}
