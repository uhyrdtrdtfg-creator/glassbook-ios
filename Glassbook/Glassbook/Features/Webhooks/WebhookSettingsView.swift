import SwiftUI

/// Spec v2 §6.2.7 · Device-side Webhook endpoints.
struct WebhookSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = WebhookStore.shared
    @State private var editingEndpoint: WebhookStore.Endpoint?
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    heroCard
                    Text("已配置端点").eyebrowStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4).padding(.top, 4)
                    ForEach(store.endpoints) { endpoint in
                        endpointCard(endpoint)
                    }
                    addButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $editingEndpoint) { endpoint in
            EndpointEditSheet(original: endpoint, onSave: { updated in
                store.update(updated)
            }, onDelete: {
                store.delete(id: endpoint.id)
            })
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddSheet) {
            EndpointEditSheet(
                original: .init(id: UUID(), name: "", url: "",
                                platform: .slack, enabledTriggers: []),
                onSave: { store.add($0) }
            )
            .presentationDetents([.large])
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("Webhook · 设备直出").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设备直出").eyebrowStyle()
            Text("事件发生时,手机 App 直接 POST 到你配置的 URL")
                .font(.system(size: 14, weight: .medium))
            Text("无中转服务器 · 无用户账号 · API Key 走 Keychain")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func endpointCard(_ endpoint: WebhookStore.Endpoint) -> some View {
        Button { editingEndpoint = endpoint } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: endpoint.platform.tintHex))
                        Text(String(endpoint.platform.displayName.prefix(2)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(endpoint.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.ink)
                        Text(endpoint.platform.displayName).font(.system(size: 10))
                            .foregroundStyle(AppColors.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink4)
                }
                Text(endpoint.url)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.ink3)
                    .lineLimit(1)
                if !endpoint.enabledTriggers.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(endpoint.enabledTriggers), id: \.self) { t in
                            Text(t.emoji + " " + t.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppColors.ink2)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.6)))
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 14))
                Text("添加新端点").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassCard(radius: 14)
        }
        .buttonStyle(.plain)
    }
}

private struct EndpointEditSheet: View {
    @State var endpoint: WebhookStore.Endpoint
    var onSave: (WebhookStore.Endpoint) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    private let original: WebhookStore.Endpoint

    init(original: WebhookStore.Endpoint,
         onSave: @escaping (WebhookStore.Endpoint) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.original = original
        self._endpoint = State(initialValue: original)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    Text(original.name.isEmpty ? "新增 Webhook" : "编辑 Webhook")
                        .font(AppFont.h2).padding(.top, 8)
                    platformPicker
                    nameField
                    urlField
                    triggersCard
                    actionButtons
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var platformPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("平台").eyebrowStyle()
            HStack(spacing: 6) {
                ForEach(WebhookStore.Endpoint.Platform.allCases, id: \.self) { p in
                    Button { endpoint.platform = p } label: {
                        Text(p.displayName)
                            .font(.system(size: 11, weight: endpoint.platform == p ? .medium : .regular))
                            .foregroundStyle(endpoint.platform == p ? .white : AppColors.ink)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(endpoint.platform == p
                                          ? Color(hex: p.tintHex)
                                          : Color.white.opacity(0.55))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名称").eyebrowStyle()
            TextField("#fin-alerts · 家庭群", text: $endpoint.name)
                .font(.system(size: 13))
        }
        .padding(14).glassCard(radius: 14)
    }

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Webhook URL").eyebrowStyle()
            TextField("https://hooks.slack.com/…", text: $endpoint.url)
                .font(.system(size: 12, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(14).glassCard(radius: 14)
    }

    private var triggersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("触发事件").eyebrowStyle()
            ForEach(WebhookStore.Trigger.allCases, id: \.self) { t in
                HStack {
                    Text(t.emoji + " " + t.displayName)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { endpoint.enabledTriggers.contains(t) },
                        set: { on in
                            if on { endpoint.enabledTriggers.insert(t) }
                            else { endpoint.enabledTriggers.remove(t) }
                        }
                    ))
                    .labelsHidden()
                    .tint(AppColors.ink)
                }
                if t != WebhookStore.Trigger.allCases.last {
                    Divider().background(AppColors.glassDivider)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onSave(endpoint)
                dismiss()
            } label: {
                Text("保存").font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
            .disabled(endpoint.name.isEmpty || endpoint.url.isEmpty)
            .opacity((endpoint.name.isEmpty || endpoint.url.isEmpty) ? 0.5 : 1)

            if let onDelete {
                Button {
                    onDelete()
                    dismiss()
                } label: {
                    Text("删除此端点")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.expenseRed)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    WebhookSettingsView()
}
