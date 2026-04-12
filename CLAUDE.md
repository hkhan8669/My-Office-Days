# Project Rules

## IMPORTANT: Bug Fix Protocol
- BEFORE any bug fix, run `git diff HEAD~3` to review recent changes
- BEFORE modifying code, write a regression test that locks in current working behavior
- Make the SMALLEST change possible to fix the issue. Do not touch unrelated code.
- If a fix would undo or conflict with a recent change, STOP and ask me before proceeding
- Never silently revert a previous fix to solve a new problem
- When two concerns conflict, flag both and propose a solution that preserves both
- After every fix, commit immediately so we have a clean rollback point

## Planning
- Think hard before making changes. Read all relevant files first.
- For any change touching more than one file, write a brief plan and confirm with me before implementing
- If you are unsure about the root cause, say so. Do not guess and patch symptoms.

## Code Changes
- Do not refactor, rename variables, restructure files, or "clean up" code unless that is the explicit task
- If you feel tempted to improve nearby code, ask me first
- When told "never do X", always prefer the stated alternative. If no alternative is given, ask me for one.

## Testing
- Run build after every change: `cd "/Users/hamzakhan/SLM Office Attendance/OfficeDays" && xcodebuild -scheme OfficeDays -sdk iphoneos -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED" | tail -1`
- If no test exists for the area you are changing, write one BEFORE making the fix
- Verify geofence-related changes with the /review skill which covers known bug patterns

## Context Management
- When running /compact, YOU MUST preserve: the full list of modified files, current bugs and status, all entries from Lessons Learned below, and any active plan
- When switching tasks, suggest /clear to me so we start fresh
- Do not hold assumptions from earlier in a long session. Re-read files if context is stale.

## Learning From Mistakes
- When I point out a bug you introduced, a regression, or a repeated mistake, you MUST:
  1. Append a new entry to the "Lessons Learned" section at the BOTTOM of THIS file (./CLAUDE.md)
  2. Do this BEFORE continuing with the fix
- Format: `- [YYYY-MM-DD] Don't do X because it breaks Y; prefer Z instead`
- Never remove or edit existing lessons
- Review the Lessons Learned section before starting any bug fix to avoid repeating past mistakes

## Lessons Learned
- [2026-04-03] Don't use `DateHelper.isWeekday` or `AppPreferences.isWorkDay` as guards on geofence callbacks; it blocks non-configured workdays (e.g., Friday) from logging. Geofence must fire on ANY day.
- [2026-04-03] Don't stop and re-register all CLLocationManager regions in `refreshMonitoring()`; it resets iOS region state and drops pending exit/re-entry events. Use a diff approach (stop removed, add new, leave existing).
- [2026-04-03] Don't use a single notification ID ("checkin-latest") for all check-in notifications; they replace each other. Use per-office per-day IDs.
- [2026-04-03] Don't use `.sheet(isPresented:)` with `if let` for export share sheets; SwiftUI timing causes empty content. Use `.sheet(item:)` with `IdentifiableURL`.
- [2026-04-03] Don't use XML SpreadsheetML (.xls) for export; causes "needs repair" errors and Mail attachment issues. Use plain CSV.
- [2026-04-03] Don't write export files inside `UIViewControllerRepresentable.makeUIViewController`; the file is written after @State propagation, producing 0-byte files. Write synchronously in the button action.
- [2026-04-03] Don't use `@State` for splash screen visibility; it resets on every cold launch. Use `@AppStorage` to track if splash has been seen.
- [2026-04-03] Don't forget to check `ensureHolidays` for dismissed holiday tracking when merging external changes; the dismissed check can be silently removed.
- [2026-04-03] Don't let `togglePlanned` overwrite non-remote entries; it destroys office/vacation/holiday data. Only overwrite `.remote` entries.
- [2026-04-03] Don't use office name as CLCircularRegion identifier; renaming an office breaks geofence tracking. Use a stable UUID (`stableID`).
- [2026-04-03] Don't skip all days without entries in streak calculation; it inflates streaks across vacation gaps. Only skip weekends (Sat/Sun), break on weekdays without credited attendance.
- [2026-04-03] Don't start streak counting from today if today isn't logged yet; it shows 0 even with a valid streak. Start from yesterday if today has no credited entry.
- [2026-04-03] Don't use "automatic check-in", "auto-log", or "detect when you arrive" language in the app; Apple rejected it under Guideline 2.5.4 as employee tracking. Use "arrival reminders" and "geofencing" language.
- [2026-04-07] When adding a new property to a SwiftData @Model (like stableID on OfficeLocation), existing records get empty/default values — NOT the init value. Always add a backfill migration in seedIfNeeded() to populate the field on existing records. Without this, existing offices had stableID="" which broke geofence region tracking entirely.
- [2026-04-07] REVERTED: "Clear ALL entry timestamps on every foreground" was wrong. It caused: (1) duplicate GeoLog entries every app open, (2) log time = app open time not actual arrival, (3) multiple notifications per day, (4) broke exit tracking. The correct approach: only clear PREVIOUS DAY timestamps. Same-day timestamps must persist to prevent duplicates. didDetermineState should only create GeoLog on first detection of the day, but ALWAYS call logOfficeDayIfNeeded (so manual Remote changes get overwritten by physical presence).
- [2026-04-10] Entry timestamps key by stableID (UUID), not office name. The officeName(for:) resolver must never fall back to the raw UUID for user-facing strings. If lookup fails, use "Unknown Office" not the UUID. The UUID fallback caused "weird number" notifications.
- [2026-04-10] CORRECTED: didDetermineState MUST create ONE GeoLog per office per day (first detection, via !alreadyTracked). Without this, home office users who never leave the geofence get no GeoLog at all because didEnterRegion never fires. The alreadyTracked check prevents duplicates on subsequent app opens. didEnterRegion creates additional GeoLog entries on actual physical crossings.
- [2026-04-10] iOS geofence exit detection is unreliable for small/home regions. didExitRegion requires ~200m+ movement beyond boundary. This is an iOS limitation, not fixable in code. The app should still log exits when they fire, but users should not expect 100% exit capture at home offices.
