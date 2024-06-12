import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: HabitCompletionRecord.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]) var completions: FetchedResults<HabitCompletionRecord>
    @State private var refreshTrigger = false


    var body: some View {
        List {
            ForEach(groupedCompletions.sorted(by: { $0.key > $1.key }), id: \.key) { date, completionsInDate in
                Section(header: Text(format(date: date))) {
                    ForEach(completionsInDate) { completion in
                        Text(completion.habitName ?? "")
                    }
                    .onDelete { indexSet in
                        deleteRecords(at: indexSet, completions: completionsInDate)
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
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
