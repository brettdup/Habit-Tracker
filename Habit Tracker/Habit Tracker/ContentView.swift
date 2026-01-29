import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [], animation: .default) private var habits: FetchedResults<Habit>
    

    var body: some View {
        TabView {
            NavigationView {
                HabitListView()
                    .navigationTitle("Habits")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Habits", systemImage: "list.bullet")
            }
            
            NavigationView {
                HistoryView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("History", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            NavigationView {
                NewHabitView()
                    .navigationTitle("New Habit")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("New Habit", systemImage: "plus.circle.fill")
            }
            
            NavigationView {
                Group {
                    if #available(iOS 18.0, *) {
                        SettingsView()
                    } else {
                        Text("Settings")
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            
            NavigationView {
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









