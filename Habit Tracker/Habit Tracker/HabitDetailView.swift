// HabitDetailView.swift

import SwiftUI
import UserNotifications
import CoreData

struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @State private var habitName: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var showAlert = false
    @State private var isReminderSet = false
    @State private var isTimePickerVisible = false
    @State private var selectedDate = Date()
    @State private var reminderTime: Date? = nil
    @State private var scheduledNotifications: [UNNotificationRequest] = []
    
    var viewContext: NSManagedObjectContext

    init(habit: Habit, viewContext: NSManagedObjectContext) {
        self.habit = habit
        _habitName = State(initialValue: habit.name ?? "")
        self.viewContext = viewContext
        if let notificationIdentifier = habit.notificationIdentifier, !notificationIdentifier.isEmpty {
            _isReminderSet = State(initialValue: true)
            reminderTime = habit.reminderTime
        } else {
            _isReminderSet = State(initialValue: false)
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
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            Button(action: saveChanges) {
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
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
        // Delete using both the notification identifier and the object ID based identifier
        if let notificationIdentifier = habit.notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        }
        
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        fetchScheduledNotifications()
    }
    
    private func saveChanges() {
        habit.name = habitName
        
        // Update reminder time based on toggle state
        if !isReminderSet {
            habit.reminderTime = nil
            deleteReminders(for: habit)
        } else {
            habit.reminderTime = selectedDate
        }
    
        do {
            try viewContext.save()
            if isReminderSet {
                if let notificationIdentifier = habit.notificationIdentifier {
                    scheduleNotification(withIdentifier: notificationIdentifier, for: habit)
                } else {
                    let newIdentifier = scheduleNotification(for: habit)
                    habit.notificationIdentifier = newIdentifier
                    try viewContext.save()
                }
            }
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving habit changes: \(error)")
        }
    }
    
    func scheduleNotification(for habit: Habit) -> String? {
        guard let reminderTime = habit.reminderTime, !habit.isCompleted else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = "Reminder - \(habit.name ?? "")"
        content.body = "Don't forget to complete your habit: \(habit.name ?? "")"
        content.sound = UNNotificationSound.default

        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully")
                fetchScheduledNotifications()
            }
        }

        return identifier
    }
    
    func scheduleNotification(withIdentifier identifier: String, for habit: Habit) {
        guard let reminderTime = habit.reminderTime, !habit.isCompleted else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Reminder - \(habit.name ?? "")"
        content.body = "Don't forget to complete your habit: \(habit.name ?? "")"
        content.sound = UNNotificationSound.default

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification rescheduled successfully")
                fetchScheduledNotifications()
            }
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
