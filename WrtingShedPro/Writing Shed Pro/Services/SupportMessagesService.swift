import Foundation
import Observation

struct SupportMessage: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let body: String
    let createdAt: TimeInterval
    let updatedAt: TimeInterval
    let isCritical: Bool?
    let severity: String?

    var isMarkedCritical: Bool {
        if isCritical == true {
            return true
        }

        if let severity, severity.caseInsensitiveCompare("critical") == .orderedSame {
            return true
        }

        return title.uppercased().hasPrefix("CRITICAL:")
    }
}

private struct SupportMessagesResponse: Codable {
    let messages: [SupportMessage]
}

@Observable
final class SupportMessagesService {
    var isLoading = false
    var messages: [SupportMessage] = []
    var errorMessage: String?

    private let endpoint = URL(string: "https://wsp-support.wsp-support.workers.dev/api/messages")!
    private let hiddenMessageIDsKey = "support.hiddenMessageIDs"
    private let readMessageVersionsKey = "support.readMessageVersions"
    private let alertedMessageVersionsKey = "support.alertedMessageVersions"
    private static let receiveOperatorMessagesKey = "support.receiveOperatorMessages"
    private static let allowCriticalOperatorMessagesWhenOptedOutKey = "support.allowCriticalOperatorMessagesWhenOptedOut"

    private(set) var hiddenMessageIDs: Set<String>
    private(set) var readMessageVersions: [String: TimeInterval]
    private(set) var alertedMessageVersions: [String: TimeInterval]

    init() {
        // Seed explicit defaults on first run.
        if UserDefaults.standard.object(forKey: Self.receiveOperatorMessagesKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.receiveOperatorMessagesKey)
        }
        if UserDefaults.standard.object(forKey: Self.allowCriticalOperatorMessagesWhenOptedOutKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.allowCriticalOperatorMessagesWhenOptedOutKey)
        }

        if let stored = UserDefaults.standard.array(forKey: hiddenMessageIDsKey) as? [String] {
            hiddenMessageIDs = Set(stored)
        } else {
            hiddenMessageIDs = []
        }

        if let stored = UserDefaults.standard.dictionary(forKey: readMessageVersionsKey) as? [String: TimeInterval] {
            readMessageVersions = stored
        } else {
            readMessageVersions = [:]
        }

        if let stored = UserDefaults.standard.dictionary(forKey: alertedMessageVersionsKey) as? [String: TimeInterval] {
            alertedMessageVersions = stored
        } else {
            alertedMessageVersions = [:]
        }
    }

    static var receiveOperatorMessages: Bool {
        get {
            if UserDefaults.standard.object(forKey: receiveOperatorMessagesKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: receiveOperatorMessagesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: receiveOperatorMessagesKey)
        }
    }

    static var allowCriticalWhenOptedOut: Bool {
        get {
            if UserDefaults.standard.object(forKey: allowCriticalOperatorMessagesWhenOptedOutKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: allowCriticalOperatorMessagesWhenOptedOutKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: allowCriticalOperatorMessagesWhenOptedOutKey)
        }
    }

    static func shouldDeliver(_ message: SupportMessage) -> Bool {
        if receiveOperatorMessages {
            return true
        }

        return allowCriticalWhenOptedOut && message.isMarkedCritical
    }

    var visibleMessages: [SupportMessage] {
        messages.filter { !hiddenMessageIDs.contains($0.id) && Self.shouldDeliver($0) }
    }

    func fetchMessages() async {
        if !Self.receiveOperatorMessages && !Self.allowCriticalWhenOptedOut {
            messages = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = NSLocalizedString("messages.error.unavailable", comment: "")
                isLoading = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = NSLocalizedString("messages.error.unavailable", comment: "")
                isLoading = false
                return
            }

            let decoded = try JSONDecoder().decode(SupportMessagesResponse.self, from: data)
            messages = decoded.messages.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = NSLocalizedString("messages.error.unavailable", comment: "")
        }

        isLoading = false
    }

    func hideMessage(_ messageID: String) {
        hiddenMessageIDs.insert(messageID)
        UserDefaults.standard.set(Array(hiddenMessageIDs), forKey: hiddenMessageIDsKey)
    }

    func isRead(_ message: SupportMessage) -> Bool {
        guard let readVersion = readMessageVersions[message.id] else {
            return false
        }

        return readVersion >= message.updatedAt
    }

    func markAsRead(_ message: SupportMessage) {
        readMessageVersions[message.id] = message.updatedAt
        persistReadMessageVersions()
    }

    func markAsUnread(_ messageID: String) {
        readMessageVersions.removeValue(forKey: messageID)
        persistReadMessageVersions()
    }

    func pendingNewMessageAlertVersions() async -> [String: TimeInterval] {
        if !Self.receiveOperatorMessages && !Self.allowCriticalWhenOptedOut {
            return [:]
        }

        await fetchMessages()

        let newlyAlertableMessages = visibleMessages.filter { message in
            guard !isRead(message) else { return false }
            let alertedVersion = alertedMessageVersions[message.id] ?? 0
            return alertedVersion < message.updatedAt
        }

        guard !newlyAlertableMessages.isEmpty else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: newlyAlertableMessages.map { ($0.id, $0.updatedAt) })
    }

    func acknowledgeNewMessageAlert(_ versions: [String: TimeInterval]) {
        guard !versions.isEmpty else { return }

        for (messageID, updatedAt) in versions {
            alertedMessageVersions[messageID] = updatedAt
        }
        persistAlertedMessageVersions()
    }

    private func persistReadMessageVersions() {
        UserDefaults.standard.set(readMessageVersions, forKey: readMessageVersionsKey)
    }

    private func persistAlertedMessageVersions() {
        UserDefaults.standard.set(alertedMessageVersions, forKey: alertedMessageVersionsKey)
    }
}
