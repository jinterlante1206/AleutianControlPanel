//
//  SettingsView.swift
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

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Aleutian Preferences")
                .font(.largeTitle)
            
            Form {
                Toggle("Launch at login", isOn: .constant(false))
                TextField("Aleutian Binary Path:", text: .constant("/opt/homebrew/bin/aleutian"))
            }
            .padding()
            
            Text("More settings will go here.")
        }
        .padding()
        .frame(minWidth: 450, minHeight: 250)
    }
}
