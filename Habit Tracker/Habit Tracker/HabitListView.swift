import SwiftUI
import CoreData
import Combine
import UIKit
import UserNotifications

private enum HabitPreviewRuntime {
    static var isRunning: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case time = "Reminder Time"
    case priority = "Priority"
    
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .name:
            return [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]
        case .time:
            return [NSSortDescriptor(keyPath: \Habit.reminderTime, ascending: true)]
        case .priority:
            return [NSSortDescriptor(keyPath: \Habit.priority, ascending: false), NSSortDescriptor(keyPath: \Habit.name, ascending: true)]
        }
    }
}

enum GroupOption: String, CaseIterable {
    case none = "None"
    case category = "Category"
}

enum DisplayOption: String, CaseIterable {
    case all = "All"
    case notDone = "Not Done"
}

struct HabitListView: View {
    private static let delayedRemovalInterval: TimeInterval = 3

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: Habit.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]) var habits: FetchedResults<Habit>
    @AppStorage("habitListSortOption") private var selectedSortOptionRaw = SortOption.name.rawValue
    @AppStorage("habitListDisplayOption") private var selectedDisplayOptionRaw = DisplayOption.all.rawValue
    @State private var showAddHabit = false
    @State private var searchText = ""
    @State private var selectedGroupOption: GroupOption = .none
    @State private var showCategoryManagement = false
    @State private var showRandomNudges = false
    @State private var showRemindersImport = false
    @State private var selectedHabitForEditing: Habit?
    @State private var habitPendingDeletion: Habit?
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var delayedVisibleCompletedHabitIDs: [NSManagedObjectID: Date] = [:]

    private var selectedDisplayOption: DisplayOption {
        get { DisplayOption(rawValue: selectedDisplayOptionRaw) ?? .all }
        nonmutating set { selectedDisplayOptionRaw = newValue.rawValue }
    }

    private var selectedSortOption: SortOption {
        get { SortOption(rawValue: selectedSortOptionRaw) ?? .name }
        nonmutating set { selectedSortOptionRaw = newValue.rawValue }
    }
    
    var filteredHabits: [Habit] {
        let habitsArray = Array(habits)
        let visibleOnSelectedDate = habitsArray.filter { HabitScheduleResolver.existsOnOrBefore(habit: $0, date: selectedDate) }
        let activeOnSelectedDate = visibleOnSelectedDate.filter { HabitScheduleResolver.isActive(habit: $0, on: selectedDate) }
        let displayFiltered: [Habit]
        switch selectedDisplayOption {
        case .all:
            displayFiltered = activeOnSelectedDate
        case .notDone:
            let completedHabitIDs = completedHabitObjectIDs(on: selectedDate)
            let delayedVisibleHabitIDs = currentDelayedVisibleCompletedHabitIDs
            displayFiltered = activeOnSelectedDate.filter {
                !completedHabitIDs.contains($0.objectID) || delayedVisibleHabitIDs.contains($0.objectID)
            }
        }
        let filteredBase = searchText.isEmpty ? displayFiltered : displayFiltered.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
        let filtered = filteredBase
        return filtered.sorted(by: { habit1, habit2 in
            switch selectedSortOption {
            case .name:
                return (habit1.name ?? "") < (habit2.name ?? "")
            case .time:
                let time1 = habit1.reminderTime ?? Date.distantFuture
                let time2 = habit2.reminderTime ?? Date.distantFuture
                return time1 < time2
            case .priority:
                if habit1.priority != habit2.priority {
                    return habit1.priority > habit2.priority
                }
                return (habit1.name ?? "") < (habit2.name ?? "")
            }
        })
    }
    
    var groupedHabits: [String: [Habit]] {
        // When sorting by time, group by time of day (Morning, Afternoon, Evening, Night)
        if selectedSortOption == .time {
            var groups: [String: [Habit]] = [:]
            for habit in filteredHabits {
                let timeOfDay = HabitSchedule.TimeOfDay.from(reminderTime: habit.reminderTime)
                let key = timeOfDay.rawValue
                if groups[key] == nil { groups[key] = [] }
                groups[key]?.append(habit)
            }
            return groups
        }
        if selectedGroupOption == .category {
            var groups: [String: [Habit]] = [:]
            for habit in filteredHabits {
                let category = habit.category?.isEmpty == false ? habit.category! : "Uncategorized"
                if groups[category] == nil { groups[category] = [] }
                groups[category]?.append(habit)
            }
            return groups
        }
        return ["All": filteredHabits]
    }
    
    var sortedGroupKeys: [String] {
        if selectedSortOption == .time {
            return HabitSchedule.TimeOfDay.displayOrder
                .filter { (groupedHabits[$0.rawValue]?.isEmpty ?? true) == false }
                .map(\.rawValue)
        }
        return groupedHabits.keys.sorted()
    }

    private var activeHabitsForSelectedDate: [Habit] {
        let habitsArray = Array(habits)
        let visibleOnSelectedDate = habitsArray.filter { HabitScheduleResolver.existsOnOrBefore(habit: $0, date: selectedDate) }
        return visibleOnSelectedDate.filter { HabitScheduleResolver.isActive(habit: $0, on: selectedDate) }
    }

    private func completedHabitObjectIDs(on date: Date) -> Set<NSManagedObjectID> {
        let request: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            nextDay as NSDate
        )

        guard let records = try? viewContext.fetch(request) else {
            return []
        }

        return Set(records.compactMap { $0.habit?.objectID })
    }

    private var currentDelayedVisibleCompletedHabitIDs: Set<NSManagedObjectID> {
        let now = Date()
        return Set(
            delayedVisibleCompletedHabitIDs.compactMap { objectID, expiry in
                expiry > now ? objectID : nil
            }
        )
    }

    private func handleCompletionChange(for habit: Habit, isCompleted: Bool) {
        let objectID = habit.objectID

        if selectedDisplayOption == .notDone && isCompleted {
            let expiry = Date().addingTimeInterval(Self.delayedRemovalInterval)
            delayedVisibleCompletedHabitIDs[objectID] = expiry

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.delayedRemovalInterval) {
                if let currentExpiry = delayedVisibleCompletedHabitIDs[objectID], currentExpiry <= Date() {
                    delayedVisibleCompletedHabitIDs.removeValue(forKey: objectID)
                }
            }
            return
        }

        delayedVisibleCompletedHabitIDs.removeValue(forKey: objectID)
    }
    
    var body: some View {
        AppScreenBackground {
            VStack(spacing: 0) {
                if habits.isEmpty {
                    EmptyStateView(
                        onImportReminders: { showRemindersImport = true },
                        onShowRandomNudges: { showRandomNudges = true }
                    )
                } else {
                    List {
                        dateNavigator
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)

                        if groupedHabits.count > 1 || (groupedHabits.count == 1 && groupedHabits.keys.first != "All") {
                            ForEach(sortedGroupKeys, id: \.self) { groupKey in
                                Section(groupKey) {
                                    ForEach(groupedHabits[groupKey] ?? [], id: \.objectID) { habit in
                                        HabitRow(
                                            habit: habit,
                                            totalHabits: filteredHabits.count,
                                            selectedDate: selectedDate,
                                            onCompletionChange: { isCompleted in
                                                handleCompletionChange(for: habit, isCompleted: isCompleted)
                                            },
                                            onEdit: { selectedHabitForEditing = habit },
                                            onDeleteRequest: { habitPendingDeletion = habit },
                                            onDeleteConfirmRequest: { habitPendingDeletion = habit }
                                        )
                                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                    }
                                }
                            }
                        } else {
                            Section {
                                ForEach(filteredHabits, id: \.objectID) { habit in
                                    HabitRow(
                                        habit: habit,
                                        totalHabits: filteredHabits.count,
                                        selectedDate: selectedDate,
                                        onCompletionChange: { isCompleted in
                                            handleCompletionChange(for: habit, isCompleted: isCompleted)
                                        },
                                        onEdit: { selectedHabitForEditing = habit },
                                        onDeleteRequest: { habitPendingDeletion = habit },
                                        onDeleteConfirmRequest: { habitPendingDeletion = habit }
                                    )
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 0, for: .scrollContent)
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddHabit = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Search habits"
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if !habits.isEmpty {
                displayToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .background(Color(uiColor: .systemGroupedBackground).opacity(0.96))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                }

                if !habits.isEmpty {
                    Menu {
                        Button {
                            showRemindersImport = true
                        } label: {
                            Label("Import From Reminders", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            showRandomNudges = true
                        } label: {
                            Label("Random Nudges", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                Menu {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                selectedSortOption = option
                            } label: {
                                if selectedSortOption == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label("Sort By", systemImage: "arrow.up.arrow.down")
                    }

                    Menu {
                        ForEach(GroupOption.allCases, id: \.self) { option in
                            Button {
                                selectedGroupOption = option
                            } label: {
                                if selectedGroupOption == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label("Group By", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }

                Button {
                    showCategoryManagement = true
                } label: {
                    Image(systemName: "tag")
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            NewHabitView(showsCancelButton: true)
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        .sheet(isPresented: $showRandomNudges) {
            NavigationStack {
                RandomNudgesView()
            }
        }
        .sheet(isPresented: $showRemindersImport) {
            RemindersImportView()
        }
        .sheet(item: $selectedHabitForEditing) { habit in
            HabitDetailView(habit: habit, viewContext: viewContext)
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()

                    Spacer()
                }
                .navigationTitle("Choose Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Habit?", isPresented: deleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                guard let habit = habitPendingDeletion else { return }
                deleteHabit(habit)
                habitPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                habitPendingDeletion = nil
            }
        } message: {
            Text("This will permanently remove this habit and its completion history.")
        }
        .onAppear {
            guard !HabitPreviewRuntime.isRunning else { return }
            HabitDailySyncService.migrateLegacyCompletionRelationships(in: viewContext)
            HabitDailySyncService.syncHabitStates(in: viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard !HabitPreviewRuntime.isRunning else { return }
            HabitDailySyncService.syncHabitStates(in: viewContext)
        }
    }

    @ViewBuilder
    private var displayToggle: some View {
        Picker("Show", selection: Binding(
            get: { selectedDisplayOption },
            set: { selectedDisplayOption = $0 }
        )) {
            ForEach(DisplayOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Show")
    }

    @ViewBuilder
    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button {
                shiftSelectedDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)

            Button {
                showDatePicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(selectedDateTitle)
                        .font(.headline)
                    Text(selectedDateSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                shiftSelectedDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private func shiftSelectedDate(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }

    private var selectedDateTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }
        if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var selectedDateSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateLabel = formatter.string(from: selectedDate)
        let totalCount = activeHabitsForSelectedDate.count
        let completedCount = activeHabitsForSelectedDate.filter { completedHabitObjectIDs(on: selectedDate).contains($0.objectID) }.count

        let summary: String
        switch selectedDisplayOption {
        case .all:
            summary = "\(completedCount)/\(totalCount)"
        case .notDone:
            summary = "\(max(totalCount - completedCount, 0)) left"
        }

        return "\(dateLabel) · \(summary)"
    }

    // Keep existing functions but update deleteHabit to include animation
    public func deleteHabit(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            offsets.forEach { index in
                let habit = habits[index]
                deleteReminders(for: habit)
                viewContext.delete(habit)
            }

            do {
                try viewContext.save()
            } catch {
                print("Error deleting habit: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteReminders(for habit: Habit) {
        HabitReminderScheduler.removeReminders(for: habit)
        HabitIntervalScheduleStore.clearInterval(for: habit)
    }

    private func deleteHabit(_ habit: Habit) {
        do {
            HabitReminderScheduler.removeReminders(for: habit)
            HabitIntervalScheduleStore.clearInterval(for: habit)
            try HabitCompletionStore.deleteAllRecords(for: habit, in: viewContext)
            viewContext.delete(habit)
            try viewContext.save()
        } catch {
            print("Error deleting habit: \(error.localizedDescription)")
        }
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { habitPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    habitPendingDeletion = nil
                }
            }
        )
    }
}

// Modern Empty State View
struct EmptyStateView: View {
    let onImportReminders: () -> Void
    let onShowRandomNudges: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label("No Habits Yet", systemImage: "checklist")
            } description: {
                Text("Add a habit, import repeating reminders, or use random nudges.")
            }

            VStack(spacing: 12) {
                Button(action: onImportReminders) {
                    Label("Import From Reminders", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onShowRandomNudges) {
                    Label("Random Nudges", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Modern Search Bar
struct SearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search habits...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
        .cornerRadius(10)
    }
}

// Keep remaining structs (HabitRow, CheckBox, ContentView_Previews) unchanged
struct HabitRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var habit: Habit
    @FetchRequest private var completionRecords: FetchedResults<HabitCompletionRecord>
    var totalHabits: Int
    let selectedDate: Date
    let onCompletionChange: (Bool) -> Void
    let onEdit: () -> Void
    let onDeleteRequest: () -> Void
    let onDeleteConfirmRequest: () -> Void

    init(
        habit: Habit,
        totalHabits: Int,
        selectedDate: Date,
        onCompletionChange: @escaping (Bool) -> Void = { _ in },
        onEdit: @escaping () -> Void,
        onDeleteRequest: @escaping () -> Void,
        onDeleteConfirmRequest: @escaping () -> Void
    ) {
        self.habit = habit
        self.totalHabits = totalHabits
        self.selectedDate = selectedDate
        self.onCompletionChange = onCompletionChange
        self.onEdit = onEdit
        self.onDeleteRequest = onDeleteRequest
        self.onDeleteConfirmRequest = onDeleteConfirmRequest
        _completionRecords = FetchRequest<HabitCompletionRecord>(
            entity: HabitCompletionRecord.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)],
            predicate: NSPredicate(format: "habit == %@", habit)
        )
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                onEdit()
            }
            .contextMenu {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        toggleCompletion()
                    }
                } label: {
                    Label(isCompletedOnSelectedDate ? "Undo" : "Complete", systemImage: isCompletedOnSelectedDate ? "arrow.uturn.backward.circle" : "checkmark.circle")
                }

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDeleteConfirmRequest()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        toggleCompletion()
                    }
                } label: {
                    Label(isCompletedOnSelectedDate ? "Undo" : "Complete", systemImage: isCompletedOnSelectedDate ? "arrow.uturn.backward.circle" : "checkmark.circle")
                }
                .tint(.accentColor)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.accentColor)
            }
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 16) {
            CheckBox(isChecked: isCompletedOnSelectedDate, toggleCompletion: toggleCompletion)
                .foregroundColor(isCompletedOnSelectedDate ? Color.accentColor : .secondary)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name ?? "")
                    .foregroundColor(.primary.opacity(isCompletedOnSelectedDate ? 0.82 : 1))
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .strikethrough(isCompletedOnSelectedDate, color: .secondary.opacity(0.7))
                    .animation(.easeInOut(duration: 0.25), value: isCompletedOnSelectedDate)

                VStack(alignment: .leading, spacing: 4) {
                    if habit.reminderTime == nil, currentStreak > 0 {
                        HStack(spacing: 10) {
                            metadataLine(icon: "repeat", text: scheduleLabel, color: .secondary)
                            metadataLine(icon: "flame.fill", text: "\(currentStreak)d", color: .accentColor)
                        }
                    } else {
                        metadataLine(icon: "repeat", text: scheduleLabel, color: .secondary)
                    }

                    reminderAndStreakLine

                    metadataSummaryLine
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
    }

    private var isCompletedOnSelectedDate: Bool {
        let selectedDay = Calendar.current.startOfDay(for: selectedDate)
        return completionRecords.contains {
            guard let date = $0.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDay)
        }
    }

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func metadataLine(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(isCompletedOnSelectedDate ? color.opacity(0.85) : color)
    }

    private var scheduleLabel: String {
        HabitScheduleResolver.label(for: habit)
    }

    private var currentStreak: Int {
        let completionDates = completionRecords.compactMap(\.date)
        let mask = habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask
        return HabitStreakCalculator.currentStreak(
            completionDates: completionDates,
            activeDaysMask: mask
        )
    }

    @ViewBuilder
    private var reminderAndStreakLine: some View {
        if let reminderTime = habit.reminderTime {
            HStack(spacing: 10) {
                metadataLine(icon: "bell.fill", text: formatReminderTime(reminderTime), color: .secondary)

                if currentStreak > 0 {
                    metadataLine(icon: "flame.fill", text: "\(currentStreak)d", color: .accentColor)
                }
            }
            .frame(height: 16, alignment: .leading)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var metadataSummaryLine: some View {
        if habit.priority > 0 {
            metadataLine(icon: "star.fill", text: "\(habit.priority)", color: .orange)
                .frame(height: 16, alignment: .leading)
        }
    }
    
    private func toggleCompletion() {
        if isCompletedOnSelectedDate {
            do {
                try HabitCompletionStore.setCompleted(false, for: habit, totalHabits: Int16(totalHabits), on: selectedDate, in: viewContext)
                onCompletionChange(false)
            } catch {
                print("Error removing completion record: \(error.localizedDescription)")
            }
        } else {
            do {
                try HabitCompletionStore.setCompleted(true, for: habit, totalHabits: Int16(totalHabits), on: selectedDate, in: viewContext)
                onCompletionChange(true)
            } catch {
                print("Error saving habit completion: \(error.localizedDescription)")
            }
        }
    }
}

struct CheckBox: View {
    let isChecked: Bool
    var toggleCompletion: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                toggleCompletion()
            }
        } label: {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct CategoryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @FetchRequest(entity: Habit.entity(), sortDescriptors: []) var habits: FetchedResults<Habit>
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var newCategoryName = ""
    @State private var showAddCategory = false
    @State private var searchText = ""
    
    private var existingCategories: [String] { categoryStore.categories }
    
    private var filteredCategories: [String] {
        let all = existingCategories
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            AppScreenBackground {
                VStack(spacing: 0) {
                    if existingCategories.isEmpty {
                        ContentUnavailableView {
                            Label("No Categories Yet", systemImage: "tag")
                        } description: {
                            Text("Categories will appear here as you add them to habits.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCategories, id: \.self) { category in
                                    NavigationLink(destination: CategoryHabitsView(categoryName: category)) {
                                        CategoryCard(
                                            name: category,
                                            habitCount: habits.filter { $0.category == category }.count,
                                            tint: tintColor(for: category)
                                        ) {
                                            deleteCategory(named: category)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showAddCategory = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Category")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search categories"
            )
            .alert("Add Category", isPresented: $showAddCategory) {
                TextField("Category name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Add") {
                    categoryStore.add(newCategoryName)
                    newCategoryName = ""
                }
            } message: {
                Text("Enter a name for the new category")
            }
        }
    }

    private func deleteCategory(named category: String) {
        // Clear category on any habits using it (avoids “ghost” categories)
        for habit in habits where habit.category == category {
            habit.category = nil
        }
        categoryStore.remove(category)
        try? viewContext.save()
    }
    
    private func tintColor(for category: String) -> Color {
        // Stable tint color per category name
        let hash = abs(category.lowercased().hashValue)
        let palette: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        return palette[hash % palette.count]
    }
}

struct CategoryHabitsView: View {
    let categoryName: String
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var habits: FetchedResults<Habit>
    @State private var selectedHabitForEditing: Habit?
    @State private var habitPendingDeletion: Habit?
    
    init(categoryName: String) {
        self.categoryName = categoryName
        _habits = FetchRequest<Habit>(
            entity: Habit.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)],
            predicate: NSPredicate(format: "category == %@", categoryName)
        )
    }
    
    var body: some View {
        AppScreenBackground {
            if habits.isEmpty {
                ContentUnavailableView {
                    Label("No Habits in \(categoryName)", systemImage: "list.bullet")
                } description: {
                    Text("Add habits and assign them to this category.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(Array(habits), id: \.objectID) { habit in
                            HabitRow(
                                habit: habit,
                                totalHabits: habits.count,
                                selectedDate: Date(),
                                onEdit: { selectedHabitForEditing = habit },
                                onDeleteRequest: { habitPendingDeletion = habit },
                                onDeleteConfirmRequest: { habitPendingDeletion = habit }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedHabitForEditing) { habit in
            HabitDetailView(habit: habit, viewContext: viewContext)
        }
        .alert("Delete Habit?", isPresented: deleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                guard let habit = habitPendingDeletion else { return }
                deleteHabit(habit)
                habitPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                habitPendingDeletion = nil
            }
        } message: {
            Text("This will permanently remove this habit and its completion history.")
        }
    }

    private func deleteHabit(_ habit: Habit) {
        do {
            HabitReminderScheduler.removeReminders(for: habit)
            HabitIntervalScheduleStore.clearInterval(for: habit)
            try HabitCompletionStore.deleteAllRecords(for: habit, in: viewContext)
            viewContext.delete(habit)
            try viewContext.save()
        } catch {
            print("Error deleting habit: \(error.localizedDescription)")
        }
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { habitPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    habitPendingDeletion = nil
                }
            }
        )
    }
}

private struct CategoryCard: View {
    let name: String
    let habitCount: Int
    let tint: Color
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "tag.fill")
                        .foregroundStyle(tint)
                        .font(.system(size: 18, weight: .semibold))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(habitCount == 1 ? "1 habit" : "\(habitCount) habits")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(habitCount)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(uiColor: .systemGray6) : Color(uiColor: .systemBackground))
                .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Category", systemImage: "trash")
            }
        }
        .alert("Delete Category?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This will remove the category from all habits that use it.")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let controller = makePreviewController()
        let context = controller.container.viewContext

        return Group {
            NavigationStack {
                HabitListView()
                    .environment(\.managedObjectContext, context)
            }
            .preferredColorScheme(.light)
            
            NavigationStack {
                HabitListView()
                    .environment(\.managedObjectContext, context)
            }
            .preferredColorScheme(.dark)
        }
    }

    private static func makePreviewController() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        createSampleData(in: controller.container.viewContext)
        return controller
    }

    private static func createSampleData(in context: NSManagedObjectContext) {
        let defaults: [(name: String, icon: String, reminderHour: Int?, completed: Bool)] = [
            ("Morning meditation", "brain.head.profile", 7, true),
            ("Read 20 minutes", "book.fill", 21, false),
            ("Exercise", "figure.run", 8, true),
            ("Drink water", "drop.fill", nil, false),
            ("Sleep by 10pm", "bed.double.fill", 22, false)
        ]
        let calendar = Calendar.current
        for (name, icon, hour, completed) in defaults {
            let habit = Habit(context: context)
            habit.name = name
            habit.iconName = icon
            habit.isCompleted = completed
            habit.timestamp = Date()
            if let hour = hour {
                habit.reminderTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
            }
        }
        do {
            try context.save()
        } catch {
            print("Failed to create sample data: \(error)")
        }
    }
}
