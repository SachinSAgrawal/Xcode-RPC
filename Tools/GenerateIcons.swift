#!/usr/bin/env swift

//
//  GenerateIcons.swift
//  XRPC
//
//  Created by Sachin Agrawal on 7/20/26.
//

// Run swift Tools/GenerateIcons.swift to regenerate the icons Discord displays from LaunchServices

import Cocoa
import CryptoKit
import Foundation
import UniformTypeIdentifiers

// Discord recommends 1024x1024 for presence art
let iconSize: CGFloat = 1024

// Everything Xcode is likely to open plus the usual supporting cast
let extensions = [
    // Apple languages
    "swift", "m", "mm", "h", "hpp", "hh", "hxx", "c", "cc", "cpp", "cxx",
    "metal", "s", "asm", "nasm", "pch", "iig", "modulemap", "inl", "ipp", "tpp",
    // Interface and project files
    "storyboard", "xib", "nib", "plist", "entitlements", "xcconfig", "pbxproj",
    "xcscheme", "xcworkspacedata", "xcstrings", "strings", "stringsdict",
    "playground", "xcplayground", "storekit", "xctestplan", "xcappdata",
    // Assets and 3D
    "xcassets", "scnassets", "sks", "scn", "dae", "usdz", "reality",
    "rcproject", "arobject", "gputrace",
    // Data models
    "xcdatamodel", "xcdatamodeld", "mom", "momd",
    // Machine learning
    "mlmodel", "mlpackage",
    // Build products and libraries
    "framework", "xcframework", "bundle", "app", "a", "dylib", "o",
    // Build systems
    "cmake", "make", "makefile", "mk", "exp", "r", "resolved", "lock",
    "podspec", "podfile", "gemfile", "dockerfile",
    // Other languages
    "rb", "py", "sh", "bash", "zsh", "pl", "lua", "java", "kt", "go", "rs",
    "php", "dart", "js", "jsx", "ts", "tsx", "vue", "svelte", "sql",
    "graphql", "proto", "wasm",
    // Markup and config
    "json", "yml", "yaml", "xml", "html", "css", "scss", "md", "markdown",
    "txt", "toml", "ini", "cfg", "conf", "env", "log", "csv", "tsv",
    "gitignore", "gitattributes", "docc", "tutorial",
    // Media
    "pdf", "png", "jpg", "jpeg", "gif", "svg", "webp", "heic",
    "mp3", "wav", "aiff", "m4a", "mp4", "mov", "ttf", "otf",
    // Archives
    "zip", "tar", "gz",
]

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let outDir = root.appendingPathComponent("Icons")
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

// Renders an NSImage to PNG data at the target size
func png(from image: NSImage) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(iconSize), pixelsHigh: Int(iconSize),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    rep.size = NSSize(width: iconSize, height: iconSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
        from: .zero, operation: .sourceOver, fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let workspace = NSWorkspace.shared

// LaunchServices hands back the icon belonging to whichever app currently owns a
// file type, so with VS Code or Chrome installed the art comes back badged with
// their logos instead of Apple's
// Only Xcode and the system are trusted to supply an icon
func ownerIsTrusted(ofProbeNamed name: String) -> Bool {
    let probe = fm.temporaryDirectory.appendingPathComponent(name)
    fm.createFile(atPath: probe.path, contents: Data())
    defer { try? fm.removeItem(at: probe) }
    guard let owner = workspace.urlForApplication(toOpen: probe)?.path else {
        // Nothing claims it, so macOS renders its own generic art
        return true
    }
    return owner.hasPrefix("/System/")
        || owner.hasPrefix("/Applications/Xcode")
        || owner.hasPrefix("/Applications/Utilities/")
}

// Apple labels an otherwise plain document with its extension
// Rebuilding that here keeps hijacked types looking like the rest of the set
func composeGenericIcon(for ext: String) -> NSImage {
    let base = workspace.icon(for: UTType("public.source-code") ?? .data)
    let canvas = NSImage(size: NSSize(width: iconSize, height: iconSize))

    canvas.lockFocus()
    base.draw(
        in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
        from: .zero, operation: .sourceOver, fraction: 1.0
    )

    // Sized to sit where Apple puts it, shrinking only once the extension is long
    // enough that it would otherwise run past the edge of the page
    let label = ext.uppercased()
    let fontSize = min(iconSize * 0.085, iconSize * 0.5 / CGFloat(max(label.count, 1)))
    let style = NSMutableParagraphStyle()
    style.alignment = .center

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
        .foregroundColor: NSColor(white: 0.72, alpha: 1.0),
        .paragraphStyle: style,
    ]
    let text = NSAttributedString(string: label, attributes: attrs)
    let height = text.size().height
    text.draw(in: NSRect(
        x: 0, y: iconSize * 0.145,
        width: iconSize, height: height
    ))
    canvas.unlockFocus()

    return canvas
}

// Maps a file name on disk to the icon macOS would show for it
func icon(forExtension ext: String) -> NSImage {
    // Some of these are whole file names rather than suffixes
    let bareNames = ["makefile", "podfile", "gemfile", "dockerfile", "gitignore", "gitattributes"]
    // LaunchServices takes the icon for these from whichever editor registered
    // one, which is not necessarily the app that opens them, so the ownership
    // check cannot be trusted here
    // macOS has no distinctive art for any of them, so compose every one
    if bareNames.contains(ext) {
        return composeGenericIcon(for: ext)
    }
    guard ownerIsTrusted(ofProbeNamed: "probe.\(ext)"), let type = UTType(filenameExtension: ext) else {
        return composeGenericIcon(for: ext)
    }
    return workspace.icon(for: type)
}

// Content hash so identical icons collapse onto one file
var byHash: [String: String] = [:]
var mapping: [String: String] = [:]
var written = 0

// Hash of the unlabelled generic document, used to spot the types macOS has no
// art for at all
let genericHash: String? = png(from: workspace.icon(for: .data)).map {
    SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
}

for ext in extensions {
    guard var data = png(from: icon(forExtension: ext)) else {
        FileHandle.standardError.write("failed to render \(ext)\n".data(using: .utf8)!)
        continue
    }
    var hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

    // A bare document with nothing on it reads as a missing image once Discord
    // has scaled it down, so label these rather than letting them all collapse
    // onto the same blank page
    if hash == genericHash, let labelled = png(from: composeGenericIcon(for: ext)) {
        data = labelled
        hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    if let existing = byHash[hash] {
        mapping[ext] = existing
        continue
    }
    try data.write(to: outDir.appendingPathComponent("\(ext).png"))
    byHash[hash] = ext
    mapping[ext] = ext
    written += 1
}

// The generic document icon backs any extension not covered above
if let data = png(from: workspace.icon(for: .data)) {
    try data.write(to: outDir.appendingPathComponent("_default.png"))
    written += 1
}

// Xcode's own icon is used for idling and the welcome window
let xcodeIcon = workspace.icon(forFile: "/Applications/Xcode.app")
if let data = png(from: xcodeIcon) {
    try data.write(to: outDir.appendingPathComponent("_xcode.png"))
    written += 1
}

// Emit the Swift lookup table consumed by RPC.swift
var swift = """
//
//  FileIcons.swift
//  XRPC
//
//  Created by Sachin Agrawal on 7/20/26.
//

// Generated by Tools/GenerateIcons.swift so re-run it to pick up new file types

import Foundation

// Maps a lowercased file extension to its icon file which several extensions can share
let fileIconNames: [String: String] = [\n
"""
for ext in mapping.keys.sorted() {
    swift += "    \"\(ext)\": \"\(mapping[ext]!)\",\n"
}
swift += "]\n"

try swift.write(
    to: root.appendingPathComponent("XRPC/FileIcons.swift"),
    atomically: true, encoding: .utf8
)

print("wrote \(written) icons for \(mapping.count) extensions -> Icons/")
print("wrote XRPC/FileIcons.swift")
