package com.iml1s.xmrigminer.data.model

import kotlinx.serialization.Serializable

@Serializable
data class MiningConfig(
    val poolUrl: String = "pool.supportxmr.com:3333",
    val walletAddress: String = "",
    val workerName: String = "android",
    val threads: Int = Runtime.getRuntime().availableProcessors() - 1,
    val maxCpuUsage: Int = 75,
    val useTls: Boolean = true,
    val autoReconnect: Boolean = true,
    val mineWhenScreenOff: Boolean = false,
    val donateLevel: Int = 1,  // 捐贈 1%
    val customArgs: String = "",
    val retries: Int = 5,
    val retryPause: Int = 5,
    val printTime: Int = 60
) {
    fun toJson(): String {
        return """
        {
            "autosave": false,
            "cpu": {
                "enabled": true,
                "max-threads-hint": $maxCpuUsage,
                "priority": 1,
                "asm": true,
                "argon2-impl": "auto"
            },
            "pools": [
                {
                    "url": "$poolUrl",
                    "user": "$walletAddress",
                    "pass": "$workerName",
                    "keepalive": true,
                    "tls": $useTls
                }
            ],
            "donate-level": 1,
            "log-file": null,
            "print-time": $printTime,
            "health-print-time": $printTime,
            "retries": $retries,
            "retry-pause": $retryPause,
            "api": null,
            "http": null
        }
        """.trimIndent()
    }

    fun isValid(): Boolean {
        return walletAddress.isNotBlank() && 
               poolUrl.isNotBlank() &&
               threads > 0 &&
               maxCpuUsage in 10..100
    }
}
