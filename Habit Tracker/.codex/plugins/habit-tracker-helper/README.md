# Habit Tracker Helper Plugin

This is a project-local Codex plugin scaffold for the Habit Tracker app.

## What it includes

- `.codex-plugin/plugin.json`: plugin manifest
- `skills/habit-tracker-ios/SKILL.md`: starter app-specific skill

## Why use a plugin

Use a plugin when you want reusable project knowledge to travel together:

- app architecture and naming conventions
- review and implementation rules
- common workflows and reminders
- optional MCP server or slash command wiring later

## Recommended next steps

1. Add more skills under `skills/` for distinct workflows.
2. Keep each skill narrowly scoped and outcome-focused.
3. Add `.mcp.json` later if you want the plugin to expose custom MCP servers.
4. Add `commands/` later if you want slash-command entry points.

## Suggested future skills

- `habit-tracker-ui-review`
- `habit-tracker-data-modeling`
- `habit-tracker-release-notes`
- `habit-tracker-notifications`

## Notes

This scaffold is intentionally minimal. It gives you a valid plugin shape that mirrors the installed Codex plugins without adding unnecessary moving parts.
