import SwiftUI

/// Spec §3.1 · 4 tabs + centre FAB.
/// Custom tab bar replaces `TabView` so that the FAB can sit on top of the glass
/// strip with its own shadow — `TabView.tabItem` can't host a raised button.
struct RootView: View {
    @State private var selectedTab: TabKey = .home
    @State private var showingAddSheet = false
    @State private var showingSmartImport = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground(palette: selectedTab.palette)
                .animation(.easeInOut(duration: 0.45), value: selectedTab)

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
            .padding(.bottom, 2)
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
        case .home:    "house"
        case .bills:   "list.bullet.rectangle"
        case .stats:   "chart.bar.xaxis"
        case .profile: "person.crop.circle"
        }
    }

    var activeIconSystemName: String {
        switch self {
        case .home:    "house.fill"
        case .bills:   "list.bullet.rectangle.fill"
        case .stats:   "chart.bar.xaxis"
        case .profile: "person.crop.circle.fill"
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

    @Namespace private var selectionAnimation

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            cluster(items: [.home, .bills])
            addButton
            cluster(items: [.stats, .profile])
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    @ViewBuilder private func cluster(items: [TabKey]) -> some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { key in
                tabButton(key)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppColors.glassTint)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppColors.glassBorderSoft, lineWidth: 1)
        )
        .shadow(color: AppColors.surfaceShadow, radius: 18, x: 0, y: 10)
    }

    private func tabButton(_ key: TabKey) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selected = key
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected == key ? key.activeIconSystemName : key.iconSystemName)
                    .font(.system(size: 14, weight: selected == key ? .semibold : .medium))
                Text(key.title)
                    .font(.system(size: 11, weight: selected == key ? .semibold : .medium))
            }
            .foregroundStyle(selected == key ? AppColors.ink : AppColors.ink2)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if selected == key {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.56))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "selected-tab", in: selectionAnimation)
                        .shadow(color: AppColors.surfaceShadow.opacity(0.65), radius: 10, x: 0, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.brandStart, AppColors.brandEnd, AppColors.brandAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)
            .shadow(color: AppColors.brandStart.opacity(0.30), radius: 16, x: 0, y: 10)
            .shadow(color: AppColors.surfaceShadowStrong, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("记一笔")
    }
}

// MARK: - Preview

#Preview {
    RootView().environment(AppStore())
}
