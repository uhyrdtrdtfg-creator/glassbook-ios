import SwiftUI

/// Page 3 · Digital Crown amount picker + category list → enqueue for iOS drain.
///
/// The Watch target does not compile `AppStore.swift` (see `project.yml` — only
/// `GlassbookWatch/` + `Glassbook/SharedTypes/` are scanned). So we persist the
/// tap by pushing a `PendingImportQueue.Entry` into the App Group; the iOS app
/// drains it on next foreground via `AppStore.drainPendingImports()`.
struct WatchQuickAddView: View {
    @State private var amountYuan: Double = 28
    @State private var selectedSlug: String = "food"
    @State private var saved = false
    @FocusState private var crownFocused: Bool

    /// Keep name/emoji local — `Category` lives in iOS `Models.swift` which the
    /// Watch target can't see. Slug rawValues mirror `Category.Slug`.
    private let categories: [(slug: String, name: String, emoji: String)] = [
        ("food", "餐饮", "🍜"),
        ("transport", "交通", "🚇"),
        ("shopping", "购物", "🛍"),
        ("entertainment", "娱乐", "🎬"),
        ("home", "居家", "🏠"),
        ("health", "医疗", "💊"),
        ("learning", "学习", "📚"),
        ("kids", "孩子", "🧒"),
        ("other", "其他", "✨"),
    ]

    private var selectedCategory: (slug: String, name: String, emoji: String) {
        categories.first { $0.slug == selectedSlug } ?? categories.last!
    }

    var body: some View {
        VStack(spacing: 8) {
            if saved {
                savedSheet
            } else {
                editSheet
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Edit state

    @ViewBuilder private var editSheet: some View {
        HStack(spacing: 8) {
            Text(selectedCategory.emoji)
                .font(.system(size: 22))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("快速记账")
                    .font(.system(size: 11, weight: .semibold))
                Text(selectedCategory.name)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }

        amountDisplay

        #if !os(watchOS)
        Slider(value: $amountYuan, in: 1...9999, step: 1)
            .tint(Color(red: 0.44, green: 0.67, blue: 1.0))
        #endif

        Text(controlHint)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)

        categoryStrip

        saveButton
    }

    @ViewBuilder private var amountDisplay: some View {
        #if os(watchOS)
        Text("¥\(Int(amountYuan))")
            .font(.system(size: 38, weight: .light).monospacedDigit())
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .focusable(true)
            .focused($crownFocused)
            .digitalCrownRotation(
                $amountYuan,
                from: 0,
                through: 9999,
                by: 1,
                sensitivity: .medium,
                isContinuous: false
            )
            .onAppear { crownFocused = true }
        #else
        Text("¥\(Int(amountYuan))")
            .font(.system(size: 34, weight: .light).monospacedDigit())
        #endif
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.slug) { cat in
                    Button {
                        selectedSlug = cat.slug
                    } label: {
                        VStack(spacing: 2) {
                            Text(cat.emoji)
                                .font(.system(size: 14))
                            Text(cat.name)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(selectedSlug == cat.slug ? .primary : .secondary)
                        }
                        .frame(width: 38, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    selectedSlug == cat.slug
                                        ? Color.white.opacity(0.22)
                                        : Color.white.opacity(0.08)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 48)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("记一笔")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: amountYuan > 0
                                    ? [Color(red: 1.0, green: 0.48, blue: 0.60), Color(red: 0.44, green: 0.67, blue: 1.0)]
                                    : [Color.white.opacity(0.14), Color.white.opacity(0.14)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(amountYuan <= 0)
    }

    // MARK: - Saved sheet

    @ViewBuilder private var savedSheet: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.48, blue: 0.60), Color(red: 0.44, green: 0.67, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            Text("已记一笔")
                .font(.system(size: 12, weight: .semibold))
            Text("¥\(Int(amountYuan)) · \(selectedCategory.name)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                saved = false
                amountYuan = 28
            }
        }
    }

    private var controlHint: String {
        #if os(watchOS)
        return "旋转表冠调整金额"
        #else
        return "拖动滑杆调整金额"
        #endif
    }

    // MARK: - Save

    /// Enqueue into the App Group so iOS drains it into SwiftData on foreground.
    /// `platform` is a free-form tag — drainPendingImports ignores it, only the
    /// merchant/amount/category/timestamp are used.
    private func save() {
        guard amountYuan > 0 else { return }
        let amountCents = Int(amountYuan.rounded()) * 100
        let entry = PendingImportQueue.Entry(
            merchant: selectedCategory.name,
            amountCents: amountCents,
            categorySlug: selectedSlug,
            platform: "watch",
            timestamp: .now
        )
        PendingImportQueue.enqueue(entry)
        saved = true
    }
}
