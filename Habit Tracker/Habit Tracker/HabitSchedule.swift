import Foundation

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

