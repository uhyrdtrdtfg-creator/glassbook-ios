import SwiftUI

/// Spec v2 §6.1.4 · AI 引擎 (BYO LLM).
/// Mirrors the advanced-features HTML Diagram 04 layout: top section highlights
/// the on-device default, below lists user-provided engines with per-engine
/// detail drill-in.
struct AIEngineSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = AIEngineStore.shared
    @State private var selectedForDetail: AIEngineStore.Engine?

    // PhoneClaw 自检状态 — 按测试按钮后更新, 成功/失败都回显在卡片里.
    @State private var phoneClawTesting: Bool = false
    @State private var phoneClawTestLog: String = ""
    @State private var phoneClawTestIsError: Bool = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .stats)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    onDeviceCard
                    phoneClawCard
                    Text("接入自己的模型 (Pro)")
                        .eyebrowStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    ForEach([AIEngineStore.Engine.openAI, .claude, .gemini, .ollama, .custom], id: \.self) { engine in
                        engineRow(engine)
                    }
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selectedForDetail) { engine in
            EngineDetailSheet(engine: engine)
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
            Text("AI 引擎").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var onDeviceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: AIEngineStore.Engine.appleIntelligence.tintHex))
                Text("🍎").font(.system(size: 18))
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Intelligence")
                    .font(.system(size: 13, weight: .medium))
                Text("on-device · 默认 · 免费 · 0 网络依赖")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            if store.selected == .appleIntelligence {
                Text("当前").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.incomeGreen))
            } else {
                Button("切换") { store.selectEngine(.appleIntelligence) }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.ink)
            }
        }
        .padding(16)
        .glassCard()
    }

    /// 第二张本地卡 — 走 phoneclaw:// URL scheme + group.app.glassbook.ios,
    /// Glassbook 这边不抱 MLX 依赖,模型在 PhoneClaw 那边跑完写回 App Group,
    /// 延迟 5-10 秒冷启, 之后同进程秒回。
    /// 带一个"测试连接"按钮 — 问 PhoneClaw 一句最短 prompt, 把成功答复或
    /// 具体错误信息回显在下面的 log 区域, 方便定位 Bundle ID / App Group /
    /// URL scheme 哪一环没配对.
    private var phoneClawCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: AIEngineStore.Engine.phoneclaw.tintHex))
                    Text("🦾").font(.system(size: 18))
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PhoneClaw (本地 Gemma 4)")
                        .font(.system(size: 13, weight: .medium))
                    Text("跨 App · 离线推理 · 需装 PhoneClaw")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                if store.selected == .phoneclaw {
                    Text("当前").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.incomeGreen))
                } else {
                    Button("切换") { store.selectEngine(.phoneclaw) }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await runPhoneClawTest() }
                } label: {
                    HStack(spacing: 6) {
                        if phoneClawTesting {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "wrench.adjustable")
                                .font(.system(size: 10))
                        }
                        Text(phoneClawTesting ? "测试中…" : "测试连接")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.ink.opacity(0.08)))
                    .foregroundStyle(AppColors.ink)
                }
                .disabled(phoneClawTesting)
                .buttonStyle(.plain)

                Spacer()
            }

            if !phoneClawTestLog.isEmpty {
                Text(phoneClawTestLog)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(phoneClawTestIsError ? Color.red : AppColors.incomeGreen)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.ink.opacity(0.04))
                    )
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - PhoneClaw self-test
    //
    // 串行跑三道检查, 任何一道断了就把错误贴在卡片里:
    //   1) App Group 容器是否拿得到 (entitlements + 开发者后台 App Group 注册)
    //   2) canOpenURL("phoneclaw://") 是否通过 (Bundle ID 对 + PhoneClaw 装了
    //      + LSApplicationQueriesSchemes 声明了 phoneclaw)
    //   3) 完整 RPC 回路 (写 req → open phoneclaw:// → PhoneClaw 跑模型 →
    //      写 res → open glassbook:// callback → 解码 res)
    //
    // 用 12 秒超时 (而不是默认 60) — 仅 ping 级别的交互, 等不到说明链路断了
    // 就该停下让用户看错误, 不要让用户干等.
    @MainActor
    private func runPhoneClawTest() async {
        phoneClawTesting = true
        phoneClawTestLog = ""
        phoneClawTestIsError = false
        defer { phoneClawTesting = false }

        var log: [String] = []

        // 1) App Group
        if let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: PhoneClawClient.appGroup) {
            log.append("✓ App Group 容器 OK")
            log.append("  \(container.path)")
        } else {
            log.append("✗ App Group 容器返回 nil")
            log.append("  检查:entitlements 里的 group.app.glassbook.ios,")
            log.append("  以及 developer.apple.com → Identifiers → App Groups")
            log.append("  已注册 group.app.glassbook.ios,且两个 App ID 都勾上了它")
            phoneClawTestLog = log.joined(separator: "\n")
            phoneClawTestIsError = true
            return
        }

        // 2) URL scheme
        if let url = URL(string: "phoneclaw://ask"),
           UIApplication.shared.canOpenURL(url) {
            log.append("✓ phoneclaw:// URL scheme 可响应")
        } else {
            log.append("✗ phoneclaw:// 无响应")
            log.append("  PhoneClaw 没装,或 Bundle ID 还是 com.example.phoneclaw 没改过来")
            phoneClawTestLog = log.joined(separator: "\n")
            phoneClawTestIsError = true
            return
        }

        // 3) 完整 RPC 回路
        log.append("→ 正在请求 PhoneClaw…")
        phoneClawTestLog = log.joined(separator: "\n")

        do {
            let answer = try await PhoneClawClient.ask(
                prompt: "用一个字回答:你好吗",
                timeout: 45
            )
            let snippet = answer.isEmpty ? "(空响应)" : String(answer.prefix(120))
            log.append("✓ 收到回答:\(snippet)")
            phoneClawTestLog = log.joined(separator: "\n")
            phoneClawTestIsError = false
        } catch {
            log.append("✗ \(error.localizedDescription)")
            phoneClawTestLog = log.joined(separator: "\n")
            phoneClawTestIsError = true
        }
    }

    private func engineRow(_ engine: AIEngineStore.Engine) -> some View {
        let cfg = store.config(for: engine)
        return Button {
            selectedForDetail = engine
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: engine.tintHex))
                    Text(engine.emoji).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.displayName).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                    Text(cfg.model.isEmpty ? "未配置" : "\(cfg.model) · \(cfg.connected ? "已连接" : "未激活")")
                        .font(.system(size: 10))
                        .foregroundStyle(cfg.connected ? AppColors.incomeGreen : AppColors.ink3)
                }
                Spacer()
                if store.selected == engine {
                    Text("当前").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.ink))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink4)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

private struct EngineDetailSheet: View {
    let engine: AIEngineStore.Engine
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = AIEngineStore.shared

    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var keyRevealed = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .stats)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    engineHero
                    baseURLCard
                    apiKeyCard
                    modelPickerCard
                    usageCard
                    actionsRow
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .onAppear {
            let cfg = store.config(for: engine)
            baseURL = cfg.baseURL
            model = cfg.model
            apiKey = store.apiKey(for: engine) ?? ""
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("配置 \(engine.displayName)").font(.system(size: 15, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var engineHero: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color(hex: engine.tintHex))
                Text(engine.emoji).font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(engine.displayName).font(.system(size: 15, weight: .medium))
                Text("OpenAI 兼容 Chat Completions · 调用走手机直接出网")
                    .font(.system(size: 10)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var baseURLCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Base URL").eyebrowStyle()
            TextField(engine.defaultBaseURL, text: $baseURL)
                .font(.system(size: 12, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: baseURL) { _, new in store.setBaseURL(new, for: engine) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("API Key").eyebrowStyle()
                Spacer()
                Button { keyRevealed.toggle() } label: {
                    Image(systemName: keyRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            Group {
                if keyRevealed {
                    TextField("sk-…", text: $apiKey)
                } else {
                    SecureField("sk-…", text: $apiKey)
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: apiKey) { _, new in store.setAPIKey(new, for: engine) }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill").font(.system(size: 10))
                Text("存于 iOS Keychain · 不会同步到 iCloud")
                    .font(.system(size: 10))
            }
            .foregroundStyle(AppColors.incomeGreen)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    @ViewBuilder private var modelPickerCard: some View {
        if !engine.defaultModels.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("模型").eyebrowStyle()
                FlowChipRow(items: engine.defaultModels, selected: $model) { picked in
                    store.setModel(picked, for: engine)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 14)
        }
    }

    private var usageCard: some View {
        let cfg = store.config(for: engine)
        return VStack(alignment: .leading, spacing: 6) {
            Text("本月使用").eyebrowStyle()
            Text("\(cfg.monthlyCallCount) 次 · 估算 US$\(String(format: "%.2f", cfg.monthlyCostUSD))")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
            Text("驱动: 自动打标 · 年度回顾 · AI 洞察 · 问账")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button {
                store.selectEngine(engine)
                dismiss()
            } label: {
                Text(store.selected == engine ? "已设为当前" : "设为当前引擎")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
            .disabled(store.selected == engine)
            .opacity(store.selected == engine ? 0.5 : 1)
        }
    }
}

/// Chip row that wraps (FlowLayout) for model pickers / mood chips.
private struct FlowChipRow: View {
    let items: [String]
    @Binding var selected: String
    var onPick: (String) -> Void

    var body: some View {
        WrapLayout(spacing: 6, lineSpacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    selected = item
                    onPick(item)
                } label: {
                    Text(item)
                        .font(.system(size: 11, weight: selected == item ? .medium : .regular))
                        .foregroundStyle(selected == item ? .white : AppColors.ink)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected == item ? AppColors.ink : Color.white.opacity(0.55))
                        )
                        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widthLimit = proposal.width ?? .infinity
        var xCursor: CGFloat = 0
        var yCursor: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if xCursor + size.width > widthLimit {
                xCursor = 0
                yCursor += lineHeight + lineSpacing
                lineHeight = 0
            }
            xCursor += size.width + spacing
            maxX = max(maxX, xCursor)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, widthLimit), height: yCursor + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widthLimit = bounds.width
        var xCursor: CGFloat = bounds.minX
        var yCursor: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if xCursor + size.width > bounds.minX + widthLimit {
                xCursor = bounds.minX
                yCursor += lineHeight + lineSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: xCursor, y: yCursor), proposal: ProposedViewSize(size))
            xCursor += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    AIEngineSettingsView()
}
