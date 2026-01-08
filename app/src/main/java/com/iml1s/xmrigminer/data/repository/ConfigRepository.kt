package com.iml1s.xmrigminer.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.iml1s.xmrigminer.data.model.MiningConfig
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "mining_config")

@Singleton
class ConfigRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private object Keys {
        val POOL_URL = stringPreferencesKey("pool_url")
        val WALLET_ADDRESS = stringPreferencesKey("wallet_address")
        val WORKER_NAME = stringPreferencesKey("worker_name")
        val THREADS = intPreferencesKey("threads")
        val MAX_CPU_USAGE = intPreferencesKey("max_cpu_usage")
        val USE_TLS = booleanPreferencesKey("use_tls")
        val AUTO_RECONNECT = booleanPreferencesKey("auto_reconnect")
        val MINE_WHEN_SCREEN_OFF = booleanPreferencesKey("mine_when_screen_off")
    }

    fun getConfig(): Flow<MiningConfig> = context.dataStore.data.map { prefs ->
        MiningConfig(
            poolUrl = prefs[Keys.POOL_URL] ?: "gulf.moneroocean.stream:10128",
            walletAddress = prefs[Keys.WALLET_ADDRESS] ?: "8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC",
            workerName = prefs[Keys.WORKER_NAME] ?: "android",
            threads = prefs[Keys.THREADS] ?: (Runtime.getRuntime().availableProcessors() - 1),
            maxCpuUsage = prefs[Keys.MAX_CPU_USAGE] ?: 75,
            useTls = prefs[Keys.USE_TLS] ?: true,
            autoReconnect = prefs[Keys.AUTO_RECONNECT] ?: true,
            mineWhenScreenOff = prefs[Keys.MINE_WHEN_SCREEN_OFF] ?: false
        )
    }

    suspend fun saveConfig(config: MiningConfig) {
        context.dataStore.edit { prefs ->
            prefs[Keys.POOL_URL] = config.poolUrl
            prefs[Keys.WALLET_ADDRESS] = config.walletAddress
            prefs[Keys.WORKER_NAME] = config.workerName
            prefs[Keys.THREADS] = config.threads
            prefs[Keys.MAX_CPU_USAGE] = config.maxCpuUsage
            prefs[Keys.USE_TLS] = config.useTls
            prefs[Keys.AUTO_RECONNECT] = config.autoReconnect
            prefs[Keys.MINE_WHEN_SCREEN_OFF] = config.mineWhenScreenOff
        }
    }

    suspend fun clear() {
        context.dataStore.edit { it.clear() }
    }
}
