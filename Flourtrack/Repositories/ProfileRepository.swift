import Foundation
import SwiftData

protocol ProfileRepository {
    func current() throws -> PlayerProfile
}

struct SwiftDataProfileRepository: ProfileRepository {
    let context: ModelContext

    func current() throws -> PlayerProfile {
        let profiles = try context.fetch(FetchDescriptor<PlayerProfile>())
        if let p = profiles.first { return p }
        let p = PlayerProfile()
        context.insert(p)
        try context.save()
        return p
    }
}