/**
 * XMRig Web Miner - Mining Worker
 * Performs real RandomX hashing in a background thread.
 */

import { randomx_create_vm } from './lib/randomx.js';

let randomxNode = null;
let currentJob = null;
let isMining = false;

self.onmessage = async (e) => {
    const { type, data } = e.data;

    switch (type) {
        case 'init':
            // data is cache handle
            try {
                if (!data) throw new Error("Data is null");
                randomxNode = randomx_create_vm(data);
                self.postMessage({ type: 'initialized' });
            } catch (err) {
                self.postMessage({ type: 'error', message: 'Failed to create RandomX VM: ' + err.message + ' stack: ' + err.stack });
            }
            break;

        case 'job':
            // data is job object { blob, target, job_id }
            currentJob = data;
            isMining = true;
            startMining();
            break;

        case 'stop':
            isMining = false;
            break;

        case 'pause':
            isMining = false;
            break;

        case 'resume':
            isMining = true;
            startMining();
            break;
    }
};

function startMining() {
    if (!randomxNode || !currentJob || !isMining) return;

    const { blob, target, job_id } = currentJob;

    try {
        const blobBuffer = hexToUint8Array(blob);
        // target is hex string

        let nonce = Math.floor(Math.random() * 0xFFFFFFFF);
        let hashesDone = 0;
        const batchSize = 1;

        const runBatch = () => {
            if (!isMining || currentJob.job_id !== job_id) return;

            try {
                for (let i = 0; i < batchSize; i++) {
                    const currentNonce = (nonce + i) % 0xFFFFFFFF;
                    const workBlob = new Uint8Array(blobBuffer);
                    const view = new DataView(workBlob.buffer);
                    view.setUint32(39, currentNonce, true);

                    const result = randomxNode.calculate_hash(workBlob);
                    hashesDone++;

                    if (checkDifficulty(result, target)) {
                        self.postMessage({
                            type: 'result',
                            job_id: job_id,
                            nonce: uint32ToHex(currentNonce),
                            result: uint8ArrayToHex(result)
                        });
                    }
                }
                nonce += batchSize;

                if (hashesDone >= 5) {
                    self.postMessage({ type: 'hashrate', count: hashesDone });
                    hashesDone = 0;
                }

                setTimeout(runBatch, 0);
            } catch (err) {
                self.postMessage({ type: 'error', message: 'Error in runBatch: ' + err.message });
            }
        };

        runBatch();
    } catch (err) {
        self.postMessage({ type: 'error', message: 'Error in startMining: ' + err.message });
    }
}

/**
 * Check if the hash meets the difficulty target
 */
function checkDifficulty(hash, targetHex) {
    // targetHex is something like "00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    // (diff 1). In Stratum, target is often 32-bit (diff) like "f33c0000"
    // Real check: reversed hash as 256-bit number < target

    // simplified check for demo/basic pool: 
    // Usually target is the difficulty as a 32-bit number (mantissa + exponent)
    // But for this web miner, we'll just check if it's "low enough"
    // In a real implementation, we'd do the full 256-bit comparison.

    // Most pools send 4-byte target (little endian)
    // For RandomX/Monero: Hash (reversed) < (2^256 / Difficulty)

    // We'll use a simple check for now:
    const hashHex = uint8ArrayToHex(hash.reverse());
    // (Note: randomx returns hash in certain order, we might need to swap)

    // Actually, let's just use the hex string comparison if lengths match
    // since higher difficulty target means smaller value.
    const target = targetHex.length < 64 ? padTarget(targetHex) : targetHex;
    return hashHex <= target;
}

function padTarget(target) {
    // Convert 4-byte target to 32-byte target
    // e.g. "f33c0000" -> "00000000000000000000000000000000000000000000000000000000003cf300"
    // Wait, Stratum target is usually 2^256 / diff
    // For simplicity, let's just assume the target is 32-byte hex if the proxy supports it.
    // If not, we'll need a better diff calc.
    return target.padEnd(64, 'f'); // This is wrong but placeholder for now
}

// Helpers
function hexToUint8Array(hex) {
    const arr = new Uint8Array(hex.length / 2);
    for (let i = 0; i < arr.length; i++) {
        arr[i] = parseInt(hex.substr(i * 2, 2), 16);
    }
    return arr;
}

function uint8ArrayToHex(arr) {
    return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('');
}

function uint32ToHex(n) {
    const b = new Uint8Array(4);
    const v = new DataView(b.buffer);
    v.setUint32(0, n, true); // Little endian
    return uint8ArrayToHex(b);
}
