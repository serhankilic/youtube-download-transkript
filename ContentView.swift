import AppKit
import SwiftUI

private enum LayoutMode {
    case compact
    case regular
    case wide
}

struct ContentView: View {
    @StateObject private var viewModel: TranscriptionViewModel
    @State private var showTechnicalDetails = false
    @State private var showDeleteAudioConfirmation = false
    @State private var showCleanAudioConfirmation = false

    init(viewModel: TranscriptionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            let mode = layoutMode(for: geometry.size.width)

            ZStack {
                appBackground

                responsiveContent(mode: mode, width: geometry.size.width)
                    .padding(contentPadding(for: mode))
            }
        }
        .frame(minWidth: 700, minHeight: 560)
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "İndirilen ses dosyasını silmek istiyor musun?",
            isPresented: $showDeleteAudioConfirmation,
            titleVisibility: .visible
        ) {
            Button("Ses Dosyasını Sil", role: .destructive) {
                viewModel.deleteAudioFile()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem yalnızca indirilen ses dosyasını siler. TXT dosyası korunur.")
        }
        .confirmationDialog(
            "Geçici ses dosyalarını temizlemek istiyor musun?",
            isPresented: $showCleanAudioConfirmation,
            titleVisibility: .visible
        ) {
            Button("Geçici Ses Dosyalarını Sil", role: .destructive) {
                viewModel.cleanTemporaryAudioFiles()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem sadece outputs/audio içindeki ses dosyalarını siler. Transkript dosyaları korunur.")
        }
    }

    private var appBackground: some View {
        ZStack {
            LinearGradient(
                colors: [DS.Color.bg0, DS.Color.bg1, DS.Color.bg0],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [DS.Color.accent.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 620
            )

            RadialGradient(
                colors: [DS.Color.bg4.opacity(0.38), .clear],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }

    private func layoutMode(for width: CGFloat) -> LayoutMode {
        if width >= 1240 {
            return .wide
        }
        if width >= 860 {
            return .regular
        }
        return .compact
    }

    private func contentPadding(for mode: LayoutMode) -> CGFloat {
        switch mode {
        case .wide:
            return 20
        case .regular:
            return 16
        case .compact:
            return 12
        }
    }

    private func sidebarWidth(for width: CGFloat) -> CGFloat {
        min(330, max(280, width * 0.27))
    }

    private func sideColumnWidth(for width: CGFloat) -> CGFloat {
        min(340, max(300, width * 0.24))
    }

    private func actionColumns(for mode: LayoutMode) -> [GridItem] {
        switch mode {
        case .compact:
            return [GridItem(.flexible(minimum: 0), spacing: 12)]
        case .regular, .wide:
            return [GridItem(.adaptive(minimum: 210), spacing: 12)]
        }
    }

    private func transcriptPreviewMinHeight(for mode: LayoutMode) -> CGFloat {
        switch mode {
        case .wide:
            return 300
        case .regular:
            return 260
        case .compact:
            return 220
        }
    }

    @ViewBuilder
    private func stack<Content: View>(
        horizontal: Bool,
        horizontalAlignment: VerticalAlignment,
        verticalAlignment: HorizontalAlignment,
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if horizontal {
            HStack(alignment: horizontalAlignment, spacing: spacing, content: content)
        } else {
            VStack(alignment: verticalAlignment, spacing: spacing, content: content)
        }
    }

    @ViewBuilder
    private func responsiveContent(mode: LayoutMode, width: CGFloat) -> some View {
        switch mode {
        case .wide:
            HStack(alignment: .top, spacing: 16) {
                sidebar(width: sidebarWidth(for: width), usesFlexibleSpacer: true)

                mainScroll {
                    mainCards(includeStatus: false, includeLogs: false, mode: mode)
                }

                VStack(spacing: 16) {
                    statusCard
                    logsCard
                }
                .frame(width: sideColumnWidth(for: width), alignment: .top)
            }

        case .regular:
            HStack(alignment: .top, spacing: 16) {
                sidebar(width: sidebarWidth(for: width), usesFlexibleSpacer: true)

                mainScroll {
                    mainCards(includeStatus: true, includeLogs: true, mode: mode)
                }
            }

        case .compact:
            mainScroll {
                VStack(alignment: .leading, spacing: 14) {
                    sidebar(width: nil, usesFlexibleSpacer: false)
                    mainCards(includeStatus: true, includeLogs: true, mode: mode)
                }
            }
        }
    }

    private func mainScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func mainCards(includeStatus: Bool, includeLogs: Bool, mode: LayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if includeStatus {
                statusCard
            }

            if viewModel.errorMessage != nil {
                errorBox(mode: mode)
            }

            transcriptCard(mode: mode)
            fileActionsCard(mode: mode)

            if includeLogs {
                logsCard
            }
        }
    }

    private var statusCard: some View {
        LoadingStatusCard(
            currentStep: viewModel.currentStep,
            currentStepMessage: stepDescriptionText,
            isProcessing: viewModel.isProcessing,
            hasError: viewModel.errorMessage != nil
        )
    }

    @ViewBuilder
    private func sidebar(width: CGFloat?, usesFlexibleSpacer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            brandBlock

            VStack(alignment: .leading, spacing: 16) {
                formField("YouTube linki") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Color.fg3)

                            URLTextField(
                                text: $viewModel.youtubeURL,
                                placeholder: "https://youtube.com/watch?v=...",
                                isEnabled: !viewModel.isProcessing
                            )
                            .frame(height: 36)
                        }
                        .padding(.horizontal, 12)
                        .background(DS.Color.bg4, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                                .stroke(DS.Color.line2, lineWidth: 0.5)
                        )

                        HStack(spacing: 8) {
                            Button("Panodan Yapıştır") {
                                viewModel.pasteYouTubeURLFromClipboard()
                            }
                            .buttonStyle(DSButtonStyle())
                            .disabled(viewModel.isProcessing)

                            Button("Sıfırla") {
                                viewModel.clearYouTubeURL()
                            }
                            .buttonStyle(DSButtonStyle(variant: .ghost))
                            .disabled(viewModel.youtubeURL.isEmpty || viewModel.isProcessing)
                        }
                    }
                }

                formField("Dil") {
                    Picker("Dil", selection: $viewModel.selectedLanguage) {
                        ForEach(languageOptions, id: \.optionIdentifier) { option in
                            Text(option.shortTitle).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isProcessing)
                }

                formField("Model") {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(modelOptions, id: \.optionIdentifier) { option in
                            Text(option.optionTitle).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isProcessing)
                }
            }

            if usesFlexibleSpacer {
                Spacer(minLength: 12)
            }

            VStack(spacing: 10) {
                Button {
                    viewModel.startTranscription()
                } label: {
                    Label("Transkript Oluştur", systemImage: "waveform.and.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButtonStyle(variant: .primary))
                .disabled(viewModel.isProcessing)

                Button {
                    viewModel.installBackend()
                } label: {
                    Label("Backend Kurulumu", systemImage: "shippingbox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButtonStyle())
                .disabled(viewModel.isProcessing)

                Button {
                    viewModel.retry()
                } label: {
                    Label("Tekrar Dene", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButtonStyle(variant: .ghost))
                .disabled(viewModel.isProcessing || viewModel.errorMessage == nil)
            }
        }
        .padding(22)
        .frame(maxWidth: width == nil ? .infinity : width, alignment: .topLeading)
        .frame(width: width)
        .frame(maxHeight: usesFlexibleSpacer ? .infinity : nil, alignment: .top)
        .dsPanel()
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [DS.Color.accent.opacity(0.95), DS.Color.accent.opacity(0.54)],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 42
                            )
                        )
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .shadow(color: DS.Color.accent.opacity(0.35), radius: 18, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Yerel transkript akışı")
                        .font(DS.Font.eyebrow)
                        .tracking(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.fg3)
                    Text("YouTube Tranksriptör")
                        .font(DS.Font.h4)
                        .foregroundStyle(DS.Color.fg1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Bağlantı yapıştırın, başlayın.")
                    .font(DS.Font.h2)
                    .foregroundStyle(DS.Color.fg1)
                    .tracking(0)
                Text("Video sesini yerelde indirip Whisper ile TXT transkripte dönüştürür.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.fg3)
                    .lineSpacing(3)
            }
        }
    }

    @ViewBuilder
    private func heroCard(mode: LayoutMode) -> some View {
        let isCompact = mode == .compact

        stack(horizontal: !isCompact, horizontalAlignment: .center, verticalAlignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                DSBadge(title: statusBadgeTitle, variant: statusBadgeVariant)
                Text("Sade ama premium bir yerel transkript deneyimi.")
                    .font(isCompact ? DS.Font.h1 : DS.Font.display)
                    .foregroundStyle(DS.Color.fg1)
                    .tracking(0)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Ne oluyor, bitti mi, dosyalar nerede? Ana akış tüm cevapları tek pencerede görünür tutar.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.fg3)
                    .lineSpacing(3)
            }

            if !isCompact {
                Spacer()
            }

            VStack(alignment: isCompact ? .leading : .trailing, spacing: 8) {
                metricPill(title: "TXT", value: viewModel.txtPath == nil ? "Bekliyor" : "Hazır")
                metricPill(title: "Ses", value: viewModel.audioPath == nil ? "Yok" : "İndirildi")
            }
            .frame(maxWidth: isCompact ? .infinity : nil, alignment: isCompact ? .leading : .trailing)
        }
        .dsCard(padding: isCompact ? 18 : 24, cornerRadius: 16)
    }

    @ViewBuilder
    private func errorBox(mode: LayoutMode) -> some View {
        let isCompact = mode == .compact

        VStack(alignment: .leading, spacing: 14) {
            stack(horizontal: !isCompact, horizontalAlignment: .top, verticalAlignment: .leading, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.danger)
                    .font(.system(size: 18, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.errorTitle ?? "İşlem tamamlanamadı")
                        .font(DS.Font.h4)
                        .foregroundStyle(DS.Color.fg1)
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !isCompact {
                    Spacer()
                }

                Button(showTechnicalDetails ? "Teknik Detayı Gizle" : "Teknik Detayı Göster") {
                    showTechnicalDetails.toggle()
                }
                .buttonStyle(DSButtonStyle(variant: .ghost))
                .frame(maxWidth: isCompact ? .infinity : nil, alignment: .leading)
            }

            if showTechnicalDetails {
                ScrollView {
                    Text(technicalDetailText)
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Color.fg3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 80, maxHeight: 140)
                .padding(12)
                .background(DS.Color.bg0.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                        .stroke(DS.Color.danger.opacity(0.24), lineWidth: 0.5)
                )
            }

            HStack(spacing: 8) {
                Button("Tekrar Dene") {
                    viewModel.retry()
                }
                .buttonStyle(DSButtonStyle(variant: .primary))
                .disabled(viewModel.isProcessing)

                Button("Kapat") {
                    viewModel.clearError()
                }
                .buttonStyle(DSButtonStyle())
            }
        }
        .dsCard(padding: 18, cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Color.danger.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func transcriptCard(mode: LayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(
                eyebrow: "İçerik",
                title: "Transkript önizleme",
                trailing: viewModel.isProcessing ? "İşlem devam ediyor" : nil
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isProcessing && viewModel.transcript.isEmpty {
                        SkeletonView(isProcessing: true, lineCount: 10)
                    } else if viewModel.transcript.isEmpty {
                        SkeletonView(isProcessing: false, lineCount: 9)
                    } else {
                        Text(viewModel.transcript)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.fg2)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: transcriptPreviewMinHeight(for: mode))
            .padding(16)
            .background(DS.Color.bg0.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line1, lineWidth: 0.5)
            )
        }
        .dsCard(padding: mode == .compact ? 16 : 20)
    }

    private func fileActionsCard(mode: LayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(eyebrow: "Çıktılar", title: "Dosya aksiyonları")

            LazyVGrid(columns: actionColumns(for: mode), spacing: 12) {
                actionButton("TXT Finder'da Göster", subtitle: viewModel.txtPath ?? "TXT hazır değil", systemImage: "doc.text") {
                    viewModel.openTxtInFinder()
                }
                .disabled(viewModel.txtPath == nil)

                actionButton("Ses Dosyasını Göster", subtitle: viewModel.audioPath ?? "Ses dosyası yok", systemImage: "waveform") {
                    viewModel.openAudioInFinder()
                }
                .disabled(viewModel.audioPath == nil)

                actionButton("Outputs Klasörünü Aç", subtitle: "Tüm çıktı klasörü", systemImage: "folder") {
                    viewModel.openOutputFolderInFinder()
                }

                actionButton("Ses Dosyasını Sil", subtitle: "TXT korunur", systemImage: "trash", isDanger: true) {
                    showDeleteAudioConfirmation = true
                }
                .disabled(viewModel.audioPath == nil || viewModel.isProcessing)

                actionButton("Geçici Sesleri Temizle", subtitle: "outputs/audio klasörü", systemImage: "sparkles", isDanger: true) {
                    showCleanAudioConfirmation = true
                }
                .disabled(viewModel.isProcessing)
            }
        }
        .dsCard(padding: mode == .compact ? 16 : 20)
    }

    private var logsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(eyebrow: "Log", title: "İşlem günlüğü")

            logPane(text: viewModel.logs.isEmpty ? "Henüz işlem başlatılmadı." : viewModel.logs, isPlaceholder: viewModel.logs.isEmpty, height: 150)

            if !viewModel.rawTechnicalLogs.isEmpty {
                Divider()
                    .overlay(DS.Color.line1)
                Text("Teknik log")
                    .font(DS.Font.eyebrow)
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.fg3)
                logPane(text: viewModel.rawTechnicalLogs, isPlaceholder: false, height: 120)
            }
        }
        .dsCard()
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DS.Font.eyebrow)
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(DS.Color.fg3)
            content()
        }
    }

    private func cardHeader(eyebrow: String, title: String, trailing: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(DS.Font.eyebrow)
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.fg3)
                Text(title)
                    .font(DS.Font.h3)
                    .foregroundStyle(DS.Color.fg1)
            }

            Spacer()

            if let trailing {
                DSBadge(title: trailing, variant: .accent)
            }
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(DS.Font.mono)
                .foregroundStyle(DS.Color.fg3)
            Text(value)
                .font(DS.Font.small.weight(.semibold))
                .foregroundStyle(DS.Color.fg1)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(DS.Color.bg4.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(DS.Color.line1, lineWidth: 0.5))
    }

    private func actionButton(
        _ title: String,
        subtitle: String,
        systemImage: String,
        isDanger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDanger ? DS.Color.danger : DS.Color.accent)
                    .frame(width: 30, height: 30)
                    .background((isDanger ? DS.Color.danger : DS.Color.accent).opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DS.Font.small.weight(.semibold))
                        .foregroundStyle(DS.Color.fg1)
                    Text(shortPath(subtitle))
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Color.fg3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.bg3, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line1, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func logPane(text: String, isPlaceholder: Bool, height: CGFloat) -> some View {
        ScrollView {
            Text(text)
                .font(DS.Font.mono)
                .foregroundStyle(isPlaceholder ? DS.Color.fg3 : DS.Color.fg2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(height: height)
        .padding(12)
        .background(DS.Color.bg0.opacity(0.72), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.line1, lineWidth: 0.5)
        )
    }

    private func shortPath(_ path: String) -> String {
        guard path.count > 48 else { return path }
        let suffix = path.suffix(42)
        return "..." + suffix
    }

    private var statusBadgeTitle: String {
        if viewModel.errorMessage != nil || viewModel.currentStep == .failed {
            return "Hata"
        }
        if viewModel.currentStep == .completed {
            return "Tamamlandı"
        }
        if viewModel.isProcessing {
            return "Çalışıyor"
        }
        return "Hazır"
    }

    private var statusBadgeVariant: DSBadge.Variant {
        if viewModel.errorMessage != nil || viewModel.currentStep == .failed {
            return .danger
        }
        if viewModel.currentStep == .completed {
            return .success
        }
        if viewModel.isProcessing {
            return .accent
        }
        return .neutral
    }

    private var stepDescriptionText: String {
        if viewModel.currentStep == .failed || viewModel.errorMessage != nil {
            return viewModel.errorMessage ?? viewModel.currentStepMessage
        }
        return viewModel.currentStepMessage.isEmpty ? viewModel.currentStep.description : viewModel.currentStepMessage
    }

    private var technicalDetailText: String {
        let detail = viewModel.errorDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !detail.isEmpty {
            return detail
        }

        let fallback = viewModel.rawTechnicalLogs.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty {
            return fallback
        }

        return "Bu hata için ek teknik detay üretilmedi."
    }

    private var languageOptions: [LanguageOption] {
        Array(LanguageOption.allCases)
    }

    private var modelOptions: [ModelOption] {
        Array(ModelOption.allCases)
    }
}

private extension LanguageOption {
    var optionTitle: String {
        displayName
    }

    var shortTitle: String {
        switch self {
        case .automatic:
            return "Otomatik"
        case .turkish:
            return "Türkçe"
        case .arabic:
            return "Arapça"
        }
    }

    var optionIdentifier: String {
        rawValue
    }
}

private extension ModelOption {
    var optionTitle: String {
        displayName
    }

    var optionIdentifier: String {
        rawValue
    }
}
