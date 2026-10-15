import SwiftUI

@main
struct QuantumToyApp: App {
    var body: some Scene {
        WindowGroup {
            QuantumRootView()
                .preferredColorScheme(.dark)
                .tint(InstrumentPalette.actionCyan)
        }
    }
}

struct QuantumRootView: View {
    @State private var tab = initialLab
    @State private var showGuide = false
    var body: some View {
        TabView(selection: $tab) {
            Tab("Shor", systemImage: "waveform.path", value: 0) {
                shell { ShorLabView() }
            }
            Tab("Grover", systemImage: "square.grid.3x3", value: 1) {
                shell { GroverLabView() }
            }
            Tab("Keys", systemImage: "key.horizontal", value: 2) {
                shell { KeyLabView() }
            }
            Tab("Qubit Lab", systemImage: "atom", value: 3) {
                shell { QubitLabView(isSelected: tab == 3) }
            }
        }
        .sheet(isPresented: $showGuide) { QuantumGuideView() }
    }

    private func shell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ZStack {
                InstrumentDesignBackground()
                content()
            }
            .navigationTitle("Quantum Toy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Model guide", systemImage: "info.circle") { showGuide = true }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("modelGuide")
                }
            }
            .toolbarBackground(InstrumentPalette.canvas, for: .navigationBar)
        }
    }
}

// Direct launch routing lets visual QA inspect each workbench independently
// when the simulator's input service is unavailable. It is disabled in Release.
private var initialLab: Int {
    #if DEBUG
    if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--lab=") }),
       let value = Int(argument.dropFirst(6)), (0...3).contains(value) { return value }
    #endif
    return 0
}
