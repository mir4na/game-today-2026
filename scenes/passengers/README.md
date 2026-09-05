# NPC sprite animations

Each `npc_1.tscn` through `npc_17.tscn` has its own `SpriteFrames` resource, using the same `idle` and `walk` animation names as the player.

1. Open the NPC scene you want to configure.
2. Select `CharacterScale/PassengerVisual/NPCVisual` (`AnimatedSprite2D`).
3. Open **Sprite Frames** in the Inspector. Select `idle` or `walk`, then use **Add frames from a Sprite Sheet** to select your sheet, configure its grid, and add frames in playback order.
4. Fill `idle` with a resting frame or idle sequence, and `walk` with the walking sequence. Both animations loop at 10 FPS by default; tune their speed in the SpriteFrames panel.
5. Adjust `NPCVisual` Position and Scale to match the character's height and keep its feet aligned with the ground shadow. Use consistent frame dimensions and foot placement for both animations.
6. On the NPC root, set **Artwork Faces Left** to match the direction in your sheet. The visual parent mirrors automatically when the NPC changes direction.
7. Adjust the sibling `InteractionPromptAnchor` to sit just above the new artwork's head.

For editor previews, temporarily show `NPCVisual` and hide `CharacterArtwork`. At runtime the script manages both nodes' visibility. Empty animations use the existing static artwork; a missing walk animation uses idle if available. No spritesheet is assigned automatically.

`NPCVisual` has no cutout material, so transparent spritesheets render directly. The parent retains the interaction outline and night effects. The old reference artwork keeps its own cutout shader.

Walking follows actual NPC movement, including boarding. Idle is selected when movement stops, AI pauses, the passenger is inspected, or night mode begins. Animation playback does not restart every frame. The old procedural walking bob is disabled while sprite animation is active.
