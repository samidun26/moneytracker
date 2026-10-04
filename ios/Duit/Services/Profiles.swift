import Foundation

/// One separate set of money: "Mine", "Us", a trip fund. A profile has its own
/// database file (wallets, transactions, budgets, bills, Payday Split buckets)
/// and its own payday / salary settings, so nothing in one can show up in, or
/// change, another. See `ProfileStores`.
struct Profile: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    /// Which of `ProfileSwatch.all` colors it.
    var swatch: Int
    /// The database file's name. nil is the app's original database
    /// (`default.store`): the profile all pre-existing data became, with
    /// nothing moved or copied.
    var storeName: String?

    var isOriginal: Bool { storeName == nil }
}

enum ProfileError: Error, Equatable {
    case emptyName
    case nameTaken
    case tooMany
    case notFound
    case cannotRemoveActive
    case cannotRemoveOriginal

    var message: String {
        switch self {
        case .emptyName: "Give the profile a name."
        case .nameTaken: "Another profile already has that name."
        case .tooMany: "That's the most profiles Duit keeps (\(ProfileRegistry.maxProfiles)). Delete one you don't use first."
        case .notFound: "That profile doesn't exist any more."
        case .cannotRemoveActive: "Switch to another profile first; the one you're in can't be deleted."
        case .cannotRemoveOriginal: "The first profile can't be deleted. Use Reset all data in Settings to empty it."
        }
    }
}

/// The list of profiles and which one is open: small, so it lives in
/// UserDefaults as JSON (the profiles' own data is in their databases). Pure
/// value logic, so every rule is unit-tested.
struct ProfileRegistry: Equatable {
    static let maxProfiles = 6
    static let maxNameLength = 14
    static let listKey = "profiles.list"
    static let activeKey = "profiles.active"

    private(set) var profiles: [Profile]
    private(set) var activeID: UUID

    /// The original profile always has this id, so it is the same one on every
    /// launch even before the list has ever been saved.
    static let originalID = UUID(uuidString: "00000000-0000-0000-0000-00000000D017") ?? UUID()

    /// A fresh install, or the first launch after profiles arrive: one profile
    /// that *is* the existing data.
    static func firstRun() -> ProfileRegistry {
        let first = Profile(id: originalID, name: "Mine", swatch: 0, storeName: nil)
        return ProfileRegistry(profiles: [first], activeID: first.id)
    }

    var active: Profile { profiles.first { $0.id == activeID } ?? profiles[0] }

    func profile(_ id: UUID) -> Profile? { profiles.first { $0.id == id } }

    // MARK: Saving

    static func load(from defaults: UserDefaults) -> ProfileRegistry {
        guard let data = defaults.data(forKey: listKey),
              let list = try? JSONDecoder().decode([Profile].self, from: data),
              list.contains(where: { $0.isOriginal }) else {
            return firstRun()
        }
        let saved = defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
        let active = list.first { $0.id == saved } ?? list.first { $0.isOriginal } ?? list[0]
        return ProfileRegistry(profiles: list, activeID: active.id)
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Self.listKey)
        }
        defaults.set(activeID.uuidString, forKey: Self.activeKey)
    }

    // MARK: Changes

    /// Trimmed, whitespace collapsed, cut to `maxNameLength`.
    static func cleaned(_ name: String) -> String {
        String(name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(maxNameLength))
            .trimmingCharacters(in: .whitespaces)
    }

    private func isTaken(_ name: String, except id: UUID?) -> Bool {
        profiles.contains { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Adds a profile (it does not switch to it).
    mutating func add(name: String, swatch: Int, id: UUID = UUID()) -> Result<Profile, ProfileError> {
        let name = Self.cleaned(name)
        guard !name.isEmpty else { return .failure(.emptyName) }
        guard profiles.count < Self.maxProfiles else { return .failure(.tooMany) }
        guard !isTaken(name, except: nil) else { return .failure(.nameTaken) }
        let profile = Profile(id: id, name: name, swatch: swatch, storeName: "profile-\(id.uuidString)")
        profiles.append(profile)
        return .success(profile)
    }

    mutating func rename(_ id: UUID, to name: String) -> ProfileError? {
        let name = Self.cleaned(name)
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return .notFound }
        guard !name.isEmpty else { return .emptyName }
        guard !isTaken(name, except: id) else { return .nameTaken }
        profiles[index].name = name
        return nil
    }

    mutating func recolor(_ id: UUID, swatch: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].swatch = swatch
    }

    @discardableResult
    mutating func select(_ id: UUID) -> Bool {
        guard profiles.contains(where: { $0.id == id }) else { return false }
        activeID = id
        return true
    }

    /// Takes a profile out of the list. The one that is open and the original
    /// can't be removed. Returns it, so its database can be deleted.
    mutating func remove(_ id: UUID) -> Result<Profile, ProfileError> {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return .failure(.notFound) }
        guard id != activeID else { return .failure(.cannotRemoveActive) }
        guard !profiles[index].isOriginal else { return .failure(.cannotRemoveOriginal) }
        return .success(profiles.remove(at: index))
    }
}

/// The colors a profile can wear (its dot in the app bar and in the list).
enum ProfileSwatch {
    static let all: [CategoryColor] = [.indigo, .pink, .green, .orange, .teal, .purple, .red, .yellow]

    static func color(_ index: Int) -> CategoryColor {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// Where a profile's own settings (payday day, salary, …) are kept.
enum ProfilePrefs {
    /// The original profile keeps using the standard defaults, so what was
    /// saved before profiles existed is still its settings. Every other profile
    /// gets a defaults file of its own.
    static func defaults(for profile: Profile) -> UserDefaults {
        guard !profile.isOriginal else { return .standard }
        return UserDefaults(suiteName: suiteName(for: profile)) ?? .standard
    }

    static func suiteName(for profile: Profile) -> String {
        "duit.profile.\(profile.id.uuidString)"
    }

    /// Forgets a deleted profile's settings.
    static func erase(_ profile: Profile) {
        guard !profile.isOriginal else { return }
        UserDefaults.standard.removePersistentDomain(forName: suiteName(for: profile))
    }
}
