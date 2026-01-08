#include "xmrig_bridge.h"
#include "App.h"
#include "base/kernel/Process.h"
#include "core/Controller.h"
#include "core/Miner.h"

#include <iostream>
#include <thread>
#include <vector>
#include <string>
#include <mutex>
#include <atomic>
#include <fstream>
#include <unistd.h>
#include <fcntl.h>
#include <cinttypes>

#include <os/log.h>

using namespace xmrig;

static os_log_t g_ios_log = os_log_create("com.iml1s.xmrigminer", "XMRigCore");

static std::thread g_mining_thread;
static std::thread g_log_thread;
static std::atomic<bool> g_is_running{false};
static Process* g_process = nullptr;
static App* g_app = nullptr;
static std::string g_storage_path = "";
static std::string g_config_path = "";
static std::mutex g_mutex;
static xmrig_log_callback_t g_log_callback = nullptr;

// Stats globals
static XMRigStats g_stats = {0};
static std::mutex g_stats_mutex;

// Pipe for capturing stdout/stderr
static int g_pipe_fd[2] = {-1, -1};
static int g_saved_stdout = -1;
static int g_saved_stderr = -1;

extern "C" {

void xmrig_set_storage_path_v8(const char* path) {
    if (path) {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_storage_path = path;
        os_log(g_ios_log, "[XMRIG BRIDGE vFINAL_PROBE] Storage path set to: %{public}s", path);
    }
}

void xmrig_set_log_callback_v8(xmrig_log_callback_t callback) {
    g_log_callback = callback;
}

void xmrig_get_stats_v8(XMRigStats* stats) {
    if (!stats) return;
    
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    stats->hashrate_10s = g_stats.hashrate_10s;
    stats->hashrate_60s = g_stats.hashrate_60s;
    stats->hashrate_15m = g_stats.hashrate_15m;
    stats->total_hashes = g_stats.total_hashes;
    stats->accepted_shares = g_stats.accepted_shares;
    stats->rejected_shares = g_stats.rejected_shares;
    stats->is_mining = g_is_running;
    stats->threads = g_stats.threads;
}

void xmrig_update_stats_v8(double hr10s, double hr60s, double hr15m, 
                         uint64_t accepted, uint64_t rejected, int threads) {
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    g_stats.hashrate_10s = hr10s;
    g_stats.hashrate_60s = hr60s;
    g_stats.hashrate_15m = hr15m;
    g_stats.total_hashes += (uint64_t)(hr10s * 10); // Rough estimate for update
    g_stats.accepted_shares = accepted;
    g_stats.rejected_shares = rejected;
    g_stats.threads = threads;
}

double xmrig_get_hashrate_v8(void) {
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    return g_stats.hashrate_10s;
}

void xmrig_set_threads_v8(int threads) {
    // Not implemented for real core yet, config controls this
}

const char* xmrig_version_v8(void) {
    return "6.25.0";
}

int xmrig_init_v8(const char* config_json) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_is_running) return -1;
    
    // Config file setup
    if (!g_storage_path.empty()) {
        setenv("HOME", g_storage_path.c_str(), 1);
        os_log(g_ios_log, "[XMRIG BRIDGE vFINAL_PROBE] Overriding HOME to: %{public}s", g_storage_path.c_str());
    }
    
    std::string base_path = g_storage_path.empty() ? "/tmp" : g_storage_path;
    g_config_path = base_path + "/.xmrig.json";
    
    os_log(g_ios_log, "[XMRIG BRIDGE vFINAL_PROBE] Writing config to %{public}s", g_config_path.c_str());
    if (g_saved_stdout != -1) {
        dprintf(g_saved_stdout, "[XMRIG BRIDGE vFINAL_PROBE] Writing config to %s\n", g_config_path.c_str());
        fsync(g_saved_stdout);
    }
    
    std::ofstream out(g_config_path);
    if (!out.is_open()) return -2;
    
    out << config_json;
    out.close();
    
    return 0;
}

static void capture_logs() {
    char buffer[2048];
    while (true) {
        ssize_t n = read(g_pipe_fd[0], buffer, sizeof(buffer) - 1);
        if (n > 0) {
            buffer[n] = '\0';
            // Split by lines
            char* start = buffer;
            for (int i = 0; i < n; ++i) {
                if (buffer[i] == '\n') {
                    buffer[i] = '\0';
                    // Write to original stdout so it shows in devicectl --console
                    if (g_saved_stdout != -1) {
                        dprintf(g_saved_stdout, "[XMRIG] %s\n", start);
                    }
                    os_log(g_ios_log, "%{public}s", start);
                    if (g_log_callback) g_log_callback(start);
                    start = buffer + i + 1;
                }
            }
            if (start < buffer + n) {
                if (g_saved_stdout != -1) {
                    dprintf(g_saved_stdout, "[XMRIG] %s\n", start);
                }
                os_log(g_ios_log, "%{public}s", start);
                if (g_log_callback) g_log_callback(start);
            }
            if (g_saved_stdout != -1) fsync(g_saved_stdout);
        } else {
            break;
        }
    }
}

int xmrig_start_v8(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (g_is_running) return -1;
    g_is_running = true;
    
    if (pipe(g_pipe_fd) == -1) {
        g_is_running = false;
        return -2;
    }
    
    // Save original stdout/stderr
    g_saved_stdout = dup(STDOUT_FILENO);
    g_saved_stderr = dup(STDERR_FILENO);
    
    // Redirect stdout/stderr to pipe
    dup2(g_pipe_fd[1], STDOUT_FILENO);
    dup2(g_pipe_fd[1], STDERR_FILENO);
    
    // Start log capture thread
    g_log_thread = std::thread(capture_logs);
    g_log_thread.detach();

    // Start mining thread
    g_mining_thread = std::thread([]() {
        if (g_log_callback) g_log_callback("[XMRIG BRIDGE] Starting real XMRig core thread...");
        
        // Use a local copy of the global config path
        std::string local_config_path = g_config_path;
        
        if (g_log_callback) {
            std::string msg = "[XMRIG BRIDGE] Config path: " + local_config_path;
            g_log_callback(msg.c_str());
        }
        
        static std::string arg_prog = "xmrig";
        static std::string arg_c = "-c";
        
        const char* argv[] = { arg_prog.c_str(), arg_c.c_str(), local_config_path.c_str(), nullptr };
        int argc = 3;

        os_log(g_ios_log, "[BRIDGE v8] Executing XMRig with config: %{public}s", local_config_path.c_str());
        if (g_saved_stdout != -1) {
            dprintf(g_saved_stdout, "[BRIDGE v8] REAL_STDOUT: Executing XMRig with argc=%d, config=%s\n", argc, local_config_path.c_str());
            fsync(g_saved_stdout);
        }

        try {
            g_process = new Process(argc, (char**)argv);
            g_app = new App(g_process);
            g_app->exec();
        } catch (const std::exception& e) {
            os_log_error(g_ios_log, "[BRIDGE v8] XMRig exception: %{public}s", e.what());
        }
        
        delete g_app;
        delete g_process;
        g_app = nullptr;
        g_process = nullptr;
        
        if (g_log_callback) g_log_callback("[XMRIG BRIDGE] XMRig core stopped.");
        g_is_running = false;
        
        // Don't restore stdout here, let cleanup do it or just exit
    });
    g_mining_thread.detach();

    return 0;
}

void xmrig_stop_v8(void) {
    if (!g_is_running) return;
    
    if (g_log_callback) g_log_callback("[XMRIG BRIDGE] Stopping...");
    
    if (g_app) {
         // g_app->exit(); // Error: no member named exit
         os_log(g_ios_log, "[XMRIG BRIDGE vFINAL_PROBE] Stop requested but App::exit missing");
    }
}

bool xmrig_is_running_v8(void) {
    return g_is_running.load();
}

void xmrig_cleanup_v8(void) {
    if (g_is_running) {
        xmrig_stop_v8();
    }
    
    // Close pipe ends
    if (g_pipe_fd[0] != -1) close(g_pipe_fd[0]);
    if (g_pipe_fd[1] != -1) close(g_pipe_fd[1]);
    
    if (g_saved_stdout != -1) {
        dup2(g_saved_stdout, STDOUT_FILENO);
        close(g_saved_stdout);
    }
    if (g_saved_stderr != -1) {
        dup2(g_saved_stderr, STDERR_FILENO);
        close(g_saved_stderr);
    }
    
    if (!g_config_path.empty()) {
        unlink(g_config_path.c_str());
        g_config_path.clear();
    }
    
    std::lock_guard<std::mutex> lock(g_stats_mutex);
    g_stats = {0};
}

} // extern "C"
