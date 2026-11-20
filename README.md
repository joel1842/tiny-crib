# tiny-crib

A tiny Liquid Glass cribbage overlay that sits in the bottom-left corner of your Mac, played entirely from the keyboard against the computer. Cuts and scoring are automatic, and a crib board is a keypress away. Games run to 121. Needs macOS 26 or later.

## Run

```sh
swift run Cribbage
```

Or build a standalone app (no Dock icon) into `dist/Cribbage.app`:

```sh
scripts/bundle.sh
open dist/Cribbage.app
```

## Keys

| Key | Does |
| --- | --- |
| ⌃⌥C | Focus the overlay from anywhere (press again to hand focus back) |
| ⌃⌥H | Hide or show the overlay from anywhere |
| ⌘H | Hide the overlay while it's focused |
| 1–6 | Pick the two cards for the crib (press again to unpick) |
| ⏎ | Send the picked cards to the crib, step through the counting, start the next hand |
| 1–4 | Lay that card during the play |
| Click | Cards and the ⏎ hints are clickable too |
| B | Show or hide the crib board |
| ⌘N | New game |
| Esc | Hand focus back to the app you were in |
| ⌘Q | Quit |

The overlay starts in the bottom-left corner. Drag the handle at the top (or the background) to move it; it reopens wherever you left it. Running `open dist/Cribbage.app` while it's hidden brings it back. The game carries on where you left it.

## Checks

```sh
swift run CribbageChecks
```

Runs the scoring and game-flow checks plus 60 computer-vs-computer games. It's a plain executable because the Command Line Tools ship without a working XCTest or Swift Testing.

The Command Line Tools also lack the SwiftUI macro plugin, so views can't use `@State`. Entrance animations hang off `GameController.hasEntered` instead.

Liquid Glass only renders on screen, so offscreen renders come out blank. To check UI changes, run the app in demo mode, where it plays itself (deal, crib, cut, play, count) from a fixed seed, and screenshot its window:

```sh
dist/Cribbage.app/Contents/MacOS/Cribbage --demo 7
```

Glass cards break when an animation rotates them or fades them in or out, so moving glass cards only use offset and scale. The cut animation draws plain cards and swaps to the glass starter once it settles.
