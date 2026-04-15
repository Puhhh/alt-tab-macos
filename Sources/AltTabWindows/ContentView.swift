import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            permissionCard
            instructionCard
            footer
        }
        .padding(24)
        .frame(width: 520, height: 360, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("AltTab")
                    .font(.system(size: 24, weight: .semibold))

                Text("Window switcher for macOS with real window focus")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: controller.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(controller.accessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill((controller.accessibilityGranted ? Color.green : Color.orange).opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Access")
                        .font(.system(size: 13, weight: .semibold))

                    Text(controller.permissionStatusDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(controller.permissionStatusTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill((controller.accessibilityGranted ? Color.green : Color.orange).opacity(0.16))
                    )
                    .foregroundStyle(controller.accessibilityGranted ? Color.green : Color.orange)
            }

            HStack(spacing: 10) {
                Button("Open System Settings") {
                    controller.requestAccessibilityAccess()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    controller.refreshPermissionStatus()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.system(size: 13, weight: .semibold))

            instructionRow(number: "1", text: "Grant Accessibility access in System Settings.")
            instructionRow(number: "2", text: "Leave AltTab running in the background.")
            instructionRow(number: "3", text: "Hold Option and press Tab to cycle windows, then release Option to focus the selected one.")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(controller.shortcutDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(controller.hotKeyErrorMessage == nil ? Color.primary : Color.orange)

            Text("Press Esc while the switcher is visible to cancel without changing windows.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                )

            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
