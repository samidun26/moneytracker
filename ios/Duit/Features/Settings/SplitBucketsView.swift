import SwiftUI
import SwiftData

/// Settings → Payday split buckets: the jobs you give your salary before the
/// rest becomes spending money (rent, savings, family…). Names are edited
/// here; the amounts are set each payday in the split itself.
struct SplitBucketsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SplitBucket.order) private var buckets: [SplitBucket]
    @State private var alert: RetroAlertContent?

    var body: some View {
        RetroSheet(title: "Split buckets", tint: Theme.titleColors[1], icon: PixelIconData.briefcase, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("The jobs you give your salary on payday. Whatever is left becomes spending money. You set the amounts in the split itself.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)

                    VStack(spacing: 10) {
                        ForEach(buckets, id: \.id) { bucket in
                            BucketRow(bucket: bucket) { askDelete(bucket) }
                        }
                    }

                    Button("Add a bucket", action: add)
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                .padding(14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .retroAlert($alert)
    }

    private func add() {
        let next = (buckets.map(\.order).max() ?? -1) + 1
        context.insert(SplitBucket(name: "New bucket", color: .gray, iconKey: "box", amount: 0, order: next))
        try? context.save()
    }

    private func askDelete(_ bucket: SplitBucket) {
        let ctx = context
        let id = bucket.id
        alert = RetroAlertContent(
            title: "Delete “\(bucket.name)”?",
            message: "It only removes this slot from the split. Nothing you logged changes.",
            icon: PixelIconData.caution,
            confirmLabel: "Delete",
            action: {
                var descriptor = FetchDescriptor<SplitBucket>(predicate: #Predicate { $0.id == id })
                descriptor.fetchLimit = 1
                if let doomed = try? ctx.fetch(descriptor).first {
                    ctx.delete(doomed)
                    try? ctx.save()
                }
            }
        )
    }
}

private struct BucketRow: View {
    @Bindable var bucket: SplitBucket
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PixelTile(rects: bucket.icon, color: bucket.color.color, size: 36)
            TextField("Name", text: $bucket.name, prompt: Text("Name").foregroundStyle(Theme.ink2))
                .font(.plex(15))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .retroSunk()
                .onChange(of: bucket.name) {
                    if bucket.name.count > 30 { bucket.name = String(bucket.name.prefix(30)) }
                }
            Button(action: onDelete) {
                Text("x")
                    .font(.pixel(12))
                    .foregroundStyle(Theme.negative)
                    .frame(width: 24, height: 24)
                    .background(Theme.face)
                    .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(bucket.name)")
        }
    }
}
