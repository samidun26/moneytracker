import SwiftUI
import SwiftData

/// Payday Split — give every rupiah a job; what's left becomes the spending
/// money that refills the Tanggal Tua battery. After the prototype's
/// "Payday Split" sheet. The rules live in Services/PaydaySplit.swift and
/// what "Split it!" writes in Services/PaydayWriter.swift.
struct PaydaySplitView: View {
    let ledger: Ledger

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Toaster.self) private var toaster
    @Query(sort: \SplitBucket.order) private var buckets: [SplitBucket]

    @State private var amounts: [UUID: Int] = [:]
    @State private var stamped = false
    @State private var shakes = 0.0

    private var salary: Int { ledger.salary }
    private func amount(_ bucket: SplitBucket) -> Int { amounts[bucket.id] ?? bucket.amount }
    private var spending: Int { PaydaySplit.spendingMoney(salary: salary, buckets: buckets.map(amount)) }

    var body: some View {
        RetroSheet(title: "Payday Split", tint: Theme.titleColors[1], icon: PixelIconData.briefcase, closeLabel: "Close payday split", onClose: { dismiss() }) {
            if salary <= 0 {
                noSalary
            } else {
                splitter
            }
        }
        .overlay {
            if stamped {
                StampView(text: "Allocated", ink: Theme.greenInk, tilt: -5, size: .large)
            }
        }
    }

    private var noSalary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set your monthly salary in Settings first, then Duit can help you split it.")
                .font(.plex(13))
                .foregroundStyle(Theme.ink2)
            Button("OK") { dismiss() }
                .buttonStyle(RetroButtonStyle(kind: .primary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var splitter: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LCDStatBox(
                    caption: "Salary · \(DateHelpers.formatPayday(ledger.period.start))",
                    value: CurrencyFormatter.formatRp(salary)
                )
                Text("Give every rupiah a job. Whatever is left becomes your spending money and refills the battery.")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)

                VStack(spacing: 16) {
                    ForEach(buckets, id: \.id) { bucket in row(bucket) }
                }
                .padding(.top, 4)

                spendBox

                HStack(spacing: 14) {
                    Spacer()
                    Button("Later") { dismiss() }
                        .buttonStyle(RetroButtonStyle())
                    Button("Split it!", action: confirm)
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                        .disabled(stamped)
                }
                .padding(.trailing, 4)
            }
            .padding(14)
            .modifier(ShakeEffect(shakes: shakes))
        }
    }

    private func row(_ bucket: SplitBucket) -> some View {
        HStack(spacing: 10) {
            PixelTile(rects: bucket.icon, color: bucket.color.color, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(bucket.name)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(CurrencyFormatter.formatRp(amount(bucket)))
                    .font(.plex(11.5))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("-") { amounts[bucket.id] = PaydaySplit.stepped(amount(bucket), by: -PaydaySplit.step) }
                .buttonStyle(RetroButtonStyle())
                .frame(width: 44)
                .accessibilityLabel("Decrease \(bucket.name) by \(CurrencyFormatter.formatRp(PaydaySplit.step))")
            Button("+") { amounts[bucket.id] = PaydaySplit.stepped(amount(bucket), by: PaydaySplit.step) }
                .buttonStyle(RetroButtonStyle())
                .frame(width: 44)
                .accessibilityLabel("Increase \(bucket.name) by \(CurrencyFormatter.formatRp(PaydaySplit.step))")
        }
        .accessibilityElement(children: .contain)
    }

    private var spendBox: some View {
        let over = spending < 0
        let perDay = PaydaySplit.perDay(spending: spending, daysUntilNextPayday: ledger.period.daysLeft)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Spending money")
                .font(.plex(11, .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            Text(CurrencyFormatter.formatRp(spending))
                .font(.pixel(24))
                .foregroundStyle(over ? Theme.negative : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(over
                ? "Over by \(CurrencyFormatter.formatRp(-spending)). Lower something above before you split."
                : "≈ \(CurrencyFormatter.formatRp(perDay)) a day until \(DateHelpers.formatPayday(ledger.period.nextPayday)).")
                .font(.plex(12.5))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroSunk()
        .accessibilityElement(children: .combine)
    }

    // MARK: Confirm

    private func confirm() {
        guard !stamped else { return }
        if spending < 0 {
            if !reduceMotion {
                withAnimation(.linear(duration: 0.45)) { shakes += 3 }
            }
            return
        }
        let plan = buckets.map { (id: $0.id, amount: amount($0)) }
        let result = spending
        let outcome = PaydayWriter.confirm(salary: salary, buckets: plan, spendingMoney: result, ledger: ledger, in: context)
        stamped = true
        let toaster = toaster
        let close = dismiss
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            close()
            toaster.show(outcome.salaryTransactionID != nil
                ? "Salary logged. Spending money: \(CurrencyFormatter.formatRpCompact(result))"
                : "Spending money: \(CurrencyFormatter.formatRpCompact(result))")
        }
    }
}

/// A short left-right wobble for a refused action (the prototype's `.shake`).
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: Double

    var animatableData: Double {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * CGFloat(sin(shakes * .pi * 2)), y: 0))
    }
}
