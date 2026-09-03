# Notch Launcher — Quickshell config

A light-mode (white / black / `#aaaaff`) notch at the top of the screen that
shows the date and time, and expands into an app launcher on hover.

## Behavior

- **Hover** the notch → it expands into a search box + app list.
- It **stays expanded** even if you move the mouse away or click somewhere
  else on the desktop (clicks outside the notch pass straight through to
  whatever's underneath — the notch doesn't grab the whole screen).
- It **only closes** when you press **Escape** or **launch an app**.
- **F8** also toggles it open/closed, from anywhere (see KDE setup below).
- The search field **autofocuses** as soon as it opens, whether opened by hover or F8.
- A small **mic icon** sits at the left of the clock (collapsed pill) and
  next to the clock in the expanded header, reflecting your default
  microphone's mute state live and giving a quick pulse whenever you
  toggle it. Uses PipeWire, so it just works if that's what's driving your
  audio (it is, on virtually every modern distro).
- Switching **KDE virtual desktops** briefly swaps the collapsed pill's
  clock for a row of dots (current desktop highlighted) for about 1.4
  seconds, then it fades back to the clock. Reads KWin's own D-Bus
  interface — see the Notes section below for requirements/caveats.
- Four small buttons in the top-right of the expanded panel — **lock**,
  **log out**, **restart**, **shut down** — make up a power menu.
- **Every power button requires confirmation.** Tapping one swaps the
  search box and app list for a "Restart the system?" (etc.) panel with
  **Cancel**/**Confirm** buttons; nothing happens until you hit Confirm.
  **Escape** or **Cancel** backs out with no side effects and returns you
  to the app list.

## Install

1. Copy this folder to `~/.config/quickshell/notch-launcher/`
   (or any name you like — it just needs to be a subfolder of
   `~/.config/quickshell/` containing `shell.qml`).

   ```bash
   mkdir -p ~/.config/quickshell
   cp -r quickshell-notch-launcher ~/.config/quickshell/notch-launcher
   ```

2. Run it:

   ```bash
   qs -c notch-launcher
   ```

   or, if you want it to be your default config, put `shell.qml` directly
   in `~/.config/quickshell/` instead of a subfolder.

3. **Autostart on login (KDE):** System Settings → Autostart → Add →
   Application, point it at a small script or directly at:

   ```
   qs -c notch-launcher
   ```

   (Or use System Settings' "Login script" option if you prefer a shell
   script wrapper.)

4. **F8 hotkey (KDE, or any DE):** the shell exposes an IPC target
   (`notch`) instead of a compositor-specific shortcut API, since
   `GlobalShortcut` only works on Hyprland. On KDE:

   1. Open **System Settings → Shortcuts → Custom Shortcuts**.
   2. **Edit → New → Global Shortcut → Command/URL**.
   3. Set the trigger to **F8**.
   4. Set the command to:

      ```
      qs ipc -c notch-launcher call notch toggle
      ```

   That's it — F8 now runs this command, which flips the shared
   `LauncherState.open` toggle that every monitor's notch listens to.

   You can test it manually from a terminal first:

   ```bash
   qs ipc -c notch-launcher call notch toggle   # open/close
   qs ipc -c notch-launcher call notch open      # force open
   qs ipc -c notch-launcher call notch close     # force close
   ```

   This approach is compositor-agnostic — the same `qs ipc ... call notch
   toggle` command works identically under GNOME, sway, Hyprland, etc.,
   you'd just bind it through whatever that DE's shortcut settings are.

## Files

- `Theme.qml` — the color palette (white/black/`#aaaaff`) and sizing tokens.
  Tweak this to restyle everything at once.
- `Notch.qml` — the actual panel: collapsed clock pill, hover-to-expand
  logic, search field, app list, and the power menu's confirmation flow.
  One instance is created per monitor.
- `PowerButton.qml` — the small round icon button used for the four power
  menu entries (lock/log out/restart/shut down) in `Notch.qml`'s header.
- `LauncherState.qml` — tiny shared singleton so the F8/IPC toggle can
  open every monitor's notch together.
- `AppUsage.qml` — tiny shared singleton that counts app launches and
  persists them to disk, so the launcher can sort most-used apps first.
- `AppCatalog.qml` — shared, lazily-built desktop-entry index; avoids
  rebuilding and resorting the complete app list for every monitor and
  search keystroke.
- `Mic.qml` — tiny shared singleton exposing the default microphone's live
  mute state, via Quickshell's built-in PipeWire service.
- `MicIndicator.qml` — the small mic icon itself (used in both the
  collapsed pill and the expanded header), with its pulse-on-toggle
  animation.
- `Workspaces.qml` — tiny shared singleton exposing the current/total KDE
  virtual desktop count, read from KWin over D-Bus and pushed on change
  (not polled).
- `shell.qml` — entry point, wires `Notch.qml` up to every connected
  screen and registers the `notch` IPC target used by F8.

## Notes / tweaking

- **Shape**: the pill floats `Notch.topGap` (8px) below the screen edge,
  is fully rounded (stadium-shaped) when collapsed, and settles to a
  normal rounded rect when expanded, with a 1.5px dark outline —
  matching a typical floating menu-bar look.
- **Sizes**: `Theme.collapsedWidth/Height` and `Theme.expandedWidth/Height`
  control the pill size in both states.
- **Search**: matches against app name only (descriptions are ignored).
  Press Enter to launch the top result.
- **Ordering**: your most-launched apps float to the top, ties broken
  alphabetically. Usage counts persist across restarts in
  `~/.local/state/notch-launcher/usage.json` (see `AppUsage.qml`).
- **Scroll**: the app list always resets to the top when the notch closes,
  however it was closed (Escape, launching an app, or F8).
- Requires the app being pressed to have a valid `.desktop` entry (i.e. it
  shows up in a normal app menu) — Quickshell reads these the same way any
  other launcher does.
- **Power menu commands**: lock uses `loginctl lock-session`, restart uses
  `systemctl reboot`, shut down uses `systemctl poweroff`, and log out uses
  `loginctl terminate-session "$XDG_SESSION_ID"`. These are plain systemd
  commands so they should work unmodified on most setups, but log out in
  particular is somewhat DE/compositor-dependent — if it doesn't behave the
  way you want, swap the `logout` entry in `Notch.qml`'s `powerCommands` for
  something more specific to your session, e.g. `["hyprctl", "dispatch",
  "exit"]` on Hyprland or `["qdbus", "org.kde.ksmserver", "/KSMServer",
  "logout", "0", "0", "0"]` on KDE Plasma.
- The icons use standard freedesktop icon names (`system-lock-screen`,
  `system-log-out`, `system-reboot`, `system-shutdown`), so they'll pick up
  whatever icon theme you have installed (Breeze, Adwaita, Papirus, etc.).
- **Mic indicator**: needs a PipeWire-based audio stack (the default on
  basically every current distro/DE, KDE included) and a default input
  device to track. If you have no mic connected at all, the icon just
  doesn't take up any space rather than showing a stale state.
- **Workspace indicator**: reads KWin's `org.kde.KWin.VirtualDesktopManager`
  D-Bus interface, needs `qdbus` (or Plasma 6's renamed `qdbus6`) and
  `dbus-monitor` on your `$PATH` — both are standard dbus/Qt tooling that
  ships with any Plasma session, so this should work out of the box on
  KDE. On a non-KDE compositor (Hyprland, sway, GNOME, ...) the query
  simply fails and the flash never fires; nothing else is affected. If
  your Plasma version's D-Bus surface differs from what's expected, you
  can sanity-check the calls yourself and adjust `Workspaces.qml`'s
  `script` property to match:

  ```bash
  qdbus org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.current
  qdbus org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.count
  qdbus org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.desktops
  ```

  This was written and reasoned through against KWin's documented D-Bus
  surface rather than tested live against a running Plasma session, so
  treat it as a solid starting point rather than a guarantee — if the
  flash never appears, run the three commands above and compare against
  what `Workspaces.qml`'s script expects.
