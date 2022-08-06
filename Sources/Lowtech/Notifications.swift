import UserNotifications

public func notify(identifier: String, title: String, body: String) {
    let sendNotification = { (nc: UNUserNotificationCenter) in
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        nc.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil),
            withCompletionHandler: nil
        )
    }

    let nc = UNUserNotificationCenter.current()
    nc.getNotificationSettings { settings in
        mainAsync {
            let enabled = settings.alertSetting == .enabled
            guard enabled else {
                nc.requestAuthorization(options: [], completionHandler: { granted, _ in
                    guard granted else { return }
                    sendNotification(nc)
                })
                return
            }
            sendNotification(nc)
        }
    }
}

public func removeNotifications(withIdentifiers ids: [String]) {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
}
