import SwiftUI

/// Battery glyph filled to the nearest 20%.
struct BatteryGauge: View {
    let percent: Int

    private let width: CGFloat = 46
    private let height: CGFloat = 22
    private let inset: CGFloat = 2.5

    /// 0 / 20 / 40 / 60 / 80 / 100
    private var bucket: Int {
        guard percent >= 0 else { return 0 }
        return min(100, max(0, Int((Double(percent) / 20).rounded()) * 20))
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
                    .frame(width: width, height: height)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green)
                    .frame(width: (width - inset * 2) * CGFloat(bucket) / 100,
                           height: height - inset * 2)
                    .padding(.leading, inset)
            }
            .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 2.5, height: 8)
        }
        .accessibilityLabel("Battery \(bucket) percent")
    }
}
