# App Store Launch Tasks for Quota

## Context
The app was renamed from "My Office Days" to "Quota - Track Office Days".
The code changes are done. These are the remaining App Store tasks.

## Task 1: Generate Simulator Screenshots

Build and run Quota on the following simulators and capture screenshots of each screen:

### Devices Needed (App Store requires these sizes):
- iPhone 16 Pro Max (6.9")
- iPhone 16 Pro (6.3")
- iPad Pro 13" (if supporting iPad)

### Screens to Capture (in order):
1. **Dashboard** — Show the progress ring with some credited days, the "on track" status, and recent activity
2. **Plan Tab** — Show a month with a mix of Office (O), Planned (P), Holiday (H), and Vacation (V) days
3. **Log Tab** — Show geofence entry/exit events with timestamps and the streak card
4. **Setup Tab** — Show offices list, tracking status "Active", and the goals section
5. **Onboarding - Welcome** — The first screen with "Quota" title
6. **Onboarding - Permissions** — Show the "Privacy First" callout and permission cards

### Steps:
```
1. cd "/Users/hamzakhan/SLM Office Attendance/OfficeDays"
2. xcodebuild -scheme OfficeDays -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build
3. Open Simulator, navigate to each screen
4. Take screenshots using: xcrun simctl io booted screenshot ~/Desktop/AppScreenshots/[name].png
5. Repeat for each device size
```

Save all screenshots to: `~/Desktop/AppScreenshots/`

## Task 2: Create App Store Screenshots with AppLaunchFlow

### Tool: https://dashboard.applaunchflow.com/upload

### Screenshot Frame Content (6 slides):

**Slide 1 — Dashboard**
- Headline: "Hit Your Office Quota"
- Subheadline: "Track your hybrid attendance at a glance"
- Screen: Dashboard with progress ring
- Background: Dark navy (#1E3A5F)

**Slide 2 — Plan Tab**
- Headline: "Plan Your Week"
- Subheadline: "Drag to schedule your office days"
- Screen: Plan tab showing a full month
- Background: White (#FFFFFF)

**Slide 3 — Auto Tracking**
- Headline: "Arrive. Done."
- Subheadline: "GPS reminders log your day automatically"
- Screen: Log tab showing entry/exit events
- Background: Blue (#0064D2)

**Slide 4 — Insights**
- Headline: "Know Your Numbers"
- Subheadline: "Streaks, trends, and quarterly progress"
- Screen: Log tab showing streak card + stats
- Background: Dark navy (#1E3A5F)

**Slide 5 — Privacy**
- Headline: "100% Private"
- Subheadline: "All data stays on your device. Always."
- Screen: Setup showing Privacy First card
- Background: Green (#059669)

**Slide 6 — Export**
- Headline: "Export Anytime"
- Subheadline: "Download your attendance as a CSV"
- Screen: Setup showing export section
- Background: White (#FFFFFF)

### Steps:
1. Open https://dashboard.applaunchflow.com/upload in browser
2. Upload the simulator screenshots from ~/Desktop/AppScreenshots/
3. Apply the headline/subheadline text above to each frame
4. Download the framed screenshots
5. Upload to App Store Connect under the appropriate device sizes

## Task 3: Update App Store Connect Metadata

### App Name:
Quota - Track Office Days

### Subtitle (30 chars max):
Hybrid Work Attendance Planner

### Keywords (100 chars max):
hybrid work,office days,attendance,remote work,vacation,RTO,work planner,office reminder,compliance

### Description:
Your company says "come in 3 days a week." But which days did you actually go? How many this quarter? Are you on track?

Quota answers all of that -- so you never have to think about it.

Just save your office location once and let your phone handle the rest. Using GPS geofencing, Quota quietly sends you a reminder when you arrive at the office and helps you log your day. No spreadsheets, no manual tracking. It just works.


ARRIVAL REMINDERS
Your phone recognizes when you arrive at a saved office and reminds you to log it -- even in the background. Zero effort required.

VISUAL PROGRESS TRACKING
A clear dashboard shows your quarterly or monthly progress at a glance. Know instantly whether you're on track, ahead, or behind your target.

SMART CALENDAR
See your entire month color-coded by day type -- office, remote, vacation, holidays, travel, and planned days all in one place. Tap any day to edit.

VACATION & TRAVEL LOGGING
Mark time off and business trips with a tap. Your numbers adjust automatically.

FLEXIBLE GOALS
Set your own targets by quarter or month. Whether your policy is 2 days a week or 4, the app adapts to you.

CSV EXPORT
Need a record for yourself or HR? Export your full attendance history as a CSV anytime.

MULTI-OFFICE SUPPORT
Save multiple office locations -- headquarters, satellite offices, or home office. Each one gets its own geofence.


100% PRIVATE. YOUR DATA NEVER LEAVES YOUR PHONE.

This is the part we take most seriously. Quota stores everything on your device and nowhere else. There are no servers, no cloud sync, no analytics, and no accounts. Your location is used only to detect office arrivals and is never recorded or shared. You can delete all your data anytime from Settings. When you remove the app, your data is gone for good.

Built for hybrid workers who want a simple, private way to stay on top of their office attendance. Download Quota and stop worrying about it.

### What's New (v1.1):
- Renamed to Quota
- Arrival reminders now work on any day of the week
- Improved geofence reliability for multi-office setups
- Added Delete All My Data option in Settings
- CSV export now includes every calendar day
- Fixed streak calculation accuracy
- Privacy-first language throughout

### App Review Notes:
This app uses background location via CLCircularRegion geofence monitoring to send arrival reminders when the user reaches a saved office location. This is battery-efficient, event-driven region monitoring -- not continuous GPS tracking. The user can log days manually without location access. All data is stored locally on-device using SwiftData. Nothing is uploaded or transmitted. Users can delete all data from Settings > Data & Privacy > Delete All My Data.

### Privacy Policy URL:
(You need to host a privacy policy page and add the URL here)

### Support URL:
(You need a support page or email -- can use mailto:kviction@gmail.com)

### App Store Privacy Section:
Select "Data Not Collected" for all categories -- the app does not collect or transmit any user data.
