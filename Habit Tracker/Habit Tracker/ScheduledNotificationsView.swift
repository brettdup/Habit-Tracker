//
//  ScheduledNotificationsView.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/04.
//

import SwiftUI
import CoreData
import UserNotifications

private struct ReminderGroup: Identifiable {
    let id: String
    let title: String
    let body: String
    let scheduleText: String
    let nextTriggerDate: Date?
    let todaysRemainingTriggerDates: [Date]
    let pendingNextTriggerDate: Date?
    let pendingTodayTriggerDates: [Date]
    let displayTime: Date?
    let pendingCount: Int
    let expectedPendingCount: Int
    let hasPendingMismatch: Bool
}

private struct RandomNudgeGroup: Identifiable {
    let id: UUID
    let nudge: RandomNudge
    let requests: [UNNotificationRequest]
    let nextTriggerDate: Date?
    let todaysTriggerDates: [Date]
}

struct ScheduledNotificationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var reminderGroups: [ReminderGroup] = []
    @State private var randomNudgeGroups: [RandomNudgeGroup] = []
    @State private var pendingDeleteGroup: ReminderGroup?
    @State private var pendingDeleteNudgeGroup: RandomNudgeGroup?
    @State private var editingNudge: RandomNudge?
    @State private var showAddRandomNudge = false

    var body: some View {
        AppListContainer {
            if reminderGroups.isEmpty && randomNudgeGroups.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Active Notifications", systemImage: "bell.slash")
                    } description: {
                        Text("Add habit reminders or random nudges to see scheduled notifications here.")
                    }
                }
            } else {
                if !randomNudgeGroups.isEmpty {
                    Section {
                        Text("Random nudges are separate from habits and do not track completions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Random Nudges")
                    }

                    Section {
                        ForEach(randomNudgeGroups) { group in
                            randomNudgeListRow(for: group)
                        }
                    }
                }

                if !reminderGroups.isEmpty {
                    Section("Habit Reminders") {
                        ForEach(reminderGroups) { group in
                            ReminderRow(group: group)
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Remove", role: .destructive) {
                                        pendingDeleteGroup = group
                                    }
                                }
                                .contextMenu {
                                    Button("Remove Reminder", role: .destructive) {
                                        pendingDeleteGroup = group
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddRandomNudge = true
                } label: {
                    Label("Add Random Nudge", systemImage: "sparkles")
                }
            }
        }
        .onAppear {
            refreshScheduledNotificationsAfterQueueSettles()
        }
        .alert("Remove reminder?", isPresented: deleteConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingDeleteGroup = nil
            }
            Button("Remove", role: .destructive) {
                if let group = pendingDeleteGroup {
                    removeReminderGroup(group)
                }
                pendingDeleteGroup = nil
            }
        } message: {
            if let group = pendingDeleteGroup {
                Text("This will remove \(group.pendingCount) scheduled reminder\(group.pendingCount == 1 ? "" : "s") for this habit.")
            } else {
                Text("This reminder will be removed.")
            }
        }
        .alert("Remove random nudge?", isPresented: deleteNudgeConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                pendingDeleteNudgeGroup = nil
            }
            Button("Remove", role: .destructive) {
                if let group = pendingDeleteNudgeGroup {
                    removeRandomNudgeGroup(group)
                }
                pendingDeleteNudgeGroup = nil
            }
        } message: {
            if let group = pendingDeleteNudgeGroup {
                Text("This will remove all scheduled nudges for \"\(group.nudge.title)\".")
            } else {
                Text("This random nudge will be removed.")
            }
        }
        .sheet(isPresented: $showAddRandomNudge, onDismiss: refreshScheduledNotificationsAfterQueueSettles) {
            AddRandomNudgeView {
                refreshScheduledNotificationsAfterQueueSettles()
            }
        }
        .sheet(item: $editingNudge, onDismiss: refreshScheduledNotificationsAfterQueueSettles) { nudge in
            AddRandomNudgeView(existingNudge: nudge) {
                refreshScheduledNotificationsAfterQueueSettles()
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteGroup != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteGroup = nil
                }
            }
        )
    }

    private var deleteNudgeConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteNudgeGroup != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteNudgeGroup = nil
                }
            }
        )
    }

    private func fetchScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let habitRequests = requests.filter { $0.identifier.hasPrefix("habitReminder-") }
                let nudgeRequests = requests.filter { $0.identifier.hasPrefix("randomNudge-") }
                reminderGroups = groupRequests(habitRequests)
                    .sorted(by: { g1, g2 in
                        let d1 = g1.nextTriggerDate ?? Date.distantFuture
                        let d2 = g2.nextTriggerDate ?? Date.distantFuture
                        if d1 != d2 { return d1 < d2 }
                        return g1.title < g2.title
                    })
                randomNudgeGroups = groupRandomNudgeRequests(nudgeRequests)
                    .sorted(by: { g1, g2 in
                        let d1 = g1.nextTriggerDate ?? Date.distantFuture
                        let d2 = g2.nextTriggerDate ?? Date.distantFuture
                        if d1 != d2 { return d1 < d2 }
                        return g1.nudge.title < g2.nudge.title
                    })
            }
        }
    }

    private func refreshScheduledNotificationsAfterQueueSettles() {
        fetchScheduledNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            fetchScheduledNotifications()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            fetchScheduledNotifications()
        }
    }

    @ViewBuilder
    private func randomNudgeListRow(for group: RandomNudgeGroup) -> some View {
        RandomNudgeRow(group: group)
            .contentShape(Rectangle())
            .onTapGesture {
                editingNudge = group.nudge
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    editingNudge = group.nudge
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.accentColor)

                Button("Remove", role: .destructive) {
                    pendingDeleteNudgeGroup = group
                }
            }
            .contextMenu {
                Button("Edit Random Nudge") {
                    editingNudge = group.nudge
                }

                Button("Remove Random Nudge", role: .destructive) {
                    pendingDeleteNudgeGroup = group
                }
            }
    }

    private func removeNotifications(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        fetchScheduledNotifications()
    }

    private func removeReminderGroup(_ group: ReminderGroup) {
        clearReminderState(forBaseIdentifier: group.id)
        HabitReminderScheduler.removeNotifications(forBaseIdentifier: group.id)
        fetchScheduledNotifications()
    }

    private func removeRandomNudgeGroup(_ group: RandomNudgeGroup) {
        RandomNudgeStore.remove(id: group.id)
        RandomNudgeGeneratedScheduleStore.clear(nudgeID: group.id)
        RandomNudgeScheduler.removePending(for: group.id)
        refreshScheduledNotificationsAfterQueueSettles()
    }

    private func clearReminderState(forBaseIdentifier baseIdentifier: String) {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.fetchLimit = 1

        guard let habits = try? viewContext.fetch(request),
              let habit = habits.first(where: { HabitReminderScheduler.baseIdentifier(for: $0) == baseIdentifier }) else {
            return
        }

        habit.reminderTime = nil
        habit.notificationIdentifier = nil

        do {
            try viewContext.save()
        } catch {
            print("Error clearing reminder state: \(error.localizedDescription)")
        }
    }

    private func groupRequests(_ requests: [UNNotificationRequest]) -> [ReminderGroup] {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        guard let habits = try? viewContext.fetch(request) else { return [] }

        return habits.compactMap { habit in
            guard habit.reminderTime != nil else { return nil }

            let base = HabitReminderScheduler.baseIdentifier(for: habit)
            let matchingRequests = requests.filter { request in
                request.identifier == base || request.identifier.hasPrefix("\(base)-")
            }
            let upcomingDates = nextReminderDates(for: habit, limit: 7)
            let nextDate = upcomingDates.first
            let todaysRemainingDates = upcomingDates.filter { Calendar.current.isDateInToday($0) }
            let pendingDates = matchingRequests
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .sorted()
            let pendingTodayDates = pendingDates.filter { Calendar.current.isDateInToday($0) }
            let expectedPendingCount = expectedPendingRequestCount(for: habit)

            return ReminderGroup(
                id: base,
                title: "Reminder - \(habit.name ?? "")",
                body: "Don't forget to complete your habit: \(habit.name ?? "")",
                scheduleText: HabitScheduleResolver.label(for: habit),
                nextTriggerDate: nextDate,
                todaysRemainingTriggerDates: todaysRemainingDates,
                pendingNextTriggerDate: pendingDates.first,
                pendingTodayTriggerDates: pendingTodayDates,
                displayTime: habit.reminderTime,
                pendingCount: matchingRequests.count,
                expectedPendingCount: expectedPendingCount,
                hasPendingMismatch: hasPendingMismatch(
                    habit: habit,
                    pendingCount: matchingRequests.count,
                    expectedPendingCount: expectedPendingCount,
                    expectedNextDate: nextDate,
                    pendingNextDate: pendingDates.first
                )
            )
        }
    }

    private func nextReminderDates(for habit: Habit, limit: Int) -> [Date] {
        guard let reminderTime = habit.reminderTime else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startDay = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        var results: [Date] = []

        for offset in 0..<14 {
            guard results.count < limit else { break }
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            guard HabitScheduleResolver.isActive(habit: habit, on: day, calendar: calendar) else { continue }
            guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            guard fireDate > now else { continue }
            results.append(fireDate)
        }

        return results
    }

    private func groupRandomNudgeRequests(_ requests: [UNNotificationRequest]) -> [RandomNudgeGroup] {
        let nudgesByID = Dictionary(uniqueKeysWithValues: RandomNudgeStore.fetchAll().map { ($0.id, $0) })
        let grouped = Dictionary(grouping: requests, by: { randomNudgeID(from: $0.identifier) })

        return grouped.compactMap { id, reqs in
            guard let id, let nudge = nudgesByID[id] else { return nil }
            let sortedReqs = reqs.sorted { $0.identifier < $1.identifier }
            let upcomingDates = sortedReqs
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .sorted()
            let todaysDates = upcomingDates.filter { Calendar.current.isDateInToday($0) }
            return RandomNudgeGroup(
                id: id,
                nudge: nudge,
                requests: sortedReqs,
                nextTriggerDate: upcomingDates.first,
                todaysTriggerDates: todaysDates
            )
        }
    }

    private func randomNudgeID(from identifier: String) -> UUID? {
        let prefix = "randomNudge-"
        guard identifier.hasPrefix(prefix) else { return nil }
        let remainder = String(identifier.dropFirst(prefix.count))
        guard remainder.count >= 36 else { return nil }
        let uuidToken = String(remainder.prefix(36))
        return UUID(uuidString: uuidToken)
    }

    private func hasPendingMismatch(
        habit: Habit,
        pendingCount: Int,
        expectedPendingCount: Int,
        expectedNextDate: Date?,
        pendingNextDate: Date?
    ) -> Bool {
        if HabitIntervalScheduleStore.interval(for: habit)?.intervalDays ?? 1 > 1 {
            switch (expectedNextDate, pendingNextDate) {
            case (nil, nil):
                return false
            case let (expected?, pending?):
                return minuteToken(for: expected) != minuteToken(for: pending)
            default:
                return true
            }
        }

        if pendingCount != expectedPendingCount {
            return true
        }

        return pendingCount == 0 && expectedNextDate != nil
    }

    private func minuteToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func expectedPendingRequestCount(for habit: Habit) -> Int {
        if HabitIntervalScheduleStore.interval(for: habit)?.intervalDays ?? 1 > 1 {
            return min(nextReminderDates(for: habit, limit: 45).count, 45)
        }

        let mask = habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask
        if mask == HabitSchedule.allDaysMask {
            return 1
        }

        return HabitWeekday.allCases.reduce(into: 0) { count, weekday in
            if HabitSchedule.isSelected(weekday, mask: mask) {
                count += 1
            }
        }
    }

}

private struct RandomNudgeRow: View {
    let group: RandomNudgeGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.nudge.title)
                    .font(.headline)
                Text("Random \(group.nudge.nudgesPerDay)x/day · \(wakeWindowLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(nextLabel(group.nextTriggerDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !group.todaysTriggerDates.isEmpty {
                    Text(todayTimesLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var wakeWindowLabel: String {
        String(format: "%02d:%02d-%02d:%02d",
               group.nudge.wakeStartHour,
               group.nudge.wakeStartMinute,
               group.nudge.wakeEndHour,
               group.nudge.wakeEndMinute)
    }

    private func nextLabel(_ date: Date?) -> String {
        guard let date else { return "No upcoming nudge" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return "Next nudge \(relative.localizedString(for: date, relativeTo: Date()))"
    }

    private var todayTimesLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        let labels = group.todaysTriggerDates.map { formatter.string(from: $0) }
        return "Today: \(labels.joined(separator: " · "))"
    }
}

private struct ReminderRow: View {
    let group: ReminderGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.title)
                    .font(.headline)

                Text("\(timeLabel(group.displayTime)), \(group.scheduleText.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(nextLabel(group.nextTriggerDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !group.todaysRemainingTriggerDates.isEmpty {
                    Text(expectedTodayLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(pendingLineLabel)
                    .font(.footnote)
                    .foregroundStyle(group.hasPendingMismatch ? .red : .secondary)

                if group.hasPendingMismatch {
                    Text("Pending in iOS does not match the expected schedule.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func nextLabel(_ date: Date?) -> String {
        guard let date else { return "Unknown time" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        let rel = relative.localizedString(for: date, relativeTo: Date())
        return "Next alert \(rel)"
    }

    private func timeLabel(_ date: Date?) -> String {
        guard let date else { return "Unknown time" }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var expectedTodayLabel: String {
        "Expected today: \(joinedTimes(group.todaysRemainingTriggerDates))"
    }

    private var pendingLineLabel: String {
        if group.expectedPendingCount > 0 && !group.hasPendingMismatch {
            return "Pending in iOS: \(group.pendingCount) scheduled"
        }

        if !group.pendingTodayTriggerDates.isEmpty {
            return "Pending in iOS today: \(joinedTimes(group.pendingTodayTriggerDates))"
        }

        if let pendingNext = group.pendingNextTriggerDate {
            return "Pending in iOS next: \(timeLabel(pendingNext))"
        }

        return "Pending in iOS: none (\(group.pendingCount)/\(group.expectedPendingCount) scheduled)"
    }

    private func joinedTimes(_ dates: [Date]) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        return dates.map { formatter.string(from: $0) }.joined(separator: " · ")
    }
}
