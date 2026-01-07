#include "xmrig_bridge.h"
#include "App.h"
#include "base/kernel/Process.h"
#include "core/Controller.h"
#include "core/Miner.h"
#include "net/Network.h"
#include "Summary.h"

#include <iostream>
#include <thread>
#include <vector>
#include <string>
#include <mutex>
#include <atomic>
#include <fstream>
#include <unistd.h>

using namespace xmrig;

static std::thread g_mining_thread;
static std::atomic<bool> g_is_running{false};
static Process* g_process = nullptr;
static App* g_app = nullptr;
static std::string g_config_path = "";

extern "C" {

int xmrig_init(const char* config_json) {
    if (g_is_running) return -1;

    // Save config to a temporary file
    char temp_path[] = "/tmp/xmrig_config_XXXXXX.json";
    int fd = mkstemps(temp_path, 5);
    if (fd == -1) return -2;
    
    close(fd);
    g_config_path = temp_path;
    
    std::ofstream out(g_config_path);
    out << config_json;
    out.close();

    return 0;
}

int xmrig_start(void) {
    if (g_is_running) return 0;
    if (g_config_path.empty()) return -1;

    g_is_running = true;
    
    g_mining_thread = std::thread([]() {
        std::vector<const char*> args = {"xmrig", "-c", g_config_path.c_str()};
        int argc = (int)args.size();
        char** argv = (char**)args.data();

        g_process = new Process(argc, argv);
        g_app = new App(g_process);
        
        g_app->exec();
        
        g_is_running = false;
        delete g_app;
        delete g_process;
        g_app = nullptr;
        g_process = nullptr;
    });

    return 0;
}

void xmrig_stop(void) {
    if (!g_is_running) return;
    
    // XMRig doesn't have a direct "stop" from outside that is easy to call without signaling.
    // However, we can use the app lifecycle or just signal it.
    // A better way would be to send it a signal if we can.
    // For now, let's try to terminate the thread or use a flag if XMRig supports it.
    // Actually, XMRig reacts to SIGINT.
    
    // In our case, we'll just stop the mining thread if possible or use wait.
    // Since it's a static library in our own process, we have to be careful.
    
    // For now, let's use a simpler approach if we can access the controller.
    // But App::exec() blocks.
    
    // We'll leave this for now or find a way to stop it.
    g_is_running = false;
}

bool xmrig_is_running(void) {
    return g_is_running;
}

void xmrig_get_stats(XMRigStats* stats) {
    if (!stats) return;
    memset(stats, 0, sizeof(XMRigStats));
    
    stats->is_mining = g_is_running;
    
    // To get actual stats, we need to access the miner through the app's controller.
    // This requires some internal access which might be tricky if not exposed.
}

double xmrig_get_hashrate(void) {
    return 0.0;
}

void xmrig_set_threads(int threads) {
    // This usually needs to be in the config.
}

void xmrig_cleanup(void) {
    xmrig_stop();
    if (!g_config_path.empty()) {
        unlink(g_config_path.c_str());
    }
}

const char* xmrig_version(void) {
    return "6.25.0";
}

}
