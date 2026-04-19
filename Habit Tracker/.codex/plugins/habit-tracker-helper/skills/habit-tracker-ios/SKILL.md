---
name: habit-tracker-ios
description: Project-specific guidance for working on the Habit Tracker iOS app. Use when implementing, reviewing, or refactoring SwiftUI features in this codebase.
metadata:
  priority: 5
  pathPatterns:
    - 'Habit Tracker/**'
    - 'Habit TrackerTests/**'
    - 'Habit TrackerUITests/**'
  promptSignals:
    phrases:
      - "habit tracker"
      - "habit list"
      - "streak"
      - "reminder"
      - "swiftui habit app"
    anyOf:
      - "habit"
      - "tracker"
      - "swiftui"
      - "ios"
    minScore: 5
retrieval:
  aliases:
    - habit tracker ios
    - habit tracker swiftui
    - habit tracker app
  intents:
    - implement habit tracker feature
    - review habit tracker code
    - refactor habit tracker screen
  entities:
    - Habit Tracker
    - SwiftUI
    - iOS
---

# Habit Tracker iOS

Use this skill when working in the Habit Tracker app codebase.

## Project rules

- Do not run builds to test changes.
- Update the development log for every meaningful change.
- Add a new changelog entry at the top of the day file in `changelogs/`.
- If the day file does not exist, create it.
- Use clear, factual, outcome-focused language in changelog entries.

## Working style

- Preserve the app's existing SwiftUI structure unless there is a clear reason to refactor.
- Prefer targeted edits over broad rewrites.
- Watch for behavior changes around date-based filtering, completion state, reminders, and persisted settings.
- When reviewing changes, prioritize regressions in user flows before style concerns.

## Response expectations

When making changes in this project:

1. Implement the code change directly.
2. Update the daily changelog file.
3. Report what changed, any assumptions made, and what was not verified because builds are disallowed.
