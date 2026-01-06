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
            poolSelect: document.getElementById('pool-select'),
            customProxyGroup: document.getElementById('custom-proxy-group'),
            customProxyUrl: document.getElementById('custom-proxy-url'),
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

        // 綁定礦池選擇變更事件
        this.dom.poolSelect.addEventListener('change', () => this.onPoolSelectChange());

        // 渲染線程數選項
        this.renderThreadOptions();

        // 設置 Miner 回調
        this.miner.onLog = (msg) => this.log(msg);
        this.miner.onStatsUpdate = (stats) => this.updateUI(stats);

        // 初始化自訂代理顯示狀態
        this.onPoolSelectChange();

        this.log('Web Miner 就緒 (支援多礦池選擇)');
    }

    onPoolSelectChange() {
        const isCustom = this.dom.poolSelect.value === 'custom';
        this.dom.customProxyGroup.style.display = isCustom ? 'block' : 'none';
    }

    loadSettings() {
        const settings = JSON.parse(localStorage.getItem('xmrig_web_settings') || '{}');
        if (settings.walletAddress) this.dom.walletAddress.value = settings.walletAddress;
        if (settings.poolSelect) this.dom.poolSelect.value = settings.poolSelect;
        if (settings.customProxyUrl) this.dom.customProxyUrl.value = settings.customProxyUrl;
        if (settings.threads) this.dom.threads.value = settings.threads;
        if (settings.workerName) this.dom.workerName.value = settings.workerName;
    }

    saveSettings() {
        const settings = {
            walletAddress: this.dom.walletAddress.value,
            poolSelect: this.dom.poolSelect.value,
            customProxyUrl: this.dom.customProxyUrl.value,
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
        const poolSelection = this.dom.poolSelect.value;
        const isCustomProxy = poolSelection === 'custom';

        // Determine proxy URL and pool key
        let proxyUrl, poolKey;
        if (isCustomProxy) {
            proxyUrl = this.dom.customProxyUrl.value.trim();
            poolKey = null; // Custom proxy handles its own pool
        } else {
            // Use local proxy with pool selection
            proxyUrl = 'ws://localhost:3333';
            poolKey = poolSelection;
        }

        const config = {
            walletAddress: this.dom.walletAddress.value.trim(),
            pool: poolKey, // Pool key for server.js to route
            threads: parseInt(this.dom.threads.value),
            workerName: this.dom.workerName.value.trim() || 'web-worker',
            password: this.dom.workerName.value.trim() || 'x',
            proxy: proxyUrl
        };

        if (!config.walletAddress) {
            alert('請輸入錢包地址');
            return;
        }

        if (!config.proxy.startsWith('ws://') && !config.proxy.startsWith('wss://')) {
            alert('代理地址必須以 ws:// 或 wss:// 開頭');
            return;
        }

        this.saveSettings();
        this.log(`使用礦池: ${isCustomProxy ? '自訂代理' : poolSelection}`);
        this.miner.start(config);

        this.dom.startBtn.disabled = true;
        this.dom.stopBtn.disabled = false;
        this.dom.walletAddress.readOnly = true;
        this.dom.poolSelect.disabled = true;
        this.dom.customProxyUrl.disabled = true;
        this.dom.threads.disabled = true;
    }

    stopMining() {
        this.miner.stop();

        this.dom.startBtn.disabled = false;
        this.dom.stopBtn.disabled = true;
        this.dom.walletAddress.readOnly = false;
        this.dom.poolSelect.disabled = false;
        this.dom.customProxyUrl.disabled = false;
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
