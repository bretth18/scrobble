// NowPlayingFetcher.swift
// Swift wrapper around MediaRemoteBridge for use in Swift code.
// NOTE: This uses private API via the Objective-C shim. Not App Store safe.


import Foundation


final class NowPlayingFetcher {
    init?() {
        guard MediaRemoteBridge.loadMediaRemote() else {
            print("MediaRemote not available.")
            return nil
        }
    }

    func currentInfo() -> [String: Any] {
        guard let dict = MediaRemoteBridge.copyNowPlayingInfo() as? [String: Any] else {
            return [:]
        }
        print("Current Info: \(dict)") 
        return dict
    }

    // Common keys seen in MediaRemote dictionaries. These are not stable.
    struct Keys {
        static let title = "kMRMediaRemoteNowPlayingInfoTitle"
        static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
        static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
        static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
        static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
        static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    }

    func parse(_ info: [String: Any]) -> (title: String?, artist: String?, album: String?, duration: TimeInterval?, rate: Double?) {
        let title = info[Keys.title] as? String
        let artist = info[Keys.artist] as? String
        let album = info[Keys.album] as? String
        let duration = info[Keys.duration] as? Double
        let rate = info[Keys.playbackRate] as? Double
        return (title, artist, album, duration, rate)
    }

    @discardableResult
    func startNotifications(callback: @escaping () -> Void) -> Bool {
        return MediaRemoteBridge.registerForNowPlayingNotifications(with: DispatchQueue.main, callback: callback)
    }

    func stopNotifications() {
        MediaRemoteBridge.unregisterForNowPlayingNotifications()
    }
}

