package com.iml1s.xmrigminer.service

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dev Fee Manager - 1% mining fee to support development
 *
 * Implements time-based fee: mines to dev address for 1% of total time
 * Every 100 seconds of mining = 1 second to dev address
 */
object DevFeeManager {
    // Developer wallet address (1% fee)
    const val DEV_WALLET = "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC"
    const val DEV_WORKER = "devfee"

    // Fee percentage (1%)
    private const val FEE_PERCENT = 1.0
    private const val FEE_CYCLE_SECONDS = 6000L // 100 minutes cycle
    private const val FEE_DURATION_SECONDS = 60L // 1 minute dev mining per cycle (1%)

    private val _isDevFeeMining = MutableStateFlow(false)
    val isDevFeeMining: StateFlow<Boolean> = _isDevFeeMining

    private var feeJob: Job? = null
    private var userWallet: String = ""
    private var onWalletSwitch: ((String, String) -> Unit)? = null

    /**
     * Start the dev fee cycle
     * @param userWalletAddress User's wallet address
     * @param onSwitch Callback when switching wallet (newWallet, newWorker)
     */
    fun start(userWalletAddress: String, onSwitch: (String, String) -> Unit) {
        userWallet = userWalletAddress
        onWalletSwitch = onSwitch

        feeJob?.cancel()
        feeJob = CoroutineScope(Dispatchers.Default).launch {
            while (isActive) {
                // Mine to user wallet for 99% of time
                _isDevFeeMining.value = false
                onWalletSwitch?.invoke(userWallet, "android")
                delay((FEE_CYCLE_SECONDS - FEE_DURATION_SECONDS) * 1000)

                // Mine to dev wallet for 1% of time
                _isDevFeeMining.value = true
                onWalletSwitch?.invoke(DEV_WALLET, DEV_WORKER)
                delay(FEE_DURATION_SECONDS * 1000)
            }
        }
    }

    /**
     * Stop the dev fee cycle
     */
    fun stop() {
        feeJob?.cancel()
        feeJob = null
        _isDevFeeMining.value = false
    }

    /**
     * Check if currently mining to dev address
     */
    fun isDevMining(): Boolean = _isDevFeeMining.value

    /**
     * Get current effective wallet (user or dev)
     */
    fun getCurrentWallet(): String {
        return if (_isDevFeeMining.value) DEV_WALLET else userWallet
    }

    /**
     * Calculate dev fee amount from total mined
     */
    fun calculateDevFee(totalMined: Double): Double {
        return totalMined * (FEE_PERCENT / 100.0)
    }
}
