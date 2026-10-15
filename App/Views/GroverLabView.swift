import SwiftUI
import QuantumCore

struct GroverLabView: View {
    @State private var qubitCount = 3
    @State private var target = 5
    @State private var experiment = GroverExperiment(qubitCount: 3, target: 5)
    @State private var page = 0
    @State private var measured: Int?
    @State private var sampleCount = 0
    @State private var hitCount = 0

    private var stateCount: Int { 1 << qubitCount }
    private var targetProbability: Double { experiment.probabilities[target] }
    private var pageCount: Int { max(1, stateCount / 16) }
    private var visibleStates: Range<Int> { (page * 16)..<min(stateCount, page * 16 + 16) }
    private var oracleReady: Bool { experiment.stage != .oracleApplied }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(eyebrow: "02 / Amplitude amplification", title: "Grover's search",
                          subtitle: "Mark one answer with a phase flip. Reflect the amplitudes until it stands out.")
                configuration
                amplitudeRegister
                operationControls
                iterationCurve
                measurementPanel
                LabNote(title: "A sign change makes the difference",
                        text: "The oracle recognizes the selected answer and flips its amplitude. Probabilities stay unchanged. Diffusion reflects every amplitude about their mean, turning that phase difference into a larger chance of finding the answer.",
                        equation: "Oracle: aₜ → −aₜ\nDiffusion: aᵢ → 2ā − aᵢ")
                DisclosureGroup("What this simulation assumes") {
                    Text("An ideal pure-state register with one marked answer and no hardware noise. The oracle is supplied by the problem; this toy lets you choose its target. Measurement samples independent fresh runs of the displayed state, so you can compare observed hits with its probability.")
                        .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                }
                .font(.subheadline).foregroundStyle(InstrumentPalette.displayInk)
                .tint(InstrumentPalette.actionCyan)
            }
            .padding(20)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    private var configuration: some View {
        VStack(spacing: 10) {
            InstrumentParameterStepper("QUBITS", value: $qubitCount, in: 2...6, unit: "",
                                       onAcceptedChange: { _ in
                target = min(target, stateCount - 1)
                resetExperiment()
                QuantumFeedback.selection()
            })
            .accessibilityIdentifier("groverQubitsStepper")
            InstrumentParameterStepper("TARGET", value: $target, in: 0...(stateCount - 1), unit: "",
                                       onAcceptedChange: { _ in
                resetExperiment()
                QuantumFeedback.selection()
            })
            .accessibilityIdentifier("groverTargetStepper")
        }
    }

    private var amplitudeRegister: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\((targetProbability * 100).formatted(.number.precision(.fractionLength(1))))")
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .monospacedDigit().foregroundStyle(InstrumentPalette.displayInk)
                    Text("TARGET |\(binary(target))⟩")
                        .font(.system(.caption, design: .monospaced)).tracking(1)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
                Text("%")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.actionCyan)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(experiment.iteration)")
                        .font(.system(.title, design: .rounded, weight: .medium)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.actionAmber)
                    Text("ROUNDS")
                        .font(.system(.caption2, design: .monospaced)).tracking(1)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Target probability")
            .accessibilityValue("\((targetProbability * 100).formatted(.number.precision(.fractionLength(1)))) percent after \(experiment.iteration) rounds")
            .accessibilityIdentifier("groverProbability")

            HStack {
                Text("SIGNED AMPLITUDES")
                    .font(.system(.caption2, design: .monospaced)).tracking(1)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                Spacer()
                Text("+ cyan").foregroundStyle(InstrumentPalette.actionCyan)
                Text("− violet").foregroundStyle(InstrumentPalette.spectrum)
            }.font(.system(.caption2, design: .monospaced))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                ForEach(Array(visibleStates), id: \.self) { index in
                    amplitudeCell(index)
                }
            }
            if pageCount > 1 {
                Picker("Register page", selection: $page) {
                    ForEach(0..<pageCount, id: \.self) { value in
                        Text("\(value * 16)–\(min(stateCount - 1, value * 16 + 15))").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Shows another group of basis states. All states remain in the quantum register.")
            }
            HStack(spacing: 5) {
                Image(systemName: "hand.tap")
                Text("Tap a state to mark a new target.")
            }
            .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(red: 0.065, green: 0.085, blue: 0.10),
                                            Color(red: 0.022, green: 0.034, blue: 0.044)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0.03),
                                                .black, .white.opacity(0.13)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.55), radius: 16, y: 10)
    }

    private func amplitudeCell(_ index: Int) -> some View {
        let amplitude = experiment.amplitudes[index]
        let isTarget = index == target
        let color = amplitude < 0 ? InstrumentPalette.spectrum : InstrumentPalette.actionCyan
        return Button {
            guard index != target else { return }
            target = index
            resetExperiment()
            QuantumFeedback.selection()
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 1) {
                    Text("|\(binary(index))⟩")
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if isTarget { Image(systemName: "scope").font(.system(size: 9)) }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isTarget ? InstrumentPalette.actionAmber : InstrumentPalette.secondaryInk)
                Text(amplitude.formatted(.number.sign(strategy: .always()).precision(.fractionLength(3))))
                    .font(.system(.caption2, design: .monospaced))
                    .monospacedDigit().foregroundStyle(color)
                    .lineLimit(1).minimumScaleFactor(0.7)
                GeometryReader { geometry in
                    let half = geometry.size.width / 2
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.04))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.85))
                            .frame(width: max(1, half * abs(amplitude)))
                            .offset(x: amplitude < 0 ? half * (1 - abs(amplitude)) : half)
                        Rectangle().fill(.white.opacity(0.25))
                            .frame(width: 1).offset(x: half)
                    }
                }.frame(height: 4).accessibilityHidden(true)
            }
            .padding(.horizontal, 7).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(Color.black.opacity(isTarget ? 0.5 : 0.24), in: .rect(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isTarget ? InstrumentPalette.actionAmber.opacity(0.7) : .white.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Basis state \(index)\(isTarget ? ", marked target" : "")")
        .accessibilityValue("Amplitude \(amplitude.formatted(.number.precision(.fractionLength(3)))), probability \((experiment.probabilities[index] * 100).formatted(.number.precision(.fractionLength(1)))) percent")
        .accessibilityHint("Selects this state as the oracle target and resets the experiment.")
    }

    private var operationControls: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(oracleReady ? InstrumentPalette.actionCyan : InstrumentPalette.spectrum)
                    .frame(width: 6, height: 6).padding(.top, 6)
                Text(oracleReady ? "Ready to flip the target's sign." : "Oracle applied. The target's sign has flipped; its probability has not changed yet.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("groverStatus")
                Spacer(minLength: 0)
            }
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    LabAction(title: "Oracle", symbol: "plus.forwardslash.minus",
                              accent: InstrumentPalette.spectrum) {
                        guard oracleReady else { return }
                        experiment.oracle()
                        clearMeasurements()
                        QuantumFeedback.selection()
                    }.disabled(!oracleReady)
                        .accessibilityIdentifier("groverOracle")
                    LabAction(title: "Diffuse", symbol: "arrow.up.and.down") {
                        guard !oracleReady else { return }
                        experiment.diffuse()
                        clearMeasurements()
                        QuantumFeedback.selection()
                    }.disabled(oracleReady)
                        .accessibilityIdentifier("groverDiffuse")
                }
            }
            HStack(spacing: 10) {
                LabAction(title: oracleReady ? "Full round" : "Finish round", symbol: "forward.end.fill",
                          accent: InstrumentPalette.actionAmber) {
                    experiment.step()
                    clearMeasurements()
                    QuantumFeedback.selection()
                }
                .accessibilityIdentifier("groverIterate")
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    resetExperiment()
                    QuantumFeedback.selection()
                }
                .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                .frame(minWidth: 74, minHeight: 44)
                .accessibilityLabel("Reset Grover register to equal amplitudes")
                .accessibilityIdentifier("groverReset")
            }
        }
    }

    private var iterationCurve: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("THE FIRST PEAK")
                        .font(.system(.caption, design: .monospaced)).tracking(1)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    Spacer()
                    Text("\(experiment.optimalIteration) rounds")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(InstrumentPalette.actionAmber)
                }
                GroverProbabilityCurve(stateCount: stateCount, iteration: experiment.iteration,
                                       optimal: experiment.optimalIteration)
                HStack {
                    InstrumentMetricReadout("INITIAL", value: (100 / Double(stateCount)).formatted(.number.precision(.fractionLength(1))), unit: "%")
                    InstrumentMetricReadout("CURRENT", value: (targetProbability * 100).formatted(.number.precision(.fractionLength(1))), unit: "%",
                                            color: InstrumentPalette.actionAmber)
                    InstrumentMetricReadout("STATES", value: "\(stateCount)", unit: "")
                }
                Text(experiment.iteration > experiment.optimalIteration
                     ? "Past the first peak: more rounds can rotate amplitude away from the answer. Keep stepping to see it return."
                     : "Stop near the first peak. Repeating the circuit forever does not keep improving the answer.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("P(k) = sin²((2k + 1)θ)\nθ = asin(1 / √\(stateCount))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.actionCyan)
            }
        }
    }

    private var measurementPanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("MEASUREMENT").font(.system(.caption, design: .monospaced)).tracking(1)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    Spacer()
                    if let measured {
                        Label("|\(binary(measured))⟩", systemImage: measured == target ? "checkmark.circle.fill" : "circle")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(measured == target ? InstrumentPalette.actionCyan : InstrumentPalette.actionAmber)
                    }
                }
                LabAction(title: "Measure a fresh run", symbol: "scope") {
                    measured = experiment.measure(unitSample: Double.random(in: 0..<1))
                    sampleCount += 1
                    if measured == target { hitCount += 1 }
                    QuantumFeedback.event(success: measured == target)
                }
                .accessibilityIdentifier("groverMeasure")
                if sampleCount > 0 {
                    Text("\(hitCount) target hits / \(sampleCount) fresh runs")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.displayInk)
                        .accessibilityLabel("\(hitCount) target hits in \(sampleCount) measurements")
                        .accessibilityIdentifier("groverMeasurementCount")
                }
                Text("One readout is random. Repeated fresh runs approach the displayed target probability.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func binary(_ value: Int) -> String {
        let digits = String(value, radix: 2)
        return String(repeating: "0", count: max(0, qubitCount - digits.count)) + digits
    }

    private func resetExperiment() {
        experiment = GroverExperiment(qubitCount: qubitCount, target: target)
        page = target / 16
        clearMeasurements()
    }

    private func clearMeasurements() {
        measured = nil
        sampleCount = 0
        hitCount = 0
    }
}

private struct GroverProbabilityCurve: View {
    let stateCount: Int
    let iteration: Int
    let optimal: Int

    private var lastRound: Int { max(optimal * 2 + 2, iteration + 2) }

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let inset: CGFloat = 6
                let width = size.width - inset * 2
                let height = size.height - inset * 2
                let theta = asin(1 / sqrt(Double(stateCount)))
                var guides = Path()
                for fraction in [0.0, 0.5, 1.0] {
                    let y = inset + height * (1 - fraction)
                    guides.move(to: CGPoint(x: inset, y: y))
                    guides.addLine(to: CGPoint(x: size.width - inset, y: y))
                }
                context.stroke(guides, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                var curve = Path()
                let samples = max(100, lastRound * 12)
                for index in 0...samples {
                    let k = Double(index) / Double(samples) * Double(lastRound)
                    let probability = pow(sin((2 * k + 1) * theta), 2)
                    let point = CGPoint(x: inset + width * k / Double(lastRound),
                                        y: inset + height * (1 - probability))
                    if index == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
                }
                context.stroke(curve, with: .color(InstrumentPalette.actionCyan.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                for k in 0...lastRound {
                    let probability = pow(sin(Double(2 * k + 1) * theta), 2)
                    let point = CGPoint(x: inset + width * Double(k) / Double(lastRound),
                                        y: inset + height * (1 - probability))
                    let radius: CGFloat = k == iteration ? 4.5 : 2.5
                    let color = k == iteration ? InstrumentPalette.actionAmber : InstrumentPalette.actionCyan
                    context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                                        width: radius * 2, height: radius * 2)), with: .color(color))
                }
                let x = inset + width * Double(optimal) / Double(lastRound)
                var peak = Path()
                peak.move(to: CGPoint(x: x, y: inset))
                peak.addLine(to: CGPoint(x: x, y: size.height - inset))
                context.stroke(peak, with: .color(InstrumentPalette.actionAmber.opacity(0.3)),
                               style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            .frame(height: 115)
            HStack {
                Text("0 rounds")
                Spacer()
                Text("\(lastRound) rounds")
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(InstrumentPalette.secondaryInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Target probability by completed rounds")
        .accessibilityValue("The first optimal round is \(optimal). The current round is \(iteration). Probability oscillates as rounds increase.")
    }
}
