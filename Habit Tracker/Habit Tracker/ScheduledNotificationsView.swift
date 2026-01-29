//
//  ScheduledNotificationsView.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/04.
//

import SwiftUI
import CoreData
import UserNotifications

private struct ReminderGroup: Identifiable {
    let id: String // base identifier
    let title: String
    let body: String
    let requests: [UNNotificationRequest]
    let weekdays: [Int] // 1=Sun ... 7=Sat
    let nextTriggerDate: Date?
}

struct ScheduledNotificationsView: View {
    @State private var reminderGroups: [ReminderGroup] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    if reminderGroups.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 64, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
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
                        ForEach(reminderGroups) { group in
                            ReminderGroupCard(group: group) {
                                removeNotifications(withIdentifiers: group.requests.map(\.identifier))
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
                let habitRequests = requests.filter { $0.identifier.hasPrefix("habitReminder-") }
                self.reminderGroups = groupRequests(habitRequests)
                    .sorted(by: { g1, g2 in
                        let d1 = g1.nextTriggerDate ?? Date.distantFuture
                        let d2 = g2.nextTriggerDate ?? Date.distantFuture
                        if d1 != d2 { return d1 < d2 }
                        return g1.title < g2.title
                    })
            }
        }
    }

    private func removeNotifications(withIdentifiers identifiers: [String]) {
        withAnimation {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            fetchScheduledNotifications()
        }
    }

    private func groupRequests(_ requests: [UNNotificationRequest]) -> [ReminderGroup] {
        let grouped = Dictionary(grouping: requests, by: { baseIdentifier(from: $0.identifier) })
        return grouped.map { base, reqs in
            let sortedReqs = reqs.sorted { ($0.identifier) < ($1.identifier) }
            let title = sortedReqs.first?.content.title ?? "Reminder"
            let body = sortedReqs.first?.content.body ?? ""
            let weekdays = sortedReqs.compactMap { weekday(from: $0.identifier) }.sorted()
            let nextDate = sortedReqs
                .compactMap { ( $0.trigger as? UNCalendarNotificationTrigger )?.nextTriggerDate() }
                .min()
            return ReminderGroup(
                id: base,
                title: title,
                body: body,
                requests: sortedReqs,
                weekdays: weekdays,
                nextTriggerDate: nextDate
            )
        }
    }

    /// identifier format: "habitReminder-<habitURI>-<weekdayInt>"
    /// We recover the base by stripping a trailing "-<1..7>" segment, if present.
    private func baseIdentifier(from identifier: String) -> String {
        let parts = identifier.split(separator: "-")
        guard parts.count >= 2, let last = parts.last, let n = Int(last), (1...7).contains(n) else {
            return identifier
        }
        return parts.dropLast().joined(separator: "-")
    }

    private func weekday(from identifier: String) -> Int? {
        let parts = identifier.split(separator: "-")
        guard let last = parts.last, let n = Int(last), (1...7).contains(n) else { return nil }
        return n
    }
}

private struct ReminderGroupCard: View {
    let group: ReminderGroup
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        Text("\(daysLabel(group.weekdays)) at \(timeLabel(group.requests.first))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        Text("Next: \(nextLabel(group.nextTriggerDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !group.body.isEmpty {
                    Text(group.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: { showDeleteConfirm = true }) {
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
        .alert("Remove reminder?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { onDelete() }
        } message: {
            Text("This will remove \(group.requests.count) scheduled reminder\(group.requests.count == 1 ? "" : "s") for this habit.")
        }
    }

    private func nextLabel(_ date: Date?) -> String {
        guard let date else { return "Unknown time" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        let rel = relative.localizedString(for: date, relativeTo: Date())

        let time = DateFormatter()
        time.locale = .autoupdatingCurrent
        time.dateStyle = .none
        time.timeStyle = .short
        return "\(rel) (\(time.string(from: date)))"
    }
    
    private func timeLabel(_ request: UNNotificationRequest?) -> String {
        guard
            let request,
            let trigger = request.trigger as? UNCalendarNotificationTrigger,
            let date = trigger.nextTriggerDate()
        else { return "Unknown time" }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func daysLabel(_ weekdays: [Int]) -> String {
        if weekdays.count == 7 { return "Every day" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        
        func short(_ weekday: Int) -> String {
            switch weekday {
            case 1: return "Sun"
            case 2: return "Mon"
            case 3: return "Tue"
            case 4: return "Wed"
            case 5: return "Thu"
            case 6: return "Fri"
            case 7: return "Sat"
            default: return "?"
            }
        }
        return weekdays.map(short).joined(separator: ", ")
    }
}
