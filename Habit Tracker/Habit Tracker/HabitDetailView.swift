// HabitDetailView.swift

import SwiftUI
import CoreData

struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var habitName: String
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var isReminderSet = false
    @State private var selectedDate = Date()
    @State private var notificationTitle: String = ""
    @State private var notificationBody: String = ""
    @State private var category: String = ""
    @State private var priority: Int16 = 0
    @State private var showCategoryPicker = false
    @State private var activeDaysMask: Int16 = HabitSchedule.allDaysMask
    @State private var iconName: String = HabitIcons.defaultIcon
    @State private var showIconPicker = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @FocusState private var focusedNotificationField: NotificationTextField?
    
    var viewContext: NSManagedObjectContext
    
    private var existingCategories: [String] { categoryStore.categories }
    private let priorityValues: [Int16] = [0, 1, 2, 3, 4, 5]

    init(habit: Habit, viewContext: NSManagedObjectContext) {
        self.habit = habit
        _habitName = State(initialValue: habit.name ?? "")
        _category = State(initialValue: habit.category ?? "")
        _priority = State(initialValue: habit.priority)
        _activeDaysMask = State(initialValue: habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask)
        _iconName = State(initialValue: habit.iconName ?? HabitIcons.defaultIcon)
        _notificationTitle = State(initialValue: habit.notificationTitle ?? "")
        _notificationBody = State(initialValue: habit.notificationBody ?? "")
        self.viewContext = viewContext
        if let notificationIdentifier = habit.notificationIdentifier, !notificationIdentifier.isEmpty {
            _isReminderSet = State(initialValue: true)
            if let reminderTime = habit.reminderTime {
                _selectedDate = State(initialValue: reminderTime)
            } else {
                _selectedDate = State(initialValue: Date())
            }
        } else {
            _isReminderSet = State(initialValue: false)
            if let reminderTime = habit.reminderTime {
                _selectedDate = State(initialValue: reminderTime)
            } else {
                _selectedDate = State(initialValue: Date())
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                prioritySection
                scheduleSection
                reminderSection

                Section("Insights") {
                    NavigationLink("View Habit History") {
                        HabitHistoryView(habit: habit)
                    }
                }

                Section {
                    Button("Delete Habit", role: .destructive) {
                        showAlert = true
                    }
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $iconName)
            }
            .alert("New Category", isPresented: $showCategoryPicker) {
                TextField("Category name", text: $category)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    categoryStore.add(category)
                }
            } message: {
                Text("Enter a name for the new category")
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(HabitFormValidation.normalizedName(habitName).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedNotificationField = nil
                    }
                }
            }
            .alert("Delete Habit", isPresented: $showAlert) {
                Button("Delete", role: .destructive) {
                    deleteHabit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this habit?")
            }
            .alert("Cannot Save Habit", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    private var readableIconName: String {
        iconName
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Habit Name", text: $habitName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .appTextInputStyle()

            Button {
                showIconPicker = true
            } label: {
                HStack {
                    Label("Icon", systemImage: iconName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(readableIconName)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Category", selection: $category) {
                Text("None").tag("")
                ForEach(existingCategories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }

            Button("Add New Category") {
                showCategoryPicker = true
            }
        }
    }

    private var prioritySection: some View {
        Section("Priority") {
            Picker("Priority", selection: $priority) {
                ForEach(priorityValues, id: \.self) { value in
                    Text(priorityLabel(for: value)).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Preset", selection: schedulePresetBinding) {
                Text("Custom").tag("custom")
                Text("Every day").tag("everyday")
                Text("Weekdays").tag("weekdays")
                Text("Weekends").tag("weekends")
            }
            .pickerStyle(.menu)

            ForEach(HabitWeekday.allCases) { day in
                Toggle(day.shortLabel, isOn: binding(for: day))
            }

            LabeledContent("Summary", value: HabitSchedule.label(for: activeDaysMask))
                .foregroundStyle(.secondary)
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: $isReminderSet.animation())

            if isReminderSet {
                DatePicker(
                    "Time",
                    selection: $selectedDate,
                    displayedComponents: .hourAndMinute
                )

                TextField(defaultNotificationTitle, text: $notificationTitle)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused($focusedNotificationField, equals: .title)

                TextField(defaultNotificationBody, text: $notificationBody, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(2...4)
                    .focused($focusedNotificationField, equals: .body)
            }
        } header: {
            Text("Reminder")
        } footer: {
            Text("Use {habit} where the habit name should appear. Leave text fields blank to use the built-in message.")
        }
    }

    private func priorityLabel(for value: Int16) -> String {
        value == 0 ? "None" : "\(value)"
    }

    private enum NotificationTextField {
        case title
        case body
    }

    private var defaultNotificationTitle: String {
        HabitReminderScheduler.defaultNotificationTitle(for: HabitFormValidation.normalizedName(habitName))
    }

    private var defaultNotificationBody: String {
        HabitReminderScheduler.defaultNotificationBody(for: HabitFormValidation.normalizedName(habitName))
    }

    private func normalizedOptionalText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var schedulePresetSelection: String {
        get {
            switch activeDaysMask {
            case HabitSchedule.allDaysMask:
                return "everyday"
            case HabitSchedule.weekdaysMask:
                return "weekdays"
            case HabitSchedule.weekendsMask:
                return "weekends"
            default:
                return "custom"
            }
        }
        set {
            applySchedulePreset(newValue)
        }
    }

    private var schedulePresetBinding: Binding<String> {
        Binding(
            get: { schedulePresetSelection },
            set: { newValue in
                applySchedulePreset(newValue)
            }
        )
    }
    
    private func applySchedulePreset(_ preset: String) {
        switch preset {
        case "everyday":
            activeDaysMask = HabitSchedule.allDaysMask
        case "weekdays":
            activeDaysMask = HabitSchedule.weekdaysMask
        case "weekends":
            activeDaysMask = HabitSchedule.weekendsMask
        default:
            break
        }
    }

    private func binding(for day: HabitWeekday) -> Binding<Bool> {
        Binding(
            get: { HabitSchedule.isSelected(day, mask: activeDaysMask) },
            set: { isSelected in
                var mask = activeDaysMask
                HabitSchedule.setSelected(day, selected: isSelected, mask: &mask)
                activeDaysMask = mask
            }
        )
    }

    func deleteHabit() {
        do {
            HabitReminderScheduler.removeReminders(for: habit)
            HabitIntervalScheduleStore.clearInterval(for: habit)
            try HabitCompletionStore.deleteAllRecords(for: habit, in: viewContext)
            viewContext.delete(habit)
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error deleting habit: \(error.localizedDescription)")
        }
    }

    func deleteReminders(for habit: Habit) {
        HabitReminderScheduler.removeReminders(for: habit)
        HabitIntervalScheduleStore.clearInterval(for: habit)
    }
    
    private func saveChanges() {
        let normalizedName = HabitFormValidation.normalizedName(habitName)
        guard !normalizedName.isEmpty else {
            validationMessage = "Habit name can't be empty."
            showValidationAlert = true
            return
        }
        guard !HabitFormValidation.duplicateNameExists(normalizedName, excluding: habit, in: viewContext) else {
            validationMessage = "A habit with this name already exists."
            showValidationAlert = true
            return
        }

        habit.name = normalizedName
        habit.category = category.isEmpty ? nil : category
        habit.priority = priority
        habit.activeDaysMask = activeDaysMask
        habit.iconName = iconName
        habit.notificationTitle = normalizedOptionalText(notificationTitle)
        habit.notificationBody = normalizedOptionalText(notificationBody)
        
        // Update reminder time based on toggle state
        if !isReminderSet {
            habit.reminderTime = nil
            habit.notificationIdentifier = nil
            deleteReminders(for: habit)
        } else {
            habit.reminderTime = selectedDate
            habit.notificationIdentifier = "\(HabitReminderScheduler.baseIdentifier(for: habit))-multi"
        }
    
        do {
            if !category.isEmpty {
                categoryStore.add(category)
            }
            try viewContext.save()
            HabitReminderScheduler.scheduleReminders(for: habit)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving habit changes: \(error)")
        }
    }
    
    // (legacy single-notification scheduling removed; reminders are now scheduled per selected weekday)
}

struct HabitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        clearSampleData(in: context)
        let habit = createSampleHabit(in: context)
        return NavigationStack {
            HabitDetailView(habit: habit, viewContext: context)
        }
    }
    
    private static func clearSampleData(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Habit.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            print("Failed to clear sample data: \(error)")
        }
    }
    
    private static func createSampleHabit(in context: NSManagedObjectContext) -> Habit {
        let habit = Habit(context: context)
        habit.name = "Sample Habit"
        habit.isCompleted = false
        habit.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
        do {
            try context.save()
        } catch {
            print("Failed to create sample habit: \(error)")
        }
        return habit
    }
}

struct HabitHistoryView: View {
    @ObservedObject var habit: Habit
    @FetchRequest private var completions: FetchedResults<HabitCompletionRecord>

    private struct CompletionRow: Identifiable {
        let id: NSManagedObjectID
        let completion: HabitCompletionRecord
    }

    init(habit: Habit) {
        self.habit = habit
        _completions = FetchRequest<HabitCompletionRecord>(
            entity: HabitCompletionRecord.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)],
            predicate: NSPredicate(format: "habit == %@", habit)
        )
    }

    var body: some View {
        List {
            Section {
                HistoryDotsSection(
                    days: daySummaries,
                    title: "Habit History",
                    subtitle: "Last 35 tracked days"
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section("Completions") {
                if completionItems.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Complete this habit a few times to see its history.")
                    )
                } else {
                    ForEach(completionRows) { row in
                        completionRow(for: row.completion)
                    }
                }
            }
        }
        .navigationTitle(habit.name ?? "Habit History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completionItems: [HabitCompletionRecord] {
        Array(completions)
    }

    private var completionRows: [CompletionRow] {
        completionItems.map { completion in
            CompletionRow(id: completion.objectID, completion: completion)
        }
    }

    private var daySummaries: [HistoryDaySummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: completions, by: { calendar.startOfDay(for: $0.date ?? Date()) })
        let today = calendar.startOfDay(for: Date())

        return Array((0..<35).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let records = grouped[date] ?? []
            return HistoryDaySummary(date: date, completedCount: records.count, totalCount: records.isEmpty ? 0 : 1)
        }
        .reversed())
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func statusText(for completion: HabitCompletionRecord) -> String {
        "Completed \(completion.isCompleted ? "successfully" : "partially")"
    }

    @ViewBuilder
    private func completionRow(for completion: HabitCompletionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(completion.date))
                    .font(.body.weight(.medium))
                Text(statusText(for: completion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}
