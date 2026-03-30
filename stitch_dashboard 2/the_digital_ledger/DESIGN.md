# Design System Specification: Architectural Precision

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Structural Blueprint."** 

Unlike generic "app-like" interfaces that rely on rounded corners and heavy drop shadows, this system draws inspiration from high-end architectural drafting and editorial ledgers. It moves beyond the "template" look through a commitment to **absolute linearity** and **tonal depth**. We achieve a premium feel not through decoration, but through the rigorous application of whitespace, sharp 0px radii, and a sophisticated layering of monochromatic surfaces. The goal is to make the user feel they are interacting with a high-end physical ledger—precise, authoritative, and permanent.

---

## 2. Colors & Surface Logic
The palette is rooted in `primary-container` (#003366), an "Architectural Blue" that conveys reliability. This is balanced by a clinical range of greys and crisp whites to ensure clarity.

### The "No-Line" Rule
To maintain a high-end editorial feel, designers are prohibited from using standard 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts. Use `surface-container-low` for secondary content areas sitting on a `surface` background. This creates "implied borders" that feel integrated rather than "pasted on."

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked architectural plates. 
- **Base Layer:** `surface` (#f8f9fb)
- **Secondary Structural Layer:** `surface-container-low` (#f2f4f6)
- **Nested Detail Layer:** `surface-container` (#eceef0)
- **Interactive/Floating Layer:** `surface-container-lowest` (#ffffff)

### The "Glass & Gradient" Rule
While we avoid "generic" gradients, we use **Signature Tonal Transitions** to provide soul. Main CTAs or Hero backgrounds may utilize a subtle linear gradient from `primary` (#001e40) to `primary-container` (#003366) at a 135-degree angle. For floating navigation or overlays, use **Glassmorphism**: apply `surface-container-lowest` at 80% opacity with a `20px` backdrop-blur to allow the structural grid to peek through.

---

## 3. Typography: The Editorial Voice
We use **Inter** exclusively. It is our "drafting" font—functional, modern, and professional.

*   **Display (lg/md):** Used for high-impact data points or section starters. Keep tracking at `-0.02em` to create a dense, authoritative feel.
*   **Headline (lg/md/sm):** These function as the "beams" of the layout. Use `on-surface` (#191c1e) for maximum contrast.
*   **Body (lg/md):** Our primary carrier of information. Ensure a generous line-height (1.5x) to maintain the "Architectural Ledger" feel of ordered information.
*   **Labels (md/sm):** Reserved for metadata and functional captions. Often used in uppercase with `+0.05em` letter-spacing to mimic architectural annotations.

---

## 4. Elevation & Depth
In this system, elevation is conveyed through **Tonal Layering** rather than traditional structural lines.

*   **The Layering Principle:** Depth is achieved by "stacking." A `surface-container-lowest` card placed on a `surface-container-low` section creates a natural, sharp lift without a shadow.
*   **Ambient Shadows:** If a floating effect is mandatory (e.g., a modal), use a shadow tinted with `on-surface` at 4% opacity with a blur of `32px`. It should feel like a soft glow, not a dark smudge.
*   **The "Ghost Border" Fallback:** If accessibility requires a stroke, use the **Ghost Border**: `outline-variant` (#c3c6d1) at **15% opacity**. Never use 100% opaque borders for containers.
*   **Zero-Radius Mandate:** All elements (buttons, cards, inputs) must use a `0px` border radius. Sharp corners are the hallmark of this system’s precision.

---

## 5. Components

### Buttons
*   **Primary:** Solid `primary` (#001e40), `0px` radius, `label-md` uppercase text. Padding: `1rem` (top/bottom) by `2rem` (left/right).
*   **Secondary:** Ghost style. `Ghost Border` (15% opacity `outline-variant`) with `on-primary-fixed-variant` text.
*   **Tertiary:** Text only. `label-md` with a 1px underline that appears only on hover.

### Input Fields
*   **Text Inputs:** No bottom line. Instead, use a subtle `surface-container-high` background. On focus, transition the background to `surface-container-highest` and add a `primary` 1px left-edge accent (the "Indicator Bar").
*   **Checkboxes/Radios:** Sharp `0px` squares. Checked state uses `primary-container`. Unchecked uses a 1px `outline` (#737780).

### Cards & Lists
*   **Forbid Dividers:** Do not use horizontal lines to separate list items. Use the **Spacing Scale** (e.g., `spacing-4`) to create "White Space Gutters."
*   **Tonal Grouping:** Group related list items inside a `surface-container-low` block to separate them from the main page flow.

### Ledger Data Table (Custom Component)
*   A signature component. Use `surface-container-lowest` for the header row with `label-sm` text. Alternate rows use a subtle shift between `surface` and `surface-container-low`. No vertical lines; use alignment to create structure.

---

## 6. Do's and Don'ts

### Do:
*   **Embrace Asymmetry:** Use wide margins on one side and dense information on the other to create a high-end editorial rhythm.
*   **Use the Spacing Scale Rigorously:** Use `spacing-12` or `spacing-16` for major section breaks to let the design breathe.
*   **Align to a Grid:** Every element must snap to a strict columns-and-rows logic.

### Don't:
*   **Don't use Rounded Corners:** No exceptions. `0px` is the standard.
*   **Don't use "App-style" Icons:** Avoid bubbly, filled icons. Use thin-stroke (1px), geometric, and sharp-angled iconography.
*   **Don't use Drop Shadows for Layout:** Shadows are for temporary overlays only. Layout depth is achieved through color tiers.
*   **Don't use Generic Blue:** Stick to the `Architectural Blue` (#003366) and its derivatives. Avoid vibrant, "tech" blues.