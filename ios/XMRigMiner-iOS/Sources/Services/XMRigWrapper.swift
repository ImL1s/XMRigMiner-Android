//
//  XMRigWrapper.swift
//  XMRigMiner-iOS
//
//  Swift wrapper for XMRig C++ library
//

import Foundation
import Combine
import UIKit

/// Mining statistics model
struct MiningStats: Equatable {
    var hashrate10s: Double = 0
    var hashrate60s: Double = 0
    var hashrate15m: Double = 0
    var totalHashes: UInt64 = 0
    var acceptedShares: UInt64 = 0
    var rejectedShares: UInt64 = 0
    var isMining: Bool = false
    var threads: Int = 0
}

/// Swift wrapper for XMRig native library
@MainActor
class XMRigWrapper: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var stats = MiningStats()
    @Published private(set) var isRunning = false
    @Published private(set) var version: String = "6.25.0"
    @Published private(set) var logs: [String] = []
    
    // MARK: - Private Properties
    
    private var statsTimer: Timer?
    private let bridge: XMRigBridge
    private let maxLogLines = 1000
    
    // MARK: - Initialization
    
    init() {
        bridge = XMRigBridge.shared()
        version = bridge.getVersion()
        
        // Use Caches directory for temporary config files
        if let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path {
            bridge.setStoragePath(cachesPath)
        }
        
        setupLogCallback()
        
        // Write a test file immediately to verify devicectl access
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let bootFile = docs.appendingPathComponent("BOOT_SUCCESS.txt")
            try? "APP STARTED AT \(Date())".write(to: bootFile, atomically: true, encoding: .utf8)
        }
        
        // [E2E] Auto-Pilot: Start mining automatically for hands-free verification
        self.appendLog("[XMRigWrapper v8] Enabling Auto-Pilot...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            self.appendLog("[XMRigWrapper] CHECKPOINT 1: DispatchQueue fired")
            
            // 1. Set Storage Path
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
            self.appendLog("[XMRigWrapper] CHECKPOINT 2: Setting storage path to: \(documentsPath)")
            self.bridge.setStoragePath(documentsPath)
            
            // 2. Create Config
            let pool = "gulf.moneroocean.stream:10128"
            let user = "48AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnCxtls"
            self.appendLog("[XMRigWrapper] CHECKPOINT 3: Config created - pool: \(pool)")
            
            let config = self.createConfig(pool: pool, user: user)
            
            self.appendLog("[XMRigWrapper] CHECKPOINT 4: About to call toJSON")
            guard let jsonConfig = config.toJSON() else {
                self.appendLog("[XMRigWrapper] CHECKPOINT 4a: toJSON returned nil!")
                return
            }
            self.appendLog("[XMRigWrapper] CHECKPOINT 5: JSON config length: \(jsonConfig.count)")
            
            // 3. Initialize Bridge
            self.appendLog("[XMRigWrapper] CHECKPOINT 6: About to call initialize")
            let initResult = self.bridge.initialize(withConfig: jsonConfig)
            self.appendLog("[XMRigWrapper] CHECKPOINT 7: initialize returned \(initResult)")
            
            if !initResult {
                self.appendLog("[XMRigWrapper] CHECKPOINT FAIL: Initialize failed")
            }
            
            
            // 5. Start Mining
            self.appendLog("[XMRigWrapper] CHECKPOINT 8: About to call startMining")
            let startResult = self.bridge.startMining()
            self.appendLog("[XMRigWrapper] CHECKPOINT 9: startMining returned \(startResult)")
            
            if startResult {
                self.isRunning = true
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Initialize miner with configuration
    func initialize(config: MiningConfig) -> Bool {
        guard let jsonConfig = config.toJSON() else { return false }
        return bridge.initialize(withConfig: jsonConfig)
    }
    
    /// Start mining
    func start() {
        guard bridge.startMining() else { return }
        isRunning = true
        startStatsTimer()
    }
    
    /// Stop mining
    func stop() {
        bridge.stopMining()
        isRunning = false
        stopStatsTimer()
    }
    
    /// Set number of mining threads
    func setThreads(_ count: Int) {
        bridge.setThreads(Int32(count))
    }
    
    /// Cleanup resources
    func cleanup() {
        stop()
        bridge.cleanup()
        logs.removeAll()
    }
    
    /// Clear logs
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func createConfig(pool: String, user: String) -> MiningConfig {
        var config = MiningConfig()
        config.pool = PoolConfig(url: pool, user: user)
        config.threads = 0 // Auto
        return config
    }
    
    private func setupLogCallback() {
        bridge.logCallback = { [weak self] line in
            Task { @MainActor in
                self?.handleLogLine(line)
            }
        }
    }
    
    private func handleLogLine(_ line: String) {
        // Add to logs (keep limited)
        logs.append(line)
        if logs.count > maxLogLines {
            logs.removeFirst()
        }
        
        // Export logs immediately for evidence capture
        exportLogs()
        
        // Parse the line for stats
        bridge.updateStats(fromLogLine: line)
    }
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }
    
    private func writeVerificationFile() {
        let fileManager = FileManager.default
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = docs.appendingPathComponent("VERIFICATION_SUCCESS.txt")
        
        if fileManager.fileExists(atPath: fileURL.path) { return }
        
        let content = "VERIFIED: Mining is active. Hashrate: \(stats.hashrate10s) H/s. Time: \(Date())"
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("[TEST] Verification file written to: \(fileURL.path)")
        
        // [E2E] Capture evidence for observation
        captureScreenshot()
        exportLogs()
    }

    private func captureScreenshot() {
        print("[TEST] Capturing screenshot for observation...")
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .filter({ $0.isKeyWindow }).first else {
                print("[TEST] Failed to find key window for screenshot.")
                return
            }
            
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { context in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            
            if let data = image.pngData(),
               let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = docs.appendingPathComponent("E2E_SCREENSHOT.png")
                try? data.write(to: fileURL)
                print("[TEST] Screenshot saved to: \(fileURL.path)")
            }
        }
    }
    
    private func appendLog(_ message: String) {
        Task { @MainActor in
            self.handleLogLine(message)
        }
    }
    
    private func exportLogs() {
        let content = logs.joined(separator: "\n")
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent("E2E_MINING_LOGS.txt")
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateStats() {
        guard let statsDict = bridge.getStats() as? [String: Any] else { return }
        
        let newStats = MiningStats(
            hashrate10s: statsDict["hashrate_10s"] as? Double ?? 0,
            hashrate60s: statsDict["hashrate_60s"] as? Double ?? 0,
            hashrate15m: statsDict["hashrate_15m"] as? Double ?? 0,
            totalHashes: statsDict["total_hashes"] as? UInt64 ?? 0,
            acceptedShares: statsDict["accepted_shares"] as? UInt64 ?? 0,
            rejectedShares: statsDict["rejected_shares"] as? UInt64 ?? 0,
            isMining: statsDict["is_mining"] as? Bool ?? false,
            threads: statsDict["threads"] as? Int ?? 0
        )
        
        // Only update if changed to reduce UI updates
        if newStats != stats {
            stats = newStats
            
            // [E2E] Write verification file if we have a valid hashrate
            if stats.hashrate10s > 0 {
                writeVerificationFile()
            }
        }
        
        // Update isRunning from stats
        isRunning = newStats.isMining
    }
}
