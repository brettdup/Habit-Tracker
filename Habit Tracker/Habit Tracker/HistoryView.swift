import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: HabitCompletionRecord.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]) var completions: FetchedResults<HabitCompletionRecord>

    var body: some View {
        List {
            ForEach(groupedCompletions.sorted(by: { $0.key > $1.key }), id: \.key) { date, completionsInDate in
                Section(header: Text(dateFormatter.string(from: date))) {
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
    }

    private var groupedCompletions: [Date: [HabitCompletionRecord]] {
        Dictionary(grouping: completions, by: { Calendar.current.startOfDay(for: $0.date ?? Date()) })
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
    
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
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
