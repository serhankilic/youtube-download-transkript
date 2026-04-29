import Foundation

struct PythonRunner {
    private let processFactory: () -> Process
    private let jsonDecoder: JSONDecoder
    private let fileManager: FileManager

    init(
        processFactory: @escaping () -> Process = { Process() },
        jsonDecoder: JSONDecoder = JSONDecoder(),
        fileManager: FileManager = .default
    ) {
        self.processFactory = processFactory
        self.jsonDecoder = jsonDecoder
        self.fileManager = fileManager
    }

    func runTranscription(
        url: String,
        language: LanguageOption,
        model: ModelOption,
        autoDeleteAudio _: Bool,
        onEvent: @escaping (BackendEvent) -> Void,
        onRawLog: @escaping (String) -> Void
    ) async throws -> TranscriptionResult {
        let scriptURL = (try? BackendEnvironment.runtimeScriptURL(fileManager: fileManager))
            ?? Self.resolveScriptURL(fileManager: fileManager)
        let pythonExecutableURL: URL

        do {
            pythonExecutableURL = try BackendEnvironment.runtimePythonExecutableURL(fileManager: fileManager)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas."
            throw PythonRunnerError(
                title: "Backend başlatılamadı",
                message: message,
                detail: error.localizedDescription,
                step: .checkingBackend
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = processFactory()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let state = RunnerState(decoder: jsonDecoder, onEvent: onEvent, onRawLog: onRawLog)

            process.executableURL = pythonExecutableURL
            process.arguments = makeArguments(
                scriptURL: scriptURL,
                url: url,
                language: language,
                model: model
            )
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.currentDirectoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
            process.environment = BackendEnvironment.environmentWithHuggingFaceToken(fileManager: fileManager)

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    state.finishStdout()
                    return
                }
                state.appendStdout(data)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    state.finishStderr()
                    return
                }
                state.appendStderr(data)
            }

            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingStdout.isEmpty {
                    state.appendStdout(remainingStdout)
                }
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingStderr.isEmpty {
                    state.appendStderr(remainingStderr)
                }
                state.finishStdout()
                state.finishStderr()

                do {
                    let result = try state.makeResult(exitCode: process.terminationStatus)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let message: String
                if let localizedError = error as? LocalizedError,
                   let description = localizedError.errorDescription {
                    message = description
                } else {
                    message = "Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas."
                }
                continuation.resume(
                    throwing: PythonRunnerError(
                        title: "Backend başlatılamadı",
                        message: message,
                        detail: error.localizedDescription,
                        step: .checkingBackend
                    )
                )
            }
        }
    }

    private func makeArguments(
        scriptURL: URL,
        url: String,
        language: LanguageOption,
        model: ModelOption
    ) -> [String] {
        var arguments = [scriptURL.path, url]

        arguments.append(contentsOf: ["--model", model.backendValue])

        if let languageValue = language.backendValue {
            arguments.append(contentsOf: ["--language", languageValue])
        }

        return arguments
    }

    private static func resolveScriptURL(fileManager: FileManager) -> URL {
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Backend/transcriber.py"),
            Bundle.main.resourceURL?.appendingPathComponent("Backend/transcriber.py"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Backend/transcriber.py")
        ]

        for candidate in candidates.compactMap({ $0 }) where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        return URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Backend/transcriber.py")
    }
}

private final class RunnerState {
    private let decoder: JSONDecoder
    private let onEvent: (BackendEvent) -> Void
    private let onRawLog: (String) -> Void
    private let lock = NSLock()

    private var stdoutData = Data()
    private var stderrBuffer = Data()
    private var stderrLogs: [String] = []
    private var lastStep: TranscriptionStep = .idle

    init(
        decoder: JSONDecoder,
        onEvent: @escaping (BackendEvent) -> Void,
        onRawLog: @escaping (String) -> Void
    ) {
        self.decoder = decoder
        self.onEvent = onEvent
        self.onRawLog = onRawLog
    }

    func appendStdout(_ data: Data) {
        lock.lock()
        stdoutData.append(data)
        lock.unlock()
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        stderrBuffer.append(data)
        let lines = consumeLines(from: &stderrBuffer)
        lock.unlock()

        for line in lines {
            handleStderrLine(line)
        }
    }

    func finishStdout() {
        lock.withLock { }
    }

    func finishStderr() {
        lock.lock()
        let remainingLine = consumeTrailingLine(from: &stderrBuffer)
        lock.unlock()

        if let remainingLine, !remainingLine.isEmpty {
            handleStderrLine(remainingLine)
        }
    }

    func makeResult(exitCode: Int32) throws -> TranscriptionResult {
        let stdoutString = lock.withLock {
            String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        let stderrText = lock.withLock {
            stderrLogs.joined(separator: "\n").nilIfEmpty
        }

        if stdoutString.isEmpty {
            throw PythonRunnerError(
                title: "Backend sonucu eksik",
                message: "Beklenmeyen bir hata oluştu. Teknik detayları kontrol edip tekrar dene.",
                detail: stderrText,
                step: lastKnownStep()
            )
        }

        let resultJSON = try extractResultJSON(from: stdoutString)
        let finalStdoutData = Data(resultJSON.utf8)
        let result = try decodeResult(from: finalStdoutData)

        if exitCode == 0, result.success {
            return result
        }

        if let backendError = makeBackendError(from: result) {
            throw backendError
        }

        throw PythonRunnerError(
            title: "İşlem tamamlanamadı",
            message: userFriendlyMessage(from: stderrLogs),
            detail: stderrText ?? stdoutString,
            step: lastKnownStep()
        )
    }

    private func extractResultJSON(from stdoutString: String) throws -> String {
        let lines = stdoutString
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines.reversed() where line.hasPrefix("{") && line.hasSuffix("}") {
            if let data = line.data(using: .utf8),
               (try? decoder.decode(TranscriptionResult.self, from: data)) != nil {
                return line
            }
        }

        if stdoutString.hasPrefix("{"), stdoutString.hasSuffix("}") {
            return stdoutString
        }

        throw PythonRunnerError(
            title: "Backend sonucu okunamadı",
            message: "Beklenmeyen bir hata oluştu. Teknik detayları kontrol edip tekrar dene.",
            detail: stdoutString,
            step: lastKnownStep()
        )
    }

    private func decodeResult(from data: Data) throws -> TranscriptionResult {
        do {
            return try decoder.decode(TranscriptionResult.self, from: data)
        } catch {
            throw PythonRunnerError(
                title: "Backend sonucu okunamadı",
                message: "Beklenmeyen bir hata oluştu. Teknik detayları kontrol edip tekrar dene.",
                detail: error.localizedDescription,
                step: lastKnownStep()
            )
        }
    }

    private func handleStderrLine(_ line: String) {
        guard !line.isEmpty else { return }

        if let data = line.data(using: .utf8),
           let event = try? decoder.decode(BackendEvent.self, from: data) {
            if let step = event.step, let transcriptionStep = TranscriptionStep(rawValue: step) {
                lock.withLock {
                    lastStep = transcriptionStep
                }
            }
            Task { @MainActor in
                onEvent(event)
            }
            return
        }

        lock.withLock {
            stderrLogs.append(line)
        }

        Task { @MainActor in
            onRawLog(line)
        }
    }

    private func consumeLines(from buffer: inout Data) -> [String] {
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

    private func consumeTrailingLine(from buffer: inout Data) -> String? {
        guard !buffer.isEmpty else { return nil }
        defer { buffer.removeAll() }
        return String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeBackendError(from result: TranscriptionResult) -> PythonRunnerError? {
        guard let errorMessage = result.error, !errorMessage.isEmpty else {
            return nil
        }

        return PythonRunnerError(
            title: "İşlem tamamlanamadı",
            message: errorMessage,
            detail: result.detail ?? lock.withLock { stderrLogs.joined(separator: "\n").nilIfEmpty },
            step: TranscriptionStep(rawValue: result.step ?? "") ?? lastKnownStep()
        )
    }

    private func lastKnownStep() -> TranscriptionStep {
        lock.withLock {
            lastStep == .idle ? .failed : lastStep
        }
    }

    private func userFriendlyMessage(from logs: [String]) -> String {
        let combined = logs.joined(separator: "\n").lowercased()

        if combined.contains("ffmpeg") {
            return "Ses işleme aracı ffmpeg bulunamadı. Kurulum için: brew install ffmpeg"
        }
        if combined.contains("url boş geldi") {
            return "Devam etmek için bir YouTube linki yapıştırmalısın."
        }
        if combined.contains("geçersiz url") || combined.contains("desteklenmeyen alan adı") {
            return "Bu geçerli bir YouTube linki gibi görünmüyor."
        }
        if combined.contains("no module named") || combined.contains("modulenotfounderror") || combined.contains("can't open file") {
            return "Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas."
        }
        if combined.contains("python 3.10") || combined.contains("python 3.10 veya üstü") {
            return "Python 3.10 veya üstü bulunamadı. Lütfen Homebrew ya da python.org ile Python 3.10+ kurup tekrar dene."
        }
        if combined.contains("yt-dlp") || combined.contains("youtube") {
            return "Video sesi indirilemedi. Link gizli, silinmiş, yaş kısıtlı veya erişilemez olabilir."
        }
        if combined.contains("whisper modeli") || combined.contains("loading_model") {
            return "Whisper modeli yüklenemedi. İnternet bağlantını kontrol edip tekrar dene."
        }
        if combined.contains("whisper") || combined.contains("transcribing") {
            return "Ses transkripte dönüştürülürken hata oluştu."
        }
        if combined.contains("permission denied") || combined.contains("read-only file system") {
            return "Çıktı dosyası kaydedilemedi. Disk alanını ve klasör izinlerini kontrol et."
        }

        return "Beklenmeyen bir hata oluştu. Teknik detayları kontrol edip tekrar dene."
    }
}

private struct PythonRunnerError: LocalizedError {
    let title: String
    let message: String
    let detail: String?
    let step: TranscriptionStep

    var errorDescription: String? {
        message
    }
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self, !value.isEmpty else {
            return nil
        }
        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
