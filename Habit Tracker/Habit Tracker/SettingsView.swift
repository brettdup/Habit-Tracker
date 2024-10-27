import SwiftUI
import CoreData

@available(iOS 18.0, *)
struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("resetTime") private var resetTime = Calendar.current.startOfDay(for: Date())
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Enable Notifications", systemImage: "bell.fill")
                }
                
                Toggle(isOn: $darkModeEnabled) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
                
                DatePicker(
                    "Daily Reset Time",
                    selection: $resetTime,
                    displayedComponents: .hourAndMinute
                )
            }
            
            Section(header: Text("About")) {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                
                Link(destination: URL(string: "https://www.example.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
                
                Link(destination: URL(string: "https://www.example.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        SettingsView()
    } else {
        // Fallback on earlier versions
    }
}
