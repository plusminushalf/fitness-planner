import Foundation
import UserNotifications

/// Builds signed with a free Apple ID (Xcode or SideStore) stop launching after 7 days.
/// Reads the expiry from the provisioning profile the signer embedded and schedules
/// a morning reminder for each day left, so it gets reinstalled in time.
enum BuildExpiry {
    private static let notificationPrefix = "fitness-planner.build-expiry."
    private static let reminderHour = 9
    /// The expiry the "reminders are on" notification was last sent for, so each new signing gets one.
    private static let confirmedExpiryKey = "buildExpiry.confirmedExpiry"

    /// When the installed build stops launching; nil without a provisioning
    /// profile (simulator, unsigned builds).
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return expirationDate(fromProfile: data)
    }()

    /// The profile is a signed CMS envelope around a plain XML plist; pull the plist out.
    static func expirationDate(fromProfile data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plist = try? PropertyListSerialization.propertyList(
            from: data.subdata(in: start.lowerBound..<end.upperBound),
            format: nil
        ) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }

    /// Replaces reminders left over from a previous signing. Call whenever the app becomes active.
    static func scheduleReminders(now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(notificationPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            guard let expiry = expirationDate else { return }
            let defaults = UserDefaults.standard
            let isNewSigning = defaults.double(forKey: confirmedExpiryKey) != expiry.timeIntervalSince1970
            var requests = reminders(expiry: expiry, now: now)
            if isNewSigning, !requests.isEmpty {
                requests.append(confirmation(expiry: expiry, now: now))
            }
            center.addIfAllowed(requests) {
                if isNewSigning { defaults.set(expiry.timeIntervalSince1970, forKey: confirmedExpiryKey) }
            }
        }
    }

    /// Delivered right away, so a fresh install shows the reminders are set up.
    private static func confirmation(expiry: Date, now: Date, calendar: Calendar = .current) -> UNNotificationRequest {
        let daysLeft = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiry)
        ).day ?? 0
        let content = UNMutableNotificationContent()
        content.title = "Build reminders are on"
        content.body = "\(expiryPhrase(expiry, daysLeft: daysLeft)) You'll get a reminder at \(reminderHour) AM each day until then."
        content.sound = .default
        return UNNotificationRequest(identifier: notificationPrefix + "confirmation", content: content, trigger: nil)
    }

    /// Lets this file's notifications show as banners while the app is open; others stay hidden.
    static func shouldPresentInForeground(_ identifier: String) -> Bool {
        identifier.hasPrefix(notificationPrefix)
    }

    /// One reminder at `reminderHour` on each day from today until the build expires.
    static func reminders(expiry: Date, now: Date, calendar: Calendar = .current) -> [UNNotificationRequest] {
        let expiryDay = calendar.startOfDay(for: expiry)
        var requests: [UNNotificationRequest] = []
        var day = calendar.startOfDay(for: now)
        while day <= expiryDay {
            if let fireDate = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day),
               fireDate > now, fireDate < expiry {
                let daysLeft = calendar.dateComponents([.day], from: day, to: expiryDay).day ?? 0
                let content = UNMutableNotificationContent()
                content.title = switch daysLeft {
                case 0: "Build expires today"
                case 1: "1 day left on this build"
                default: "\(daysLeft) days left on this build"
                }
                content.body = "\(expiryPhrase(expiry, daysLeft: daysLeft)) Plug in your phone and run it from Xcode again."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
                requests.append(UNNotificationRequest(
                    identifier: notificationPrefix + fireDate.formatted(.iso8601),
                    content: content,
                    trigger: trigger
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return requests
    }

    private static func expiryPhrase(_ expiry: Date, daysLeft: Int) -> String {
        let time = expiry.formatted(date: .omitted, time: .shortened)
        switch daysLeft {
        case 0: return "Fitness Planner stops opening at \(time)."
        case 1: return "Fitness Planner stops opening tomorrow at \(time)."
        default: return "Fitness Planner stops opening \(expiry.formatted(.dateTime.weekday(.wide))) at \(time)."
        }
    }
}

extension UNUserNotificationCenter {
    /// Adds the requests, asking for permission first if it hasn't been decided yet.
    /// `onAdded` runs only if they were actually added.
    func addIfAllowed(_ requests: [UNNotificationRequest], onAdded: (() -> Void)? = nil) {
        guard !requests.isEmpty else { return }
        let add = {
            requests.forEach { self.add($0) }
            onAdded?()
        }
        getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { add() }
                }
            case .authorized, .provisional, .ephemeral:
                add()
            default:
                break
            }
        }
    }
}

/// iOS hides notifications while their app is open unless a delegate opts in.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        BuildExpiry.shouldPresentInForeground(notification.request.identifier) ? [.banner, .sound] : []
    }
}
