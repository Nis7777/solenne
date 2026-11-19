import Foundation
import Security

/// Fill these in to switch from on-device generation to the full pipeline
/// (Claude for story text, ElevenLabs for narration and voice cloning).
/// See README → "Backend". Leave empty to run fully offline.
enum Config {
    /// Set by the TestFlight workflow from the GitHub variables SUPABASE_URL / SUPABASE_ANON_KEY,
    /// or type them into the fallbacks below when building from Xcode.
    static let supabaseURL = infoValue("SolenneSupabaseURL") ?? ""          // e.g. "https://abcdefgh.supabase.co"
    static let supabaseAnonKey = infoValue("SolenneSupabaseAnonKey") ?? ""  // Project Settings → API → anon public key
    static let instagramAppID = ""       // Meta app id, enables direct Instagram Stories sharing
    static let termsURL = URL(string: "https://example.com/terms")!
    static let privacyURL = URL(string: "https://example.com/privacy")!
    static let supportEmail = "hello@example.com"

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }
}

enum BackendError: LocalizedError {
    case notConfigured
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "The story service isn't connected yet."
        case let .http(code, body): "Server error \(code): \(body.prefix(200))"
        }
    }
}

enum Backend {
    static var isConfigured: Bool { !Config.supabaseURL.isEmpty && !Config.supabaseAnonKey.isEmpty }

    struct GeneratedStory: Decodable {
        let title: String
        let text: String
        let audio_url: String?

        var audioURL: URL? { audio_url.flatMap(URL.init(string:)) }
    }

    static func generateStory(profile: Profile, desire: Desire, voiceID: String) async throws -> GeneratedStory {
        struct Body: Encodable {
            let profile: Profile
            let desire: DesireBody
            let voice_id: String
        }
        struct DesireBody: Encodable { let title: String; let detail: String }
        return try await call("generate-story", json: Body(profile: profile, desire: DesireBody(title: desire.title, detail: desire.detail), voice_id: voiceID))
    }

    static func reflect(question: String, answer: String, name: String) async throws -> String {
        struct Body: Encodable { let question: String; let answer: String; let name: String }
        struct Reply: Decodable { let text: String }
        let reply: Reply = try await call("reflect", json: Body(question: question, answer: answer, name: name))
        return reply.text
    }

    static func lifestyleTags(profile: Profile) async throws -> [String] {
        struct Body: Encodable { let profile: Profile }
        struct Reply: Decodable { let tags: [String] }
        let reply: Reply = try await call("lifestyle-tags", json: Body(profile: profile))
        return reply.tags
    }

    /// Uploads a ~10s sample and returns the ElevenLabs voice id.
    static func cloneVoice(sample: URL, name: String) async throws -> String {
        struct Reply: Decodable { let voice_id: String }
        let boundary = "solenne-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n\(name)\r\n")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"sample\"; filename=\"sample.m4a\"\r\nContent-Type: audio/m4a\r\n\r\n")
        body.append(try Data(contentsOf: sample))
        append("\r\n--\(boundary)--\r\n")
        let reply: Reply = try await call("clone-voice", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
        return reply.voice_id
    }

    // MARK: Plumbing

    private static func call<T: Decodable, B: Encodable>(_ function: String, json: B) async throws -> T {
        try await call(function, body: try JSONEncoder().encode(json), contentType: "application/json")
    }

    private static func call<T: Decodable>(_ function: String, body: Data, contentType: String, retry: Bool = true) async throws -> T {
        guard isConfigured, let url = URL(string: "\(Config.supabaseURL)/functions/v1/\(function)") else {
            throw BackendError.notConfigured
        }
        let token = try await Auth.accessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 && retry {
            Auth.clear()
            return try await call(function, body: body, contentType: contentType, retry: false)
        }
        guard (200..<300).contains(status) else {
            throw BackendError.http(status, String(decoding: data, as: UTF8.self))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Supabase anonymous sign-in. Every install gets a user id so the backend
/// can enforce a per-user daily generation cap.
private enum Auth {
    struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_at: Double?
        let expires_in: Double?
    }

    struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let expiry: Date
    }

    static func accessToken() async throws -> String {
        if let session = Keychain.read(Session.self, key: "supabase.session") {
            if session.expiry > Date.now.addingTimeInterval(60) { return session.accessToken }
            if let refreshed = try? await request(path: "token?grant_type=refresh_token", body: ["refresh_token": session.refreshToken]) {
                return refreshed.accessToken
            }
        }
        return try await request(path: "signup", body: [:]).accessToken
    }

    static func clear() { Keychain.delete(key: "supabase.session") }

    private static func request(path: String, body: [String: String]) async throws -> Session {
        guard let url = URL(string: "\(Config.supabaseURL)/auth/v1/\(path)") else { throw BackendError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw BackendError.http(status, String(decoding: data, as: UTF8.self)) }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiry = token.expires_at.map { Date(timeIntervalSince1970: $0) }
            ?? Date.now.addingTimeInterval(token.expires_in ?? 3600)
        let session = Session(accessToken: token.access_token, refreshToken: token.refresh_token, expiry: expiry)
        Keychain.write(session, key: "supabase.session")
        return session
    }
}

enum Keychain {
    static func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func delete(key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
