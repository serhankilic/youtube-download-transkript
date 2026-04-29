import Foundation

enum PythonLocator {
    static let minimumMajorVersion = 3
    static let minimumMinorVersion = 10

    static func preferredPythonURL(
        fileManager: FileManager = .default,
        virtualEnvironmentPythonURL: URL? = nil
    ) throws -> URL {
        let candidates = candidatePythonURLs(
            virtualEnvironmentPythonURL: virtualEnvironmentPythonURL
        )

        for candidate in candidates {
            guard fileManager.isExecutableFile(atPath: candidate.path) else { continue }
            guard let version = pythonVersion(at: candidate), isSupported(version: version) else { continue }
            return candidate
        }

        throw PythonLocatorError.unsupportedPythonVersion
    }

    private static func candidatePythonURLs(
        virtualEnvironmentPythonURL: URL?
    ) -> [URL] {
        var candidates: [URL] = []

        if let virtualEnvironmentPythonURL {
            candidates.append(virtualEnvironmentPythonURL)
        }

        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let commonDirectories = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin",
            "/usr/bin",
        ]

        let directories = uniqueStrings(in: pathEntries + commonDirectories)
        let executableNames = ["python3.13", "python3.12", "python3.11", "python3.10", "python3"]

        for directory in directories {
            for executableName in executableNames {
                candidates.append(URL(fileURLWithPath: directory).appendingPathComponent(executableName))
            }
        }

        return uniqueURLs(in: candidates)
    }

    private static func pythonVersion(at executableURL: URL) -> PythonVersion? {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = [
            "-c",
            "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')",
        ]
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let version = PythonVersion(output)
        else {
            return nil
        }

        return version
    }

    private static func isSupported(version: PythonVersion) -> Bool {
        version.major > minimumMajorVersion ||
            (version.major == minimumMajorVersion && version.minor >= minimumMinorVersion)
    }

    private static func uniqueStrings(in values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }

        return ordered
    }

    private static func uniqueURLs(in values: [URL]) -> [URL] {
        var seen = Set<String>()
        var ordered: [URL] = []

        for value in values where seen.insert(value.path).inserted {
            ordered.append(value)
        }

        return ordered
    }
}

struct PythonVersion: Equatable {
    let major: Int
    let minor: Int

    init?(_ rawValue: String) {
        let components = rawValue.split(separator: ".", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let major = Int(components[0]),
              let minor = Int(components[1])
        else {
            return nil
        }

        self.major = major
        self.minor = minor
    }
}

enum PythonLocatorError: LocalizedError {
    case unsupportedPythonVersion

    var errorDescription: String? {
        switch self {
        case .unsupportedPythonVersion:
            return "Python 3.10 veya üstü bulunamadı. Lütfen Homebrew ya da python.org ile Python 3.10+ kurup tekrar dene."
        }
    }
}
