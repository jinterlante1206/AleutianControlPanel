//
//  LogStreamer.swift
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

import Foundation
import Combine

@MainActor
class LogStreamer: ObservableObject {
    @Published var logText: String = ""
    let serviceName: String
    private var process: Process?
    private var outputPipe: Pipe?
    
    init(serviceName: String) {
        self.serviceName = serviceName
        self.logText = "Starting log stream for \(serviceName)...\n\n"
        startStreaming()
    }
    
    private func startStreaming() {
        process = Process()
        outputPipe = Pipe()
        
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
            
        // Build the command string
        let commandString = "aleutian stack logs \"\(serviceName)\"" // Added quotes for safety
        
        // Setup the PATH
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process?.environment = env
        
        // Set arguments for zsh
        process?.arguments = ["-c", commandString]
        
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        
        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        
        // handler to marshal new data as it arrives
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                DispatchQueue.main.async {
                    self?.stopStreaming()
                }
            } else if let newText = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.logText += newText
                }
            }
        }
        // clean it up
        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.logText += "\n\nLog stream terminated\n"
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
            }
        }
        do {
            try process?.run()
        } catch {
            logText += "\n\nFailed to start log stream: \(error.localizedDescription)\n"
        }
    }
    func stopStreaming() {
        process?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
    }
}
