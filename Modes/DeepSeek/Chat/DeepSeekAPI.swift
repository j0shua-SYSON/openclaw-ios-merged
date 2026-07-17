import Foundation

/// Errors surfaced to the chat UI. `message` is user-presentable.
struct DeepSeekError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A solved-once proof-of-work challenge from `create_pow_challenge` /
/// `create_guest_challenge`.
private struct DSChallenge {
    let algorithm: String
    let challenge: String   // 64-hex target digest
    let salt: String
    let expireAt: String    // decimal string of the ms timestamp
    let difficulty: Int
    let signature: String

    /// Build the base64 `X-DS(-Guest)-PoW-Response` header value for `targetPath`,
    /// solving the PoW on the current (background) thread.
    func solvedHeader(targetPath: String) throws -> String {
        guard DeepSeekPoW.selfCheck() else {
            throw DeepSeekError(message: "PoW self-check failed (build issue).")
        }
        guard let answer = DeepSeekPoW.solve(
            salt: salt, expireAt: expireAt, challengeHex: challenge, difficulty: difficulty
        ) else {
            throw DeepSeekError(message: "Couldn't solve the proof-of-work challenge (it may have expired).")
        }
        // Compact JSON, field order matches the official client. difficulty/expire_at
        // are intentionally excluded (they are baked into the server signature).
        let payload: [(String, Any)] = [
            ("algorithm", algorithm), ("challenge", challenge), ("salt", salt),
            ("answer", answer), ("signature", signature), ("target_path", targetPath),
        ]
        let json = "{" + payload.map { key, value in
            let v = value is String ? "\"\(value)\"" : "\(value)"
            return "\"\(key)\":\(v)"
        }.joined(separator: ",") + "}"
        return Data(json.utf8).base64EncodedString()
    }
}

/// Talks to chat.deepseek.com. Guest and authenticated share everything except
/// which challenge/completion endpoint and PoW header they use, and whether a
/// bearer token is attached.
final class DeepSeekAPI {
    static let shared = DeepSeekAPI()

    private let base = "https://chat.deepseek.com"
    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 300
        cfg.waitsForConnectivity = true
        self.session = URLSession(configuration: cfg)
    }

    // A stable per-install device id (the API wants one; value is arbitrary).
    private var deviceID: String {
        let key = "deepseek.deviceID"
        if let v = UserDefaults.standard.string(forKey: key) { return v }
        let v = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(v, forKey: key)
        return v
    }

    private func baseHeaders() -> [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "DeepSeek/2 CFNetwork/1568.100.1 Darwin/24.0.0",
            "x-client-platform": "ios",
            "x-client-version": "2.2.2",
            "x-client-bundle-id": "com.deepseek.chat",
            "x-client-locale": "en_US",
            "x-client-timezone-offset": "0",
        ]
    }

    private func request(_ path: String, body: [String: Any], token: String?, extra: [String: String] = [:]) -> URLRequest {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "POST"
        var headers = baseHeaders()
        if let token { headers["Authorization"] = "Bearer \(token)" }
        for (k, v) in extra { headers[k] = v }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    // MARK: - Response helpers

    private func json(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeepSeekError(message: "Unexpected server response.")
        }
        // Envelope: { code, msg, data: { biz_code, biz_msg, biz_data } }
        if let code = obj["code"] as? Int, code != 0 {
            throw DeepSeekError(message: (obj["msg"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Server error \(code).")
        }
        return obj
    }

    private func bizData(_ obj: [String: Any]) throws -> [String: Any] {
        guard let data = obj["data"] as? [String: Any] else { throw DeepSeekError(message: "Malformed response.") }
        if let bizCode = data["biz_code"] as? Int, bizCode != 0 {
            let m = (data["biz_msg"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "biz_code \(bizCode)"
            throw DeepSeekError(message: m)
        }
        return (data["biz_data"] as? [String: Any]) ?? [:]
    }

    private func parseChallenge(_ dict: [String: Any]) throws -> DSChallenge {
        // expire_at may arrive as a number or a string.
        let expireAt: String
        if let n = dict["expire_at"] as? Int64 { expireAt = String(n) }
        else if let n = dict["expire_at"] as? Int { expireAt = String(n) }
        else if let n = dict["expire_at"] as? Double { expireAt = String(Int64(n)) }
        else if let s = dict["expire_at"] as? String { expireAt = s }
        else { throw DeepSeekError(message: "Challenge missing expire_at.") }
        guard
            let algorithm = dict["algorithm"] as? String,
            let challenge = dict["challenge"] as? String,
            let salt = dict["salt"] as? String,
            let signature = dict["signature"] as? String
        else { throw DeepSeekError(message: "Malformed PoW challenge.") }
        let difficulty = (dict["difficulty"] as? Int) ?? Int((dict["difficulty"] as? Double) ?? 0)
        return DSChallenge(algorithm: algorithm, challenge: challenge, salt: salt,
                           expireAt: expireAt, difficulty: difficulty, signature: signature)
    }

    // MARK: - Authenticated flow

    func login(email: String, password: String) async throws -> String {
        let body: [String: Any] = ["email": email, "password": password, "device_id": deviceID,
                                    "os": "ios", "area_code": "", "mobile": ""]
        let (data, _) = try await session.data(for: request("/api/v0/users/login", body: body, token: nil))
        let biz = try bizData(try json(data))
        guard let user = biz["user"] as? [String: Any], let token = user["token"] as? String else {
            throw DeepSeekError(message: "Login succeeded but no token was returned.")
        }
        return token
    }

    func createSession(token: String) async throws -> String {
        let (data, _) = try await session.data(for: request("/api/v0/chat_session/create", body: ["character_id": NSNull()], token: token))
        let biz = try bizData(try json(data))
        if let id = biz["id"] as? String { return id }
        if let s = biz["chat_session"] as? [String: Any], let id = s["id"] as? String { return id }
        throw DeepSeekError(message: "Couldn't create a chat session.")
    }

    private func powHeader(token: String, targetPath: String) async throws -> String {
        let (data, _) = try await session.data(for: request("/api/v0/chat/create_pow_challenge", body: ["target_path": targetPath], token: token))
        let biz = try bizData(try json(data))
        guard let ch = biz["challenge"] as? [String: Any] else { throw DeepSeekError(message: "No PoW challenge returned.") }
        let challenge = try parseChallenge(ch)
        return try await solveOffMain(challenge, targetPath: targetPath)
    }

    // MARK: - Guest flow (best-effort; region/captcha-gated, may be unavailable)

    private func guestPowHeader(targetPath: String) async throws -> String {
        let extra = ["x-rangers-id": String(Int.random(in: 100_000_000_000_000_000...999_999_999_999_999_999))]
        let body: [String: Any] = ["target_path": targetPath]
        let (data, _) = try await session.data(for: request("/api/v0/users/create_guest_challenge", body: body, token: nil, extra: extra))
        let biz = try bizData(try json(data))
        guard let ch = biz["guest_challenge"] as? [String: Any] else {
            throw DeepSeekError(message: "Guest mode is unavailable here — please sign in.")
        }
        let challenge = try parseChallenge(ch)
        return try await solveOffMain(challenge, targetPath: targetPath)
    }

    private func solveOffMain(_ challenge: DSChallenge, targetPath: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try challenge.solvedHeader(targetPath: targetPath)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    // MARK: - Streaming completion

    /// Streams an authenticated chat turn. Yields text fragments as they arrive.
    /// Returns the assistant's response message id via `onMessageID` for threading.
    func streamAuthed(token: String, sessionId: String, parentMessageID: Int?, prompt: String,
                      onMessageID: @escaping (Int) -> Void) -> AsyncThrowingStream<String, Error> {
        let path = "/api/v0/chat/completion"
        let body: [String: Any] = [
            "chat_session_id": sessionId,
            "parent_message_id": parentMessageID.map { $0 as Any } ?? NSNull(),
            "prompt": prompt, "ref_file_ids": [], "thinking_enabled": false,
            "search_enabled": false,
        ]
        return stream(path: path, body: body, token: token, powHeaderName: "X-DS-PoW-Response",
                      powHeader: { try await self.powHeader(token: token, targetPath: path) },
                      onMessageID: onMessageID)
    }

    /// Best-effort guest completion via the iOS-only `/guest/chat/completion`
    /// endpoint. Throws a friendly error if guest mode is gated in this region.
    func streamGuest(prompt: String, onMessageID: @escaping (Int) -> Void) -> AsyncThrowingStream<String, Error> {
        let path = "/api/v0/guest/chat/completion"
        let body: [String: Any] = ["prompt": prompt, "ref_file_ids": [], "thinking_enabled": false,
                                   "search_enabled": false, "os": "ios", "device_id": deviceID]
        return stream(path: path, body: body, token: nil, powHeaderName: "X-DS-Guest-PoW-Response",
                      powHeader: { try await self.guestPowHeader(targetPath: path) },
                      onMessageID: onMessageID)
    }

    private func stream(path: String, body: [String: Any], token: String?, powHeaderName: String,
                        powHeader: @escaping () async throws -> String,
                        onMessageID: @escaping (Int) -> Void) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let header = try await powHeader()
                    let req = self.request(path, body: body, token: token,
                                           extra: ["Accept": "text/event-stream", powHeaderName: header])
                    let (bytes, response) = try await self.session.bytes(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        throw DeepSeekError(message: "Chat failed (HTTP \(http.statusCode)).")
                    }
                    var currentEvent = "message"
                    for try await line in bytes.lines {
                        if line.isEmpty { continue }
                        if line.hasPrefix("event:") { currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces); continue }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty || payload == "[DONE]" { continue }
                        guard let obj = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { continue }
                        if currentEvent == "hint", (obj["type"] as? String) == "error" {
                            throw DeepSeekError(message: (obj["msg"] as? String) ?? "The chat service returned an error.")
                        }
                        currentEvent = "message"
                        if let mid = obj["response_message_id"] as? Int { onMessageID(mid) }
                        for fragment in Self.extractContent(obj) { continuation.yield(fragment) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Pulls assistant text out of a DeepSeek SSE event. Content arrives either as
    /// APPEND ops on a `…/content` path, or inside an initial snapshot object.
    private static func extractContent(_ obj: [String: Any]) -> [String] {
        if let p = obj["p"] as? String {
            guard p.hasSuffix("content"), !p.contains("thinking") else { return [] }
            if let v = obj["v"] as? String { return [v] }
            return []
        }
        // Snapshot: v is an object holding response.fragments[].content
        if let v = obj["v"] as? [String: Any] {
            var out: [String] = []
            if let resp = v["response"] as? [String: Any], let frags = resp["fragments"] as? [[String: Any]] {
                for f in frags where (f["type"] as? String) != "THINK" {
                    if let c = f["content"] as? String, !c.isEmpty { out.append(c) }
                }
            }
            return out
        }
        return []
    }
}
