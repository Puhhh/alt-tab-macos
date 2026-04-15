import SwiftUI

struct SwitcherPanelView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(controller.visibleWindows.enumerated()), id: \.element.id) { index, entry in
                            SwitcherCardView(
                                entry: entry,
                                selected: index == controller.selectedIndex
                            )
                            .id(entry.id)
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    scrollSelection(with: proxy)
                }
                .onChange(of: controller.selectedIndex) { _, _ in
                    scrollSelection(with: proxy)
                }
                .onChange(of: controller.visibleWindows.map(\.id)) { _, _ in
                    scrollSelection(with: proxy)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scrollSelection(with proxy: ScrollViewProxy) {
        guard controller.visibleWindows.indices.contains(controller.selectedIndex) else { return }
        let selectedID = controller.visibleWindows[controller.selectedIndex].id

        withAnimation(.easeOut(duration: 0.14)) {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }
}

private struct SwitcherCardView: View {
    let entry: WindowEntry
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                iconView

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(entry.appName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(selected ? 0.22 : 0.14),
                                Color.white.opacity(selected ? 0.08 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)

                VStack(alignment: .leading, spacing: 6) {
                    Spacer()

                    Text(selected ? "Release Option to switch" : "Visible window")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(Int(entry.frame.width)) x \(Int(entry.frame.height))")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(12)
            }
            .frame(height: 68)
        }
        .padding(16)
        .frame(width: 210, height: 132)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.06), lineWidth: selected ? 2 : 1)
        )
        .scaleEffect(selected ? 1.03 : 1.0)
        .shadow(color: Color.black.opacity(selected ? 0.24 : 0.14), radius: selected ? 20 : 12, y: selected ? 8 : 5)
        .opacity(selected ? 1.0 : 0.92)
        .animation(.easeOut(duration: 0.14), value: selected)
    }

    private var iconView: some View {
        Group {
            if let icon = entry.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "macwindow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var cardFillColor: Color {
        if selected {
            return Color(nsColor: .controlBackgroundColor).opacity(0.94)
        }

        return Color.black.opacity(0.16)
    }
}
