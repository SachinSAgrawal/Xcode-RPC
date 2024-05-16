//
//  AXScrape.swift
//  XRPC
//
//  Created by Lakhan Lothiyi on 13/03/2024.
//

import Foundation
import AXSwift
import Cocoa
import SwordRPC

let xcodeBundleId = "com.apple.dt.Xcode"

// MARK: AXScrape
class AXScrape: ObservableObject {
    // Timer for periodic scraping
    var timer: Timer?
    
    init() {
        // Schedule a timer to scrape Xcode state every 2 seconds
        self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { _ in
            self.scrape()
        })
    }
    
    // Published property to track presence state
    @Published var presenceState: PresenceState = .xcodeNoWindowsOpen
    
    // Function to scrape Xcode state
    func scrape() {
        // Check if AXSwift is working
        guard UIElement.isProcessTrusted(withPrompt: false) else { return }
        
        // Find the running Xcode process
        let xcodeProcess = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == xcodeBundleId }
        
        // Get the Xcode application
        guard let xcodeApp = Application.allForBundleID(xcodeBundleId).first else { self.presenceState = .xcodeNotRunning; return }
        
        // Get all windows of Xcode
        let windows = try? xcodeApp.windows()
        
        // Get the main window and focused window of Xcode
        let mainWindow: UIElement? = try? xcodeApp.attribute(.mainWindow)
        let focusedWindow: UIElement? = try? xcodeApp.attribute(.focusedWindow)
        let focusedWindowTitle: String? = try? focusedWindow?.attribute(.title)
        
        // If no main window and no windows are open, set presence state to no windows open
        if mainWindow == nil && (windows?.isEmpty ?? false) {
            self.presenceState = .xcodeNoWindowsOpen
        }
        
        // If the focused window title contains "Welcome", set presence state to on welcome screen
        if focusedWindowTitle?.contains("Welcome") ?? false {
            self.presenceState = .isOnWelcome
            return
        }
        
        // Get workspace name, file editing status, document file path, and current session date
        let windowTitle: String? = try? mainWindow?.attribute(.title)
        let workspace: String? = windowTitle == nil ? nil : windowTitle!.components(separatedBy: " — ").first
        let isEditing: Bool = windowTitle?.contains("— Edited") ?? false
        let docFilePath: String? = try? mainWindow?.attribute(.document)
        let doc: URL? = docFilePath == nil ? nil : URL(fileURLWithPath: docFilePath!.replacingOccurrences(of: "file://", with: ""))
        
        let currentSessionDate: Date? = {
            switch presenceState {
            case .working(let xcodeState):
                return xcodeState.sessionDate
            default: return nil
            }
        }()
        
        // Create Xcode state object
        let xcState = XcodeState(
            workspace: workspace,
            editorFile: doc,
            isEditingFile: isEditing,
            // Preserve Xcode last date or make new date
            sessionDate: currentSessionDate ?? xcodeProcess?.launchDate ?? .now /// Used for timings
        )
        
        // Set presence state to working with Xcode state
        self.presenceState = .working(xcState)
    }
}

// MARK: Presence State
enum PresenceState {
    // Enumeration to represent different presence states
    case xcodeNotRunning
    case xcodeNoWindowsOpen  /// When Xcode has no windows and is doing nothing
    case working(XcodeState) /// When user is working
    case isOnWelcome
}

// MARK: Xcode Struct
struct XcodeState: Equatable {
    var workspace: String?  /// Workspace name
    var editorFile: URL?    /// URL of the editing file
    var isEditingFile: Bool /// Flag indicating if a file is being edited
    
    // Date of the current session
    var sessionDate: Date?
    
    // Boolean indicating if Xcode is idle and no file is open
    var isIdle: Bool {
        // Sitting in .xcodeproj or .xcworkspace
        editorFile?.lastPathComponent.contains("xcodeproj") ?? true || editorFile?.lastPathComponent.contains("xcworkspace") ?? true
    }
    
    // File name being edited
    var fileName: String? {
        if isIdle { return nil }
        return editorFile?.lastPathComponent.removingPercentEncoding
    }
    
    // File extension of the editing file
    var fileExtension: String? {
        if let fileName {
            let fx = fileName.split(separator: ".").last
            if let fx {
                return String(fx).lowercased()
            }
        }
        return nil
    }
}

// MARK: Extension
fileprivate extension String {
    // Extension to count occurrences of a string within another string
    func numberOfOccurrencesOf(string: String) -> Int {
        self.components(separatedBy: string).count - 1
    }
}
