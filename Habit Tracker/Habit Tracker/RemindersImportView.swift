import SwiftUI
import CoreData
import EventKit

private struct ReminderListSection: Identifiable {
    let id: String
    let title: String
    let reminders: [EKReminder]
}

struct RemindersImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var sections: [ReminderListSection] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = false
    @State private var authorizationDenied = false
    @State private var showResultAlert = false
    @State private var resultMessage = ""
    @State private var errorMessage: String?

    private let store = EKEventStore()

    var body: some View {
        NavigationStack {
            AppListContainer {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading reminders...")
                            Spacer()
                        }
                    }
                } else if authorizationDenied {
                    Section {
                        ContentUnavailableView {
                            Label("Reminders Access Needed", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("Enable Reminders access in iOS Settings to import reminder schedules as habits.")
                        }
                    }
                } else if sections.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Reminders Found", systemImage: "checklist")
                        } description: {
                            Text("No active reminders were found in your lists.")
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Text("Select reminders to import as habits. Their reminder time and weekly schedule will be carried over.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 12)

                            Button(allVisibleSelected ? "Clear All" : "Select All") {
                                toggleSelectAll()
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }

                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.reminders, id: \.calendarItemIdentifier) { reminder in
                                ReminderImportRow(
                                    reminder: reminder,
                                    isSelected: selectedIDs.contains(reminder.calendarItemIdentifier),
                                    toggleSelection: { toggle(reminderID: reminder.calendarItemIdentifier) }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import All") {
                        importAll()
                    }
                    .fontWeight(.semibold)
                    .disabled(allVisibleReminderIDs.isEmpty || isLoading || authorizationDenied)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        importSelected()
                    }
                    .disabled(selectedIDs.isEmpty || isLoading || authorizationDenied)
                }
            }
            .task {
                await loadReminders()
            }
            .refreshable {
                await loadReminders()
            }
        }
        .alert("Import Result", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
        .alert("Import Failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private var allVisibleReminderIDs: Set<String> {
        Set(sections.flatMap { $0.reminders.map(\.calendarItemIdentifier) })
    }

    private var allVisibleSelected: Bool {
        !allVisibleReminderIDs.isEmpty && selectedIDs.isSuperset(of: allVisibleReminderIDs)
    }

    private func loadReminders() async {
        isLoading = true
        defer { isLoading = false }

        let granted = await requestAccessIfNeeded()
        guard granted else {
            authorizationDenied = true
            sections = []
            selectedIDs = []
            return
        }
        authorizationDenied = false

        let calendars = store.calendars(for: .reminder).sorted { $0.title < $1.title }
        var loadedSections: [ReminderListSection] = []

        for calendar in calendars {
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
            let reminders = await fetchReminders(matching: predicate)
                .filter { hasRepeatRule($0) }
                .filter { !($0.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
                .sorted { ($0.title ?? "") < ($1.title ?? "") }

            if !reminders.isEmpty {
                loadedSections.append(
                    ReminderListSection(
                        id: calendar.calendarIdentifier,
                        title: calendar.title,
                        reminders: reminders
                    )
                )
            }
        }

        sections = loadedSections
        let validIDs = Set(loadedSections.flatMap { $0.reminders.map(\.calendarItemIdentifier) })
        selectedIDs = selectedIDs.intersection(validIDs)
    }

    private func requestAccessIfNeeded() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func toggle(reminderID: String) {
        if selectedIDs.contains(reminderID) {
            selectedIDs.remove(reminderID)
        } else {
            selectedIDs.insert(reminderID)
        }
    }

    private func toggleSelectAll() {
        if allVisibleSelected {
            selectedIDs.subtract(allVisibleReminderIDs)
        } else {
            selectedIDs.formUnion(allVisibleReminderIDs)
        }
    }

    private func importSelected() {
        let reminders = sections
            .flatMap(\.reminders)
            .filter { selectedIDs.contains($0.calendarItemIdentifier) }

        let candidates = reminders.map { ReminderImportService.candidate(from: $0) }

        do {
            let result = try ReminderImportService.importCandidates(candidates, into: viewContext)
            resultMessage = "Imported \(result.importedCount) reminder\(result.importedCount == 1 ? "" : "s")."
            if result.skippedDuplicates > 0 {
                resultMessage += " Skipped \(result.skippedDuplicates) duplicate name\(result.skippedDuplicates == 1 ? "" : "s")."
            }
            showResultAlert = true
            selectedIDs.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importAll() {
        selectedIDs = allVisibleReminderIDs
        importSelected()
    }

    private func hasRepeatRule(_ reminder: EKReminder) -> Bool {
        guard let rules = reminder.recurrenceRules else { return false }
        return !rules.isEmpty
    }
}

private struct ReminderImportRow: View {
    let reminder: EKReminder
    let isSelected: Bool
    let toggleSelection: () -> Void

    var body: some View {
        Button(action: toggleSelection) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(reminder.title ?? "Untitled Reminder")
                        .font(.headline)

                    Text("\(ReminderImportService.timeLabel(for: reminder)) · \(ReminderImportService.scheduleLabel(for: reminder))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
