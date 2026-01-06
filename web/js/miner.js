/**
 * XMRig Web Miner - Mining Controller
 * Uses randomx.js for RandomX hash calculation
 */

class Miner {
    constructor() {
        this.isRunning = false;
        this.hashCount = 0;
        this.startTime = null;
        this.threads = 1;
        this.hashrate = 0;
        this.acceptedShares = 0;
        this.rejectedShares = 0;
        this.workers = [];
        this.onHashrateUpdate = null;
        this.onLog = null;
        this.onShareAccepted = null;
        this.onShareRejected = null;

        // RandomX 參數
        this.dataset = null;
        this.cache = null;
        this.vm = null;
        this.randomxLoaded = false;
    }

    /**
     * 初始化 RandomX
     */
    async init() {
        try {
            this.log('info', '正在載入 randomx.js...');

            // 動態導入 randomx.js
            // 注意：實際使用時需要安裝 npm 套件
            // import { RandomX } from 'randomx.js';

            // 模擬初始化（實際需要 randomx.js 套件）
            this.log('info', 'RandomX 引擎已就緒 (模擬模式)');
            this.log('warning', '⚠️ 這是展示版本，未連接真實礦池');
            this.randomxLoaded = true;

            return true;
        } catch (error) {
            this.log('error', `初始化失敗: ${error.message}`);
            return false;
        }
    }

    /**
     * 開始挖礦
     */
    async start(config) {
        if (this.isRunning) {
            this.log('warning', '挖礦已在運行中');
            return false;
        }

        const { walletAddress, pool, threads, workerName } = config;

        if (!walletAddress || walletAddress.length < 95) {
            this.log('error', '請輸入有效的 Monero 錢包地址');
            return false;
        }

        this.threads = threads || 1;
        this.isRunning = true;
        this.startTime = Date.now();
        this.hashCount = 0;

        this.log('info', `開始挖礦...`);
        this.log('info', `礦池: ${pool}`);
        this.log('info', `執行緒數: ${this.threads}`);
        this.log('info', `礦工名稱: ${workerName}`);

        // 啟動挖礦循環
        this.startMiningLoop();

        return true;
    }

    /**
     * 挖礦主循環
     */
    startMiningLoop() {
        const mineIteration = () => {
            if (!this.isRunning) return;

            // 模擬挖礦計算
            // 實際需要使用 randomx.js 的 calculateHash
            for (let i = 0; i < this.threads; i++) {
                this.simulateHash();
            }

            // 更新算力
            this.updateHashrate();

            // 繼續下一輪
            if (this.isRunning) {
                setTimeout(mineIteration, 100);
            }
        };

        mineIteration();
    }

    /**
     * 模擬 hash 計算（展示用）
     */
    simulateHash() {
        // 模擬一些計算
        let result = 0;
        for (let i = 0; i < 1000; i++) {
            result += Math.random();
        }
        this.hashCount++;

        // 隨機模擬找到 share
        if (Math.random() < 0.001) {
            this.acceptedShares++;
            if (this.onShareAccepted) {
                this.onShareAccepted(this.acceptedShares);
            }
            this.log('success', `✓ Share 已接受 #${this.acceptedShares}`);
        }
    }

    /**
     * 更新算力統計
     */
    updateHashrate() {
        const elapsed = (Date.now() - this.startTime) / 1000;
        if (elapsed > 0) {
            // 模擬約 15-25 H/s 的算力（符合 randomx.js 的實際效能）
            this.hashrate = (15 + Math.random() * 10) * this.threads;

            if (this.onHashrateUpdate) {
                this.onHashrateUpdate(this.hashrate);
            }
        }
    }

    /**
     * 停止挖礦
     */
    stop() {
        if (!this.isRunning) {
            return false;
        }

        this.isRunning = false;
        this.log('info', '挖礦已停止');

        // 清理 workers
        this.workers.forEach(worker => worker.terminate());
        this.workers = [];

        return true;
    }

    /**
     * 獲取運行時間
     */
    getUptime() {
        if (!this.startTime) return 0;
        return Math.floor((Date.now() - this.startTime) / 1000);
    }

    /**
     * 格式化運行時間
     */
    formatUptime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }

    /**
     * 日誌輸出
     */
    log(level, message) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`);

        if (this.onLog) {
            this.onLog(level, message);
        }
    }

    /**
     * 獲取統計信息
     */
    getStats() {
        return {
            isRunning: this.isRunning,
            hashrate: this.hashrate,
            hashCount: this.hashCount,
            acceptedShares: this.acceptedShares,
            rejectedShares: this.rejectedShares,
            uptime: this.getUptime(),
            threads: this.threads
        };
    }
}

export default Miner;
