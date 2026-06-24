import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            colors: [
                Color.primary.opacity(0.08),
                Color.primary.opacity(0.18),
                Color.primary.opacity(0.08),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: phase * 200)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

struct ShimmerPlaceholder: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.primary.opacity(0.06))
            .frame(height: height)
            .overlay {
                ShimmerView()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
    }
}
