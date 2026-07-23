//
//  Persistence.swift
//  Habit Tracker
//
//  Created by Brett du Plessis on 2024/05/03.
//

import CoreData
import CloudKit
import Combine

enum CloudSyncState: Equatable {
    case checking
    case ready
    case syncing
    case backedUp(Date)
    case restored(Date)
    case noAccount
    case restricted
    case temporarilyUnavailable
    case failed(String)
}

final class CloudSyncMonitor: ObservableObject {
    static let shared = CloudSyncMonitor()

    @Published private(set) var state: CloudSyncState

    private static let lastSuccessfulBackupKey = "cloudKitLastSuccessfulBackup"
    private var eventObserver: NSObjectProtocol?

    private init() {
        if let lastBackup = UserDefaults.standard.object(
            forKey: Self.lastSuccessfulBackupKey
        ) as? Date {
            state = .backedUp(lastBackup)
        } else {
            state = .checking
        }

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }

        refreshAccountStatus()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    func refreshAccountStatus() {
        CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier).accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self else { return }

                switch status {
                case .available:
                    switch self.state {
                    case .checking, .noAccount, .restricted, .temporarilyUnavailable:
                        self.state = .ready
                    default:
                        break
                    }
                case .noAccount:
                    self.state = .noAccount
                case .restricted:
                    self.state = .restricted
                case .temporarilyUnavailable:
                    self.state = .temporarilyUnavailable
                case .couldNotDetermine:
                    self.state = .failed(error?.localizedDescription ?? "iCloud account status could not be determined.")
                @unknown default:
                    self.state = .failed("An unknown iCloud account error occurred.")
                }
            }
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            guard let completedAt = event.endDate else {
                self.state = .syncing
                return
            }

            guard event.succeeded else {
                self.state = .failed(event.error?.localizedDescription ?? "CloudKit sync failed.")
                return
            }

            switch event.type {
            case .export:
                UserDefaults.standard.set(completedAt, forKey: Self.lastSuccessfulBackupKey)
                self.state = .backedUp(completedAt)
            case .import:
                if case .backedUp = self.state {
                    break
                }
                self.state = .restored(completedAt)
            case .setup:
                if case .syncing = self.state {
                    self.state = .ready
                }
            @unknown default:
                break
            }
        }
    }
}

struct PersistenceController {
    static let cloudKitContainerIdentifier = "iCloud.brett.Habit-Tracker"
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let defaults: [(name: String, icon: String, reminderHour: Int?, completed: Bool)] = [
            ("Morning meditation", "brain.head.profile", 7, true),
            ("Read 20 minutes", "book.fill", 21, false),
            ("Exercise", "figure.run", 8, true),
            ("Drink water", "drop.fill", nil, false),
            ("Sleep by 10pm", "bed.double.fill", 22, false)
        ]
        let calendar = Calendar.current
        for (name, icon, hour, completed) in defaults {
            let habit = Habit(context: viewContext)
            habit.name = name
            habit.iconName = icon
            habit.isCompleted = completed
            habit.timestamp = Date()
            if let hour = hour {
                habit.reminderTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
            }
        }
        do {
            try viewContext.save()
        } catch {
            print("Preview data failed to save: \(error.localizedDescription)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer
    let wasLocalStorePresent: Bool

    init(inMemory: Bool = false) {
        if !inMemory {
            _ = CloudSyncMonitor.shared
        }

        container = NSPersistentCloudKitContainer(name: "Habit_Tracker")
        if inMemory {
            wasLocalStorePresent = true
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if let description = container.persistentStoreDescriptions.first {
            wasLocalStorePresent = description.url.map {
                FileManager.default.fileExists(atPath: $0.path)
            } ?? false
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
        } else {
            wasLocalStorePresent = false
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data failed to load persistent store: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
