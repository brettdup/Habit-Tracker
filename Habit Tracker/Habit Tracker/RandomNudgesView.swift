import SwiftUI
import UserNotifications

private struct RandomNudgeNotificationGroup: Identifiable {
    let id: UUID
    let nudge: RandomNudge
    let requests: [UNNotificationRequest]
    let nextTriggerDate: Date?
    let todaysTriggerDates: [Date]
}

struct RandomNudgesView: View {
    @State private var randomNudgeGroups: [RandomNudgeNotificationGroup] = []
    @State private var pendingDeleteNudgeGroup: RandomNudgeNotificationGroup?
    @State private var editingNudge: RandomNudge?
    @State private var showAddRandomNudge = false

    var body: some View {
        AppListContainer {
            if randomNudgeGroups.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Random Nudges", systemImage: "sparkles")
                    } description: {
                        Text("Create nudges for things like posture, stretching, or hydration.")
                    }
                }
            } else {
                Section {
                    Text("Random nudges are separate from habits and do not track completions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Random Nudges")
                }

                Section {
                    ForEach(randomNudgeGroups) { group in
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
                    }
                }
            }
        }
        .navigationTitle("Random Nudges")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddRandomNudge = true
                } label: {
                    Label("Add Random Nudge", systemImage: "plus")
                }
            }
        }
        .onAppear {
            refreshScheduledNotificationsAfterQueueSettles()
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
                let nudgeRequests = requests.filter { $0.identifier.hasPrefix("randomNudge-") }
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

    private func removeRandomNudgeGroup(_ group: RandomNudgeNotificationGroup) {
        RandomNudgeStore.remove(id: group.id)
        RandomNudgeGeneratedScheduleStore.clear(nudgeID: group.id)
        RandomNudgeScheduler.removePending(for: group.id)
        refreshScheduledNotificationsAfterQueueSettles()
    }

    private func groupRandomNudgeRequests(_ requests: [UNNotificationRequest]) -> [RandomNudgeNotificationGroup] {
        let nudgesByID = Dictionary(uniqueKeysWithValues: RandomNudgeStore.fetchAll().map { ($0.id, $0) })
        let grouped = Dictionary(grouping: requests, by: { randomNudgeID(from: $0.identifier) })

        return grouped.compactMap { id, reqs in
            guard let id, let nudge = nudgesByID[id] else { return nil }
            let sortedReqs = reqs.sorted { $0.identifier < $1.identifier }
            let upcomingDates = sortedReqs
                .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
                .sorted()
            let todaysDates = upcomingDates.filter { Calendar.current.isDateInToday($0) }
            return RandomNudgeNotificationGroup(
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
}

private struct RandomNudgeRow: View {
    let group: RandomNudgeNotificationGroup

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

struct AddRandomNudgeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var wakeStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeEnd = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var nudgesPerDay = 4
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    let existingNudge: RandomNudge?
    let onCreated: () -> Void

    init(existingNudge: RandomNudge? = nil, onCreated: @escaping () -> Void) {
        self.existingNudge = existingNudge
        self.onCreated = onCreated
        _title = State(initialValue: existingNudge?.title ?? "")
        let initialMessage: String
        if let existingNudge, !existingNudge.message.isEmpty {
            initialMessage = existingNudge.message
        } else {
            initialMessage = RandomNudgeDefaults.defaultMessage
        }
        _message = State(initialValue: initialMessage)
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: existingNudge?.wakeStartHour ?? 8, minute: existingNudge?.wakeStartMinute ?? 0, second: 0, of: Date()) ?? Date()
        let end = calendar.date(bySettingHour: existingNudge?.wakeEndHour ?? 21, minute: existingNudge?.wakeEndMinute ?? 0, second: 0, of: Date()) ?? Date()
        _wakeStart = State(initialValue: start)
        _wakeEnd = State(initialValue: end)
        _nudgesPerDay = State(initialValue: existingNudge?.nudgesPerDay ?? 4)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What To Nudge") {
                    TextField("Title (e.g. Drink Water)", text: $title)
                    TextField("Notification message", text: $message)
                }

                Section("Random Timing") {
                    DatePicker("Wake Start", selection: $wakeStart, displayedComponents: .hourAndMinute)
                    DatePicker("Wake End", selection: $wakeEnd, displayedComponents: .hourAndMinute)
                    Stepper(value: $nudgesPerDay, in: 1...12) {
                        Text("Nudges per day: \(nudgesPerDay)")
                    }
                }

                Section {
                    Text("These are random nudges, not habits. They do not have completions or streaks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existingNudge == nil ? "New Random Nudge" : "Edit Random Nudge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .alert("Cannot Save Nudge", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter a nudge title."
            showValidationAlert = true
            return
        }

        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: wakeStart)
        let startMinute = calendar.component(.minute, from: wakeStart)
        let endHour = calendar.component(.hour, from: wakeEnd)
        let endMinute = calendar.component(.minute, from: wakeEnd)

        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute
        guard endTotal > startTotal else {
            validationMessage = "Wake end must be later than wake start."
            showValidationAlert = true
            return
        }

        let nudge = RandomNudge(
            id: existingNudge?.id ?? UUID(),
            title: trimmedTitle,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            wakeStartHour: startHour,
            wakeStartMinute: startMinute,
            wakeEndHour: endHour,
            wakeEndMinute: endMinute,
            nudgesPerDay: nudgesPerDay,
            createdAt: existingNudge?.createdAt ?? Date()
        )
        if existingNudge == nil {
            RandomNudgeStore.add(nudge)
        } else {
            RandomNudgeGeneratedScheduleStore.clear(nudgeID: nudge.id)
            RandomNudgeStore.update(nudge)
        }
        RandomNudgeScheduler.scheduleNudge(nudge)
        onCreated()
        dismiss()
    }
}
