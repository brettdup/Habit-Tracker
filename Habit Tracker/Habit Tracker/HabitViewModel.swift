import Foundation
import CoreData
import SwiftUI

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    private var viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        fetchHabits()
    }
    
    func fetchHabits() {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]
        
        do {
            habits = try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habits: \(error)")
        }
    }
    
    func deleteHabit(at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let habit = habits[index]
                deleteReminders(for: habit)
                viewContext.delete(habit)
            }
            saveContext()
        }
    }
    
    private func deleteReminders(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func saveContext() {
        do {
            try viewContext.save()
            fetchHabits()  // Refresh the habit list
        } catch {
            print("Error saving managed object context: \(error)")
        }
    }
    
    func resetHabitsIfNewDay() {
        let defaults = UserDefaults.standard
        let lastResetDate = defaults.object(forKey: "LastResetDate") as? Date ?? Date.distantPast
        let currentDate = Date()
        
        if !Calendar.current.isDate(lastResetDate, inSameDayAs: currentDate) {
            for habit in habits {
                let fetchRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "habitName == %@", habit.name ?? "")
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                fetchRequest.fetchLimit = 1
                
                do {
                    let latestCompletionRecords = try viewContext.fetch(fetchRequest)
                    if let latestCompletionRecord = latestCompletionRecords.first,
                       let lastCompletionDate = latestCompletionRecord.date,
                       lastCompletionDate < currentDate {
                        habit.isCompleted = false
                    }
                } catch {
                    print("Error fetching latest completion record: \(error)")
                }
            }
            defaults.set(currentDate, forKey: "LastResetDate")
            saveContext()
        }
    }
}
