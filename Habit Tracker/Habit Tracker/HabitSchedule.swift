import Foundation
import SwiftUI
import CoreData

enum HabitWeekday: Int, CaseIterable, Identifiable {
    // Bit positions (Mon = 0 ... Sun = 6)
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    var veryShortLabel: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }

    /// Calendar weekday: 1=Sunday, 2=Monday, ... 7=Saturday
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

struct HabitSchedule {
    static let allDaysMask: Int16 = 0b111_1111 // 127
    static let weekdaysMask: Int16 = 0b001_1111 // Mon..Fri
    static let weekendsMask: Int16 = 0b110_0000 // Sat..Sun (bits 5 & 6)

    static func isActive(on date: Date, mask: Int16) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun ... 7=Sat
        let bitIndex: Int
        switch weekday {
        case 2: bitIndex = HabitWeekday.monday.rawValue
        case 3: bitIndex = HabitWeekday.tuesday.rawValue
        case 4: bitIndex = HabitWeekday.wednesday.rawValue
        case 5: bitIndex = HabitWeekday.thursday.rawValue
        case 6: bitIndex = HabitWeekday.friday.rawValue
        case 7: bitIndex = HabitWeekday.saturday.rawValue
        case 1: bitIndex = HabitWeekday.sunday.rawValue
        default: bitIndex = HabitWeekday.monday.rawValue
        }
        return ((Int(mask) >> bitIndex) & 1) == 1
    }

    static func label(for mask: Int16) -> String {
        switch mask {
        case allDaysMask:
            return "Every day"
        case weekdaysMask:
            return "Weekdays"
        case weekendsMask:
            return "Weekends"
        default:
            let selected = HabitWeekday.allCases.filter { isSelected($0, mask: mask) }
            if selected.isEmpty { return "No days" }
            return selected.map(\.shortLabel).joined(separator: ", ")
        }
    }

    static func isSelected(_ weekday: HabitWeekday, mask: Int16) -> Bool {
        ((Int(mask) >> weekday.rawValue) & 1) == 1
    }

    static func setSelected(_ weekday: HabitWeekday, selected: Bool, mask: inout Int16) {
        let bit = Int16(1 << weekday.rawValue)
        if selected {
            mask = mask | bit
        } else {
            mask = mask & ~bit
        }
    }

    // MARK: - Time of Day Grouping
    // Morning: 5am–12pm, Afternoon: 12pm–5pm, Evening: 5pm–12am, Night: 12am–5am
    enum TimeOfDay: String, CaseIterable {
        case night = "Night"
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case noReminder = "No Reminder"

        static var displayOrder: [TimeOfDay] {
            [.night, .morning, .afternoon, .evening, .noReminder]
        }

        static func from(reminderTime: Date?) -> TimeOfDay {
            guard let time = reminderTime else { return .noReminder }
            let hour = Calendar.current.component(.hour, from: time)
            switch hour {
            case 0..<5: return .night
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            default: return .evening
            }
        }
    }
}

struct HabitFormValidation {
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func duplicateNameExists(
        _ normalizedName: String,
        excluding habit: Habit? = nil,
        in context: NSManagedObjectContext
    ) -> Bool {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name =[c] %@", normalizedName)
        do {
            let matches = try context.fetch(fetchRequest)
            if let habit {
                return matches.contains { $0.objectID != habit.objectID }
            }
            return !matches.isEmpty
        } catch {
            return false
        }
    }
}

struct HabitStreakCalculator {
    static func currentStreak(
        completionDates: [Date],
        activeDaysMask: Int16,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let normalizedCompletions = Set(completionDates.map { calendar.startOfDay(for: $0) })
        let effectiveMask = activeDaysMask == 0 ? HabitSchedule.allDaysMask : activeDaysMask

        guard let startDay = latestActiveDay(onOrBefore: calendar.startOfDay(for: date), mask: effectiveMask, calendar: calendar) else {
            return 0
        }

        var streak = 0
        var cursor = startDay

        while normalizedCompletions.contains(cursor) {
            streak += 1
            guard let previous = latestActiveDay(
                onOrBefore: calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor,
                mask: effectiveMask,
                calendar: calendar
            ) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    private static func latestActiveDay(onOrBefore date: Date, mask: Int16, calendar: Calendar) -> Date? {
        guard mask != 0 else { return nil }
        var day = calendar.startOfDay(for: date)
        for _ in 0..<8 {
            if HabitSchedule.isActive(on: day, mask: mask) {
                return day
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previous
        }
        return nil
    }
}

struct HabitPrioritySection: View {
    @Binding var priority: Int16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Priority", systemImage: "star")
                .font(.headline)
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                HStack {
                    Text("Priority Level")
                        .font(.system(size: 16))
                    Spacer()
                    Text("\(priority)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { index in
                        Button(action: { priority = Int16(index) }) {
                            Image(systemName: index <= priority ? "star.fill" : "star")
                                .foregroundColor(index <= priority ? .orange : .gray)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct HabitScheduleSection: View {
    @Binding var activeDaysMask: Int16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schedule", systemImage: "calendar")
                .font(.headline)
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                HStack {
                    Text("Active on")
                        .font(.system(size: 16))
                    Spacer()
                    Text(HabitSchedule.label(for: activeDaysMask))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack(spacing: 10) {
                    HabitSchedulePresetButton(title: "Every day", isSelected: activeDaysMask == HabitSchedule.allDaysMask) {
                        activeDaysMask = HabitSchedule.allDaysMask
                    }
                    HabitSchedulePresetButton(title: "Weekdays", isSelected: activeDaysMask == HabitSchedule.weekdaysMask) {
                        activeDaysMask = HabitSchedule.weekdaysMask
                    }
                    HabitSchedulePresetButton(title: "Weekends", isSelected: activeDaysMask == HabitSchedule.weekendsMask) {
                        activeDaysMask = HabitSchedule.weekendsMask
                    }
                }

                HStack(spacing: 8) {
                    ForEach(HabitWeekday.allCases) { day in
                        let isOn = HabitSchedule.isSelected(day, mask: activeDaysMask)
                        Button {
                            var mask = activeDaysMask
                            HabitSchedule.setSelected(day, selected: !isOn, mask: &mask)
                            activeDaysMask = mask
                        } label: {
                            Text(day.veryShortLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(isOn ? Color.accentColor : Color(.systemGray5))
                                )
                                .foregroundColor(isOn ? .white : .primary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct HabitReminderSection: View {
    @Binding var isReminderSet: Bool
    @Binding var isTimePickerVisible: Bool
    @Binding var selectedDate: Date
    let selectedTimeString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Reminder", systemImage: "bell.fill")
                .font(.headline)
                .foregroundColor(.gray)

            VStack(spacing: 15) {
                Toggle(isOn: $isReminderSet) {
                    Text("Daily Reminder")
                        .font(.system(size: 16))
                }
                .tint(.accentColor)

                if isReminderSet {
                    Divider()

                    Button(action: { isTimePickerVisible.toggle() }) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.accentColor)
                            Text(selectedTimeString)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                    }

                    if isTimePickerVisible {
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}

struct HabitSchedulePresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
    }
}
