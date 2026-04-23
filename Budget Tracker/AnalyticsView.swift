import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var store: DataStore

    var last3Months: [Date] {
        (0..<3).map { Date().startOfMonth().adding(months: -$0) }.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header (Apple News style)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textSub)
                                .padding(.top, 4)
                            Text("Analytics")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(DS.text)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 28)

                        // Month cards
                        SectionLabel(title: "Monthly summary")

                        VStack(spacing: 12) {
                            ForEach(Array(last3Months.enumerated()), id: \.offset) { idx, month in
                                MonthCard(month: month, index: idx)
                                    .padding(.horizontal, 20)
                            }
                        }

                        // Category breakdown
                        SectionLabel(title: "This month by category")

                        CategoryBreakdownCard(month: Date().startOfMonth())
                            .padding(.horizontal, 20)

                        Spacer(minLength: 110)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Month Card
struct MonthCard: View {
    @EnvironmentObject var store: DataStore
    let month: Date
    let index: Int

    var spent: Double    { store.totalPaid(for: month) }
    var received: Double { store.totalBack(for: month) }
    var net: Double      { spent - received }
    var txCount: Int     { store.transactions(for: month).count }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var accentColor: Color {
        [DS.blue, DS.purple, Color(hex: "#4CD9A0")][index % 3]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(DS.card)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.cardBorder, lineWidth: 1))

            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 18)
                .padding(.leading, 0)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 0) {
                // Month header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(month.monthYearString)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.text)
                        Text("\(txCount) transaction\(txCount == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textSub)
                    }
                    Spacer()
                    if isCurrentMonth {
                        Text("Current")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 16)

                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.bottom, 16)

                // Spent / Received
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Circle().fill(DS.red).frame(width: 6, height: 6)
                            Text("Spent")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textSub)
                        }
                        Text(spent, format: .currency(code: DS.currencyCode))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DS.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle().fill(DS.cardBorder).frame(width: 1, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Circle().fill(DS.green).frame(width: 6, height: 6)
                            Text("Received")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textSub)
                        }
                        Text(received, format: .currency(code: DS.currencyCode))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DS.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                }
                .padding(.bottom, 16)

                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.bottom, 12)

                HStack {
                    Text("Net spend")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.textSub)
                    Spacer()
                    Text(net, format: .currency(code: DS.currencyCode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(net > 0 ? DS.red : DS.green)
                }
            }
            .padding(20)
            .padding(.leading, 12)
        }
    }
}

// MARK: - Category Breakdown
struct CategoryBreakdownCard: View {
    @EnvironmentObject var store: DataStore
    let month: Date
    @State private var selectedCategory: Category?

    var breakdown: [(cat: Category, net: Double, pct: Double)] {
        let total = store.netSpent(for: month)
        return store.categories.compactMap { cat in
            let net = store.netSpent(categoryId: cat.id, month: month)
            guard net > 0 else { return nil }
            return (cat, net, total > 0 ? net / total : 0)
        }.sorted { $0.net > $1.net }
    }

    func trend(for cat: Category) -> (symbol: String, pct: Double, color: Color)? {
        let prior = month.adding(months: -1)
        let cur  = store.netSpent(categoryId: cat.id, month: month)
        let prev = store.netSpent(categoryId: cat.id, month: prior)
        guard prev > 0 else { return nil }
        let change = (cur - prev) / prev
        if abs(change) < 0.01 { return ("→", change, DS.textSub) }
        return change > 0
            ? ("↑", change, DS.red)
            : ("↓", abs(change), DS.green)
    }

    var body: some View {
        VStack(spacing: 0) {
            if breakdown.isEmpty {
                EmptyStateView(message: "No spending data this month")
            } else {
                ForEach(Array(breakdown.enumerated()), id: \.element.cat.id) { idx, item in
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            Text(item.cat.icon)
                                .font(.system(size: 15))
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 9).fill(DS.surface))

                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.cat.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(DS.text)
                                    Spacer()
                                    Text(item.net, format: .currency(code: DS.currencyCode))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.red)
                                    Text(String(format: "%.0f%%", item.pct * 100))
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.textSub)
                                        .frame(width: 36, alignment: .trailing)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(DS.surface).frame(height: 3)
                                        Capsule()
                                            .fill(item.cat.color)
                                            .frame(width: geo.size.width * item.pct, height: 3)
                                    }
                                }
                                .frame(height: 3)

                                if let t = trend(for: item.cat) {
                                    Text("\(t.symbol) \(String(format: "%.0f%%", t.pct * 100)) vs last month")
                                        .font(.system(size: 11))
                                        .foregroundStyle(t.color)
                                }
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedCategory = item.cat }

                        if idx < breakdown.count - 1 {
                            Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.leading, 66)
                        }
                    }
                }
            }
        }
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.cardBorder, lineWidth: 1))
        .sheet(item: $selectedCategory) { cat in
            CategoryDetailView(category: cat)
        }
    }
}
