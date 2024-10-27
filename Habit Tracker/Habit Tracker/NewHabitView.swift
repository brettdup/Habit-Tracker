import UserNotifications
import SwiftUI
import CoreData

struct NewHabitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var habitName: String = ""
    @State private var reminderTime: Date? = nil
    @State private var showingToast = false
    @State private var isTimePickerVisible = false
    @State private var isReminderSet = true
    @State private var selectedDate = Date()
    @State private var isKeyboardHidden = true
    
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

        do {
            try viewContext.save()
            withAnimation {
                showingToast = true
            }
            if let notificationIdentifier = scheduleNotification(for: newHabit) {
                newHabit.notificationIdentifier = notificationIdentifier
                try viewContext.save()
            }
            // Reset form
            habitName = ""
            reminderTime = nil
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
    
    func scheduleNotification(for habit: Habit) -> String? {
        guard let reminderTime = reminderTime, !habit.isCompleted else {
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

        return identifier
    }
}

struct NewHabitView_Previews: PreviewProvider {
    static var previews: some View {
        NewHabitView()
    }
}
