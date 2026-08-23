# GiftQuest UI spec

Handoff doc for implementation in Flutter. Layout and structure only —
apply the Sunset Pop theme tokens (background #1C1B1F, primary purple
#4F378B, light purple #D0BCFF, Fredoka for display text, Schibsted
Grotesk for body, chunky sticker-shadow component style) on top of
this structure.

---

## Home screen

**Purpose:** hub screen, entry point after login/pairing, holds the two
core tabs.

**Layout (top to bottom):**

1. **Header row** — app/user label on the left, avatar or profile icon
   (32dp circle) on the right.
2. **Segmented tab control** — two segments, equal width, rounded
   container, active segment has a filled/raised background:
   - `my wishes`
   - `partner / QR` (see "Pairing tab" below for its two states)
   - Also swipeable between the two — the segmented control is a
     visible affordance in addition to the swipe gesture, not a
     replacement for it.
3. **Wish list** — vertical list of cards, each:
   - 44dp square thumbnail (leading, rounded corners)
   - Title line (primary text)
   - Status line (secondary text, smaller) — one of: "hidden", "guessed
     by [partner]", "wrapped"
   - **Resolved:** locked/not-yet-guessable wishes render faded
     (~50% opacity) with a lock icon and an "unlocks [date]" label,
     rather than being hidden from the list. The tease is intentional —
     it signals more is coming and keeps the list from collapsing to
     empty.
   - **New status — "wrapped":** a wish that's been guessed and
     physically delivered/redeemed. This wasn't in the original flow;
     confirm the trigger (manual mark-as-wrapped action? automatic on
     some event?) and add the Firestore field + UI action for it.
4. **Add button** — floating action button, bottom-right, circular,
   `+` icon. Navigates to Add/Edit Wish screen (add mode).
5. **Bottom nav** — two items only: home (active) and settings.
   Simple icon row, no labels needed at two items.

**States to design for:**
- Empty state (no wishes added yet) — headline names the space, one
  line explaining it, CTA to add the first wish. Avoid a bare "nothing
  here yet."
- Partner's-wishes tab before pairing → shows QR linking content
  instead of a wish list (see Pairing tab spec, below)
- Loading state while Firestore stream resolves — simple skeleton/
  placeholder rows, not a full-screen spinner

---

## Add / edit wish screen

**Purpose:** create a new hidden wish, or edit an existing one.

**Layout (top to bottom):**

1. **Header** — back arrow + screen title.
2. **Image picker** — dashed-border placeholder, tap to add a photo
   (Cloudinary upload).
3. **Title field** — single-line text input.
4. **Hint field** — multi-line text area, labeled so it's clear only
   the AI sees it. **Resolved:** dedicated hint field, not inferred
   from the title. In the Groq prompt: title = the answer, hint =
   the only evidence the AI is allowed to draw on. Keeps difficulty
   tunable per wish and keeps AI clues from going generic.
5. **Visibility field** — when this wish becomes guessable (on pairing,
   on a set date, manually revealed, etc.) — exact mechanism TBD.
6. **Save button** — primary action, full width.
7. **Delete button** — edit mode only, destructive style, full width,
   below save.

---

## Pairing tab (My Wishes' sibling tab)

**Purpose:** single tab slot that shows different content depending on
pairing state — not two separate screens/routes.

**Before pairing:**
- QR code placeholder (own code, ~140dp square)
- Own user code as text below the QR
- Divider
- Text field: "enter partner's code" (manual fallback)
- Button: "scan QR code" (opens camera)

**After pairing:**
- Renders as a wish list, same card pattern as My Wishes, but showing
  the partner's hidden wishes
- Each row is tappable → opens Guess chat scoped to that specific wish
  - **Resolved:** one thread per wish, not one rolling conversation
    across all of a partner's wishes. Keeps context tight per wish,
    makes the win/lose transition unambiguous, and matches the
    row-tap entry point — a shared thread would leak clues across
    wishes.

**Trigger for state change:** pairing confirmation is an external
event (partner completes their side of the scan/code entry), not a
local user action — implies this tile needs a Firestore stream
listener, not simple on-tap navigation.

**Additional state — waiting on partner:** after this user scans/enters
a code but before the partner confirms their side, show a waiting
state ("waiting for [partner] to confirm") rather than leaving the
screen looking unchanged.

---

## Guess chat with AI screen

**Purpose:** conversational guessing interface for one specific
partner wish.

**Layout (top to bottom):**

1. **Header** — back arrow, wish/partner label, guesses-remaining
   counter (top right). **Resolved:** guesses are capped, 5 by default
   (make it a tweakable value, not hardcoded) — the cap is what makes
   the reveal a real payoff and gives the lose state a reason to
   exist.
2. **Message thread** — standard chat bubbles, AI messages
   left-aligned, user messages right-aligned. Scrollable.
3. **Input row** — text field + send button, pinned to bottom.

**States to design for:**
- AI "typing" / thinking indicator
- Correct guess → transitions to Win/Lose reveal
- Guesses exhausted (if capped) → transitions to Win/Lose reveal (loss)

---

## Win / lose reveal screen

**Purpose:** the payoff moment — one screen, two outcome states (win
vs. lose), likely differentiated by icon/color rather than separate
layouts.

**Layout (top to bottom):**

1. **Outcome icon** — large, centered, swaps per outcome (e.g. success
   icon/color for win, a more subdued icon/color for lose).
2. **Headline** — outcome text ("you got it!" / "so close"), with a
   short line naming how it went (e.g. "guessed in 3" / "out of
   guesses, one word away").
3. **Result card** — reveals the actual gift (name + short detail).
4. **Primary action button** — "brag to [partner]" on win, "share the
   fail" on lose. **Open decision:** confirm what this actually does —
   an in-app notification to the partner, or an OS share sheet out to
   messages/social. Needs to be spelled out before implementation.
5. **Back to home button** — secondary action, full width, below the
   primary button.

---

## Login / sign up and Settings screens

**No mockup pass done for these two** — standard, low-risk patterns
(auth form, basic settings list). Build these directly from the flow
doc and Sunset Pop tokens without a separate design mockup:

- **Login / sign up:** email or Google auth, per the onboarding flow.
  Match component styles (buttons, inputs, sticker-shadow) established
  in the six mocked-up screens for consistency.
- **Settings:** simple list — account, notification preferences,
  privacy, unlink partner, logout. Bordered rows per the CDS "dense
  lists: bordered rows, not rounded-rect cards" convention, consistent
  with the rest of the app.

## Open items carried into implementation

1. **"Wrapped" status** — new wish state (guessed + delivered/
   redeemed). Needs a Firestore field and a UI action to trigger it;
   not yet designed.
2. **"Brag to partner" / "share the fail" buttons** on the Win/Lose
   screen — behavior undefined (in-app notification vs. OS share
   sheet). Decide before wiring the button.

## Reference

Full mockups for the six designed screens (Home in its three states,
Add/Edit Wish, Pairing tab in both states, Guess chat, Win/Lose in
both outcomes) are in `GiftQuest_UI_Mockups.pdf`, generated via
Claude Design against this spec, Sunset Pop tokens.
