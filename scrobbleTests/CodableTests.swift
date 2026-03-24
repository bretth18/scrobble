import Testing
@testable import scrobble

@Suite("Codable Tests")
struct CodableTests {

    @Test("ErrorResponse decodes correctly")
    func errorResponseDecode() throws {
        let json = """
        {"error": 6, "message": "User not found"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ErrorResponse.self, from: data)
        #expect(response.error == 6)
        #expect(response.message == "User not found")
    }

    @Test("AuthResponse decodes correctly")
    func authResponseDecode() throws {
        let json = """
        {"session": {"name": "testuser", "key": "abc123"}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)
        #expect(response.session.name == "testuser")
        #expect(response.session.key == "abc123")
    }

    @Test("Friend decodes with all fields")
    func friendDecodeAllFields() throws {
        let json = """
        {
            "name": "testfriend",
            "realname": "Test Friend",
            "url": "https://last.fm/user/testfriend",
            "image": [{"#text": "https://example.com/img.jpg", "size": "medium"}],
            "country": "US",
            "playcount": "5000",
            "registered": {"unixtime": "1234567890"},
            "subscriber": "0"
        }
        """
        let data = json.data(using: .utf8)!
        let friend = try JSONDecoder().decode(Friend.self, from: data)
        #expect(friend.name == "testfriend")
        #expect(friend.realname == "Test Friend")
        #expect(friend.country == "US")
        #expect(friend.playcount == "5000")
        #expect(friend.image.count == 1)
        #expect(friend.image.first?.size == "medium")
    }

    @Test("Friend decodes with optional fields missing")
    func friendDecodeOptionalFields() throws {
        let json = """
        {
            "name": "minimalfriend",
            "url": "https://last.fm/user/minimal",
            "image": []
        }
        """
        let data = json.data(using: .utf8)!
        let friend = try JSONDecoder().decode(Friend.self, from: data)
        #expect(friend.name == "minimalfriend")
        #expect(friend.realname == nil)
        #expect(friend.country == nil)
        #expect(friend.playcount == nil)
        #expect(friend.registered == nil)
    }

    @Test("ScrobbleResponse decodes correctly")
    func scrobbleResponseDecode() throws {
        let json = """
        {
            "scrobbles": {
                "scrobble": {
                    "artist": {"corrected": "0", "#text": "Radiohead"},
                    "album": {"corrected": "0", "#text": "OK Computer"},
                    "track": {"corrected": "0", "#text": "Paranoid Android"},
                    "ignoredMessage": {"code": "0", "#text": ""},
                    "albumArtist": {"corrected": "0", "#text": "Radiohead"},
                    "timestamp": "1234567890"
                },
                "@attr": {"ignored": 0, "accepted": 1}
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(ScrobbleResponse.self, from: data)
        #expect(response.scrobbles.scrobble.artist.text == "Radiohead")
        #expect(response.scrobbles.scrobble.track.text == "Paranoid Android")
        #expect(response.scrobbles.scrobble.album.text == "OK Computer")
        #expect(response.scrobbles.attr.accepted == 1)
        #expect(response.scrobbles.attr.ignored == 0)
    }

    @Test("FriendsResponse decodes correctly")
    func friendsResponseDecode() throws {
        let json = """
        {
            "friends": {
                "user": [
                    {
                        "name": "friend1",
                        "url": "https://last.fm/user/friend1",
                        "image": []
                    }
                ],
                "@attr": {
                    "page": "1",
                    "total": "50",
                    "user": "testuser",
                    "perPage": "10",
                    "totalPages": "5"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(FriendsResponse.self, from: data)
        #expect(response.friends.user.count == 1)
        #expect(response.friends.user.first?.name == "friend1")
        #expect(response.friends.attr.total == "50")
    }

    @Test("RecentTracksResponse decodes now-playing track")
    func recentTracksNowPlaying() throws {
        let json = """
        {
            "recenttracks": {
                "track": [
                    {
                        "artist": {"mbid": "", "#text": "Radiohead"},
                        "streamable": "0",
                        "image": [{"size": "small", "#text": "https://example.com/img.jpg"}],
                        "mbid": "",
                        "album": {"mbid": "", "#text": "OK Computer"},
                        "name": "Paranoid Android",
                        "url": "https://last.fm/track",
                        "@attr": {"nowplaying": "true"}
                    }
                ],
                "@attr": {
                    "user": "testuser",
                    "page": "1",
                    "perPage": "10",
                    "totalPages": "1",
                    "total": "1"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
        #expect(response.recenttracks.track.count == 1)
        let track = response.recenttracks.track.first!
        #expect(track.name == "Paranoid Android")
        #expect(track.artist.text == "Radiohead")
        #expect(track.nowplaying == true)
    }

    @Test("RecentTracksResponse decodes track with date")
    func recentTracksWithDate() throws {
        let json = """
        {
            "recenttracks": {
                "track": [
                    {
                        "artist": {"mbid": "", "#text": "Radiohead"},
                        "streamable": "0",
                        "image": [],
                        "mbid": "",
                        "album": {"mbid": "", "#text": "OK Computer"},
                        "name": "Karma Police",
                        "url": "https://last.fm/track",
                        "date": {"uts": "1234567890", "#text": "13 Feb 2009, 16:31"}
                    }
                ],
                "@attr": {
                    "user": "testuser",
                    "page": "1",
                    "perPage": "10",
                    "totalPages": "1",
                    "total": "1"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
        let track = response.recenttracks.track.first!
        #expect(track.name == "Karma Police")
        #expect(track.date?.uts == "1234567890")
        #expect(track.nowplaying == false)
    }

    @Test("Friend has expected values")
    func friendValues() {
        let friend = Friend(
            name: "test",
            realname: "Test User",
            url: "https://example.com",
            image: [Friend.Image(text: "https://example.com/image.jpg", size: "medium")],
            country: "USA",
            playcount: "100",
            registered: Friend.Registered(unixtime: "1234567890"),
            subscriber: "0"
        )
        #expect(friend.name == "test")
        #expect(friend.realname == "Test User")
        #expect(friend.country == "USA")
    }

    @Test("SupportedMusicApp encoding excludes id field")
    func supportedMusicAppCodingExcludesId() throws {
        let app = SupportedMusicApp.allApps.first!
        let data = try JSONEncoder().encode(app)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(!jsonString.contains("\"id\""))
        #expect(jsonString.contains("bundleId"))
    }
}
