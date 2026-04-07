import XCTest
import CoreData
@testable import Habit_Tracker

final class Habit_TrackerTests: XCTestCase {
    private var controller: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
    }

    override func tearDownWithError() throws {
        controller = nil
        context = nil
    }

    func testCompletionStoreUsesHabitRelationship() throws {
        let habit = Habit(context: context)
        habit.name = "Read"
        habit.activeDaysMask = HabitSchedule.allDaysMask
        try context.save()

        try HabitCompletionStore.setCompleted(true, for: habit, totalHabits: 3, on: Date(), in: context)

        let records = try HabitCompletionStore.fetchRecords(for: habit, in: context)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.habit, habit)
        XCTAssertEqual(records.first?.habitName, "Read")
    }

    func testDailySyncResetsIncompleteHabitsWithoutLegacyNameLookups() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 9))!

        let habit = Habit(context: context)
        habit.name = "Exercise"
        habit.activeDaysMask = HabitSchedule.allDaysMask
        habit.isCompleted = true
        try context.save()

        HabitDailySyncService.syncHabitStates(in: context, referenceDate: today, calendar: calendar)

        XCTAssertFalse(habit.isCompleted)
    }
}
