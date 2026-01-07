//
//  XMRigWrapper.swift
//  XMRigMiner-iOS
//
//  Swift wrapper for XMRig C++ library
//

import Foundation
import Combine

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
    private let bridge = XMRigBridge.shared()
    private let maxLogLines = 100
    
    // MARK: - Initialization
    
    init() {
        version = bridge?.getVersion() ?? "Unknown"
        setupLogCallback()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Initialize miner with configuration
    func initialize(config: MiningConfig) -> Bool {
        guard let jsonConfig = config.toJSON() else { return false }
        return bridge?.initialize(withConfig: jsonConfig) ?? false
    }
    
    /// Start mining
    func start() {
        guard bridge?.startMining() == true else { return }
        isRunning = true
        startStatsTimer()
    }
    
    /// Stop mining
    func stop() {
        bridge?.stopMining()
        isRunning = false
        stopStatsTimer()
    }
    
    /// Set number of mining threads
    func setThreads(_ count: Int) {
        bridge?.setThreads(Int32(count))
    }
    
    /// Cleanup resources
    func cleanup() {
        stop()
        bridge?.cleanup()
        logs.removeAll()
    }
    
    /// Clear logs
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupLogCallback() {
        bridge?.logCallback = { [weak self] line in
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
        
        // Parse the line for stats
        bridge?.updateStats(fromLogLine: line)
    }
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }
    
    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateStats() {
        guard let statsDict = bridge?.getStats() as? [String: Any] else { return }
        
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
        }
        
        // Update isRunning from stats
        isRunning = newStats.isMining
    }
}
