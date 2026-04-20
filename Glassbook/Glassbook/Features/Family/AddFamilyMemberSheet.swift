import SwiftUI

/// Add a new family member to the shared book. In the scaffold members live
/// only in-memory; a production integration would open the CloudKit CKShare
/// invite sheet so the invitee receives the shared CloudKit zone.
struct AddFamilyMemberSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var initial = ""
    @State private var role: FamilyMember.Role = .member
    @State private var selectedColor = 0
    @State private var selectedAvatar = "👨"

    private let colors: [UInt32] = [0x3B82F6, 0xEC4899, 0xF59E0B, 0x10B981, 0xC48AFF, 0xFF7A9C]
    private let avatars = ["👨", "👩", "👧", "👦", "👶", "🧑", "👴", "👵"]

    var body: some View {
        ZStack {
            AuroraBackground(palette: .home)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    previewCard
                    nameField
                    avatarRow
                    colorRow
                    roleCard
                    saveButton
                    ckShareHint
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
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
            Text("添加家庭成员").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: colors[selectedColor]))
                    .frame(width: 56, height: 56)
                Text(initial.isEmpty ? String(name.prefix(1)) : String(initial.prefix(1)))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "成员名称" : name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(name.isEmpty ? AppColors.ink3 : AppColors.ink)
                Text(role.displayName).font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Text(selectedAvatar).font(.system(size: 22))
        }
        .padding(16)
        .glassCard()
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名字 · 首字母").eyebrowStyle()
            HStack(spacing: 8) {
                TextField("A", text: $initial)
                    .font(.system(size: 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 52, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
                TextField("Lily / 小朋友 / ...", text: $name)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassCard(radius: 12)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var avatarRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emoji 图标").eyebrowStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(avatars, id: \.self) { emoji in
                        Button { selectedAvatar = emoji } label: {
                            Text(emoji).font(.system(size: 22))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(selectedAvatar == emoji
                                                  ? Color.white.opacity(0.75)
                                                  : Color.white.opacity(0.35))
                                )
                                .overlay(Circle().strokeBorder(
                                    selectedAvatar == emoji ? AppColors.ink : Color.clear,
                                    lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("头像底色").eyebrowStyle()
            HStack(spacing: 8) {
                ForEach(Array(colors.enumerated()), id: \.offset) { idx, hex in
                    Button { selectedColor = idx } label: {
                        Circle().fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(
                                selectedColor == idx ? AppColors.ink : Color.clear,
                                lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var roleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("角色").eyebrowStyle()
            ForEach([FamilyMember.Role.admin, .member, .childPassive], id: \.self) { r in
                Button { role = r } label: {
                    HStack {
                        Text(r.lockEmoji).font(.system(size: 14))
                        Text(r.displayName).font(.system(size: 13, weight: role == r ? .medium : .regular))
                            .foregroundStyle(AppColors.ink)
                        Spacer()
                        if role == r {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .medium))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                if r != .childPassive {
                    Divider().background(AppColors.glassDivider)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("添加成员")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.4 : 1)
    }

    private var ckShareHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud").font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 4) {
                Text("CKShare 邀请 · V1.5").eyebrowStyle()
                Text("当前只在本设备添加占位成员。V1.5 开 CKShare 后会调用苹果原生邀请界面,对方用 iCloud 账号接受即自动同步。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private func save() {
        let letter = initial.isEmpty ? String(name.prefix(1)) : initial
        let m = FamilyMember(
            id: UUID(),
            name: name,
            initial: letter.uppercased(),
            role: role,
            avatarColorHex: colors[selectedColor],
            monthlyContributionCents: 0,
            avatar: selectedAvatar
        )
        store.addFamilyMember(m)
        dismiss()
    }
}

#Preview { AddFamilyMemberSheet().environment(AppStore()) }
