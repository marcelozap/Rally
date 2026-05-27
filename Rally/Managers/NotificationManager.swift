import Foundation
import UIKit
import UserNotifications

/// Manages local and push notifications for engagement and achievements
struct NotificationManager {
    
    /// Request user permission for notifications (call on app launch)
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error:", error)
                return
            }
            print("✅ Notification permission granted:", granted)
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Schedule a daily reminder notification at a specific time
    /// - Parameters:
    ///   - hour: Hour of day (0-23)
    ///   - minute: Minute (0-59)
    ///   - identifier: Unique ID for this notification
    static func scheduleDailyReminder(hour: Int = 9, minute: Int = 0, identifier: String = "daily_reminder") {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Time to play! 🎾"
        content.body = "Complete today's challenges and keep your streak alive!"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = ["type": "daily_reminder"]

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily reminder:", error)
            } else {
                print("✅ Daily reminder scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// Send an achievement notification
    static func notifyAchievementEarned(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Achievement Unlocked!"
        content.body = achievement.title
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = ["type": "achievement", "badgeId": achievement.badgeId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send achievement notification:", error)
            }
        }
    }

    /// Send a challenge completion notification
    static func notifyChallengeCompleted(_ challenge: DailyChallenge) {
        let content = UNMutableNotificationContent()
        content.title = "⭐ Challenge Complete!"
        content.body = "\(challenge.title) — +\(challenge.rewardCoins) coins"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = ["type": "challenge", "challengeId": challenge.challengeId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send challenge notification:", error)
            }
        }
    }

    /// Send a streak milestone notification
    static func notifyStreakMilestone(streak: Int) {
        guard streak > 0 && streak % 7 == 0 else { return } // Every 7 days

        let content = UNMutableNotificationContent()
        content.title = "🔥 \(streak)-Day Streak!"
        content.body = "You're crushing it! Keep it going tomorrow."
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = ["type": "streak_milestone", "streak": streak]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_\(streak)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send streak notification:", error)
            }
        }
    }

    /// Send a streak reset warning if player hasn't played today
    static func scheduleStreakWarning(hour: Int = 22, minute: Int = 0) {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Your streak expires soon! ⚠️"
        content.body = "Play one more game before midnight to keep your streak alive."
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.userInfo = ["type": "streak_warning"]

        let request = UNNotificationRequest(identifier: "streak_warning", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak warning:", error)
            } else {
                print("✅ Streak warning scheduled for \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// Clear all pending notifications
    static func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Clear a specific notification by identifier
    static func clear(_ identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
