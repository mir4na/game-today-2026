# "Where Do You Belong?" — In-Game Interactive Tutorial Planning

A simple, straightforward, step-by-step master plan for the game's interactive onboarding tutorial.

---

## 📖 Story & Lore Overview

- **Protagonist**: A job applicant who died unexpectedly right before a job interview.
- **The Angel**: A divine supervisor who gives the protagonist a second chance at life by appointing them as an **Intern Conductor** on a mystical train between worlds.
- **The 5 Stations**: The daytime service runs across **5 distinct stations**:
  1. **Alderwick** (Departure / Starting Point)
  2. **Brambleford** (First Stop)
  3. **Cinderfield** (Second Stop)
  4. **Dunmere** (Third Stop)
  5. **Eastmere** (Terminal / Depot Stop)
- **Day Shift**: Inspect passenger IDs, tickets, and newspapers. Stamping tickets for living passengers is routine maintenance, but **stamping tickets is not your primary job**. Your true purpose is finding those who do not belong among the living (**Anomalies**) and keeping them aboard.
- **Paycheck Report**: At day's end, performance is calculated (correct drop-offs vs. wrong station penalties). Reaching the target passes the day.
- **Night Shift ("Soul Line")**: The train enters the *Soul Line*. The conductor reads soul records and solves deductive station puzzles to guide each departed soul to their final spiritual resting place. Completing 5 days earns the protagonist their second chance at life.
- **Cutscene Rule**: All cinematic cutscenes throughout the tutorial are **strictly unskippable** (`unskippable = true`) to prevent skipping crucial story and gameplay rules.

---

## 🚂 Step-by-Step Tutorial Flow

---

### Step 1: Main Menu Tutorial Button
- **Action**: Player clicks the **"TUTORIAL"** button on the Main Menu.
- **Effect**: 
  1. The loading screen appears (`LoadingScreenUI`).
  2. Screen fades to solid black (unskippable).
  3. Game scene loads with `is_tutorial_mode = true`.
  4. Screen fades back to normal.
- **Game State**:
  - The Conductor Player spawns inside Passenger Coach 4 (front carriage) at coordinates `Vector2(143, 430)`.
  - **Player cannot move**: `player.movement_enabled = false`.
  - **Player cannot interact**: `player.interaction_enabled = false`.
  - **All UI is hidden**: `GameHUD.hide()`.
- **Technical Reference**:
  - Scene: `scenes/menu/main_menu.tscn` ➔ Add `TutorialButton`.
  - Script: `scripts/menu/main_menu.gd` ➔ Connect `_on_tutorial_button_pressed()`.

---

### Step 2: Story Intro & Angel Dialogue
- **Effect**: 
  - The screen dims into a dark vignette so the player's full attention is directed to the dialogue box.
  - A celestial dialogue box pops up at the bottom-center of the screen.
- **Speaker**: The Angel
- **Dialogue Text**:
  > *"You died before your job interview, but you are given a second chance. Work as an intern conductor on this train. **Remember, do your job well.**"*
- **Player Action**:
  - You can **press [Space]** on your keyboard or **click the Continue button** on screen to dismiss the dialogue.
- **Clear Condition**: Dialogue box closes; screen dimmer fades out.

---

### Step 3: Learn Movement (3-Second Walking Test)
- **Dialogue Box (The Angel)**:
  > *"For controls, try **walking for 3 seconds** using **[A] / [D]** or the **Arrow Keys**."*
- **Effect**:
  - A circular spotlight shines directly on the Conductor Player.
  - The surrounding carriage remains dark.
  - **Movement is unlocked**: `player.movement_enabled = true` (only walking; interaction stays disabled).
- **Prompt on Screen**:
  - Floating keyhint above player: `Use [A] / [D] or [←] / [→] to Walk`.
- **Player Action**:
  - You can **press [A] / [D]** or **use the Arrow Keys** to walk.
  - Player must walk horizontally. Standing still does NOT count.
  - An internal timer accumulates walking time (`_walk_timer += delta` while `abs(velocity.x) > 10.0`).
- **Clear Condition**:
  - Walking timer reaches 3.0 seconds.
  - Spotlight fades out, and carriage lighting returns to warm daylight.
- **Technical Reference**:
  - Script: `scripts/player/player.gd` ➔ `movement_enabled`, `walk_animation_threshold`.

---

### Step 4: Show the UI (Minimap, Clock, & The 5 Stations)
- **Effect**:
  - The in-game HUD is revealed: `GameHUD.show()`.
- **Spotlight 1 — Train Minimap**:
  - Screen dims slightly; camera and UI zoom directly into the Minimap.
  - Spotlight highlights the `TrainMinimap`.
  - **Angel Dialogue**:
    > *"This is your **Train Minimap**. Each icon represents a carriage, and the glowing dots show the **live positions of passengers** across the train."*
  - Player can **press [Space]** or **click Continue** to proceed.
- **Spotlight 2 — Journey Clock & Station Overview**:
  - Focus pans smoothly and zooms directly into the Journey Clock.
  - Spotlight highlights the `JourneyClock` / `ClockPanel`.
  - **Angel Dialogue**:
    > *"This is your **Journey Clock**. Our route covers **5 stations**: **Alderwick**, **Brambleford**, **Cinderfield**, **Dunmere**, and **Eastmere**."*
    > *"The needle advances as we travel. When it touches a station symbol, the train halts. **Check every passenger before we arrive!**"*
  - Player can **press [Space]** or **click Continue** to dismiss.
- **Clear Condition**:
  - Both spotlights dismissed; UI and camera return to standard 1.0x scale.
- **Technical Reference**:
  - Script: `scripts/ui/hud.gd` ➔ `%TrainMinimap`, `%ClockPanel`.

---

### Step 5: Meet the First Passenger
- **Effect**:
  - A guide arrow appears on screen pointing rightward to the first seated passenger in Coach 4 (Julian Rowe).
  - **Angel Dialogue**:
    > *"Now, **walk over** to the passenger sitting in front of you."*
- **Player Action**:
  - Player walks rightward toward the passenger using **[A] / [D]** or **Arrow Keys**.
- **Proximity Trigger**:
  - When the player is within 112px (`interaction_distance`):
    - A golden outline glow appears around the passenger sprite (`interactable_outline.gdshader`).
    - Interaction unlocks: `player.interaction_enabled = true`.
    - Floating prompt appears above the passenger: `[E] Inspect Documents`.
- **Player Action**:
  - You can **press [E]** on your keyboard or **click the interaction prompt** to open documents.
- **Clear Condition**:
  - `interaction_pressed` signal emitted; opens the document viewer.
- **Technical Reference**:
  - Script: `scripts/interactables/interactable.gd` ➔ `interaction_distance = 112.0`.
  - Shader: `shaders/interactable_outline.gdshader`.

---

### Step 6: Check Documents (ID & Ticket)
- **Effect**:
  - `DocumentOverlayUI` slides up from the bottom of the screen with a physical paper sound.
  - Two documents appear side-by-side:
    - **Civil ID Card**: Photo of a young man, name *"Julian Rowe"*, Civil ID `CID-0001`.
    - **Train Ticket**: Passenger name *"Julian Rowe"*, Date, Train `505`, Destination: **Brambleford**.
- **Spotlight & Instructions**:
  - Spotlight highlights the **ID Photo & Name**, matching the Ticket Name.
  - **Angel Dialogue**:
    > *"**Rule 1:** Verify identity. Make sure the passenger's **face and name on the Civil ID match the ticket**."*
  - Spotlight moves to **Destination: Brambleford**.
  - **Angel Dialogue**:
    > *"**Rule 2:** Note their destination. Julian Rowe wants to disembark at **Brambleford**—which is our **next stop**."*
- **Player Action**:
  - You can **click the Ticket** with your mouse to bring it forward.
- **Clear Condition**:
  - Ticket is brought to the foreground; triggers Step 7.
- **Technical Reference**:
  - Script: `scripts/ui/document_overlay_ui.gd` ➔ `%IDCard`, `%PassengerTicket`.

---

### Step 7: Stamp the Ticket (Stamp Drawer)
- **Effect**:
  - The brass stamp drawer (`StampTrayUI`) slides out from the bottom-left corner.
  - 5 station stamps are shown: Alderwick, Brambleford, Cinderfield, Dunmere, Eastmere.
  - A flashing golden pulse highlights the **"BRAMBLEFORD"** stamp.
- **Angel Dialogue**:
  > *"Living passengers must have their tickets **stamped with their destination station** before arrival. Drag the **Brambleford stamp** onto his ticket."*
  > *"**Warning:** Stamping the **wrong station** or **dropping passengers off late** will deduct a **-20 Blessings penalty**!"*
- **Player Action**:
  1. Click and drag the **Brambleford** stamp over the ticket surface.
  2. Release the mouse button: ink sound plays, permanent stamp appears on the ticket.
  3. You can **press [Esc]** on your keyboard or **click the [X] button** in the corner to close documents.
- **Clear Condition**:
  - Ticket stamped with `Brambleford` and document overlay closed.
- **Technical Reference**:
  - Script: `scripts/ui/stamp_tray_ui.gd` ➔ `stamp_dropped("Brambleford", pos)`.

---

### Step 8: The True Purpose & Detailed Guidebook Breakdown
- **Narrative Bridge (The Angel)**:
  - Before opening the Guidebook, the Angel pauses the conductor:
  > *"Good work stamping that ticket. But remember: **stamping tickets is not your primary job**."*
  > *"Your true purpose as an intern conductor is finding those who do not belong among the living—the **Anomalies**."*
  > *"To understand your daily schedule, rules, and how to spot them, open your **Guidebook**."*
- **Effect**:
  - Spotlight highlights the Guidebook icon in the top-right corner.
  - Prompt: `Press [Tab] or click the Guidebook icon`.
- **Player Action**:
  - You can **press [Tab]** on your keyboard or **click the Guidebook icon** to open it.
- **Detailed Page-by-Page Explanation**:
  - `GuidebookUI` opens. The Angel walks the player through each page:
  
  1. **Page 1: Today's Service (`%TodayTab`)**:
     - Displays today's shift data: Train Number (**505**), Service Date, and full 5-station route (**Alderwick ➔ Brambleford ➔ Cinderfield ➔ Dunmere ➔ Eastmere**).
     - Displays current passenger count and the **Day 1 Pass Target (100 Blessings)** needed to pass today's shift.
     - **Angel Dialogue**:
       > *"**Page 1 is Today's Service.** It tracks your route progress across all 5 stations and displays the **net earnings target** you must achieve before sunset."*
     - Player can **press [Space]** or **click the next tab**.

  2. **Page 2: Operating Rules & Paycheck (`%RulesTab`)**:
     - Details the conductor's revenue ledger:
       - **+30 Blessings**: Awarded for every living passenger dropped off at the correct station.
       - **-20 Blessings Penalty**: Deducted if a passenger is stamped with the wrong station or missed their stop.
       - **-40 Blessings Penalty**: Charged immediately if you mistakenly stamp a deceased Anomaly for daylight service!
     - **Angel Dialogue**:
       > *"**Page 2 lists your Operating Rules.** Correct drop-offs earn you **+30 Blessings**, but wrong drop-offs cost a **-20 penalty**. Worse yet, stamping an anomaly costs a heavy **-40 penalty**!"*
     - Player can **press [Space]** or **click the next tab**.

  3. **Page 3: Anomaly Catalogue (`%AnomalyTab`)**:
     - A reference guide listing the telltale signs of deceased impostors:
       - **Missing Shadow**: Deceased passengers cast no shadow or only a faint, translucent outline.
       - **Physical Twitching**: Subtle supernatural body tremors and desaturated skin.
       - **Document Irregularities**: Mismatched portrait photo, unlisted destination, or impossible ticket dates.
       - **Morning Obituaries**: Public newspaper death notices.
     - **Angel Dialogue**:
       > *"**Page 3 is the Anomaly Catalogue.** Memorize these warning signs: **missing shadows**, **body twitches**, **invalid ticket dates**, and **newspaper obituaries**."*
- **Player Action**:
  - You can **press [Tab]** or **press [Esc]** or **click the [X] button** to close the Guidebook.
- **Clear Condition**: Guidebook is closed.
- **Technical Reference**:
  - Script: `scripts/ui/guidebook_ui.gd` ➔ `%TodayTab`, `%RulesTab`, `%AnomalyTab`.

---

### Step 9: Read the Morning Newspaper (Obituary Clue)
- **Effect**:
  - A guide arrow directs the player rightward into Carriage 3.
  - Spotlight highlights the morning newspaper resting on the side table (`NewspaperInteractable`).
  - Floating prompt: `[E] Read Morning Gazette`.
- **Player Action**:
  - You can **press [E]** or **click the prompt** to read the newspaper.
- **Content Shown**:
  - `NewspaperReader` opens showing the front page:
    - Headline: *"Sudden Collapse at Ironworks: Millwright Arthur Finch Pronounced Dead"*.
- **Angel Dialogue**:
  > *"Read the news carefully. **Arthur Finch passed away yesterday**. If anyone on this train claims to be Arthur Finch, **they are not of the living world**."*
- **Player Action**:
  - You can **press [Esc]** or **click the [X] button** to close the newspaper.
  - The obituary note is automatically saved into the Guidebook's Evidence tab.
- **Clear Condition**: Newspaper is closed.
- **Technical Reference**:
  - Script: `scripts/interactables/newspaper.gd`.
  - Script: `scripts/ui/newspaper_reader.gd`.

---

### Step 10: Find the Anomaly (The 3-Passenger Inspection)
- **Scene Setup**:
  - Ahead in Carriage 3, the game spawns **3 passengers** seated along the coach:
    1. **Passenger A (Living)**: *Clara Higgins* — destination **Cinderfield**. Normal dark shadow, face matches ID.
    2. **Passenger B (Living)**: *Thomas Vance* — destination **Eastmere**. Normal dark shadow, face matches ID.
    3. **Passenger C (The Anomaly)**: *Arthur Finch* — destination *Dunmere*. **Casts no shadow** (or faint translucent shadow), exhibits subtle body twitches, and matches the newspaper obituary.
- **The Angel's Instruction**:
  > *"Ahead in this carriage are **3 passengers**. One of them is an **Anomaly**!"*
  > *"Inspect all three. **Stamp every living passenger for their correct stop, but DO NOT STAMP the anomaly!**"*
  > *"**Remember:** Stamping a living passenger earns **+30 Blessings**, but stamping an anomaly will cost you a severe **-40 Blessings penalty**!"*
- **Player Actions**:
  1. **Inspect Clara Higgins**: Check ID and ticket. Notice normal shadow. Drag the **Cinderfield stamp** onto her ticket. Close document.
  2. **Inspect Thomas Vance**: Check ID and ticket. Notice normal shadow. Drag the **Eastmere stamp** onto his ticket. Close document.
  3. **Inspect Arthur Finch**:
     - Spotlight 1 highlights the floor beneath his feet: **he casts no shadow**.
     - Spotlight 2 highlights his sprite: **subtle body twitches**.
     - Open ticket: Name reads *Arthur Finch*.
     - **Angel Alert Box**:
       > *"**[ANOMALY CONFIRMED!]**"*
       > *"Arthur Finch is deceased. **Leave his ticket UNSTAMPED** so he stays aboard for the **Night Shift**."*
     - Player closes documents with **[Esc]** or **[X] button** without applying any stamp.
- **Clear Condition**:
  - Both living passengers (Clara & Thomas) are correctly stamped for their destinations.
  - Arthur Finch's ticket remains completely **unstamped** (`stamped_station == ""`).
- **Technical Reference**:
  - Script: `scripts/passenger/passenger.gd` ➔ `dead_shadow_alpha = 0.14`, `dead_twitch_interval_seconds`.
  - Scene: `scenes/passengers/passenger.tscn`.

---

### Step 11: Route Sign-Off & Signature Trace
- **Context & Purpose**:
  - This is the official **Conductor's Sign-Off**: confirming and certifying that all passengers have been thoroughly inspected, living passengers are stamped, and anomalies are retained for this travel leg.
  - The Service Action Button (`%ServiceActionButton`) unlocks and becomes visible on the HUD only after completing Step 10.
- **Spotlight & Zoom**:
  - Screen dims slightly; camera and UI zoom directly into the newly appeared **Service Action Button**.
  - A flashing golden outline highlights the button.
- **The Angel's Dialogue**:
  > *"As a conductor, once you finish inspecting passengers on a route leg, you must **officially sign off on the service ledger**."*
  > *"This signature confirms that **all duties for this travel leg are complete**. Click the **Service Action button** to open the sign-off ledger!"*
- **Player Action 1**:
  - You can **click the Service Action Button** on screen.
- **The Service Signature Interface (`ServiceSignatureUI`)**:
  - The ledger opens showing: `ALDERWICK → BRAMBLEFORD`.
  - Question stage: *"Are you sure all passenger duties for Brambleford arrival are complete?"*
  - Player clicks **[Confirm]**.
- **The Signature Trace**:
  - A glowing celestial seal pattern (`PulsePattern`) appears on the drawing board.
  - **Angel Dialogue**:
    > *"Hold your left mouse button and **accurately trace the glowing seal mark** to certify your shift. The train will only proceed once your signature is verified!"*
  - Player holds the left mouse button and traces along the line.
  - If the trace is inaccurate: Screen shakes slightly, message: *"Trace the mark carefully."*
  - If the trace is accurate: Radiant golden flash, acceptance sound: **"SERVICE CONFIRMED"**, and the modal smoothly closes.
- **Clear Condition**:
  - Signature is successfully verified (`service_signed` emitted) ➔ Train immediately accelerates and halts at Brambleford.
- **Technical Reference**:
  - Script: `scripts/ui/service_signature_ui.gd` ➔ `_trace_matches_pattern()`, `service_signed`.
  - Scene: `scenes/ui/service_signature_ui.tscn`.

---

### Step 12: Train Stops at Station (Brambleford Arrival)
- **Effect**:
  - Train whistle blows and brakes screech as the train pulls into Brambleford platform.
  - Black cinematic letterbox bars slide onto screen (`StationStopCutsceneUI`). **Cutscene is unskippable**.
- **Cutscene Events**:
  - Julian Rowe (stamped for Brambleford) walks off the train onto the platform (`+30 Blessings` popup).
  - Clara & Thomas remain on board for later stops (Cinderfield and Eastmere).
  - Arthur Finch (anomaly, unstamped) remains sitting quietly inside Carriage 3.
  - A new passenger boards and sits in an empty seat.
- **Angel Dialogue**:
  > *"Brambleford arrival complete! The living passenger **safely disembarked**, and the anomaly **remained on board**. Excellent work."*
- **Clear Condition**:
  - Cutscene finishes, letterboxes retract, and daytime travel continues smoothly until sunset.
- **Technical Reference**:
  - Script: `scripts/ui/station_stop_cutscene_ui.gd`.

---

### Step 13: End of Day Shift (Paycheck Report)
- **Effect**:
  - Sunset shifts to nightfall. The train visits all stops and arrives at the terminal depot at Eastmere.
  - The Conductor's official paycheck ledger opens on screen (`ShiftReportUI`).
- **Ledger Breakdown**:
  - Correct Living Drop-offs: `3 x 30 = +90 Blessings` (Julian Rowe, Clara Higgins, Thomas Vance)
  - Wrong Station / Distance Penalties: `0 Blessings`
  - Anomaly Daylight Penalties: `0 Blessings`
  - Retained Anomalies: `3 Safe` (Arthur Finch, Eleanor Ward, Gideon Cross)
  - **NET EARNINGS**: `90 / 90 Target`
  - A brass stamp punches down onto the receipt: **"PASSED"**.
- **Angel Dialogue**:
  > *"Your daytime shift is evaluated. **You met the quota and avoided penalties!** But your work is only half done. The sun has set—prepare for the **Soul Line**."*
- **Player Action**:
  - You can **press [Space]** or **click the [Proceed to Night Service] button**.
- **Clear Condition**: Paycheck confirmed; transitions into Night Service.
- **Technical Reference**:
  - Script: `scripts/ui/shift_report_ui.gd`.

---

### Step 14: Night Market & Mandatory Veil Note Purchase
- **Effect**:
  - The mystical lantern-lit Night Market opens (`NightMarketUI`).
  - Conductor's Blessings wallet (90 Blessings) is shown in the top corner.
- **Spotlight on the Veil Note**:
  - Spotlight highlights the **Veil Note** item slot.
  - **Angel Dialogue**:
    > *"Before entering the metaphysical realm, you must equip yourself. **Click to purchase the Veil Note!**"*
    > *"This occult parchment reveals a hidden connection between souls on tonight's spiritual map."*
- **Player Action**:
  - Player clicks on the **Veil Note** slot to buy it (90 Blessings).
  - Purchase feedback sound plays; Veil Note is added to inventory.
  - The `[Proceed to Night Service]` button unlocks.
  - Player clicks **[Proceed to Night Service]**.
- **Clear Condition**:
  - Veil Note purchased, Night Market closed.
- **Technical Reference**:
  - Script: `scripts/systems/market_tool_state.gd` ➔ `TOOL_VEIL_NOTE`.
  - Script: `scripts/ui/night_market_ui.gd`.

---

### Step 15: The Soul Line & Spiritual Deduction Puzzle
- **Atmosphere Shift**:
  - Unskippable night transition: train enters the mystical **Soul Line**.
  - Train windows display deep space cosmic nebulae and stars; interior lights glow in pale cyan (`night_atmosphere.gdshader`).
  - **3 Deceased Anomalies** remain aboard the carriages in spiritual form: **Arthur Finch**, **Eleanor Ward**, and **Gideon Cross**.

#### Phase A: Explaining the UI (Soul Ledger & Constellation Map)
- The deduction board (`NightPuzzleUI`) opens. The Angel explains the interface:
  1. **Spotlight 1 — The Soul Ledger (`%LedgerAnchor`)**:
     - Highlights the card column on the left side.
     - **Angel Dialogue**:
       > *"This is your **Soul Ledger**. It holds the spiritual cards of all **3 deceased souls** aboard your train tonight."*
     - Press **[Space]** or click to continue.
  2. **Spotlight 2 — The Constellation Map (`%StationPathAnchor`)**:
     - Highlights the spiritual node map on the right side.
     - **Angel Dialogue**:
       > *"This is the **Constellation Map**. These glowing nodes represent spiritual stations, joined by mystical transit lines. **Souls cannot rest anywhere**—they only resonate with their designated constellation node."*
     - Press **[Space]** or click to continue.

#### Phase B: Inspecting 3 Anomaly Biographies & Finding Clues
- **Angel Dialogue**:
  > *"You must inspect the **biography of each soul**. Hidden within their surviving records is a **vital clue statement** indicating their true place on the map."*
- **Player Action**:
  - Click / interact with each soul card to open their Soul Record (`NightSoulRecordUI`):
    1. **Arthur Finch Record**:
       - Clue Statement: *"Arthur Finch rests at the **highest station mark** on the path."*
    2. **Eleanor Ward Record**:
       - Clue Statement: *"Eleanor Ward rests at the **lowest station mark**."*
    3. **Gideon Cross Record**:
       - Clue Statement: *"Gideon Cross rests **between Arthur and Eleanor**, joined by one direct line to each."*
    4. **Veil Note Statement (`%VeilNotePanel`)**:
       - The purchased Veil Note reveals: *"Arthur Finch and Gideon Cross are joined by **one line**."*

#### Phase C: Solving & Confirming Alignment
- **Angel Dialogue**:
  > *"Now, drag each soul card from the **Soul Ledger** onto their rightful node on the **Constellation Map**, then click **[Confirm Alignment]**!"*
- **Player Action**:
  1. Drag **Arthur Finch** ➔ to the **highest station node**.
  2. Drag **Eleanor Ward** ➔ to the **lowest station node**.
  3. Drag **Gideon Cross** ➔ to the **center node between them**.
  4. Click the **[Confirm Alignment] button**.
- **Result & Validation**:
  - A brilliant golden beam of spiritual light traverses along the connected path lines.
  - Celestial chime rings out: **"THE STATION PATH IS ALIGNED"**!
  - Final ending dialogue appears:
    > *"You have successfully guided the lost souls to their rightful rest, Intern. **Day 1 Complete!** **4 shifts remain** until your internship is fulfilled and you **reclaim your mortal life**."*
- **Clear Condition**:
  - You can **click the [Return to Main Menu] button**. Tutorial is officially finished!
- **Technical Reference**:
  - Script: `scripts/ui/night_puzzle_ui.gd`.
  - Script: `scripts/systems/departure_puzzle_data.gd`.
  - Script: `scripts/ui/night_soul_record_ui.gd`.
