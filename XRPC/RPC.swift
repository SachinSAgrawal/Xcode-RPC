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

// Default (?) client ID for Discord RPC
fileprivate let RPC_CLIENT_ID = "1217178081484079135"

// MARK: RPC Class
class RPC: ObservableObject, SwordRPCDelegate {
    static let shared = RPC() // Singleton instance
    
    // Variable to track if the app is paused
    var isPaused = false
    
    // SwordRPC instance
    var rpc = SwordRPC(appId: RPC_CLIENT_ID)
    
    // AXScrape instance for accessibility
    let scraper = AXScrape.init()
    
    // Set to hold cancellables
    var c = Set<AnyCancellable>()

    init() {
        // Sink to observe changes in AXScrape object
        scraper.objectWillChange.sink { _ in
            self.setPresence(self.scraper.presenceState)
        }.store(in: &c)
    }
    
    // Method to toggle pause/resume state
    func togglePauseResume() {
        isPaused.toggle()
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
    
    // Delegate method called when RPC connects
    func swordRPCDidConnect(_ rpc: SwordRPC) {
        self.rpcConnected = true
    }
    
    // Delegate method called when RPC disconnects
    func swordRPCDidDisconnect(_ rpc: SwordRPC, code: Int?, message msg: String?) {
        self.rpcConnected = false
    }
    
    // Delegate method called when RPC receives an error
    func swordRPCDidReceiveError(_ rpc: SwordRPC, code: Int, message msg: String) {
        print("[RPC Error] \(code) :: \(msg)")
        // Disconnect from Discord RPC
        self.rpcDisconnect()
    }
    
    func setStatusBarIconTo(Fill: Bool) {
        let appDelegate = NSApp.delegate as! AppDelegate
        if !Fill {
            appDelegate.statusBarItem.button?.image = NSImage(systemSymbolName: "hammer.circle", accessibilityDescription: "Xcode RPC")
        } else {
            appDelegate.statusBarItem.button?.image = NSImage(systemSymbolName: "hammer.circle.fill", accessibilityDescription: "Xcode RPC")
        }
    }
    
    // MARK: Set Presence
    func setPresence(_ state: PresenceState) {
        // Check if RPC is paused
        if isPaused {
            // Disconnect and return
            rpcDisconnect()
            setStatusBarIconTo(Fill: false)
//            print("Disconnecting?")
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
        case .xcodeNotRunning: break
        case .xcodeNoWindowsOpen: break
        
        case .working(let xcodeState):
            // Xcode is in a working state
            
            if let ws = xcodeState.workspace {
                // Set workspace details
                presence.details = "In \(ws)"
            }
            
            if xcodeState.isIdle {
                // Set idling state
                presence.state = "Idling in Xcode"
                presence.assets.largeImage = "xcode"
                presence.assets.largeText = "Idling"
            } else {
                // Set active state
                if let filename = xcodeState.fileName {
                    if xcodeState.isEditingFile {
                        presence.state = "Editing \(filename)"
                    } else {
                        presence.state = "Viewing \(filename)"
                    }
                }
                
                let exemptedExtensions = ["scnassests", "xcassets"]
                if exemptedExtensions.contains(xcodeState.fileExtension ?? "") {
                    // Set large image to Xcode logo for exempted file extensions
                    presence.assets.largeImage = "xcode"
                } else {
                    presence.assets.largeImage = xcodeState.fileExtension ?? "xcode"
                }
                
                // Set large text to file extension or default text
                presence.assets.largeText = (xcodeState.fileExtension?.capitalized ?? "No") + " File"
//                presence.assets.largeText = presence.state
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
            
            presence.assets.largeImage = "xcode"
            presence.assets.largeText = "Welcome to Xcode"
        }
        
        // Actually set the Discord presence
        rpc.setPresence(presence)
    }
}
