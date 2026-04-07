//
//  Habit_TrackerApp.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import SwiftUI
import UserNotifications
import CoreData

private enum PreviewRuntime {
    static var isRunning: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - Notification Category & Actions

private enum HabitNotificationCategory {
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
            identifier: HabitReminderScheduler.notificationCategoryIdentifier,
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

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard !PreviewRuntime.isRunning else {
            return true
        }

        HabitNotificationCategory.register()
        UNUserNotificationCenter.current().delegate = self
        let context = PersistenceController.shared.container.viewContext
        context.performAndWait {
            HabitDailySyncService.migrateLegacyCompletionRelationships(in: context)
            HabitDailySyncService.syncHabitStates(in: context)
            HabitReminderScheduler.refreshAllReminders(in: context)
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard !PreviewRuntime.isRunning else { return }
        clearDeliveredRandomNudges()
        RandomNudgeScheduler.refreshAllNudges()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        refreshNudgesIfNeeded(for: notification.request)
        completionHandler([.banner, .sound])
    }

    // Handle user interactions with notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["randomNudge"] as? Bool == true {
            clearDeliveredRandomNudges()
            RandomNudgeScheduler.refreshAllNudges()
            completionHandler()
            return
        }

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
            HabitScheduleResolver.isActive(habit: h, on: Date())
        }
        let totalCount = Int16(activeToday.count)

        try? HabitCompletionStore.setCompleted(true, for: habit, totalHabits: totalCount, on: today, in: context)
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
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = HabitReminderScheduler.notificationCategoryIdentifier
        content.userInfo = ["habitObjectIDURI": habitURI.absoluteString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: snoozeID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func refreshNudgesIfNeeded(for request: UNNotificationRequest) {
        if request.content.userInfo["randomNudge"] as? Bool == true {
            RandomNudgeScheduler.refreshAllNudges()
        }
    }

    private func clearDeliveredRandomNudges() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .map(\.request)
                .filter { $0.identifier.hasPrefix("randomNudge-") || (($0.content.userInfo["randomNudge"] as? Bool) == true) }
                .map(\.identifier)
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
