import SwiftUI
import CoreData
import Combine
import UIKit

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

struct HabitListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(entity: Habit.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]) var habits: FetchedResults<Habit>
    @State private var showAlert = false
    @State private var deletionIndexSet: IndexSet?
    @State private var showAddHabit = false
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .name
    @State private var selectedGroupOption: GroupOption = .none
    @State private var showSortOptions = false
    @State private var showCategoryManagement = false
    
    var filteredHabits: [Habit] {
        let habitsArray = Array(habits)
        let today = Date()
        let activeToday = habitsArray.filter { HabitSchedule.isActive(on: today, mask: $0.activeDaysMask == 0 ? HabitSchedule.allDaysMask : $0.activeDaysMask) }
        let filteredBase = searchText.isEmpty ? activeToday : activeToday.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
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
        guard selectedGroupOption == .category else {
            return ["All": filteredHabits]
        }
        
        var groups: [String: [Habit]] = [:]
        for habit in filteredHabits {
            let category = habit.category?.isEmpty == false ? habit.category! : "Uncategorized"
            if groups[category] == nil {
                groups[category] = []
            }
            groups[category]?.append(habit)
        }
        return groups
    }
    
    var sortedCategoryKeys: [String] {
        groupedHabits.keys.sorted()
    }
    
    var body: some View {
        ZStack {
            // Background gradient - adapts to dark mode
            LinearGradient(gradient: Gradient(colors: [
                colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1),
                colorScheme == .dark ? Color.black : Color.white
            ]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                if habits.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if selectedGroupOption == .category {
                                ForEach(sortedCategoryKeys, id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(category)
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                        
                                        ForEach(groupedHabits[category] ?? [], id: \.self) { habit in
                                            HabitRow(habit: habit, totalHabits: habits.count)
                                                .frame(height: 80)
                                                .transition(.scale)
                                        }
                                    }
                                }
                            } else {
                                ForEach(filteredHabits, id: \.self) { habit in
                                    HabitRow(habit: habit, totalHabits: habits.count)
                                        .frame(height: 80)
                                        .transition(.scale)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .refreshable {
                        resetHabitsIfNewDay()
                    }
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddHabit = true }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search habits"
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                    Image(systemName: "arrow.up.arrow.down")
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
                    Image(systemName: "square.grid.2x2")
                }

                Button {
                    showCategoryManagement = true
                } label: {
                    Image(systemName: "tag")
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            NewHabitView()
        }
        .sheet(isPresented: $showCategoryManagement) {
            CategoryManagementView()
        }
        .onAppear {
            resetHabitsIfNewDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            resetHabitsIfNewDay()
        }
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
    
    // Keep other existing functions unchanged
    private func deleteReminders(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }
        
        let identifier = "habitReminder-\(habit.objectID.uriRepresentation().absoluteString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func resetHabitsIfNewDay() {
        let defaults = UserDefaults.standard
        let lastResetDate = defaults.object(forKey: "LastResetDate") as? Date ?? Date.distantPast
        let currentDate = Date()

        if !Calendar.current.isDate(lastResetDate, inSameDayAs: currentDate) {
            withAnimation {
                for habit in habits {
                    let fetchRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "habitName == %@", habit.name ?? "")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                    fetchRequest.fetchLimit = 1

                    do {
                        let latestCompletionRecords = try viewContext.fetch(fetchRequest)
                        if let latestCompletionRecord = latestCompletionRecords.first,
                           let lastCompletionDate = latestCompletionRecord.date,
                           lastCompletionDate < currentDate {
                            habit.isCompleted = false
                        }
                    } catch {
                        print("Error fetching completion record: \(error.localizedDescription)")
                    }
                }
                
                defaults.set(currentDate, forKey: "LastResetDate")
                
                try? viewContext.save()
            }
        }
    }
}

// Modern Empty State View
struct EmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 70))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
            Text("No Habits Yet")
                .font(.title2.bold())
            Text("Tap the + button to add your first habit")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
    @ObservedObject var habit: Habit
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAlert = false
    @State private var isCheckboxTapped = false
    @State private var isEditing = false
    var totalHabits: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(habit.isCompleted ? 
                    (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                    (colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)))
                .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), 
                       radius: 8, x: 0, y: 2)
            
            HStack(spacing: 16) {
                CheckBox(isChecked: $habit.isCompleted, toggleCompletion: toggleCompletion)
                    .foregroundColor(habit.isCompleted ? .blue : .gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name ?? "")
                        .foregroundColor(habit.isCompleted ? .blue : (colorScheme == .dark ? .white : .primary))
                        .font(.system(size: 17, weight: .medium))
                        .strikethrough(habit.isCompleted)
                        .animation(.easeInOut, value: habit.isCompleted)
                    
                    HStack(spacing: 8) {
                        if let reminderTime = habit.reminderTime {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 10))
                                Text(formatReminderTime(reminderTime))
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(HabitSchedule.label(for: habit.activeDaysMask == 0 ? HabitSchedule.allDaysMask : habit.activeDaysMask))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                        
                        if let category = habit.category, !category.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 10))
                                Text(category)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if habit.priority > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                Text("\(habit.priority)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
        }
        .onTapGesture {
            isEditing = true
        }
        .sheet(isPresented: $isEditing) {
            HabitDetailView(habit: habit, viewContext: viewContext)
        }
    }

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func toggleCompletion() {
        if !habit.isCompleted {
            // Delete corresponding completion record if habit is unticked
            let fetchRequest: NSFetchRequest<HabitCompletionRecord> = HabitCompletionRecord.fetchRequest()
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: Date())
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND habitName == %@", argumentArray: [startDate, endDate, habit.name ?? ""])

            do {
                let records = try viewContext.fetch(fetchRequest)
                print("Found \(records.count) records to delete for habit: \(habit.name ?? "")")
                for record in records {
                    print("Deleting record: \(record)")
                    viewContext.delete(record)
                }
                try viewContext.save()
                print("Records deleted successfully")
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        } else {
            addCompletionRecord(for: habit)
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func addCompletionRecord(for habit: Habit) {
        print(habit)
        let newCompletion = HabitCompletionRecord(context: viewContext)
        newCompletion.date = Calendar.current.startOfDay(for: Date()) // Save only the day portion of the date
        newCompletion.habitName = habit.name
        newCompletion.isCompleted = true
        newCompletion.totalHabits = Int16(totalHabits) // Set totalHabits

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct CheckBox: View {
    @Binding var isChecked: Bool
    var toggleCompletion: () -> Void // Closure to toggle completion state

    var body: some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .resizable()
            .frame(width: 24, height: 24)
            .padding(4)
            .onTapGesture {
                withAnimation(.spring()) {
                    isChecked.toggle()
                    toggleCompletion()
                }
            }
    }
}

struct CategoryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
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
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [
                    colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1),
                    colorScheme == .dark ? Color.black : Color.white
                ]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    if existingCategories.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "tag")
                                .font(.system(size: 70))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                            Text("No Categories Yet")
                                .font(.title2.bold())
                            Text("Categories will appear here as you add them to habits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCategories, id: \.self) { category in
                                    CategoryCard(
                                        name: category,
                                        habitCount: habits.filter { $0.category == category }.count,
                                        tint: tintColor(for: category)
                                    ) {
                                        deleteCategory(named: category)
                                    }
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
                        .background(Color.blue)
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
        let context = PersistenceController.preview.container.viewContext

        // Clear existing sample data
        clearSampleData(in: context)
        // Create sample data
        createSampleData(in: context)

        return Group {
            NavigationView {
                HabitListView()
                    .environment(\.managedObjectContext, context)
            }
            .preferredColorScheme(.light)
            
            NavigationView {
                HabitListView()
                    .environment(\.managedObjectContext, context)
            }
            .preferredColorScheme(.dark)
        }
    }

    private static func clearSampleData(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Habit.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
        } catch {
            print("Failed to clear sample data: \(error)")
        }
    }

    private static func createSampleData(in context: NSManagedObjectContext) {
        for i in 1...5 {
            let habit = Habit(context: context)
            habit.name = "Sample Habit \(i)"
            habit.isCompleted = i % 2 == 0
        }
        do {
            try context.save()
        } catch {
            print("Failed to create sample data: \(error)")
        }
    }
}
