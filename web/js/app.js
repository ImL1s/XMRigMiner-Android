/**
 * XMRig Web Miner - Main Application
 */

import Miner from './miner.js';

class App {
    constructor() {
        this.miner = new Miner();
        this.uptimeInterval = null;
        this.init();
    }

    /**
     * 初始化應用
     */
    async init() {
        // 獲取 DOM 元素
        this.elements = {
            statusIndicator: document.getElementById('statusIndicator'),
            statusText: document.getElementById('statusText'),
            hashrateValue: document.getElementById('hashrateValue'),
            acceptedShares: document.getElementById('acceptedShares'),
            rejectedShares: document.getElementById('rejectedShares'),
            uptime: document.getElementById('uptime'),
            walletAddress: document.getElementById('walletAddress'),
            poolSelect: document.getElementById('poolSelect'),
            threadsSlider: document.getElementById('threadsSlider'),
            threadsValue: document.getElementById('threadsValue'),
            workerName: document.getElementById('workerName'),
            startBtn: document.getElementById('startBtn'),
            stopBtn: document.getElementById('stopBtn'),
            logContainer: document.getElementById('logContainer')
        };

        // 綁定事件
        this.bindEvents();

        // 設置 miner 回調
        this.setupMinerCallbacks();

        // 初始化 miner
        await this.miner.init();

        // 載入儲存的設定
        this.loadSettings();

        // 設置最大執行緒數
        const maxThreads = navigator.hardwareConcurrency || 4;
        this.elements.threadsSlider.max = Math.min(maxThreads, 8);

        this.log('info', `檢測到 ${maxThreads} 個 CPU 核心`);
    }

    /**
     * 載入儲存的設定
     */
    loadSettings() {
        const settings = localStorage.getItem('xmrig_web_settings');
        if (settings) {
            try {
                const { walletAddress, pool, threads, workerName } = JSON.parse(settings);
                if (walletAddress) this.elements.walletAddress.value = walletAddress;
                if (pool) this.elements.poolSelect.value = pool;
                if (threads) {
                    this.elements.threadsSlider.value = threads;
                    this.elements.threadsValue.textContent = threads;
                }
                if (workerName) this.elements.workerName.value = workerName;
            } catch (e) {
                console.error('Failed to load settings:', e);
            }
        }
    }

    /**
     * 儲存設定
     */
    saveSettings() {
        const settings = {
            walletAddress: this.elements.walletAddress.value.trim(),
            pool: this.elements.poolSelect.value,
            threads: this.elements.threadsSlider.value,
            workerName: this.elements.workerName.value.trim()
        };
        localStorage.setItem('xmrig_web_settings', JSON.stringify(settings));
    }

    /**
     * 綁定事件處理器
     */
    bindEvents() {
        // 開始按鈕
        this.elements.startBtn.addEventListener('click', () => this.startMining());

        // 停止按鈕
        this.elements.stopBtn.addEventListener('click', () => this.stopMining());

        // 執行緒滑桿
        this.elements.threadsSlider.addEventListener('input', (e) => {
            this.elements.threadsValue.textContent = e.target.value;
        });

        // 錢包地址驗證
        this.elements.walletAddress.addEventListener('input', (e) => {
            const value = e.target.value;
            if (value.length > 0 && !value.startsWith('4')) {
                e.target.style.borderColor = 'var(--danger)';
            } else {
                e.target.style.borderColor = '';
            }
        });
    }

    /**
     * 設置 miner 回調
     */
    setupMinerCallbacks() {
        // 算力更新
        this.miner.onHashrateUpdate = (hashrate) => {
            this.elements.hashrateValue.textContent = hashrate.toFixed(2);
        };

        // 日誌輸出
        this.miner.onLog = (level, message) => {
            this.log(level, message);
        };

        // Share 接受
        this.miner.onShareAccepted = (count) => {
            this.elements.acceptedShares.textContent = count;
        };

        // Share 拒絕
        this.miner.onShareRejected = (count) => {
            this.elements.rejectedShares.textContent = count;
        };
    }

    /**
     * 開始挖礦
     */
    async startMining() {
        const config = {
            walletAddress: this.elements.walletAddress.value.trim(),
            pool: this.elements.poolSelect.value,
            threads: parseInt(this.elements.threadsSlider.value),
            workerName: this.elements.workerName.value.trim() || 'web-miner'
        };

        // 儲存設定
        this.saveSettings();

        const success = await this.miner.start(config);

        if (success) {
            this.updateUIState(true);
            this.startUptimeCounter();
        }
    }

    /**
     * 停止挖礦
     */
    stopMining() {
        this.miner.stop();
        this.updateUIState(false);
        this.stopUptimeCounter();
    }

    /**
     * 更新 UI 狀態
     */
    updateUIState(isMining) {
        if (isMining) {
            this.elements.statusIndicator.classList.add('mining');
            this.elements.statusText.textContent = '挖礦中';
            this.elements.startBtn.disabled = true;
            this.elements.stopBtn.disabled = false;
            this.elements.walletAddress.disabled = true;
            this.elements.poolSelect.disabled = true;
            this.elements.threadsSlider.disabled = true;
            this.elements.workerName.disabled = true;
        } else {
            this.elements.statusIndicator.classList.remove('mining');
            this.elements.statusText.textContent = '已停止';
            this.elements.startBtn.disabled = false;
            this.elements.stopBtn.disabled = true;
            this.elements.walletAddress.disabled = false;
            this.elements.poolSelect.disabled = false;
            this.elements.threadsSlider.disabled = false;
            this.elements.workerName.disabled = false;
            this.elements.hashrateValue.textContent = '0.00';
        }
    }

    /**
     * 開始運行時間計數器
     */
    startUptimeCounter() {
        this.uptimeInterval = setInterval(() => {
            const uptime = this.miner.getUptime();
            this.elements.uptime.textContent = this.miner.formatUptime(uptime);
        }, 1000);
    }

    /**
     * 停止運行時間計數器
     */
    stopUptimeCounter() {
        if (this.uptimeInterval) {
            clearInterval(this.uptimeInterval);
            this.uptimeInterval = null;
        }
    }

    /**
     * 添加日誌
     */
    log(level, message) {
        const entry = document.createElement('div');
        entry.className = `log-entry ${level}`;
        entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;

        this.elements.logContainer.appendChild(entry);
        this.elements.logContainer.scrollTop = this.elements.logContainer.scrollHeight;

        // 限制日誌數量
        while (this.elements.logContainer.children.length > 100) {
            this.elements.logContainer.removeChild(this.elements.logContainer.firstChild);
        }
    }
}

// 初始化應用
document.addEventListener('DOMContentLoaded', () => {
    window.app = new App();
});
