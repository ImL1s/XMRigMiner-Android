/**
 * Dynamic WebSocket-to-Stratum Proxy Server
 * Bridges browser WebSocket connections to TCP Stratum mining pools
 * Supports dynamic pool selection via login message
 * 
 * Usage: node server.js [port]
 * Default port: 3333
 */

const WebSocket = require('ws');
const net = require('net');

const PORT = process.argv[2] || 3333;

// Pre-configured Monero mining pools
const POOL_PRESETS = {
    'moneroocean': { host: 'gulf.moneroocean.stream', port: 10128, name: 'MoneroOcean' },
    'supportxmr': { host: 'pool.supportxmr.com', port: 3333, name: 'SupportXMR' },
    'hashvault': { host: 'pool.hashvault.pro', port: 3333, name: 'HashVault' },
    '2miners': { host: 'xmr.2miners.com', port: 2222, name: '2Miners' },
};

// Fallback pool order
const FALLBACK_POOLS = ['supportxmr', 'hashvault', '2miners'];

const wss = new WebSocket.Server({ port: PORT });

console.log(`🚀 Dynamic WebSocket-to-Stratum Proxy running on ws://localhost:${PORT}`);
console.log(`📌 Use this URL in the web miner: ws://localhost:${PORT}`);
console.log(`📋 Supported pools: ${Object.keys(POOL_PRESETS).join(', ')}`);
console.log('');

wss.on('connection', (ws, req) => {
    const clientIp = req.socket.remoteAddress;
    console.log(`[${new Date().toISOString()}] Client connected from ${clientIp}`);

    let pool = null;
    let buffer = '';
    let selectedPoolKey = null;
    let fallbackIndex = 0;
    let pendingMessages = [];

    function connectToPool(poolConfig) {
        console.log(`[Pool] Connecting to ${poolConfig.name} (${poolConfig.host}:${poolConfig.port})...`);

        pool = net.createConnection(poolConfig.port, poolConfig.host, () => {
            console.log(`[Pool] ✅ Connected to ${poolConfig.name}`);

            // Send any pending messages
            pendingMessages.forEach(msg => {
                pool.write(msg);
            });
            pendingMessages = [];
        });

        pool.on('data', (data) => {
            buffer += data.toString();

            // Stratum uses newline-delimited JSON
            const lines = buffer.split('\n');
            buffer = lines.pop(); // Keep incomplete line in buffer

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
            // Try fallback pools
            fallbackIndex++;
            if (fallbackIndex < FALLBACK_POOLS.length) {
                const fallbackKey = FALLBACK_POOLS[fallbackIndex];
                console.log(`[Pool] Trying fallback: ${fallbackKey}`);
                setTimeout(() => connectToPool(POOL_PRESETS[fallbackKey]), 1000);
            }
        });

        pool.on('close', () => {
            console.log('[Pool] Connection closed');
        });
    }

    ws.on('message', (message) => {
        try {
            const msg = JSON.parse(message);

            // Check if this is a login message with pool selection
            if (msg.method === 'login' && !pool) {
                const params = msg.params || {};
                const requestedPool = params.pool || 'supportxmr'; // Default pool

                console.log(`[Client] Login request with pool preference: ${requestedPool}`);

                // Get pool config
                let poolConfig = POOL_PRESETS[requestedPool];
                if (!poolConfig) {
                    console.log(`[Pool] Unknown pool "${requestedPool}", using default`);
                    poolConfig = POOL_PRESETS['supportxmr'];
                }

                selectedPoolKey = requestedPool;

                // Connect to the selected pool
                connectToPool(poolConfig);

                // Queue the login message to be sent after connection
                const line = JSON.stringify(msg) + '\n';
                pendingMessages.push(line);
                console.log(`[Client → Pool] (queued) ${line.substring(0, 100)}...`);
            } else {
                const line = JSON.stringify(msg) + '\n';
                console.log(`[Client → Pool] ${line.substring(0, 100)}...`);

                if (pool && !pool.destroyed) {
                    pool.write(line);
                } else {
                    // Queue if not connected yet
                    pendingMessages.push(line);
                }
            }
        } catch (e) {
            console.error('[Client] Invalid JSON:', message);
        }
    });

    ws.on('close', () => {
        console.log(`[${new Date().toISOString()}] Client disconnected`);
        if (pool) {
            pool.destroy();
        }
    });

    ws.on('error', (err) => {
        console.error(`[Client] Error: ${err.message}`);
        if (pool) {
            pool.destroy();
        }
    });
});

console.log('Waiting for connections...');
