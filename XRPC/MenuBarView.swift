//
//  MenuBarView.swift
//  XRPC
//
//  Created by Sachin Agrawal on 4/22/24.
//

import Foundation
import SwiftUI

// MARK: Menu Bar
class MenuBar: NSObject {
    // Create a new NSMenu instance
    let menu = NSMenu()
    
    // Observed RPC object
    let rpc = RPC.shared
    
    // Variable to track if the app is paused
    var isPaused = false
    
    // Timer for updating status bar icon periodically
    var statusUpdateTimer: Timer?
    
    // Function to create and configure the menu
    func createMenu() -> NSMenu {
        // Create the status view
        let statusView = StatusView()
        let topView = NSHostingController(rootView: statusView)
        topView.view.frame.size = CGSize(width: 200, height: 48)
        let customMenuItem = NSMenuItem()
        customMenuItem.view = topView.view
        menu.addItem(customMenuItem)
        
        // Add separator to the menu
        menu.addItem(NSMenuItem.separator())
        
        // Add pause/resume menu item
        let pauseResumeMenuItem = NSMenuItem(title: isPaused ? "Resume" : "Pause",
                                             action: #selector(togglePauseResume),
                                             keyEquivalent: "p")
        pauseResumeMenuItem.target = self
        menu.addItem(pauseResumeMenuItem)
        
        // Add separator to the menu
        menu.addItem(NSMenuItem.separator())
        
        // Add web links to the menu
        let webLinkMenuItem1 = NSMenuItem(title: "By Lakhan Lothiyi",
                                          action: #selector(openLink),
                                          keyEquivalent: "")
        webLinkMenuItem1.target = self
        webLinkMenuItem1.representedObject = "https://github.com/llsc12"
        menu.addItem(webLinkMenuItem1)
        
        let webLinkMenuItem2 = NSMenuItem(title: "By Sachin Agrawal",
                                          action: #selector(openLink),
                                          keyEquivalent: "")
        webLinkMenuItem2.target = self
        webLinkMenuItem2.representedObject = "https://sachinagrawal.me"
        menu.addItem(webLinkMenuItem2)
        
        // Add another separator to the menu
        menu.addItem(NSMenuItem.separator())
        
        // Add about menu item to show information about the app
        let aboutMenuItem = NSMenuItem(title: "About Xcode RPC",
                                       action: #selector(about),
                                       keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)
        
        // Add quit menu item to terminate the app
        let quitMenuItem = NSMenuItem(title: "Quit App",
                                      action: #selector(quit),
                                      keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        // Return the configured menu
        return menu
    }
    
    // Action to toggle pause/resume state
    @objc func togglePauseResume(sender: NSMenuItem) {
        isPaused.toggle()
        sender.title = isPaused ? "Resume" : "Pause"
        // Call RPC method to toggle pause/resume
        rpc.togglePauseResume()
    }
    
    // Action to show the about panel
    @objc func about(sender: NSMenuItem) {
        NSApp.orderFrontStandardAboutPanel()
    }
    
    // Action to open a link in the default browser
    @objc func openLink(sender: NSMenuItem) {
        let link = sender.representedObject as! String
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }
    
    // Action to quit the app
    @objc func quit(sender: NSMenuItem) {
        NSApp.terminate(self)
    }
}
