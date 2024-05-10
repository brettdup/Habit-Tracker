import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [], animation: .default) private var habits: FetchedResults<Habit>

    var body: some View {
        TabView {
            // Habit List View
            NavigationView {
                HabitListView()
                    .navigationTitle("Habits")
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Habits")
            }
            
            // History View
            NavigationView {
                HistoryView()
                    .navigationTitle("History")
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("History")
            }
            
            // New Habit View
            NavigationView {
                NewHabitView()
                    .navigationTitle("New Habit")
            }
            .tabItem {
                Image(systemName: "plus.circle")
                Text("New Habit")
            }
            
            // Settings View
            NavigationView {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            
            
            NavigationView {
                        ScheduledNotificationsView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.clock")
                Text("Reminders")
            }
            
        }
        .background(Color.pink) // Set default background color here

        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return ContentView().environment(\.managedObjectContext, context)
    }
}








