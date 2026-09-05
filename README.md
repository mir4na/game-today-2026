# Where Do You Belong? — Godot 4.7 Vertical Slice

Playable 2D side-view mystery/deduction prototype. The conductor explores a continuous train populated by passengers with varied ambient behavior, checks ID cards and tickets, stamps living passengers for the correct stops, retains suspected anomalies for night service, then solves their night-station assignments.

## Run

Open this folder in Godot **4.7** and press **F6/F5**, or run from a terminal:

```bash
godot --path .
```

The configured entry scene is `res://scenes/menu/main_menu.tscn`. Choose **New Game** for Day 1, or **Continue — Day X** to resume the saved day from its beginning. New Game replaces the previous run. The player starts in the front passenger coach. After the day title and opening boarding cinematic, inspect IDs and tickets, stamp living passengers for their required stops, and retain anomalies for night service.

The paycheck awards **30 Blessings per correct living-passenger drop-off**, deducts **20 per wrong drop-off** regardless of distance, and deducts **40 per incorrectly stamped anomaly once per passenger per day**. Removing or repeating that stamp does not erase or multiply the penalty. Safely retained anomalies have no daylight bonus or penalty. Anomalies remain aboard for night service. No other daylight penalty categories are charged.

**Net earnings** are compared with the day's target, independently of the saved wallet balance. Initial targets for Days 1–5 are **100 / 120 / 140 / 160 / 180**, configurable through Main → Day Progression → Day Pass Targets. The day intro also shows the target. PASSED pays the shift's net earnings and opens the Night Market; FAILED pays nothing and offers Restart Shift or Main Menu. Negative net earnings remain visible without taking previous days' savings. There are no strikes, warnings, or dropouts.

Progress checkpoints contain the day, manifest seed, and starting Blessings/supplies/upgrades in `user://shift_progress.cfg`. Restart Shift and menu Continue restore that day-start checkpoint, including undoing the current attempt's purchases and rewards. They do not resume the exact mid-shift position or station. Completing the night saves the next day's inventory and seed. Day 5 ends the journey; the completed run can be replaced with New Game. Market prices and night rewards remain separately configurable.

Run the paycheck and progress integration checks using an isolated save directory:

```bash
XDG_DATA_HOME=/tmp/where-do-you-belong-tests godot --headless --path . --script tools/test_shift_progress.gd
```


The newspaper can be read repeatedly. Its edition is rolled once per playthrough and remains unchanged when reread. Collected articles and inspected document summaries are copied into the conductor's guidebook alongside dynamic service data, operating rules, and the anomaly catalogue.

The game launches fullscreen by default. The main menu contains Start, Settings, and Quit; Settings can switch back to Windowed and persist master volume, display mode, and VSync in `user://where_do_you_belong_settings.cfg`. The gameplay pause screen also provides a Main Menu button.

## Controls

| Input | Action |
|---|---|
| `A` / `D` or Left / Right | Walk horizontally |
| `E` | Use the nearest contextual interaction |
| `Tab` | Open/close the conductor's guidebook |
| `Esc` | Close the active UI or pause |
| Mouse / keyboard focus | Inspect documents and select passengers, tools, or night stations |

## Scene structure

```text
MainMenu                         application entry
├── Start                       transitions to gameplay
├── Settings                    audio/display settings
└── Quit

Main                             gameplay scene
├── Train                         one continuous 4,800 px level, moving left
│   ├── PassengerCoach4..1       modular cutaway coach scenes
│   └── ExteriorSequence         scene-authored station transition controller
├── Passengers                   data-generated passenger roster; replacements board during station exchanges
├── Player                       CharacterBody2D + Camera2D + final conductor texture
├── TrainAmbience                procedural rail/night ambience
├── HUD                          duties, live passenger-dot minimap, prompt, clock, notifications
└── ModalLayer
	├── DayIntroUI                 full-black DAY 1 fade title card
    ├── DocumentOverlayUI        ID and ticket documents; newspaper/statement reader
    ├── GuidebookUI             daily service, procedures, records, evidence, anomalies, night rules, and tools
    ├── StationStopCutsceneUI    letterbox + passenger staging over the gameplay camera
    ├── ShiftReportUI            receipt, net earnings, daily target, PASSED/FAILED, retry/menu actions
    ├── NightMarketUI            tools purchased with Blessings before night service
    ├── NightPuzzleUI            deceased-passenger/night-stop clue board
    ├── DepartureSequenceUI      four-station ending sequence
    └── PauseUI
```

Reusable world scenes live in `scenes/train`, `scenes/player`, `scenes/passengers`, and `scenes/interactables`. UI screens live in `scenes/ui`; the ending presentation lives in `scenes/night`.

Every static hierarchy and visual is scene-owned: menu panels and backdrop, HUD widgets, modal layouts, manifest rows, report cards, night-puzzle slots, train bodies, carriage interiors, cutscene actors, player/passenger visuals, interactable art, and minimap slots are visible and editable through `.tscn` nodes or scene-assigned textures. Button signals, focus neighbors, initial visibility/process modes, prompt copy, themes, colors, and audio-stream configuration are stored in scenes/Inspector data. Scripts bind those scene nodes and update runtime state only. Runtime `add_child()` is reserved for passenger instances created from the `passenger_scene` PackedScene assigned on `Main` in the Inspector.

## Main scripts

- `scripts/menu/main_menu.gd` binds the scene-authored responsive menu, applies and saves settings, and transitions into gameplay.
- `scripts/main/main.gd` owns the `OPENING → DAY → SUNSET → SHIFT_REPORT → MARKET → NIGHT → NIGHT_PUZZLE → COMPLETE` state flow, the configured daytime route and travel duration, repeated exit assignments, station exchanges, cutscenes, live minimap population, penalties, Blessings rewards, time, and validation.
- `scripts/systems/market_tool_state.gd` owns the Inspector-configured Blessings balance, daylight/night reward rates, penalty deductions, purchases, consumables, and speed upgrade inventory.
- `scripts/player/player.gd` handles horizontal `CharacterBody2D` movement, camera follow, facing, and nearest-interactable selection.
- `scripts/train/carriage.gd` and `scripts/train/train.gd` animate the scene-authored modular carriages, day/night overlay, underframe, and train sway; their geometry and palette live in train scenes and assigned SVG textures.
- `scripts/passenger/passenger_data.gd` is the designer-facing passenger Resource. `passenger.gd` presents it, emits inspection requests, and runs the selected ambient AI profile inside safe passenger-coach boundaries.
- `scripts/systems/departure_puzzle_data.gd` stores the night-stop order, relational clues, and internal deceased-passenger solution. “Night drop-off” means the station where a deceased passenger leaves the night train; it is separate from their daytime ticket destination.
- Scripts in `scripts/ui` project state into responsive Control/Container layouts and signal decisions back to `Main`.

## Adding a passenger

1. Duplicate an `npc_*_profile.tres` file and assign its scene, portrait, gender, civil ID, birthplace, birth date, occupation, and visual color.
2. Add the profile to `passenger_identity_profiles` on `Main`, then update `total_passenger_count` in `DailyManifestConfig`.
3. Add enough unique names to the matching Victorian gender pool. Names, routes, tickets, carriage, life state, anomaly, and AI behavior are assigned at runtime.
4. Keep the opening roster at no more than 10 and the active deceased roster at no more than 4.

The runtime never writes into passenger Resources, so the same data can safely be reused by UI and visual nodes.

The current roster contains 17 unique visual profiles: NPC 1, 3, 4, 6, 7, 9, 11, 14, 15, and 17 are female; the remaining profiles are male. NPC 18 was removed because it duplicated NPC 10.

### Document formats

- Identity numbers use `CID-0001`: the `CID` document prefix followed by a stable four-digit identity serial.
- Service dates use `DD MON YYYY`, while the ticket's compact day code uses `YYMMDD`.
- Train numbers use three digits and normally match the active service configured in `DailyManifestConfig`.
- Ticket numbers use `YYMMDD-TRAIN-SERIAL`, for example `260607-505-0001`. A time-invalid ticket changes both its printed service date and the matching `YYMMDD` segment; a wrong-train boarder changes the train segment.

## Adding an anomaly

Configured deceased-anomaly values are `shadowless`, `impossible_ticket`, `unlisted_destination`, `portrait_mismatch`, `time_invalid_ticket`, and `newspaper_death`; `none` marks a normal passenger. `wrong_train_boarder` is a daytime ticket violation, not a deceased anomaly.

1. Add a new value to `anomaly_type` in `passenger_data.gd`.
2. Add only its visible/body presentation to `passenger.gd` or the relevant interactable/environment script.
3. If it produces explicit documentary evidence, record that fact in `main.gd` and display it through the scene-authored guidebook sections.
4. Do not add automatic “anomaly” labels—the player must interpret visual contradictions and public records.

## Creating another departure puzzle

Duplicate `data/puzzles/first_departures.tres`, then edit:

- `night_stations`: ordered night-train stops shown to the player;
- `night_stop_clues`: newline-separated relational clues;
- `correct_passenger_by_station`: `{ station_name: passenger_short_name }` entries.

Assign the new Resource to `puzzle_resource` on `Main`. Keep one passenger per station and make clues reference discovered properties (“without a shadow”, “impossible journey”), ordering, adjacency, or non-adjacency rather than naming a direct answer. Verify that the clues yield one solution before shipping the puzzle.

## Validation

The project was parsed and run using Godot 4.7 stable. Tests cover Main Menu → Settings → Start, the DAY 1 fade, ten-passenger Alderwick boarding, leftward departure, diverse passenger AI (including stationary, wandering, and cross-car movement), live minimap population dots, all four 60-second route legs in order, repeated proximity-based exit selection, equal exchanges at Brambleford/Cinderfield/Dunmere/Eastmere, impostors boarding from different stations, deferred penalties, paycheck results, and final night drop-offs:

```bash
godot --headless --path . --script res://tests/menu_flow_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/runtime_flow_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/performance_failure_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/station_assignment_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/newspaper_randomization_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/scene_architecture_test.gd --audio-driver Dummy
```

`scene_architecture_test.gd` additionally prevents regressions: it rejects script-created presentation nodes, `_draw()` placeholder rendering, scene preloads in behavior scripts, static signal connections made in code, unapproved `add_child()`, and any concrete Node script that is not attached to a `.tscn` scene.
