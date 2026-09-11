# itch.io page setup

Paste `where-do-you-belong.css` into **Edit theme > Custom CSS**.

Suggested built-in theme values:

- Background: `#101923`
- Background 2: `#21313E`
- Text: `#EEE4D1`
- Links and buttons: `#D8BB70`
- Headers: `#F0D990`
- Font: `Josefin Sans`
- Layout: `Sidebar` for a downloadable build, or `Hidden` for a large HTML5 embed

Custom CSS access is disabled by default on itch.io. Request access from itch.io if the Custom CSS field is not visible. Keep a copy of this file because platform markup can change.

Optional cards can be added through the description editor's HTML mode:

```html
<div class="custom-training-card">
  <strong>EMPLOYEE DIRECTIVE</strong>
  <p>Inspect every passenger. Trust the record, not the face.</p>
</div>

<div class="custom-warning">
  <strong>NIGHT SERVICE NOTICE</strong>
  <p>Some passengers do not belong among the living.</p>
</div>

<div class="custom-manifest">
  <strong>SHIFT MANIFEST</strong>
  <p>Stamp carefully. Every decision follows you to Eastmere.</p>
</div>
```
