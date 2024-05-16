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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the AppDelegate instance
        AppDelegate.instance = self
        
        // Configure status bar item
        statusBarItem.button?.image = .init(systemSymbolName: "hammer.circle", accessibilityDescription: "Xcode RPC")
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
    
    // Function to show the setup window
    func showSetupWindow() {
        // Create setup view
        let contentView = SetupView()
        // View controller to handle window close
        let controller = KillOnCloseViewController()
        // Create window with controller
        self.window = .init(contentViewController: controller)
        
        self.window?.contentViewController?.view = NSHostingView(rootView: contentView)
        self.window?.setContentSize(.init(width: 300, height: 400))
        self.window?.titleVisibility = .hidden
        self.window?.backgroundColor = .clear
//        self.window?.standardWindowButton(.closeButton)?.isHidden = true
        self.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.window?.standardWindowButton(.zoomButton)?.isHidden = true
//        let titlebar = self.window?.standardWindowButton(.closeButton)?.superview
//        self.window?.titlebarAppearsTransparent = true
        self.window?.makeKeyAndOrderFront(self)
        SetupVM.shared.setupWindowClose = { self.window?.close(); self.window = nil}
    }
}

// MARK: Exit on Close
class KillOnCloseViewController: NSViewController {
    // View controller that exits the application when the setup window is closed
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    // If accessibility is not allowed, exit the application
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
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }
    
    // Stop monitoring events
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}

/*
class AppDelegate: NSObject, NSApplicationDelegate {
    var popover = NSPopover.init()
    var statusBar: StatusBarController?
    var window: NSWindow? = nil
    
    var rpc = RPC.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the contents
        let contentView = MenuBarView()
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
        
        // Set the SwiftUI's ContentView to the Popover's ContentViewController
        popover.contentViewController = NSViewController()
        popover.contentSize = NSSize(width: 128, height: 128)
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        
        // Create the Status Bar Item with the Popover
        statusBar = StatusBarController.init(popover)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.rpc.initialCheck()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
    }
    
    func popMenubarView() {
        guard let statusBar else { return }
        statusBar.hidePopover(nil)
    }
    
    func showMenubarView() {
        guard let statusBar else { return }
        statusBar.showPopover(nil)
    }
    
    func showSetupWindow() {
        let contentView = SetupView()
        let controller = KillOnCloseViewController()
        self.window = .init(contentViewController: controller)
        self.window?.contentViewController?.view = NSHostingView(rootView: contentView)
        self.window?.setContentSize(.init(width: 300, height: 400))
        self.window?.titleVisibility = .hidden
        self.window?.backgroundColor = .clear
        //    self.window?.standardWindowButton(.closeButton)?.isHidden = true
        self.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.window?.standardWindowButton(.zoomButton)?.isHidden = true
        let titlebar = self.window?.standardWindowButton(.closeButton)?.superview
        //    self.window?.titlebarAppearsTransparent = true
        self.window?.makeKeyAndOrderFront(self)
        SetupVM.shared.setupWindowClose = { self.window?.close(); self.window = nil}
    }
}

class KillOnCloseViewController: NSViewController {
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    override func viewDidDisappear() {
        guard SetupVM.shared.accessibilityAllowed else {
            exit(0)
        }
    }
}

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as! NSObject
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?
    
    init(_ popover: NSPopover)
    {
        self.popover = popover
        statusBar = NSStatusBar.init()
        statusItem = statusBar.statusItem(withLength: 28.0)
        
        if let statusBarButton = statusItem.button {
            statusBarButton.image = .init(systemSymbolName: "hammer.fill", accessibilityDescription: "XRPC")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true
            
            statusBarButton.action = #selector(togglePopover(sender:))
            statusBarButton.target = self
        }
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: mouseEventHandler)
    }
    
    @objc func togglePopover(sender: AnyObject) {
        if(popover.isShown) {
            hidePopover(sender)
        }
        else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let statusBarButton = statusItem.button {
            popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: NSRectEdge.maxY)
            eventMonitor?.start()
        }
    }
    
    func hidePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    func mouseEventHandler(_ event: NSEvent?) {
        if(popover.isShown) {
            hidePopover(event!)
        }
    }
}
*/
