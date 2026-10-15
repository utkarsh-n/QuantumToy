import SwiftUI
import UIKit

struct LabHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(InstrumentPalette.actionCyan)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(InstrumentPalette.displayInk)
            Text(subtitle).font(.subheadline)
                .foregroundStyle(InstrumentPalette.secondaryInk).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LabNote: View {
    let title: String
    let text: String
    var equation: String? = nil
    var body: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                if let equation {
                    Text(equation).font(.system(.callout, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.actionCyan)
                        .textSelection(.enabled)
                }
                Text(text).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LabAction: View {
    let title: String
    let symbol: String
    var accent: Color = InstrumentPalette.actionCyan
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(accent)
        }
        .buttonStyle(.glass)
        .instrumentControlOwnsTouches(identifier: title)
    }
}

struct ProbabilityBars: View {
    let values: [Double]
    var highlighted: Int? = nil
    var labels: [String] = []
    var color: Color = InstrumentPalette.actionCyan
    var body: some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let maxValue = max(values.max() ?? 1, 0.001)
                let w = size.width / CGFloat(max(1, values.count))
                var guides = Path()
                for i in 0...4 {
                    let y = size.height * CGFloat(i) / 4
                    guides.move(to: CGPoint(x: 0, y: y))
                    guides.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(guides, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
                for (index, value) in values.enumerated() {
                    let h = max(1, CGFloat(max(0, value) / maxValue) * (size.height - 4))
                    let rect = CGRect(x: CGFloat(index) * w + 1, y: size.height - h,
                                      width: max(1, w - 2), height: h)
                    let accent = index == highlighted ? InstrumentPalette.actionAmber : color
                    context.fill(Path(roundedRect: rect, cornerRadius: min(w * 0.2, 3)),
                                 with: .color(accent.opacity(index == highlighted ? 1 : 0.7)))
                }
            }.frame(height: 145)
            HStack {
                Text(labels.first ?? "|0⟩")
                Spacer()
                Text("P MAX \(Int((values.max() ?? 0) * 100))%")
                Spacer()
                Text(labels.last ?? "|\(max(0, values.count - 1))⟩")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Measurement probabilities")
        .accessibilityValue(highlighted.map { "State \($0), \(Int((values.indices.contains($0) ? values[$0] : 0) * 100)) percent" } ?? "Maximum \(Int((values.max() ?? 0) * 100)) percent")
    }
}

@MainActor enum QuantumFeedback {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func event(success: Bool = true) {
        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .warning)
    }
}

struct QuantumSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatted: String
    var accent: Color = InstrumentPalette.actionCyan
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                Spacer()
                Text(formatted).font(.system(.body, design: .rounded, weight: .medium))
                    .monospacedDigit().foregroundStyle(accent)
            }
            Slider(value: $value, in: range, step: step, onEditingChanged: { editing in
                if !editing { QuantumFeedback.selection() }
            }).tint(accent)
                .accessibilityLabel(title).accessibilityValue(formatted)
                .instrumentControlOwnsTouches(identifier: title)
        }
    }
}
