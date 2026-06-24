import SwiftUI

struct ChartTooltipRow {
    let color: Color
    let label: String
    let value: String
}

struct ChartTooltipCard: View {
    let rows: [ChartTooltipRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    Circle().fill(row.color).frame(width: 6, height: 6)
                    Text(row.label).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(row.value).monospacedDigit()
                }
            }
        }
        .font(.caption2)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
