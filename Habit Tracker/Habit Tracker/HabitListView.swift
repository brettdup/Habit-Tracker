//
//  HabitListView.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import SwiftUI
import CoreData

struct HabitListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: Habit.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]) var habits: FetchedResults<Habit>
    @State private var showAlert = false
    @State private var deletionIndexSet: IndexSet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(habits) { habit in
                    
                    HabitRow(habit: habit)
                        .frame(height: 60)
                        
                }
                
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Delete Habit"),
                        message: Text("Are you sure you want to delete this habit?"),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteHabit(at: deletionIndexSet!)
                        },
                        secondaryButton: .cancel()
                    )
                }
                .onAppear {
                    // Call the function to reset habits if it's a new day
                    resetHabitsIfNewDay()
                }
            }
            
        }
    }

    public func deleteHabit(at offsets: IndexSet) {
        withAnimation {
                    offsets.forEach { index in
                        let habit = habits[index]
                        // Delete associated reminders (notifications)
                        deleteReminders(for: habit)
                        viewContext.delete(habit)
                    }

                    do {
                        try viewContext.save()
                    } catch {
                        let nsError = error as NSError
                        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                    }
                }
    }
        
    private func deleteReminders(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }
        
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    
    
    private func resetHabitsIfNewDay() {
        // Retrieve the last reset date from UserDefaults or another storage mechanism
        let defaults = UserDefaults.standard
        let lastResetDate = defaults.object(forKey: "LastResetDate") as? Date ?? Date.distantPast
        
        // Get the current date
        let currentDate = Date()

        // Check if it's a new day
        if !Calendar.current.isDate(lastResetDate, inSameDayAs: currentDate) {
            // Iterate through each habit
            for habit in habits {
                // Fetch the latest completion record for the habit
                let fetchRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "habitName == %@", habit.name ?? "")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                fetchRequest.fetchLimit = 1

                do {
                    let latestCompletionRecords = try viewContext.fetch(fetchRequest)
                    if let latestCompletionRecord = latestCompletionRecords.first {
                        // Check if the last completion date is earlier than the current date
                        if let lastCompletionDate = latestCompletionRecord.date,
                            lastCompletionDate < currentDate {
                            // Reset the completion status
                            habit.isCompleted = false
                        }
                    }
                } catch {
                    print("Error fetching latest completion record: \(error)")
                }
            }
            
            // Save the current date as the last reset date
            defaults.set(currentDate, forKey: "LastResetDate")
            
            // Save the managed object context to persist changes
            do {
                try viewContext.save()
            } catch {
                print("Error saving managed object context: \(error)")
            }
        }
    }


}


struct HabitRow: View {
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showAlert = false
    @State private var isCheckboxTapped = false
    @State private var isEditing = false


    var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                HStack {
                    Text(habit.name ?? "")
                        .foregroundColor(habit.isCompleted ? .secondary : .primary)
                        .font(.headline)
                        .padding(.leading, 20)
                    
                    Spacer()
                    
                    CheckBox(isChecked: $habit.isCompleted, toggleCompletion: toggleCompletion) // Pass the toggleCompletion closure
                        .foregroundColor(habit.isCompleted ? .accentColor : .secondary)
                        .padding(.trailing, 20)
                }
                .padding(.vertical, 10)
                

            }
            .padding(.horizontal, 20)
            .onLongPressGesture {
                isEditing = true
            }
            
            .sheet(isPresented: $isEditing) {
                HabitDetailView(habit: habit, viewContext: viewContext)
            }
        }     
    
        

    

   
    private func toggleCompletion() {
        print(habit)

//        habit.isCompleted.toggle()
//        print(habit)
        if !habit.isCompleted {
            // Delete corresponding completion record if habit is unticked
            let fetchRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: Date())
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND habitName == %@", argumentArray: [startDate, endDate, habit.name ?? ""])

            do {
                let records = try viewContext.fetch(fetchRequest)
                print("Found \(records.count) records to delete for habit: \(habit.name ?? "")")
                for record in records {
                    print("Deleting record: \(record)")
                    viewContext.delete(record)
                }
                try viewContext.save()
                print("Records deleted successfully")
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
        else
        {
            addCompletionRecord(for: habit)
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }






    private func addCompletionRecord(for habit: Habit) {
        print(habit)
        let newCompletion = HabitCompletionRecord(context: viewContext)
        newCompletion.date = Calendar.current.startOfDay(for: Date()) // Save only the day portion of the date
        newCompletion.habitName = habit.name
        newCompletion.isCompleted = true

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct CheckBox: View {
    @Binding var isChecked: Bool
    var toggleCompletion: () -> Void // Closure to toggle completion state
    
    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .resizable()
            .frame(width: 24, height: 24)
            .padding(4)
            .onTapGesture {
                isChecked.toggle()
                toggleCompletion()
            }
    }
}

