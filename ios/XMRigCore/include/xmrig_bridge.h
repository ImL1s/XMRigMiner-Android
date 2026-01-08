/**
 * XMRig Bridge API for iOS
 * C interface for Swift/Objective-C interop
 */

#ifndef XMRIG_BRIDGE_H
#define XMRIG_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

/**
 * Mining statistics structure
 */
typedef struct {
    double hashrate_10s;
    double hashrate_60s;
    double hashrate_15m;
    uint64_t total_hashes;
    uint64_t accepted_shares;
    uint64_t rejected_shares;
    bool is_mining;
    int threads;
} XMRigStats;

/**
 * Set the directory where temporary config files will be stored
 * @param path Absolute path to a writable directory
 */
void xmrig_set_storage_path_v8(const char* path);

/**
 * Initialize XMRig with JSON configuration
 * @param config_json JSON string with mining configuration
 * @return 0 on success, error code otherwise
 */
int xmrig_init_v8(const char* config_json);

/**
 * Start mining
 * @return 0 on success, error code otherwise
 */
int xmrig_start_v8(void);

/**
 * Stop mining
 */
void xmrig_stop_v8(void);

/**
 * Check if miner is currently running
 * @return true if mining, false otherwise
 */
bool xmrig_is_running_v8(void);

/**
 * Get current mining statistics
 * @param stats Pointer to XMRigStats structure to fill
 */
void xmrig_get_stats_v8(XMRigStats* stats);

/**
 * Get current hashrate (10s average)
 * @return Hashrate in H/s
 */
double xmrig_get_hashrate_v8(void);

/**
 * Set number of mining threads
 * @param threads Number of threads (0 = auto)
 */
void xmrig_set_threads_v8(int threads);

/**
 * Cleanup and release resources
 */
void xmrig_cleanup_v8(void);

/**
 * Get XMRig version string
 * @return Version string (e.g., "6.25.0")
 */
const char* xmrig_version_v8(void);

/**
 * Update stats from external source (e.g., log parsing)
 * This allows the iOS layer to feed stats back if it parses XMRig output
 */
void xmrig_update_stats_v8(double hr10s, double hr60s, double hr15m,
                        uint64_t accepted, uint64_t rejected, int threads);

/**
 * Log callback type
 */
typedef void (*xmrig_log_callback_t)(const char* line);

/**
 * Register log callback
 * @param callback Function pointer to the log handler
 */
void xmrig_set_log_callback_v8(xmrig_log_callback_t callback);

#ifdef __cplusplus
}
#endif

#endif /* XMRIG_BRIDGE_H */
