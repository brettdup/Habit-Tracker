import Foundation
import Combine

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    @Published private(set) var categories: [String] = []

    private static let userDefaultsKey = "HabitCategories"

    private init() {
        categories = Self.loadFromDefaults()
    }

    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let alreadyExists = categories.contains { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        guard !alreadyExists else { return }

        categories.append(trimmed)
        categories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        Self.saveToDefaults(categories)
    }

    func remove(_ name: String) {
        categories.removeAll { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }
        Self.saveToDefaults(categories)
    }

    private static func loadFromDefaults() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func saveToDefaults(_ categories: [String]) {
        let data = (try? JSONEncoder().encode(categories)) ?? Data()
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

