# Habit Tracker – Enhancement Ideas

A curated list of potential improvements, organized by impact.

---

## Implemented

### Custom Icons per Habit
- SF Symbol picker for each habit (`IconPickerView`, `HabitIcons`)
- Stored in Core Data as `iconName`
- Displayed in habit rows, new habit form, and habit detail

### Theme Picker
- Theme mode: System / Light / Dark (`AppThemeMode` in `ThemeStore`)
- Accent color: Blue, Purple, Green, Orange, Pink, Teal (`AppAccentColor`)
- Applied app-wide via `preferredColorScheme` and `tint` in `Habit_TrackerApp`

### iCloud Backup & Sync
- Existing Core Data store is mirrored to the user's private iCloud database
- Habits and completion history sync across devices
- Settings reports confirmed CloudKit exports and any sync errors
- Fresh installations check CloudKit at launch and offer to restore imported habits

---

## High Impact

### 1. Streaks & Statistics
- Show current streak per habit (e.g. "5 day streak")
- Weekly/monthly completion rate
- Best streak ever
- Calendar heatmap (like GitHub contributions)

### 2. History View Improvements
- Filter by date range
- Completion trends over time
- Export history (CSV/JSON)

### 3. Swipe Actions on Habit Rows
- Swipe right: complete
- Swipe left: edit or delete
- Faster than tapping into detail

### 4. "Skip Today"
- Option to skip a habit for today without breaking streak
- Useful for habits that don't apply every day

### 5. Home Screen Widget
- Today's habits and completion status
- Quick complete from widget

---

## Medium Impact

### 6. Notes/Description
- Optional notes per habit (e.g. "Drink 8 glasses", "30 min run")

### 7. Snooze Reminder
- Snooze notification for 15/30/60 min
- Reschedule without opening app

### 8. Habit Templates
- Presets like "Morning routine", "Exercise", "Reading"
- One-tap add with common settings

---

## Nice to Have

### 9. Gamification
- Points/XP for completions
- Achievements (first habit, 7-day streak, etc.)

### 10. Undo Completion
- "Undo" toast after marking complete
- Avoid accidental taps

### 11. Bulk Actions
- Select multiple habits
- Bulk edit category, schedule, or delete

### 12. Apple Watch
- Quick complete from watch
- Complication for today's progress

---

## Implementation Priority

1. **Streaks** – Strong motivation
2. **Swipe actions** – Better UX
3. **Skip today** – More realistic tracking
4. **History improvements** – Better insights
5. **Widget** – More visibility and quick access
