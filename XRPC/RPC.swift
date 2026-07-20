//
//  RPC.swift
//  XRPC
//
//  Created by Lakhan Lothiyi on 12/03/2024.
//

import Cocoa
import Foundation
import AXSwift
import SwordRPC
import Combine

// Identifies the Discord app this reports as which you can create at https://discord.com/developers/applications
fileprivate let RPC_CLIENT_ID = "1431664417472385219"

// MARK: Presence Art

// Serve art from this repo since Discord proxies external image URLs and sidesteps the 300 asset cap
fileprivate let iconBaseURL = "https://cdn.jsdelivr.net/gh/SachinSAgrawal/Xcode-RPC@main/Icons"

// Show this while sitting in a project rather than a file
fileprivate let xcodeIconURL = "\(iconBaseURL)/_xcode.png"

// Resolve a file extension to the image Discord should display or the generic document icon
fileprivate func resolveIconURL(_ ext: String?) -> String {
    guard let ext = ext?.lowercased(), !ext.isEmpty else { return xcodeIconURL }
    return "\(iconBaseURL)/\(fileIconNames[ext] ?? "_default").png"
}

// MARK: Presence Preview

// Snapshot what was last handed to Discord so the menu bar can show the same card
struct PresencePreview: Equatable {
    var details: String?    /// Top line, usually the workspace
    var state: String?      /// Second line, usually the file
    var imageURL: String?   /// Art Discord is displaying
    var imageText: String?  /// Tooltip Discord shows over the art
    var start: Date?        /// Elapsed timer start, nil when there is no timer
    var isActive: Bool      /// False when nothing is being reported at all
}

// MARK: RPC Class
class RPC: ObservableObject, SwordRPCDelegate {
    // Expose the file scope resolver so setPresence can reach it
    static func iconURL(for ext: String?) -> String { resolveIconURL(ext) }

    static let shared = RPC() // Singleton instance
    
    // Variable to track if the app is paused
    @Published var isPaused = false
    
    // SwordRPC instance
    var rpc = SwordRPC(appId: RPC_CLIENT_ID)
    
    // AXScrape instance for accessibility
    let scraper = AXScrape.init()
    
    // Set to hold cancellables
    var c = Set<AnyCancellable>()

    init() {
        // Sink the published value since objectWillChange fires before the state is updated
        scraper.$presenceState
            .dropFirst()
            .sink { [weak self] state in
                self?.setPresence(state)
            }.store(in: &c)
    }
    
    // Publish a snapshot of the presence currently being reported to Discord
    @Published var preview = PresencePreview(isActive: false)

    // Method to toggle pause/resume state
    func togglePauseResume() {
        isPaused.toggle()
        // Apply it now rather than waiting out the rest of the scrape interval
        setPresence(scraper.presenceState)
    }

    // Re-read Xcode which pushes the new state through the publisher
    func forceRefresh() {
        scraper.scrape()
    }
    
    // Function to perform initial check and connect RPC
    func initialCheck() {
        // Check if AXSwift is working
        let axWorking = UIElement.isProcessTrusted(withPrompt: false)
        // Show setup window if AXSwift is not working
        if axWorking == false {
            (NSApplication.shared.delegate as! AppDelegate).showSetupWindow()
        }
        // Connect to Discord RPC
        rpcConnect()
    }
    
    // Published property to track RPC connection status
    @Published var rpcConnected: Bool = false
    
    // Function to connect to Discord RPC
    func rpcConnect() {
        // If already connected, return
        guard rpcConnected == false else { return }
        self.rpc = SwordRPC(appId: RPC_CLIENT_ID)
        self.rpc.delegate = self
        self.rpcConnected = self.rpc.connect()
    }
    
    // Function to disconnect from Discord RPC
    func rpcDisconnect() {
        self.rpc.disconnect()
        self.rpcConnected = false
    }
    
    // Hop to the main thread since SwordRPC calls delegates off it and AppKit corrupts silently
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    // Ignore callbacks from an instance we already replaced since its socket is stale
    private func isCurrent(_ rpc: SwordRPC) -> Bool {
        rpc === self.rpc
    }

    // Delegate method called when RPC connects
    func swordRPCDidConnect(_ rpc: SwordRPC) {
        guard isCurrent(rpc) else { return }
        onMain { self.rpcConnected = true }
    }

    // Delegate method called when RPC disconnects
    func swordRPCDidDisconnect(_ rpc: SwordRPC, code: Int?, message msg: String?) {
        guard isCurrent(rpc) else { return }
        onMain { self.rpcConnected = false }
    }

    // Delegate method called when RPC receives an error
    func swordRPCDidReceiveError(_ rpc: SwordRPC, code: Int, message msg: String) {
        print("[RPC Error] \(code) :: \(msg)")
        guard isCurrent(rpc) else { return }
        // Disconnect from Discord RPC
        onMain { self.rpcDisconnect() }
    }

    func setStatusBarIconTo(Fill: Bool) {
        // Guard against a background caller reaching AppKit through setPresence
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.setStatusBarIconTo(Fill: Fill) }
            return
        }
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.statusBarItem.button?.image = AppDelegate.statusBarIcon(filled: Fill)
    }
    
    // MARK: Set Presence
    func setPresence(_ state: PresenceState) {
        // Check if RPC is paused
        if isPaused {
            // Disconnect and return
            rpcDisconnect()
            setStatusBarIconTo(Fill: false)
            publishPreview(PresencePreview(isActive: false))
            return
        } else {
            setStatusBarIconTo(Fill: true)
        }
        
        // Set Discord presence based on Xcode state
        switch state {
        case .xcodeNotRunning:                  /// Disconnect to allow other RPCs to connect
            rpcDisconnect()
            setStatusBarIconTo(Fill: false)
        case .xcodeNoWindowsOpen:               /// Disconnect since user isnt doing anything
            rpcDisconnect()
            setStatusBarIconTo(Fill: false)
        default:                                /// User is doing something, connect if not already connected
            if !isPaused {
                rpcConnect()
                setStatusBarIconTo(Fill: true)
            }
        }
        
        // Create a new RichPresence object
        var presence = RichPresence()
        switch state {
        case .xcodeNotRunning, .xcodeNoWindowsOpen:
            // Clear the preview since nothing is being reported
            publishPreview(PresencePreview(isActive: false))
            return

        case .working(let xcodeState):
            // Xcode is in a working state
            
            if let ws = xcodeState.workspace {
                // Set workspace details
                presence.details = "In \(ws)"
            }
            
            if xcodeState.isIdle {
                // Set idling state
                presence.state = "Idling in Xcode"
                presence.assets.largeImage = xcodeIconURL
                presence.assets.largeText = "Idling"
            } else {
                // Set active state
                if let filename = xcodeState.fileName {
                    let verb = xcodeState.isEditingFile ? "Editing" : "Viewing"

                    // Append the error and warning badge when Xcode is flagging anything
                    if let issues = xcodeState.issues.summary {
                        presence.state = "\(verb) \(filename) · \(issues)"
                    } else {
                        presence.state = "\(verb) \(filename)"
                    }
                }
                
                let ext = xcodeState.fileExtension
                presence.assets.largeImage = Self.iconURL(for: ext)

                // Set large text to file extension or default text
                presence.assets.largeText = (ext?.capitalized ?? "No") + " File"
            }
            
            // Set the start timestamp
            let date = xcodeState.sessionDate ?? .now
            presence.timestamps.start = date
            presence.timestamps.end = nil
        case .isOnWelcome:
            // User is on welcome screen so set details to welcome window
            presence.details = "In Welcome window"
            presence.state = "Choosing a project"
            
            presence.timestamps.start = nil
            presence.timestamps.end = nil
            
            presence.assets.largeImage = xcodeIconURL
            presence.assets.largeText = "Welcome to Xcode"
        }
        
        // Mirror the presence into the menu bar before handing it to Discord
        publishPreview(PresencePreview(
            details: presence.details,
            state: presence.state,
            imageURL: presence.assets.largeImage,
            imageText: presence.assets.largeText,
            start: presence.timestamps.start,
            isActive: true
        ))

        // Actually set the Discord presence
        rpc.setPresence(presence)
    }

    // Publish on the main thread since the menu bar observes this
    private func publishPreview(_ new: PresencePreview) {
        onMain {
            // Skip no-op writes so the preview does not redraw every scrape tick
            guard self.preview != new else { return }
            self.preview = new
        }
    }
}
