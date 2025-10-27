//
//  AleutianControlPanelApp.swift
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
import SwiftData

@main
struct AleutianControlPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate


    var body: some Scene {
        Settings{
            SettingsView()
        }
    }
}
//
//class AppDelegate: NSObject, NSApplicationDelegate {
//    var statusItem: NSStatusItem?
//    var stackManager = StackManager()
//    
//    
//    func applicationDidFinishLaunching(_ notification: Notification) {
//        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
//        if let button = statusItem?.button {
//            if let image = NSImage(named: "icon-stopped") {
//                image.isTemplate = true
//                button.image = image
//            }
//        }
//        
//        let minMenuWidth: CGFloat = 280
//        let minMenuHeight: CGFloat = 200
//        
//        // Build the menu
//        let menu = NSMenu()
//        let menuItem = NSMenuItem()
//        
//        // 1. Create the SwiftUI view with minimum size constraints
//        let menuView = MainMenuView()
//            .environmentObject(stackManager)
//            .frame(minWidth: minMenuWidth, minHeight: minMenuHeight) // Give SwiftUI constraints
//
//        // 2. Create the NSHostingController
//        let hostingController = NSHostingController(rootView: menuView)
//
//        // 3. Get the controller's view
//        let view = hostingController.view
//
//        // 4. Force the view to calculate its layout immediately
//        view.layoutSubtreeIfNeeded() // Force layout NOW
//
//        // 5. Get the calculated size *after* forcing layout
//        let calculatedSize = view.fittingSize
//        print("DEBUG: Calculated fittingSize: \(calculatedSize)") // Log the size
//
//        // 6. Ensure the calculated size isn't zero
//        let finalSize = CGSize(
//            width: max(calculatedSize.width, minMenuWidth), // Use calculated or min width
//            height: max(calculatedSize.height, 1) // IMPORTANT: Ensure height is at least 1
//        )
//        print("DEBUG: Final size being set: \(finalSize)") // Log the final size
//
//        // 7. Set the view's frame *before* assigning it to the menu item
//        view.frame = NSRect(origin: .zero, size: finalSize)
//
//        // 8. NOW assign the correctly-sized view to the menu item
//        menuItem.view = view
//        
//        menu.addItem(menuItem)
//        statusItem?.menu = menu
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            self.stackManager.startMonitoring()
//        }
//    }
//    func applicationWillTerminate(_ notification: Notification) {
//        print("DEBUG: applicationWillTerminate - Removing status item.")
//        if let statusItem = statusItem {
//            NSStatusBar.system.removeStatusItem(statusItem)
//        }
//        self.statusItem = nil
//    }
//
//    deinit {
//        print("DEBUG: AppDelegate deinit.")
//    }
//}
