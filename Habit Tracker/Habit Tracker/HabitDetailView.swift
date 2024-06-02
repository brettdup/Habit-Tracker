// HabitDetailView.swift

import SwiftUI
import UserNotifications

import CoreData


struct HabitDetailView: View {
    @ObservedObject var habit: Habit
    @State private var habitName: String // Non-optional habit name
    @Environment(\.presentationMode) var presentationMode // Presentation mode environment variable
    @State private var showAlert = false
    @State private var isReminderSet = false
    @State private var isTimePickerVisible = false
    @State private var selectedDate = Date() // New variable to bind to the Date state
    @State private var reminderTime: Date? = nil
    
    


    
    var viewContext: NSManagedObjectContext // Managed object context


    init(habit: Habit, viewContext: NSManagedObjectContext) {
        self.habit = habit
        _habitName = State(initialValue: habit.name ?? "") // Provide default value for habit name
        self.viewContext = viewContext
        if let notificationIdentifier = habit.notificationIdentifier, !notificationIdentifier.isEmpty {
                _isReminderSet = State(initialValue: true) // Initialize to true if notificationIdentifier exists
                reminderTime = habit.reminderTime
            } else {
                _isReminderSet = State(initialValue: false) // Initialize to false if notificationIdentifier does not exist
            }
        
//        print(habit)
//        print(habit.reminderTime)


    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit")) {
                    HStack {
                        Text("Habit name: ")
                        TextField("Enter habit name", text: $habitName)
                    }
                    HStack{
                        Text("Reminder Time:")
                        if isReminderSet {
                            if (habit.reminderTime != nil) {
                                Text(selectedTimeString)
                                    .foregroundColor(.blue)
                                    .onTapGesture {
                                        isTimePickerVisible.toggle()
                                    }
                            } else {
                                Text("Select time")
                                    .foregroundColor(.blue)
                                    .underline()
                                    .onTapGesture {
                                        isTimePickerVisible.toggle()
                                    }
                            }
                        } else {
                            Text("N/A")
                                .foregroundColor(.gray)
                        }
                        Toggle(isOn: $isReminderSet) {
                        }
                    }
                       
                    


                    if isTimePickerVisible && isReminderSet {
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .padding(.vertical, 5) // Adjust vertical padding
                            .padding(.horizontal) // Keep horizontal padding
                            .onChange(of:selectedDate) { newValue in
                                habit.reminderTime = newValue // Update reminderTime when selectedDate changes
                            }

                    }
                    // Add controls for editing reminder time
                    
                    Button(action: {
                            saveChanges()
                        }) {
                            Text("Save Changes")
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                }
                
            }
//            .gesture(
//                           TapGesture()
//                               .onEnded { _ in
//                                   UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                               }
//            )
            .navigationTitle("Edit Habit")
            .navigationBarItems(leading: Button("Close") {
                saveChanges()
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button(action: {
                (showAlert = true)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            })
            .alert(isPresented: $showAlert, content: deleteAlert)

        }
        
        
    
    }
    
    
    private var selectedTimeString: String {
        guard let reminderTime = habit.reminderTime else {
            return "Now"
        }
        // Format the selected reminder time as a string
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Display time in short format
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
        
        // Delete associated reminders (notifications)
        deleteReminders(for: habit)
        viewContext.delete(habit)

        do {
            try viewContext.save()
            // Navigate back after deletion
            presentationMode.wrappedValue.dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func deleteReminders(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }

        // Construct the identifier for the habit's reminder
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"

        // Remove the pending notification request with the constructed identifier
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    
    
    private func saveChanges() {
        habit.name = habitName // Update habit name in the Habit object
        habit.reminderTime = habit.reminderTime

    
            do {
                try viewContext.save()
                if let notificationIdentifier = habit.notificationIdentifier {
                           scheduleNotification(withIdentifier: notificationIdentifier, for: habit)
                       }
                else{
                    scheduleNotification(for: habit)
                }
                presentationMode.wrappedValue.dismiss() // Dismiss the view
                
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
            }
        }

        return identifier // Return the notification identifier
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

      
        do {
            try UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        } catch {
            print("Error removing pending notification request: \(error.localizedDescription)")
        }
        
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification rescheduled successfully")
            }
        }

    }

    

    
}

struct HabitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Clear existing sample data
        clearSampleData(in: context)
        // Create sample habit
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
