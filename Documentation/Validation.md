# Quantum Toy validation — October 12, 2026

## Completed

- Native iPhone-only SwiftUI app, minimum iOS 26. Bundle ID `com.utkarsh.quantumtoy`.
- Final simulator target compiled successfully in Xcode 27 on the iPhone 17 Pro / iOS 27 destination. Saved log: `QA/SimulatorBuild.log`.
- Final arm64 iPhone target compiled successfully with signing disabled. Saved log: `QA/DeviceBuild.log`. App Intents metadata extraction emits the usual no-framework warning; the app does not define App Intents.
- The source staged under `/private/tmp/QuantumToyBuild` matches 26 application, core, test and project files byte for byte. See `SourceParity.json`. The workspace source is authoritative.
- App installed and launched on the iPhone 17 Pro simulator; initial runtime view captured. The final app is left at the Shor workbench.
- All 14 platform-neutral core tests passed, exit 0. Exact command: `CLANG_MODULE_CACHE_PATH=/tmp/quantum-toy-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/quantum-toy-swift-cache swift test --disable-sandbox --scratch-path /tmp/quantum-toy-core-build --cache-path /tmp/quantum-toy-spm-cache`. SwiftPM's nested sandbox was disabled inside the existing tool sandbox to avoid `sandbox_apply` failure.
- Tests cover Grover's closed-form curve, oracle phase behavior, normalization, overshoot and weighted shots; the Shor FFT against independent joint-amplitude calculation; phase-derived factors and all miniature RSA plaintexts; invalid inputs; elliptic-curve group operations and every secret; SI-constant thermal values; T2 bounds and pure dephasing independent of T1; physical Bloch evolution under modulation.
- Independent review compared Bloch integration with a separate Python RK4 ODE. Maximum component errors were approximately 3×10⁻⁶ in tested demanding display-scale intervals. Large intervals hit the documented subdivision cap and are not quantitative long-time integration. The UI uses increments at most 0.08 μs.
- Exhaustive phase postprocessing returned no invalid factor products. Born-weighted recovery probabilities were approximately 75% for N=15, 62.29% for N=21 and 70.60% for N=35, supporting genuine retry behavior. Review output: `QA/IndependentMathReview.txt`.
- All four workbenches rendered and their initial layouts were visually inspected. Screenshots are `QA/Shor.jpg`, `QA/Grover.jpg`, `QA/Keys.jpg`, and `QA/QubitLab.jpg`. The latter three were opened with Debug-only launch routing to inspect each view independently; this verifies rendering, not tab interaction.

## Verification limits

The simulator UI test target compiled, but its tests did not execute. Xcode repeatedly failed to connect to `com.apple.instruments.deviceservice.lockdown` with `DTServiceHubClient failed to bless service hub`. The stalled, task-owned xcodebuild test process was stopped after about four minutes. The log is saved as `QA/SimulatorUITest.log`; no UI test pass is claimed.

Runtime snapshots and screenshots worked, and a page scroll worked. Injected taps on native buttons and tab-bar items left the UI unchanged. An independent source review found no tab interception path in the scroll-control touch bridge. The Mac was confirmed unlocked; the Device Hub computer-use inspection also timed out. Native interaction, held controls during live evolution, large Dynamic Type, accessibility settings, long runs, and perceived haptics still need hands-on verification after the Apple simulator infrastructure responds normally.

Following the user's request, a signed Release build was installed on the physical iPhone 15 Pro Max. Version 1.0, build 1 was confirmed in the installed-app inventory. The initial CoreDevice launch returned success but its process exited. The user then launched the app from its icon and confirmed: “It stays open.” A subsequent device process inventory confirmed QuantumToy running as PID 9513. Signature validation passed and the provisioning profile includes the phone. Evidence is in `QA/SignedDeviceBuild.log`, `QA/PhoneInstall.json`, `QA/PhoneLaunch.json`, `QA/PhoneInstalledApp.json`, `QA/PhoneProcess.json`, and `QA/DeviceDeliveryReceipt.json`.

Detailed feature interactions and perceived haptics await user hands-on use. All quantum computation, qubit temperature and telemetry remain local classical educational models, with limits and primary sources available in the in-app Field Guide and `Research.md`.
