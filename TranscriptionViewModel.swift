import AppKit
import Foundation

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var youtubeURL: String = ""
    @Published var selectedLanguage: LanguageOption
    @Published var selectedModel: ModelOption
    @Published var autoDeleteAudio: Bool = true
    @Published var isProcessing: Bool = false
    @Published var currentStep: TranscriptionStep = .idle
    @Published var currentStepMessage: String = TranscriptionStep.idle.description
    @Published var logs: String = ""
    @Published var rawTechnicalLogs: String = ""
    @Published var transcript: String = ""
    @Published var txtPath: String?
    @Published var audioPath: String?
    @Published var outputDir: String?
    @Published var errorTitle: String?
    @Published var errorMessage: String?
    @Published var errorDetail: String?

    private let runner: PythonRunner
    private let backendInstaller: BackendInstaller
    private let fileManager: FileManager

    init(
        runner: PythonRunner = PythonRunner(),
        backendInstaller: BackendInstaller = BackendInstaller(),
        fileManager: FileManager = .default,
        selectedLanguage: LanguageOption = .automatic,
        selectedModel: ModelOption = .balanced
    ) {
        self.runner = runner
        self.backendInstaller = backendInstaller
        self.fileManager = fileManager
        self.selectedLanguage = selectedLanguage
        self.selectedModel = selectedModel
    }

    func startTranscription() {
        resetForNewRun()
        isProcessing = true
        currentStep = .checkingBackend
        currentStepMessage = "Backend başlatılıyor..."

        Task {
            do {
                let result = try await runner.runTranscription(
                    url: youtubeURL,
                    language: selectedLanguage,
                    model: selectedModel,
                    autoDeleteAudio: autoDeleteAudio,
                    onEvent: { [weak self] event in
                        self?.handle(event: event)
                    },
                    onRawLog: { [weak self] rawLine in
                        self?.appendRawTechnicalLog(rawLine)
                    }
                )

                applySuccessResult(result)
            } catch {
                applyFailure(error)
            }
        }
    }

    func retry() {
        clearError()
        startTranscription()
    }

    func pasteYouTubeURLFromClipboard() {
        guard let pastedValue = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !pastedValue.isEmpty else {
            presentError(
                title: "Panoda bağlantı bulunamadı",
                message: "Panoda yapıştırılacak bir metin bulunamadı.",
                detail: nil,
                step: activeOrFailedStep
            )
            return
        }

        youtubeURL = pastedValue
        appendLog("Bağlantı panodan yapıştırıldı.")
    }

    func clearYouTubeURL() {
        youtubeURL = ""
    }

    func copyTranscriptToClipboard() {
        guard !transcript.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        appendLog("Transkript panoya kopyalandı.")
    }

    func clearError() {
        errorTitle = nil
        errorMessage = nil
        errorDetail = nil
    }

    func installBackend() {
        clearError()
        isProcessing = true
        currentStep = .checkingBackend
        currentStepMessage = "Backend kuruluyor..."
        appendLog("Backend kurulumu baslatildi.")

        Task {
            do {
                try await backendInstaller.install { [weak self] line in
                    await MainActor.run {
                        self?.appendRawTechnicalLog(line)
                    }
                }

                isProcessing = false
                currentStep = .idle
                currentStepMessage = "Backend kurulumu tamamlandi."
                appendLog("Backend kurulumu tamamlandi.")
            } catch {
                isProcessing = false
                currentStep = .failed
                currentStepMessage = "Backend kurulumu tamamlanamadi."
                presentError(
                    title: "Backend kurulumu tamamlanamadi",
                    message: "Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas.",
                    detail: failureDetail(from: error),
                    step: .failed
                )
            }
        }
    }

    func openTxtInFinder() {
        revealFileInFinder(
            path: txtPath,
            missingTitle: "TXT dosyası bulunamadı",
            missingMessage: "Gösterilecek TXT dosyası bulunamadı."
        )
    }

    func openAudioInFinder() {
        revealFileInFinder(
            path: audioPath,
            missingTitle: "Ses dosyası bulunamadı",
            missingMessage: "Ses dosyası bulunamadı."
        )
    }

    func openOutputFolderInFinder() {
        let preferredURL = outputDir.map { URL(fileURLWithPath: $0) }
        let fallbackURL = (try? BackendEnvironment.outputsDirectoryURL(fileManager: fileManager))
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("outputs", isDirectory: true)
        let destinationURL: URL?

        if let preferredURL, fileManager.fileExists(atPath: preferredURL.path) {
            destinationURL = preferredURL
        } else if fileManager.fileExists(atPath: fallbackURL.path) {
            destinationURL = fallbackURL
        } else {
            destinationURL = nil
        }

        guard let destinationURL else {
            presentError(
                title: "Outputs klasörü bulunamadı",
                message: "Açılacak bir outputs klasörü bulunamadı.",
                detail: fallbackURL.path,
                step: currentStep == .idle ? .failed : currentStep
            )
            return
        }

        NSWorkspace.shared.open(destinationURL)
    }

    func deleteAudioFile() {
        deleteFile(
            path: audioPath,
            clearBoundPath: { self.audioPath = nil },
            missingTitle: "Ses dosyası bulunamadı",
            missingMessage: "Silinecek bir ses dosyası bulunamadı.",
            deleteErrorTitle: "Ses dosyası silinemedi",
            deleteErrorMessage: "İndirilen ses dosyası silinemedi.",
            successLogMessage: "Ses dosyası silindi."
        )
    }

    func cleanTemporaryAudioFiles() {
        let outputsDirectory = (try? BackendEnvironment.outputsDirectoryURL(fileManager: fileManager))
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("outputs", isDirectory: true)
        let audioDirectory = outputsDirectory.appendingPathComponent("audio", isDirectory: true)
        guard fileManager.fileExists(atPath: audioDirectory.path) else {
            presentError(
                title: "Geçici ses klasörü bulunamadı",
                message: "Temizlenecek bir ses klasörü bulunamadı.",
                detail: audioDirectory.path,
                step: currentStep == .idle ? .failed : currentStep
            )
            return
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let audioExtensions = Set(["mp3", "m4a", "wav", "webm", "mp4", "ogg", "opus", "aac", "flac"])

            for fileURL in contents where audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                try fileManager.removeItem(at: fileURL)
            }

            if let audioPath, audioPath.hasPrefix(audioDirectory.path) {
                self.audioPath = nil
            }

            appendLog("Geçici ses dosyaları temizlendi.")
        } catch {
            presentError(
                title: "Geçici dosyalar temizlenemedi",
                message: "Geçici ses dosyaları silinirken bir hata oluştu.",
                detail: error.localizedDescription,
                step: currentStep == .idle ? .failed : currentStep
            )
        }
    }

    private func resetForNewRun() {
        clearError()
        isProcessing = false
        currentStep = .idle
        currentStepMessage = TranscriptionStep.idle.description
        logs = ""
        rawTechnicalLogs = ""
        transcript = ""
        txtPath = nil
        audioPath = nil
        outputDir = nil
    }

    private func handle(event: BackendEvent) {
        if let stepValue = event.step, let step = TranscriptionStep(rawValue: stepValue) {
            currentStep = step
        } else if event.type == "error" {
            currentStep = .failed
        }

        currentStepMessage = event.message
        appendLog(event.message)
        if let detail = event.detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendRawTechnicalLog(detail)
        }

        if event.type == "error" {
            presentError(
                title: "İşlem sırasında hata oluştu",
                message: event.message,
                detail: event.detail,
                step: currentStep == .idle ? .failed : currentStep
            )
        }
    }

    private func applySuccessResult(_ result: TranscriptionResult) {
        isProcessing = false

        if result.success {
            clearError()
            transcript = result.transcript ?? ""
            txtPath = result.txt_path
            audioPath = result.audio_path
            outputDir = result.output_dir
            currentStep = .completed
            currentStepMessage = "İşlem başarıyla tamamlandı."

            if autoDeleteAudio {
                deleteAudioFileAfterSuccessfulRun()
            }

            appendLog("İşlem tamamlandı.")
            return
        }

        let step = TranscriptionStep(rawValue: result.step ?? "") ?? .failed
        currentStep = .failed
        currentStepMessage = result.error ?? TranscriptionStep.failed.description
        presentError(
            title: "Transkript oluşturulamadı",
            message: result.error ?? "İşlem tamamlanamadı.",
            detail: result.detail,
            step: step
        )
    }

    private func applyFailure(_ error: Error) {
        isProcessing = false
        currentStep = .failed

        if let runnerError = error as? LocalizedError {
            let message = runnerError.errorDescription ?? "İşlem tamamlanamadı."
            currentStepMessage = message
            presentError(
                title: "Transkript oluşturulamadı",
                message: message,
                detail: failureDetail(from: error),
                step: currentStep
            )
        } else {
            currentStepMessage = "İşlem tamamlanamadı."
            presentError(
                title: "Transkript oluşturulamadı",
                message: "İşlem tamamlanamadı.",
                detail: failureDetail(from: error),
                step: currentStep
            )
        }
    }

    private func presentError(title: String, message: String, detail: String?, step: TranscriptionStep) {
        errorTitle = title
        errorMessage = message
        errorDetail = resolvedTechnicalDetail(detail, against: message)
        if step == .idle {
            currentStep = .failed
        }
    }

    private func deleteAudioFileAfterSuccessfulRun() {
        deleteFile(
            path: audioPath,
            clearBoundPath: { self.audioPath = nil },
            missingTitle: "Ses dosyası bulunamadı",
            missingMessage: "Otomatik silinecek ses dosyası bulunamadı.",
            deleteErrorTitle: "Ses dosyası otomatik silinemedi",
            deleteErrorMessage: "İndirilen ses dosyası otomatik olarak silinemedi.",
            successLogMessage: "Ses dosyası otomatik silindi.",
            showMissingError: false
        )
    }

    private func revealFileInFinder(path: String?, missingTitle: String, missingMessage: String) {
        guard let fileURL = validatedFileURL(
            for: path,
            missingTitle: missingTitle,
            missingMessage: missingMessage
        ) else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    private func validatedFileURL(for path: String?, missingTitle: String, missingMessage: String) -> URL? {
        guard let path, !path.isEmpty else {
            presentError(title: missingTitle, message: missingMessage, detail: nil, step: activeOrFailedStep)
            return nil
        }

        let fileURL = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            presentError(title: missingTitle, message: missingMessage, detail: path, step: activeOrFailedStep)
            return nil
        }

        return fileURL
    }

    private func deleteFile(
        path: String?,
        clearBoundPath: () -> Void,
        missingTitle: String,
        missingMessage: String,
        deleteErrorTitle: String,
        deleteErrorMessage: String,
        successLogMessage: String,
        showMissingError: Bool = true
    ) {
        guard let path, !path.isEmpty else {
            if showMissingError {
                presentError(title: missingTitle, message: missingMessage, detail: nil, step: activeOrFailedStep)
            }
            return
        }

        let fileURL = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            clearBoundPath()
            if showMissingError {
                presentError(title: missingTitle, message: missingMessage, detail: path, step: activeOrFailedStep)
            }
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
            clearBoundPath()
            appendLog(successLogMessage)
        } catch {
            presentError(
                title: deleteErrorTitle,
                message: deleteErrorMessage,
                detail: error.localizedDescription,
                step: activeOrFailedStep
            )
        }
    }

    private func appendLog(_ message: String) {
        logs = appendLine(message, to: logs)
    }

    private func appendRawTechnicalLog(_ message: String) {
        rawTechnicalLogs = appendLine(message, to: rawTechnicalLogs)
    }

    private func appendLine(_ message: String, to existing: String) -> String {
        guard !message.isEmpty else { return existing }
        if existing.isEmpty {
            return message
        }
        return existing + "\n" + message
    }

    private func failureDetail(from error: Error) -> String? {
        let nsError = error as NSError
        if !nsError.localizedFailureReason.orEmpty.isEmpty {
            return nsError.localizedFailureReason
        }
        if !nsError.localizedRecoverySuggestion.orEmpty.isEmpty {
            return nsError.localizedRecoverySuggestion
        }
        let description = nsError.localizedDescription
        return description.isEmpty ? nil : description
    }

    private var activeOrFailedStep: TranscriptionStep {
        currentStep == .idle ? .failed : currentStep
    }

    private func resolvedTechnicalDetail(_ detail: String?, against message: String) -> String? {
        if let detail = sanitizedDetail(detail, against: message) {
            return detail
        }

        let fallback = rawTechnicalLogs.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }

    private func sanitizedDetail(_ detail: String?, against message: String) -> String? {
        guard let detail else { return nil }
        let normalizedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedDetail.isEmpty, normalizedDetail != normalizedMessage else {
            return nil
        }

        return normalizedDetail
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
