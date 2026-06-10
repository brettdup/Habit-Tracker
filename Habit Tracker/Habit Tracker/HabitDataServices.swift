import CoreData
import EventKit
import Foundation
import UserNotifications

enum RandomNudgeDefaults {
    static let defaultMessage = "Small reset: take a moment for this now."
}

struct RandomNudge: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var message: String
    var wakeStartHour: Int
    var wakeStartMinute: Int
    var wakeEndHour: Int
    var wakeEndMinute: Int
    var nudgesPerDay: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        wakeStartHour: Int,
        wakeStartMinute: Int,
        wakeEndHour: Int,
        wakeEndMinute: Int,
        nudgesPerDay: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.wakeStartHour = wakeStartHour
        self.wakeStartMinute = wakeStartMinute
        self.wakeEndHour = wakeEndHour
        self.wakeEndMinute = wakeEndMinute
        self.nudgesPerDay = nudgesPerDay
        self.createdAt = createdAt
    }
}

enum RandomNudgeStore {
    static let storageKey = "randomNudges"

    static func fetchAll() -> [RandomNudge] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let nudges = try? JSONDecoder().decode([RandomNudge].self, from: data)
        else {
            return []
        }
        return nudges.sorted { $0.createdAt < $1.createdAt }
    }

    static func saveAll(_ nudges: [RandomNudge]) {
        guard let data = try? JSONEncoder().encode(nudges) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func add(_ nudge: RandomNudge) {
        var nudges = fetchAll()
        nudges.append(nudge)
        saveAll(nudges)
    }

    static func update(_ nudge: RandomNudge) {
        var nudges = fetchAll()
        guard let index = nudges.firstIndex(where: { $0.id == nudge.id }) else {
            nudges.append(nudge)
            saveAll(nudges)
            return
        }
        nudges[index] = nudge
        saveAll(nudges)
    }

    static func remove(id: UUID) {
        let nudges = fetchAll().filter { $0.id != id }
        saveAll(nudges)
    }
}

enum RandomNudgeGeneratedScheduleStore {
    private static let storageKey = "randomNudgeGeneratedSchedules"

    static func dates(for nudgeID: UUID, dayToken: String) -> [Date]? {
        load()[key(for: nudgeID, dayToken: dayToken)]
    }

    static func setDates(_ dates: [Date], for nudgeID: UUID, dayToken: String) {
        var map = load()
        map[key(for: nudgeID, dayToken: dayToken)] = dates.sorted()
        save(map)
    }

    static func clear(nudgeID: UUID) {
        let prefix = "\(nudgeID.uuidString)|"
        var map = load()
        map.keys.filter { $0.hasPrefix(prefix) }.forEach { map.removeValue(forKey: $0) }
        save(map)
    }

    private static func key(for nudgeID: UUID, dayToken: String) -> String {
        "\(nudgeID.uuidString)|\(dayToken)"
    }

    private static func load() -> [String: [Date]] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let map = try? JSONDecoder().decode([String: [Date]].self, from: data)
        else {
            return [:]
        }
        return map
    }

    private static func save(_ map: [String: [Date]]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum HabitCompletionStore {
    static func fetchRecords(
        for habit: Habit,
        in context: NSManagedObjectContext
    ) throws -> [HabitCompletionRecord] {
        let request: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]
        request.predicate = NSPredicate(format: "habit == %@", habit)
        return try context.fetch(request)
    }

    static func fetchRecord(
        for habit: Habit,
        on date: Date,
        in context: NSManagedObjectContext,
        calendar: Calendar = .current
    ) throws -> HabitCompletionRecord? {
        let request: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            calendar.startOfDay(for: date) as NSDate,
            (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date) as NSDate
        )
        return try context.fetch(request).first
    }

    static func setCompleted(
        _ isCompleted: Bool,
        for habit: Habit,
        totalHabits: Int16,
        on date: Date = Date(),
        in context: NSManagedObjectContext,
        calendar: Calendar = .current
    ) throws {
        let startOfDay = calendar.startOfDay(for: date)
        if isCompleted {
            let record = try fetchRecord(for: habit, on: startOfDay, in: context, calendar: calendar) ?? HabitCompletionRecord(context: context)
            record.date = startOfDay
            record.habit = habit
            record.habitName = habit.name
            record.isCompleted = true
            record.totalHabits = totalHabits
        } else if let record = try fetchRecord(for: habit, on: startOfDay, in: context, calendar: calendar) {
            context.delete(record)
        }

        habit.isCompleted = isCompleted
        try context.save()
    }

    static func deleteAllRecords(for habit: Habit, in context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@", habit)
        let records = try context.fetch(request)
        for record in records {
            context.delete(record)
        }
        try context.save()
    }
}

enum HabitDailySyncService {
    static func migrateLegacyCompletionRelationships(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        request.predicate = NSPredicate(format: "habit == nil AND habitName != nil")

        guard let records = try? context.fetch(request), !records.isEmpty else { return }

        var habitsByNormalizedName: [String: Habit] = [:]
        let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        if let habits = try? context.fetch(habitRequest) {
            for habit in habits {
                let normalizedName = HabitFormValidation.normalizedName(habit.name ?? "").lowercased()
                guard !normalizedName.isEmpty else { continue }
                habitsByNormalizedName[normalizedName] = habit
            }
        }

        var didChange = false
        for record in records {
            let normalizedName = HabitFormValidation.normalizedName(record.habitName ?? "").lowercased()
            guard let habit = habitsByNormalizedName[normalizedName] else { continue }
            record.habit = habit
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }

    static func syncHabitStates(
        in context: NSManagedObjectContext,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        guard let habits = try? context.fetch(habitRequest) else { return }

        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let completionRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        completionRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)

        let todaysCompletions = (try? context.fetch(completionRequest)) ?? []
        let completedHabitIDs = Set(todaysCompletions.compactMap { $0.habit?.objectID })

        var didChange = false
        for habit in habits {
            let shouldBeCompleted = HabitScheduleResolver.isActive(habit: habit, on: referenceDate, calendar: calendar) && completedHabitIDs.contains(habit.objectID)
            if habit.isCompleted != shouldBeCompleted {
                habit.isCompleted = shouldBeCompleted
                didChange = true
            }
        }

        if didChange {
            try? context.save()
        }
    }
}

enum HabitReminderScheduler {
    static let notificationsEnabledKey = "notificationsEnabled"
    static let notificationCategoryIdentifier = "HABIT_REMINDER"
    private static let defaultNotificationTitleKey = "defaultNotificationTitle"
    private static let defaultNotificationBodyKey = "defaultNotificationBody"

    static var notificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: notificationsEnabledKey)
    }

    static func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    completion(true)
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }

    static func refreshAllReminders(in context: NSManagedObjectContext, completion: (() -> Void)? = nil) {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        guard let habits = try? context.fetch(request) else {
            completion?()
            return
        }

        guard notificationsEnabled else {
            removeAllHabitReminders()
            RandomNudgeScheduler.removeAllNudges()
            completion?()
            return
        }

        ensureAuthorization { granted in
            guard granted else {
                removeAllHabitReminders()
                RandomNudgeScheduler.removeAllNudges()
                completion?()
                return
            }

            for habit in habits {
                scheduleReminders(for: habit)
            }
            RandomNudgeScheduler.refreshAllNudges()
            completion?()
        }
    }

    static func updateGlobalNotifications(
        enabled: Bool,
        in context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        UserDefaults.standard.set(enabled, forKey: notificationsEnabledKey)

        guard enabled else {
            removeAllHabitReminders()
            RandomNudgeScheduler.removeAllNudges()
            completion(true)
            return
        }

        ensureAuthorization { granted in
            if granted {
                refreshAllReminders(in: context)
                completion(true)
            } else {
                UserDefaults.standard.set(false, forKey: notificationsEnabledKey)
                removeAllHabitReminders()
                completion(false)
            }
        }
    }

    static func scheduleReminders(for habit: Habit) {
        let base = baseIdentifier(for: habit)
        removeNotifications(forBaseIdentifier: base)

        guard notificationsEnabled, let reminderTime = habit.reminderTime else { return }

        ensureAuthorization { granted in
            guard granted else { return }

            let habitURI = habit.objectID.uriRepresentation().absoluteString
            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: habit)
            content.body = notificationBody(for: habit)
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = notificationCategoryIdentifier
            content.userInfo = ["habitObjectIDURI": habitURI]

            let hour = Calendar.current.component(.hour, from: reminderTime)
            let minute = Calendar.current.component(.minute, from: reminderTime)

            if let interval = HabitIntervalScheduleStore.interval(for: habit), interval.intervalDays > 1 {
                scheduleIntervalReminders(
                    for: habit,
                    baseIdentifier: base,
                    content: content,
                    hour: hour,
                    minute: minute,
                    intervalDays: interval.intervalDays,
                    anchorDate: interval.anchorDate
                )
                return
            }

            let mask = habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask
            if mask == HabitSchedule.allDaysMask {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: base, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
                return
            }

            let selectedDays = HabitWeekday.allCases.filter {
                HabitSchedule.isSelected($0, mask: mask)
            }

            for day in selectedDays {
                var components = DateComponents()
                components.weekday = day.calendarWeekday
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(base)-\(day.calendarWeekday)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    static func removeReminders(for habit: Habit) {
        removeNotifications(forBaseIdentifier: baseIdentifier(for: habit))
    }

    static func removeAllHabitReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("habitReminder-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    static func baseIdentifier(for habit: Habit) -> String {
        "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
    }

    static func defaultNotificationTitle(for habitName: String?) -> String {
        "Reminder - \(habitName ?? "")"
    }

    static func defaultNotificationBody(for habitName: String?) -> String {
        "Don't forget to complete your habit: \(habitName ?? "")"
    }

    static var savedDefaultNotificationTitle: String {
        sanitizedNotificationText(UserDefaults.standard.string(forKey: defaultNotificationTitleKey)) ?? ""
    }

    static var savedDefaultNotificationBody: String {
        sanitizedNotificationText(UserDefaults.standard.string(forKey: defaultNotificationBodyKey)) ?? ""
    }

    static func saveDefaultNotificationText(title: String, body: String) {
        setSavedDefaultNotificationText(title, forKey: defaultNotificationTitleKey)
        setSavedDefaultNotificationText(body, forKey: defaultNotificationBodyKey)
    }

    static func notificationTitle(for habit: Habit) -> String {
        if let title = sanitizedNotificationText(habit.notificationTitle) {
            return notificationText(title, habitName: habit.name)
        }
        if let title = sanitizedNotificationText(savedDefaultNotificationTitle) {
            return notificationText(title, habitName: habit.name)
        }
        return defaultNotificationTitle(for: habit.name)
    }

    static func notificationBody(for habit: Habit) -> String {
        if let body = sanitizedNotificationText(habit.notificationBody) {
            return notificationText(body, habitName: habit.name)
        }
        if let body = sanitizedNotificationText(savedDefaultNotificationBody) {
            return notificationText(body, habitName: habit.name)
        }
        return defaultNotificationBody(for: habit.name)
    }

    private static func sanitizedNotificationText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func notificationText(_ text: String, habitName: String?) -> String {
        text.replacingOccurrences(of: "{habit}", with: habitName ?? "")
    }

    private static func setSavedDefaultNotificationText(_ text: String, forKey key: String) {
        if let sanitized = sanitizedNotificationText(text) {
            UserDefaults.standard.set(sanitized, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func removeNotifications(forBaseIdentifier base: String) {
        let identifiers = [base, "\(base)-multi"] + (1...7).map { "\(base)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let intervalIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("\(base)-interval-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: intervalIDs)
        }
    }

    private static func scheduleIntervalReminders(
        for habit: Habit,
        baseIdentifier: String,
        content: UNMutableNotificationContent,
        hour: Int,
        minute: Int,
        intervalDays: Int,
        anchorDate: Date
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startAnchor = calendar.startOfDay(for: anchorDate)
        let horizonDays = 45

        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let delta = calendar.dateComponents([.day], from: startAnchor, to: dayStart).day ?? 0
            if delta < 0 || delta % intervalDays != 0 { continue }

            guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) else { continue }
            if fireDate <= Date() { continue }

            let dayComponents = calendar.dateComponents([.year, .month, .day], from: dayStart)
            let dayToken = String(format: "%04d%02d%02d", dayComponents.year ?? 0, dayComponents.month ?? 0, dayComponents.day ?? 0)
            let identifier = "\(baseIdentifier)-interval-\(dayToken)"
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

enum RandomNudgeScheduler {
    private static let identifierPrefix = "randomNudge-"
    private static let rollingPendingCount = 3

    static func refreshAllNudges() {
        let nudges = RandomNudgeStore.fetchAll()
        for nudge in nudges {
            scheduleNudge(nudge)
        }
    }

    static func scheduleNudge(_ nudge: RandomNudge) {
        removePending(for: nudge.id)
        guard HabitReminderScheduler.notificationsEnabled else { return }

        HabitReminderScheduler.ensureAuthorization { granted in
            guard granted else { return }

            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            var scheduledCount = 0

            for dayOffset in 0..<14 {
                guard scheduledCount < rollingPendingCount else { break }
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }
                let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
                let dayToken = String(format: "%04d%02d%02d", dayComponents.year ?? 0, dayComponents.month ?? 0, dayComponents.day ?? 0)
                let randomDates = storedOrGeneratedTimes(for: nudge, on: day, dayToken: dayToken, calendar: calendar)
                for (idx, date) in randomDates.enumerated() {
                    guard scheduledCount < rollingPendingCount else { break }
                    if date <= now { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "Nudge: \(nudge.title)"
                    content.body = nudge.message.isEmpty ? RandomNudgeDefaults.defaultMessage : nudge.message
                    content.sound = .default
                    content.interruptionLevel = .timeSensitive
                    content.userInfo = [
                        "randomNudgeID": nudge.id.uuidString,
                        "randomNudge": true
                    ]

                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "\(identifierPrefix)\(nudge.id.uuidString)-\(dayToken)-\(idx)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request)
                    scheduledCount += 1
                }
            }
        }
    }

    static func removePending(for nudgeID: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let prefix = "\(identifierPrefix)\(nudgeID.uuidString)-"
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func removeAllNudges() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func randomTimes(for nudge: RandomNudge, on day: Date, calendar: Calendar) -> [Date] {
        var startComponents = calendar.dateComponents([.year, .month, .day], from: day)
        startComponents.hour = nudge.wakeStartHour
        startComponents.minute = nudge.wakeStartMinute

        var endComponents = calendar.dateComponents([.year, .month, .day], from: day)
        endComponents.hour = nudge.wakeEndHour
        endComponents.minute = nudge.wakeEndMinute

        guard
            let startDate = calendar.date(from: startComponents),
            let endDate = calendar.date(from: endComponents),
            endDate > startDate
        else {
            return []
        }

        let totalMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        let maxNudges = max(1, min(nudge.nudgesPerDay, totalMinutes + 1))
        var chosenMinutes = Set<Int>()
        while chosenMinutes.count < maxNudges {
            chosenMinutes.insert(Int.random(in: 0...totalMinutes))
        }

        return chosenMinutes
            .map { calendar.date(byAdding: .minute, value: $0, to: startDate) ?? startDate }
            .sorted()
    }

    private static func storedOrGeneratedTimes(
        for nudge: RandomNudge,
        on day: Date,
        dayToken: String,
        calendar: Calendar
    ) -> [Date] {
        if let stored = RandomNudgeGeneratedScheduleStore.dates(for: nudge.id, dayToken: dayToken), !stored.isEmpty {
            return stored
        }
        let generated = randomTimes(for: nudge, on: day, calendar: calendar)
        if !generated.isEmpty {
            RandomNudgeGeneratedScheduleStore.setDates(generated, for: nudge.id, dayToken: dayToken)
        }
        return generated
    }
}

struct ReminderImportCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String?
    let reminderTime: Date?
    let activeDaysMask: Int16
}

struct ReminderImportResult {
    let importedCount: Int
    let skippedDuplicates: Int
}

enum ReminderImportService {
    static func importCandidates(
        _ candidates: [ReminderImportCandidate],
        into context: NSManagedObjectContext
    ) throws -> ReminderImportResult {
        let existingRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        let existingHabits = try context.fetch(existingRequest)
        var existingNames = Set(existingHabits.map { HabitFormValidation.normalizedName($0.name ?? "").lowercased() })

        var createdHabits: [Habit] = []
        var importedCount = 0
        var skippedDuplicates = 0

        for candidate in candidates {
            let normalized = HabitFormValidation.normalizedName(candidate.title)
            guard !normalized.isEmpty else { continue }

            if existingNames.contains(normalized.lowercased()) {
                skippedDuplicates += 1
                continue
            }

            let newHabit = Habit(context: context)
            newHabit.name = normalized
            newHabit.isCompleted = false
            newHabit.reminderTime = candidate.reminderTime
            newHabit.category = candidate.category
            newHabit.priority = 0
            newHabit.activeDaysMask = candidate.activeDaysMask == 0 ? HabitSchedule.allDaysMask : candidate.activeDaysMask
            newHabit.iconName = HabitIcons.defaultIcon
            newHabit.notificationIdentifier = candidate.reminderTime == nil ? nil : "\(HabitReminderScheduler.baseIdentifier(for: newHabit))-multi"
            newHabit.timestamp = Date()

            existingNames.insert(normalized.lowercased())
            createdHabits.append(newHabit)
            importedCount += 1
        }

        if !createdHabits.isEmpty {
            try context.save()
            HabitReminderScheduler.refreshAllReminders(in: context)
        }

        return ReminderImportResult(importedCount: importedCount, skippedDuplicates: skippedDuplicates)
    }

    static func candidate(from reminder: EKReminder, calendar: Calendar = .current) -> ReminderImportCandidate {
        let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let category = reminder.calendar.title.isEmpty ? nil : reminder.calendar.title
        let reminderTime = dateForTimeOnly(from: reminder.dueDateComponents, calendar: calendar)
        let activeDaysMask = mask(for: reminder, calendar: calendar)
        return ReminderImportCandidate(
            id: reminder.calendarItemIdentifier,
            title: title,
            category: category,
            reminderTime: reminderTime,
            activeDaysMask: activeDaysMask
        )
    }

    static func scheduleLabel(for reminder: EKReminder, calendar: Calendar = .current) -> String {
        if isDailyEveryDay(reminder) {
            return "Every day"
        }
        if let intervalDays = dayInterval(for: reminder), intervalDays > 1 {
            return "Every day"
        }
        if let rule = reminder.recurrenceRules?.first,
           let days = rule.daysOfTheWeek,
           !days.isEmpty {
            let mapped = days.compactMap { habitWeekday(from: $0.dayOfTheWeek) }
            if mapped.count == 7 { return "Every day" }
            let mappedSet = Set(mapped)
            let weekdays: Set<HabitWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
            let weekends: Set<HabitWeekday> = [.saturday, .sunday]
            if mappedSet == weekdays { return "Weekdays" }
            if mappedSet == weekends { return "Weekends" }
            let ordered = HabitWeekday.allCases.filter { mappedSet.contains($0) }
            return ordered.map(\.shortLabel).joined(separator: ", ")
        }

        if let mapped = weekdayFromDueDateComponents(reminder.dueDateComponents, calendar: calendar) {
            return mapped.shortLabel
        }

        return "No repeat"
    }

    static func timeLabel(for reminder: EKReminder, calendar: Calendar = .current) -> String {
        guard let date = dateForTimeOnly(from: reminder.dueDateComponents, calendar: calendar) else {
            return "No time"
        }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func mask(for reminder: EKReminder, calendar: Calendar) -> Int16 {
        if isDailyEveryDay(reminder) {
            return HabitSchedule.allDaysMask
        }
        if let intervalDays = dayInterval(for: reminder), intervalDays > 1 {
            _ = intervalDays
            return HabitSchedule.allDaysMask
        }
        if let rule = reminder.recurrenceRules?.first,
           let days = rule.daysOfTheWeek,
           !days.isEmpty {
            var mask: Int16 = 0
            for day in days {
                guard let weekday = habitWeekday(from: day.dayOfTheWeek) else { continue }
                HabitSchedule.setSelected(weekday, selected: true, mask: &mask)
            }
            return mask == 0 ? HabitSchedule.allDaysMask : mask
        }

        if let mapped = weekdayFromDueDateComponents(reminder.dueDateComponents, calendar: calendar) {
            var mask: Int16 = 0
            HabitSchedule.setSelected(mapped, selected: true, mask: &mask)
            return mask
        }

        return HabitSchedule.allDaysMask
    }

    private static func dateForTimeOnly(from components: DateComponents?, calendar: Calendar) -> Date? {
        guard
            let components,
            let hour = components.hour,
            let minute = components.minute
        else {
            return nil
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private static func weekdayFromDueDateComponents(_ components: DateComponents?, calendar: Calendar) -> HabitWeekday? {
        guard let components else { return nil }
        if let weekday = components.weekday, let mapped = habitWeekday(from: weekday) {
            return mapped
        }
        if let date = calendar.date(from: components) {
            let weekday = calendar.component(.weekday, from: date)
            return habitWeekday(from: weekday)
        }
        return nil
    }

    private static func dayInterval(for reminder: EKReminder) -> Int? {
        guard
            let rule = reminder.recurrenceRules?.first,
            rule.frequency == .daily,
            rule.interval > 1
        else {
            return nil
        }
        return rule.interval
    }

    private static func isDailyEveryDay(_ reminder: EKReminder) -> Bool {
        guard
            let rule = reminder.recurrenceRules?.first,
            rule.frequency == .daily,
            rule.interval == 1
        else {
            return false
        }
        return true
    }

    private static func habitWeekday(from calendarWeekday: Int) -> HabitWeekday? {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }

    private static func habitWeekday(from weekday: EKWeekday) -> HabitWeekday? {
        switch weekday {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        @unknown default: return nil
        }
    }
}

struct HabitIntervalSchedule: Codable, Equatable {
    let intervalDays: Int
    let anchorDate: Date
}

enum HabitIntervalScheduleStore {
    private static let storageKey = "habitIntervalSchedules"

    static func interval(for habit: Habit) -> HabitIntervalSchedule? {
        let uri = habit.objectID.uriRepresentation().absoluteString
        return load()[uri]
    }

    static func setInterval(for habit: Habit, intervalDays: Int, anchorDate: Date) {
        guard intervalDays > 1 else {
            clearInterval(for: habit)
            return
        }
        let uri = habit.objectID.uriRepresentation().absoluteString
        var map = load()
        map[uri] = HabitIntervalSchedule(intervalDays: intervalDays, anchorDate: anchorDate)
        save(map)
    }

    static func clearInterval(for habit: Habit) {
        let uri = habit.objectID.uriRepresentation().absoluteString
        var map = load()
        map.removeValue(forKey: uri)
        save(map)
    }

    private static func load() -> [String: HabitIntervalSchedule] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let map = try? JSONDecoder().decode([String: HabitIntervalSchedule].self, from: data)
        else {
            return [:]
        }
        return map
    }

    private static func save(_ map: [String: HabitIntervalSchedule]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum HabitScheduleResolver {
    static func existsOnOrBefore(habit: Habit, date: Date, calendar: Calendar = .current) -> Bool {
        guard let createdAt = habit.timestamp else { return true }
        return calendar.startOfDay(for: createdAt) <= calendar.startOfDay(for: date)
    }

    static func isActive(habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        guard existsOnOrBefore(habit: habit, date: date, calendar: calendar) else {
            return false
        }

        if let interval = HabitIntervalScheduleStore.interval(for: habit), interval.intervalDays > 1 {
            let start = calendar.startOfDay(for: interval.anchorDate)
            let current = calendar.startOfDay(for: date)
            let delta = calendar.dateComponents([.day], from: start, to: current).day ?? 0
            if delta < 0 { return false }
            return delta % interval.intervalDays == 0
        }

        let mask = habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask
        return HabitSchedule.isActive(on: date, mask: mask)
    }

    static func label(for habit: Habit) -> String {
        if let interval = HabitIntervalScheduleStore.interval(for: habit), interval.intervalDays > 1 {
            return "Every \(interval.intervalDays) days"
        }
        let mask = habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask
        return HabitSchedule.label(for: mask)
    }
}
