# Adjustments implementation record

Source: `C:/Users/Kristian/OneDrive/Documents/Adjustments.docx`.
The document supplies the requested game changes; the original file is unchanged.
Additional user choices: three-minute matches and computer-controlled opponents
in the solo developer test.

| Requested change | Implementation and verification |
| --- | --- |
| Start the waiting-room list with one player; add real joiners | ENet registration populates the roster and world. Five-process test checks 1 → 5 members and departure removal. |
| Create a name in the main menu | Twenty-character name field persists in the local profile and appears in the roster, world, and results. |
| Play Local → Host loads the waiting room | Host creates the ENet session and opens the existing clubhouse directly. The old host placeholder screen is bypassed. |
| Show a room code at the bottom | Copyable seven-character LAN code in the room footer; Join resolves it or accepts the host IP. Address/code round trips are tested. |
| Automatic owner-only slipper pickup and colored outlines | All five characters collect their own landed slipper while moving without E. Stable member colors match the outline, name, feet ring, and roster badge. |
| Main-menu Practice option | Opens the clubhouse practice bay with three resetting cans, full throw/retrieval mechanics, and no readiness or match requirement. |
| Join with developer-mode for solo testing | Opens a one-human lobby. Ready and Start run the full map/match flow with four bots, including a bot Taya. |
| Crate-style random map selection after Start | Shared horizontal carousel spins and decelerates to the host's random choice. Three existing-art arena variants have distinct palettes and prop layouts. |
| First-game rules popup | Saved first-game flag; rules must be acknowledged before the grace period. Rules can be reopened during a match. |
| Thirty-second grace period | Separate visible 30-second countdown before the 180-second scoring timer. No tags or match points during grace. |
| Predicted trajectory / landing indicator | Colored dots and a landing crosshair while charging. Uses the projectile's launch, gravity, drag, and collision parameters. |
| Out-of-bounds penalty | Slipper is hidden and unavailable for three seconds, then restored to the owner's hand. A visible return countdown replaces Ready to Throw. |
| Hit feedback | Can flashes on impact; tagged players flash during the role transfer. The host replicates feedback state. |
| Throw cooldown indicator | Local character displays Ready to Throw, charge percentage, Slipper in Play, retrieval prompt, or the penalty countdown. |
| Lifetime local statistics | Main-menu Statistics reads saved wins, losses, successful throws, and can knockdowns. Results are recorded once per match ID. |

## Checks

- `tests/adjustments_smoke.gd`: menu, saved name, Practice, developer entry,
  one-member lobby, ready Start, carousel, tutorial flag, grace/match timing,
  four bots moving/throwing, hit scoring/flash, trajectory, out-of-bounds recovery,
  result flow, and persistent/idempotent saves.
- `tests/slipper_pickup_smoke.gd`: all five characters collect on landing while
  sprinting and walking, with ownership/range/initial-flight guards and no cooldown.
- `tests/waiting_room_smoke.gd`: three practice cans, reset, real mouse charge and
  hit, automatic pickup, divider collision from both directions, player passage,
  readiness/glow, and room boundaries.
- `tests/lan_session_smoke.gd`: one host and four separate client processes,
  actual RPC registration, membership, owner input, shared map/match progression,
  results, saved outcomes, and host/client disconnects.
- Rendered menu, statistics, Join, one/full-member lobbies, Practice, carousel,
  first-game rules, grace/active HUD, and results at 1920×1080 and 1280×720.

## Prototype boundaries

The three maps reuse existing level artwork; they are layout/palette variants,
not three newly illustrated environments. Developer/practice games do not pollute
normal LAN statistics. The concept's opening throw-off, powered throws, and
internet matchmaking are outside this adjustments list. Physical five-PC LAN
playtesting and bot balance still need human playtests; the automated network
verification uses five separate processes on one PC.
