import SwiftUI
import CoreData

@available(iOS 18.0, *)
struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    @AppStorage("resetTime") private var resetTime = Calendar.current.startOfDay(for: Date())
    @Environment(\.colorScheme) private var colorScheme
    
    private var themeMode: AppThemeMode {
        get { AppThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }
    
    private var accentColor: AppAccentColor {
        get { AppAccentColor(rawValue: accentColorRaw) ?? .blue }
        set { accentColorRaw = newValue.rawValue }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Form {
                Section(header: Text("Appearance")) {
                Picker(selection: $themeModeRaw, label: Label("Theme", systemImage: "paintbrush.fill")) {
                    ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                
                Picker(selection: $accentColorRaw, label: Label("Accent Color", systemImage: "paintpalette.fill")) {
                    ForEach(AppAccentColor.allCases, id: \.rawValue) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 20, height: 20)
                            Text(color.rawValue)
                        }
                        .tag(color.rawValue)
                    }
                }
            }
            
            Section(header: Text("Preferences")) {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Enable Notifications", systemImage: "bell.fill")
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
            .scrollContentBackground(.hidden)
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
