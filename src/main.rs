mod clash_api;
mod config;
mod constants;
mod models;
mod network;
mod system;
mod tray_helpers;

use std::collections::HashMap;
use std::thread;
use std::time::{Duration, Instant};

use clash_api::{perform_refresh, set_clash_mode, set_clash_proxy, test_proxy_latency};
use constants::{APP_ID_PREFIX, APP_NAME};
use models::{
    ActionOutcome, AppConfig, ClashSnapshot, GroupTestProgress, GroupTestResult,
    NetworkCheckResult, RefreshResult,
};
use network::run_network_checks;
use system::{open_config_file, open_dashboard, toggle_launch_at_login};
use tray_helpers::{build_tray, clear_menu, encode_component, parse_proxy_id, parse_test_group_id};
use tray_icon::{
    TrayIcon, TrayIconEvent,
    menu::{CheckMenuItem, Menu, MenuEvent, MenuItem, PredefinedMenuItem, Submenu},
};
use winit::application::ApplicationHandler;
use winit::event::{StartCause, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop, EventLoopProxy};
#[cfg(target_os = "macos")]
use winit::platform::macos::{ActivationPolicy, EventLoopBuilderExtMacOS};
use winit::window::WindowId;

const MAX_TRAY_RETRY_ATTEMPTS: u32 = 5;
const MAX_TRAY_RETRY_DELAY_SECONDS: u64 = 8;

enum UserEvent {
    Menu(MenuEvent),
    Tray(TrayIconEvent),
    RefreshFinished(std::result::Result<RefreshResult, String>),
    ActionFinished(std::result::Result<ActionOutcome, String>),
    GroupTestProgress(GroupTestProgress),
    GroupTestFinished(std::result::Result<GroupTestResult, String>),
    NetworkCheckFinished(std::result::Result<NetworkCheckResult, String>),
}

struct App {
    proxy: EventLoopProxy<UserEvent>,
    menu: Menu,
    tray: Option<TrayIcon>,
    config: AppConfig,
    snapshot: Option<ClashSnapshot>,
    group_latencies: HashMap<String, HashMap<String, Option<u64>>>,
    node_latencies: HashMap<String, Option<u64>>,
    network_checks: Vec<(&'static str, String)>,
    ip_checks: Vec<(&'static str, String)>,
    last_status: String,
    last_error: Option<String>,
    refresh_in_flight: bool,
    next_refresh_at: Instant,
    next_tray_retry_at: Option<Instant>,
    tray_retry_attempts: u32,
}

impl App {
    fn new(proxy: EventLoopProxy<UserEvent>) -> Self {
        Self {
            proxy,
            menu: Menu::new(),
            tray: None,
            config: AppConfig::default(),
            snapshot: None,
            group_latencies: HashMap::new(),
            node_latencies: HashMap::new(),
            network_checks: Vec::new(),
            ip_checks: Vec::new(),
            last_status: "Starting...".to_string(),
            last_error: None,
            refresh_in_flight: false,
            next_refresh_at: Instant::now(),
            next_tray_retry_at: None,
            tray_retry_attempts: 0,
        }
    }

    fn init(&mut self, event_loop: &ActiveEventLoop) {
        if let Err(error) = config::ensure_config_exists() {
            self.last_error = Some(error.to_string());
            self.last_status = "Failed to prepare config".to_string();
        }

        self.rebuild_menu();
        self.try_build_tray(event_loop);

        self.start_refresh("startup");
    }

    fn try_build_tray(&mut self, event_loop: &ActiveEventLoop) {
        if self.tray.is_some() {
            self.next_tray_retry_at = None;
            self.tray_retry_attempts = 0;
            return;
        }

        match build_tray(self.menu.clone()) {
            Ok(tray) => {
                self.tray = Some(tray);
                self.next_tray_retry_at = None;
                self.tray_retry_attempts = 0;
                self.last_error = None;
                if self.last_status == "Failed to create tray icon" {
                    self.last_status = "Tray icon restored".to_string();
                }
                self.rebuild_menu();
            }
            Err(error) => {
                let message = error.to_string();
                eprintln!("failed to create tray icon: {message}");
                self.last_error = Some(message);
                self.tray_retry_attempts = self.tray_retry_attempts.saturating_add(1);

                if self.tray_retry_attempts >= MAX_TRAY_RETRY_ATTEMPTS {
                    self.last_status = "Tray icon failed to start; exiting".to_string();
                    self.next_tray_retry_at = None;
                    self.rebuild_menu();
                    event_loop.exit();
                    return;
                }

                let delay_seconds =
                    (1_u64 << (self.tray_retry_attempts - 1)).min(MAX_TRAY_RETRY_DELAY_SECONDS);
                self.last_status = format!(
                    "Failed to create tray icon (retry {}/{} in {}s)",
                    self.tray_retry_attempts, MAX_TRAY_RETRY_ATTEMPTS, delay_seconds
                );
                self.next_tray_retry_at = Some(Instant::now() + Duration::from_secs(delay_seconds));
                self.rebuild_menu();
            }
        }
    }

    fn start_refresh(&mut self, reason: &'static str) {
        if self.refresh_in_flight {
            return;
        }
        self.refresh_in_flight = true;
        self.last_status = format!("Refreshing ({reason})...");
        self.rebuild_menu();

        let proxy = self.proxy.clone();
        thread::spawn(move || {
            let result = perform_refresh().map_err(|error| error.to_string());
            let _ = proxy.send_event(UserEvent::RefreshFinished(result));
        });
    }

    fn apply_refresh_result(&mut self, result: std::result::Result<RefreshResult, String>) {
        self.refresh_in_flight = false;
        match result {
            Ok(result) => {
                self.config = result.config;
                self.snapshot = result.snapshot;
                self.last_status = result.status;
                self.last_error = result.error;
            }
            Err(error) => {
                self.last_status = "Refresh failed".to_string();
                self.last_error = Some(error);
            }
        }
        self.schedule_next_refresh();
        self.rebuild_menu();
    }

    fn schedule_next_refresh(&mut self) {
        let seconds = self.config.refresh_interval_seconds.max(1);
        self.next_refresh_at = Instant::now() + Duration::from_secs(seconds);
    }

    fn rebuild_menu(&mut self) {
        clear_menu(&self.menu);

        let backend = MenuItem::with_id(
            format!("{APP_ID_PREFIX}:info:backend"),
            format!("Backend: {}", self.config.backend_label()),
            false,
            None,
        );
        let refresh_interval = MenuItem::with_id(
            format!("{APP_ID_PREFIX}:info:interval"),
            format!(
                "Auto Refresh: {}s",
                self.config.refresh_interval_seconds.max(1)
            ),
            false,
            None,
        );
        let status = MenuItem::with_id(
            format!("{APP_ID_PREFIX}:info:status"),
            self.last_status.clone(),
            false,
            None,
        );
        let _ = self
            .menu
            .append_items(&[&backend, &refresh_interval, &status]);

        if let Some(error) = &self.last_error {
            let error_item =
                MenuItem::with_id(format!("{APP_ID_PREFIX}:info:error"), error, false, None);
            let _ = self.menu.append(&error_item);
        }

        if let Some(snapshot) = &self.snapshot {
            if let Some(traffic) = &snapshot.traffic {
                let traffic_item = MenuItem::with_id(
                    format!("{APP_ID_PREFIX}:info:traffic"),
                    traffic,
                    false,
                    None,
                );
                let _ = self.menu.append(&traffic_item);
            }
            if let Some(expire) = &snapshot.expire {
                let expire_item =
                    MenuItem::with_id(format!("{APP_ID_PREFIX}:info:expire"), expire, false, None);
                let _ = self.menu.append(&expire_item);
            }
        }

        if let Some(snapshot) = &self.snapshot {
            let mode_menu = Submenu::new("Mode", true);
            for mode in ["Rule", "Global", "Direct"] {
                let item = CheckMenuItem::with_id(
                    format!("{APP_ID_PREFIX}:mode:{mode}"),
                    mode,
                    true,
                    snapshot.mode.eq_ignore_ascii_case(mode),
                    None,
                );
                let _ = mode_menu.append(&item);
            }
            let _ = self.menu.append(&mode_menu);

            let proxies_menu = Submenu::new("Proxies", true);
            for group in &snapshot.groups {
                let group_menu = Submenu::new(&group.name, true);
                let test_group = MenuItem::with_id(
                    format!(
                        "{APP_ID_PREFIX}:test-group:{}",
                        encode_component(&group.name)
                    ),
                    "Test Group",
                    true,
                    None,
                );
                let _ = group_menu.append(&test_group);
                let _ = group_menu.append(&PredefinedMenuItem::separator());
                for node in &group.nodes {
                    let label = self
                        .group_latencies
                        .get(&group.name)
                        .and_then(|latencies| latencies.get(node))
                        .or_else(|| self.node_latencies.get(node))
                        .map(|latency| match latency {
                            Some(ms) => format!("{node} ({ms}ms)"),
                            None => format!("{node} (timeout)"),
                        })
                        .unwrap_or_else(|| node.clone());
                    let item = CheckMenuItem::with_id(
                        format!(
                            "{APP_ID_PREFIX}:proxy:{}:{}",
                            encode_component(&group.name),
                            encode_component(node)
                        ),
                        label,
                        true,
                        group.selected.as_deref() == Some(node.as_str()),
                        None,
                    );
                    let _ = group_menu.append(&item);
                }
                let _ = proxies_menu.append(&group_menu);
            }
            let _ = self.menu.append(&proxies_menu);

            let network_menu = Submenu::new("Network", true);
            let run_checks = MenuItem::with_id(
                format!("{APP_ID_PREFIX}:network-check"),
                "Run Checks",
                true,
                None,
            );
            let _ = network_menu.append(&run_checks);
            let _ = network_menu.append(&PredefinedMenuItem::separator());
            for (name, status) in &self.network_checks {
                let item = MenuItem::with_id(
                    format!("{APP_ID_PREFIX}:info:network:{}", encode_component(name)),
                    format!("{name}: {status}"),
                    false,
                    None,
                );
                let _ = network_menu.append(&item);
            }
            for (name, value) in &self.ip_checks {
                let item = MenuItem::with_id(
                    format!("{APP_ID_PREFIX}:info:ip:{}", encode_component(name)),
                    format!("{name}: {value}"),
                    false,
                    None,
                );
                let _ = network_menu.append(&item);
            }
            let _ = self.menu.append(&network_menu);
        }

        let separator = PredefinedMenuItem::separator();
        let refresh = MenuItem::with_id(format!("{APP_ID_PREFIX}:refresh"), "Refresh", true, None);
        let _ = self.menu.append_items(&[&separator, &refresh]);

        let separator = PredefinedMenuItem::separator();
        let launch = CheckMenuItem::with_id(
            format!("{APP_ID_PREFIX}:launch"),
            "Launch at Login",
            true,
            self.config.launch_at_login,
            None,
        );
        let open_config = MenuItem::with_id(
            format!("{APP_ID_PREFIX}:open-config"),
            "Open Config...",
            true,
            None,
        );
        let open_dashboard = MenuItem::with_id(
            format!("{APP_ID_PREFIX}:open-dashboard"),
            "Open Dashboard",
            true,
            None,
        );
        let quit = MenuItem::with_id(format!("{APP_ID_PREFIX}:quit"), "Quit", true, None);
        let _ = self.menu.append_items(&[
            &separator,
            &launch,
            &open_dashboard,
            &open_config,
            &PredefinedMenuItem::separator(),
            &quit,
        ]);

        if let Some(tray) = &self.tray {
            let _ = tray.set_tooltip(Some(format!(
                "{APP_NAME} ({})",
                self.config.backend_label()
            )));
        }
    }

    fn handle_menu_event(&mut self, event_loop: &ActiveEventLoop, event: MenuEvent) {
        let id = event.id.as_ref();
        match id {
            x if x == format!("{APP_ID_PREFIX}:refresh") => self.start_refresh("manual refresh"),
            x if x == format!("{APP_ID_PREFIX}:launch") => {
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = toggle_launch_at_login().map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::ActionFinished(result));
                });
            }
            x if x == format!("{APP_ID_PREFIX}:open-config") => {
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = open_config_file().map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::ActionFinished(result));
                });
            }
            x if x == format!("{APP_ID_PREFIX}:open-dashboard") => {
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = open_dashboard().map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::ActionFinished(result));
                });
            }
            x if x == format!("{APP_ID_PREFIX}:network-check") => {
                if self.snapshot.is_none() {
                    self.last_error = Some("No Clash snapshot yet".to_string());
                    self.rebuild_menu();
                    return;
                }
                self.last_status = "Running network checks...".to_string();
                self.last_error = None;
                self.rebuild_menu();
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = run_network_checks().map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::NetworkCheckFinished(result));
                });
            }
            _ if id.starts_with(&format!("{APP_ID_PREFIX}:test-group:")) => {
                let Some(group) = parse_test_group_id(APP_ID_PREFIX, id) else {
                    self.last_error = Some(format!("Invalid test-group id: {id}"));
                    self.rebuild_menu();
                    return;
                };
                let Some(nodes) = self
                    .snapshot
                    .as_ref()
                    .and_then(|snapshot| snapshot.groups.iter().find(|item| item.name == group))
                    .map(|item| item.nodes.clone())
                else {
                    self.last_error = Some(format!("Missing group snapshot: {group}"));
                    self.rebuild_menu();
                    return;
                };
                self.last_status = format!("Testing {group}...");
                self.last_error = None;
                self.group_latencies.insert(group.clone(), HashMap::new());
                self.rebuild_menu();
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let mut latencies = HashMap::new();
                    for node in nodes {
                        match test_proxy_latency(&node) {
                            Ok(latency) => {
                                latencies.insert(node.clone(), latency);
                                let _ = proxy.send_event(UserEvent::GroupTestProgress(
                                    GroupTestProgress {
                                        group: group.clone(),
                                        node,
                                        latency,
                                    },
                                ));
                            }
                            Err(error) => {
                                let _ = proxy.send_event(UserEvent::GroupTestProgress(
                                    GroupTestProgress {
                                        group: group.clone(),
                                        node: node.clone(),
                                        latency: None,
                                    },
                                ));
                                latencies.insert(node, None);
                                let _ = error;
                            }
                        }
                    }
                    let result = Ok(GroupTestResult { group, latencies });
                    let _ = proxy.send_event(UserEvent::GroupTestFinished(result));
                });
            }
            x if x == format!("{APP_ID_PREFIX}:quit") => event_loop.exit(),
            _ if id.starts_with(&format!("{APP_ID_PREFIX}:mode:")) => {
                let mode = id.rsplit(':').next().unwrap_or("Rule").to_string();
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = set_clash_mode(&mode).map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::ActionFinished(result));
                });
            }
            _ if id.starts_with(&format!("{APP_ID_PREFIX}:proxy:")) => {
                let Some((group, node)) = parse_proxy_id(APP_ID_PREFIX, id) else {
                    self.last_error = Some(format!("Invalid proxy id: {id}"));
                    self.rebuild_menu();
                    return;
                };
                let proxy = self.proxy.clone();
                thread::spawn(move || {
                    let result = set_clash_proxy(&group, &node).map_err(|error| error.to_string());
                    let _ = proxy.send_event(UserEvent::ActionFinished(result));
                });
            }
            _ => {}
        }
    }

    fn handle_group_test_result(&mut self, result: std::result::Result<GroupTestResult, String>) {
        match result {
            Ok(result) => {
                let tested = result.latencies.len();
                for (node, latency) in &result.latencies {
                    self.node_latencies.insert(node.clone(), *latency);
                }
                self.group_latencies
                    .insert(result.group.clone(), result.latencies);
                self.last_status =
                    format!("Latency test finished: {} ({tested} nodes)", result.group);
                self.last_error = None;
            }
            Err(error) => {
                self.last_status = "Latency test failed".to_string();
                self.last_error = Some(error);
            }
        }
        self.rebuild_menu();
    }

    fn handle_group_test_progress(&mut self, progress: GroupTestProgress) {
        self.group_latencies
            .entry(progress.group.clone())
            .or_default()
            .insert(progress.node.clone(), progress.latency);
        self.node_latencies
            .insert(progress.node.clone(), progress.latency);
    }

    fn handle_network_check_result(
        &mut self,
        result: std::result::Result<NetworkCheckResult, String>,
    ) {
        match result {
            Ok(result) => {
                self.network_checks = result.access;
                self.ip_checks = result.ip_checks;
                self.last_status = "Network checks finished".to_string();
                self.last_error = None;
            }
            Err(error) => {
                self.last_status = "Network checks failed".to_string();
                self.last_error = Some(error);
            }
        }
        self.rebuild_menu();
    }

    fn handle_action_result(&mut self, result: std::result::Result<ActionOutcome, String>) {
        match result {
            Ok(outcome) => {
                self.last_status = outcome.status;
                self.last_error = None;
                if outcome.trigger_refresh {
                    self.start_refresh("post action");
                } else {
                    self.rebuild_menu();
                }
            }
            Err(error) => {
                self.last_status = "Last action failed".to_string();
                self.last_error = Some(error);
                self.rebuild_menu();
            }
        }
    }
}

impl ApplicationHandler<UserEvent> for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        self.try_build_tray(event_loop);
    }

    fn window_event(
        &mut self,
        _event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        _event: WindowEvent,
    ) {
    }

    fn new_events(&mut self, event_loop: &ActiveEventLoop, cause: StartCause) {
        match cause {
            StartCause::Init => self.init(event_loop),
            StartCause::ResumeTimeReached { .. } => {
                if self
                    .next_tray_retry_at
                    .is_some_and(|retry_at| Instant::now() >= retry_at)
                {
                    self.try_build_tray(event_loop);
                }
                if Instant::now() >= self.next_refresh_at {
                    self.start_refresh("auto refresh");
                }
            }
            _ => {}
        }
    }

    fn user_event(&mut self, event_loop: &ActiveEventLoop, event: UserEvent) {
        match event {
            UserEvent::Menu(event) => self.handle_menu_event(event_loop, event),
            UserEvent::Tray(_event) => {}
            UserEvent::RefreshFinished(result) => self.apply_refresh_result(result),
            UserEvent::ActionFinished(result) => self.handle_action_result(result),
            UserEvent::GroupTestProgress(progress) => self.handle_group_test_progress(progress),
            UserEvent::GroupTestFinished(result) => self.handle_group_test_result(result),
            UserEvent::NetworkCheckFinished(result) => self.handle_network_check_result(result),
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        let next_wake_at = self
            .next_tray_retry_at
            .map(|retry_at| retry_at.min(self.next_refresh_at))
            .unwrap_or(self.next_refresh_at);
        event_loop.set_control_flow(ControlFlow::WaitUntil(next_wake_at));
    }
}

fn main() {
    #[cfg(target_os = "linux")]
    if let Err(error) = gtk::init() {
        eprintln!("failed to initialize GTK: {error}");
        std::process::exit(1);
    }

    let mut builder = EventLoop::<UserEvent>::with_user_event();
    #[cfg(target_os = "macos")]
    {
        builder.with_activation_policy(ActivationPolicy::Accessory);
        builder.with_default_menu(false);
    }
    let event_loop = builder.build().expect("failed to build event loop");
    let proxy = event_loop.create_proxy();

    let menu_proxy = proxy.clone();
    MenuEvent::set_event_handler(Some(move |event| {
        let _ = menu_proxy.send_event(UserEvent::Menu(event));
    }));

    let tray_proxy = proxy.clone();
    TrayIconEvent::set_event_handler(Some(move |event| {
        let _ = tray_proxy.send_event(UserEvent::Tray(event));
    }));

    let mut app = App::new(proxy);
    event_loop.run_app(&mut app).expect("event loop failed");
}
