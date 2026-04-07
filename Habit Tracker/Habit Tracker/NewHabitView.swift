import SwiftUI
import CoreData

struct NewHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var habitName: String = ""
    @State private var showingToast = false
    @State private var isReminderSet = true
    @State private var selectedDate = Date()
    @State private var category: String = ""
    @State private var priority: Int16 = 0
    @State private var showCategoryPicker = false
    @State private var activeDaysMask: Int16 = HabitSchedule.allDaysMask
    @State private var iconName: String = HabitIcons.defaultIcon
    @State private var showIconPicker = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    
    private var existingCategories: [String] { categoryStore.categories }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit Name", text: $habitName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } header: {
                    Label("Details", systemImage: "square.and.pencil")
                } footer: {
                    Text("Choose a short, specific habit name.")
                }

                Section {
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
                    .buttonStyle(.plain)

                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(existingCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    Button("Add New Category") {
                        showCategoryPicker = true
                    }
                } header: {
                    Label("Organization", systemImage: "tray.full")
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(0...5, id: \.self) { value in
                            Text(value == 0 ? "None" : "\(value)").tag(Int16(value))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Priority", systemImage: "star")
                }

                Section {
                    Picker("Preset", selection: schedulePresetBinding) {
                        Text("Custom").tag("custom")
                        Text("Every day").tag("everyday")
                        Text("Weekdays").tag("weekdays")
                        Text("Weekends").tag("weekends")
                    }
                    .pickerStyle(.segmented)

                    ForEach(HabitWeekday.allCases) { day in
                        Toggle(day.shortLabel, isOn: binding(for: day))
                    }

                    LabeledContent("Summary", value: HabitSchedule.label(for: activeDaysMask))
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Schedule", systemImage: "calendar")
                }

                Section {
                    Toggle("Enable Reminder", isOn: $isReminderSet.animation())

                    if isReminderSet {
                        DatePicker(
                            "Time",
                            selection: $selectedDate,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                    }
                } header: {
                    Label("Reminder", systemImage: "bell")
                } footer: {
                    Text("Optional. If enabled, notifications are scheduled on selected days.")
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
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        addHabit()
                    }
                    .fontWeight(.semibold)
                    .disabled(HabitFormValidation.normalizedName(habitName).isEmpty)
                }
            }
        }
        .alert("Cannot Create Habit", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private func addHabit() {
        let normalizedName = HabitFormValidation.normalizedName(habitName)
        guard !normalizedName.isEmpty else {
            validationMessage = "Habit name can't be empty."
            showValidationAlert = true
            return
        }
        guard !HabitFormValidation.duplicateNameExists(normalizedName, in: viewContext) else {
            validationMessage = "A habit with this name already exists."
            showValidationAlert = true
            return
        }

        let newHabit = Habit(context: viewContext)
        newHabit.name = normalizedName
        newHabit.isCompleted = false
        newHabit.timestamp = Date()
        newHabit.reminderTime = isReminderSet ? selectedDate : nil
        newHabit.category = category.isEmpty ? nil : category
        newHabit.priority = priority
        newHabit.activeDaysMask = activeDaysMask
        newHabit.iconName = iconName
        newHabit.notificationIdentifier = isReminderSet ? "\(HabitReminderScheduler.baseIdentifier(for: newHabit))-multi" : nil

        do {
            if !category.isEmpty {
                categoryStore.add(category)
            }
            try viewContext.save()
            withAnimation {
                showingToast = true
            }
            HabitReminderScheduler.scheduleReminders(for: newHabit)
            habitName = ""
            selectedDate = Date()
            category = ""
            priority = 0
            activeDaysMask = HabitSchedule.allDaysMask
            iconName = HabitIcons.defaultIcon
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error saving habit: \(nsError), \(nsError.userInfo)")
        }
    }

    private var readableIconName: String {
        iconName
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
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
}

struct NewHabitView_Previews: PreviewProvider {
    static var previews: some View {
        NewHabitView()
    }
}
