import SwiftUI

/// Spec v2 · AI 财务顾问 · 多轮对话. Plays through BYO LLM when configured,
/// falls back to deterministic local answers otherwise.
struct AdvisorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var service: AdvisorChatService?
    @State private var input: String = ""
    @FocusState private var inputFocused: Bool
    @Bindable private var engineStore = AIEngineStore.shared

    var body: some View {
        ZStack {
            AuroraBackground(palette: .importBlue)

            VStack(spacing: 0) {
                header
                messagesScroll
                suggestionStrip
                inputBar
            }
        }
        .onAppear {
            if service == nil { service = AdvisorChatService(store: store) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text("问账").font(.system(size: 16, weight: .medium))
                Text("by \(engineStore.selected.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Circle().fill(LinearGradient.brand())
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: "sparkles")
                    .foregroundStyle(.white).font(.system(size: 13)))
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    if let service {
                        ForEach(service.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        if service.isThinking {
                            thinkingIndicator
                        }
                    }
                    Spacer().frame(height: 10)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
            .onChange(of: service?.messages.count ?? 0) { _, _ in
                if let last = service?.messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private func messageBubble(_ msg: AdvisorChatService.Message) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.role == .assistant {
                Text("✨").font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(LinearGradient.brand()))
                    .foregroundStyle(.white)
            } else { Spacer(minLength: 40) }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 6) {
                if let tool = msg.toolName {
                    toolCallBlock(name: tool, result: msg.toolResult ?? "")
                }
                Text(.init(msg.content))
                    .font(.system(size: 13))
                    .foregroundStyle(msg.role == .user ? .white : AppColors.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        msg.role == .user
                          ? AnyShapeStyle(AppColors.ink)
                          : AnyShapeStyle(Color.white.opacity(0.7))
                    )
                    .clipShape(BubbleShape(isUser: msg.role == .user))
                    .overlay(
                        BubbleShape(isUser: msg.role == .user)
                            .stroke(AppColors.glassBorder, lineWidth: msg.role == .user ? 0 : 1)
                    )
            }
            if msg.role == .user {
                Text("R").font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(LinearGradient(
                        colors: [AppColors.auroraPink, AppColors.auroraPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .foregroundStyle(.white)
            } else {
                Spacer(minLength: 40)
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            Text("✨").font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(Circle().fill(LinearGradient.brand()))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(AppColors.ink2).frame(width: 6, height: 6)
                        .modifier(BounceDelayModifier(delay: Double(i) * 0.15))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white.opacity(0.7))
            .clipShape(BubbleShape(isUser: false))
            .overlay(BubbleShape(isUser: false).stroke(AppColors.glassBorder, lineWidth: 1))
            Spacer()
        }
    }

    private func toolCallBlock(name: String, result: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TOOL · \(name)")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: 0xE5C07B))
                .tracking(1.0)
            Text(result)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: 0xA5E7A5))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: 0x0F1020))
        )
    }

    // MARK: - Suggestion strip

    private let suggestions: [String] = [
        "这个月我吃饭花了多少?",
        "预算还剩多少?",
        "有哪些订阅建议取消?",
        "本月消费和上月比呢?",
    ]

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        Task { await service?.send(userInput: s) }
                    } label: {
                        Text(s).font(.system(size: 11))
                            .foregroundStyle(AppColors.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(Color.white.opacity(0.6)))
                            .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack {
                TextField("问一个关于你账本的问题…", text: $input, axis: .horizontal)
                    .font(.system(size: 13))
                    .focused($inputFocused)
                    .onSubmit { submit() }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard(radius: 14)
            Button { submit() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(input.isEmpty ? AppColors.ink3 : AppColors.ink)
            }
            .disabled(input.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private func submit() {
        let text = input
        input = ""
        Task { await service?.send(userInput: text) }
    }
}

// MARK: - Bubble shape

private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let tailRadius: CGFloat = 4
        return Path { p in
            p.addRoundedRect(in: rect,
                             cornerSize: .init(width: r, height: r),
                             style: .continuous)
            // Pinch the bottom corner on the speaker's side.
            let cornerRect = CGRect(
                x: isUser ? rect.maxX - tailRadius - 4 : rect.minX,
                y: rect.maxY - tailRadius - 4,
                width: tailRadius + 4, height: tailRadius + 4
            )
            p.addRect(cornerRect)
        }
    }
}

private struct BounceDelayModifier: ViewModifier {
    let delay: Double
    @State private var up = false
    func body(content: Content) -> some View {
        content.offset(y: up ? -4 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever().delay(delay)) {
                    up = true
                }
            }
    }
}

#Preview {
    AdvisorView().environment(AppStore())
}
