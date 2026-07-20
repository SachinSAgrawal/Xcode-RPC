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
        // Scrape every 2 seconds with a weak capture since the retained block would pin self forever
        self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] _ in
            self?.scrape()
        })
    }

    // Stop the timer so a discarded scraper stops firing and releases its block
    deinit {
        timer?.invalidate()
        timer = nil
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
        if mainWindow == nil && (windows?.isEmpty ?? true) {
            self.presenceState = .xcodeNoWindowsOpen
            return
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
        
        // Carry the previous state forward so the session timer can survive a scrape
        let previous: XcodeState? = {
            switch presenceState {
            case .working(let xcodeState):
                return xcodeState
            default: return nil
            }
        }()

        // Drop the old start time when the user moves to a different workspace
        let currentSessionDate: Date? = previous?.workspace == workspace ? previous?.sessionDate : nil
        
        // Count what Xcode is flagging in the file currently on screen
        let issues = focusedWindow.map(Self.scrapeIssues(in:)) ?? .none

        // Create Xcode state object
        let xcState = XcodeState(
            workspace: workspace,
            editorFile: doc,
            isEditingFile: isEditing,
            // Preserve Xcode last date or make new date
            sessionDate: currentSessionDate ?? xcodeProcess?.launchDate ?? .now, /// Used for timings
            issues: issues
        )
        
        // Set presence state to working with Xcode state
        self.presenceState = .working(xcState)
    }

    // MARK: Issue Scraping

    // Tally the errors and warnings Xcode is drawing in the frontmost source editor
    static func scrapeIssues(in window: UIElement) -> IssueCounts {
        // Pool the accessibility wrappers this walk allocates so peak memory stays flat
        autoreleasepool {
            // Errors and warnings live on the editor itself rather than the window chrome
            guard let editor = firstElement(in: window, matching: {
                (try? $0.role()) ?? .unknown == .textArea
                    && (try? $0.attribute(.description) ?? "") == "Source Editor"
            }) else { return .none }

            // Xcode tags each flagged line with a "Line Annotation" button
            let annotations = allElements(in: editor, matching: {
                (try? $0.role()) ?? .unknown == .button
                    && (try? $0.attribute(.identifier)) == "Line Annotation"
            })

            var counts = IssueCounts.none
            for annotation in annotations {
                counts.total += 1

                // The kind is only exposed in the description string
                // Match anywhere and case-insensitively: Xcode phrases this as
                // "Error", "1 error", "Issue: error…" depending on the annotation
                let label = ((try? annotation.attribute(.description) ?? "") ?? "").lowercased()
                if label.contains("error") {
                    counts.errors += 1
                } else if label.contains("warning") {
                    counts.warnings += 1
                }
            }
            return counts
        }
    }
}

// MARK: Issue Counts

// What Xcode is flagging in the file on screen
struct IssueCounts: Equatable {
    var errors: Int
    var warnings: Int
    var total: Int /// Includes annotations that are neither an error nor a warning

    // Nothing flagged, which is also the state when the editor cannot be read
    static let none = IssueCounts(errors: 0, warnings: 0, total: 0)

    // True when there is nothing worth putting in front of anyone
    var isEmpty: Bool { total == 0 }

    // Short badge for the presence line, showing both counts when both are present
    var summary: String? {
        var parts = [String]()
        if errors > 0 { parts.append("⛔️\(errors)") }
        if warnings > 0 { parts.append("⚠️\(warnings)") }

        // Fall back to a plain count for annotations that are neither kind
        if parts.isEmpty && total > 0 { parts.append("⚠️\(total)") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

// MARK: Accessibility Traversal

extension UIElement {
    // AXSwift returns raw element refs so wrap them back up to keep walking
    func childElements() -> [UIElement] {
        let children: [AXUIElement] = ((try? attribute(.children)) ?? nil) ?? []
        return children.map { UIElement($0) }
    }
}

// Depth first search that stops at the first hit rather than walking the whole tree
func firstElement(in element: UIElement, matching filter: (UIElement) -> Bool) -> UIElement? {
    if filter(element) { return element }
    for child in element.childElements() {
        if let match = firstElement(in: child, matching: filter) { return match }
    }
    return nil
}

// Collect every element under this one that matches
func allElements(in element: UIElement, matching filter: (UIElement) -> Bool) -> [UIElement] {
    var matches = [UIElement]()
    if filter(element) { matches.append(element) }
    for child in element.childElements() {
        matches.append(contentsOf: allElements(in: child, matching: filter))
    }
    return matches
}

// MARK: Presence State
enum PresenceState {
    // Enumeration to represent different presence states
    case xcodeNotRunning
    case xcodeNoWindowsOpen  /// When Xcode has no windows and is doing nothing
    case working(XcodeState) /// When user is working
    case isOnWelcome

    // Spell out the state since the status icon only says running or not
    var displayName: String {
        switch self {
        case .xcodeNotRunning:   return "Not open"
        case .xcodeNoWindowsOpen: return "No active window"
        case .working:           return "Working on a project"
        case .isOnWelcome:       return "In the welcome screen"
        }
    }
}

// MARK: Xcode Struct
struct XcodeState: Equatable {
    var workspace: String?  /// Workspace name
    var editorFile: URL?    /// URL of the editing file
    var isEditingFile: Bool /// Flag indicating if a file is being edited
    
    // Date of the current session
    var sessionDate: Date?

    // Errors and warnings Xcode is showing in this file
    var issues: IssueCounts = .none

    // Boolean indicating if Xcode is idle and no file is open
    var isIdle: Bool {
        // Match the whole extension so names like contents.xcworkspacedata do not count
        guard let ext = editorFile?.pathExtension.lowercased() else { return true }
        return ext == "xcodeproj" || ext == "xcworkspace"
    }

    // File name being edited
    var fileName: String? {
        if isIdle { return nil }
        return editorFile?.lastPathComponent.removingPercentEncoding
    }

    // File extension of the editing file
    var fileExtension: String? {
        guard let fileName else { return nil }
        // Strip a leading dot so dotfiles like .gitignore still resolve to their icon
        let isDotfile = fileName.hasPrefix(".")
        let trimmed = isDotfile ? String(fileName.dropFirst()) : fileName
        // Nil for extensionless names like Makefile rather than the whole filename
        guard isDotfile || trimmed.contains(".") else { return nil }
        return trimmed.split(separator: ".").last.map { $0.lowercased() }
    }
}

// MARK: Extension
fileprivate extension String {
    // Extension to count occurrences of a string within another string
    func numberOfOccurrencesOf(string: String) -> Int {
        self.components(separatedBy: string).count - 1
    }
}
