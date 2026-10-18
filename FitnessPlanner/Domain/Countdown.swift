import Foundation
import Observation
import UIKit
import UserNotifications

/// Drives the bottom timer bar: rest between sets, or the work period of a timed set.
/// Time is anchored to an end date, so it stays correct while the phone is locked.
@Observable
final class Countdown {
    enum Kind: Equatable {
        case rest
        case work
    }

    private(set) var kind: Kind = .rest
    private(set) var endDate: Date?
    private(set) var totalSeconds: Int = 0
    private(set) var label: String = ""
    /// The set a work countdown is timing; completed when the countdown runs out.
    private(set) var workSet: LoggedSet?

    private static let notificationID = "fitness-planner.countdown"

    var isActive: Bool { endDate != nil }

    func remaining(at now: Date = .now) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    func progress(at now: Date = .now) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return 1 - Double(remaining(at: now)) / Double(totalSeconds)
    }

    func start(_ kind: Kind, seconds: Int, label: String, workSet: LoggedSet? = nil) {
        guard seconds > 0 else { return }
        self.kind = kind
        self.totalSeconds = seconds
        self.label = label
        self.workSet = workSet
        self.endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        scheduleNotification()
    }

    func adjust(by delta: Int) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(TimeInterval(delta))
        guard newEnd > .now else {
            stop()
            return
        }
        self.endDate = newEnd
        totalSeconds = max(1, totalSeconds + delta)
        scheduleNotification()
    }

    func stop() {
        endDate = nil
        workSet = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    /// Call once a second. Returns true exactly once, when the countdown runs out.
    func tick(now: Date = .now) -> Bool {
        guard let endDate, now >= endDate else { return false }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        return true
    }

    private func scheduleNotification() {
        guard let endDate else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = kind == .rest ? "Rest is over" : "Time's up"
        content.body = kind == .rest ? "Next set: \(label)" : label
        content.sound = .default
        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { center.add(request) }
                }
            case .authorized, .provisional, .ephemeral:
                center.add(request)
            default:
                break
            }
        }
    }
}
