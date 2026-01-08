/**
 * Dynamic WebSocket-to-Stratum Proxy Server
 * Bridges browser WebSocket connections to TCP Stratum mining pools
 * Supports dynamic pool selection via login message
 *
 * Developer Fee: 1% to support development
 *
 * Usage: node server.js [port]
 * Default port: 3333
 */

const WebSocket = require('ws');
const net = require('net');

const PORT = process.argv[2] || 3333;

// ============================================
// Developer Fee Configuration (1%)
// ============================================
const DEV_FEE = {
    enabled: true,
    percent: 1,
    wallet: '8AfUwcnoJiRDMXnDGj3zX6bMgfaj9pM1WFGr2pakLm3jSYXVLD5fcDMBzkmk4AeSqWYQTA5aerXJ43W65AT82RMqG6NDBnC',
    worker: 'webfee',
    // Time-based: every 100 minutes, mine 1 minute to dev (1%)
    cycleDuration: 6000, // 100 minutes in seconds
    feeDuration: 60,     // 1 minute in seconds
};

// ============================================
// Pool Presets
// ============================================
const POOL_PRESETS = {
    // Monero (XMR) pools
    'moneroocean': { host: 'gulf.moneroocean.stream', port: 10128, name: 'MoneroOcean', coin: 'monero' },
    'supportxmr': { host: 'pool.supportxmr.com', port: 3333, name: 'SupportXMR', coin: 'monero' },
    'hashvault': { host: 'pool.hashvault.pro', port: 3333, name: 'HashVault', coin: 'monero' },
    '2miners': { host: 'xmr.2miners.com', port: 2222, name: '2Miners', coin: 'monero' },

    // Wownero (WOW) pools
    'herominers-wow': { host: 'wownero.herominers.com', port: 1111, name: 'HeroMiners WOW', coin: 'wownero' },
    'moneroocean-wow': { host: 'gulf.moneroocean.stream', port: 10128, name: 'MoneroOcean WOW', coin: 'wownero' },

    // Dero (DERO) nodes
    'dero-official': { host: 'minernode1.dero.io', port: 10100, name: 'DERO Official', coin: 'dero', isDaemon: true },
    'dero-community': { host: 'dero-node.mysrv.cloud', port: 10100, name: 'DERO Community', coin: 'dero', isDaemon: true },
};

// Fallback pool order per coin
const FALLBACK_POOLS = {
    'monero': ['supportxmr', 'hashvault', '2miners'],
    'wownero': ['herominers-wow', 'moneroocean-wow'],
    'dero': ['dero-official', 'dero-community']
};

const wss = new WebSocket.Server({ port: PORT });

console.log(`🚀 XMRig Web Proxy running on ws://localhost:${PORT}`);
console.log(`📌 Use this URL in the web miner: ws://localhost:${PORT}`);
console.log(`💎 Developer fee: ${DEV_FEE.percent}% (supports development)`);
console.log(`📋 Supported pools: ${Object.keys(POOL_PRESETS).join(', ')}`);
console.log('');

wss.on('connection', (ws, req) => {
    const clientIp = req.socket.remoteAddress;
    const connectionTime = Date.now();
    console.log(`[${new Date().toISOString()}] Client connected from ${clientIp}`);

    let pool = null;
    let buffer = '';
    let selectedPoolKey = null;
    let fallbackIndex = 0;
    let pendingMessages = [];
    let isConnecting = false;

    // Dev fee state for this connection
    let userWallet = '';
    let userWorker = '';
    let isDevFeeMining = false;
    let devFeeTimer = null;
    let lastWalletSwitchTime = Date.now();

    // Start dev fee cycle for this connection
    function startDevFeeCycle() {
        if (!DEV_FEE.enabled || !userWallet) return;

        const userDuration = (DEV_FEE.cycleDuration - DEV_FEE.feeDuration) * 1000;
        const devDuration = DEV_FEE.feeDuration * 1000;

        function cycle() {
            // Mine to user for 99% of time
            isDevFeeMining = false;
            console.log(`[DevFee] Mining to user wallet`);

            devFeeTimer = setTimeout(() => {
                // Mine to dev for 1% of time
                isDevFeeMining = true;
                console.log(`[DevFee] 💎 Dev fee period (${DEV_FEE.feeDuration}s)`);

                devFeeTimer = setTimeout(cycle, devDuration);
            }, userDuration);
        }

        cycle();
    }

    function stopDevFeeCycle() {
        if (devFeeTimer) {
            clearTimeout(devFeeTimer);
            devFeeTimer = null;
        }
    }

    // Get current effective wallet (applies dev fee)
    function getEffectiveWallet() {
        if (DEV_FEE.enabled && isDevFeeMining) {
            return DEV_FEE.wallet;
        }
        return userWallet;
    }

    function getEffectiveWorker() {
        if (DEV_FEE.enabled && isDevFeeMining) {
            return DEV_FEE.worker;
        }
        return userWorker;
    }

    function connectToPool(poolConfig) {
        if (isConnecting && pool && !pool.destroyed) {
            console.log('[Pool] Connection already in progress, skipping');
            return;
        }

        isConnecting = true;
        console.log(`[Pool] Connecting to ${poolConfig.name} (${poolConfig.host}:${poolConfig.port})...`);

        pool = net.createConnection(poolConfig.port, poolConfig.host, () => {
            console.log(`[Pool] ✅ Connected to ${poolConfig.name}`);
            isConnecting = false;

            // Send any pending messages
            pendingMessages.forEach(msg => {
                pool.write(msg);
            });
            pendingMessages = [];

            // Start dev fee cycle
            startDevFeeCycle();
        });

        pool.on('data', (data) => {
            buffer += data.toString();

            // Stratum uses newline-delimited JSON
            const lines = buffer.split('\n');
            buffer = lines.pop();

            for (const line of lines) {
                if (line.trim()) {
                    try {
                        const msg = JSON.parse(line);
                        console.log(`[Pool → Client] ${line.substring(0, 120)}...`);
                        ws.send(JSON.stringify(msg));
                    } catch (e) {
                        console.error('[Pool] Invalid JSON:', line);
                    }
                }
            }
        });

        pool.on('error', (err) => {
            console.error(`[Pool] ❌ Error: ${err.message}`);
            isConnecting = false;

            fallbackIndex++;
            if (fallbackIndex < FALLBACK_POOLS.length) {
                const fallbackKey = FALLBACK_POOLS[fallbackIndex];
                console.log(`[Pool] Trying fallback: ${fallbackKey}`);
                setTimeout(() => connectToPool(POOL_PRESETS[fallbackKey]), 1000);
            }
        });

        pool.on('close', () => {
            console.log('[Pool] Connection closed');
            isConnecting = false;
            stopDevFeeCycle();
        });
    }

    ws.on('message', (message) => {
        try {
            const msg = JSON.parse(message);

            // Check if this is a login message with pool selection
            if (msg.method === 'login') {
                const params = msg.params || {};
                const requestedPool = params.pool || 'moneroocean';
                const requestedCoin = params.coin || 'monero';

                // Store user's wallet for dev fee cycling
                userWallet = params.login || '';
                userWorker = params.pass || 'x';

                console.log(`[Client] Login request - Pool: ${requestedPool}, Coin: ${requestedCoin}`);
                console.log(`[Client] User wallet: ${userWallet.substring(0, 20)}...`);

                // Apply dev fee to initial login if in dev period
                if (DEV_FEE.enabled && isDevFeeMining) {
                    msg.params.login = DEV_FEE.wallet;
                    msg.params.pass = DEV_FEE.worker;
                    console.log(`[DevFee] 💎 Initial login uses dev wallet`);
                }

                // Get pool config
                let poolConfig = POOL_PRESETS[requestedPool];
                if (!poolConfig) {
                    console.log(`[Pool] Unknown pool "${requestedPool}", using default for ${requestedCoin}`);
                    const fallbacks = FALLBACK_POOLS[requestedCoin] || FALLBACK_POOLS['monero'];
                    poolConfig = POOL_PRESETS[fallbacks[0]];
                }

                selectedPoolKey = requestedPool;

                // Log coin-specific info
                if (poolConfig.coin === 'wownero') {
                    console.log(`[Pool] 🎉 Mining Wownero (WOW) - Algorithm: rx/wow`);
                } else if (poolConfig.coin === 'dero') {
                    console.log(`[Pool] 🔷 Mining DERO - Algorithm: AstroBWT/v3`);
                } else {
                    console.log(`[Pool] ⛏️ Mining Monero (XMR) - Algorithm: rx/0`);
                }

                if (!pool) {
                    connectToPool(poolConfig);
                    const line = JSON.stringify(msg) + '\n';
                    pendingMessages.push(line);
                    console.log(`[Client → Pool] (queued) ${line.substring(0, 100)}...`);
                } else {
                    const line = JSON.stringify(msg) + '\n';
                    pool.write(line);
                }
            } else {
                const line = JSON.stringify(msg) + '\n';
                console.log(`[Client → Pool] ${line.substring(0, 100)}...`);

                if (pool && !pool.destroyed) {
                    pool.write(line);
                } else {
                    pendingMessages.push(line);
                }
            }
        } catch (e) {
            console.error('[Client] Invalid JSON:', message);
        }
    });

    ws.on('close', () => {
        const sessionDuration = Math.round((Date.now() - connectionTime) / 1000);
        console.log(`[${new Date().toISOString()}] Client disconnected (session: ${sessionDuration}s)`);
        stopDevFeeCycle();
        if (pool) {
            pool.destroy();
        }
    });

    ws.on('error', (err) => {
        console.error(`[Client] Error: ${err.message}`);
        stopDevFeeCycle();
        if (pool) {
            pool.destroy();
        }
    });
});

console.log('Waiting for connections...');
