import CryptoKit
import Foundation

/// Looks up skippable segments (sponsors, self-promotion, etc.) from the free SponsorBlock database.
///
/// For privacy it only sends the first 4 characters of a hash of the video ID, so the server
/// can't tell which video you're watching. It returns matches for many videos and Tubey picks
/// out the right one locally.
enum SponsorBlock {
    static func segments(videoID: String, categories: [String]) async -> [[String: Any]] {
        let hash = SHA256.hash(data: Data(videoID.utf8)).map { String(format: "%02x", $0) }.joined()
        let categoryList = "[" + categories.map { "\"\($0)\"" }.joined(separator: ",") + "]"

        var components = URLComponents(string: "https://sponsor.ajay.app/api/skipSegments/\(hash.prefix(4))")!
        components.queryItems = [
            URLQueryItem(name: "categories", value: categoryList),
            URLQueryItem(name: "actionType", value: "skip"),
        ]
        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // 404 just means no segments have been submitted for these videos.
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 && status != 404 {
                print("Tubey: SponsorBlock server replied with status \(status)")
            }
            guard status == 200,
                  let videos = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let video = videos.first(where: { ($0["videoID"] as? String) == videoID }),
                  let segments = video["segments"] as? [[String: Any]] else {
                return []
            }
            return segments.compactMap { segment in
                guard let range = segment["segment"] as? [Double], range.count == 2,
                      let category = segment["category"] as? String else { return nil }
                return ["start": range[0], "end": range[1], "category": category]
            }
        } catch {
            print("Tubey: SponsorBlock lookup failed: \(error.localizedDescription)")
            return []
        }
    }
}
