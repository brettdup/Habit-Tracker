import SwiftUI
import CoreData
import UIKit

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("accentColor") private var accentColorRaw = AppAccentColor.blue.rawValue
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showNotificationAlert = false
    @State private var selectedAppIcon = AppIconOption.current
    @State private var iconErrorMessage: String?
    
    private var themeMode: AppThemeMode {
        get { AppThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }
    
    private var accentColor: AppAccentColor {
        get { AppAccentColor(rawValue: accentColorRaw) ?? .blue }
        set { accentColorRaw = newValue.rawValue }
    }
    
    var body: some View {
        AppFormContainer {
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

                AppIconPicker(selection: selectedAppIcon) { option in
                    updateAppIcon(to: option)
                }
            }

            Section(header: Text("Preferences")) {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Enable Notifications", systemImage: "bell.fill")
                }
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
        .onChange(of: notificationsEnabled) { _, enabled in
            HabitReminderScheduler.updateGlobalNotifications(enabled: enabled, in: viewContext) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        showNotificationAlert = true
                    }
                }
            }
        }
        .alert("Notifications Unavailable", isPresented: $showNotificationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications in iOS Settings before turning reminders back on.")
        }
        .alert("Icon Unavailable", isPresented: Binding(
            get: { iconErrorMessage != nil },
            set: { if !$0 { iconErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(iconErrorMessage ?? "The app icon could not be changed.")
        }
        .onAppear(perform: syncSelectedAppIcon)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncSelectedAppIcon()
            }
        }
    }

    private func syncSelectedAppIcon() {
        selectedAppIcon = AppIconOption(iconName: UIApplication.shared.alternateIconName)
    }

    private func updateAppIcon(to option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconErrorMessage = "This device does not support alternate app icons."
            return
        }

        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                if let error = error {
                    iconErrorMessage = error.localizedDescription
                    syncSelectedAppIcon()
                    return
                }

                selectedAppIcon = option
            }
        }
    }
}

private enum AppIconOption: String, CaseIterable, Identifiable {
    case current
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current:
            return "Classic"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .current:
            return "Original app icon"
        case .light:
            return "Bright planner style"
        case .dark:
            return "High contrast planner style"
        }
    }

    var iconName: String? {
        switch self {
        case .current:
            return nil
        case .light:
            return "AppIconLight"
        case .dark:
            return "AppIconDark"
        }
    }

    var previewAssetName: String {
        switch self {
        case .current:
            return "AppIconOriginalPreview"
        case .light:
            return "AppIconLightPreview"
        case .dark:
            return "AppIconDarkPreview"
        }
    }

    init(iconName: String?) {
        self = Self.allCases.first { $0.iconName == iconName } ?? .current
    }
}

private struct AppIconPicker: View {
    let selection: AppIconOption
    let onSelect: (AppIconOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("App Icon", systemImage: "app.badge")

            HStack(spacing: 12) {
                ForEach(AppIconOption.allCases) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: 8) {
                            Image(option.previewAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(option == selection ? Color.accentColor : Color(.separator), lineWidth: option == selection ? 3 : 1)
                                }

                            Text(option.title)
                                .font(.caption)
                                .fontWeight(option == selection ? .semibold : .regular)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.subtitle)
                    .accessibilityValue(option == selection ? "Selected" : "")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AccentColorPickerView: View {
    @Binding var selection: String

    var body: some View {
        List {
            ForEach(AppAccentColor.allCases, id: \.rawValue) { color in
                Button {
                    selection = color.rawValue
                } label: {
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)
                        Text(color.rawValue)
                            .foregroundStyle(color.color)
                        Spacer()
                        if color.rawValue == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(color.color)
                        }
                    }
                }
            }
        }
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
