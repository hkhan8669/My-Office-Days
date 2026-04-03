# Deep Code Review

You are performing a comprehensive code review on the current codebase. This checklist was built from real bugs, rework, and lessons learned across multiple app development cycles. Apply every section systematically. Report findings grouped by severity: **Critical**, **Warning**, **Suggestion**.

---

## 1. Data Consistency & Single Source of Truth

- [ ] When the same value is computed in multiple places (e.g., "days remaining" on a dashboard AND in a pace calculator), verify they use **identical inputs and logic**. Mismatched sources are the #1 cause of confusing UI bugs.
- [ ] If a value is derived (e.g., credited days = office + travel + vacation based on settings), trace every call site to confirm they all respect the same user preferences/configuration.
- [ ] Check that enums used in switch statements are exhaustive. If a new case was added to an enum, search for every `switch` on that enum and verify the new case is handled (not just falling into `default`).
- [ ] Look for "shadow state" — two variables that should always agree but are updated independently. Prefer computing one from the other.

## 2. Multi-User & Multi-Device Thinking

- [ ] Any sequential/incremental IDs (ticket numbers, counters stored in UserDefaults/local DB) will collide across users or devices. Use **random alphanumeric IDs** (6-8 chars, excluding ambiguous characters like O/0/I/1/l) for anything that might be seen by a shared recipient (e.g., support emails, shared exports).
- [ ] Anything persisted locally (UserDefaults, local DB) — consider what happens on reinstall, new device, or multiple devices. Will the app behave correctly with a fresh state?

## 3. Bundle, Display Name & App Identity

- [ ] `CFBundleDisplayName` in Info.plist must match the intended app name **with correct spacing**. Also verify `INFOPLIST_KEY_CFBundleDisplayName` in the Xcode project build settings for ALL build configurations (Debug + Release).
- [ ] `CFBundleName` (the short name) may truncate on the home screen. Test that both the short and display names render correctly.
- [ ] Check that the app name used in exports, emails, about screens, and onboarding text all match the canonical display name.

## 4. Export & File Output

- [ ] Export filenames should include enough context to be useful: app name + **full date** (e.g., "My App Apr 2 2026.xls"), not just a year or generic name.
- [ ] If using XML Spreadsheet format (`<?mso-application progid="Excel.Sheet"?>`):
  - Verify every `<Worksheet>` has a matching `</Worksheet>`, every `<Table>` has `</Table>`, every `<Row>` has `</Row>`.
  - Verify every `ss:StyleID` referenced in cells is actually defined in `<Styles>`.
  - Test that the file opens in both Excel and Numbers/Google Sheets.
- [ ] Data that belongs in separate contexts (daily log vs. summary) should be on **separate tabs/sheets**, not concatenated vertically.
- [ ] Color-coding in exports should match the app's UI color-coding so users aren't confused by inconsistent visual language.
- [ ] Separate logical data into their own columns (e.g., check-in time should NOT be concatenated with the date — it deserves its own column for sorting/filtering).
- [ ] XML/HTML content must escape `&`, `<`, `>`, `"` in all user-supplied strings to prevent malformed output.

## 5. Input Validation & Edge Cases

- [ ] All user text inputs should be **trimmed** (whitespace) before use. Guard against empty strings after trimming.
- [ ] Onboarding flows: verify that "Continue" / "Next" buttons are **disabled** until required input is provided (e.g., at least one office added before proceeding).
- [ ] Date-based features: check behavior for past dates vs. future dates. Can the user select a day type that doesn't make sense for a past date (e.g., "Planned" for yesterday)? Filter available options by temporal context.
- [ ] Deletion flows: if an item repeats (holidays across years, recurring events), offer both "delete this instance" and "delete all instances" options.
- [ ] Addition flows: if an item could logically repeat (holidays, recurring events), offer a "repeat every year" option rather than requiring manual entry per year.

## 6. Dead Code & Cleanup

- [ ] When a feature is removed (e.g., removing a holiday from defaults), trace ALL references: model code, tests, UI labels, onboarding text, counts displayed to users. A removed holiday that still says "13 holidays" in onboarding is a bug.
- [ ] After removing an enum case, search for it by name across the entire codebase — tests, view logic, helpers, export code.
- [ ] Remove helper methods that only existed to support removed features (e.g., an `easterSunday()` calculator after removing Good Friday).
- [ ] Don't leave commented-out code, `// removed` markers, or renamed `_unused` variables. Delete cleanly.

## 7. Crash Safety

- [ ] Search for force unwraps (`!`) on optionals. Replace with `guard let` / `if let` or `?? defaultValue`, especially in loops and data processing paths where one bad record shouldn't crash the app.
- [ ] Search for `%@` format specifiers in SwiftUI `Text()` — SwiftUI uses string interpolation (`\(variable)`), not `NSString` format specifiers.
- [ ] Array subscript access (`array[index]`) should be bounds-checked or use `.first`, `.last`, safe subscript extensions.

## 8. Concurrency & Threading

- [ ] ViewModels and services accessed from SwiftUI views should be `@MainActor` isolated.
- [ ] Background operations (geofencing callbacks, notifications) that update UI state must dispatch to the main actor.
- [ ] Debounce logic: rapid-fire events (geofence enter/exit, notification triggers) need debouncing. Verify the debounce window is reasonable (e.g., 10 minutes for geofence re-entry at the same location).

## 9. Geolocation & Sensor Features

- [ ] Multi-region scenarios: if the user has multiple geofenced locations, what happens when they visit two in one day? Verify "last one wins" or whatever the intended policy is, and that the log trail is complete (enter/exit for each).
- [ ] Permission descriptions: `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription` must have clear, user-friendly text explaining why location is needed.
- [ ] Graceful degradation: if location permission is denied or restricted, the app should still function (manual logging) without crashing or showing broken UI.

## 10. UI Label Accuracy

- [ ] Every label, legend, and heading must accurately describe what it represents **right now**, not what it represented in a previous version. If the underlying data changed, the label must change too.
- [ ] Numeric labels ("12 holidays", "3 offices") must be computed or kept in sync with actual data, not hardcoded.
- [ ] Pace/status indicators: if thresholds or categories changed (e.g., merging "At Risk" into "Tight"), verify every UI element referencing the old categories is updated — badges, colors, explanatory text, info sheets.

## 11. Settings & Configuration Propagation

- [ ] When a setting controls behavior (e.g., "count vacation days toward target"), trace every code path that should respect it. Export logic, dashboard calculations, pace indicators, and summary views must ALL check the setting.
- [ ] Toggling a setting should take effect immediately or on next relevant action — not require an app restart.
- [ ] Default values for new settings should be sensible for existing users who upgrade (don't break their experience with a new default).

## 12. Test Coverage

- [ ] Tests that reference removed features/data must be updated or removed. A test asserting "13 holidays" when the app now has 12 is a false-passing or false-failing test.
- [ ] After changing business logic thresholds (pace categories, validation rules), update test assertions to match.
- [ ] Boundary tests: test at exact threshold values (e.g., if "On Track" is <= 3.0 days/week, test at exactly 3.0 and 3.01).

## 13. Email, Sharing & External Communication

- [ ] Pre-populated email subjects should include unique identifiers (ticket IDs) so threads don't merge in the recipient's inbox.
- [ ] Verify `mailto:` links include proper encoding for subject and body.
- [ ] Share sheets: verify the shared content matches what the user sees in-app. No stale cached files — delete previous temp files before writing new ones.

## 14. Architectural Smell Check

- [ ] Methods over 100 lines: consider if they should be broken up for readability (but don't over-abstract — only split if there are natural logical boundaries).
- [ ] View files over 500 lines: consider if sections (subviews, share sheets, helper structs) should be extracted to separate files.
- [ ] Duplicated logic across views: if two views compute the same derived value, it should live in the ViewModel or a shared helper.

---

## How to Report

For each finding, report:
1. **File:line** — exact location
2. **Category** — which checklist item it falls under
3. **Severity** — Critical (crash/data loss), Warning (incorrect behavior), Suggestion (quality improvement)
4. **What's wrong** — concise description
5. **Fix** — concrete recommendation

After reporting, ask whether to proceed with fixes or if the user wants to review first.
