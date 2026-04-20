import SwiftUI

/// Tap the profile card on ProfileView to edit name / family group name.
/// Writes through AppStore so changes persist to UserDefaults and the
/// profile initial updates everywhere (stat row, menu value, initials circle).
struct EditProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var familyGroupName: String = ""
    @State private var initialized = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    avatarCard
                    nameCard
                    familyCard
                    Spacer().frame(height: 18)
                    saveButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18).padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            guard !initialized else { return }
            name = store.userName
            familyGroupName = store.familyGroupName
            initialized = true
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("编辑资料").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var avatarCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: [AppColors.auroraPink, AppColors.auroraPurple],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "未命名" : name)
                    .font(.system(size: 16, weight: .medium))
                Text("头像首字母会跟着名字首字母自动更新")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("昵称").eyebrowStyle()
            TextField("叫你什么好呢", text: $name)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))
        }
        .padding(14)
        .glassCard()
    }

    private var familyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("家庭账本名称").eyebrowStyle()
            TextField("例如:深圳小窝 / 咱俩的家", text: $familyGroupName)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))
            Text("显示在「家庭账本」菜单右侧,随手改不改都行。")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(14)
        .glassCard()
    }

    private var saveButton: some View {
        Button {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedFamily = familyGroupName.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty { store.userName = trimmedName }
            if !trimmedFamily.isEmpty { store.familyGroupName = trimmedFamily }
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
