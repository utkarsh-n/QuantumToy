import SwiftUI
import QuantumCore

struct KeyLabView: View {
    @State private var secret = 7
    @State private var testedCount = 0

    private var toy: EllipticCurveToy { EllipticCurveToy(secret: secret) }
    private var currentCandidate: ScalarCandidate? {
        guard testedCount > 0 else { return nil }
        return toy.candidates[min(testedCount, toy.candidates.count) - 1]
    }
    private var recovered: Int? {
        toy.candidates.prefix(testedCount).first(where: \.matchesPublicKey)?.scalar
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                LabHeader(eyebrow: "Elliptic curve lab", title: "A key, made visible.",
                          subtitle: "Make a public point. Recover the tiny secret behind it. See the mathematical target shared by recent quantum research.")
                curveInstrument
                InstrumentParameterStepper("SECRET", value: $secret, in: 1...18, unit: "× G",
                                           onAcceptedChange: { _ in
                    testedCount = 0
                    QuantumFeedback.selection()
                })
                keyReadouts
                searchPanel
                recentResearch
                LabNote(title: "Why this toy is easy to solve",
                        text: "This curve has just 19 group elements, including the point at infinity. Our classical search visits candidate points one by one. Real cryptographic curves have an enormous key space; Shor's algorithm approaches their discrete logarithm problem with quantum interference.",
                        equation: "Q = kG     ·     find k from G and Q")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(InstrumentDesignBackground())
        .scrollIndicators(.hidden)
        .onChange(of: secret) { _, _ in testedCount = 0 }
    }

    private var curveInstrument: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("FINITE FIELD · F₁₇")
                            .font(.system(.caption, design: .monospaced)).tracking(1.4)
                            .foregroundStyle(InstrumentPalette.secondaryInk)
                        Text("y² = x³ + 2x + 2")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(InstrumentPalette.displayInk)
                    }
                    Spacer(minLength: 8)
                    Text("mod 17")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.actionCyan)
                }
                EllipticCurvePlot(points: toy.candidates.map(\.point), generator: toy.generator,
                                  publicKey: toy.publicKey, candidate: currentCandidate?.point,
                                  onChooseScalar: { chosen in
                    guard secret != chosen else { return }
                    secret = chosen
                    testedCount = 0
                    QuantumFeedback.selection()
                })
                    .aspectRatio(1, contentMode: .fit)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { curveLegend }
                    VStack(alignment: .leading, spacing: 8) { curveLegend }
                }
                .font(.caption)
                Text("Tap a dot to choose a public point. Every dot satisfies the equation modulo 17; adding G moves between them.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var curveLegend: some View {
        Label("Generator G", systemImage: "square.fill")
            .foregroundStyle(InstrumentPalette.spectrum)
        Label("Public key Q", systemImage: "scope")
            .foregroundStyle(InstrumentPalette.actionAmber)
        Label("Candidate", systemImage: "circle.fill")
            .foregroundStyle(InstrumentPalette.actionCyan)
    }

    private var keyReadouts: some View {
        InstrumentContentPanel {
            HStack(spacing: 8) {
                InstrumentMetricReadout("GENERATOR", value: pointText(toy.generator), unit: "G",
                                        color: InstrumentPalette.spectrum)
                Divider().overlay(InstrumentPalette.secondaryInk.opacity(0.15))
                InstrumentMetricReadout("PUBLIC POINT", value: pointText(toy.publicKey), unit: "Q",
                                        color: InstrumentPalette.actionAmber)
            }
        }
    }

    private var searchPanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recover the toy key").font(.headline)
                        .foregroundStyle(InstrumentPalette.displayInk)
                    Spacer(minLength: 8)
                    Text("\(testedCount) / 18")
                        .font(.system(.caption, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
                Text(recovered.map { "Match found: \($0)G = Q. The recovered secret is \($0)." }
                     ?? currentCandidate.map { "Testing \($0.scalar)G = \(pointText($0.point)). This point does not match Q." }
                     ?? "Compare kG with the public point Q, one candidate at a time.")
                    .font(.subheadline)
                    .foregroundStyle(recovered == nil ? InstrumentPalette.secondaryInk : InstrumentPalette.actionAmber)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("keySearchStatus")
                candidateGrid
                HStack(spacing: 10) {
                    LabAction(title: "Next candidate", symbol: "forward.frame") { stepSearch() }
                        .disabled(recovered != nil || testedCount >= 18)
                    LabAction(title: "Recover toy key", symbol: "key.fill",
                              accent: InstrumentPalette.actionAmber) { recoverKey() }
                        .disabled(recovered != nil)
                }
                Button("Reset search") {
                    testedCount = 0
                    QuantumFeedback.selection()
                }
                .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                .frame(minHeight: 44)
                .instrumentControlOwnsTouches(identifier: "Reset key search")
                Text("Classical teaching model · no quantum hardware connected")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var candidateGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(toy.candidates, id: \.scalar) { candidate in
                let visited = candidate.scalar <= testedCount
                let matched = visited && candidate.matchesPublicKey
                VStack(spacing: 3) {
                    Text(candidate.scalar, format: .number)
                        .font(.system(.body, design: .monospaced)).monospacedDigit()
                    Image(systemName: matched ? "checkmark" : visited ? "xmark" : "minus")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(matched ? InstrumentPalette.actionAmber
                                 : visited ? InstrumentPalette.actionCyan : InstrumentPalette.secondaryInk.opacity(0.65))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background((matched ? InstrumentPalette.actionAmber : InstrumentPalette.actionCyan)
                    .opacity(visited ? 0.10 : 0.025), in: .rect(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke((matched ? InstrumentPalette.actionAmber : InstrumentPalette.actionCyan)
                            .opacity(visited ? 0.4 : 0.09), lineWidth: 1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Candidate \(candidate.scalar)")
                .accessibilityValue(matched ? "Matches public key" : visited ? "Does not match" : "Untested")
            }
        }
    }

    private var recentResearch: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 11) {
                Label("FROM THE LAB · 21 SEP 2026", systemImage: "sparkle.magnifyingglass")
                    .font(.system(.caption, design: .monospaced)).tracking(0.5)
                    .foregroundStyle(InstrumentPalette.spectrum)
                Text("A 16-bit ECC experiment").font(.headline)
                    .foregroundStyle(InstrumentPalette.displayInk)
                Text("Researchers reported solving a 16-bit elliptic-curve discrete logarithm on D-Wave Advantage2, using quantum annealing with classical index calculus. It was a small research instance, far below production 256-bit curves.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Our F₁₇ toy shows the underlying key relationship with classical enumeration. It does not reproduce the annealing experiment or Shor's circuit.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://www.sciopen.com/article/10.23919/ICN.2026.0017")!) {
                    Label("Read the original paper", systemImage: "arrow.up.right")
                        .font(.subheadline).foregroundStyle(InstrumentPalette.actionCyan)
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pointText(_ point: CurvePoint) -> String {
        guard let x = point.x, let y = point.y else { return "∞" }
        return "(\(x),\(y))"
    }

    private func stepSearch() {
        guard recovered == nil, testedCount < toy.candidates.count else { return }
        testedCount += 1
        if recovered != nil { QuantumFeedback.event() } else { QuantumFeedback.selection() }
    }

    private func recoverKey() {
        guard let candidate = toy.candidates.first(where: \.matchesPublicKey) else { return }
        testedCount = candidate.scalar
        QuantumFeedback.event()
    }
}

private struct EllipticCurvePlot: View {
    let points: [CurvePoint]
    let generator: CurvePoint
    let publicKey: CurvePoint
    let candidate: CurvePoint?
    let onChooseScalar: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
        Canvas { context, size in
            let left: CGFloat = 27
            let bottom: CGFloat = 25
            let inset: CGFloat = 14
            let width = max(1, size.width - left - inset)
            let height = max(1, size.height - bottom - inset)
            func location(_ x: Int, _ y: Int) -> CGPoint {
                CGPoint(x: left + width * CGFloat(x) / 16,
                        y: inset + height * CGFloat(16 - y) / 16)
            }
            var grid = Path()
            for coordinate in 0...16 {
                let a = location(coordinate, 0)
                let b = location(coordinate, 16)
                grid.move(to: a); grid.addLine(to: b)
                let c = location(0, coordinate)
                let d = location(16, coordinate)
                grid.move(to: c); grid.addLine(to: d)
            }
            context.stroke(grid, with: .color(.white.opacity(0.075)), lineWidth: 0.5)
            for value in [0, 4, 8, 12, 16] {
                let ink = Text("\(value)").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                context.draw(ink, at: CGPoint(x: location(value, 0).x, y: size.height - 10))
                context.draw(ink, at: CGPoint(x: 11, y: location(0, value).y))
            }
            for point in points {
                guard let x = point.x, let y = point.y else { continue }
                let p = location(x, y)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)),
                             with: .color(InstrumentPalette.secondaryInk.opacity(0.65)))
            }
            if let x = generator.x, let y = generator.y {
                let p = location(x, y)
                context.fill(Path(roundedRect: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8), cornerRadius: 1),
                             with: .color(InstrumentPalette.spectrum))
            }
            if let candidate, let x = candidate.x, let y = candidate.y {
                let p = location(x, y)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
                             with: .color(InstrumentPalette.actionCyan.opacity(0.22)))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                             with: .color(InstrumentPalette.actionCyan))
            }
            if let x = publicKey.x, let y = publicKey.y {
                let p = location(x, y)
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)),
                               with: .color(InstrumentPalette.actionAmber), lineWidth: 1.5)
                var target = Path()
                target.move(to: CGPoint(x: p.x - 12, y: p.y)); target.addLine(to: CGPoint(x: p.x - 6, y: p.y))
                target.move(to: CGPoint(x: p.x + 6, y: p.y)); target.addLine(to: CGPoint(x: p.x + 12, y: p.y))
                target.move(to: CGPoint(x: p.x, y: p.y - 12)); target.addLine(to: CGPoint(x: p.x, y: p.y - 6))
                target.move(to: CGPoint(x: p.x, y: p.y + 6)); target.addLine(to: CGPoint(x: p.x, y: p.y + 12))
                context.stroke(target, with: .color(InstrumentPalette.actionAmber), lineWidth: 1)
            }
        }
        .contentShape(.rect)
        .onTapGesture { location in
            let width = max(1, geometry.size.width - 41)
            let height = max(1, geometry.size.height - 39)
            let nearest = points.enumerated().compactMap { index, point -> (scalar: Int, distance: CGFloat)? in
                guard let x = point.x, let y = point.y else { return nil }
                let p = CGPoint(x: 27 + width * CGFloat(x) / 16,
                                y: 14 + height * CGFloat(16 - y) / 16)
                return (index + 1, hypot(location.x - p.x, location.y - p.y))
            }.min { $0.distance < $1.distance }
            if let nearest, nearest.distance < 22 { onChooseScalar(nearest.scalar) }
        }
        }
        .padding(8)
        .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Discrete elliptic curve over the field of 17 elements")
        .accessibilityValue("18 finite points. Generator at \(generator.x ?? 0), \(generator.y ?? 0). Public key at \(publicKey.x ?? 0), \(publicKey.y ?? 0).")
        .accessibilityHint("Use the secret stepper below to choose a public point.")
    }
}
