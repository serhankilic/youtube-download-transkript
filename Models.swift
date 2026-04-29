import Foundation

enum LanguageOption: String, CaseIterable, Codable {
    case automatic
    case turkish
    case arabic

    var displayName: String {
        switch self {
        case .automatic:
            return "Otomatik Algıla"
        case .turkish:
            return "Türkçe"
        case .arabic:
            return "Arapça"
        }
    }

    var backendValue: String? {
        switch self {
        case .automatic:
            return nil
        case .turkish:
            return "tr"
        case .arabic:
            return "ar"
        }
    }
}

enum ModelOption: String, CaseIterable, Codable {
    case fast
    case balanced
    case quality

    var displayName: String {
        switch self {
        case .fast:
            return "Hızlı"
        case .balanced:
            return "Dengeli"
        case .quality:
            return "Kaliteli"
        }
    }

    var backendValue: String {
        switch self {
        case .fast:
            return "base"
        case .balanced:
            return "small"
        case .quality:
            return "medium"
        }
    }
}

enum TranscriptionStep: String, Codable, CaseIterable {
    case idle
    case checkingBackend = "checking_backend"
    case downloadingAudio = "downloading_audio"
    case audioReady = "audio_ready"
    case loadingModel = "loading_model"
    case transcribing
    case savingTxt = "saving_txt"
    case completed
    case failed

    var displayName: String {
        switch self {
        case .idle:
            return "Hazır"
        case .checkingBackend:
            return "Backend Kontrolü"
        case .downloadingAudio:
            return "Ses İndiriliyor"
        case .audioReady:
            return "Ses Hazır"
        case .loadingModel:
            return "Model Yükleniyor"
        case .transcribing:
            return "Transkript Oluşturuluyor"
        case .savingTxt:
            return "TXT Kaydediliyor"
        case .completed:
            return "Tamamlandı"
        case .failed:
            return "Hata"
        }
    }

    var description: String {
        switch self {
        case .idle:
            return "İşlem başlatılmayı bekliyor."
        case .checkingBackend:
            return "Python backend ve gerekli araçlar kontrol ediliyor."
        case .downloadingAudio:
            return "YouTube videosundan ses dosyası indiriliyor."
        case .audioReady:
            return "Ses dosyası hazırlandı ve işlenmeye hazır."
        case .loadingModel:
            return "Whisper modeli belleğe yükleniyor."
        case .transcribing:
            return "Ses içeriği metne dönüştürülüyor."
        case .savingTxt:
            return "Transkript TXT dosyası olarak kaydediliyor."
        case .completed:
            return "Tüm işlem başarıyla tamamlandı."
        case .failed:
            return "İşlem bir hatayla durdu."
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
}

struct BackendEvent: Codable, Equatable {
    let type: String
    let step: String?
    let message: String
    let detail: String?
}

struct TranscriptionResult: Codable, Equatable {
    let success: Bool
    let transcript: String?
    let txt_path: String?
    let audio_path: String?
    let output_dir: String?
    let error: String?
    let step: String?
    let detail: String?
}

struct UserFacingError: Equatable {
    let title: String
    let message: String
    let detail: String?
    let step: TranscriptionStep
}
