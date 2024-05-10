//
//  ScheduledNotificationsView.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/04.
//

import SwiftUI
import CoreData
import UserNotifications

struct ScheduledNotificationsView: View {
    @State private var scheduledNotifications: [UNNotificationRequest] = []


    var body: some View {
        NavigationView {
            List {
                ForEach(scheduledNotifications, id: \.identifier) { notification in
                    VStack(alignment: .leading) {
                        Text(self.formattedNameString(for: notification.trigger, habitName: notification.content.title as? String))
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Scheduled: \(self.formattedTimeString(for: notification.trigger, habitName: notification.content.title as? String))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .contextMenu {
                        Button(action: {
                            self.removeNotification(with: notification.identifier)
                        }) {
                            Text("Delete")
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Scheduled Notifications")
            .onAppear {
                fetchScheduledNotifications()
            }
        }
    }

    private func fetchScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                // Sort the requests based on the trigger date
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
    

    

    private func removeNotification(with identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Refresh the list of scheduled notifications
        fetchScheduledNotifications()
    }

    private func formattedTimeString(for trigger: UNNotificationTrigger?, habitName: String?) -> String {
        guard let trigger = trigger as? UNCalendarNotificationTrigger else { return "Unknown" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        let currentDate = Date()
        let reminderDate = trigger.nextTriggerDate() ?? Date()
        
        let timeDifference = Calendar.current.dateComponents([.hour, .minute], from: currentDate, to: reminderDate)
        let hourDifference = timeDifference.hour ?? 0
        let minuteDifference = timeDifference.minute ?? 0
        
        var timeString = ""
        if hourDifference > 0 {
            timeString += "in \(hourDifference)h"
        }
        if minuteDifference > 0 {
            timeString += "\(minuteDifference)m"
        }
        
        let digitalTime = dateFormatter.string(from: reminderDate)
        
        let name = habitName ?? "Unknown Habit"
        
        return "\(timeString) (\(digitalTime))"
    }
    
    private func formattedNameString(for trigger: UNNotificationTrigger?, habitName: String?) -> String {
        guard let trigger = trigger as? UNCalendarNotificationTrigger else { return "Unknown" }
        
        let name = habitName ?? "Unknown Habit"
        
        // Split the name string by the delimiter "-"
        let nameComponents = name.components(separatedBy: "-")
        
        // Take the second part after the delimiter
        if let reminderName = nameComponents.last?.trimmingCharacters(in: .whitespaces) {
            return reminderName
        } else {
            return "Unknown Reminder"
        }
    }


    
    

}


