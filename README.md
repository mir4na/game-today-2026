# Where Do You Belong? — Godot 4.7 Vertical Slice

Playable 2D side-view mystery/deduction prototype. The conductor explores one continuous six-car train populated by passengers with varied ambient behavior, approaches them to assign who will disembark, keeps every station exchange balanced, types the names of the dead at sunset, then solves their night-station assignments.

## Run

Open this folder in Godot **4.7** and press **F6/F5**, or run from a terminal:

```bash
godot --path .
```

The configured entry scene is `res://scenes/menu/main_menu.tscn`. Choose **Start** to load `res://scenes/main/main.tscn`. The player first spawns inside the far-left driver and conductor cab. A full-black **DAY 1** title card fades in and out, followed by the Alderwick boarding scene through the same `Camera2D` used during gameplay. A world-space exterior-body layer covers only the cutaway interior while ten starting passengers enter through doors visible in the current frame; the layer is removed after departure to reveal playable indoor space. The full daytime route is **Alderwick → Brambleford → Cinderfield → Dunmere → Eastmere**. Every leg takes exactly 60 seconds of unpaused play; the travel clock waits while a station assignment is being executed. Select exactly two passengers for the next stop; an assignment can be canceled from the same inspection panel until the station door seals it. A missed passenger remains aboard, while the delayed-stop penalty grows with the distance from their ticket destination. Each stop boards as many passengers as actually leave, up to the ten-passenger capacity. After Eastmere, the player must walk back to the front cab and interact with the visible abnormal-passenger typewriter. It provides five report rows: type one short name and press **Space** to advance to the next row. Submitted names are validated immediately before the paycheck report is calculated. Inspection, notebook, assignment, cutscene, and pause screens stop route progression so decisions can be made comfortably.

The newspaper can be read repeatedly. Its edition is rolled once per playthrough: a 50% chance names the deceased passenger tied to that evidence, while the other 50% reports an unrelated death and contains no name from the train roster. Rereading never rerolls the article, and the collected edition is copied verbatim into the notebook.

The game launches fullscreen by default. The main menu contains Start, Settings, and Quit; Settings can switch back to Windowed and persist master volume, display mode, and VSync in `user://where_do_you_belong_settings.cfg`. The gameplay pause screen also provides a Main Menu button.

## Controls

| Input | Action |
|---|---|
| `A` / `D` or Left / Right | Walk horizontally |
| `E` | Use the nearest contextual interaction |
| `Tab` | Open/close the notebook |
| `Esc` | Close the active UI or pause |
| Mouse / keyboard focus | Assign daytime exits, type manifest names, and select tabs/passengers/stations |

## Scene structure

```text
MainMenu                         application entry
├── Start                       transitions to gameplay
├── Settings                    audio/display settings
└── Quit

Main                             gameplay scene
├── Train                         one continuous 4,800 px level, moving left
│   ├── ConductorCar             far left/front spawn; passenger-coach body, driver controls, route clock, and abnormal-passenger typewriter
│   ├── PassengerCoach4..1       modular cutaway coach scenes
│   └── ExteriorSequence         scene-authored station transition controller
├── Passengers                   ten active Passenger instances; two replacements spawn at every day stop
├── Player                       CharacterBody2D + Camera2D + final conductor texture
├── TrainAmbience                procedural rail/night ambience
├── HUD                          duties, live passenger-dot minimap, prompt, clock, notifications
└── ModalLayer
	├── DayIntroUI                 full-black DAY 1 fade title card
    ├── DocumentOverlayUI        ID and ticket documents; newspaper/statement reader
    ├── NotebookUI              passengers/route/evidence
    ├── StationStopCutsceneUI    letterbox + passenger staging over the gameplay camera
    ├── DeadSelectionUI          five typed abnormal-passenger report fields
    ├── ShiftReportUI            Merit, Penalty Points, paycheck threshold, and SP result
    ├── NightPuzzleUI            deceased-passenger/night-stop clue board
    ├── DepartureSequenceUI      four-station ending sequence
    └── PauseUI
```

Reusable world scenes live in `scenes/train`, `scenes/player`, `scenes/passengers`, and `scenes/interactables`. UI screens live in `scenes/ui`; the ending presentation lives in `scenes/night`.

Every static hierarchy and visual is scene-owned: menu panels and backdrop, HUD widgets, modal layouts, manifest rows, report cards, night-puzzle slots, train bodies, carriage interiors, cutscene actors, player/passenger visuals, interactable art, and minimap slots are visible and editable through `.tscn` nodes or scene-assigned textures. Button signals, focus neighbors, initial visibility/process modes, prompt copy, themes, colors, and audio-stream configuration are stored in scenes/Inspector data. Scripts bind those scene nodes and update runtime state only. Runtime `add_child()` is reserved for passenger instances created from the `passenger_scene` PackedScene assigned on `Main` in the Inspector.

## Main scripts

- `scripts/menu/main_menu.gd` binds the scene-authored responsive menu, applies and saves settings, and transitions into gameplay.
- `scripts/main/main.gd` owns the `OPENING → DAY → SUNSET → DEAD_SELECTION → SHIFT_REPORT → NIGHT → NIGHT_PUZZLE → COMPLETE` state flow, the complete named daytime route, four 60-second station legs, repeated exit assignments, equal station exchanges, cutscenes, live minimap population, deferred transition penalties, Merit/SP, time, and validation.
- `scripts/player/player.gd` handles horizontal `CharacterBody2D` movement, camera follow, facing, and nearest-interactable selection.
- `scripts/train/carriage.gd` and `scripts/train/train.gd` animate the scene-authored modular carriages, day/night overlay, underframe, and train sway; their geometry and palette live in train scenes and assigned SVG textures.
- `scripts/passenger/passenger_data.gd` is the designer-facing passenger Resource. `passenger.gd` presents it, emits inspection requests, and runs the selected ambient AI profile inside safe passenger-coach boundaries.
- `scripts/systems/departure_puzzle_data.gd` stores the night-stop order, relational clues, and internal deceased-passenger solution. “Night drop-off” means the station where a deceased passenger leaves the night train; it is separate from their daytime ticket destination.
- Scripts in `scripts/ui` project state into responsive Control/Container layouts and signal decisions back to `Main`.

## Adding a passenger

1. Duplicate a file in `data/passengers` and edit its exported identity, route, ticket, carriage, color, life state, anomaly, `ai_behavior`, and `ai_interval_seconds`. `origin_station` is where they board; `destination_station` is where the conductor should assign them to get off during the day.
2. Add the new `.tres` resource to `passenger_resources` on `Main`.
3. Set `initially_on_train = false` for a station replacement. Give it the same origin station and preferably the same carriage as the passenger it replaces.
4. Keep the initial roster at no more than 10 and the active deceased roster at no more than 4.
5. If the passenger belongs in a night puzzle, update that puzzle's clues and solution. World positions and typed-manifest validation populate automatically.

The runtime never writes into passenger Resources, so the same data can safely be reused by UI and visual nodes.

## Adding an anomaly

Existing values are `none`, `shadowless`, `impossible_ticket`, `age_mismatch`, and `newspaper_death`.

1. Add a new value to `anomaly_type` in `passenger_data.gd`.
2. Add only its visible/body presentation to `passenger.gd` or the relevant interactable/environment script.
3. If it produces explicit documentary evidence, record that fact in `main.gd` and display it in `notebook_ui.gd`.
4. Do not add automatic “anomaly” labels—the player must interpret visual contradictions and public records.

## Creating another departure puzzle

Duplicate `data/puzzles/first_departures.tres`, then edit:

- `night_stations`: ordered night-train stops shown to the player;
- `night_stop_clues`: newline-separated relational clues;
- `correct_passenger_by_station`: `{ station_name: passenger_short_name }` entries.

Assign the new Resource to `puzzle_resource` on `Main`. Keep one passenger per station and make clues reference discovered properties (“without a shadow”, “impossible journey”), ordering, adjacency, or non-adjacency rather than naming a direct answer. Verify that the clues yield one solution before shipping the puzzle.

## Validation

The project was parsed and run using Godot 4.7 stable. Tests cover Main Menu → Settings → Start, the DAY 1 fade, ten-passenger Alderwick boarding, leftward departure, diverse passenger AI (including stationary, wandering, and cross-car movement), live minimap population dots, all four 60-second route legs in order, repeated proximity-based exit selection, equal exchanges at Brambleford/Cinderfield/Dunmere/Eastmere, impostors boarding from different stations, deferred penalties, paycheck/SP results, and final night drop-offs:

```bash
godot --headless --path . --script res://tests/menu_flow_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/runtime_flow_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/performance_failure_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/station_assignment_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/newspaper_randomization_test.gd --audio-driver Dummy
godot --headless --path . --script res://tests/scene_architecture_test.gd --audio-driver Dummy
```

`scene_architecture_test.gd` additionally prevents regressions: it rejects script-created presentation nodes, `_draw()` placeholder rendering, scene preloads in behavior scripts, static signal connections made in code, unapproved `add_child()`, and any concrete Node script that is not attached to a `.tscn` scene.
