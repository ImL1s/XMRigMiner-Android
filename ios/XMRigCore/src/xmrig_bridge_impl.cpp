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
#include <getopt.h>
#include <sys/stat.h>

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

    // Get the app container root from storage path
    std::string base_path = g_storage_path.empty() ? "/tmp" : g_storage_path;

    fprintf(stderr, "[INIT v14] base_path: %s\n", base_path.c_str());
    os_log(g_ios_log, "[XMRIG BRIDGE v14] base_path: %{public}s", base_path.c_str());

    // Find the container root (go up from Documents/Library/Caches to the container)
    std::string container_root = base_path;
    size_t pos = container_root.rfind("/Library/");
    if (pos != std::string::npos) {
        container_root = container_root.substr(0, pos);
    } else {
        pos = container_root.rfind("/Documents");
        if (pos != std::string::npos) {
            container_root = container_root.substr(0, pos);
        }
    }

    fprintf(stderr, "[INIT v14] container_root: %s\n", container_root.c_str());
    os_log(g_ios_log, "[XMRIG BRIDGE v14] Container root: %{public}s", container_root.c_str());

    // Try writing to container root first
    g_config_path = container_root + "/.xmrig.json";
    fprintf(stderr, "[INIT v14] Trying path: %s\n", g_config_path.c_str());
    os_log(g_ios_log, "[XMRIG BRIDGE v14] Trying primary path: %{public}s", g_config_path.c_str());

    std::ofstream out(g_config_path);
    if (!out.is_open()) {
        fprintf(stderr, "[INIT v14] Failed primary, errno=%d\n", errno);
        os_log_error(g_ios_log, "[XMRIG BRIDGE v14] Failed primary path, errno=%d", errno);

        // Fallback: try writing to base_path directory instead
        g_config_path = base_path + "/.xmrig.json";
        fprintf(stderr, "[INIT v14] Fallback path: %s\n", g_config_path.c_str());
        os_log(g_ios_log, "[XMRIG BRIDGE v14] Trying fallback path: %{public}s", g_config_path.c_str());

        out.open(g_config_path);
        if (!out.is_open()) {
            fprintf(stderr, "[INIT v14] Fallback ALSO failed, errno=%d\n", errno);
            os_log_error(g_ios_log, "[XMRIG BRIDGE v14] Fallback also failed, errno=%d", errno);
            return -2;
        }
    }

    out << config_json;
    out.flush();
    out.close();
    // Force sync to disk
    int fd = open(g_config_path.c_str(), O_RDONLY);
    if (fd >= 0) {
        fsync(fd);
        close(fd);
    }
    fprintf(stderr, "[INIT v14] SUCCESS written to: %s\n", g_config_path.c_str());
    fprintf(stderr, "[INIT v14] Config content:\n%s\n", config_json);
    os_log(g_ios_log, "[XMRIG BRIDGE v14] Written to: %{public}s", g_config_path.c_str());

    // Also create .config directory and write there (in same base as successful write)
    std::string config_base = g_config_path.substr(0, g_config_path.rfind('/'));
    std::string config_dir = config_base + "/.config";
    mkdir(config_dir.c_str(), 0755);
    std::string alt_path = config_dir + "/xmrig.json";
    std::ofstream out2(alt_path);
    if (out2.is_open()) {
        out2 << config_json;
        out2.close();
        fprintf(stderr, "[INIT v14] Also wrote .config: %s\n", alt_path.c_str());
        os_log(g_ios_log, "[XMRIG BRIDGE v14] Also wrote to %{public}s", alt_path.c_str());
    }

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
        if (g_log_callback) g_log_callback("[XMRIG BRIDGE v15] Starting XMRig core...");

        fprintf(stderr, "[START v15] Using config path: %s\n", g_config_path.c_str());
        if (g_saved_stdout != -1) {
            dprintf(g_saved_stdout, "[START v15] Config path: %s\n", g_config_path.c_str());
            fsync(g_saved_stdout);
        }

        // Pass config path explicitly with --config=<path> format
        static std::string arg_prog = "xmrig";
        static std::string arg_config_opt = std::string("--config=") + g_config_path;
        const char* argv[] = { arg_prog.c_str(), arg_config_opt.c_str(), nullptr };
        int argc = 2;

        fprintf(stderr, "[START v16] XMRig args: %s %s\n", argv[0], argv[1]);
        if (g_saved_stdout != -1) {
            dprintf(g_saved_stdout, "[START v16] XMRig args: %s %s\n", argv[0], argv[1]);
            fsync(g_saved_stdout);
        }

        // Reset ALL getopt state for re-entry (critical for library usage)
        optind = 1;
        opterr = 1;
        optopt = 0;
#ifdef __APPLE__
        optreset = 1;
#endif

        // Set XMRIG_CONFIG_PATH environment variable for our patched Base.cpp
        setenv("XMRIG_CONFIG_PATH", g_config_path.c_str(), 1);
        fprintf(stderr, "[START v17] Set XMRIG_CONFIG_PATH=%s\n", g_config_path.c_str());
        if (g_saved_stdout != -1) {
            dprintf(g_saved_stdout, "[START v17] Set XMRIG_CONFIG_PATH=%s\n", g_config_path.c_str());
            fsync(g_saved_stdout);
        }

        try {
            g_process = new Process(argc, (char**)argv);
            g_app = new App(g_process);
            g_app->exec();
        } catch (const std::exception& e) {
            os_log_error(g_ios_log, "[BRIDGE v10] XMRig exception: %{public}s", e.what());
            if (g_saved_stdout != -1) {
                dprintf(g_saved_stdout, "[BRIDGE v10] Exception: %s\n", e.what());
            }
        }

        delete g_app;
        delete g_process;
        g_app = nullptr;
        g_process = nullptr;

        if (g_log_callback) g_log_callback("[XMRIG BRIDGE v10] XMRig core stopped.");
        g_is_running = false;
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
