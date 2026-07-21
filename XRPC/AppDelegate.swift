//
//  AppDelegate.swift
//  XRPC
//
//  Created by Lakhan Lothiyi on 12/03/2024.
//

import Cocoa
import SwiftUI

// MARK: App Delegate
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! // Singleton instance
    lazy var statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = MenuBar()
    
    // Main application window
    var window: NSWindow? = nil
    
    // Shared RPC instance
    var rpc = RPC.shared

    // Nudge the hammer above the default 15pt without crowding the items beside it
    static let statusIconConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)

    // Build the status bar icon in either its idle or active variant
    static func statusBarIcon(filled: Bool) -> NSImage? {
        NSImage(systemSymbolName: filled ? "hammer.circle.fill" : "hammer.circle",
                accessibilityDescription: "Xcode RPC")?
            .withSymbolConfiguration(statusIconConfiguration)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the AppDelegate instance
        AppDelegate.instance = self
        
        // Configure status bar item
        statusBarItem.button?.image = Self.statusBarIcon(filled: false)
        statusBarItem.button?.imagePosition = .imageLeading
        statusBarItem.menu = menu.createMenu() // Create and set the menu
        
        // Set application activation policy to accessory
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
        
        // Perform initial RPC check after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.rpc.initialCheck()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
    }
    
    // Show the setup window
    func showSetupWindow() {
        // Reuse the existing window if setup is already on screen
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(self)
            return
        }

        // Create setup view
        let contentView = SetupView()

        // Exit the app when this window closes
        let controller = KillOnCloseViewController()
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame.size = hosting.fittingSize

        // Round the backing layer so the window shadow follows the glass instead of a rectangle
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.cornerRadius = 20
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        controller.view = hosting

        // Borderless only — `.fullSizeContentView` would keep a rectangular theme frame around the glass
        let window = KeyableBorderlessWindow(
            contentRect: .init(origin: .zero, size: hosting.fittingSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.window = window
        window.contentViewController = controller

        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        
        window.hasShadow = true

        // Start above everything so the user actually sees it
        window.level = .floating

        window.setContentSize(hosting.fittingSize)
        window.center()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(self)

        // Drop to a normal window after showing so it stops hovering over other apps
        DispatchQueue.main.async {
            window.level = .normal
        }

        SetupVM.shared.setupWindowClose = { [weak self] in
            // Block dismissal until accessibility is actually granted
            guard SetupVM.shared.accessibilityAllowed else { return }
            self?.window?.close()
            self?.window = nil
            
            // Relaunch so the just-granted accessibility access actually applies
            self?.relaunch()
        }
    }

    // Restart in a fresh process since macOS only grants accessibility at launch
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL,
                                           configuration: configuration) { _, _ in
            DispatchQueue.main.async { exit(0) }
        }
    }
}

// MARK: Borderless Window

// Restore key status since borderless windows refuse it and that would break the buttons
class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: Exit on Close
class KillOnCloseViewController: NSViewController {
    // View controller that exits the application when the setup window is closed
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    // Exit the app when accessibility was never granted
    override func viewDidDisappear() {
        guard SetupVM.shared.accessibilityAllowed else {
            exit(0)
        }
    }
}

// MARK: Monitor Events
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    // Initialize the event monitor
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    // Deinitialize the event monitor
    deinit {
        stop()
    }
    
    // Start monitoring events
    public func start() {
        // No cast since this returns nil when the monitor cannot be installed
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    // Stop monitoring events
    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
