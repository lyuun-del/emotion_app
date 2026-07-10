import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @EnvironmentObject private var healthStore: WatchHealthStore
    @State private var page: WatchPage = .island

    var body: some View {
        ZStack {
            switch page {
            case .island:
                islandHome
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .dashboard:
                healthDashboard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await healthStore.requestAccessAndRefresh()
        }
    }

    private var islandHome: some View {
        GeometryReader { geometry in
            ZStack {
                Image("WatchIsland")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: (geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom) / 2 - geometry.safeAreaInsets.top
                    )
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        .black.opacity(0.02),
                        .black.opacity(0.02),
                        .black.opacity(0.18),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Button {
                    openDashboard()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("健康数据")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .liquidGlassBackground(Capsule(), tint: .white.opacity(0.12))
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.82)
            }
        }
        .ignoresSafeArea()
    }

    private var healthDashboard: some View {
        GeometryReader { geometry in
            ZStack {
                blurredIslandBackground

                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        ZStack {
                            Text("MoodLand")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)

                            HStack {
                                Button {
                                    closeDashboard()
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .bold))
                                        .frame(width: 27, height: 27)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white.opacity(0.92))
                                .liquidGlassBackground(
                                    Circle(),
                                    tint: .white.opacity(0.10)
                                )
                                .accessibilityLabel("返回岛屿主页")

                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 8)

                        pressureCircle

                        HStack(spacing: 10) {
                            metricCard(
                                title: "心率",
                                value: healthStore.heartRate.map { "\(Int($0.rounded()))" } ?? "--",
                                unit: "次/分",
                                tint: .red
                            )

                            metricCard(
                                title: "HRV",
                                value: healthStore.hrv.map { "\(Int($0.rounded()))" } ?? "--",
                                unit: "ms",
                                tint: .mint
                            )
                        }

                        Button {
                            Task { await healthStore.refresh() }
                        } label: {
                            Label(
                                healthStore.isLoading ? "同步中" : "同步数据",
                                systemImage: healthStore.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                            )
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .liquidGlassButtonTint()
                        .foregroundStyle(.white)
                        .disabled(healthStore.isLoading)

                        statusCard

                        dataHintCard

                        Color.clear.frame(height: max(54, geometry.size.height * 0.18))
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .contentMargins(.vertical, 0, for: .scrollContent)
                .defaultScrollAnchor(.top)
            }
        }
    }

    private var blurredIslandBackground: some View {
        ZStack {
            Color(red: 0.36, green: 0.52, blue: 0.51)
                .ignoresSafeArea()

            Image("WatchIsland")
                .resizable()
                .scaledToFill()
                .blur(radius: 24)
                .saturation(0.74)
                .brightness(-0.14)
                .scaleEffect(1.16)
                .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.52)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.04),
                    .black.opacity(0.18),
                    .black.opacity(0.34),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var pressureCircle: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.10, green: 0.27, blue: 0.28).opacity(0.72))

            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 14)
                .padding(15)

            Circle()
                .stroke(.cyan.opacity(0.52), lineWidth: 2)

            Circle()
                .trim(from: 0, to: max(0.02, CGFloat(healthStore.stress ?? 0) / 100))
                .stroke(
                    pressureColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(8)

            VStack(spacing: 8) {
                Text(healthStore.stress.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                Text("压力值")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(width: 162, height: 162)
        .shadow(color: .cyan.opacity(0.18), radius: 10, y: 3)
    }

    private func metricCard(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))

            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.68)

            Text(unit)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity, minHeight: 108)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 28, style: .continuous),
            tint: tint.opacity(0.14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.55), lineWidth: 1.2)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 9) {
            Image(systemName: healthStore.statusIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.12), in: Circle())

            Text(healthStore.status)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: .white.opacity(0.10)
        )
    }

    private var dataHintCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("数据浏览")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("上下滑动查看压力、心率、HRV 与同步状态。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: .cyan.opacity(0.10)
        )
    }

    private var pressureColor: Color {
        guard let stress = healthStore.stress else { return .white.opacity(0.62) }
        switch stress {
        case ..<35: return .green
        case ..<55: return .yellow
        case ..<75: return .orange
        default: return .red
        }
    }

    private func openDashboard() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            page = .dashboard
        }
    }

    private func closeDashboard() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            page = .island
        }
    }

}

private enum WatchPage {
    case island
    case dashboard
}

private extension View {
    @ViewBuilder
    func liquidGlassBackground<S: Shape>(_ shape: S, tint: Color) -> some View {
        if #available(watchOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint), in: shape)
                .background(.white.opacity(0.08), in: shape)
        } else {
            self
                .background(.ultraThinMaterial.opacity(0.78), in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func liquidGlassButtonTint() -> some View {
        if #available(watchOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.tint(.cyan)
        }
    }
}
