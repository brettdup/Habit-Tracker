//
//  Habit_TrackerApp.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import SwiftUI
import UserNotifications

@main
struct Habit_TrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        
    }
}

var window: UIWindow?
    
    // Define a key for UserDefaults
    let lastLaunchDateKey = "LastLaunchDate"


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Request authorization for notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
        if isNextDay() {
                    // Perform actions for the next day
                    // For example, reset daily tasks, update data, etc.
        }
        
        // Set the delegate for handling notifications
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
        // Handle user's response to the notification
        completionHandler()
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
