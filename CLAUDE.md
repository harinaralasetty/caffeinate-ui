# Caffeinate UI: project memory

Read this first. Details live in README.md, ARCHITECTURE.md and distribution/README.md.

## Hard rules
- Use only the GitHub account `harinaralasetty` for this repo and its tap. Run `gh api user --jq .login` before any release, repo or push action, and stop if it differs. If `gh` lists other accounts, do not use them.
- Git identity is the personal noreply address already configured in this repo. Do not change it.
- Ask before: publishing releases or repos, deleting files, committing or pushing, changing the installed app in /Applications.
- Never bypass Gatekeeper or strip quarantine (no `xattr` tricks, no cask postflight hacks).
- Keep bundle ID `personal.harinaralasetty.Caffeine` and the legacy award id `legally-an-espresso-machine`; they preserve users' awards and settings.

## What it is
Swift 6 / AppKit / IOKit macOS menu-bar app (macOS 13+, arm64 builds). Manages idle-sleep assertions, shows CLI `caffeinate` sessions, 12 coffee awards. Targets: `CaffeinateUICore` (Core), `CaffeinateUI` (Sources), `CaffeinateUICoreTests` (Swift Testing).

## Current state (11 Oct 2026)
- Version 1.7 (build 8). Released as GitHub release v1.7 (unsigned arm64 zip). MIT licensed.
- Optional auto-off timers for system and display (`Core/AwakeTimers.swift`; presets 15m/30m/1h/2h/4h/custom 1-1440 min; expiry releases only that mode; display timer just lets macOS sleep it normally; timers are not kept across relaunch).
- Menu: `System awake` and `Display awake` submenus (built once, updated in place so they do not collapse), Turn On/Off master items, countdown in status line and next to the menu-bar icon.
- Last verified: `./script/test.sh` passes (38 tests plus packaged self-test) on the Mac. The redesigned menu was NOT visually verified by Claude; the user tests the 1-minute custom timer by hand.

## Homebrew
- Tap: https://github.com/harinaralasetty/homebrew-tap, cask `caffeinate-ui`. Install: `brew install --cask harinaralasetty/tap/caffeinate-ui`.
- Unsigned, not notarized (no Developer ID, $99/yr, user declined for now). First launch needs System Settings > Privacy & Security > Open Anyway. Cask caveat and README say so.
- Not done: clean-Mac install/upgrade/uninstall test, `brew audit`, Intel build, immutable-releases setting.
- Release recipe (new version vX): bump APP_VERSION/APP_BUILD in script/build_and_run.sh, run tests, commit and push, `./script/build_and_run.sh CaffeinateUI --release-build-only`, `ditto -c -k --keepParent "dist/Caffeinate UI.app" dist/release/Caffeinate-UI-X.zip`, `shasum -a 256`, `gh release create vX <zip> -R harinaralasetty/caffeinate-ui --target <sha>`, then update version and sha256 in the tap's `Casks/caffeinate-ui.rb` and push. Never replace an already-released asset; ship a new version.
- A source-build formula (free, no Gatekeeper warning, needs Swift toolchain) was discussed but not built.

## How to work here
- Run tests: `./script/test.sh` (about 100 s). Install locally: `./script/install.sh CaffeinateUI` (backs up the old app into recovery/install-backups, relaunch afterwards).
- Claude's cloud sandbox has no Swift. Run commands on the Mac through the Desktop Commander tools in the linked session (shell is zsh). Long calls time out at about 60 s: start in the background or poll with read_process_output.
- SSH to GitHub may not work from that shell; push over HTTPS with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push https://github.com/harinaralasetty/<repo>.git main`.
- script/test.sh must stay bash 3.2 compatible (macOS /bin/bash): empty arrays use `${arr[@]+"${arr[@]}"}`.
- Swift 6: test functions calling `@MainActor` code need `@MainActor`.

## Open items (all need the user's OK first)
- Stale artifacts: `dist/Caffeine.app` (old v1.3, same bundle ID), probe apps, `.build/caffeine-*-probe*`, about 14 old backups in `recovery/install-backups` (about 397 MB), MicMute leftovers (`MicMute/`, `script/test_micmute.py`, `verification/micmute-*`, MicMute README link).
- 12 badge PNGs are 1254x1254 (about 19 MB); could shrink to 512 px (approved artwork; would need a new release).
- Minor: hard-coded "Twelve milestones", low-contrast green "Earned" text, `install.sh` cross-volume rename edge case, `generate_icon.swift` lacks a documented `iconutil` step, bundle identifier repeated across scripts.
- `verification/run-checks.command` is a leftover from a Finder workaround (gitignored dir); safe to delete.
