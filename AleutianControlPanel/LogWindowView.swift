//
//  LogWindowView.swift
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

struct LogWindowView: View {
    @StateObject var streamer: LogStreamer
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                Text(streamer.logText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("LogText")
                    .onChange(of: streamer.logText) {
                        proxy.scrollTo("LogText", anchor: .bottom)
                    }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onDisappear {
            streamer.stopStreaming()
        }
    }
}
