import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: HabitCompletionRecord.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]) var completions: FetchedResults<HabitCompletionRecord>
    @State private var refreshTrigger = false
    @State private var showOlderCompletions = false

    var body: some View {
        List {
            ForEach(groupedCompletionsTodayAndYesterday, id: \.key) { date, completionsInDate in
                Section(header: HStack {
                    Text(format(date: date))
                    Spacer()
                    Text("\(completionsInDate.count)/\(totalHabits(on: date)) completed")
                }) {
                    ForEach(completionsInDate) { completion in
                        Text(completion.habitName ?? "")
                    }
                    .onDelete { indexSet in
                        deleteRecords(at: indexSet, completions: completionsInDate)
                    }
                }
            }
            
            DisclosureGroup("Older Completions", isExpanded: $showOlderCompletions) {
                ForEach(groupedCompletionsOlder, id: \.key) { date, completionsInDate in
                    Section(header: HStack {
                        Text(format(date: date))
                        Spacer()
                        Text("\(completionsInDate.count)/\(totalHabits(on: date)) completed")
                    }) {
                        ForEach(completionsInDate) { completion in
                            Text(completion.habitName ?? "")
                        }
                        .onDelete { indexSet in
                            deleteRecords(at: indexSet, completions: completionsInDate)
                        }
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("History")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("Opened in the background - HISTORY")
            refreshData()
            print("applicationDidBecomeActive")
        }
    }

    private var groupedCompletions: [Date: [HabitCompletionRecord]] {
        Dictionary(grouping: completions, by: { Calendar.current.startOfDay(for: $0.date ?? Date()) })
    }

    private var groupedCompletionsTodayAndYesterday: [(key: Date, value: [HabitCompletionRecord])] {
        groupedCompletions.filter { Calendar.current.isDateInToday($0.key) || Calendar.current.isDateInYesterday($0.key) }
            .map { ($0.key, $0.value) }
            .sorted(by: { $0.key > $1.key })
    }

    private var groupedCompletionsOlder: [(key: Date, value: [HabitCompletionRecord])] {
        groupedCompletions.filter { !Calendar.current.isDateInToday($0.key) && !Calendar.current.isDateInYesterday($0.key) }
            .map { ($0.key, $0.value) }
            .sorted(by: { $0.key > $1.key })
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private func format(date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }

    private func deleteRecords(at offsets: IndexSet, completions: [HabitCompletionRecord]) {
        withAnimation {
            offsets.forEach { index in
                let completion = completions[index]
                viewContext.delete(completion)
            }
            do {
                try viewContext.save()
            } catch {
                print("Error deleting records: \(error.localizedDescription)")
            }
        }
    }

    private func refreshData() {
        // Toggle the state variable to refresh the view
        print("refreshed")
        refreshTrigger.toggle()
    }
    
    private func totalHabits(on date: Date) -> Int {
        // Find a completion record for the given date and return the totalHabits value
        if let record = completions.first(where: { Calendar.current.isDate($0.date ?? Date(), inSameDayAs: date) }) {
            return Int(record.totalHabits)
        }
        return 0
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
