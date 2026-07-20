//
//  SetupView.swift
//  XRPC
//
//  Created by Lakhan Lothiyi on 12/03/2024.
//

import SwiftUI
import AXSwift

// MARK: View Model Class
class SetupVM: ObservableObject {
    // Conforms to ObservableObject
    static let shared = SetupVM() // Singleton instance

    // Published property to track if accessibility is allowed
    @Published var accessibilityAllowed: Bool = UIElement.isProcessTrusted(withPrompt: false)

    // Timer that re-checks trust so the UI updates the moment it is granted
    private var pollTimer: Timer?

    // Initialize the ViewModel
    init() {
    }

    // Function to prompt for accessibility permissions
    func accessibilityPrompt() {
        self.accessibilityAllowed = UIElement.isProcessTrusted(withPrompt: true)
        startPolling()
    }

    // Start watching for the permission being granted outside the app
    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = UIElement.isProcessTrusted(withPrompt: false)
            if trusted != self.accessibilityAllowed {
                self.accessibilityAllowed = trusted
            }
            if trusted { self.stopPolling() }
        }
    }

    // Stop watching once there is nothing left to wait for
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // Closure to be executed when setup window is closed
    var setupWindowClose: () -> Void = {}
}

// MARK: Swift UI View
struct SetupView: View {
    // Observe changes to the ViewModel
    @ObservedObject var vm = SetupVM.shared

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "accessibility.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)

                // Title for the setup screen
                Text("Xcode RPC Setup")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Text("Xcode RPC needs Accessibility access to read what youre working on in Xcode.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Show the permission row with live status
            HStack(spacing: 10) {
                Image(systemName: vm.accessibilityAllowed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(vm.accessibilityAllowed ? Color.green : Color.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Accessibility")
                        .fontWeight(.medium)
                    Text(vm.accessibilityAllowed ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                // Button to allow or indicate accessibility status
                if !vm.accessibilityAllowed {
                    Button("Allow") {
                        // Prompt for accessibility permission
                        vm.accessibilityPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 12)

            // Button to finish setup which stays blocked until access is granted
            Button("Finish") {
                // Call the setup window close action
                vm.setupWindowClose()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!vm.accessibilityAllowed)

            if !vm.accessibilityAllowed {
                Text("Waiting for permission in System Settings…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(width: 360)
        .glassBackground()
        .onAppear { vm.startPolling() }
        .onDisappear { vm.stopPolling() }
    }
}

// MARK: Liquid Glass Helpers

// Use the real glass effect where available and fall back to material
extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
