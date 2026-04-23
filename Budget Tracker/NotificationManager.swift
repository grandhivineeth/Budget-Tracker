import UserNotifications
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()

    private let weeklyID  = "weekly_spending_summary"

    private init() {}

    // MARK: - Permission + initial schedule
    func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                guard granted else { return }
                DispatchQueue.main.async {
                    self.scheduleWeeklySummaryIfEnabled()
                }
            }
    }

    // MARK: - Weekly Summary (every Sunday 9 am)
    func scheduleWeeklySummaryIfEnabled() {
        let enabled = UserDefaults.standard.bool(forKey: "weeklyNotificationEnabled")
        guard enabled else {
            cancelWeeklySummary()
            return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let already = pending.contains { $0.identifier == self.weeklyID }
            guard !already else { return }
            DispatchQueue.main.async { self.scheduleWeeklySummary() }
        }
    }

    func scheduleWeeklySummary() {
        cancelWeeklySummary()

        let content       = UNMutableNotificationContent()
        content.title     = "Weekly Spending Summary"
        content.body      = "Check how your spending looked this week — open Budget Tracker."
        content.sound     = .default
        content.badge     = 1

        var comps         = DateComponents()
        comps.weekday     = 1   // Sunday
        comps.hour        = 9
        comps.minute      = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklyID])
    }
}
