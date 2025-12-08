//
//  LastFmManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import Combine

protocol LastFmManagerType {
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error>
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error>
    func getFriends(page: Int, limit: Int) -> AnyPublisher<[Friend], Error>
    func getRecentTracks(for username: String, page: Int, limit: Int) -> AnyPublisher<[RecentTracksResponse.RecentTracks.Track], Error>
}

enum ScrobblerError: Error, LocalizedError {
    case noSessionKey
    case networkError(Error)
    case apiError(String)
    case noData
    case invalidURL
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .noSessionKey:
            return "No session key available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return message
        case .noData:
            return "No data received"
        case .invalidURL:
            return "Invalid URL"
        case .authenticationRequired:
            return "Authentication required"
        }
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
