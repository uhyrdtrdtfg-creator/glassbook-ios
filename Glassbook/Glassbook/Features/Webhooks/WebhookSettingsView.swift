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
                        HStack(spacing: 6) {
                            Text(endpoint.platform.displayName)
                            Text("·")
                            Text(endpoint.httpMethod.rawValue)
                            if endpoint.useCustomBody {
                                Text("·")
                                Text("自定义 body")
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                    }
                    Spacer()
                    if !endpoint.isEnabled {
                        Text("已停用")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.5)))
                    }
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
            .opacity(endpoint.isEnabled ? 1 : 0.55)
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
    @State private var showPresets = false
    @State private var showVariables = false
    @State private var showPreview = false

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
            VStack(spacing: 0) {
                sheetHeader
                ScrollView {
                    VStack(spacing: 14) {
                        sectionHeader("基本")
                        basicCard
                        Text("URL 必须 https:// (开发可临时 http://)。")
                            .sectionFootnote()

                        sectionHeader("平台")
                        platformPicker

                        sectionHeader("触发事件")
                        triggersCard

                        sectionHeader("请求格式")
                        requestFormatCard
                        Text(endpoint.useCustomBody
                             ? "打开时用下面的 BODY 模板发送。"
                             : "关掉就用 App 内置 JSON 结构(含 subscription DTO + delivery_id)。")
                            .sectionFootnote()

                        sectionHeader("BODY 模板")
                        bodyTemplateCard

                        actionButtons
                        Spacer().frame(height: 32)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showPresets) {
            PresetPickerSheet { preset in
                endpoint.bodyTemplate = preset.body
                endpoint.useCustomBody = true
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showVariables) {
            VariablesSheet { key in
                endpoint.bodyTemplate += "{{\(key)}}"
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPreview) {
            PreviewSheet(
                method: endpoint.httpMethod,
                contentType: endpoint.useCustomBody
                    ? endpoint.contentType
                    : "application/json; charset=utf-8",
                rendered: WebhookTemplate.render(
                    endpoint.bodyTemplate.isEmpty
                        ? WebhookTemplate.presets.first?.body ?? ""
                        : endpoint.bodyTemplate,
                    context: .sample
                )
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var sheetHeader: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(.system(size: 14))
                .foregroundStyle(AppColors.ink)
            Spacer()
            Text(original.name.isEmpty ? "新建 Webhook" : "编辑 Webhook")
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Button("保存") {
                // Belt-and-suspenders: clear iOS smart quotes / dashes / ellipsis
                // from any structured field before persisting. SmartPunctuation
                // is already disabled globally, but historical text typed on
                // earlier builds may still carry curly quotes that would break
                // JSON bodies on Slack / 飞书 / 钉钉.
                endpoint.url = endpoint.url.normalizingSmartPunctuation()
                endpoint.bodyTemplate = endpoint.bodyTemplate.normalizingSmartPunctuation()
                endpoint.contentType = endpoint.contentType.normalizingSmartPunctuation()
                onSave(endpoint)
                dismiss()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(canSave ? AppColors.ink : AppColors.ink3)
            .disabled(!canSave)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).eyebrowStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    // MARK: - Basic

    private var basicCard: some View {
        VStack(spacing: 0) {
            TextField("名称(如 'Slack 通知')", text: $endpoint.name)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .frame(height: 46)
            Divider().background(AppColors.glassDivider)
            TextField("https://...", text: $endpoint.url)
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 46)
            Divider().background(AppColors.glassDivider)
            Toggle(isOn: $endpoint.isEnabled) {
                Text("启用").font(.system(size: 14))
            }
            .tint(AppColors.ink)
            .padding(.horizontal, 14)
            .frame(height: 46)
        }
        .glassCard(radius: 14)
    }

    // MARK: - Platform / Triggers (kept from previous version)

    private var platformPicker: some View {
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
        .padding(14)
        .glassCard(radius: 14)
    }

    private var triggersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    // MARK: - Request format

    private var requestFormatCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(WebhookStore.HTTPMethod.allCases, id: \.self) { m in
                    Button { endpoint.httpMethod = m } label: {
                        Text(m.rawValue)
                            .font(.system(size: 12,
                                          weight: endpoint.httpMethod == m ? .semibold : .regular))
                            .foregroundStyle(endpoint.httpMethod == m ? .white : AppColors.ink)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(endpoint.httpMethod == m
                                          ? AppColors.ink
                                          : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.45))
            )
            .padding(.horizontal, 10).padding(.top, 10)

            Divider().background(AppColors.glassDivider).padding(.top, 10)

            Toggle(isOn: $endpoint.useCustomBody) {
                Text("使用自定义 body").font(.system(size: 14))
            }
            .tint(AppColors.ink)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .disabled(endpoint.httpMethod == .get)
            .opacity(endpoint.httpMethod == .get ? 0.45 : 1)

            Divider().background(AppColors.glassDivider)

            TextField("application/json; charset=utf-8",
                      text: $endpoint.contentType)
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 46)
                .disabled(!endpoint.useCustomBody || endpoint.httpMethod == .get)
                .opacity((endpoint.useCustomBody && endpoint.httpMethod != .get) ? 1 : 0.55)
        }
        .glassCard(radius: 14)
    }

    // MARK: - Body template

    private var bodyTemplateCard: some View {
        VStack(spacing: 0) {
            Button {
                showPresets = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13))
                    Text("插入预设模板").font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .foregroundStyle(AppColors.ink)
            }
            .buttonStyle(.plain)

            Divider().background(AppColors.glassDivider)

            HStack(spacing: 10) {
                Button { showVariables = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 13))
                        Text("可用变量").font(.system(size: 13))
                    }
                    .foregroundStyle(AppColors.ink)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { showPreview = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye").font(.system(size: 13))
                        Text("预览").font(.system(size: 13))
                    }
                    .foregroundStyle(AppColors.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            Divider().background(AppColors.glassDivider)

            templateEditor
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        }
        .glassCard(radius: 14)
        .opacity(endpoint.useCustomBody && endpoint.httpMethod != .get ? 1 : 0.55)
    }

    private var templateEditor: some View {
        ZStack(alignment: .topLeading) {
            if endpoint.bodyTemplate.isEmpty {
                Text("Body 模板,使用 {{subscription.name}} 这样的占位符…")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink4)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $endpoint.bodyTemplate)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .disabled(!endpoint.useCustomBody || endpoint.httpMethod == .get)
                // Turn off iOS auto-features so a JSON body doesn't get its
                // ASCII " / ' / - silently replaced with curly variants.
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: endpoint.bodyTemplate) { _, new in
                    let cleaned = new.normalizingSmartPunctuation()
                    if cleaned != new { endpoint.bodyTemplate = cleaned }
                }
        }
    }

    // MARK: - Footer

    private var canSave: Bool {
        !endpoint.name.isEmpty && !endpoint.url.isEmpty
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let onDelete {
                Button {
                    onDelete()
                    dismiss()
                } label: {
                    Text("删除此端点")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.expenseRed)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .glassCard(radius: 14)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preset picker

private struct PresetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (WebhookTemplate.Preset) -> Void

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 12) {
                    Text("预设模板").font(.system(size: 16, weight: .medium))
                        .padding(.top, 16)
                    Text("选一个后可继续编辑").font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                    ForEach(WebhookTemplate.presets) { preset in
                        Button {
                            onPick(preset)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.ink)
                                Text(preset.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.ink3)
                                Text(preset.body)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppColors.ink2)
                                    .lineLimit(4)
                                    .padding(.top, 4)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(radius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Variables sheet

private struct VariablesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onInsert: (String) -> Void

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 10) {
                    Text("可用变量").font(.system(size: 16, weight: .medium))
                        .padding(.top, 16)
                    Text("点击插入到光标末尾").font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                    ForEach(WebhookTemplate.knownVariables, id: \.key) { entry in
                        Button {
                            onInsert(entry.key)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Text("{{\(entry.key)}}")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(AppColors.ink)
                                Spacer()
                                Text(entry.example)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.ink3)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .frame(maxWidth: .infinity)
                            .glassCard(radius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Preview sheet

private struct PreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let method: WebhookStore.HTTPMethod
    let contentType: String
    let rendered: String

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("预览").font(.system(size: 16, weight: .medium))
                        Spacer()
                        Button("关闭") { dismiss() }
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.ink)
                    }
                    .padding(.top, 16)

                    HStack(spacing: 6) {
                        Text(method.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.ink))
                            .foregroundStyle(.white)
                        Text(contentType)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppColors.ink3)
                    }

                    Text("样例数据 · title / body / trigger 已填入")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)

                    Text(rendered.isEmpty ? "(空 body)" : rendered)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard(radius: 14)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Style helpers

private extension Text {
    func sectionFootnote() -> some View {
        self
            .font(.system(size: 11))
            .foregroundStyle(AppColors.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}

#Preview {
    WebhookSettingsView()
}
