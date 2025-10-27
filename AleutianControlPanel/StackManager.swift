//
//  StackManager.swift
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
import AppKit
import SwiftUI

struct PodmanContainer: Codable, Identifiable {
    var id: String { Names.first ?? "" }
    let Names: [String]
    let State: String
    let Status: String
}

struct CommandResult {
    let stdout: String?
    let stderr: String?
    let exitCode: Int32
}

@MainActor
class StackManager: ObservableObject {
    @Published var stackStatus: StackState = .stopped
    @Published var services: [PodmanContainer] = []
    
    private var timer: AnyCancellable?
    private var openLogWindows = [String: NSWindow]()
    private var windowDelegates = [String: WindowDelegate]()
    private var activeStreamers = [String: LogStreamer]()
    
    deinit {
        print("DEBUG: StackManager deinit - Cancelling timer.")
        timer?.cancel()
    }
    
    enum StackState: Equatable {
        case stopped
        case starting
        case running
        case error(String)
    }
    func startMonitoring() {
        // checks the status and starts a timer
        Task {
            await checkStackStatus()
        }
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkStackStatus()
                }
            }
    }
    
    @MainActor
    func checkStackStatus() async {
        let result = await runCommand(
            command: "podman",
            args: ["ps", "-a", "--filter", "network=aleutian-network", "--format", "json"]
        )
        
        guard result.exitCode == 0 else {
            // Command failed
            let errorDetails = result.stderr ?? (result.exitCode == -1 ? "Process launch failed" : "No error output")
            let message = "Podman check failed (Code: \(result.exitCode)). Error: \(errorDetails)"
            self.stackStatus = .error(message) // Display detailed error
            self.services = []
            print("ERROR in checkStackStatus: \(message)")
            return
        }

        guard let output = result.stdout, !output.isEmpty, // Check output not empty
              let data = output.data(using: .utf8) else {
            // Command succeeded but output was empty or nil
            // Check if containers are actually running - maybe the filter is wrong?
             let allContainersResult = await runCommand(command: "podman", args: ["ps", "-a", "--format", "json"])
             if allContainersResult.exitCode == 0 && allContainersResult.stdout?.contains("Names") == true {
                 // Podman works, containers exist, but none match the network filter. Treat as stopped.
                 self.stackStatus = .stopped
                 self.services = []
                 print("INFO in checkStackStatus: Podman ps successful, but no containers found for network 'aleutian-network'.")
             } else {
                 // Podman seems broken or empty output is unexpected
                 self.stackStatus = .error("Podman check returned empty status (Code: \(result.exitCode)).")
                 self.services = []
                 print("ERROR in checkStackStatus: Podman ps returned empty stdout.")
             }
            return
        }
            
        do {
            let containers = try JSONDecoder().decode([PodmanContainer].self, from: data)
            self.services = containers
            if containers.isEmpty {
                self.stackStatus = .stopped
            } else if containers.allSatisfy({ $0.State == "running" && $0.Status.contains("(healthy)") }) {
                self.stackStatus = .running
            } else if containers.contains(where: { $0.State.contains("starting") }) {
                self.stackStatus = .starting
            } else {
                // TODO: enhance for edge cases.
                self.stackStatus = .running
            }
        } catch {
            self.stackStatus = .error("Failed to parse Podman status: \(error.localizedDescription)")
            self.services = []
            print("ERROR: Failed to decode Podman JSON: \(error)") // Add log
            print("--- Received Output ---")
            print(output) // Print the invalid output
            print("-----------------------")
        }
    }
    
    func openStats(for serviceName: String) {
        // open a new terminal to continuously stream stats
        let cmd = "podman stats \(serviceName)"
        
        // tell the terminal to run the command
        let script = """
            tell application "Terminal"
                activate
                do script "\(cmd)"
            end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
        if let error = error {
            print("Applescript error \(error)")
        }
        
    }
    
    func startStack() {
        self.stackStatus = .starting
        Task(priority: .background) {
            let result = await runCommand( // Now returns CommandResult
                command: "aleutian",
                args: ["stack", "start"]
            )
            print("--- 'aleutian stack start' Result ---")
            print("Exit Code: \(result.exitCode)")
            print("Stdout:\n\(result.stdout ?? "<empty>")")
            print("Stderr:\n\(result.stderr ?? "<empty>")")
            print("-------------------------------------")
    
            // FIX: Check if the command succeeded
            if result.exitCode == 0 {
                print("'aleutian stack start' reported success (Code 0). Checking status...")
                await checkStackStatus()
            } else {
                // If failed, show the error in the UI
                // Need @MainActor because we're updating @Published var
                await MainActor.run {
                    let errorMsg = result.stderr?.isEmpty == false ? result.stderr! : "Failed to start stack. Unknown error (Code: \(result.exitCode))."
                    print("Error during 'aleutian stack start': \(errorMsg)")
                    self.stackStatus = .error(result.stderr ?? "Failed to start stack. Unknown error.")
                }
            }
        }
    }
    
    func stopStack() {
        Task(priority: .background) {
            _ = await runCommand(
                command: "aleutian",
                args: ["stack", "stop"]
            )
            await checkStackStatus()
        }
    }
    
    private func runCommand(command: String, args: [String]) async -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let commandString = ([command] + args).joined(separator: " ")
        var environment = ProcessInfo.processInfo.environment
        let newPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = newPath
        process.environment = environment
        process.arguments = ["-c", commandString] // Use ["-c", commandString], remove "-l"

        print("--- Running Command ---")
        print("Executable: /bin/zsh")
        print("Arguments: -c \"\(commandString)\"")
        print("PATH: \(newPath)")

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var resultStdout: String? = nil
        var resultStderr: String? = nil
        var exitCode: Int32 = -1
        let timeoutSeconds: Double = 30.0

        // Define the result type for the TaskGroup
        enum RaceOutcome {
            case completed(Int32) // Process finished with exit code
            case timedOut
        }

        do {
            print("Attempting to launch process...")
            try process.run()
            print("Process launched successfully with PID: \(process.processIdentifier)")

            // --- START REVISED TIMEOUT LOGIC V2 ---
            let outcome: RaceOutcome = await withTaskGroup(of: RaceOutcome.self) { group in
                // Task 1: Wait for process exit
                group.addTask {
                    return await withCheckedContinuation { continuation in
                        process.terminationHandler = { process in
                            continuation.resume(returning: .completed(process.terminationStatus))
                        }
                        // Double-check if already terminated
                         if !process.isRunning {
                             continuation.resume(returning: .completed(process.terminationStatus))
                         }
                    }
                }

                // Task 2: Sleep for timeout
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    // If sleep finishes, return timedOut, but only if Task 1 hasn't already completed
                    return .timedOut
                }

                // Await the first result
                let firstResult = await group.next()!
                // Cancel the other task
                group.cancelAll()
                return firstResult // Return .completed(exitCode) or .timedOut
            }
            // --- END REVISED TIMEOUT LOGIC V2 ---

            // Read pipes *after* the race is decided
            print("Process finished or timed out. Reading pipes...")
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            resultStdout = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            resultStderr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Pipe reading complete.")

            switch outcome {
            case .timedOut:
                print("!!! Command timed out after \(timeoutSeconds) seconds: \(commandString)")
                if process.isRunning {
                    process.terminate() // Force kill
                }
                // Give a moment for termination if needed
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
                exitCode = -99 // Use special code for timeout
                resultStderr = (resultStderr ?? "") + "\nError: Command timed out."
                print("Process terminated with exit code: \(exitCode) (Timeout)")

            case .completed(let status):
                exitCode = status
                print("Process terminated with exit code: \(exitCode)")
            }

            // --- (stderr/stdout logging remains the same) ---
            if let errorOutput = resultStderr, !errorOutput.isEmpty {
                print("--- DEBUG (stderr) ---")
                print(errorOutput)
                print("----------------------")
            }
            if let stdOutput = resultStdout, !stdOutput.isEmpty {
                 print("--- DEBUG (stdout) ---")
                 print(stdOutput)
                 print("----------------------")
            } else if exitCode == 0 {
                 print("--- DEBUG (stdout) ---")
                 print("(stdout was empty, command successful)")
                 print("----------------------")
            }

        } catch {
            // --- (Catch block remains the same) ---
            print("!!! Failed to launch zsh !!! Error: \(error)")
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOnLaunch = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            resultStderr = "Launch Error: \(error.localizedDescription)."
            if let specificError = errorOnLaunch, !specificError.isEmpty {
                 resultStderr? += " Stderr: \(specificError)"
                 print("--- DEBUG (stderr on LAUNCH failure) ---")
                 print(specificError)
                 print("----------------------------------------")
            }
            exitCode = -1
        }

        process.terminationHandler = nil // Clear handler

        return CommandResult(stdout: resultStdout, stderr: resultStderr, exitCode: exitCode)
    }
    
    func streamLogs(for serviceName: String) {
        if let existingWindow = openLogWindows[serviceName] {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let streamer = LogStreamer(serviceName: serviceName)
        activeStreamers[serviceName] = streamer
        
        let logView = LogWindowView(streamer: streamer)
        
        let hostingController = NSHostingController(rootView: logView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Logs: \(serviceName)"
        window.isReleasedWhenClosed = false
        
        let delegate = WindowDelegate { [weak self] in
            self?.openLogWindows.removeValue(forKey: serviceName)
            self?.windowDelegates.removeValue(forKey: serviceName)
            self?.activeStreamers[serviceName]?.stopStreaming()
            self?.activeStreamers.removeValue(forKey: serviceName)
        }
        window.delegate = delegate
        
        self.openLogWindows[serviceName] = window
        self.windowDelegates[serviceName] = delegate
        
        window.makeKeyAndOrderFront(nil)
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
