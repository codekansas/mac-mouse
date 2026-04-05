# MacMouse

Minimal macOS utility for mapping extra mouse buttons to:

- Mission Control
- Move Left a Space
- Move Right a Space

It also smooths mouse-wheel scrolling by replacing raw wheel ticks with eased pixel scroll events.

## Run

```bash
swift run MacMouse
```

MacMouse opens its setup window on launch, then stays available from the menu bar as `🐭`.

## CI and Releases

- Pull requests and pushes run the `unit-tests` GitHub Actions workflow.
- `master` is configured to require the `unit-tests` check before merging pull requests.
- Published GitHub Releases run the `release` workflow, which builds a `.app`, packages a `.dmg`, and uploads the `.dmg` plus a SHA-256 checksum to the release.
- If GitHub Actions has `APPLE_DEVELOPER_ID_APPLICATION_P12`, `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, and `APPLE_TEAM_ID` configured, the release workflow signs the app with Developer ID, notarizes the `.app` and `.dmg`, and staples the notarization tickets.
- Without that Apple signing configuration, the workflow falls back to ad-hoc signing, and macOS will still warn that downloaded builds can't be verified.

## Permissions

MacMouse needs:

- Accessibility access to trigger Mission Control shortcuts.
- Input Monitoring access to capture extra mouse buttons and scroll-wheel input.

## Notes

- Primary and secondary mouse buttons are never assignable.
- Assigning a button to one action automatically removes it from any other action.
- Non-trackpad scroll-wheel input is smoothed automatically while MacMouse runs.
- Space switching uses the real Mission Control keyboard shortcuts, so the usual macOS slide animation is preserved. If you customize those shortcuts in macOS, MacMouse follows the configured shortcut when it is present in the symbolic hotkey settings.
