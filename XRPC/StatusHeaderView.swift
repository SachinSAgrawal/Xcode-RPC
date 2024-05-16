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
    
    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                // Discord RPC status
                HStack {
                    Text("RPC Connected")
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
                    Text("Xcode Running")
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
            .frame(maxHeight: .infinity)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: Header (Unused)
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 6) {
            // Title text
            Text("Xcode RPC")
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity, alignment: .center)
            // Formatting stuff
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
