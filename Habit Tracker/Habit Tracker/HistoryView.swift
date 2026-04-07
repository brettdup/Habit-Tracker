import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: HabitCompletionRecord.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \HabitCompletionRecord.date, ascending: false)]) var completions: FetchedResults<HabitCompletionRecord>
    @State private var refreshTrigger = false
    @State private var showOlderCompletions = false
    @State private var currentDate = Date()
    @State private var recordPendingDeletion: HabitCompletionRecord?
    @State private var showDeleteAlert = false

    var body: some View {
        AppListContainer {
            Section {
                HistoryDotsSection(
                    days: recentDaySummaries,
                    title: "Consistency",
                    subtitle: "Last 35 days"
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }

            ForEach(groupedCompletionsTodayAndYesterday, id: \.key) { date, completionsInDate in
                Section {
                    ForEach(completionsInDate) { completion in
                        historyRow(for: completion)
                    }
                } header: {
                    historySectionHeader(for: date, count: completionsInDate.count)
                }
            }

            if !groupedCompletionsOlder.isEmpty {
                Section("Older Completions") {
                    ForEach(groupedCompletionsOlder, id: \.key) { date, completionsInDate in
                        DisclosureGroup {
                            ForEach(completionsInDate) { completion in
                                historyRow(for: completion)
                            }
                        } label: {
                            HStack {
                                Text(format(date: date))
                                Spacer()
                                Text("\(completionsInDate.count)/\(totalHabits(on: date))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshData()
        }
        .alert("Delete completion record?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePendingRecord()
            }
            Button("Cancel", role: .cancel) {
                recordPendingDeletion = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var groupedCompletions: [Date: [HabitCompletionRecord]] {
        Dictionary(grouping: completions, by: { Calendar.current.startOfDay(for: $0.date ?? Date()) })
    }

    private var recentDaySummaries: [HistoryDaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)

        return (0..<35).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let records = groupedCompletions[date] ?? []
            let completed = records.count
            let total = totalHabits(on: date)
            return HistoryDaySummary(date: date, completedCount: completed, totalCount: total)
        }
        .reversed()
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

    private func deletePendingRecord() {
        guard let recordPendingDeletion else { return }
        withAnimation(.easeInOut) {
            viewContext.delete(recordPendingDeletion)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting record: \(error.localizedDescription)")
            }
        }
        self.recordPendingDeletion = nil
    }
    
    private func totalHabits(on date: Date) -> Int {
        if let record = completions.first(where: { Calendar.current.isDate($0.date ?? Date(), inSameDayAs: date) }) {
            return Int(record.totalHabits)
        }
        return 0
    }

    @ViewBuilder
    private func historyRow(for completion: HabitCompletionRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
            Text(completion.habit?.name ?? completion.habitName ?? "")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                recordPendingDeletion = completion
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func historySectionHeader(for date: Date, count: Int) -> some View {
        HStack {
            Text(format(date: date))
                .font(.title3.weight(.semibold))
            Spacer()
            Text("\(count)/\(totalHabits(on: date)) completed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct HistoryDaySummary: Identifiable {
    let date: Date
    let completedCount: Int
    let totalCount: Int

    var id: Date { date }

    var completionRatio: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }

    var hasActivity: Bool {
        completedCount > 0 || totalCount > 0
    }
}

struct HistoryDotsSection: View {
    let days: [HistoryDaySummary]
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summaryLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(dotFill(for: day))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.7), lineWidth: day.hasActivity ? 0.6 : 0)
                            )
                            .shadow(
                                color: day.completionRatio > 0.66 ? Color.accentColor.opacity(colorScheme == .dark ? 0.45 : 0.18) : .clear,
                                radius: 6,
                                x: 0,
                                y: 2
                            )
                        Text(dayLetter(for: day.date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: day))
                }
            }

            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(legendColor(for: index))
                        .frame(width: 10, height: 10)
                }

                Text("More")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private var summaryLabel: String {
        let activeDays = days.filter(\.hasActivity).count
        let perfectDays = days.filter { $0.totalCount > 0 && $0.completedCount >= $0.totalCount }.count
        return "\(activeDays) tracked • \(perfectDays) perfect"
    }

    private func dotFill(for day: HistoryDaySummary) -> Color {
        guard day.hasActivity else {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        }

        switch day.completionRatio {
        case 0:
            return Color.accentColor.opacity(0.18)
        case 0..<0.34:
            return Color.accentColor.opacity(0.38)
        case 0..<0.67:
            return Color.accentColor.opacity(0.62)
        default:
            return Color.accentColor
        }
    }

    private func legendColor(for index: Int) -> Color {
        switch index {
        case 0:
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
        case 1:
            return Color.accentColor.opacity(0.25)
        case 2:
            return Color.accentColor.opacity(0.55)
        default:
            return Color.accentColor
        }
    }

    private func dayLetter(for date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date)
        let symbols = Calendar.current.veryShortWeekdaySymbols
        guard symbols.indices.contains(index - 1) else { return "" }
        return symbols[index - 1]
    }

    private func accessibilityLabel(for day: HistoryDaySummary) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if day.totalCount == 0 {
            return "\(formatter.string(from: day.date)), no tracked habits"
        }
        return "\(formatter.string(from: day.date)), completed \(day.completedCount) of \(day.totalCount) habits"
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
        NavigationStack {
            HistoryView()
        }
    }
}
