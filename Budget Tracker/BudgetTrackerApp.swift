import SwiftUI
import UserNotifications

@main
struct Budget_Tracker: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appearanceMode")   private var appearanceMode:   String = "dark"
    @AppStorage("autoLockDelay")    private var autoLockDelay:    String = "immediately"

    @StateObject private var nav        = NavState()
    @State private var isLocked         = true
    @State private var backgroundedAt: Date? = nil
    @Environment(\.scenePhase) private var scenePhase

    private func lock() {
        isLocked = true
        nav.mainTab = "Home"
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    /// Seconds before the app locks after going to background. nil = lock immediately.
    private var lockDelaySeconds: Double? {
        switch autoLockDelay {
        case "1min":  return 60
        case "5min":  return 300
        default:      return nil   // "immediately"
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(nav)
                    .preferredColorScheme(colorScheme)

                if isLocked {
                    LockView { isLocked = false }
                        .preferredColorScheme(colorScheme)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLocked)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
                if lockDelaySeconds == nil {
                    lock()
                }
            case .active:
                if let delay = lockDelaySeconds,
                   let bg = backgroundedAt,
                   Date().timeIntervalSince(bg) >= delay {
                    lock()
                }
                backgroundedAt = nil
                // Clear app icon badge every time the app becomes active
                UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
            default:
                break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestPermissionAndSchedule()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
