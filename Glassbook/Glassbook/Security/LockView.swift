import SwiftUI

struct LockView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            AuroraBackground(palette: .home)
                .blur(radius: 30)

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient.brand())
                        .frame(width: 92, height: 92)
                        .shadow(color: AppColors.brandStart.opacity(0.35), radius: 20, y: 10)
                    Image(systemName: "faceid")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("Glassbook")
                        .font(.system(size: 28, weight: .light))
                        .tracking(0.5)
                    Text("轻触解锁以查看账户")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink2)
                }

                if let err = lock.lastError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.expenseRed)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    Task { await lock.unlock() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Face ID 解锁")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.ink))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .task {
            // Auto-prompt Face ID as soon as the lock screen appears.
            await lock.unlock()
        }
    }
}

#Preview {
    LockView()
        .environment({ let l = AppLock(); l.skipAuth = true; return l }())
}
