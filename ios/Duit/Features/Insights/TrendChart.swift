import SwiftUI

/// Six months of income and spending as paired bars, after the prototype's
/// hand-drawn chart: three grid lines, square bars, the chosen month
/// highlighted. Tap a month to read its numbers underneath.
struct TrendChart: View {
    var points: [Insights.TrendPoint]
    @Binding var selected: Int

    private let height: CGFloat = 176
    private let topInset: CGFloat = 8
    private let labelHeight: CGFloat = 22
    private let axisWidth: CGFloat = 42
    private let barWidth: CGFloat = 14

    private var plotHeight: CGFloat { height - topInset - labelHeight }
    private var axisMax: Double { Insights.chartMax(points) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach([0.0, 0.5, 1.0], id: \.self) { fraction in
                gridLine(fraction)
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: axisWidth)
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    column(index, point)
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
    }

    // MARK: Grid

    private func y(_ fraction: Double) -> CGFloat {
        topInset + plotHeight - CGFloat(fraction) * plotHeight
    }

    private func gridLine(_ fraction: Double) -> some View {
        let value = axisMax * fraction
        return ZStack(alignment: .topLeading) {
            Theme.grid
                .frame(height: 1)
                .padding(.leading, axisWidth)
                .offset(y: y(fraction))
            Text(fraction == 0 ? "0" : CurrencyFormatter.formatCompact(Int(value)))
                .font(.plex(10.5, .semibold))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 38, alignment: .trailing)
                .offset(y: y(fraction) - 7)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Columns

    private func barHeight(_ amount: Int) -> CGFloat {
        guard amount > 0, axisMax > 0 else { return 0 }
        return max(1, (CGFloat(Double(amount) / axisMax) * plotHeight).rounded())
    }

    private func column(_ index: Int, _ point: Insights.TrendPoint) -> some View {
        let on = index == selected
        return Button { selected = index } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    if on {
                        Theme.grid.padding(.horizontal, 2)
                    }
                    HStack(alignment: .bottom, spacing: 2) {
                        Rectangle().fill(Theme.incomeBar).frame(width: barWidth, height: barHeight(point.income))
                        Rectangle().fill(Theme.expenseBar).frame(width: barWidth, height: barHeight(point.expense))
                    }
                }
                .frame(height: height - topInset + 4 - labelHeight)
                Text(point.month.shortName)
                    .font(.plex(11, .semibold))
                    .underline(on)
                    .foregroundStyle(on ? Theme.ink : Theme.ink2)
                    .frame(height: labelHeight)
            }
            .padding(.top, topInset - 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(point.month.shortName) \(point.month.year): income \(CurrencyFormatter.formatRp(point.income)), spending \(CurrencyFormatter.formatRp(point.expense))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
