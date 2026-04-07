import SwiftUI

struct AppScreenBackground<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            content
        }
    }
}

struct AppFormContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppScreenBackground {
            Form {
                content
            }
            .scrollContentBackground(.hidden)
        }
    }
}

struct AppListContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        AppScreenBackground {
            List {
                content
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }
}

