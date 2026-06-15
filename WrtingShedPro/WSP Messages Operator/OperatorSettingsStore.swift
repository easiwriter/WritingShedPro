import Foundation
import Observation

@Observable
final class OperatorSettingsStore {
    private static let endpointKey = "operator.messages.endpoint"
    private static let tokenKey = "operator.messages.token"

    var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: Self.endpointKey) }
    }

    var token: String {
        didSet { UserDefaults.standard.set(token, forKey: Self.tokenKey) }
    }

    init() {
        endpoint = UserDefaults.standard.string(forKey: Self.endpointKey)
            ?? "https://wsp-support.wsp-support.workers.dev"
        token = UserDefaults.standard.string(forKey: Self.tokenKey) ?? ""
    }
}
