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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Dynamic background based on color scheme
            Group {
                if colorScheme == .dark {
                    Color.black.opacity(0.9)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white.opacity(0.8)]),
                                 startPoint: .top,
                                 endPoint: .bottom)
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    if scheduledNotifications.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 70))
                                .foregroundStyle(.blue)
                                .symbolEffect(.bounce)
                            
                            VStack(spacing: 12) {
                                Text("No Active Reminders")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Text("Add reminders to your habits to help stay on track")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(uiColor: .systemGray6) : Color(uiColor: .systemBackground))
                                .shadow(radius: 8)
                        )
                        .padding(.horizontal)
                    } else {
                        ForEach(scheduledNotifications, id: \.identifier) { notification in
                            ReminderCard(notification: notification) {
                                removeNotification(with: notification.identifier)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            fetchScheduledNotifications()
        }
    }

    private func fetchScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                // Print for debugging
                print("Found \(requests.count) notifications")
                for request in requests {
                    print("Notification: \(request.identifier)")
                    print("Title: \(request.content.title)")
                    print("Body: \(request.content.body)")
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        print("Next trigger date: \(trigger.nextTriggerDate()?.description ?? "none")")
                    }
                }
                
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
        withAnimation {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            fetchScheduledNotifications()
        }
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
        return "\(timeString) (\(digitalTime))"
    }
    
    private func formattedNameString(for trigger: UNNotificationTrigger?, habitName: String?) -> String {
        guard let trigger = trigger as? UNCalendarNotificationTrigger else { return "Unknown" }
        
        let name = habitName ?? "Unknown Habit"
        let nameComponents = name.components(separatedBy: "-")
        
        if let reminderName = nameComponents.last?.trimmingCharacters(in: .whitespaces) {
            return reminderName
        } else {
            return "Unknown Reminder"
        }
    }
}

struct ReminderCard: View {
    let notification: UNNotificationRequest
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.content.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    Text(notification.content.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 16))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(uiColor: .systemGray6) : Color(uiColor: .systemBackground))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                       radius: 8, x: 0, y: 2)
        )
    }
}
