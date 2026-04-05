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

MacMouse opens its setup window on launch, then stays available from the menu bar as `MM`.

## CI and Releases

- Pull requests and pushes run the `unit-tests` GitHub Actions workflow.
- To make tests actually block merges, mark the `unit-tests` check as required in your GitHub branch protection or ruleset.
- Published GitHub Releases run the `release` workflow, which builds a `.app`, packages a `.dmg`, and uploads the `.dmg` plus a SHA-256 checksum to the release.
- Release artifacts are ad-hoc signed in CI. Without a paid Apple Developer ID certificate and notarization, macOS will still treat downloads as coming from an unknown developer.

## Permissions

MacMouse needs:

- Accessibility access to trigger Mission Control shortcuts.
- Input Monitoring access to capture extra mouse buttons and scroll-wheel input.

## Notes

- Primary and secondary mouse buttons are never assignable.
- Assigning a button to one action automatically removes it from any other action.
- Non-trackpad scroll-wheel input is smoothed automatically while MacMouse runs.
- MacMouse drives the standard Mission Control keyboard shortcuts, so those shortcuts should stay enabled in macOS settings.
