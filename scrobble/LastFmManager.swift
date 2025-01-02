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
    
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard let sessionKey = self.sessionKey else {
            print("No session key available for updating now playing")
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
        }
        
        return Future { promise in
            self.queue.async {
                print("Updating now playing: \(artist) - \(track)")
                let nowPlayingURL = "https://ws.audioscrobbler.com/2.0/"
                
                var parameters: [String: String] = [
                    "method": "track.updateNowPlaying",
                    "artist": artist,
                    "track": track,
                    "album": album,
                    "api_key": self.apiKey,
                    "sk": sessionKey
                ]
                
                let signature = self.createSignature(parameters: parameters)
                parameters["api_sig"] = signature
                parameters["format"] = "json"
                
                var components = URLComponents(string: nowPlayingURL)!
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
                
                guard let url = components.url else {
                    print("Failed to create URL for now playing update")
                    promise(.failure(ScrobblerError.invalidURL))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("Network error during now playing update: \(error)")
                        promise(.failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        print("No data received from now playing update")
                        promise(.failure(ScrobblerError.noData))
                        return
                    }
                    
                    let jsonString = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                    print("Now playing response: \(jsonString)")
                    
                    do {
                        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                            print("Now playing API error: \(errorResponse.message)")
                            promise(.failure(ScrobblerError.apiError(errorResponse.message)))
                            return
                        }
                        
                        // For now playing, just check res was successful
                        promise(.success(true))
                    } catch {
                        print("Error decoding now playing response: \(error)")
                        promise(.failure(error))
                    }
                    
                }.resume()
            }
        }
        .eraseToAnyPublisher()
    }

    
    /// Mark: Socials
    
    func getFriends(page: Int = 1, limit: Int = 50) -> AnyPublisher<[Friend], Error> {
        guard isAuthenticated else {
            return authenticationSubject
                .first()
                .flatMap { [weak self] _ -> AnyPublisher<[Friend], Error> in
                    guard let self = self else {
                        return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
                    }
                    return self.performGetFriends(page: page, limit: limit)
                }
                .eraseToAnyPublisher()
        }
        
        return performGetFriends(page: page, limit: limit)
    }
    
    
    private func performGetFriends(page: Int, limit: Int) -> AnyPublisher<[Friend], Error> {
        print("Performing getFriends - Auth status: \(isAuthenticated), Session key: \(sessionKey ?? "none")")
        
        guard let sessionKey = self.sessionKey else {
            print("No session key available")
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
        }

        var parameters: [String: String] = [
            "method": "user.getFriends",
            "user": username,
            "api_key": apiKey,
            "sk": sessionKey,
            "page": String(page),
            "limit": String(limit),
        ]
        
        // Create signature before adding format
        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"
        
        print("getFriends parameters: \(parameters)")


        
        
        return makeRequest(parameters: parameters)
//            .handleEvents(
//                receiveOutput: { data in
//                    if let responseStr = String(data: data, encoding: .utf8) {
//                        print("Raw API Response: \(responseStr)")
//                    }
//                }
//            )
            .decode(type: FriendsResponse.self, decoder: JSONDecoder())
    
            .map { response -> [Friend] in
                print("Got friends response with \(response.friends.user.count) friends")
//                print("Friends: \(response.friends)")
                return response.friends.user
            }
            .eraseToAnyPublisher()
    }
    
    
    func getRecentTracks(for username: String, page: Int = 1, limit: Int = 50) -> AnyPublisher<[RecentTracksResponse.RecentTracks.Track], Error> {
        guard isAuthenticated else {
            return authenticationSubject
                .first()
                .flatMap { [weak self] _ -> AnyPublisher<[RecentTracksResponse.RecentTracks.Track], Error> in
                    guard let self = self else {
                        return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
                        
                    }
                    
                    return self.performGetRecentTracks(for: username, page: page, limit: limit)
                    
                }
                .eraseToAnyPublisher()
        }
        
        return performGetRecentTracks(for: username, page: page, limit: limit)
    }
    
    private func performGetRecentTracks(for username: String, page: Int, limit: Int) -> AnyPublisher<[RecentTracksResponse.RecentTracks.Track], Error> {
        var parameters: [String: String] = [
            "method": "user.getRecentTracks",
            "user": username,
            "api_key": apiKey,
            "page": String(page),
            "limit": String(limit),
        ]
        
        // Create signature before adding format
        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"
        
 
        
        return makeRequest(parameters: parameters
        )
        .tryMap { data -> Data in
            if let str = String(data: data, encoding: .utf8) {
                print("Recent tracks raw response: \(str)")
            }
            return data
        }
        .decode(type: RecentTracksResponse.self, decoder: JSONDecoder())
        .tryMap { response -> [RecentTracksResponse.RecentTracks.Track] in
            print("Decoded response: \(String(describing: response))")
            let tracks = response.recenttracks.track
            print("Found \(tracks.count) tracks")
            tracks.forEach { track in
                print("Track: \(track.artist.text) - \(track.name) (nowplaying: \(track.nowplaying != nil))")
            }
            return tracks
        }
        .mapError { error in
            print("Error in recent tracks pipeline: \(error)")
            return error
        }
        .eraseToAnyPublisher()
            
    }
    
    private func makeRequest(parameters: [String: String]) -> AnyPublisher<Data, Error> {
        let baseURL = "https://ws.audioscrobbler.com/2.0/"
        var components = URLComponents(string: baseURL)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            return Fail(error: ScrobblerError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .subscribe(on: queue)
            .map(\.data)
            .tryMap { data in
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ScrobblerError.apiError(errorResponse.message)
                }
                return data
            }
            .eraseToAnyPublisher()
    }


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

struct Friend: Codable {
    let name: String
    let realname: String?
    let url: String
    let image: [Image]
    let country: String?
    let playcount: String?
    let registered: Registered?
    let subscriber: String?
    
    struct Registered: Codable {
        let unixtime: String
        
        enum CodingKeys: String, CodingKey {
            case unixtime
        }
    }
    
    struct Image: Codable {
        let text: String
        let size: String
        
        enum CodingKeys: String, CodingKey {
            case text = "#text"
            case size
        }
    }
}

struct FriendsResponse: Codable {
    let friends: Friends
    
    struct Friends: Codable {
        let user: [Friend]
        let attr: Attr
        
        enum CodingKeys: String, CodingKey {
            case user
            case attr = "@attr"
        }
        
        struct Attr: Codable {
            let page: String
            let total: String
            let user: String
            let perPage: String
            let totalPages: String
        }
    }
}

struct RecentTracksResponse: Codable {
    let recenttracks: RecentTracks
    
    struct RecentTracks: Codable {
        let track: [Track]
        let attr: Attr
        
        enum CodingKeys: String, CodingKey {
            case track
            case attr = "@attr"
        }
        
        struct Track: Codable {
            let artist: Artist
            let streamable: String
            let image: [Image]
            let mbid: String
            let album: Album
            let name: String
            let url: String
            let date: Date?
            private let attr: NowPlaying?
            
            var nowplaying: Bool {
                return attr != nil
            }
            
            enum CodingKeys: String, CodingKey {
                case artist, streamable, image, mbid, album, name, url, date
                case attr = "@attr"
            }
            
            struct NowPlaying: Codable {
                let nowplaying: String
            }
            
            struct Artist: Codable {
                let mbid: String
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case mbid
                    case text = "#text"
                }
            }
            
            struct Album: Codable {
                let mbid: String
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case mbid
                    case text = "#text"
                }
            }
            
            struct Date: Codable {
                let uts: String
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case uts
                    case text = "#text"
                }
            }
            
            struct Image: Codable {
                let size: String
                let text: String
                
                enum CodingKeys: String, CodingKey {
                    case size
                    case text = "#text"
                }
            }
        }
        
        struct Attr: Codable {
            let user: String
            let page: String
            let perPage: String
            let totalPages: String
            let total: String
        }
    }
}

enum ScrobblerError: Error {
    case noSessionKey
    case networkError(Error)
    case apiError(String)
    case noData
    case invalidURL
}
