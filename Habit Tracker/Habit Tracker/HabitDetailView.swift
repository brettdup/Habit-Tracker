// HabitDetailView.swift

import SwiftUI
import UserNotifications
import CoreData

struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var habitName: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var showAlert = false
    @State private var isReminderSet = false
    @State private var isTimePickerVisible = false
    @State private var selectedDate = Date()
    @State private var reminderTime: Date? = nil
    @State private var scheduledNotifications: [UNNotificationRequest] = []
    @State private var category: String = ""
    @State private var priority: Int16 = 0
    @State private var showCategoryPicker = false
    @State private var activeDaysMask: Int16 = HabitSchedule.allDaysMask
    @State private var iconName: String = HabitIcons.defaultIcon
    @State private var showIconPicker = false
    
    var viewContext: NSManagedObjectContext
    
    private var existingCategories: [String] { categoryStore.categories }

    init(habit: Habit, viewContext: NSManagedObjectContext) {
        self.habit = habit
        _habitName = State(initialValue: habit.name ?? "")
        _category = State(initialValue: habit.category ?? "")
        _priority = State(initialValue: habit.priority)
        _activeDaysMask = State(initialValue: habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask)
        _iconName = State(initialValue: habit.iconName ?? HabitIcons.defaultIcon)
        self.viewContext = viewContext
        if let notificationIdentifier = habit.notificationIdentifier, !notificationIdentifier.isEmpty {
            _isReminderSet = State(initialValue: true)
            if let reminderTime = habit.reminderTime {
                _selectedDate = State(initialValue: reminderTime)
                self.reminderTime = reminderTime
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
        NavigationView {
            ZStack {
                // Dynamic background based on color scheme
                Group {
                    if colorScheme == .dark {
                        Color.black.opacity(0.9)
                    } else {
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white.opacity(0.8)]),
                                     startPoint: .top,
                                     endPoint: .bottom)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Habit Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Habit Name", systemImage: "pencil")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            TextField("Enter habit name", text: $habitName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        
                        // Icon Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Icon", systemImage: "square.grid.2x2")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            Button(action: { showIconPicker = true }) {
                                HStack(spacing: 16) {
                                    Image(systemName: iconName)
                                        .font(.system(size: 28))
                                        .foregroundColor(.blue)
                                        .frame(width: 52, height: 52)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                    Text("Change Icon")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer(minLength: 12)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showIconPicker) {
                            IconPickerView(selectedIcon: $iconName)
                        }
                        
                        // Category Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Category", systemImage: "tag")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            Menu {
                                Button(action: { category = "" }) {
                                    HStack {
                                        Text("None")
                                        if category.isEmpty {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                ForEach(existingCategories, id: \.self) { cat in
                                    Button(action: { category = cat }) {
                                        HStack {
                                            Text(cat)
                                            if category == cat {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button(action: { showCategoryPicker = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("New Category")
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.blue)
                                    Text(category.isEmpty ? "Select Category" : category)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal)
                        .alert("New Category", isPresented: $showCategoryPicker) {
                            TextField("Category name", text: $category)
                            Button("Cancel", role: .cancel) {
                                // Keep current category
                            }
                            Button("Add") {
                                categoryStore.add(category)
                            }
                        } message: {
                            Text("Enter a name for the new category")
                        }
                        
                        // Priority Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Priority", systemImage: "star")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Priority Level")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text("\(priority)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                                
                                HStack(spacing: 12) {
                                    ForEach(1...5, id: \.self) { index in
                                        Button(action: { priority = Int16(index) }) {
                                            Image(systemName: index <= priority ? "star.fill" : "star")
                                                .foregroundColor(index <= priority ? .orange : .gray)
                                                .font(.system(size: 24))
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)

                        // Schedule Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Schedule", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Active on")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text(HabitSchedule.label(for: activeDaysMask))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }

                                HStack(spacing: 10) {
                                    SchedulePresetButton(title: "Every day", isSelected: activeDaysMask == HabitSchedule.allDaysMask) {
                                        activeDaysMask = HabitSchedule.allDaysMask
                                    }
                                    SchedulePresetButton(title: "Weekdays", isSelected: activeDaysMask == HabitSchedule.weekdaysMask) {
                                        activeDaysMask = HabitSchedule.weekdaysMask
                                    }
                                    SchedulePresetButton(title: "Weekends", isSelected: activeDaysMask == HabitSchedule.weekendsMask) {
                                        activeDaysMask = HabitSchedule.weekendsMask
                                    }
                                }

                                HStack(spacing: 8) {
                                    ForEach(HabitWeekday.allCases) { day in
                                        let isOn = HabitSchedule.isSelected(day, mask: activeDaysMask)
                                        Button {
                                            var mask = activeDaysMask
                                            HabitSchedule.setSelected(day, selected: !isOn, mask: &mask)
                                            activeDaysMask = mask
                                        } label: {
                                            Text(day.veryShortLabel)
                                                .font(.system(size: 14, weight: .semibold))
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    Circle()
                                                        .fill(isOn ? Color.blue : Color(.systemGray5))
                                                )
                                                .foregroundColor(isOn ? .white : .primary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        // Reminder Section
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Reminder", systemImage: "bell.fill")
                                .font(.headline)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            VStack(spacing: 16) {
                                Toggle(isOn: $isReminderSet) {
                                    Text("Daily Reminder")
                                        .fontWeight(.medium)
                                }
                                .tint(.blue)
                                
                                if isReminderSet {
                                    Divider()
                                    
                                    VStack(spacing: 12) {
                                        Button(action: { withAnimation { isTimePickerVisible.toggle() }}) {
                                            HStack {
                                                Image(systemName: "clock.fill")
                                                    .foregroundColor(.blue)
                                                Text(selectedTimeString)
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Image(systemName: isTimePickerVisible ? "chevron.up" : "chevron.down")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        if isTimePickerVisible {
                                            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(WheelDatePickerStyle())
                                                .labelsHidden()
                                                .onChange(of: selectedDate) { newValue in
                                                    habit.reminderTime = newValue
                                                }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        // Delete Button
                        VStack(spacing: 16) {
                            Button(action: { showAlert = true }) {
                                Text("Delete Habit")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 25)
                }
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
                }
            }
            .alert(isPresented: $showAlert, content: deleteAlert)
            .onAppear {
                fetchScheduledNotifications()
            }
        }
    }
    
    private var selectedTimeString: String {
        guard let reminderTime = habit.reminderTime else {
            return "Select Time"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: reminderTime)
    }
    
    private func deleteAlert() -> Alert {
        Alert(
            title: Text("Delete Habit"),
            message: Text("Are you sure you want to delete this habit?"),
            primaryButton: .destructive(Text("Delete")) {
                deleteHabit()
            },
            secondaryButton: .cancel()
        )
    }

    func deleteHabit() {
        // Delete any existing notifications first
        if let notificationIdentifier = habit.notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        }
        
        // Also delete using the habit's object ID as identifier since that's how we create them
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Delete the habit from Core Data
        viewContext.delete(habit)

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func fetchScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.scheduledNotifications = requests.sorted(by: { (request1, request2) -> Bool in
                    guard let trigger1 = request1.trigger as? UNCalendarNotificationTrigger,
                          let trigger2 = request2.trigger as? UNCalendarNotificationTrigger else {
                        return false
                    }
                    let date1 = trigger1.nextTriggerDate() ?? Date.distantFuture
                    let date2 = trigger2.nextTriggerDate() ?? Date.distantFuture
                    return date1 < date2
                })
            }
        }
    }

    func deleteReminders(for habit: Habit) {
        let base = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        deleteNotifications(forBaseIdentifier: base)
        fetchScheduledNotifications()
    }
    
    private func saveChanges() {
        habit.name = habitName
        habit.category = category.isEmpty ? nil : category
        habit.priority = priority
        habit.activeDaysMask = activeDaysMask
        habit.iconName = iconName
        
        // Update reminder time based on toggle state
        if !isReminderSet {
            habit.reminderTime = nil
            deleteReminders(for: habit)
        } else {
            habit.reminderTime = selectedDate
        }
    
        do {
            if !category.isEmpty {
                categoryStore.add(category)
            }
            try viewContext.save()
            rescheduleNotifications(for: habit)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving habit changes: \(error)")
        }
    }

    private func rescheduleNotifications(for habit: Habit) {
        guard isReminderSet, let reminderTime = habit.reminderTime else {
            deleteReminders(for: habit)
            habit.notificationIdentifier = nil
            try? viewContext.save()
            return
        }

        let base = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        deleteNotifications(forBaseIdentifier: base)

        let content = UNMutableNotificationContent()
        content.title = "Reminder - \(habit.name ?? "")"
        content.body = "Don't forget to complete your habit: \(habit.name ?? "")"
        content.sound = UNNotificationSound.default

        let hour = Calendar.current.component(.hour, from: reminderTime)
        let minute = Calendar.current.component(.minute, from: reminderTime)

        let selectedDays = HabitWeekday.allCases.filter { HabitSchedule.isSelected($0, mask: activeDaysMask) }
        for day in selectedDays {
            var comps = DateComponents()
            comps.weekday = day.calendarWeekday
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let identifier = "\(base)-\(day.calendarWeekday)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("Error scheduling notification: \(error.localizedDescription)") }
            }
        }

        habit.notificationIdentifier = "\(base)-multi"
        try? viewContext.save()
        fetchScheduledNotifications()
    }

    private func deleteNotifications(forBaseIdentifier base: String) {
        // Remove deterministically to avoid races with async fetch/remove.
        let identifiers = [base, "\(base)-multi"] + (1...7).map { "\(base)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // (legacy single-notification scheduling removed; reminders are now scheduled per selected weekday)
}

private struct SchedulePresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                )
                .foregroundColor(isSelected ? .blue : .primary)
        }
    }
}

struct HabitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        clearSampleData(in: context)
        let habit = createSampleHabit(in: context)
        return NavigationView {
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
