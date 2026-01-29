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

### 9. iCloud Sync
- Sync habits across devices
- Backup and restore

---

## Nice to Have

### 10. Gamification
- Points/XP for completions
- Achievements (first habit, 7-day streak, etc.)

### 11. Undo Completion
- "Undo" toast after marking complete
- Avoid accidental taps

### 12. Bulk Actions
- Select multiple habits
- Bulk edit category, schedule, or delete

### 13. Apple Watch
- Quick complete from watch
- Complication for today's progress

---

## Implementation Priority

1. **Streaks** – Strong motivation
2. **Swipe actions** – Better UX
3. **Skip today** – More realistic tracking
4. **History improvements** – Better insights
5. **Widget** – More visibility and quick access
