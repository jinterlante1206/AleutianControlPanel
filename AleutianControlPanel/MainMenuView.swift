//
//  MainMenuView.swift
//  AleutianControlPanel
//
//  Created by Jin on 10/26/25.
//
// Copyright (C) 2025 Aleutian AI (jinterlante@aleutian.ai)
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// See the LICENSE.txt file for the full license text.
//
// NOTE: This work is subject to additional terms under AGPL v3 Section 7.
// See the NOTICE.txt file for details regarding AI system attribution.

import AppKit
import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var stackManager: StackManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- Ensure the cases are INSIDE the switch ---
            switch stackManager.stackStatus {
            case .stopped:
                HeaderView(icon: "icon-stopped", status: "Stack stopped")
                MenuButton(title: "Start aleutian stack") {
                    stackManager.startStack()
                }
            case .starting:
                HeaderView(icon: "icon-starting", status: "Stack starting up")
                MenuButton(title: "Starting...", disabled: true) {} // Corrected title
            case .running:
                HeaderView(icon: "icon-running", status: "Stack running")
                MenuButton(title: "Stop aleutian stack") {
                    stackManager.stopStack()
                }
            case .error(let msg):
                HeaderView(icon: "icon-error", status: "Error")
                // Make the error message selectable and wrap lines
                 Text(msg)
                     .font(.caption)
                     .padding(.horizontal, 10) // Match other padding
                     .lineLimit(nil) // Allow multiple lines
                     .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
            }
            // --- End Switch ---

            Divider().padding(.vertical, 4)

            // Use the extracted view
            if stackManager.stackStatus == .running && !stackManager.services.isEmpty {
                RunningStatusMenuView()
            }

            // App Buttons
            MenuButton(title: "Preferences...") {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            .padding(.vertical, 2)
            MenuButton(title: "Quit Aleutian Control Panel") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.vertical, 2)
        }
        .padding(.vertical, 5)
    }
}


struct MenuButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .contentShape(Rectangle()) // Makes the whole area clickable
        }
        .buttonStyle(.plain) // This is the key! Makes it look like a menu item.
        .padding(.horizontal, 10) // Clean spacing
        .disabled(disabled)
    }
}

struct HeaderView: View {
    let icon: String
    let status: String
    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(status)
                .font(.headline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

struct RunningStatusMenuView: View {
    @EnvironmentObject var stackManager: StackManager

    var body: some View {
        Menu("Services") {
            ForEach(Array(stackManager.services), id: \PodmanContainer.id) { service in
                let serviceName = service.Names.first ?? "Unknown Service"
                Menu(serviceName) {
                    Button("View Logs") {
                        stackManager.streamLogs(for: serviceName)
                    }
                }
            }
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        
        MenuButton(title: "View All Stats") {
            stackManager.openAllStats()
        }
        .padding(.vertical, 2)

        Divider().padding(.vertical, 4)

        // Quick Links
        MenuButton(title:"Open Jaeger UI") {
            NSWorkspace.shared.open(URL(string: "http://localhost:16686")!)
        }
        .padding(.vertical, 2)
        MenuButton(title:"Open Grafana UI") {
            NSWorkspace.shared.open(URL(string: "http://localhost:3000")!)
        }
        .padding(.vertical, 2)

        Divider().padding(.vertical, 4)
    }
}
