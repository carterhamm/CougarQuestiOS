//
//  CougarQuestLink.swift
//  CougarQuest
//
//  Universal link / App Clip URL construction + parsing.
//  Lives in its own file so the future App Clip target can include it
//  without dragging in the rest of CougarQuest.
//

import Foundation

enum CougarQuestLink {
    /// The host that maps to both the main app (Universal Link) and the
    /// App Clip experience. Set up via Apple's App Site Association file at:
    ///   https://cougarquest.com/.well-known/apple-app-site-association
    static let host = "cougarquest.com"

    /// Build a shareable URL for a single quest.
    /// Format: https://cougarquest.com/q/<questId>
    /// - Tapped on iOS with the app installed → opens the app, deep-links to the quest.
    /// - Tapped on iOS without the app → offers the App Clip (one-quest preview).
    /// - Tapped on web → renders the quest detail page (web fallback).
    static func url(forQuestId id: String) -> URL? {
        var c = URLComponents()
        c.scheme = "https"
        c.host = host
        c.path = "/q/\(id)"
        return c.url
    }

    /// Inverse of `url(forQuestId:)`. Returns the quest id, or nil if the URL
    /// doesn't match the share-link shape.
    static func questId(from url: URL) -> String? {
        guard
            url.scheme == "https" || url.scheme == "http",
            url.host == host
        else { return nil }
        // Path is "/q/<id>" — split returns ["", "q", "<id>"] under split(separator:)
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 2, parts[0] == "q" else { return nil }
        let id = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }
}
