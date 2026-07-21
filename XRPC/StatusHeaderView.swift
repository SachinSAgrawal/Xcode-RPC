//
//  StatusHeaderView.swift
//  XRPC
//
//  Created by Lakhan Lothiyi on 12/03/2024.
//

import SwiftUI

// MARK: Status View
struct StatusView: View {
    // Observed RPC object
    @ObservedObject var rpc = RPC.shared

    // Observed scraper object for Xcode
    @ObservedObject var ax = RPC.shared.scraper

    // Observed setup state so the menu reflects accessibility trust during setup
    @ObservedObject var setup = SetupVM.shared

    var body: some View {
        // Space the divider itself so the gap above matches the one the menu insets below
        VStack(spacing: 0) {
            if setup.accessibilityAllowed {
                VStack(spacing: 6) {
                    // Discord RPC status
                    HStack {
                        // Mirror the Xcode row so both read as a name over its current state
                        VStack(alignment: .leading, spacing: 1) {
                            Text("RPC")
                            Text(rpc.rpcConnected ? "Active" : "Inactive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if rpc.rpcConnected {
                            // Checkmark icon if connected
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.gray)
                        } else {
                            // X mark icon if not connected
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }

                    // Xcode status
                    HStack {
                        // Drop the secondary line underneath since the icon only says running or not
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Xcode")
                            Text(ax.presenceState.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        switch ax.presenceState {
                        // If Xcode is not running
                        case .xcodeNotRunning:
                            // X mark icon
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        default:
                            // Checkmark icon
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }

                Divider()
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                // Show what Discord is currently reporting to everyone else
                PresencePreviewView(preview: rpc.preview)
            } else {
                // Accessibility has not been granted yet so nothing can be read from Xcode
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Accessibility")
                        Text("Not granted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.gray)
                }

                Divider()
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                // Point the user at the setup step that unblocks everything else
                Text("Grant Accessibility access in setup to start showing your Xcode activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Match the stock menu item inset and let the menu draw its own vertical gap
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(width: 240, alignment: .topLeading)

        // Pin to the ideal height so the hosting view reports a content sized intrinsic height
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Presence Preview

// Approximate the Discord activity card so this matches what others see on the profile
struct PresencePreviewView: View {
    let preview: PresencePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Showing on Discord")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if preview.isActive {
                HStack(alignment: .top, spacing: 8) {
                    // Draw the same remote image handed to Discord so breakage shows up here too
                    artwork

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Xcode RPC")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if let details = preview.details {
                            Text(details)
                                .font(.caption)
                                .lineLimit(1)
                        }

                        if let state = preview.state {
                            Text(state)
                                .font(.caption)
                                .lineLimit(1)
                        }

                        if let start = preview.start {
                            // Match the elapsed counter Discord runs on the card
                            Text(start, style: .timer)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
            } else {
                Text("Nothing is being shown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Render remote art behind a placeholder so the row does not jump while it loads
    @ViewBuilder private var artwork: some View {
        Group {
            if let urlString = preview.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help(preview.imageText ?? "")
    }
}
