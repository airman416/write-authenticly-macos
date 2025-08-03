//
//  APIClient.swift
//  Shared networking for Freewrite apps
//
//  Created by Backend Integration on 8/3/25.
//

import Foundation

// MARK: - API Models

struct APIJournalEntry: Codable {
    let id: String
    let date: String
    let filename: String
    let content: String
    let previewText: String?
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case id, date, filename, content, timestamp
        case previewText = "preview_text"
    }
}

struct APIJournalEntryCreate: Codable {
    let content: String
    
    init(content: String) {
        self.content = content
    }
}

struct APIJournalEntryUpdate: Codable {
    let content: String?
    
    init(content: String?) {
        self.content = content
    }
}

struct APIAnalysisRequest: Codable {
    let entryId: String
    let analysisType: String
    
    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case analysisType = "analysis_type"
    }
    
    init(entryId: String, analysisType: String = "general") {
        self.entryId = entryId
        self.analysisType = analysisType
    }
}

struct APIAnalysisResponse: Codable {
    let entryId: String
    let analysisType: String
    let analysis: String
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case analysisType = "analysis_type"
        case analysis, timestamp
    }
}

struct APIPromptResponse: Codable {
    let prompt: String
}

// MARK: - API Client

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    
    private init() {
        // Default to localhost for development
        // In production, this would be your deployed API URL
        self.baseURL = "http://localhost:8000/api"
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Test connection on initialization
        Task {
            await testConnection()
        }
    }
    
    // MARK: - Connection Management
    
    func testConnection() async {
        do {
            let url = URL(string: baseURL.replacingOccurrences(of: "/api", with: "/health"))!
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                isConnected = httpResponse.statusCode == 200
                lastError = isConnected ? nil : "Server returned status \(httpResponse.statusCode)"
            }
        } catch {
            isConnected = false
            lastError = "Connection failed: \(error.localizedDescription)"
            print("❌ API Connection failed: \(error)")
        }
    }
    
    // MARK: - Journal API Methods
    
    func createJournal(content: String) async throws -> APIJournalEntry {
        let request = APIJournalEntryCreate(content: content)
        return try await performRequest(
            endpoint: "/journals/",
            method: "POST",
            body: request,
            responseType: APIJournalEntry.self
        )
    }
    
    func getJournals(limit: Int = 100, offset: Int = 0) async throws -> [APIJournalEntry] {
        let url = "/journals/?limit=\(limit)&offset=\(offset)"
        return try await performRequest(
            endpoint: url,
            method: "GET",
            responseType: [APIJournalEntry].self
        )
    }
    
    func getJournal(id: String) async throws -> APIJournalEntry {
        return try await performRequest(
            endpoint: "/journals/\(id)",
            method: "GET",
            responseType: APIJournalEntry.self
        )
    }
    
    func updateJournal(id: String, content: String) async throws -> APIJournalEntry {
        let request = APIJournalEntryUpdate(content: content)
        return try await performRequest(
            endpoint: "/journals/\(id)",
            method: "PUT",
            body: request,
            responseType: APIJournalEntry.self
        )
    }
    
    func deleteJournal(id: String) async throws {
        let _: [String: String] = try await performRequest(
            endpoint: "/journals/\(id)",
            method: "DELETE",
            responseType: [String: String].self
        )
    }
    
    // MARK: - Analysis API Methods
    
    func analyzeJournal(entryId: String, analysisType: String = "general") async throws -> APIAnalysisResponse {
        let request = APIAnalysisRequest(entryId: entryId, analysisType: analysisType)
        return try await performRequest(
            endpoint: "/analysis/analyze",
            method: "POST",
            body: request,
            responseType: APIAnalysisResponse.self
        )
    }
    
    func getWritingPrompt() async throws -> String {
        let response: APIPromptResponse = try await performRequest(
            endpoint: "/analysis/prompt",
            method: "GET",
            responseType: APIPromptResponse.self
        )
        return response.prompt
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T? = nil,
        responseType: U.Type
    ) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().data(from: body)
            } catch {
                throw APIError.encodingFailed(error)
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            do {
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                decoder.dateDecodingStrategy = .formatted(dateFormatter)
                
                return try decoder.decode(responseType, from: data)
            } catch {
                throw APIError.decodingFailed(error)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String)
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Convenience Extensions

extension APIJournalEntry {
    func toJournalEntry() -> JournalEntry {
        let entry = JournalEntry(
            date: self.date,
            filename: self.filename,
            content: self.content
        )
        
        // Parse the UUID from the API id
        if let uuid = UUID(uuidString: self.id) {
            entry.id = uuid
        }
        
        // Parse the timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let timestamp = dateFormatter.date(from: self.timestamp) {
            entry.timestamp = timestamp
        }
        
        return entry
    }
}

extension JournalEntry {
    func toAPIJournalEntry() -> APIJournalEntryCreate {
        return APIJournalEntryCreate(content: self.content)
    }
}