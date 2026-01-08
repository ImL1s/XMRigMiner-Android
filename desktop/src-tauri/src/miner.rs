// XMRig Miner Module - Process Management
use serde::{Deserialize, Serialize};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::io::{BufRead, BufReader};
use std::thread;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MiningConfig {
    pub pool_url: String,
    pub wallet_address: String,
    pub worker_name: String,
    pub threads: u32,
    pub coin_type: String,
    pub algorithm: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MiningStats {
    pub hashrate: f64,
    pub hashrate_10s: f64,
    pub hashrate_60s: f64,
    pub hashrate_15m: f64,
    pub shares_accepted: u64,
    pub shares_rejected: u64,
    pub difficulty: u64,
    pub uptime: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemInfo {
    pub cpu_name: String,
    pub cpu_cores: u32,
    pub cpu_threads: u32,
    pub memory_total: u64,
    pub memory_available: u64,
    pub os_name: String,
    pub os_version: String,
    pub arch: String,
}

pub struct MinerState {
    process: Option<Child>,
    running: AtomicBool,
    stats: MiningStats,
}

impl MinerState {
    pub fn new() -> Self {
        Self {
            process: None,
            running: AtomicBool::new(false),
            stats: MiningStats::default(),
        }
    }

    pub async fn start(&mut self, config: MiningConfig) -> Result<String, String> {
        if self.running.load(Ordering::SeqCst) {
            return Err("Miner is already running".to_string());
        }

        // Build XMRig command
        let xmrig_path = get_xmrig_path();

        let mut cmd = Command::new(&xmrig_path);
        cmd.arg("-o").arg(&config.pool_url)
           .arg("-u").arg(&config.wallet_address)
           .arg("-p").arg(&config.worker_name)
           .arg("-t").arg(config.threads.to_string())
           .arg("-a").arg(&config.algorithm)
           .arg("--no-color")
           .arg("--http-enabled")
           .arg("--http-host=127.0.0.1")
           .arg("--http-port=37420")
           .stdout(Stdio::piped())
           .stderr(Stdio::piped());

        match cmd.spawn() {
            Ok(child) => {
                self.process = Some(child);
                self.running.store(true, Ordering::SeqCst);
                Ok("Mining started successfully".to_string())
            }
            Err(e) => Err(format!("Failed to start XMRig: {}", e)),
        }
    }

    pub async fn stop(&mut self) -> Result<String, String> {
        if !self.running.load(Ordering::SeqCst) {
            return Err("Miner is not running".to_string());
        }

        if let Some(ref mut process) = self.process {
            match process.kill() {
                Ok(_) => {
                    self.running.store(false, Ordering::SeqCst);
                    self.process = None;
                    self.stats = MiningStats::default();
                    Ok("Mining stopped".to_string())
                }
                Err(e) => Err(format!("Failed to stop miner: {}", e)),
            }
        } else {
            self.running.store(false, Ordering::SeqCst);
            Ok("Miner stopped".to_string())
        }
    }

    pub fn get_stats(&self) -> MiningStats {
        self.stats.clone()
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::SeqCst)
    }
}

fn get_xmrig_path() -> String {
    #[cfg(target_os = "windows")]
    {
        "binaries/xmrig.exe".to_string()
    }
    #[cfg(target_os = "macos")]
    {
        "binaries/xmrig".to_string()
    }
    #[cfg(target_os = "linux")]
    {
        "binaries/xmrig".to_string()
    }
}

pub fn get_system_info() -> SystemInfo {
    SystemInfo {
        cpu_name: get_cpu_name(),
        cpu_cores: num_cpus::get_physical() as u32,
        cpu_threads: num_cpus::get() as u32,
        memory_total: get_total_memory(),
        memory_available: get_available_memory(),
        os_name: std::env::consts::OS.to_string(),
        os_version: get_os_version(),
        arch: std::env::consts::ARCH.to_string(),
    }
}

fn get_cpu_name() -> String {
    #[cfg(target_os = "macos")]
    {
        use std::process::Command;
        let output = Command::new("sysctl")
            .arg("-n")
            .arg("machdep.cpu.brand_string")
            .output()
            .ok();
        output
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|| "Unknown CPU".to_string())
    }
    #[cfg(target_os = "windows")]
    {
        "Windows CPU".to_string()
    }
    #[cfg(target_os = "linux")]
    {
        use std::fs;
        fs::read_to_string("/proc/cpuinfo")
            .ok()
            .and_then(|s| {
                s.lines()
                    .find(|l| l.starts_with("model name"))
                    .map(|l| l.split(':').nth(1).unwrap_or("").trim().to_string())
            })
            .unwrap_or_else(|| "Unknown CPU".to_string())
    }
}

fn get_total_memory() -> u64 {
    // Returns total memory in bytes (simplified)
    8 * 1024 * 1024 * 1024 // 8GB placeholder
}

fn get_available_memory() -> u64 {
    // Returns available memory in bytes (simplified)
    4 * 1024 * 1024 * 1024 // 4GB placeholder
}

fn get_os_version() -> String {
    #[cfg(target_os = "macos")]
    {
        use std::process::Command;
        Command::new("sw_vers")
            .arg("-productVersion")
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|| "Unknown".to_string())
    }
    #[cfg(target_os = "windows")]
    {
        "Windows".to_string()
    }
    #[cfg(target_os = "linux")]
    {
        use std::fs;
        fs::read_to_string("/etc/os-release")
            .ok()
            .and_then(|s| {
                s.lines()
                    .find(|l| l.starts_with("VERSION="))
                    .map(|l| l.replace("VERSION=", "").replace("\"", ""))
            })
            .unwrap_or_else(|| "Linux".to_string())
    }
}
