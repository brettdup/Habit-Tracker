import SwiftUI
import CoreData
import Combine
import UIKit

struct HabitListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(entity: Habit.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Habit.name, ascending: true)]) var habits: FetchedResults<Habit>
    @State private var showAlert = false
    @State private var deletionIndexSet: IndexSet?
    @State private var showAddHabit = false
    @State private var searchText = ""
    
    var filteredHabits: [Habit] {
        if searchText.isEmpty {
            return Array(habits)
        }
        return habits.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
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
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top)
                
                if habits.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredHabits, id: \.self) { habit in
                                HabitRow(habit: habit, totalHabits: habits.count)
                                    .frame(height: 80)
                                    .transition(.scale)
                            }
                            .alert(isPresented: $showAlert) {
                                Alert(
                                    title: Text("Delete Habit"),
                                    message: Text("Are you sure you want to delete this habit? This action cannot be undone."),
                                    primaryButton: .destructive(Text("Delete")) {
                                        withAnimation {
                                            deleteHabit(at: deletionIndexSet!)
                                        }
                                    },
                                    secondaryButton: .cancel()
                                )
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
        .sheet(isPresented: $showAddHabit) {
            NewHabitView()
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
                
                Text(habit.name ?? "")
                    .foregroundColor(habit.isCompleted ? .blue : (colorScheme == .dark ? .white : .primary))
                    .font(.system(size: 17, weight: .medium))
                    .strikethrough(habit.isCompleted)
                    .animation(.easeInOut, value: habit.isCompleted)
                
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
