import Foundation

struct CapturedContext: Codable, Hashable {
    var appBundleIDs: [String] = []
    var documentPaths: [String] = []
}

struct WorkThread: Codable, Identifiable, Hashable {
    let id: UUID
    var intention: String
    var note: String
    var createdAt: Date
    var finishedAt: Date?
    var context: CapturedContext
}
