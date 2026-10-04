import SwiftUI

/// The profile chip in the app bar: a colored square and the open profile's
/// name. Tap it to switch. It is always there (even with one profile) so the
/// feature can be found, and its color is a constant reminder of whose money
/// a new entry will go into.
struct ProfilePill: View {
    var profile: Profile
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(ProfileSwatch.color(profile.swatch).color)
                    .frame(width: 10, height: 10)
                    .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                Text(profile.name)
                    .font(.plex(12, .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .leading)
                Text("\u{25BE}")
                    .font(.plex(11))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 8)
            .frame(minHeight: 30)
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile: \(profile.name)")
        .accessibilityHint("Switch profile")
    }
}

enum ProfileEditTarget: Identifiable {
    case new
    case existing(Profile)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let profile): profile.id.uuidString
        }
    }
}

/// Every profile, to switch between them, with a button to add another.
struct ProfileSwitcherView: View {
    @Environment(ProfileStores.self) private var stores
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ProfileEditTarget?

    var body: some View {
        RetroSheet(title: "Profiles", tint: Theme.titleColors[3], icon: PixelIconData.family, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A profile is a separate set of money: its own wallets, transactions, budgets, bills, salary and payday. Nothing in one shows up in another. Look and lock settings are shared.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)

                    VStack(spacing: 0) {
                        ForEach(Array(stores.profiles.enumerated()), id: \.element.id) { index, profile in
                            if index > 0 { DottedDivider() }
                            row(profile)
                        }
                    }
                    .retroSunk()

                    let full = stores.profiles.count >= ProfileRegistry.maxProfiles
                    Button("New profile") { editing = .new }
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                        .disabled(full)
                        .opacity(full ? 0.5 : 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                    if full {
                        Text(ProfileError.tooMany.message)
                            .font(.plex(12))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .padding(14)
            }
        }
        .sheet(item: $editing) { target in
            ProfileEditorView(target: target)
        }
    }

    private func row(_ profile: Profile) -> some View {
        let isOpen = profile.id == stores.active.id
        return HStack(spacing: 0) {
            Button { open(profile) } label: {
                HStack(spacing: 10) {
                    PixelTile(rects: PixelIconData.family, color: ProfileSwatch.color(profile.swatch).color, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name)
                            .font(.plex(14, .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(isOpen ? "Open now" : "Tap to switch")
                            .font(.plex(11.5))
                            .foregroundStyle(Theme.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if isOpen {
                        Text("OPEN")
                            .font(.pixel(10))
                            .foregroundStyle(Theme.greenInk)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())
            .accessibilityLabel(profile.name)
            .accessibilityValue(isOpen ? "Open now" : "")
            .accessibilityHint(isOpen ? "" : "Switch to this profile")

            Button("Edit") { editing = .existing(profile) }
                .buttonStyle(RetroButtonStyle(small: true))
                .padding(.trailing, 8)
                .accessibilityLabel("Edit \(profile.name)")
        }
    }

    private func open(_ profile: Profile) {
        guard profile.id != stores.active.id else {
            dismiss()
            return
        }
        if stores.select(profile.id) {
            toaster.show("Switched to \(profile.name)")
        }
        dismiss()
    }
}

/// Add a profile, or rename / recolor / delete one.
struct ProfileEditorView: View {
    let target: ProfileEditTarget

    @Environment(ProfileStores.self) private var stores
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var swatch: Int
    @State private var error: ProfileError?
    @State private var alert: RetroAlertContent?

    init(target: ProfileEditTarget) {
        self.target = target
        switch target {
        case .new:
            _name = State(initialValue: "")
            _swatch = State(initialValue: 1)
        case .existing(let profile):
            _name = State(initialValue: profile.name)
            _swatch = State(initialValue: profile.swatch)
        }
    }

    private var cleanedName: String { ProfileRegistry.cleaned(name) }

    var body: some View {
        RetroSheet(
            title: isNew ? "New profile" : "Edit profile",
            tint: Theme.titleColors[3],
            icon: PixelIconData.family,
            closeLabel: "Close without saving",
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RetroTextField(
                        caption: "Name",
                        placeholder: "Us, Partner, Trip fund…",
                        text: $name,
                        maxLength: ProfileRegistry.maxNameLength
                    )
                    swatchPicker
                    if let error {
                        Text(error.message)
                            .font(.plex(12.5, .semibold))
                            .foregroundStyle(Theme.negative)
                    }
                    if isNew {
                        note("It starts empty, with the usual three wallets and categories. You'll switch to it right away.")
                    }
                    if case .existing(let profile) = target { manage(profile) }

                    HStack(spacing: 12) {
                        Spacer()
                        Button("Cancel") { dismiss() }
                            .buttonStyle(RetroButtonStyle())
                        Button(isNew ? "Add" : "Save", action: save)
                            .buttonStyle(RetroButtonStyle(kind: .primary))
                            .disabled(cleanedName.isEmpty)
                            .opacity(cleanedName.isEmpty ? 0.5 : 1)
                    }
                    .padding(.trailing, 4)
                }
                .padding(14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .retroAlert($alert)
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private var swatchPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color")
                .font(.plex(11, .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            HStack(spacing: 6) {
                ForEach(ProfileSwatch.all.indices, id: \.self) { index in
                    Button { swatch = index } label: {
                        Rectangle()
                            .fill(ProfileSwatch.all[index].color)
                            .frame(width: 28, height: 28)
                            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: swatch == index ? 3 : 1))
                            .frame(width: 34, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(index + 1)")
                    .accessibilityAddTraits(swatch == index ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func manage(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if profile.isOriginal {
                note("This is your first profile. It holds everything you had before profiles, so it can't be deleted; use Reset all data in Settings to empty it.")
            } else if profile.id == stores.active.id {
                note("To delete this profile, switch to another one first.")
            } else {
                Button("Delete profile…") { askDelete(profile) }
                    .buttonStyle(RetroButtonStyle(kind: .danger, small: true))
                note("Deleting erases every wallet, transaction, budget and bill in this profile for good. Your other profiles aren't touched.")
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.plex(12))
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        switch target {
        case .new:
            switch stores.add(name: name, swatch: swatch) {
            case .failure(let failure):
                error = failure
            case .success(let profile):
                stores.select(profile.id)
                toaster.show("Added \(profile.name)")
                dismiss()
            }
        case .existing(let profile):
            if let failure = stores.rename(profile.id, to: name) {
                error = failure
                return
            }
            stores.recolor(profile.id, swatch: swatch)
            toaster.show("Saved \(cleanedName)")
            dismiss()
        }
    }

    private func askDelete(_ profile: Profile) {
        let stores = stores
        let toaster = toaster
        alert = RetroAlertContent(
            title: "Delete \"\(profile.name)\"?",
            message: "This erases every wallet, transaction, budget and bill in \"\(profile.name)\" for good. It can't be undone. Export a CSV from it first if you want a copy. Your other profiles aren't touched.",
            icon: PixelIconData.caution,
            confirmLabel: "Delete profile",
            action: {
                if let failure = stores.remove(profile.id) {
                    toaster.show(failure.message)
                } else {
                    toaster.show("Deleted \(profile.name)")
                }
            }
        )
    }
}
