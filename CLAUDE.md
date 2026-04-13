# CLAUDE.md — YoLoIT Platform Abstraction Guide

This file is read by AI agents (Claude, Copilot) to understand how platform-specific
code is organised in YoLoIT and how to maintain it correctly.

---

## Architecture Summary

All platform-specific code lives in **`lib/core/platform/`**. Everywhere else in the
app must be platform-agnostic Dart/Flutter.

| File | Responsibility |
|---|---|
| `platform_dirs.dart` | Directories for config, data, logs, temp per OS |
| `platform_shell.dart` | Default shell + PATH enrichment per OS |
| `platform_launcher.dart` | Open URLs, reveal in file manager, open terminal |
| `platform_installer.dart` | In-app update install (download → copy → relaunch) |
| `terminal_session_backend.dart` | Abstract session backend (tmux / future ConPTY) |

Each file contains:
1. An **abstract class** defining the interface
2. A **`MacosPlatformFoo`** implementation (current, fully working)
3. A **`LinuxPlatformFoo`** implementation (working or stub)
4. A **`WindowsPlatformFoo`** implementation (mostly stubs until Windows work begins)
5. A **factory** `PlatformFoo.instance` that picks the right implementation

---

## Rules

### ✅ DO
- Put ALL `Platform.isMacOS` checks inside `lib/core/platform/` implementations
- Use `PlatformDirs.instance.configDir` instead of `$HOME/.config/yoloit`
- Use `PlatformShell.instance.enrichedPath(existing)` instead of custom PATH concat
- Use `PlatformLauncher.instance.openUrl(url)` instead of `Process.run('open', [url])`
- Use `PlatformLauncher.instance.revealInFinder(path)` instead of `open -R`
- Use `PlatformLauncher.instance.openTerminal(workdir)` instead of `osascript`
- Use `PlatformInstaller.instance` for update install/version detection
- Write a FakeProcessRunner test for every new platform operation

### ❌ DON'T
- Put `Platform.isMacOS` outside `lib/core/platform/`
- Hardcode `~/Library/Logs`, `~/.config/yoloit`, `/tmp/yoloit_*` in feature code
- Hardcode shell paths like `/bin/zsh`, `/opt/homebrew/bin` in feature code
- Call `Process.run('open', ...)`, `Process.run('hdiutil', ...)`, `Process.run('osascript', ...)` outside `lib/core/platform/`
- Put macOS-only logic in UI code

---

## How to Add a New Platform-Specific Feature

**Example: "Show desktop notification"**

1. **Add to the abstract class** in `lib/core/platform/`:
   ```dart
   // In platform_notifications.dart (new file)
   abstract class PlatformNotifications {
     static PlatformNotifications get instance { ... }
     Future<void> showNotification(String title, String body);
   }
   ```

2. **Implement for each platform**:
   ```dart
   class MacosPlatformNotifications extends PlatformNotifications {
     @override
     Future<void> showNotification(String title, String body) async {
       await Process.run('osascript', [
         '-e', 'display notification "$body" with title "$title"',
       ]);
     }
   }

   class LinuxPlatformNotifications extends PlatformNotifications {
     @override
     Future<void> showNotification(String title, String body) async {
       await Process.run('notify-send', [title, body]);
     }
   }

   class WindowsPlatformNotifications extends PlatformNotifications {
     @override
     Future<void> showNotification(String title, String body) async {
       // TODO: implement with Windows toast notifications
       throw UnsupportedError('Not implemented on Windows yet.');
     }
   }
   ```

3. **Add factory to `PlatformNotifications`**:
   ```dart
   static PlatformNotifications _create() {
     if (Platform.isMacOS) return MacosPlatformNotifications();
     if (Platform.isLinux) return LinuxPlatformNotifications();
     if (Platform.isWindows) return WindowsPlatformNotifications();
     return LinuxPlatformNotifications(); // fallback
   }
   ```

4. **Write unit tests** in `test/unit/core/platform/platform_notifications_test.dart`:
   ```dart
   test('macOS calls osascript', () async {
     final runner = FakeProcessRunner();
     final svc = MacosPlatformNotifications(processRunner: runner.run);
     await svc.showNotification('Title', 'Body');
     expect(runner.lastCall!.executable, 'osascript');
   });
   ```

5. **Use from feature code**:
   ```dart
   await PlatformNotifications.instance.showNotification('Done', 'Build succeeded');
   ```

---

## How to Add a New Platform (e.g. ChromeOS)

1. Add a new implementation class in the relevant file(s).
2. Add a check to the factory: `if (Platform.isLinux && Platform.environment.containsKey('SOMMELIER_VERSION')) return ChromeOsFoo();`
3. Write tests with `setInstance()`.
4. Add to CI matrix.

---

## `PlatformDirs` Path Parity Rules

macOS paths MUST exactly match the values that were previously hardcoded across the codebase:

| Property | Value |
|---|---|
| `configDir` | `$HOME/.config/yoloit` |
| `logsDir` | `$HOME/Library/Logs/yoloit` |
| `dataDir` | `$HOME/Library/Application Support/yoloit` |
| `tempDir` | `Directory.systemTemp.path` (i.e. `/var/folders/.../...`) |

**Do NOT change these paths** — doing so will break existing installations that
have config files at the old locations.

---

## `PlatformShell` PATH Enrichment

When running tools from a Flutter macOS app, the process environment is minimal
(no shell profile sourced). `PlatformShell.instance.enrichedPath()` prepends:
- `/opt/homebrew/bin` + `/opt/homebrew/sbin` — Apple Silicon Homebrew
- `/usr/local/bin` — Intel Homebrew / manual installs
- `~/.local/bin` — user local tools
- `~/development/flutter/bin` + `~/flutter/bin` — Flutter SDK (common install locations)

**Do NOT** inline these paths in service code — always call `PlatformShell.instance.enrichedPath(existing)`.

`setup_check_service.dart` has additional extended PATH logic (NVM, Volta, pyenv,
cargo) that is intentional and kept separate since it is only used for tool-presence
detection, not for launching agent sessions.

---

## `TerminalSessionBackend` Extension

The tmux backend (`TmuxService`) is used on macOS and Linux.
The Windows ConPTY backend stub (`ConPtySessionBackend`) is in `terminal_session_backend.dart`.

To implement Windows ConPTY:
1. Create `lib/core/platform/conpty_session_backend.dart`
2. Implement `TerminalSessionBackend` using the `dart_process_run` or a ConPTY
   native plugin
3. Replace `ConPtySessionBackend` stub in `terminal_session_backend.dart` with a
   `ConPtyTerminalSessionBackend` class that imports the new file
4. Update `PlatformDirs.instance` in Windows to provide correct paths
5. Write unit tests (mock the native process bridge)

---

## PR Checklist for Platform Code

Before merging any change that touches `lib/core/platform/`:

- [ ] New/changed platform operations have a unit test using `FakeProcessRunner`
- [ ] macOS paths still match the parity table above (no path changes)
- [ ] `flutter analyze --no-pub` reports 0 errors
- [ ] `flutter test test/unit/core/platform/` passes 100%
- [ ] `flutter test test/unit/` passes 100%
- [ ] No `Platform.isMacOS` was introduced outside `lib/core/platform/`
- [ ] No `Process.run('open', ...)` or `Process.run('osascript', ...)` outside `lib/core/platform/`

---

## File Locations

```
lib/
  core/
    platform/
      platform_dirs.dart          ← config/data/logs/temp paths
      platform_shell.dart         ← shell + PATH enrichment
      platform_launcher.dart      ← open URL/file/terminal
      platform_installer.dart     ← in-app update install
      terminal_session_backend.dart ← tmux / ConPTY abstraction

test/
  helpers/
    fake_process_runner.dart      ← FakeProcessRunner (used by all platform tests)
  unit/
    core/
      platform/
        platform_dirs_test.dart
        platform_shell_test.dart
        platform_launcher_test.dart
        platform_installer_test.dart
        terminal_session_backend_test.dart
```
