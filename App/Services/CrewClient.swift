import Foundation

struct CrewInfo: Codable, Hashable {
    let id: String
    let name: String
    let emblem: Int
    let code: String
    let families: Int
}

struct CrewMember: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let germs: Int
    let colorIndex: Int
}

struct RadarEntry: Codable, Identifiable, Hashable {
    let germID: String
    let families: Int

    var id: String { germID }
}

struct FeedEvent: Codable, Identifiable, Hashable {
    let id: String
    let memberID: String
    let name: String
    let colorIndex: Int
    let germID: String
    let at: Double
    let reactions: [String: Int]
    let mine: [String]
    /// "beat" for a germ beaten; absent or "caught" for a germ caught.
    var kind: String?

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
    var isWin: Bool { kind == "beat" }
}

struct CrewState: Codable, Hashable {
    let crew: CrewInfo
    let me: CrewMember
    let members: [CrewMember]
    let radar: [RadarEntry]
    let feed: [FeedEvent]
}

struct CrewSession: Codable {
    let token: String
    let state: CrewState
}

struct CrewAPIError: LocalizedError {
    let code: String

    var errorDescription: String? {
        switch code {
        case "name_rejected": return tr("That name isn't allowed. Try another one.")
        case "invalid_code": return tr("No crew matches that code.")
        case "crew_full": return tr("This crew is full.")
        case "rate_limited": return tr("Too many tries. Wait a minute.")
        case "unauthorized": return tr("You're no longer in this crew.")
        case "offline": return tr("The crew server can't be reached right now.")
        default: return tr("Something went wrong. Try again.")
        }
    }
}

/// Thin JSON client for the crew server.
struct CrewClient {
    let baseURL: URL
    let token: String?

    private struct ErrorBody: Decodable {
        let error: String
    }

    private func perform(_ method: String, _ path: String, body: Data?) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CrewAPIError(code: "offline")
        }
        guard let http = response as? HTTPURLResponse else { throw CrewAPIError(code: "offline") }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "unknown"
            throw CrewAPIError(code: http.statusCode == 401 ? "unauthorized" : code)
        }
        return data
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await perform("GET", path, body: nil)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func send<B: Encodable, T: Decodable>(_ method: String, _ path: String, _ body: B) async throws -> T {
        let data = try await perform(method, path, body: try JSONEncoder().encode(body))
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        _ = try await perform("DELETE", path, body: nil)
    }
}
