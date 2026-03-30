# Design System Strategy: Architectural Clarity

## 1. Overview & Creative North Star
**Creative North Star: "The Architectural Ledger"**

This design system moves away from the cluttered, "widget-heavy" aesthetic of traditional productivity tools. Instead, it adopts the persona of a high-end architectural firm: structured, intentional, and deceptively simple. We reject the "template" look by utilizing extreme white space, asymmetric balance, and tonal depth.

The goal is to make "My Office Days" feel like a premium physical workspace. We achieve this through a "Utility-First Editorial" approach—where the data is the hero, and the interface acts as a quiet, sophisticated gallery. We break the grid not through chaos, but through intentional "breathing zones" (using the `spacing-16` and `spacing-24` tokens) that force the user's eye toward critical actions.

---

## 2. Colors & Surface Philosophy

### The "No-Line" Rule
Standard UI relies on 1px borders to define sections. In this system, **borders are strictly prohibited for structural sectioning.** Boundaries must be created through background shifts.
*   **Action:** A `surface-container-low` sidebar sitting against a `surface` main content area provides all the definition needed. If you feel the urge to draw a line, use a tonal shift instead.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. We use Material Design tokens to define "closeness" to the user:
*   **Level 0 (Base):** `surface` (#f8f9ff) - The canvas.
*   **Level 1 (Sections):** `surface-container-low` (#eff4ff) - Large structural blocks.
*   **Level 2 (Interaction):** `surface-container` (#e5eeff) - Cards or content zones.
*   **Level 3 (Emphasis):** `surface-container-highest` (#d3e4fe) - Popovers or active states.

### The "Glass & Signature Texture" Rule
To elevate the experience, use **Glassmorphism** for floating navigation or mobile headers. 
*   **Formula:** `surface-container-lowest` at 80% opacity + `backdrop-blur(12px)`.
*   **Signature Gradient:** For primary CTAs and hero headers, use a subtle linear gradient from `primary` (#004da4) to `primary-container` (#0064d2) at a 135° angle. This adds "soul" and prevents the vibrant blue from feeling flat.

---

## 3. Typography
We use **Inter** exclusively, but we treat it with editorial authority. Hierarchy is not just about size; it’s about the dramatic contrast between `display` and `label` scales.

*   **Display & Headline:** Use `display-md` or `headline-lg` for dashboard welcomes. These should feel like magazine headers—bold and unapologetic.
*   **The Utility Layer:** `title-sm` and `label-md` are the workhorses. Use `on-surface-variant` (#424753) for labels to create a sophisticated, "slate" look that reduces eye strain compared to pure black.
*   **Intentional Weight:** Headlines should use `Font-Weight: 600`, while body text stays at `400`. Never use "Medium" weights; stick to the extremes to keep the hierarchy sharp.

---

## 4. Elevation & Depth

### The Layering Principle
Depth is achieved by stacking. A `surface-container-lowest` (#ffffff) card placed on a `surface-container-low` (#eff4ff) background creates a natural, soft lift. This is our primary method of containment.

### Ambient Shadows
Shadows are a last resort. When used (e.g., for a floating action button or a modal), they must be "Ambient":
*   **Shadow Color:** A tint of `on-surface` (e.g., `rgba(11, 28, 48, 0.06)`).
*   **Blur:** Use large values (20px to 40px) with 0 offset to mimic natural light.

### The "Ghost Border" Fallback
If a border is required for accessibility (e.g., in high-contrast situations):
*   **Token:** `outline-variant` (#c2c6d5).
*   **Opacity:** Reduce to 20% opacity. It should be felt, not seen.

---

## 5. Components

### Buttons
*   **Primary:** Gradient of `primary` to `primary-container`. Corner radius: `md` (0.375rem). Use `on-primary` (#ffffff) for text.
*   **Secondary:** `surface-container-highest` background with `on-secondary-container` text. No border.
*   **Tertiary:** Pure text using `primary` color. Used for "Cancel" or "Back" actions.

### Cards & Lists
*   **Constraint:** Forbid divider lines between list items.
*   **Pattern:** Separate items using `spacing-2` or `spacing-3`. For high-density lists, use a 1px `surface-dim` background shift on hover to indicate interactivity.

### Input Fields
*   **State:** Default state uses `surface-container-low` background. 
*   **Focus:** Transition background to `surface-container-lowest` and add a 2px `primary` "Ghost Border" at 40% opacity.

### Navigation (App Specific)
*   **The Day-Selector:** A horizontal scroll of cards using `surface-container-lowest`. The "Active Day" should be the only element using the vibrant `primary-container` blue, making it the immediate focal point of the screen.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical spacing. A left margin of `spacing-8` paired with a right margin of `spacing-12` can create a more dynamic, "designed" feel.
*   **Do** use `tertiary` (#8a3500) sparingly. It is a warm accent meant only for urgent notifications or specific "Office Perk" highlights.
*   **Do** rely on the `Spacing Scale`. Every gap should be a multiple of the scale to maintain the "Architectural" rhythm.

### Don't
*   **Don’t** use pure black (#000000). Use `on-surface` (#0b1c30) for high-contrast text.
*   **Don’t** use heavy dropshadows. If the depth isn't clear through tonal shifts, rethink the layout.
*   **Don’t** use icons smaller than 24px for primary navigation. Maintain the "bold stroke" minimalist aesthetic to ensure the "Premium" feel is consistent.