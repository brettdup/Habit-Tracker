import UserNotifications
import SwiftUI
import CoreData

struct NewHabitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var habitName: String = ""
    @State private var reminderTime: Date? = nil
    @State private var showingToast = false
    @State private var isTimePickerVisible = false
    @State private var isReminderSet = true
    @State private var selectedDate = Date()
    @State private var isKeyboardHidden = true
    @State private var category: String = ""
    @State private var priority: Int16 = 0
    @State private var showCategoryPicker = false
    @State private var activeDaysMask: Int16 = HabitSchedule.allDaysMask
    @State private var iconName: String = HabitIcons.defaultIcon
    @State private var showIconPicker = false
    
    private var existingCategories: [String] { categoryStore.categories }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)]),
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 30) {
                    // Modern header with icon
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top, 20)
                        
                        Text("Create New Habit")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Habit Name Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Habit Name", systemImage: "pencil")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        TextField("What habit would you like to build?", text: $habitName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    
                    // Icon Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Icon", systemImage: "square.grid.2x2")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: { showIconPicker = true }) {
                            HStack(spacing: 16) {
                                Image(systemName: iconName)
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                                    .frame(width: 52, height: 52)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                Text("Choose Icon")
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
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .sheet(isPresented: $showIconPicker) {
                        IconPickerView(selectedIcon: $iconName)
                    }
                    
                    // Category Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Category", systemImage: "tag")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
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
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .alert("New Category", isPresented: $showCategoryPicker) {
                        TextField("Category name", text: $category)
                        Button("Cancel", role: .cancel) {
                            category = ""
                        }
                        Button("Add") {
                            categoryStore.add(category)
                        }
                    } message: {
                        Text("Enter a name for the new category")
                    }
                    
                    // Priority Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Priority", systemImage: "star")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
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
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)

                    // Schedule Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Schedule", systemImage: "calendar")
                            .font(.headline)
                            .foregroundColor(.gray)

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
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    
                    // Reminder Card
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Reminder", systemImage: "bell.fill")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 15) {
                            Toggle(isOn: $isReminderSet) {
                                Text("Daily Reminder")
                                    .font(.system(size: 16))
                            }
                            .tint(.blue)
                            
                            if isReminderSet {
                                Divider()
                                
                                Button(action: { isTimePickerVisible.toggle() }) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.blue)
                                        Text(reminderTime != nil ? selectedTimeString : "Choose time")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    }
                                }
                                
                                if isTimePickerVisible {
                                    DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(GraphicalDatePickerStyle())
                                        .labelsHidden()
                                        .onChange(of: selectedDate) { newValue in
                                            reminderTime = newValue
                                        }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Modern floating action button
                    Button(action: addHabit) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Create Habit")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            
            // Modern toast notification
            if showingToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        Text("Habit Created Successfully")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring())
                .zIndex(1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingToast = false
                        }
                    }
                }
            }
        }
    }

    private func addHabit() {
        let newHabit = Habit(context: viewContext)
        newHabit.name = habitName
        newHabit.isCompleted = false
        newHabit.reminderTime = reminderTime
        newHabit.category = category.isEmpty ? nil : category
        newHabit.priority = priority
        newHabit.activeDaysMask = activeDaysMask
        newHabit.iconName = iconName

        do {
            if !category.isEmpty {
                categoryStore.add(category)
            }
            try viewContext.save()
            withAnimation {
                showingToast = true
            }
            scheduleNotifications(for: newHabit)
            // Reset form
            habitName = ""
            reminderTime = nil
            category = ""
            priority = 0
            activeDaysMask = HabitSchedule.allDaysMask
            iconName = HabitIcons.defaultIcon
            isTimePickerVisible = false
        } catch {
            let nsError = error as NSError
            print("Error saving habit: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private var selectedTimeString: String {
        guard let reminderTime = reminderTime else { return "Now" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: reminderTime)
    }
    
    private func scheduleNotifications(for habit: Habit) {
        guard isReminderSet, let reminderTime else { return }

        let base = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        removeNotifications(forBaseIdentifier: base)

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

        // Keep legacy field non-empty so existing UI logic treats reminders as enabled.
        habit.notificationIdentifier = "\(base)-multi"
    }

    private func removeNotifications(forBaseIdentifier base: String) {
        // Remove deterministically to avoid races with async fetch/remove.
        let identifiers = [base, "\(base)-multi"] + (1...7).map { "\(base)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
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

struct NewHabitView_Previews: PreviewProvider {
    static var previews: some View {
        NewHabitView()
    }
}
