<div align="center">

# Caffeinate UI

### Keep your Mac awake. Keep your agents running.

**macOS menu bar app to keep your Mac awake, built on the same idle-sleep assertions as `caffeinate`.** Independent system and display controls, optional auto-off timers, a live view of running `caffeinate` sessions, and twelve coffee awards for long sessions.

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138.svg)](Package.swift)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-lightgrey.svg)](Package.swift)
![Apple Silicon](https://img.shields.io/badge/release-Apple%20Silicon-lightgrey.svg)

[**Quick start**](#quick-start) · [Why Caffeinate UI](#why-caffeinate-ui) · [What it does](#what-it-does) · [How it works](#how-it-works) · [Screenshots](#screenshots) · [FAQ](#faq) · [Docs](#documentation)

```sh
brew install --cask harinaralasetty/tap/caffeinate-ui
```

<img src="docs/screenshots/awards.jpg" alt="Caffeinate UI Awards window: five full-colour earned coffee badges from First Sip to Certified All-Nighter, and a grey locked Decaf Is a Myth badge with a progress bar" width="560">

</div>

> [!NOTE]
> The release is **not signed with an Apple Developer ID or notarized**, so macOS may block the first launch. Open System Settings > Privacy & Security and choose "Open Anyway". Releases are Apple Silicon only. Caffeinate UI prevents *idle* sleep; lid closure, low battery, forced sleep and macOS power policy can still put the Mac to sleep.

## Why Caffeinate UI

You start a long coding agent, build or terminal job, walk away, and the Mac goes to sleep halfway through.

- **One click instead of a terminal.** Turn system and display idle-sleep prevention on and off from the menu bar, independently.
- **Optional auto-off.** Keep awake until turned off, or for 15 minutes to 4 hours, or any 1 to 1440 minutes. Without a timer, nothing changes on its own.
- **Sees your `caffeinate` sessions.** Qualifying CLI sessions show as On, with a session timer, and Turn Off stops your standalone Terminal `caffeinate` processes safely.
- **No dependencies, no network.** Swift, AppKit, SwiftUI and IOKit only. No network client, account, telemetry or cloud sync.
- **Coffee awards.** Twelve badges from 5 minutes to 365 days of one continuous session. Earned badges stay saved.

## Quick start

**Install** with Homebrew (Apple Silicon, macOS 13+):

```sh
brew install --cask harinaralasetty/tap/caffeinate-ui
```

Released as [v1.7](https://github.com/harinaralasetty/caffeinate-ui/releases/tag/v1.7); the cask lives in [homebrew-tap](https://github.com/harinaralasetty/homebrew-tap). See the note above about the first launch.

**Use** it: click the cup in the menu bar.

- **Turn On** starts system idle-sleep prevention. **Turn Off** releases everything the app holds.
- **System awake ▸** and **Display awake ▸** pick "Until turned off", a preset or a custom time.
- **Show Awards…** opens the Awards window.

A steaming cup means the app or a qualifying CLI session is keeping the Mac awake. A plain cup means neither is.

<details>
<summary><b>Build and install from source</b></summary>

<br>

Requires a **Swift 6** toolchain from Xcode or Apple Command Line Tools, plus Git and Python 3 for the scripts. Check with `xcode-select -p` and `swift --version`. The app declares macOS 13 or later; the automated suite has been run on the maintainer's Mac only, and newer Swift Testing libraries may require macOS 14 or later.

```sh
git clone https://github.com/harinaralasetty/caffeinate-ui.git
cd caffeinate-ui
./script/install.sh CaffeinateUI
```

The installer builds, verifies, installs into `/Applications` and opens Caffeinate UI. It needs write access to the destination and does not elevate privileges. For a per-user install:

```sh
CAFFEINATE_UI_INSTALL_DIR="$HOME/Applications" ./script/install.sh CaffeinateUI
open "$HOME/Applications/Caffeinate UI.app"
```

Re-running skips byte-identical bundles. Updates keep a ZIP and the prior bundle in `recovery/install-backups/` in the checkout, then verify the installed bytes. To roll back, quit Caffeinate UI and restore the matching backup bundle to the same path. Backups and build output are ignored by Git. Local bundles are ad hoc signed and verified by the scripts.

Optional login startup uses a per-user LaunchAgent, without a KeepAlive loop:

```sh
./script/install.sh CaffeinateUI --login
./script/login_items.sh status CaffeinateUI
./script/login_items.sh disable CaffeinateUI
```

Disabling startup does not quit Caffeinate UI. When moving an install, disable the old registration before installing at the new path with `--login`. A registration check does not prove success at a future login.

</details>

<details>
<summary><b>Full menu reference and Turn Off rules</b></summary>

<br>

| Control | Behaviour |
| --- | --- |
| Status heading | "Caffeinate UI: On" or "Off" |
| CLI session / Awake streak | Current elapsed time |
| Show Awards… | Opens or raises one native Awards window, with the earned count |
| Turn On | Starts system idle-sleep prevention; disabled while app or CLI activity is already On |
| Turn Off | Releases app assertions and stops verified standalone Terminal `caffeinate` sessions; disabled once fully Off |
| System awake: On/Off ▸ | Submenu for the app's system assertion: "Until turned off", 15 minutes, 30 minutes, 1 hour, 2 hours, 4 hours, Custom… (1–1440 minutes), Turn off. While a timer runs the row shows the time left (for example "System awake: On · 15 m left"), the submenu offers "Stop timer, keep on", and the menu-bar icon shows the soonest countdown. Choosing another time restarts the countdown |
| Display awake: On/Off ▸ | The same submenu for the display assertion, independent of system. When its timer ends the app releases the display and macOS sleeps it on its normal schedule; the app never changes power settings or forces display sleep |
| Other Sleep Assertions | Lists other apps' active system and display assertions |
| About / Quit Caffeinate UI | Quit releases only app assertions |

Turn Off stops standalone `/usr/bin/caffeinate` processes owned by your user and attached to an interactive shell, after rechecking executable, owner, birth time, arguments and children. Wrapped commands, `-w` job monitors, processes with children, other applications' processes and unverified detached processes are preserved. Failures name the affected PID, and remaining qualifying activity keeps steam and On visible. Detached processes need explicit authorization for their exact PID and birth time. No shell, process group or workload is terminated, and no force kill is used.

Timers apply to app assertions only, never to CLI sessions. Turn Off or toggling a control off cancels its timer, and timers are not restored on relaunch. App choices persist and restore on launch; assertion IDs are acquired afresh. Other apps may still prevent idle sleep when Caffeinate UI is Off. Keeping the system or display awake can increase battery use; enable only what your task needs.

</details>

## What it does

| Area | Details |
| --- | --- |
| **System awake** | Prevents system idle sleep, until turned off or for a timed period |
| **Display awake** | Keeps the display on, independent of the system control |
| **Auto-off timers** | 15 m, 30 m, 1 h, 2 h, 4 h or custom 1–1440 minutes, per control, with a countdown in the menu bar |
| **CLI sessions** | Detects running `caffeinate` system (`-i` or default) and display (`-d`) assertions and times the current session |
| **Safe Turn Off** | Stops only verified standalone Terminal `caffeinate` processes you own |
| **Other assertions** | Shows which other apps are keeping the system or display awake |
| **Awards** | Twelve badges for one continuous session, from 5 minutes to 365 days, saved locally |
| **Login startup** | Optional per-user LaunchAgent when installed from source |

## Supported macOS versions

| Platform | Status |
| --- | --- |
| macOS 13 Ventura or later, Apple Silicon | Homebrew release v1.7 (unsigned) |
| macOS 13 or later, build from source | Requires a Swift 6 toolchain |
| Intel / universal | Not built or tested |

## How it works

Caffeinate UI creates and releases its own IOKit power assertions, the same mechanism `/usr/bin/caffeinate` uses, and reads the system's active assertion list once per second.

- It releases only assertion IDs it created. Quit releases them; it never calls `pmset` or forces sleep.
- A qualifying CLI session is a `caffeinate` assertion of the system or display type. `-u`, `-m` and other apps do not count; `-s` counts only on AC power.
- Award time is one continuous interval. Earlier time of a still-running CLI session counts and **may include system sleep**; overlapping sessions count once.

More detail in the [architecture and contribution guide](ARCHITECTURE.md).

<details>
<summary><b>Award timing rules</b></summary>

<br>

Caffeinate UI samples qualifying CLI assertions once per second. System idle-sleep (`-i` or default) and display idle-sleep (`-d`) count. Timed `-t` and watched-process `-w` sessions stop qualifying when their assertions expire. User-active `-u`, disk-only `-m`, and unrelated apps do not earn awards. `-s` counts only on AC power and gets no historical credit by itself because earlier AC conditions are unknown.

An active assertion with a macOS start timestamp and global ID can recover its earlier duration, **including possible sleep**, and that time counts toward awards. The app reconciles one continuous interval by elapsed coverage, not by adding simultaneous sessions. Saved interval claims match both identity and start timestamp; observed overlaps survive relaunch while an associated assertion is still active. Repeated opens, polling and relaunches do not multiply time or duplicate earned IDs. A restarted, non-overlapping CLI identity starts a fresh interval. Closed process history is not restored. Missing metadata falls back to time observed by the app; future dates get no earlier credit.

App-only progress resets when no qualifying activity remains, on quit or relaunch, or on system sleep. A still-running CLI session can recover its interval after relaunch or sleep. Calendar changes do not advance an anchored interval, and a detected clock jump prevents a new historical anchor. Display sleep and screen locking do not reset app-only progress. Earned awards stay saved, and no unlock dates are made up.

| Award | Session threshold |
| --- | --- |
| First Sip | 5 minutes |
| Espresso Yourself | 1 hour |
| Just One More Cup | 4 hours |
| The Daily Grind | 8 hours |
| Certified All-Nighter | 24 hours |
| Decaf Is a Myth | 3 days |
| Sleep Is a Rumor | 7 days |
| Bean There, Done That | 14 days |
| Your Mac Is Legally a Café | 30 days |
| Roast Level: Critical | 60 days |
| Head Barista | 90 days |
| Caffeine Overdose | 365 days |

A day is 24 hours. The [badge catalog](CaffeinateUI/Resources/Badges/catalog.json) defines the ordered thresholds and artwork; the [badge gallery](CaffeinateUI/Resources/Badges/README.md) shows all twelve images.

</details>

## Screenshots

The Awards window above and the timer closeup below are from the installed 1.5 app, captured on 10 October 2026. Five awards came from a qualifying CLI session of about 2 days 16 hours; that time may include system sleep, so it is not proof of continuous awake time. Only app content is shown. The current 1.7 menu has not been captured yet.

<img src="docs/screenshots/timer.jpg" alt="Awards window header: 5 of 12 earned, CLI session 2d 15:56:29, with the note that earlier CLI time may include sleep and overlaps count once" width="720">

All twelve award assets with their catalog labels, rendered from the real PNG files:

<img src="docs/screenshots/all-awards.jpg" alt="Grid of all twelve Caffeinate UI coffee award badges with names and thresholds, from First Sip at 5 minutes to Caffeine Overdose at 365 days" width="720">

## FAQ

**How is this different from running `caffeinate` in Terminal?** It uses the same kind of assertion, but gives you separate system and display controls, auto-off timers, a view of running `caffeinate` sessions and a safe way to stop them from the menu bar.

**Will it keep my Mac awake with the lid closed?** No. It prevents idle sleep only. Lid closure, low battery, forced sleep and macOS power policy can override it.

**Does it watch or restart my agents?** No. It does not supervise or restart processes, prevent crashes or network outages, or guarantee a job finishes.

**Why does macOS warn me on first launch?** The build is not signed with a Developer ID or notarized. Use System Settings > Privacy & Security > "Open Anyway", or build from source.

**Does it send data anywhere?** No. It has no network code. It reads local power-assertion data and stores app choices, earned award IDs and CLI interval claims in local UserDefaults. The build and install scripts use local tools only; cloning from GitHub is the only network step.

**Is it the same as the `caffeine` cask?** No. That is a different app from another developer. This cask is `harinaralasetty/tap/caffeinate-ui` and installs `Caffeinate UI.app`; it declares a conflict with the `caffeine` and `domzilla-caffeine` casks.

## Documentation

- [Architecture and contribution guide](ARCHITECTURE.md): file map, invariants, diagnostics
- [Homebrew distribution notes](distribution/README.md): signing decision and pending release checks
- [Badge gallery](CaffeinateUI/Resources/Badges/README.md) and [badge catalog](CaffeinateUI/Resources/Badges/catalog.json)

<details>
<summary><b>Upgrading from the old <code>Caffeine.app</code></b></summary>

<br>

The rename keeps `personal.harinaralasetty.Caffeine` as the bundle identifier and the original login-job label, so existing awards and settings survive. The source installer backs up and migrates this project's old `Caffeine.app` only after checking its identity, and updates an already configured login job to `Caffeinate UI.app`. Another vendor's bundle is never overwritten.

Still pending for the Homebrew release: clean-system install, upgrade and uninstall tests, and Intel support. Developer ID signing and notarization remain optional future work.

</details>

## Contributing

Build and test:

```sh
./script/build_and_run.sh CaffeinateUI --build-only
./script/test.sh
python3 script/audit_source.py
```

The build creates `dist/Caffeinate UI.app` and does not launch or quit apps. `./script/test.sh` runs 38 Swift tests and a packaged self-test (real assertion acquire/release, ownership cycles, image decoding, simulated clocks, persistence, CLI overlap/restart, menu state and safe test-owned CLI termination). `./script/test.sh --no-display` runs 37 tests and skips real display assertions and the packaged self-test. Tests use isolated defaults and never touch real award storage or existing CLI processes. Regenerate the badge preview with `python3 script/generate_badge_preview.py`; `--check` detects catalog drift.

Real system sleep, login cycles and AC/battery switching are manual checks. Automated tests do not certify every macOS version or hardware configuration. See the [architecture guide](ARCHITECTURE.md) for invariants. Production code has no third-party dependencies.

Report reproducible issues in [Caffeinate UI issues](https://github.com/harinaralasetty/caffeinate-ui/issues) with your macOS version, toolchain version, any errors, and whether app-owned or CLI activity was involved. Check screenshots and logs for private information before posting. Maintained by [Hari Naralasetty](https://github.com/harinaralasetty).

## License

[MIT](LICENSE)
