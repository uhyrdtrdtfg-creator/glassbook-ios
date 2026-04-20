import SwiftUI

/// Edit monthly budget total + per-category caps. Opened from the pencil in
/// BudgetView's nav bar.
struct EditBudgetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var monthlyYuan: String = ""
    @State private var perCategoryYuan: [Category.Slug: String] = [:]

    var body: some View {
        ZStack {
            AuroraBackground(palette: .budget)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    totalCard
                    categoryCard
                    saveButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: seedFromStore)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("编辑预算").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每月总预算").eyebrowStyle()
            HStack {
                Text("¥").font(.system(size: 22)).foregroundStyle(AppColors.ink3)
                TextField("6000", text: $monthlyYuan)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .light).monospacedDigit())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard(radius: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类预算").eyebrowStyle()
            ForEach(Category.all, id: \.id) { cat in
                HStack(spacing: 10) {
                    CategoryIconTile(category: cat, size: 30)
                    Text(cat.name).font(.system(size: 13, weight: .medium))
                        .frame(width: 72, alignment: .leading)
                    Spacer()
                    Text("¥").foregroundStyle(AppColors.ink3)
                    TextField(
                        "0",
                        text: Binding(
                            get: { perCategoryYuan[cat.id] ?? "" },
                            set: { perCategoryYuan[cat.id] = $0 }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .frame(width: 100)
                }
                .padding(.vertical, 6)
                if cat.id != Category.all.last?.id {
                    Divider().background(AppColors.glassDivider)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("保存预算")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
    }

    private func seedFromStore() {
        monthlyYuan = "\(store.budget.monthlyTotalCents / 100)"
        perCategoryYuan = Dictionary(uniqueKeysWithValues:
            Category.all.map { cat in
                (cat.id, "\((store.budget.perCategory[cat.id] ?? 0) / 100)")
            }
        )
    }

    private func save() {
        let total = (Double(monthlyYuan) ?? 0) * 100
        var perCat: [Category.Slug: Int] = [:]
        for (slug, text) in perCategoryYuan {
            let cents = Int((Double(text) ?? 0) * 100)
            if cents > 0 { perCat[slug] = cents }
        }
        store.updateBudget(monthlyTotalCents: Int(total), perCategory: perCat)
        dismiss()
    }
}

#Preview { EditBudgetSheet().environment(AppStore()) }
