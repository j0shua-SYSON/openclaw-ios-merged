import Foundation

/// Errors surfaced to the chat UI. `message` is user-presentable.
struct DeepSeekError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// One piece of a streamed assistant turn.
enum DSStreamEvent {
    case answer(String)        // visible answer text (append)
    case thinking(String)      // chain-of-thought text (the "Thought for Ns" block)
    case searchStatus(String)  // "Searching the web", "Read N web pages", …
    case messageID(Int)        // assistant response_message_id (for threading)
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
        return try await solveOffMain(try parseChallenge(ch), targetPath: targetPath)
    }

    // MARK: - Guest flow (best-effort; region/captcha-gated, may be unavailable)

    private func guestPowHeader(targetPath: String) async throws -> String {
        let extra = ["x-rangers-id": String(Int.random(in: 100_000_000_000_000_000...999_999_999_999_999_999))]
        let (data, _) = try await session.data(for: request("/api/v0/users/create_guest_challenge", body: ["target_path": targetPath], token: nil, extra: extra))
        let biz = try bizData(try json(data))
        guard let ch = biz["guest_challenge"] as? [String: Any] else {
            throw DeepSeekError(message: "Guest mode is unavailable here — please sign in.")
        }
        return try await solveOffMain(try parseChallenge(ch), targetPath: targetPath)
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

    /// Streams an authenticated chat turn as typed events.
    func streamAuthed(token: String, sessionId: String, parentMessageID: Int?, prompt: String,
                      thinkingEnabled: Bool, searchEnabled: Bool) -> AsyncThrowingStream<DSStreamEvent, Error> {
        let path = "/api/v0/chat/completion"
        let body: [String: Any] = [
            "chat_session_id": sessionId,
            "parent_message_id": parentMessageID.map { $0 as Any } ?? NSNull(),
            "prompt": prompt, "ref_file_ids": [],
            "thinking_enabled": thinkingEnabled, "search_enabled": searchEnabled,
        ]
        return stream(path: path, body: body, token: token, powHeaderName: "X-DS-PoW-Response",
                      powHeader: { try await self.powHeader(token: token, targetPath: path) })
    }

    /// Best-effort guest completion via the iOS-only `/guest/chat/completion`
    /// endpoint. Throws a friendly error if guest mode is gated in this region.
    func streamGuest(prompt: String, thinkingEnabled: Bool, searchEnabled: Bool) -> AsyncThrowingStream<DSStreamEvent, Error> {
        let path = "/api/v0/guest/chat/completion"
        let body: [String: Any] = ["prompt": prompt, "ref_file_ids": [],
                                   "thinking_enabled": thinkingEnabled, "search_enabled": searchEnabled,
                                   "os": "ios", "device_id": deviceID]
        return stream(path: path, body: body, token: nil, powHeaderName: "X-DS-Guest-PoW-Response",
                      powHeader: { try await self.guestPowHeader(targetPath: path) })
    }

    private func stream(path: String, body: [String: Any], token: String?, powHeaderName: String,
                        powHeader: @escaping () async throws -> String) -> AsyncThrowingStream<DSStreamEvent, Error> {
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
                    var parser = DSStreamParser()
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
                        for ev in parser.process(obj) { continuation.yield(ev) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

}

/// Stateful applier for DeepSeek's streaming JSON-patch protocol. The response is a
/// document with `response.fragments[]`, each fragment typed THINK / TOOL_SEARCH /
/// TOOL_OPEN / RESPONSE. Content arrives as APPEND ops on `response/fragments/-1/content`
/// (the last fragment) — with bare `{"v":…}` ops continuing the last path and BATCH ops
/// appending new typed fragments — so answer vs chain-of-thought vs search is
/// distinguished only by the target fragment's type.
private struct DSStreamParser {
    private var fragTypes: [String] = []
    private var lastPath = ""

    mutating func process(_ obj: [String: Any]) -> [DSStreamEvent] {
        var out: [DSStreamEvent] = []
        if let mid = obj["response_message_id"] as? Int { out.append(.messageID(mid)) }
        if let p = obj["p"] as? String { lastPath = p }
        apply(path: obj["p"] as? String ?? lastPath, op: obj["o"] as? String, value: obj["v"], into: &out)
        return out
    }

    private mutating func apply(path: String, op: String?, value: Any?, into out: inout [DSStreamEvent]) {
        // BATCH (explicit, or a bare array-of-patches continuation)
        if let arr = value as? [[String: Any]], arr.first?["p"] != nil, op == "BATCH" || op == nil {
            for sub in arr {
                let subPath = (sub["p"] as? String).map { path.isEmpty ? $0 : path + "/" + $0 } ?? path
                apply(path: subPath, op: sub["o"] as? String, value: sub["v"], into: &out)
            }
            return
        }
        // Full-response snapshot
        if let dict = value as? [String: Any],
           let resp = (dict["response"] as? [String: Any]) ?? (path.hasSuffix("response") ? dict : nil),
           let frags = resp["fragments"] as? [[String: Any]] {
            fragTypes = []
            for f in frags { appendFragment(f, into: &out) }
            return
        }
        // New typed fragments appended
        if path.hasSuffix("fragments"), let arr = value as? [[String: Any]] {
            for f in arr { appendFragment(f, into: &out) }
            return
        }
        // Content append to a fragment
        if path.hasSuffix("content"), let idx = fragmentIndex(path), let s = value as? String {
            emit(fragment: idx, content: s, into: &out)
        }
    }

    private mutating func appendFragment(_ f: [String: Any], into out: inout [DSStreamEvent]) {
        let type = f["type"] as? String ?? "RESPONSE"
        fragTypes.append(type)
        if type == "TOOL_SEARCH" { out.append(.searchStatus("Searching the web")) }
        if let c = f["content"] as? String, !c.isEmpty { emit(fragment: fragTypes.count - 1, content: c, into: &out) }
    }

    private func fragmentIndex(_ path: String) -> Int? {
        let parts = path.components(separatedBy: "/")
        guard let fi = parts.firstIndex(of: "fragments"), fi + 1 < parts.count, let n = Int(parts[fi + 1]) else { return nil }
        return n < 0 ? fragTypes.count + n : n
    }

    private func emit(fragment idx: Int, content: String, into out: inout [DSStreamEvent]) {
        guard idx >= 0, idx < fragTypes.count else { return }
        switch fragTypes[idx] {
        case "THINK": out.append(.thinking(content))
        case "RESPONSE": out.append(.answer(content))
        default: break
        }
    }
}
