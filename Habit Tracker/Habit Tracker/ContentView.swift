import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [], animation: .default) private var habits: FetchedResults<Habit>
    

    var body: some View {
        TabView {
            NavigationStack {
                HabitListView()
                    .navigationTitle("Habits")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Habits", systemImage: "list.bullet")
            }
            
            NavigationStack {
                HistoryView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("History", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            NavigationStack {
                NewHabitView()
                    .navigationTitle("New Habit")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("New Habit", systemImage: "plus.circle.fill")
            }
            
            NavigationStack {
                SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            
            NavigationStack {
                ScheduledNotificationsView()
                    .navigationTitle("Reminders")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Reminders", systemImage: "bell.badge.fill")
            }
            
        }
    }
}







