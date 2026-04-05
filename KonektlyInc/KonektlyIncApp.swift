//
//  KonektlyIncApp.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    /// Stored FCM token for unregister-on-logout
    static var currentFCMToken: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Push notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("[PUSH] Permission granted: \(granted), error: \(String(describing: error))")
        }
        application.registerForRemoteNotifications()

        // FCM delegate
        Messaging.messaging().delegate = self

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[FIREBASE] APNs token received")
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        print("[FIREBASE] APNs token configured for sandbox")
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        print("[FIREBASE] APNs token configured for production")
        #endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[FIREBASE] APNs registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        // Refresh unread count when a push arrives while app is open
        Task { @MainActor in
            await MessageStore.shared.loadUnreadCount()
            await MessageStore.shared.loadConversations()
        }
        completionHandler(.newData)
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }

    // MARK: - MessagingDelegate (FCM token)

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("[FCM] Token received: \(token.prefix(20))...")
        AppDelegate.currentFCMToken = token

        // Register with backend if authenticated
        if TokenStore.shared.accessToken != nil {
            Task { @MainActor in
                await MessageStore.shared.registerDevice(token: token)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Foreground notification display
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        let notificationType = userInfo["type"] as? String

        // Suppress banner if user is already viewing this conversation
        if notificationType == "new_message" || notificationType == nil,
           let conversationIdStr = userInfo["conversation_id"] as? String,
           let conversationId = UUID(uuidString: conversationIdStr) {
            let currentId = await MainActor.run { MessageStore.shared.currentMessages.first?.conversationId }
            if currentId == conversationId {
                Task { @MainActor in
                    await MessageStore.shared.loadUnreadCount()
                }
                return []
            }
        }

        // new_job: refresh nearby jobs in background so the job is ready when tapped
        if notificationType == "new_job" {
            Task { @MainActor in
                await JobStore.shared.fetchNearbyJobs(forceRefresh: true)
            }
        }

        // Campaign / marketing pushes (custom notification system)
        if let t = notificationType,
           Self.campaignDataTypes.contains(t) {
            Task { @MainActor in
                NotificationCenter.default.post(name: .marketingPushReceived, object: nil)
            }
        }

        return [.banner, .sound, .badge]
    }

    // Notification tap handler — deep link based on push type
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let notificationType = userInfo["type"] as? String

        if notificationType == "new_job",
           let jobIdStr = userInfo["job_id"] as? String,
           let jobId = Int(jobIdStr) {
            await MainActor.run {
                JobStore.shared.pendingDeepLinkJobId = jobId
            }
        } else if let t = notificationType, Self.campaignDataTypes.contains(t) {
            let tid = userInfo["template_id"] as? String ?? (userInfo["template_id"] as? NSNumber).map { String(describing: $0) }
            let cid = userInfo["campaign_id"] as? String ?? (userInfo["campaign_id"] as? NSNumber).map { String(describing: $0) }
            await MainActor.run {
                NotificationRoutingStore.shared.pendingTemplateId = tid
                NotificationRoutingStore.shared.pendingCampaignId = cid
            }
        } else if let conversationIdStr = userInfo["conversation_id"] as? String,
                  let conversationId = UUID(uuidString: conversationIdStr) {
            await MainActor.run {
                MessageStore.shared.pendingDeepLinkConversationId = conversationId
            }
        }
    }

    /// `data.type` from FCM for the notifications app (marketing, transactional, etc.).
    private static let campaignDataTypes: Set<String> = [
        "marketing", "promotional", "re_engagement", "transactional",
        "test_notification",
    ]
}

extension Notification.Name {
    static let marketingPushReceived = Notification.Name("marketingPushReceived")
}

@main
struct KonektlyIncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authStore = AuthStore.shared
    @StateObject private var jobStore = JobStore.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var messageStore = MessageStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authStore)
                .environmentObject(jobStore)
                .environmentObject(locationManager)
                .environmentObject(subscriptionManager)
                .environmentObject(messageStore)
                .environmentObject(NotificationRoutingStore.shared)
                .task {
                    #if DEBUG
                    print("[APP] API: \(Config.apiBaseURL) | WS: \(Config.wsBaseURL) | ENV: \(AppEnvironment.current)")
                    #endif
                    // No UX change: make sure an access token is available if refresh exists.
                    await APIClient.shared.bootstrapTokensIfNeeded()
                    await authStore.bootstrapIfNeeded()

                    // Load unread count on launch if authenticated
                    if authStore.isAuthenticated {
                        await messageStore.loadUnreadCount()
                    }

                    // Register FCM token if we have one
                    if let fcmToken = AppDelegate.currentFCMToken, authStore.isAuthenticated {
                        await messageStore.registerDevice(token: fcmToken)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await subscriptionManager.refreshSubscriptionStatus()
                            if authStore.isAuthenticated {
                                await messageStore.loadUnreadCount()
                                // Reconnect WebSocket if user was in a chat when app went to background
                                messageStore.reconnectIfNeeded()
                            }
                        }
                    }
                }
        }
    }
}
