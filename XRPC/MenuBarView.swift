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

    // Timer for updating status bar icon periodically
    var statusUpdateTimer: Timer?

    // Held so the title can be resynced if the state changes from outside the menu
    private var pauseResumeMenuItem: NSMenuItem?

    // Width shared by the status item container and the SwiftUI content
    private static let statusItemWidth: CGFloat = 240

    // Hold both so the item can be re-sized to the content before the menu opens
    private var statusItemContainer: NSView?
    private var statusItemHosting: NSHostingView<StatusView>?

    // Function to create and configure the menu
    func createMenu() -> NSMenu {
        let statusView = StatusView()

        // Wrap in a plain container the menu can measure since an auto layout host discards its frame
        let hosting = NSHostingView(rootView: statusView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: CGRect(x: 0, y: 0,
                                             width: MenuBar.statusItemWidth,
                                             height: 140))
        container.translatesAutoresizingMaskIntoConstraints = true
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        statusItemContainer = container
        statusItemHosting = hosting
        let customMenuItem = NSMenuItem()
        customMenuItem.view = container
        menu.addItem(customMenuItem)

        // The item is sized from the delegate just before the menu is shown
        menu.delegate = self

        // Add separator to the menu
        menu.addItem(NSMenuItem.separator())
        
        // Add pause/resume menu item
        let pauseResumeMenuItem = NSMenuItem(title: rpc.isPaused ? "Resume" : "Pause",
                                             action: #selector(togglePauseResume),
                                             keyEquivalent: "p")
        pauseResumeMenuItem.target = self
        menu.addItem(pauseResumeMenuItem)
        self.pauseResumeMenuItem = pauseResumeMenuItem

        // Add refresh menu item to re-read Xcode without waiting for the next scrape tick
        let refreshMenuItem = NSMenuItem(title: "Refresh",
                                         action: #selector(refresh),
                                         keyEquivalent: "r")
        refreshMenuItem.target = self
        menu.addItem(refreshMenuItem)
        
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
        webLinkMenuItem2.representedObject = "https://sachinsagrawal.github.io"
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
        // Call RPC method to toggle pause/resume then read back the single source of truth
        rpc.togglePauseResume()
        sender.title = rpc.isPaused ? "Resume" : "Pause"
    }
    
    // Action to force the presence to re-read whatever file is open
    @objc func refresh(sender: NSMenuItem) {
        rpc.forceRefresh()
    }

    // Action to show the about panel
    @objc func about(sender: NSMenuItem) {
        // Activate first since an accessory app would open the panel behind other windows
        NSApp.activate(ignoringOtherApps: true)
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

// MARK: Menu Delegate

extension MenuBar: NSMenuDelegate {
    // Size the item from the intrinsic height since the stretched hosting frame is no use here
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Resync in case the state was changed somewhere other than this menu item
        pauseResumeMenuItem?.title = rpc.isPaused ? "Resume" : "Pause"

        guard let container = statusItemContainer,
              let hosting = statusItemHosting else { return }

        let height = hosting.intrinsicContentSize.height
        guard height > 0, abs(container.frame.height - height) > 0.5 else { return }

        container.frame.size = CGSize(width: MenuBar.statusItemWidth, height: height)
        container.layoutSubtreeIfNeeded()
    }
}
