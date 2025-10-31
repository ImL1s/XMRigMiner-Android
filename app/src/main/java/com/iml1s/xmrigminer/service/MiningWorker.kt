package com.iml1s.xmrigminer.service

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.ForegroundInfo
import androidx.core.app.NotificationCompat
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import timber.log.Timber
import java.io.File
import com.iml1s.xmrigminer.data.repository.ConfigRepository
import com.iml1s.xmrigminer.data.repository.StatsRepository
import com.iml1s.xmrigminer.R
import android.os.Process as AndroidProcess

/**
 * 2025 Best Practice: WorkManager 代替 Service
 * - 更好的電池優化
 * - 自動重試機制
 * - 約束條件支持 (Wi-Fi, 充電等)
 */
@HiltWorker
class MiningWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val configRepository: ConfigRepository,
    private val statsRepository: StatsRepository
) : CoroutineWorker(context, params) {

    private var process: Process? = null
    private var outputJob: Job? = null
    private var cpuMonitorJob: Job? = null

    companion object {
        const val WORK_NAME = "mining_work"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "xmrig_mining"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Timber.i("MiningWorker doWork() started")
        try {
            Timber.i("Setting foreground...")
            setForeground(createForegroundInfo())
            Timber.i("Starting mining...")
            startMining()
            Timber.i("Mining completed successfully")
            Result.success()
        } catch (e: Exception) {
            Timber.e(e, "Mining failed")
            Result.retry()
        }
    }

    private suspend fun startMining() {
        Timber.i("startMining() called")
        val config = configRepository.getConfig().first()
        Timber.i("Config loaded: wallet=${config.walletAddress}, pool=${config.poolUrl}")
        
        if (!config.isValid()) {
            val errorMsg = when {
                config.walletAddress.isBlank() -> "錢包地址未設置"
                config.poolUrl.isBlank() -> "礦池地址未設置"
                config.threads <= 0 -> "線程數無效"
                config.maxCpuUsage !in 10..100 -> "CPU使用率設置無效"
                else -> "配置無效"
            }
            Timber.w("Invalid config: $errorMsg")
            throw IllegalStateException(errorMsg)
        }

        // 1. 準備配置文件
        Timber.i("Preparing config file...")
        val configFile = prepareConfigFile(config.toJson())
        
        // 2. 獲取 xmrig 二進制路徑（從 native library）
        Timber.i("Loading binary...")
        val binaryPath = copyBinary()
        
        // 3. 驗證執行權限
        setExecutable(binaryPath)
        
        // 4. 啟動 XMRig
        Timber.i("Starting XMRig process...")
        Timber.i("Binary: $binaryPath")
        Timber.i("Config: ${configFile.absolutePath}")
        Timber.i("Working directory: ${applicationContext.filesDir.absolutePath}")
        
        // 使用命令行參數而不是配置文件
        process = ProcessBuilder(
            binaryPath,
            "-o", config.poolUrl,
            "-u", config.walletAddress,
            "-p", config.workerName,
            "-t", config.threads.toString(),
            "--donate-level=1",
            "--donate-over-proxy=1",
            "--no-color",
            "--print-time=10",  // 每 10 秒輸出統計
            "--log-file=${applicationContext.filesDir.absolutePath}/xmrig.log"
        ).apply {
            directory(applicationContext.filesDir)
            redirectErrorStream(true)
            // 設置 LD_LIBRARY_PATH 讓系統找到 libc++_shared.so
            val libPath = File(binaryPath).parent
            environment()["LD_LIBRARY_PATH"] = libPath
        }.start()

        Timber.i("XMRig process started")

        // 5. 監聽輸出
        outputJob = CoroutineScope(Dispatchers.IO).launch {
            process?.inputStream?.bufferedReader()?.use { reader ->
                reader.lineSequence()
                    .asFlow()
                    .catch { e -> Timber.e(e, "Output read error") }
                    .collect { line ->
                        parseOutputLine(line)
                    }
            }
        }
        
        // 6. 監控 CPU 使用率
        cpuMonitorJob = CoroutineScope(Dispatchers.IO).launch {
            monitorCpuUsage()
        }

        // 等待進程結束
        process?.waitFor()
        Timber.i("XMRig process terminated")
    }

    private fun copyBinary(): String {
        // The xmrig binary is now packaged as a native library (libxmrig.so)
        // Android will automatically install it to the nativeLibraryDir with execute permissions
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
        val binaryPath = File(nativeLibDir, "libxmrig.so").absolutePath
        
        Timber.i("Using native library at: $binaryPath")
        
        // Verify the file exists
        if (!File(binaryPath).exists()) {
            throw IllegalStateException("Native library not found at $binaryPath")
        }
        
        Timber.i("Binary ready at: $binaryPath")
        return binaryPath
    }

    private fun setExecutable(path: String) {
        // Native libraries are automatically set to executable by Android
        // No need to modify permissions
        val file = File(path)
        Timber.i("Binary is executable: ${file.canExecute()}, readable: ${file.canRead()}")
    }

    private fun prepareConfigFile(jsonConfig: String): File {
        return File(applicationContext.filesDir, "config.json").apply {
            writeText(jsonConfig)
            Timber.i("Config file written to $absolutePath")
        }
    }

    private suspend fun parseOutputLine(line: String) {
        Timber.v("XMRig: $line")

        when {
            // 解析接受的 share: "cpu accepted (1/0) diff 75000"
            line.contains("accepted", ignoreCase = true) -> {
                statsRepository.incrementAccepted()
                extractDifficulty(line)?.let { difficulty ->
                    statsRepository.updateDifficulty(difficulty)
                }
            }
            // 解析拒絕的 share
            line.contains("rejected", ignoreCase = true) -> {
                statsRepository.incrementRejected()
            }
            // 解析算力: "speed 10s/60s/15m 123.4 456.7 789.0 H/s max 999.9 H/s"
            line.contains("speed", ignoreCase = true) -> {
                extractHashrate(line)?.let { (h10s, h60s, h15m) ->
                    statsRepository.updateHashrate(h10s, h60s, h15m)
                }
            }
            // 解析難度: "new job from pool diff 75000"  
            line.contains("diff", ignoreCase = true) && line.contains("job", ignoreCase = true) -> {
                extractDifficulty(line)?.let { difficulty ->
                    statsRepository.updateDifficulty(difficulty)
                }
            }
        }
    }

    private fun extractHashrate(line: String): Triple<Double, Double, Double>? {
        // Parse: "speed 10s/60s/15m 316.3 335.9 n/a H/s max 348.0 H/s"
        // Or: "miner    speed 10s/60s/15m 316.3 n/a n/a H/s max 319.9 H/s"
        val regex = """speed\s+10s/60s/15m\s+([\d.]+|n/a)\s+([\d.]+|n/a)\s+([\d.]+|n/a)\s+H/s""".toRegex()
        
        return regex.find(line)?.let { match ->
            val h10s = match.groupValues[1].toDoubleOrNull() ?: 0.0
            val h60s = match.groupValues[2].toDoubleOrNull() ?: 0.0
            val h15m = match.groupValues[3].toDoubleOrNull() ?: 0.0
            
            Timber.d("Extracted hashrate: 10s=$h10s, 60s=$h60s, 15m=$h15m from line: $line")
            Triple(h10s, h60s, h15m)
        }
    }

    private fun extractDifficulty(line: String): Long? {
        // 匹配 "diff 75000" 或 "diff 76680"
        val regex = """diff\s+(\d+)""".toRegex()
        return regex.find(line)?.groupValues?.get(1)?.toLongOrNull()?.also { difficulty ->
            Timber.d("Extracted difficulty: $difficulty from line: $line")
        }
    }
    
    private suspend fun monitorCpuUsage() {
        val pid = AndroidProcess.myPid()
        var lastCpuTime = 0L
        var lastWallTime = 0L
        
        while (currentCoroutineContext().isActive && process?.isAlive == true) {
            try {
                // 讀取 /proc/[pid]/stat 取得 CPU 時間（這個應該是可讀的）
                val statFile = File("/proc/$pid/stat")
                if (statFile.exists() && statFile.canRead()) {
                    val stat = statFile.readText().split(" ")
                    val utime = stat[13].toLong()  // user mode time
                    val stime = stat[14].toLong()  // kernel mode time
                    val currentCpuTime = utime + stime
                    
                    // 使用實際時間而不是系統 CPU 時間
                    val currentWallTime = System.currentTimeMillis()
                    
                    if (lastCpuTime > 0 && lastWallTime > 0) {
                        val cpuTimeDelta = currentCpuTime - lastCpuTime
                        val wallTimeDelta = currentWallTime - lastWallTime
                        
                        if (wallTimeDelta > 0) {
                            // CPU 時間是以 clock ticks 為單位，通常是 1/100 秒
                            // 轉換為毫秒：cpuTimeDelta * 10
                            val cpuMillis = cpuTimeDelta * 10
                            
                            // CPU 使用率 = (CPU 時間 / 實際時間) * 100
                            val cpuUsage = (cpuMillis.toDouble() / wallTimeDelta * 100).toFloat()
                            
                            // 限制在合理範圍內（考慮多核心，最大可能超過100%）
                            val cpuCores = Runtime.getRuntime().availableProcessors()
                            val normalizedUsage = cpuUsage.coerceIn(0f, cpuCores * 100f)
                            statsRepository.updateCpuUsage(normalizedUsage)
                            Timber.d("CPU Usage: %.1f%% (cores: $cpuCores)".format(normalizedUsage))
                        }
                    }
                    
                    lastCpuTime = currentCpuTime
                    lastWallTime = currentWallTime
                } else {
                    Timber.w("Cannot read /proc/$pid/stat, CPU monitoring disabled")
                    return // 如果無法讀取，就停止監控
                }
                
                // 每 5 秒更新一次
                delay(5000)
            } catch (e: Exception) {
                Timber.e(e, "Error monitoring CPU usage")
                delay(5000)
            }
        }
    }

    private fun createForegroundInfo(): ForegroundInfo {
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("XMRig Mining")
            .setContentText("Mining in progress...")
            .setSmallIcon(R.drawable.ic_mining)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            ForegroundInfo(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    private fun stopMining() {
        cpuMonitorJob?.cancel()
        outputJob?.cancel()
        process?.destroy()
        process = null
        Timber.i("Mining stopped")
    }
}
