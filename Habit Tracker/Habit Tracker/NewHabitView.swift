import UserNotifications
import SwiftUI
import CoreData

struct NewHabitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var habitName: String = ""
    @State private var reminderTime: Date? = nil
    @State private var showingToast = false
    @State private var isTimePickerVisible = false // Track the visibility of the time picker
    @State private var isReminderSet = true // Track if the reminder time is set
    @State private var selectedDate = Date() // New variable to bind to the Date state
    @State private var isKeyboardHidden = true // Track if keyboard should be hidden

    
    var body: some View {
        VStack {
            Spacer() // Add spacer to push form to the top
            Form {
                Section(header: Text("New Habit Form")) {
                    VStack {
                        TextField("Enter habit name", text: $habitName)
                            .font(.system(size: 16, weight: .bold))
                            .padding()
                            .frame(width: 325)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 1))
                            .padding()
                            .onTapGesture {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        

                        HStack {
                            Text("Reminder Time:")
                            Spacer()
                            if isReminderSet {
                                if reminderTime != nil {
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
                                Text("None")
                                    .foregroundColor(.gray)
                            }
                            Toggle(isOn: $isReminderSet) {
                                Text("Reminder")
                            }
                        }
                        .padding(.horizontal) // Keep horizontal padding


                        if isTimePickerVisible && isReminderSet {
                            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .padding(.vertical, 5) // Adjust vertical padding
                                .padding(.horizontal) // Keep horizontal padding
                                .onChange(of:selectedDate) { newValue in
                                    reminderTime = newValue // Update reminderTime when selectedDate changes
                                }

                        }
                    }
                    .frame(maxWidth: .infinity) // Make the form width extend to the maximum width
                    .padding() // Add padding inside the form
                }
            }
            .gesture(
                           TapGesture()
                               .onEnded { _ in
                                   UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                               }
                       )
            Spacer() // Add spacer to push form to the center
            Button(action: {
                    addHabit()
                }) {
                    Text("Add Habit")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .padding(.vertical, 65)
                .padding(.bottom, 20) // Add bottom padding to the button
        }
        .frame(maxWidth: 500) // Limit the maximum width of the form
        .padding(.top, 150)
        .padding(.bottom, 20)
        .background(Color.gray.opacity(0.1))
        .edgesIgnoringSafeArea(.all)
        .overlay(
            VStack {
                if showingToast {
                    Text("New Habit Added")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.move(edge: .top))
                        .animation(.easeInOut(duration: 0.5))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingToast = false
                            }
                        }
                }
                Spacer()
            }
            .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top)
            .edgesIgnoringSafeArea(.top)
            , alignment: .top
        )


    }

    private func addHabit() {
        let newHabit = Habit(context: viewContext)
        newHabit.name = habitName
        newHabit.isCompleted = false
        newHabit.reminderTime = reminderTime

        do {
            try viewContext.save()
            showingToast = true
            if let notificationIdentifier = scheduleNotification(for: newHabit) {
                        newHabit.notificationIdentifier = notificationIdentifier
                        try viewContext.save() // Save the updated habit with notification identifier
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private var selectedTimeString: String {
        guard let reminderTime = reminderTime else {
            return "Now"
        }
        // Format the selected reminder time as a string
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Display time in short format
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

        return identifier // Return the notification identifier
    }
}


struct NewHabitView_Previews: PreviewProvider {
    static var previews: some View {
        NewHabitView()
    }
}

