import SwiftUI
import UserNotifications

// MARK: - Notifications Settings View
// Manages notification preferences and permissions for the Oxford Pronunciation App.
// Pushed via NavigationLink from AccountSheetView — inherits parent NavigationStack.

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Persisted Settings
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("dailyReminderTime") private var dailyReminderTimeInterval: Double = 32400 // 9:00 AM

    // MARK: - State
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var selectedTime = Date(timeIntervalSince1970: 32400) // 9:00 AM default

    var body: some View {
        List {
            // ── Permission Status ─────────────────────────────
            permissionStatusSection

            // ── Daily Reminder Toggle ─────────────────────────
            remindersSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
        .onAppear {
            checkNotificationPermissionStatus()
            syncTimeFromStorage()
        }
        .onChange(of: dailyReminderEnabled) { newValue in
            handleReminderToggleChange(to: newValue)
        }
        .onChange(of: selectedTime) { newValue in
            updateReminderTime(to: newValue)
        }
    }

    // MARK: - Permission Status Section

    private var permissionStatusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    Image(systemName: permissionStatusIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(permissionStatusColor)

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Notification Status")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(permissionStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Open Settings button (shown only when denied)
                if notificationPermissionStatus == .denied {
                    Button(action: openAppSettings) {
                        HStack {
                            Spacer()
                            Text("Open Settings")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.blue)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        Section(header: Text("Daily Reminder")) {
            // ── Daily Reminder Toggle ──────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(systemName: "bell.fill", color: .red)

                Toggle(isOn: $dailyReminderEnabled) {
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Daily Reminder")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Get motivated to learn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            // ── Time Picker (shown when enabled) ──────────────────
            if dailyReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .accessibilityLabel("Select reminder time")
            }
        }
    }

    // MARK: - Permission Status Helpers

    private var permissionStatusIcon: String {
        switch notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "circle"
        @unknown default:
            return "circle"
        }
    }

    private var permissionStatusColor: Color {
        switch notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }

    private var permissionStatusMessage: String {
        switch notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are enabled"
        case .denied:
            return "Notifications are blocked. Enable in Settings to receive reminders."
        case .notDetermined:
            return "Turn on Daily Reminder to enable notifications"
        @unknown default:
            return "Unknown status"
        }
    }

    // MARK: - Notification Management

    private func checkNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }

    private func handleReminderToggleChange(to enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        } else {
            cancelAllNotifications()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                checkNotificationPermissionStatus()

                if granted {
                    scheduleOrUpdateNotification(for: selectedTime)
                } else {
                    dailyReminderEnabled = false
                }
            }
        }
    }

    private func updateReminderTime(to newTime: Date) {
        dailyReminderTimeInterval = newTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)

        if dailyReminderEnabled {
            scheduleOrUpdateNotification(for: newTime)
        }
    }

    private func scheduleOrUpdateNotification(for time: Date) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminderNotification"])

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let content = UNMutableNotificationContent()
        content.title = "Time to Learn"
        content.body = "Time to learn some new words! 📚"
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.userInfo = ["notificationType": "dailyReminder"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "dailyReminderNotification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminderNotification"])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func syncTimeFromStorage() {
        let seconds = dailyReminderTimeInterval.truncatingRemainder(dividingBy: 86400)
        selectedTime = Date(timeIntervalSince1970: seconds)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
