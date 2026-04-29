import SwiftUI

struct LoadingStatusCard: View {
    let currentStep: TranscriptionStep
    let currentStepMessage: String
    let isProcessing: Bool
    let hasError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DS.Color.accent)
                    } else {
                        Image(systemName: statusSymbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(DS.Font.h4)
                        .foregroundStyle(DS.Color.fg1)
                    Text(currentStepMessage.isEmpty ? currentStep.description : currentStepMessage)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Color.fg3)
                        .lineLimit(1)
                }

                Spacer()
                
                if currentStep != .idle {
                    Text(currentStep == .completed ? "100%" : (isProcessing ? "..." : ""))
                        .font(DS.Font.mono.weight(.bold))
                        .foregroundStyle(statusColor)
                }
            }
            
            if isProcessing || currentStep == .completed || hasError {
                ProgressView(value: progressValue)
                    .tint(statusColor)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .dsCard()
    }

    private var titleText: String {
        hasError ? "Hata" : currentStep.displayName
    }

    private var statusSymbolName: String {
        if hasError || currentStep == .failed {
            return "xmark.octagon.fill"
        }
        if currentStep == .completed {
            return "checkmark.circle.fill"
        }
        return "hourglass.badge.plus"
    }

    private var statusColor: Color {
        if hasError || currentStep == .failed {
            return DS.Color.danger
        }
        if currentStep == .completed {
            return DS.Color.success
        }
        if isProcessing {
            return DS.Color.accent
        }
        return DS.Color.fg3
    }

    private var progressValue: Double {
        let steps: [TranscriptionStep] = [.idle, .checkingBackend, .downloadingAudio, .loadingModel, .transcribing, .savingTxt, .completed]
        guard let currentIndex = steps.firstIndex(of: currentStep) else { return 0 }
        if currentStep == .completed { return 1.0 }
        return Double(currentIndex) / Double(steps.count - 1)
    }
}
