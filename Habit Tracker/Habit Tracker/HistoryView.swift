import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(entity: HabitCompletionRecord.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]) var completions: FetchedResults<HabitCompletionRecord>
    @State private var refreshTrigger = false
    @State private var showOlderCompletions = false
    @State private var currentDate = Date()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [
                colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1),
                colorScheme == .dark ? Color.black : Color.white
            ]),
                          startPoint: .top,
                          endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Today and Yesterday Section
                    ForEach(groupedCompletionsTodayAndYesterday, id: \.key) { date, completionsInDate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(format(date: date))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(completionsInDate.count)/\(totalHabits(on: date)) completed")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            ForEach(completionsInDate) { completion in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(completion.habitName ?? "")
                                        .font(.body)
                                    Spacer()
                                }
                                .padding()
                                .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                                .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                      removal: .scale.combined(with: .opacity)))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation(.easeInOut) {
                                            viewContext.delete(completion)
                                            do {
                                                try viewContext.save()
                                            } catch {
                                                print("Error deleting record: \(error.localizedDescription)")
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // Older Completions Section
                    DisclosureGroup(
                        content: {
                            ForEach(groupedCompletionsOlder, id: \.key) { date, completionsInDate in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(format(date: date))
                                            .font(.headline)
                                        Spacer()
                                        Text("\(completionsInDate.count)/\(totalHabits(on: date)) completed")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top)
                                    
                                    ForEach(completionsInDate) { completion in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text(completion.habitName ?? "")
                                            Spacer()
                                        }
                                        .padding()
                                        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                                        .cornerRadius(12)
                                        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                              removal: .scale.combined(with: .opacity)))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                withAnimation(.easeInOut) {
                                                    viewContext.delete(completion)
                                                    do {
                                                        try viewContext.save()
                                                    } catch {
                                                        print("Error deleting record: \(error.localizedDescription)")
                                                    }
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        label: {
                            Text("Older Completions")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    )
                    .padding()
                    .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshData()
        }
    }

    private var groupedCompletions: [Date: [HabitCompletionRecord]] {
        Dictionary(grouping: completions, by: { Calendar.current.startOfDay(for: $0.date ?? Date()) })
    }

    private var groupedCompletionsTodayAndYesterday: [(key: Date, value: [HabitCompletionRecord])] {
        groupedCompletions.filter { Calendar.current.isDateInToday($0.key, referenceDate: currentDate) || Calendar.current.isDateInYesterday($0.key, referenceDate: currentDate) }
            .map { ($0.key, $0.value) }
            .sorted(by: { $0.key > $1.key })
    }

    private var groupedCompletionsOlder: [(key: Date, value: [HabitCompletionRecord])] {
        groupedCompletions.filter { !Calendar.current.isDateInToday($0.key, referenceDate: currentDate) && !Calendar.current.isDateInYesterday($0.key, referenceDate: currentDate) }
            .map { ($0.key, $0.value) }
            .sorted(by: { $0.key > $1.key })
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private func format(date: Date) -> String {
        if Calendar.current.isDateInToday(date, referenceDate: currentDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date, referenceDate: currentDate) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: date)
        }
    }

    private func deleteRecords(at offsets: IndexSet, completions: [HabitCompletionRecord]) {
        withAnimation(.easeInOut) {
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
        currentDate = Date()
        refreshTrigger.toggle()
    }
    
    private func totalHabits(on date: Date) -> Int {
        if let record = completions.first(where: { Calendar.current.isDate($0.date ?? Date(), inSameDayAs: date) }) {
            return Int(record.totalHabits)
        }
        return 0
    }
}

extension Calendar {
    func isDateInToday(_ date: Date, referenceDate: Date) -> Bool {
        return self.isDate(date, inSameDayAs: referenceDate)
    }
    
    func isDateInYesterday(_ date: Date, referenceDate: Date) -> Bool {
        guard let yesterday = self.date(byAdding: .day, value: -1, to: referenceDate) else { return false }
        return self.isDate(date, inSameDayAs: yesterday)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HistoryView()
        }
    }
}
