//
//  AppDelegate.swift
//  AleutianControlPanel
//
//  Created by Jin on 10/27/25.
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

import SwiftUI
import AppKit
import Combine // <-- 1. Import Combine framework

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    // Use @StateObject if AppDelegate were a SwiftUI view,
    // but here, just keep a strong reference.
    var stackManager = StackManager()

    // --- References to specific menu items ---
    var statusMenuItem: NSMenuItem?
    var startStopMenuItem: NSMenuItem?
    var servicesMenuItem: NSMenuItem?
    var logsMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    // private var cancellables = Set<AnyCancellable>() // Correct type now Combine is imported
    private var cancellables: Set<AnyCancellable> = [] // Initialize explicitly


    func applicationDidFinishLaunching(_ notification: Notification) {
        print("DEBUG: applicationDidFinishLaunching: START")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // --- 2. Setup the Status Bar Icon ---
        if let button = statusItem?.button {
             if let image = NSImage(named: "icon-stopped") { // Load initial icon
                 image.isTemplate = true // Make sure it's a template image
                 button.image = image
             } else {
                 print("ERROR: Could not load status bar icon 'icon-stopped'")
                 button.title = "A" // Fallback text
             }
         } else {
             print("ERROR: Could not create status bar button.")
             // Handle error - maybe quit the app?
             NSApplication.shared.terminate(self)
             return
         }


        // --- Build the Static Menu Structure ---
        let menu = NSMenu()
        menu.delegate = self // Set delegate

        // Status Item (non-interactive)
        statusMenuItem = NSMenuItem(title: "Status: Checking...", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false // Make it clear it's not clickable
        menu.addItem(statusMenuItem!)
        menu.addItem(NSMenuItem.separator())

        // Start/Stop Item
        startStopMenuItem = NSMenuItem(title: "Start Stack", action: #selector(startStackClicked), keyEquivalent: "") // Initial action
        startStopMenuItem?.target = self
        menu.addItem(startStopMenuItem!)
        menu.addItem(NSMenuItem.separator())

        // Services Submenu Item
        servicesMenuItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesMenuItem?.submenu = NSMenu(title: "Services") // Give submenu a title for debugging
        menu.addItem(servicesMenuItem!)

        // Logs Submenu Item
        logsMenuItem = NSMenuItem(title: "View Logs", action: nil, keyEquivalent: "") // Renamed slightly
        logsMenuItem?.submenu = NSMenu(title: "View Logs") // Give submenu a title
        menu.addItem(logsMenuItem!)
        
        // All Stats Submenu Item
        let allStatsItem = NSMenuItem(title: "View All Stats", action: #selector(viewAllStatsClicked), keyEquivalent: "")
        allStatsItem.target = self
        menu.addItem(allStatsItem)
        
        menu.addItem(NSMenuItem.separator())

        // Static Links
        let jaegerItem = NSMenuItem(title: "Open Jaeger UI", action: #selector(openJaeger), keyEquivalent: "")
        jaegerItem.target = self
        menu.addItem(jaegerItem)

        // --- 3. Add Grafana Item ---
        let grafanaItem = NSMenuItem(title: "Open Grafana UI", action: #selector(openGrafana), keyEquivalent: "")
        grafanaItem.target = self
        menu.addItem(grafanaItem)
        // --- End Add Grafana Item ---

        menu.addItem(NSMenuItem.separator())

        // Preferences & Quit
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit Aleutian Control Panel", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // --- Observe StackManager for Updates ---
        stackManager.$stackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("DEBUG: Received status update: \(status)")
                self?.updateIcon(for: status)
                self?.updateMenuItems(for: status)
            }
            .store(in: &cancellables)

        stackManager.$services
             .receive(on: DispatchQueue.main)
             .sink { [weak self] services in
                 print("DEBUG: Received services update: \(services.count) services") // Log service change
                 self?.updateServicesSubmenu(with: services)
                 self?.updateLogsSubmenu(with: services)
             }
             .store(in: &cancellables)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.stackManager.startMonitoring()
        }
        print("DEBUG: applicationDidFinishLaunching: END - Menu is set, monitoring started.")
    }

    // --- Update Icon ---
    func updateIcon(for status: StackManager.StackState) {
        let iconName: String
        switch status {
        case .stopped:
            iconName = "icon-stopped"
        case .starting:
            iconName = "icon-starting"
        case .running:
            iconName = "icon-running"
        case .error:
            iconName = "icon-error"
        }

        if let button = statusItem?.button {
            if let image = NSImage(named: iconName) {
                image.isTemplate = true
                button.image = image
            } else {
                 print("ERROR: Could not load icon named '\(iconName)'")
            }
        }
    }


    // --- Update Menu Items ---
    func updateMenuItems(for status: StackManager.StackState) {
        switch status {
        case .stopped:
            statusMenuItem?.title = "Status: Stopped"
            statusMenuItem?.image = nil // Or a specific stopped icon
            startStopMenuItem?.title = "Start Aleutian Stack"
            startStopMenuItem?.action = #selector(startStackClicked)
            startStopMenuItem?.isEnabled = true
            servicesMenuItem?.isHidden = true
            logsMenuItem?.isHidden = true
        case .running:
            // Check overall health based on services list
            let hasUnhealthy = stackManager.services.contains { !$0.Status.contains("(healthy)") && $0.State == "running" }
            if hasUnhealthy {
                 statusMenuItem?.title = "Status: Running (Degraded)"
                 // Optionally set an orange/warning icon
                 statusMenuItem?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
            } else {
                 statusMenuItem?.title = "Status: Running (Healthy)"
                 statusMenuItem?.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Healthy")
            }
            startStopMenuItem?.title = "Stop Aleutian Stack"
            startStopMenuItem?.action = #selector(stopStackClicked)
            startStopMenuItem?.isEnabled = true
            servicesMenuItem?.isHidden = false
            logsMenuItem?.isHidden = false
        case .starting:
             statusMenuItem?.title = "Status: Starting..."
             statusMenuItem?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: "Starting")
             startStopMenuItem?.title = "Starting..."
             startStopMenuItem?.action = nil // Disable action by removing selector
             startStopMenuItem?.isEnabled = false
             servicesMenuItem?.isHidden = true
             logsMenuItem?.isHidden = true
        case .error(let msg):
             statusMenuItem?.title = "Status: Error"
             statusMenuItem?.image = NSImage(systemSymbolName: "exclamationmark.octagon.fill", accessibilityDescription: "Error")
             startStopMenuItem?.title = "Start Aleutian Stack" // Allow retry
             startStopMenuItem?.action = #selector(startStackClicked)
             startStopMenuItem?.isEnabled = true
             servicesMenuItem?.isHidden = true
             logsMenuItem?.isHidden = true
             print("ERROR State in UI: \(msg)") // Log the error message
        }
    }

    func updateServicesSubmenu(with services: [PodmanContainer]) {
        guard let submenu = servicesMenuItem?.submenu else { return }
        submenu.removeAllItems() // Clear previous items

        if services.isEmpty && stackManager.stackStatus == .running {
             submenu.addItem(NSMenuItem(title: "No services found", action: nil, keyEquivalent: ""))
             return
         } else if services.isEmpty {
             return
         }


        for service in services {
            let title = service.Names.first ?? "Unknown"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

            // Set icon based on state AND health string
            if service.Status.contains("(healthy)") && service.State == "running" {
                 item.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Healthy")
                 item.toolTip = "Healthy"
            } else if service.State.contains("starting") || service.Status.contains("starting") {
                 item.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: "Starting")
                 item.toolTip = "Starting"
            } else if service.State == "running" && !service.Status.contains("(healthy)") {
                // Running but not healthy (e.g., unhealthy check, restarting)
                 item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Unhealthy")
                 item.toolTip = service.Status // Show the actual status string
             } else { // Exited, Created, Degraded etc.
                 item.image = NSImage(systemSymbolName: "xmark.octagon.fill", accessibilityDescription: "Stopped/Error")
                 item.toolTip = service.Status.isEmpty ? service.State : service.Status
            }
            submenu.addItem(item)
        }
    }

    func updateLogsSubmenu(with services: [PodmanContainer]) {
         guard let submenu = logsMenuItem?.submenu else { return }
         submenu.removeAllItems()

         // Filter for services that are likely running or starting
         let activeServices = services.filter { $0.State == "running" || $0.State.contains("starting") }

         if activeServices.isEmpty {
             submenu.addItem(NSMenuItem(title: "No running services", action: nil, keyEquivalent: ""))
             return
         }

         for service in activeServices {
             let containerName = service.Names.first ?? "Unknown"
             let logsItem = NSMenuItem(title: "Logs: \(containerName)", action: #selector(viewLogsClicked(_:)), keyEquivalent: "")
             logsItem.target = self
             logsItem.representedObject = containerName
             submenu.addItem(logsItem)
         }
    }


    // --- Action Methods ---
    @objc func startStackClicked() {
         print("DEBUG: Start Stack button clicked.")
         stackManager.startStack()
     }

     @objc func stopStackClicked() {
         print("DEBUG: Stop Stack button clicked.")
         stackManager.stopStack()
     }

    @objc func openJaeger() {
        print("DEBUG: Open Jaeger clicked.")
        guard let url = URL(string: "http://localhost:16686") else { return }
        NSWorkspace.shared.open(url)
    }

    // --- 4. Add openGrafana action ---
    @objc func openGrafana() {
        print("DEBUG: Open Grafana clicked.")
        guard let url = URL(string: "http://localhost:3000") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func openPreferences() {
        print("DEBUG: Open Preferences clicked.")

        // --- START NEW MANUAL WINDOW LOGIC ---
        // 1. Check if the window already exists and bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            print("DEBUG: Settings window already open, bringing to front.")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 2. Create the SwiftUI Settings View
        let settingsView = SettingsView()

        // 3. Create a Hosting Controller
        let hostingController = NSHostingController(rootView: settingsView)

        // 4. Create a new NSWindow
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Aleutian Preferences"
        window.styleMask = [.titled, .closable] // Standard window style
        window.isReleasedWhenClosed = false // Important: Keep window in memory until we nil it out
        window.center() // Center it on screen

        // 5. Set a delegate to clear our reference when the window is closed
        let delegate = WindowDelegate { [weak self] in
            print("DEBUG: Settings window closed.")
            self?.settingsWindow = nil // Clear the reference
        }
        window.delegate = delegate
        objc_setAssociatedObject(window, "WindowDelegateKey", delegate, .OBJC_ASSOCIATION_RETAIN)


        // 6. Store the reference and show the window
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil) // Show the window
        print("DEBUG: Created and showed new settings window.")

        // 7. Activate the app to ensure the new window gets focus
        NSApp.activate(ignoringOtherApps: true)
    }

     @objc func viewLogsClicked(_ sender: NSMenuItem) {
         if let serviceTitle = sender.representedObject as? String {
              // Find the corresponding PodmanContainer
              if let container = stackManager.services.first(where: { $0.Names.first == serviceTitle }) {
                  print("DEBUG: View Logs clicked for service '\(serviceTitle)', container ID '\(container.id)'.")
                  // Pass the container ID (which is derived from Names.first)
                  stackManager.streamLogs(for: container.id)
              } else {
                  print("ERROR: Could not find container details for service \(serviceTitle)")
              }
          }
     }
    
    @objc func viewAllStatsClicked() {
        print("DEBUG: View All Stats clicked.")
        stackManager.openAllStats()
    }

     func menuNeedsUpdate(_ menu: NSMenu) {
          print("DEBUG: menuNeedsUpdate called for \(menu.title)")
     }

    func applicationWillTerminate(_ notification: Notification) {
        print("DEBUG: applicationWillTerminate - Removing status item.")
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        // stackManager cleanup happens in its deinit
        cancellables.forEach { $0.cancel() } // Cancel Combine subscriptions
        print("DEBUG: applicationWillTerminate - Cleanup complete.")
    }

    deinit {
        // This might not get called reliably for AppDelegate in modern SwiftUI apps,
        // but good practice to include.
        print("DEBUG: AppDelegate deinit.")
        cancellables.forEach { $0.cancel() }
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init() // Need to call super.init()
    }
    func windowWillClose(_ notification: Notification) {
        onClose()
        // Clean up the associated object to break potential retain cycles
        if let window = notification.object as? NSWindow {
             objc_setAssociatedObject(window, "WindowDelegateKey", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
