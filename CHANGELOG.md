# LooseButtons

## 0.1.6

- Icons tint like the default action bar. Blue means you are short on power. Gray means the action cannot be used. A reactive ability lights up when it becomes usable.
- `/loose tint` turns that tint off and on. It starts on.
- Pet actions are gray or full color only.

## 0.1.5

- Ranged spell hotkeys turn red when the target is out of range
- Pet abilities appear in the catalog and drag onto the HUD like other rows

## 0.1.4

- AddOn list shows the book icon instead of the mystery-mark placeholder
- Under-the-hood cleanup so Forever keeps loading clean. Same buttons, less jank risk

## 0.1.3

- The TOC interface is 16001, Forever beta 1.60.1. The client lists 120100 as incompatible.

## 0.1.2

- Login shows the layout that character last left on. A character with no saved row still starts Blank.
- Edit can bind a loose button to a mouse button past Right, the wheel, or a controller button the game already reports, including a paddle such as PADPADDLE1. The wheel stays off until Edit is open.
- Each character keeps its own loose-button keys. A hover bind writes that character's keys, and the Blizzard Key Bindings window does too. A character with no saved keys starts clear.
- Spellbook and game-menu launchers open from a secure click, so Edit Mode and the spellbook no longer taint ClearTarget, SetWidth, or the pet bar.

## 0.1.1

- CurseForge lists this file as Forever 1.60.1. The TOC interface stays 120100 so the Forever client loads the addon.

## 0.1.0

- A placed spell button switches to a higher rank of that same spell when you learn it.
- A spellbook refresh no longer blocks the pet bar from hiding.
- Share selects the layout string. Press Ctrl+C to copy. The dialog does not call CopyToClipboard.
- Edge cooldown covers the cropped icon. The other themes keep the swipe inset from the icon.
- Edge is a new button theme: a gray rim on a dark well, a red rim on hover, and a red wash while pressed.
- Changing scale repaints placed buttons, so the hover highlight matches the new size instead of hanging below the button.
- Scale and Theme sit side by side under the Character & info title, lined up with its left edge. Scale is the left column. Theme is the right. Checking a box shows that column's slider or dropdown.
- The first time you open the Loose Buttons spellbook tab, the catalog and ribbon stay visible. A reused category button no longer hides them, because the hide hook reads the live tab id.
- Edit and Quick Keybind hide the button tooltip and the bind tooltip when bind mode starts, the cursor stays on a button, the cursor leaves, or bind mode ends.
- Character & info centers its title in the header, and Scale sits closer above Theme.
- Share and Import dialogs grow to fit their controls.
- Character & info stacks Scale above Theme so the dropdown stays on the parchment, and No plate glows inside the icon instead of an outer frame.
- Leaving the Loose Buttons spellbook tab for another addon tab hides the catalog, section headers, and parchment ribbon.
- Escape ends bind mode without tainting the game menu, so stopping a cast still works.
- Alt- and Shift-right-click remove no longer casts the button, and drops skip hidden action bars.
- The spellbook ribbon's right edge lines up with the General divider.
- General and Character macros in the catalog can be dragged onto the HUD or an empty action slot.
- Place up to 48 action buttons and 24 launchers.
