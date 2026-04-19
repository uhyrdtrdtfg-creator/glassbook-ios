import SwiftUI

/// Spec §3.1 · 4 tabs + centre FAB.
/// Custom tab bar replaces `TabView` so that the FAB can sit on top of the glass
/// strip with its own shadow — `TabView.tabItem` can't host a raised button.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: TabKey = .home
    @State private var showingAddSheet = false
    @State private var showingSmartImport = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Aurora behind everything, keyed to selected tab.
            AuroraBackground(palette: selectedTab.palette)
                .animation(.easeInOut(duration: 0.45), value: selectedTab)

            // Current page
            Group {
                switch selectedTab {
                case .home:     HomeView()
                case .bills:    BillsView()
                case .stats:    StatsView()
                case .profile:  ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selected: $selectedTab) {
                showingAddSheet = true
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionView(onPresentSmartImport: {
                showingAddSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showingSmartImport = true
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingSmartImport) {
            SmartImportFlow(isPresented: $showingSmartImport)
        }
    }
}

// MARK: - Tab keys

enum TabKey: String, Hashable, CaseIterable {
    case home, bills, stats, profile
    var title: String {
        switch self {
        case .home: "首页"
        case .bills: "账单"
        case .stats: "统计"
        case .profile: "我的"
        }
    }
    var iconSystemName: String {
        switch self {
        case .home:    "circle.fill"
        case .bills:   "list.bullet"
        case .stats:   "chart.pie"
        case .profile: "person.circle"
        }
    }
    var palette: AuroraPalette {
        switch self {
        case .home:    .home
        case .bills:   .bills
        case .stats:   .stats
        case .profile: .profile
        }
    }
}

// MARK: - TabBar

struct TabBar: View {
    @Binding var selected: TabKey
    var onAdd: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            segment(items: [.home, .bills])

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppColors.ink)
                    )
                    .shadow(color: AppColors.ink.opacity(0.38), radius: 14, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("记一笔")

            segment(items: [.stats, .profile])
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder private func segment(items: [TabKey]) -> some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { key in
                Button {
                    selected = key
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: key.iconSystemName)
                            .font(.system(size: 15, weight: selected == key ? .medium : .regular))
                            .foregroundStyle(selected == key ? AppColors.ink : AppColors.ink3)
                        Text(key.title)
                            .font(.system(size: 10, weight: selected == key ? .medium : .regular))
                            .foregroundStyle(selected == key ? AppColors.ink : AppColors.ink3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 52)
        .glassCard(radius: 18)
    }
}

// MARK: - Preview

#Preview {
    RootView().environment(AppStore())
}
