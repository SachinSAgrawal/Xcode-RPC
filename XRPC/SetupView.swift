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
    
    // Initialize the ViewModel
    init() {
    }
    
    // Function to prompt for accessibility permissions
    func accessibilityPrompt() {
        self.accessibilityAllowed = UIElement.isProcessTrusted(withPrompt: true)
    }
    
    // Closure to be executed when setup window is closed
    var setupWindowClose: () -> Void = {}
}

// MARK: Swift UI View
struct SetupView: View {
    // Observe changes to the ViewModel
    @ObservedObject var vm = SetupVM.shared
    
    var body: some View {
        VStack {
            VStack {
                // Title for the setup screen
                Text("Xcode RPC Setup")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                
                HStack {
                    // Label for Accessibility section
                    Text("Accessibility")
                    Spacer()
                    
                    // Button to allow or indicate accessibility status
                    if !vm.accessibilityAllowed {
                        Button {
                            // Prompt for accessibility permission
                            vm.accessibilityPrompt()
                        } label: {
                            Text("Allow")
                        }
                    } else {
                        Button {
                            // Do nothing if accessibility is already allowed
                        } label: {
                            Text("Allowed")
                        }
                    }
                }
                
                // Button to finish setup
                Button("Finish") {
                    // Call the setup window close action
                    vm.setupWindowClose()
                }
                .padding(.top)
            }
            .padding(16)
        }
        .frame(width: 250, height: 150) /// Set frame size for the setup view
        .background(.regularMaterial)   /// Apply regular material background
    }
}
