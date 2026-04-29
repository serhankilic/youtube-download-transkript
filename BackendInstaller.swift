import Foundation

struct BackendInstaller {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func install(onLog: @escaping (String) async -> Void) async throws {
        let backendURL = try BackendEnvironment.prepareRuntimeBackend(fileManager: fileManager)
        let venvDirectoryURL = backendURL.appendingPathComponent(".venv", isDirectory: true)
        let venvPythonURL = backendURL.appendingPathComponent(".venv/bin/python3")
        let requirementsURL = try BackendEnvironment.requirementsURL(fileManager: fileManager)
        let systemPythonURL = try PythonLocator.preferredPythonURL(
            fileManager: fileManager,
            virtualEnvironmentPythonURL: nil
        )

        await onLog("Backend klasoru hazirlaniyor...")
        if fileManager.fileExists(atPath: venvDirectoryURL.path) {
            try fileManager.removeItem(at: venvDirectoryURL)
        }
        try await runProcess(
            executableURL: systemPythonURL,
            arguments: ["-m", "venv", venvDirectoryURL.path],
            currentDirectoryURL: backendURL.deletingLastPathComponent(),
            onLog: onLog
        )

        await onLog("Python paket yoneticisi guncelleniyor...")
        try await runProcess(
            executableURL: venvPythonURL,
            arguments: ["-m", "pip", "install", "--upgrade", "pip"],
            currentDirectoryURL: backendURL,
            onLog: onLog
        )

        await onLog("Backend bagimliliklari kuruluyor...")
        try await runProcess(
            executableURL: venvPythonURL,
            arguments: ["-m", "pip", "install", "-r", requirementsURL.path],
            currentDirectoryURL: backendURL,
            onLog: onLog
        )

        if BackendEnvironment.huggingFaceToken(fileManager: fileManager) == nil {
            await onLog("Hugging Face token bulunamadi. Model indirme anonim devam eder; daha yuksek limit icin HF_TOKEN ekle.")
        } else {
            await onLog("Hugging Face token bulundu ve model indirme asamasinda kullanilacak.")
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL,
        onLog: @escaping (String) async -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            let state = InstallerLogState(onLog: onLog)

            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL
            process.standardOutput = pipe
            process.standardError = pipe
            process.environment = BackendEnvironment.environmentWithHuggingFaceToken(fileManager: fileManager)

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    state.flush()
                    return
                }
                state.append(data)
            }

            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil
                let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remainder.isEmpty {
                    state.append(remainder)
                }
                state.flush()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: BackendInstallerError.installationFailed(detail: state.collectedLogs)
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    throwing: BackendInstallerError.installationFailed(
                        detail: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    )
                )
            }
        }
    }
}

private final class InstallerLogState {
    private let lock = NSLock()
    private var buffer = Data()
    private(set) var collectedLogs = ""
    private let onLog: (String) async -> Void

    init(onLog: @escaping (String) async -> Void) {
        self.onLog = onLog
    }

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        let lines = consumeLines()
        lock.unlock()

        for line in lines where !line.isEmpty {
            record(line)
        }
    }

    func flush() {
        lock.lock()
        let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeAll()
        lock.unlock()

        if let line, !line.isEmpty {
            record(line)
        }
    }

    private func consumeLines() -> [String] {
        var lines: [String] = []

        while let newlineRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lines.append(line)
            buffer.removeSubrange(0...newlineRange.lowerBound)
        }

        return lines
    }

    private func record(_ line: String) {
        lock.withLock {
            collectedLogs = collectedLogs.isEmpty ? line : collectedLogs + "\n" + line
        }

        Task {
            await onLog(line)
        }
    }
}

enum BackendInstallerError: LocalizedError {
    case installationFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .installationFailed:
            return "Backend kurulumu tamamlanamadı. Teknik detayları kontrol edip tekrar dene."
        }
    }

    var failureReason: String? {
        switch self {
        case .installationFailed(let detail):
            return detail
        }
    }
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
