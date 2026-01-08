// XMRig Miner Desktop - Tauri Backend
// Supports macOS, Windows, Linux

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod miner;

use miner::MinerState;
use std::sync::Mutex;
use tauri::State;

// Global miner state
struct AppState {
    miner: Mutex<MinerState>,
}

#[tauri::command]
async fn start_mining(
    state: State<'_, AppState>,
    config: miner::MiningConfig,
) -> Result<String, String> {
    let mut miner = state.miner.lock().map_err(|e| e.to_string())?;
    miner.start(config).await
}

#[tauri::command]
async fn stop_mining(state: State<'_, AppState>) -> Result<String, String> {
    let mut miner = state.miner.lock().map_err(|e| e.to_string())?;
    miner.stop().await
}

#[tauri::command]
fn get_mining_stats(state: State<'_, AppState>) -> Result<miner::MiningStats, String> {
    let miner = state.miner.lock().map_err(|e| e.to_string())?;
    Ok(miner.get_stats())
}

#[tauri::command]
fn is_mining(state: State<'_, AppState>) -> Result<bool, String> {
    let miner = state.miner.lock().map_err(|e| e.to_string())?;
    Ok(miner.is_running())
}

#[tauri::command]
fn get_system_info() -> miner::SystemInfo {
    miner::get_system_info()
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_process::init())
        .manage(AppState {
            miner: Mutex::new(MinerState::new()),
        })
        .invoke_handler(tauri::generate_handler![
            start_mining,
            stop_mining,
            get_mining_stats,
            is_mining,
            get_system_info,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
