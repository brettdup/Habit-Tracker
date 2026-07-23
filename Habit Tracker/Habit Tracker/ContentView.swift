import SwiftUI
import CoreData

struct ContentView: View {
    var shouldCheckForRestoreOnLaunch = false

    @FetchRequest(sortDescriptors: [], animation: .default) private var habits: FetchedResults<Habit>
    @ObservedObject private var cloudSyncMonitor = CloudSyncMonitor.shared
    @State private var hasCheckedLocalStore = false
    @State private var shouldShowRestoreCheck = false

    var body: some View {
        ZStack {
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

            if shouldShowRestoreCheck {
                CloudRestoreView(
                    state: cloudSyncMonitor.state,
                    restoredHabitCount: habits.count,
                    onRetry: cloudSyncMonitor.refreshAccountStatus,
                    onContinue: {
                        withAnimation {
                            shouldShowRestoreCheck = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            guard !hasCheckedLocalStore else { return }
            hasCheckedLocalStore = true
            shouldShowRestoreCheck = shouldCheckForRestoreOnLaunch
        }
    }
}

private struct CloudRestoreView: View {
    let state: CloudSyncState
    let restoredHabitCount: Int
    let onRetry: () -> Void
    let onContinue: () -> Void

    @State private var allowContinueWhileChecking = false

    private var backupWasFound: Bool {
        restoredHabitCount > 0
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: backupWasFound ? "icloud.and.arrow.down.fill" : statusIcon)
                    .font(.system(size: 58))
                    .foregroundStyle(backupWasFound ? Color.accentColor : statusColor)
                    .symbolEffect(.pulse, isActive: isChecking)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if isChecking && !backupWasFound {
                    ProgressView()
                }

                VStack(spacing: 12) {
                    if backupWasFound {
                        Button("Restore Backup", action: onContinue)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    } else if canRetry {
                        Button("Check Again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }

                    if canContinue {
                        Button("Continue Without Restore", action: onContinue)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 520)
        }
        .task {
            try? await Task.sleep(for: .seconds(12))
            allowContinueWhileChecking = true
        }
        .accessibilityElement(children: .contain)
    }

    private var isChecking: Bool {
        switch state {
        case .checking, .ready, .syncing, .backedUp:
            return true
        default:
            return false
        }
    }

    private var canRetry: Bool {
        switch state {
        case .noAccount, .restricted, .temporarilyUnavailable, .failed:
            return true
        case .restored where !backupWasFound:
            return true
        default:
            return false
        }
    }

    private var canContinue: Bool {
        guard !backupWasFound else { return false }
        return allowContinueWhileChecking || !isChecking
    }

    private var title: String {
        if backupWasFound {
            return "iCloud Backup Found"
        }

        switch state {
        case .checking, .ready, .syncing, .backedUp:
            return "Checking iCloud Backup"
        case .restored:
            return "No Backup Found"
        case .noAccount:
            return "Sign In to iCloud"
        case .restricted:
            return "iCloud Is Restricted"
        case .temporarilyUnavailable:
            return "iCloud Is Unavailable"
        case .failed:
            return "Unable to Check Backup"
        }
    }

    private var message: String {
        if backupWasFound {
            let noun = restoredHabitCount == 1 ? "habit is" : "habits are"
            return "\(restoredHabitCount) \(noun) ready to restore from iCloud."
        }

        switch state {
        case .checking, .ready, .syncing, .backedUp:
            return "Please keep the app open while Habit Tracker checks CloudKit for your habits and completion history."
        case .restored:
            return "CloudKit completed its restore check but did not return any habits."
        case .noAccount:
            return "Sign in to the same iCloud account that was used to back up your habits, then check again."
        case .restricted:
            return "This device does not currently allow access to iCloud."
        case .temporarilyUnavailable:
            return "CloudKit is temporarily unavailable. You can check again shortly."
        case .failed(let error):
            return error
        }
    }

    private var statusIcon: String {
        switch state {
        case .noAccount:
            return "person.crop.circle.badge.exclamationmark"
        case .restricted, .temporarilyUnavailable, .failed:
            return "exclamationmark.icloud.fill"
        case .restored:
            return "icloud.slash.fill"
        default:
            return "icloud.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .restricted, .temporarilyUnavailable, .failed:
            return .orange
        default:
            return .accentColor
        }
    }
}





