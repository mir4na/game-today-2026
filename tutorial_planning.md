# "Where Do You Belong?" — Interactive Tutorial Plan

This tutorial is a guided run that teaches the current service loop inside the real gameplay scene. It should never describe the night map as a literal constellation; the player sees a symbolic **station path**.

## Current rules taught by the tutorial

- The Guidebook button is in the lower-left HUD.
- The service action button sits above the Guidebook.
  - Day shift: opens the sign-off signature UI to fast-forward to the next station.
  - Night shift: opens the station path and ledger UI.
- Day pass thresholds by level:
  - Level 1: 300 Blessings
  - Level 2: 350 Blessings
  - Level 3: 400 Blessings
  - Level 4: 450 Blessings
  - Level 5: 500 Blessings
- Day distractions by level:
  - Level 1: none
  - Level 2: blocked aisle only
  - Level 3: clean seat only
  - Level 4: blocked aisle + clean seat
  - Level 5: blocked aisle + clean seat
- Night anomaly counts:
  - Level 1: 3 souls
  - Level 2: 3 souls
  - Level 3: 4 souls
  - Level 4: 4 souls
  - Level 5: 5 souls
- Night reward math:
  - +100 Blessings per correctly released soul.
  - Attempt 1 has no penalty.
  - Attempt 2 onward costs -100 Blessings per extra attempt.
  - Reward cannot go below 0.
- Market prices and stock:
  - Veil Note: 200 Blessings, max stock 1.
  - Radar: 150 Blessings, max stock 3.
  - Swiftstep Soles: 75 Blessings, max stock 5.
- Swiftstep Soles make the player walk 3× faster for 10 seconds.

## Tutorial flow

1. **Main Menu**
   - Player clicks `Tutorial`.
   - The normal loading screen opens the gameplay scene with tutorial mode requested.
   - A new Day 1 run is started.

2. **Clean gameplay start**
   - The loading screen fades to black, then fades into the normal gameplay view.
   - The opening station cutscene is skipped.
   - The player spawns immediately inside a clean coach with no passengers or maintenance distractions.
   - Route time stays paused while the first tutorial instructions are active.

3. **Inspector briefing**
   - A dimmed overlay shows the angelic Inspector portrait beside a speech bubble.
   - The introduction is split across four short Continue beats:
     1. `Hello. I am the Inspector assigned to this train.`
     2. `You died before reaching your job interview. The railway is offering you a second chance.`
     3. `You will work here as an intern conductor. During the day, inspect passengers and decide who should leave at each station.`
     4. `At night, guide the souls who remain to the station where they belong. Do your work well, and this second chance is yours to keep.`
   - Space completes the current typewriter line first, then advances on the next press. Clicking `CONTINUE` follows the same behavior.

4. **Movement test**
   - Route time is paused.
   - Player movement is enabled, interaction is disabled.
   - Player must walk for 3 seconds with `A / D` or arrow keys.

5. **HUD explanation**
   - The tutorial explains the minimap, journey clock, day Blessings, and daily threshold.
   - The tutorial reminds the player that the route has stations and time matters after onboarding.

6. **Passenger inspection**
   - Interaction is enabled.
   - Player walks to any passenger and presses `E`.
   - The document UI opens.
   - Tutorial text explains checking the visible passenger, ID, ticket date, and destination.

7. **Stamping**
   - Tutorial explains that the correct station stamp is permanent.
   - Player stamps a ticket and closes the document UI.

8. **Guidebook**
   - Player opens the Guidebook from the lower-left button or by pressing `Tab`.
   - Tutorial explains:
     - Today’s Service shows route/threshold progress;
     - Rules explains scoring;
     - Anomaly Signs helps identify passengers to keep aboard for Night Service.

9. **Two-minute stamp test**
   - The Inspector announces a test, then Abby, Reff, Ratta, Denta, and Mecca spawn near the player.
   - Player stamps Reff, Ratta, and Denta; Abby and Mecca are anomalies and must remain unstamped.
   - The test lasts one clock turn, or two minutes.
   - Stamping either anomaly or running out of time clears the temporary stamps and restarts from the Inspector's test dialogue.
   - Success displays: `Good job. You are 50 percent ready to begin your internship.`

10. **Day service sign-off**
    - The service action button fades in and receives the spotlight.
    - The Inspector explains that signing lets a worker who finished early fast-forward to the next assignment.
    - Player opens Sign Service and must successfully trace the mark.
    - Brambleford is the tutorial's terminal stop, so the accepted signature starts its station sequence and continues directly into the night transition.

11. **Terminal transition, Paycheck, and Night Market**
    - At the terminal, daylight service ends.
    - Paycheck appears.
    - The Inspector explains that correct daytime work earns Blessings for useful tools.
    - Continuing the Inspector dialogue resumes the transition automatically.
    - The train enters fog/whiteout.
    - Night Market opens during the whiteout.
    - Tutorial explains that Veil Note, Radar, and Swiftstep can make the internship easier.
    - Purchases are disabled during training; the player only continues with Begin.

12. **Night Service**
    - After the market, the train exits the fog at night.
    - The Inspector welcomes the player and gives a short two-part briefing.
    - Abby's Departure Statement is already stored as the ledger example.
    - A pointer directs the player to inspect Mecca, the only soul used for this lesson.
    - The Soul Record explanation identifies the biography and its hidden Departure Statement.
    - Mecca's correct statement is highlighted red for the tutorial and unlocks after the explanation.
    - Clicking it pulls the statement into the ledger, then the Soul Record closes.
    - The Inspector spotlights the ledger/map button and asks the player to open it.

13. **Station path assignment**
    - The open map explains the station path and the two stored soul clues.
    - Player drags Abby and Mecca from the ledger to their correct stations.
    - One station can hold more than one soul; some stations can remain empty depending on the puzzle.
    - A wrong Finalize returns to the ledger explanation checkpoint while keeping the map open.
    - A correct Finalize completes the tutorial and starts a clean Day 1 run.

## Dialogue coverage notes

The tutorial dialogue should directly cover these points because they are easy to miss during first play:

- Stamps are permanent, so the player should compare the passenger body, ID, ticket date, route, and destination before stamping.
- Ordinary passengers leave during day service; suspicious/anomalous passengers should remain aboard for Night Service.
- The Guidebook is split by purpose: Today’s Service for route targets, Rules for Blessing math, and Anomaly Signs for evidence.
- The newspaper can reveal death-related anomalies that documents alone do not prove.
- The service button changes role by shift: sign-off during day, station path during night.
- At night, the ledger starts empty and only the exact hidden statement sentence clicked in a soul record is saved.
- The station path always has four stations; one station may remain empty and another can hold more than one soul.
- The first night assignment attempt is free; retries reduce the night payout.

## Scene-based dialogue markers

Every tutorial beat has its own `Marker2D` under `DialogueMarkers` in `scenes/tutorial/tutorial_director.tscn`. The runtime dialogue bubble uses the selected marker as its top-left origin. Reposition a tutorial dialogue by moving its marker in the 2D editor; the script does not contain screen coordinates. The matching guide under `DialogueFrames` controls only that beat's bubble size and the local portrait/tail pose.

| Tutorial beat | Marker | Placement purpose |
| --- | --- | --- |
| Angel briefing | `Intro` | Keeps the opening speech away from the highlighted player. |
| Movement test | `Movement` | Leaves the aisle and player visible while movement is measured. |
| Train minimap | `HudMinimap` | Avoids covering the minimap being explained. |
| Journey clock and Blessings | `HudClock` | Avoids covering the top HUD values being explained. |
| Passenger inspection | `Passenger` | Leaves the target passenger and interaction prompt visible. |
| Documents and stamping | `Documents` | Leaves the active document area readable. |
| Guidebook | `Guidebook` | Leaves the relevant guidebook page readable. |
| Newspaper | `Newspaper` | Leaves the newspaper evidence readable. |
| Service signature | `Signature` | Leaves the tracing area visible. |
| Day service handoff | `DayService` | Returns guidance to the gameplay view. |
| Night Market | `NightMarket` | Leaves the item cards and Begin action visible. |
| Night soul inspection | `NightWalk` | Leaves the soul and biography interaction visible. |
| Statement found | `NightRecord` | Leaves the Soul Record biography and red tutorial statement visible. |
| Ledger checkpoint | `NightLedger` | Leaves the highlighted ledger/map button visible and clickable. |
| Station path | `NightMap` | Leaves station nodes and drag targets visible. |

`Default` is only a fallback if a marker path is missing. The live Inspector portrait crop, bubble, tail, and text layout remain under `DialogueDock`.

## Implementation status

The current implementation uses `TutorialDirector` as an in-game overlay that listens to tutorial events emitted by `main.gd`. Dialogue is presented through a scene-authored Angel portrait/head and speech bubble, and each tutorial beat chooses a dedicated scene marker for placement. It pauses route time during onboarding, then releases normal day progression when the clean-coach introduction ends.
