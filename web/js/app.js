/**
 * XMRig Web Miner - Application Logic
 * Handles UI interactions and miner control.
 */

import Miner from './miner.js';

class App {
    constructor() {
        this.miner = new Miner();
        this.dom = {
            walletAddress: document.getElementById('wallet-address'),
            pool: document.getElementById('pool-url'), // Updated ID
            threads: document.getElementById('threads'),
            workerName: document.getElementById('worker-name'),
            startBtn: document.getElementById('start-btn'),
            stopBtn: document.getElementById('stop-btn'),
            hashrate: document.getElementById('hashrate'),
            hashes: document.getElementById('hashes'),
            shares: document.getElementById('shares'),
            uptime: document.getElementById('uptime'),
            console: document.getElementById('console-output'),
            cpuUsage: document.getElementById('cpu-usage')
        };

        this.init();
    }

    init() {
        // 載入儲存的設定
        this.loadSettings();

        // 綁定按鈕事件
        this.dom.startBtn.addEventListener('click', () => this.startMining());
        this.dom.stopBtn.addEventListener('click', () => this.stopMining());

        // 渲染線程數選項
        this.renderThreadOptions();

        // 設置 Miner 回調
        this.miner.onLog = (msg) => this.log(msg);
        this.miner.onStatsUpdate = (stats) => this.updateUI(stats);

        this.log('Web Miner 就緒 (支援自訂代理)');
    }

    loadSettings() {
        const settings = JSON.parse(localStorage.getItem('xmrig_web_settings') || '{}');
        if (settings.walletAddress) this.dom.walletAddress.value = settings.walletAddress;
        if (settings.pool) this.dom.pool.value = settings.pool;
        if (settings.threads) this.dom.threads.value = settings.threads;
        if (settings.workerName) this.dom.workerName.value = settings.workerName;
    }

    saveSettings() {
        const settings = {
            walletAddress: this.dom.walletAddress.value,
            pool: this.dom.pool.value,
            threads: this.dom.threads.value,
            workerName: this.dom.workerName.value
        };
        localStorage.setItem('xmrig_web_settings', JSON.stringify(settings));
    }

    renderThreadOptions() {
        const cores = navigator.hardwareConcurrency || 4;
        this.dom.threads.innerHTML = '';
        for (let i = 1; i <= cores; i++) {
            const option = document.createElement('option');
            option.value = i;
            option.text = `${i} Threads`;
            if (i === Math.max(1, Math.floor(cores / 2))) option.selected = true;
            this.dom.threads.appendChild(option);
        }
    }

    startMining() {
        const config = {
            walletAddress: this.dom.walletAddress.value.trim(),
            pool: this.dom.pool.value, // Used for display/log if needed
            threads: parseInt(this.dom.threads.value),
            workerName: this.dom.workerName.value.trim() || 'web-worker',
            proxy: this.dom.pool.value.trim() || 'wss://ny1.xmrminingproxy.com' // Use the input value
        };

        if (!config.walletAddress) {
            alert('請輸入錢包地址');
            return;
        }

        if (!config.proxy.startsWith('wss://')) {
            alert('代理地址必須以 wss:// 開頭 (例如: wss://ny1.xmrminingproxy.com)');
            return;
        }

        this.saveSettings();
        this.miner.start(config);

        this.dom.startBtn.disabled = true;
        this.dom.stopBtn.disabled = false;
        this.dom.walletAddress.readOnly = true;
        this.dom.pool.disabled = true;
        this.dom.threads.disabled = true;
    }

    stopMining() {
        this.miner.stop();

        this.dom.startBtn.disabled = false;
        this.dom.stopBtn.disabled = true;
        this.dom.walletAddress.readOnly = false;
        this.dom.pool.disabled = false;
        this.dom.threads.disabled = false;
    }

    updateUI(stats) {
        this.dom.hashrate.textContent = stats.hashrate.toFixed(1);
        this.dom.hashes.textContent = stats.totalHashes;
        this.dom.shares.textContent = `${stats.acceptedShares} / ${stats.rejectedShares}`;
        this.dom.uptime.textContent = this.formatUptime(stats.uptime);

        // 更新進度條
        const progress = (Date.now() % 2000) / 20;
        this.dom.cpuUsage.style.width = stats.isMining ? `${progress}%` : '0%';
    }

    formatUptime(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }

    log(message) {
        const entry = document.createElement('div');
        entry.className = 'console-entry';
        const timestamp = new Date().toLocaleTimeString();
        entry.textContent = `[${timestamp}] ${message}`;
        this.dom.console.appendChild(entry);
        this.dom.console.scrollTop = this.dom.console.scrollHeight;

        // 限制日誌數量
        while (this.dom.console.children.length > 100) {
            this.dom.console.removeChild(this.dom.console.firstChild);
        }
    }
}

// 啟動應用
window.addEventListener('load', () => {
    new App();
});
