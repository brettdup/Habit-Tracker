//
//  Persistence.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let defaults: [(name: String, icon: String, reminderHour: Int?, completed: Bool)] = [
            ("Morning meditation", "brain.head.profile", 7, true),
            ("Read 20 minutes", "book.fill", 21, false),
            ("Exercise", "figure.run", 8, true),
            ("Drink water", "drop.fill", nil, false),
            ("Sleep by 10pm", "bed.double.fill", 22, false)
        ]
        let calendar = Calendar.current
        for (name, icon, hour, completed) in defaults {
            let habit = Habit(context: viewContext)
            habit.name = name
            habit.iconName = icon
            habit.isCompleted = completed
            habit.timestamp = Date()
            if let hour = hour {
                habit.reminderTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
            }
        }
        do {
            try viewContext.save()
        } catch {
            print("Preview data failed to save: \(error.localizedDescription)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Habit_Tracker")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let description = container.persistentStoreDescriptions.first {
            // Required for stores that were previously opened with CloudKit (persistent history).
            // Without this, Core Data forces the store into read-only mode.
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data failed to load persistent store: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
