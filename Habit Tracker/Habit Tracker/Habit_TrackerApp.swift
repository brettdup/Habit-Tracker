//
//  Habit_TrackerApp.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import SwiftUI
import UserNotifications
import CoreData

// MARK: - Notification Category & Actions

private enum HabitNotificationCategory {
    static let identifier = "HABIT_REMINDER"

    static func register() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Complete",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 15 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

@main
struct Habit_TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    let persistenceController = PersistenceController.shared

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }
    
    private var accentColor: AppAccentColor {
        AppAccentColor(rawValue: accentColorRaw) ?? .blue
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(themeMode.colorScheme)
                .tint(accentColor.color)
        }
    }
}

private let lastLaunchDateKey = "LastLaunchDate"

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        HabitNotificationCategory.register()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
        if isNextDay() {
            // Perform actions for the next day
        }

        UNUserNotificationCenter.current().delegate = self
        UserDefaults.standard.set(Date(), forKey: lastLaunchDateKey)

        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Handle how to present the notification
        completionHandler([.alert, .sound])
    }

    // Handle user interactions with notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let habitURIString = userInfo["habitObjectIDURI"] as? String,
              let habitURI = URL(string: habitURIString) else {
            completionHandler()
            return
        }

        let context = PersistenceController.shared.container.viewContext

        switch response.actionIdentifier {
        case "COMPLETE":
            handleCompleteAction(habitURI: habitURI, context: context)
        case "SNOOZE":
            handleSnoozeAction(habitURI: habitURI)
        default:
            break
        }
        completionHandler()
    }

    private func handleCompleteAction(habitURI: URL, context: NSManagedObjectContext) {
        guard let coordinator = context.persistentStoreCoordinator,
              let objectID = coordinator.managedObjectID(forURIRepresentation: habitURI),
              let habit = try? context.existingObject(with: objectID) as? Habit else { return }

        let today = Calendar.current.startOfDay(for: Date())
        habit.isCompleted = true

        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        guard let allHabits = try? context.fetch(fetchRequest) else { return }
        let activeToday = allHabits.filter { h in
            HabitSchedule.isActive(on: Date(), mask: h.activeDaysMask == 0 ? HabitSchedule.allDaysMask : h.activeDaysMask)
        }
        let totalCount = Int16(activeToday.count)

        let record = HabitCompletionRecord(context: context)
        record.date = today
        record.habitName = habit.name
        record.isCompleted = true
        record.totalHabits = totalCount

        try? context.save()
    }

    private func handleSnoozeAction(habitURI: URL) {
        let context = PersistenceController.shared.container.viewContext
        guard let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: habitURI),
              let habit = try? context.existingObject(with: objectID) as? Habit,
              let habitName = habit.name else { return }

        let base = "habitReminder-\(habitURI.absoluteString)"
        let snoozeID = "\(base)-snooze-\(Date().timeIntervalSince1970)"

        let content = UNMutableNotificationContent()
        content.title = "Reminder - \(habitName)"
        content.body = "Don't forget to complete your habit: \(habitName)"
        content.sound = .default
        content.categoryIdentifier = HabitNotificationCategory.identifier
        content.userInfo = ["habitObjectIDURI": habitURI.absoluteString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    func isNextDay() -> Bool {
            // Get the last launch date from UserDefaults
            if let lastLaunchDate = UserDefaults.standard.object(forKey: lastLaunchDateKey) as? Date {
                // Get the current date
                let currentDate = Date()
                
                // Compare the day components of the last launch date and the current date
                let calendar = Calendar.current
                let lastLaunchDay = calendar.component(.day, from: lastLaunchDate)
                let currentDay = calendar.component(.day, from: currentDate)
                
                // If the current day is greater than the last launch day, it's the next day
                return currentDay > lastLaunchDay
            }
            
            // If the last launch date is nil, it's the next day
            return true
        }

}
