import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let category: Category

    var allTimeTxs: [Transaction]       { store.transactions(categoryId: category.id) }
    var allTimeTotal: Double            { allTimeTxs.reduce(0) { $0 + $1.netAmount } }
    var avgMonthly: Double              { store.averageMonthlySpend(categoryId: category.id) }
    var chartData: [(month: Date, amount: Double)] { store.monthlySpend(categoryId: category.id, months: 6) }
    var maxChartAmount: Double          { chartData.map(\.amount).max() ?? 1 }
    var hasChartData: Bool              { chartData.contains { $0.amount > 0 } }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.18))
                                    .frame(width: 72, height: 72)
                                Text(category.icon)
                                    .font(.system(size: 34))
                            }
                            VStack(spacing: 6) {
                                Text(category.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(DS.text)
                                Text("All time spending")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.textSub)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 28)

                        // ── Stats row
                        HStack(spacing: 12) {
                            StatChip(
                                label: "Total spent",
                                value: allTimeTotal,
                                color: DS.red
                            )
                            StatChip(
                                label: "Avg / month",
                                value: avgMonthly,
                                color: category.color
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                        // ── Bar chart
                        SectionLabel(title: "Last 6 months")

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DS.card)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.cardBorder, lineWidth: 1))

                            if !hasChartData {
                                EmptyStateView(message: "No spending history")
                            } else {
                                VStack(spacing: 12) {
                                    GeometryReader { geo in
                                        HStack(alignment: .bottom, spacing: 8) {
                                            ForEach(chartData, id: \.month) { entry in
                                                let isCurrentMonth = Calendar.current.isDate(entry.month, equalTo: Date(), toGranularity: .month)
                                                let frac = maxChartAmount > 0 ? entry.amount / maxChartAmount : 0
                                                let barH = max(frac * (geo.size.height - 4), entry.amount > 0 ? 4 : 2)

                                                VStack(spacing: 0) {
                                                    Spacer(minLength: 0)
                                                    RoundedRectangle(cornerRadius: 5)
                                                        .fill(
                                                            isCurrentMonth
                                                                ? category.color
                                                                : category.color.opacity(0.45)
                                                        )
                                                        .frame(height: barH)
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                    .frame(height: 90)

                                    // X-axis labels
                                    HStack(spacing: 8) {
                                        ForEach(chartData, id: \.month) { entry in
                                            let isCurrentMonth = Calendar.current.isDate(entry.month, equalTo: Date(), toGranularity: .month)
                                            Text(entry.month.shortMonthYear)
                                                .font(.system(size: 10, weight: isCurrentMonth ? .semibold : .regular))
                                                .foregroundStyle(isCurrentMonth ? category.color : DS.textSub)
                                                .frame(maxWidth: .infinity)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                }
                                .padding(16)
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Transactions
                        SectionLabel(title: "All transactions")

                        if allTimeTxs.isEmpty {
                            EmptyStateView(message: "No transactions yet")
                                .padding(.horizontal, 20)
                        } else {
                            GroupedListCard {
                                ForEach(Array(allTimeTxs.enumerated()), id: \.element.id) { idx, tx in
                                    TransactionRow(transaction: tx, isLast: idx == allTimeTxs.count - 1)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DS.textSub)
            Text(value, format: .currency(code: DS.currencyCode))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.cardBorder, lineWidth: 1))
    }
}
