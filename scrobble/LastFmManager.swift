//
//  LastFmManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import Combine
import CommonCrypto
import CryptoKit

class LastFmManager {
    private let apiKey: String
    private let apiSecret: String
    private let username: String
    private let password: String
    private var sessionKey: String?
    private var isAuthenticated = false
    private var authenticationSubject = PassthroughSubject<Void, Error>()
    
    private var cancellables = Set<AnyCancellable>()
    
    private let queue = DispatchQueue(label: "com.lastfm.api", qos: .background)

    
    init(apiKey: String, apiSecret: String, username: String, password: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.username = username
        self.password = password
        
        authenticate()
    }
    
    private func authenticate() {
        print("Attempting to authenticate user: \(username)")
        let authURL = "https://ws.audioscrobbler.com/2.0/"
        let parameters: [String: Any] = [
            "method": "auth.getMobileSession",
            "username": username,
            "password": password,
            "api_key": apiKey,
        ]
        
        let signature = createSignature(parameters: parameters)
        var allParameters = parameters
        allParameters["api_sig"] = signature
        allParameters["format"] = "json"
        
        var components = URLComponents(string: authURL)!
        components.queryItems = allParameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: queue)
            .map(\.data)
            .tryMap { data -> AuthResponse in
                let jsonString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                print("Auth Response: \(jsonString)")
                
                if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ScrobblerError.apiError(error.message)
                }
                
                return try JSONDecoder().decode(AuthResponse.self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    self?.isAuthenticated = true
                    self?.authenticationSubject.send(())
                    print("Authentication completed successfully")
                case .failure(let error):
                    print("Authentication error: \(error)")
                    self?.authenticationSubject.send(completion: .failure(error))
                }
            }, receiveValue: { [weak self] response in
                self?.sessionKey = response.session.key
                print("Received session key: \(response.session.key)")
            })
            .store(in: &cancellables)
    }
    
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        print("Scrobble method called for: \(artist) - \(track)")
        
        // If we're already authenticated, skip waiting for authentication
        if isAuthenticated {
            return performScrobble(artist: artist, track: track, album: album)
        }
        
        return authenticationSubject
            .first()
            .flatMap { [weak self] _ -> AnyPublisher<Bool, Error> in
                guard let self = self else {
                    return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
                }
                return self.performScrobble(artist: artist, track: track, album: album)
            }
            .eraseToAnyPublisher()
    }
    
    private func performScrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard let sessionKey = self.sessionKey else {
            print("No session key available")
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
        }

        return Future { promise in
            self.queue.async {
                print("Preparing scrobble request for: \(artist) - \(track)")
                let scrobbleURL = "https://ws.audioscrobbler.com/2.0/"
                let timestamp = Int(Date().timeIntervalSince1970)
                
                var parameters: [String: String] = [
                    "method": "track.scrobble",
                    "artist": artist,
                    "track": track,
                    "album": album,
                    "timestamp": String(timestamp),
                    "api_key": self.apiKey,
                    "sk": sessionKey,
                ]
                
                print("Scrobble parameters before signature: \(parameters)")
                
                let signature = self.createSignature(parameters: parameters)
                parameters["api_sig"] = signature
                parameters["format"] = "json"
                
                print("Final scrobble parameters: \(parameters)")
                
                var components = URLComponents(string: scrobbleURL)!
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
                
                guard let url = components.url else {
                    print("Failed to create URL for scrobble request")
                    promise(.failure(ScrobblerError.invalidURL))
                    return
                }
                
                print("Scrobble request URL: \(url)")
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("Network error during scrobble: \(error)")
                        promise(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        print("No data received from scrobble request")
                        promise(.failure(ScrobblerError.noData))
                        return
                    }
                    
                    let jsonString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                    print("Scrobble Response: \(jsonString)")
                    
                    do {
                        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                            print("Scrobble API error: \(errorResponse.message)")
                            promise(.failure(ScrobblerError.apiError(errorResponse.message)))
                            return
                        }
                        
                        let scrobbleResponse = try JSONDecoder().decode(ScrobbleResponse.self, from: data)
                        let success = scrobbleResponse.scrobbles.attr.accepted == 1
                        print("Scrobble response: \(success ? "Success" : "Failure")")
                        promise(.success(success))
                    } catch {
                        print("Error decoding scrobble response: \(error)")
                        promise(.failure(error))
                    }
                }.resume()
            }
        }
        .eraseToAnyPublisher()
    }

//    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
//        print("Scrobble method called for: \(artist) - \(track)")
//        return authenticationSubject
//            .first()
//            .flatMap { [weak self] _ -> AnyPublisher<Bool, Error> in
//                guard let self = self, let sessionKey = self.sessionKey else {
//                    print("No session key available")
//                    return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
//                }
//                
//                return Future { promise in
//                    self.queue.async {
//                        print("Preparing scrobble request for: \(artist) - \(track)")
//                        let scrobbleURL = "https://ws.audioscrobbler.com/2.0/"
//                        let timestamp = Int(Date().timeIntervalSince1970)
//                        
//                        var parameters: [String: String] = [
//                            "method": "track.scrobble",
//                            "artist": artist,
//                            "track": track,
//                            "album": album,
//                            "timestamp": String(timestamp),
//                            "api_key": self.apiKey,
//                            "sk": sessionKey,
//                        ]
//                        
//                        print("Scrobble parameters before signature: \(parameters)")
//                        
//                        let signature = self.createSignature(parameters: parameters)
//                        parameters["api_sig"] = signature
//                        parameters["format"] = "json"
//                        
//                        print("Final scrobble parameters: \(parameters)")
//                        
//                        var components = URLComponents(string: scrobbleURL)!
//                        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
//                        
//                        guard let url = components.url else {
//                            print("Failed to create URL for scrobble request")
//                            promise(.failure(ScrobblerError.invalidURL))
//                            return
//                        }
//                        
//                        print("Scrobble request URL: \(url)")
//                        
//                        var request = URLRequest(url: url)
//                        request.httpMethod = "POST"
//                        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//                        
//                        URLSession.shared.dataTask(with: request) { data, response, error in
//                            if let error = error {
//                                print("network error durring scrobble: \(error)")
//                                promise(.failure(error))
//                                return
//                            }
//                            
//                            guard let data = data else {
//                                print("no data received from scrobble request")
//                                promise(.failure(ScrobblerError.noData))
//                                return
//                            }
//                            
//                            let jsonString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
//                            print("Scrobble Response: \(jsonString)")
//                            
//                            do {
//                                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
//                                    promise(.failure(ScrobblerError.apiError(errorResponse.message)))
//                                    return
//                                }
//                                
//                                let scrobbleResponse = try JSONDecoder().decode(ScrobbleResponse.self, from: data)
//                                let success = scrobbleResponse.scrobbles.attr.accepted == "1"
//                                print("Scrobble response: \(success ? "Success" : "Failure")")
//                                promise(.success(success))
//                            } catch {
//                                promise(.failure(error))
//                            }
//                        }.resume()
//                    }
//                }
//                .eraseToAnyPublisher()
//            }
//            .receive(on: DispatchQueue.main)
//            .eraseToAnyPublisher()
//    }

    private func createSignature(parameters: [String: Any]) -> String {
        let sortedKeys = parameters.keys.sorted()
        let concatenatedString = sortedKeys.reduce("") { result, key in
            let value = parameters[key]!
            // Don't URL encode here, use the raw value
            return result + key + "\(value)"
        }
        let signatureString = concatenatedString + apiSecret
        print("Signature string (pre-MD5): \(signatureString)")
        return md5(string: signatureString)
    }

    private func md5(string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
    }
}

struct AuthResponse: Codable {
    let session: Session
    
    struct Session: Codable {
        let name: String
        let key: String
    }
}

struct ScrobbleResponse: Codable {
    let scrobbles: Scrobbles

    struct Scrobbles: Codable {
        let scrobble: Scrobble
        let attr: Attr

        enum CodingKeys: String, CodingKey {
            case scrobble
            case attr = "@attr"
        }

        struct Scrobble: Codable {
            let artist: Artist
            let album: Album
            let track: Track
            let ignoredMessage: IgnoredMessage
            let albumArtist: AlbumArtist
            let timestamp: String

            struct Artist: Codable {
                let corrected: String
                let text: String

                enum CodingKeys: String, CodingKey {
                    case corrected
                    case text = "#text"
                }
            }

            struct Album: Codable {
                let corrected: String
                let text: String

                enum CodingKeys: String, CodingKey {
                    case corrected
                    case text = "#text"
                }
            }

            struct Track: Codable {
                let corrected: String
                let text: String

                enum CodingKeys: String, CodingKey {
                    case corrected
                    case text = "#text"
                }
            }

            struct IgnoredMessage: Codable {
                let code: String
                let text: String

                enum CodingKeys: String, CodingKey {
                    case code
                    case text = "#text"
                }
            }

            struct AlbumArtist: Codable {
                let corrected: String
                let text: String

                enum CodingKeys: String, CodingKey {
                    case corrected
                    case text = "#text"
                }
            }
        }

        struct Attr: Codable {
            let ignored: Int
            let accepted: Int
        }
    }
}

struct ErrorResponse: Codable {
    let error: Int
    let message: String
}

enum ScrobblerError: Error {
    case noSessionKey
    case networkError(Error)
    case apiError(String)
    case noData
    case invalidURL
}
