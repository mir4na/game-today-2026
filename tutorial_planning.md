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

2. **Opening cutscene**
   - The normal Day 1 intro and station boarding cutscene plays.
   - When gameplay begins, tutorial guidance appears.

3. **Angel briefing**
   - A dimmed overlay and bottom instruction panel explain the premise:
     - the protagonist died before a job interview;
     - the Angel gives them a second chance as an intern conductor;
     - doing the job well matters.

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
   - Tutorial text explains checking the visible passenger, ID, ticket date, train number, and destination.

7. **Stamping**
   - Tutorial explains that the correct station stamp is permanent.
   - Player stamps a ticket and closes the document UI.

8. **Guidebook**
   - Player opens the Guidebook from the lower-left button or by pressing `Tab`.
   - Tutorial explains:
     - Today’s Service shows route/threshold progress;
     - Rules explains scoring;
     - Anomaly Signs helps identify passengers to keep aboard for Night Service.

9. **Newspaper clue**
   - Player reads the morning newspaper.
   - Tutorial explains that the newspaper can reveal an anomaly if it names someone aboard as already dead.

10. **Day service sign-off**
    - Player uses the service action button above the Guidebook.
    - The signature UI opens.
    - Player traces the mark.
    - If accepted, the train fast-forwards to the next station.
    - Tutorial then lets the player finish the rest of day service normally.

11. **Terminal transition and Night Market**
    - At the terminal, daylight service ends.
    - Paycheck appears.
    - The train enters fog/whiteout.
    - Night Market opens during the whiteout.
    - Tutorial explains Veil Note, Radar, and Swiftstep Soles with current price/stock rules.

12. **Night Service**
    - After the market, the train exits the fog at night.
    - Player inspects remaining souls.
    - Correct hidden statements are pulled into the ledger.
    - The ledger starts empty and fills only when the player finds statements.

13. **Station path assignment**
    - Player opens the station path/ledger button.
    - Player drags found souls from the ledger to stations.
    - One station can hold more than one soul; some stations can remain empty depending on the puzzle.
    - Player finalizes assignments and sees scan/paycheck feedback.

## Implementation status

The current implementation uses `TutorialDirector` as an in-game overlay that listens to tutorial events emitted by `main.gd`. It pauses route time during the onboarding portion, then releases normal day progression after the first successful service sign-off.
