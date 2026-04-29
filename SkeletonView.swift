import SwiftUI

struct SkeletonView: View {
    let isProcessing: Bool
    let lineCount: Int

    @State private var animatedOpacity: Double = 0.38

    init(isProcessing: Bool, lineCount: Int = 10) {
        self.isProcessing = isProcessing
        self.lineCount = min(max(lineCount, 8), 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<lineCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.Color.bg4.opacity(opacity(for: index)),
                                DS.Color.accent.opacity(opacity(for: index) * 0.32),
                                DS.Color.bg4.opacity(opacity(for: index))
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width(for: index), height: 12)
            }
        }
        .opacity(animatedOpacity)
        .animation(isProcessing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: animatedOpacity)
        .onAppear {
            animatedOpacity = isProcessing ? 0.88 : 0.72
        }
        .onChange(of: isProcessing) {
            animatedOpacity = isProcessing ? 0.88 : 0.72
        }
    }

    private func opacity(for index: Int) -> Double {
        let values: [Double] = [0.16, 0.22, 0.18, 0.24, 0.19, 0.21, 0.17, 0.23, 0.18, 0.2, 0.16, 0.22]
        return values[index % values.count]
    }

    private func width(for index: Int) -> CGFloat {
        let widths: [CGFloat] = [540, 470, 585, 430, 560, 390, 515, 350, 500, 445, 575, 410]
        return widths[index % widths.count]
    }
}
