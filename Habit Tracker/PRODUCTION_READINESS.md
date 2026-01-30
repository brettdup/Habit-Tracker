# Habit Tracker – Production Readiness Roadmap

A comprehensive checklist of what’s needed to make this app a fully fledged, App Store–ready iOS app.

---

## Critical (Must Fix Before Release)

### 1. **Settings View iOS Compatibility**
- **Issue:** `SettingsView` is `@available(iOS 18.0, *)` only. On iOS 17.x, users see a placeholder "Settings" text.
- **Fix:** Provide a fallback `SettingsView` for iOS 17.x with the same functionality (theme, accent, notifications, reset time, about) using APIs available on iOS 17.

### 2. **Placeholder URLs in Settings**
- **Issue:** Privacy Policy and Terms of Service link to `https://www.example.com/privacy` and `https://www.example.com/terms`.
- **Fix:** Replace with real URLs or remove the links until you have live pages. Broken/placeholder links can cause App Review rejection.

### 3. **Notification Cleanup Bug** ✅ Fixed
- ~~**Issue:** In `HabitListView.deleteReminders(for:)`, only one identifier is removed.~~
- **Fix:** Now removes all identifiers `[base, base-multi, base-1...base-7]` when deleting a habit.

### 4. **Replace `fatalError` with User-Facing Error Handling** ✅ Fixed
- **Issue:** `fatalError` is used in `Persistence.swift`, `HabitDetailView`, and `HabitListView` for Core Data errors. This crashes the app instead of recovering or informing the user.
- **Fix:** Replace with `try?` or `do/catch`, show an alert or toast, and optionally retry. Never crash for expected failure cases.

### 5. **Daily Reset Time** ✅ Removed
- Reset is always midnight. The Daily Reset Time setting has been removed from Settings.
- **Fix:** Either wire `resetTime` into the reset logic (e.g. in `resetHabitsIfNewDay`) or remove the setting until it’s implemented.

---

## App Store Requirements

### 6. **Info.plist / Privacy**
- Add `NSUserNotificationsUsageDescription` if you want a custom notification permission message.
- Add `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` only if you add photo features.
- Ensure `UIBackgroundModes` is set only if you use background modes (e.g. background fetch).

### 7. **App Icon**
- You have a 1024×1024 universal icon. Ensure it meets [App Store icon guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons) (no transparency, correct corner radius, etc.).

### 8. **Launch Screen**
- Launch screen exists and uses "Habit Tracker" branding. Verify it looks correct on all supported device sizes and orientations.

### 9. **Minimum Deployment Target**
- Currently iOS 17.4. Consider whether you need to support older iOS versions for a broader audience.

---

## High-Impact Features (from ENHANCEMENTS.md)

### 10. **Streaks & Statistics**
- Current streak per habit (e.g. "5 day streak").
- Weekly/monthly completion rate.
- Best streak ever.
- Calendar heatmap (GitHub-style).

### 11. **History View Improvements**
- Filter by date range.
- Completion trends over time.
- Export history (CSV/JSON).

### 12. **Swipe Actions on Habit Rows**
- Swipe right: complete habit.
- Swipe left: edit or delete.
- Speeds up common actions without opening detail.

### 13. **"Skip Today"**
- Option to skip a habit for today without breaking the streak.
- Useful for habits that don’t apply every day.

### 14. **Home Screen Widget**
- Today’s habits and completion status.
- Quick complete from widget (if supported).

---

## Polish & UX

### 15. **Undo Completion**
- Toast with "Undo" after marking a habit complete to avoid accidental taps.

### 16. **Empty Name Validation**
- Prevent creating habits with blank names (trim whitespace, show validation).

### 17. **Accessibility**
- Add `accessibilityLabel` and `accessibilityHint` to key controls (checkboxes, buttons, habit rows).
- Ensure VoiceOver and Dynamic Type work well.
- Test with Reduce Motion enabled.

### 18. **Localization**
- Add `Localizable.strings` for all user-facing strings.
- Support at least one additional language if targeting international users.

### 19. **Haptic Feedback**
- Light haptic when completing a habit or performing key actions.

---

## Optional / Nice to Have

### 20. **iCloud Sync**
- Sync habits and completion history across devices via Core Data + CloudKit.

### 21. **Habit Templates**
- Presets like "Morning routine", "Exercise", "Reading" for one-tap setup.

### 22. **Snooze Reminder**
- Snooze notification for 15/30/60 minutes from the notification itself.

### 23. **Notes/Description per Habit**
- Optional notes (e.g. "Drink 8 glasses", "30 min run").

### 24. **Apple Watch**
- Quick complete from watch.
- Complication for today’s progress.

### 25. **Gamification**
- Points/XP, achievements (first habit, 7-day streak, etc.).

---

## Code Quality

### 26. **Remove Debug Prints**
- Remove or gate `print` statements (e.g. in `HabitListView.addCompletionRecord`, `AppDelegate`).

### 27. **Unit Tests**
- Add tests for `HabitSchedule`, `resetHabitsIfNewDay`, streak calculation (once implemented), and Core Data operations.

### 28. **UI Tests**
- Basic flows: create habit, complete habit, delete habit, open settings.

---

## Summary Priority Order

| Priority | Item |
|----------|------|
| P0 | Fix notification cleanup bug (#3) |
| P0 | Settings fallback for iOS 17 (#1) |
| P0 | Replace placeholder Privacy/Terms URLs (#2) |
| P0 | Replace `fatalError` with graceful error handling (#4) |
| P1 | Wire up or remove Daily Reset Time (#5) |
| P1 | App Store privacy/Info.plist (#6) |
| P1 | Streaks & basic statistics (#10) |
| P1 | Swipe actions on habit rows (#12) |
| P2 | Skip Today (#13) |
| P2 | Undo completion (#15) |
| P2 | Accessibility (#17) |
| P2 | Empty name validation (#16) |
| P3 | Widget, iCloud, Watch, etc. |

---

*Last updated: January 2025*
