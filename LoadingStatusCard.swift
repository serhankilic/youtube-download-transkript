import SwiftUI

struct LoadingStatusCard: View {
    let currentStep: TranscriptionStep
    let currentStepMessage: String
    let isProcessing: Bool
    let hasError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Durum")
                        .font(DS.Font.eyebrow)
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.fg3)
                    Text(titleText)
                        .font(DS.Font.h3)
                        .foregroundStyle(DS.Color.fg1)
                    Text(currentStepMessage.isEmpty ? currentStep.description : currentStepMessage)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Color.fg3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .controlSize(.large)
                        .tint(DS.Color.accent)
                } else {
                    Image(systemName: statusSymbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
            }

            ProgressView(value: progressValue)
                .tint(statusColor)
                .controlSize(.small)

            VStack(spacing: 10) {
                ForEach(stageItems) { stage in
                    stageRow(for: stage)
                }
            }
        }
        .dsCard()
    }

    private var titleText: String {
        hasError ? "İşlem Durduruldu" : currentStep.displayName
    }

    private var statusSymbolName: String {
        if hasError || currentStep == .failed {
            return "xmark.octagon.fill"
        }
        if currentStep == .completed {
            return "checkmark.circle.fill"
        }
        return "circle.dashed"
    }

    private var statusColor: Color {
        if hasError || currentStep == .failed {
            return DS.Color.danger
        }
        if currentStep == .completed {
            return DS.Color.success
        }
        return DS.Color.accent
    }

    private var progressValue: Double {
        guard let currentIndex = stageItems.firstIndex(where: { stageContainsCurrentStep($0) }) else {
            return currentStep == .completed ? 1.0 : 0.02
        }

        if currentStep == .completed {
            return 1.0
        }

        return (Double(currentIndex) + (isProcessing ? 0.5 : 1.0)) / Double(stageItems.count)
    }

    private var stageItems: [StageItem] {
        [
            StageItem(title: "Backend kontrolü", subtitle: "Python, ffmpeg ve temel hazırlıklar doğrulanıyor.", coveredSteps: [.checkingBackend]),
            StageItem(title: "Ses indiriliyor", subtitle: "Video sesi güvenli dosya adıyla kaydediliyor.", coveredSteps: [.downloadingAudio, .audioReady]),
            StageItem(title: "Model yükleniyor", subtitle: "Whisper modeli belleğe hazırlanıyor.", coveredSteps: [.loadingModel]),
            StageItem(title: "Transkript çıkarılıyor", subtitle: "Ses metne dönüştürülüyor.", coveredSteps: [.transcribing]),
            StageItem(title: "Dosya kaydediliyor", subtitle: "TXT çıktısı oluşturuluyor.", coveredSteps: [.savingTxt]),
            StageItem(title: "Tamamlandı", subtitle: "Tüm çıktılar hazır.", coveredSteps: [.completed])
        ]
    }

    private func stageContainsCurrentStep(_ item: StageItem) -> Bool {
        item.coveredSteps.contains(currentStep)
    }

    private func isStageCompleted(_ item: StageItem) -> Bool {
        if currentStep == .completed {
            return true
        }

        guard let currentIndex = stageItems.firstIndex(where: { stageContainsCurrentStep($0) }),
              let itemIndex = stageItems.firstIndex(where: { $0.id == item.id }) else {
            return false
        }

        return itemIndex < currentIndex
    }

    private func stageRow(for item: StageItem) -> some View {
        let state = stageState(for: item)

        return HStack(spacing: 12) {
            Image(systemName: state.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(state.tint)
                .frame(width: 22, height: 22)
                .background(state.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(DS.Font.small.weight(.semibold))
                    .foregroundStyle(DS.Color.fg1)
                Text(item.subtitle)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Color.fg3)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(state.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(state.border, lineWidth: 1)
        )
    }

    private func stageState(for item: StageItem) -> StageVisualState {
        if (hasError || currentStep == .failed), stageContainsCurrentStep(item) {
            return StageVisualState(
                symbolName: "exclamationmark.triangle.fill",
                tint: DS.Color.danger,
                background: DS.Color.danger.opacity(0.10),
                border: DS.Color.danger.opacity(0.22)
            )
        }

        if item.coveredSteps.contains(currentStep) && currentStep != .completed {
            return StageVisualState(
                symbolName: "arrow.triangle.2.circlepath",
                tint: DS.Color.accent,
                background: DS.Color.accent.opacity(0.12),
                border: DS.Color.accent.opacity(0.28)
            )
        }

        if isStageCompleted(item) {
            return StageVisualState(
                symbolName: "checkmark",
                tint: DS.Color.success,
                background: DS.Color.success.opacity(0.10),
                border: DS.Color.success.opacity(0.22)
            )
        }

        return StageVisualState(
            symbolName: "circle",
            tint: DS.Color.fg3,
            background: DS.Color.bg3.opacity(0.58),
            border: DS.Color.line1
        )
    }
}

private struct StageItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coveredSteps: [TranscriptionStep]
}

private struct StageVisualState {
    let symbolName: String
    let tint: Color
    let background: Color
    let border: Color
}
