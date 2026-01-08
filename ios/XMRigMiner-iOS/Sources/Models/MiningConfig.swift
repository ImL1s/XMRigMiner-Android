//
//  MiningConfig.swift
//  XMRigMiner-iOS
//
//  Mining configuration model
//

import Foundation

/// Mining pool configuration
struct PoolConfig: Codable {
    var url: String
    var user: String
    var pass: String
    var tls: Bool
    
    init(url: String = "gulf.moneroocean.stream:10128",
         user: String = "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC",
         pass: String = "x",
         tls: Bool = true) {
        self.url = url
        self.user = user
        self.pass = pass
        self.tls = tls
    }
}

/// Complete mining configuration
struct MiningConfig: Codable {
    var pool: PoolConfig
    var threads: Int
    var cpuPriority: Int
    var donateLevel: Int
    
    init(pool: PoolConfig = PoolConfig(),
         threads: Int = 0,
         cpuPriority: Int = 2,
         donateLevel: Int = 1) {
        self.pool = pool
        self.threads = threads
        self.cpuPriority = cpuPriority
        self.donateLevel = donateLevel
    }
    
    /// Convert to XMRig JSON config format
    func toJSON() -> String? {
        let config: [String: Any] = [
            "autosave": true,
            "cpu": [
                "enabled": true,
                "max-threads-hint": threads > 0 ? threads * 25 : 75
            ],
            "donate-level": donateLevel,
            "pools": [
                [
                    "url": pool.url,
                    "user": pool.user,
                    "pass": pool.pass,
                    "tls": pool.tls,
                    "keepalive": true
                ]
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
}

// MARK: - Preset Pools

extension PoolConfig {
    static let supportXMR = PoolConfig(url: "pool.supportxmr.com:3333", tls: true)
    static let moneroOcean = PoolConfig(url: "gulf.moneroocean.stream:10128", tls: true)
    static let hashVault = PoolConfig(url: "pool.hashvault.pro:3333", tls: true)
    static let twoMiners = PoolConfig(url: "xmr.2miners.com:2222", tls: false)
}
