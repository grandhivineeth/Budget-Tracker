import SwiftUI

// MARK: - Design System
enum DS {
    // ── Adaptive backgrounds ──────────────────────────────────────────────────
    // UIColor(dynamicProvider:) automatically picks the right shade when
    // preferredColorScheme(.light/.dark) is set anywhere in the view hierarchy.
    static let bg = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#0A0A0F")
            : UIColor(hex: "#F2F2F7")
    })
    static let surface = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#111118")
            : UIColor(hex: "#E5E5EA")
    })
    static let card = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#1C1C1E")
            : UIColor(hex: "#FFFFFF")
    })
    static let cardBorder = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.07)
            : UIColor(white: 0, alpha: 0.08)
    })

    // ── Adaptive text ─────────────────────────────────────────────────────────
    static let text = Color(UIColor {
        $0.userInterfaceStyle == .dark ? .white : .black
    })
    static let textSub = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#8A8A9A")
            : UIColor(hex: "#636366")
    })
    static let textHint = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(hex: "#3A3A4A")
            : UIColor(hex: "#AEAEB2")
    })

    // ── Accent colors (same in both modes) ───────────────────────────────────
    static let red    = Color(hex: "#FF453A")
    static let green  = Color(hex: "#32D74B")
    static let blue   = Color(hex: "#4B8BFF")
    static let purple = Color(hex: "#9B7BFF")

    static let grad1  = Color(hex: "#4B8BFF")
    static let grad2  = Color(hex: "#9B7BFF")

    // ── Pill / tab-bar tokens ─────────────────────────────────────────────────
    /// Fill for the *selected* tab pill
    static let pillSelectedBg = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.13)
            : UIColor(white: 0, alpha: 0.07)
    })
    /// Border for the *selected* tab pill
    static let pillSelectedBorder = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.18)
            : UIColor(white: 0, alpha: 0.20)
    })
    /// Border for *unselected* tab pills — the visible differentiator
    static let pillUnselectedBorder = Color(UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.13)
    })

    /// Currency code read from user preference — use this everywhere instead of hardcoding "USD"
    static var currencyCode: String {
        UserDefaults.standard.string(forKey: "defaultCurrency") ?? "USD"
    }
}

// MARK: - HomeView
struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @State private var tab: HomeTab = .overview

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    AppPageHeader(pageTitle: "Home", selected: $tab)
                    switch tab {
                    case .overview: HomeOverviewTab(tab: $tab)
                    case .netWorth: NetWorthDetailTab(tab: $tab)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

enum HomeTab: String, CaseIterable {
    case overview = "Overview"
    case netWorth = "Net worth"
}


// MARK: - Overview Tab
struct HomeOverviewTab: View {
    @EnvironmentObject var store: DataStore
    @Binding var tab: HomeTab

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                NetWorthCard(onHeaderTap: { tab = .netWorth })
                SpentLast7DaysCard()
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Net Worth Detail Tab
struct NetWorthDetailTab: View {
    @EnvironmentObject var store: DataStore
    @Binding var tab: HomeTab

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                NetWorthCard()
                AssetsLiabilitiesCharts()
                NetWorthHistoryTile()
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Assets & Liabilities Consolidated Charts
struct AssetsLiabilitiesCharts: View {
    @EnvironmentObject var store: DataStore

    var total: Double { store.totalAssets + store.totalLiabilities }
    var assetRatio: Double      { total > 0 ? min(store.totalAssets      / total, 1) : 0 }
    var liabilityRatio: Double  { total > 0 ? min(store.totalLiabilities / total, 1) : 0 }

    var body: some View {
        HStack(spacing: 12) {
            ConsolidatedBarTile(
                title: "Assets",
                amount: store.totalAssets,
                ratio: assetRatio,
                color: DS.green,
                icon: "arrow.up.right.circle.fill"
            )
            ConsolidatedBarTile(
                title: "Liabilities",
                amount: store.totalLiabilities,
                ratio: liabilityRatio,
                color: DS.red,
                icon: "arrow.down.right.circle.fill"
            )
        }
    }
}

struct ConsolidatedBarTile: View {
    let title: String
    let amount: Double
    let ratio: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textSub)
                    .tracking(0.7)
            }

            Text(amount, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(amount > 0 ? color : DS.textHint)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * ratio, height: 8)
                        .animation(.easeOut(duration: 0.6), value: ratio)
                }
            }
            .frame(height: 8)

            Text(amount > 0 ? String(format: "%.0f%%", ratio * 100) + " of total" : "None added")
                .font(.system(size: 11))
                .foregroundStyle(DS.textHint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }
}

// MARK: - Net Worth History Tile
struct NetWorthHistoryTile: View {
    @EnvironmentObject var store: DataStore

    // Reverse so most-recent is at top
    var snapshots: [NetWorthSnapshot] { store.netWorthSnapshots.reversed() }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("HISTORY")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.textSub)
                    .tracking(0.8)
                Spacer()
                Text("\(snapshots.count) check-in\(snapshots.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textHint)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            if snapshots.isEmpty {
                Text("No history yet — update your balances in Manager.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textSub)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, snap in
                        let prev = idx < snapshots.count - 1 ? snapshots[idx + 1] : nil
                        let delta = prev.map { snap.netWorth - $0.netWorth }
                        let isLast = idx == snapshots.count - 1

                        HStack(spacing: 14) {
                            // Timeline dot + line
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(delta.map { $0 >= 0 ? DS.green : DS.red } ?? DS.blue)
                                    .frame(width: 9, height: 9)
                                if !isLast {
                                    Rectangle()
                                        .fill(DS.cardBorder)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 9)
                            .padding(.vertical, 4)

                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(Self.dateFmt.string(from: snap.date))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(DS.text)
                                    Spacer()
                                    Text(snap.netWorth, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(DS.text)
                                }

                                if let d = delta {
                                    HStack(spacing: 4) {
                                        Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(abs(d), format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                        if let p = prev, p.netWorth > 0 {
                                            Text("(\(String(format: "%+.1f%%", (d / p.netWorth) * 100)))")
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(d >= 0 ? DS.green : DS.red)
                                } else {
                                    Text("First check-in")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.textHint)
                                }
                            }
                            .padding(.vertical, 14)
                        }
                        .padding(.leading, 18)
                        .padding(.trailing, 18)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }
}

// MARK: - Net Worth Card
struct NetWorthCard: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedPeriod: String = "1M"
    @State private var showManager = false
    var onHeaderTap: (() -> Void)? = nil
    let periods = ["1W", "1M", "3M", "YTD", "ALL"]
    var isEmpty: Bool { store.netWorthAccounts.isEmpty && store.splitEntries.isEmpty }

    var filteredSnapshots: [NetWorthSnapshot] {
        let all = store.netWorthSnapshots
        guard !all.isEmpty else { return [] }
        let now = Date()
        let cal = Calendar.current
        let cutoff: Date
        switch selectedPeriod {
        case "1W":  cutoff = cal.date(byAdding: .day,   value: -7,   to: now) ?? now
        case "1M":  cutoff = cal.date(byAdding: .month, value: -1,   to: now) ?? now
        case "3M":  cutoff = cal.date(byAdding: .month, value: -3,   to: now) ?? now
        case "YTD": cutoff = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        default:    return all
        }
        let filtered = all.filter { $0.date >= cutoff }
        return filtered.isEmpty ? all : filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack(alignment: .center) {
                Button { onHeaderTap?() } label: {
                    HStack(spacing: 4) {
                        Text("NET WORTH")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.textSub)
                            .tracking(0.8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(onHeaderTap != nil ? DS.textHint : Color.clear)
                    }
                }
                .buttonStyle(.plain)
                .disabled(onHeaderTap == nil)

                Spacer()

                Button { showManager = true } label: {
                    Text("Manage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)

            // Amount + breakdown + Manage button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.netWorth, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 38, weight: .bold))
                        .tracking(-1)
                        .foregroundStyle(store.netWorth >= 0 ? DS.text : DS.red)
                    if isEmpty {
                        Text("Tap + to add accounts")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textSub)
                    } else {
                        HStack(spacing: 6) {
                            Circle().fill(DS.green).frame(width: 5, height: 5)
                            Text(store.totalAssets, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                .foregroundStyle(DS.green)
                            Text("·").foregroundStyle(DS.textHint)
                            Circle().fill(DS.red).frame(width: 5, height: 5)
                            Text(store.totalLiabilities, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                .foregroundStyle(DS.red)
                        }
                        .font(.system(size: 12))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            // Graph — real or placeholder
            NetWorthLineGraph(snapshots: filteredSnapshots)
                .frame(height: 130)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

            // Period selector
            HStack(spacing: 6) {
                ForEach(periods, id: \.self) { p in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedPeriod = p }
                    } label: {
                        Text(p)
                            .font(.system(size: 13, weight: selectedPeriod == p ? .semibold : .regular))
                            .foregroundStyle(selectedPeriod == p ? DS.text : DS.textSub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedPeriod == p ? Color.white.opacity(0.1) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)

            Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 18)

            // Add account CTA
            Button { showManager = true } label: {
                Text("Add account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.cardBorder, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
        .sheet(isPresented: $showManager) { ManagerView(isSheet: true) }
    }
}

/// MARK: - Net Worth Line Graph
import Charts

struct NetWorthLineGraph: View {
    let snapshots: [NetWorthSnapshot]

    var hasData: Bool { snapshots.count >= 2 }

    var body: some View {
        if hasData {
            Chart {
                ForEach(snapshots) { snap in
                    LineMark(
                        x: .value("Date",      snap.date),
                        y: .value("Net Worth", snap.netWorth)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [DS.blue, DS.purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date",      snap.date),
                        y: .value("Net Worth", snap.netWorth)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.blue.opacity(0.18), DS.purple.opacity(0.05), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        } else {
            ZStack {
                // Decorative faint curve
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    Path { path in
                        let pts: [CGPoint] = [
                            CGPoint(x: 0,        y: h * 0.8),
                            CGPoint(x: w * 0.2,  y: h * 0.75),
                            CGPoint(x: w * 0.45, y: h * 0.55),
                            CGPoint(x: w * 0.7,  y: h * 0.35),
                            CGPoint(x: w,        y: h * 0.2),
                        ]
                        path.move(to: pts[0])
                        for i in 1..<pts.count {
                            let cp1 = CGPoint(x: (pts[i-1].x + pts[i].x) / 2, y: pts[i-1].y)
                            let cp2 = CGPoint(x: (pts[i-1].x + pts[i].x) / 2, y: pts[i].y)
                            path.addCurve(to: pts[i], control1: cp1, control2: cp2)
                        }
                    }
                    .stroke(DS.textHint, lineWidth: 1.5)
                }

                VStack(spacing: 5) {
                    Text("No history yet.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.text)
                    Text("Add or update accounts in Manager to start tracking.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textSub)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#242428"))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Spent Last 7 Days Card
struct SpentLast7DaysCard: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var nav: NavState

    var total: Double       { store.spentLast7Days() }
    var recentTxs: [Transaction] { Array(store.transactionsLast7Days().prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Button { nav.mainTab = "Spend" } label: {
                HStack(spacing: 4) {
                    Text("SPENT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.textSub)
                        .tracking(0.8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.textHint)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Total
            Text(total, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 38, weight: .bold))
                .tracking(-1)
                .foregroundStyle(DS.text)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

            // 7-day mini strip
            SevenDayMiniStrip()
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            // Recent transactions
            if !recentTxs.isEmpty {
                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 18).padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(Array(recentTxs.enumerated()), id: \.element.id) { idx, tx in
                        TxListRow(transaction: tx, isFirst: idx == 0, isLast: idx == recentTxs.count - 1)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }
}

// MARK: - 7-Day Mini Strip
struct SevenDayMiniStrip: View {
    @EnvironmentObject var store: DataStore

    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let weekdayLabel: String
        let dayNumber: String
        let amount: Double
    }

    var days: [DayData] {
        let cal    = Calendar.current
        let wdShort = ["", "S", "M", "T", "W", "T", "F", "S"]
        return stride(from: 6, through: 0, by: -1).map { offset in
            let date    = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let weekday = cal.component(.weekday, from: date)
            let dayNum  = String(cal.component(.day, from: date))
            let total   = store.transactions
                .filter { cal.isDate($0.date, inSameDayAs: date) && !$0.isIncome }
                .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
            return DayData(date: date, weekdayLabel: wdShort[weekday], dayNumber: dayNum, amount: total)
        }
    }

    var maxAmount: Double { days.map(\.amount).max().flatMap { $0 > 0 ? $0 : nil } ?? 1 }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { day in
                let intensity = day.amount / maxAmount
                let isToday   = Calendar.current.isDateInToday(day.date)
                let hasSpend  = day.amount > 0

                VStack(spacing: 5) {
                    Text(day.weekdayLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isToday ? DS.blue : DS.textSub)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasSpend
                                  ? DS.blue.opacity(0.25 + intensity * 0.65)
                                  : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isToday ? DS.blue.opacity(0.7) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        Text(day.dayNumber)
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? DS.blue : (hasSpend ? DS.text : DS.textSub))
                    }
                    .frame(height: 32)

                    Text(hasSpend ? "$\(Int(day.amount))" : "$0")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(hasSpend ? DS.textSub : DS.textHint)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Full 7-Day Calendar Grid
struct SevenDayCalendarGrid: View {
    @EnvironmentObject var store: DataStore

    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let dayNum: String
        let weekday: String
        let amount: Double
    }

    var days: [DayData] {
        let cal = Calendar.current
        let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return stride(from: 6, through: 0, by: -1).map { offset in
            let date   = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let dayNum = String(cal.component(.day, from: date))
            let wd     = cal.component(.weekday, from: date) - 1
            let total  = store.transactions
                .filter { cal.isDate($0.date, inSameDayAs: date) && !$0.isIncome }
                .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
            return DayData(date: date, dayNum: dayNum, weekday: weekdayLabels[wd], amount: max(0, total))
        }
    }

    var maxAmount: Double { days.map(\.amount).max().flatMap { $0 > 0 ? $0 : nil } ?? 1 }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                let intensity = day.amount / maxAmount
                let isToday   = Calendar.current.isDateInToday(day.date)

                VStack(spacing: 6) {
                    Text(day.weekday)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.textSub)

                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(day.amount > 0
                                  ? DS.blue.opacity(0.15 + intensity * 0.55)
                                  : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isToday ? DS.blue : DS.cardBorder, lineWidth: isToday ? 1.5 : 1)
                            )

                        VStack(spacing: 3) {
                            Text(day.dayNum)
                                .font(.system(size: 13, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? DS.blue : DS.text)

                            if day.amount > 0 {
                                Text("$\(Int(day.amount))")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(DS.textSub)
                            } else {
                                Circle().fill(DS.textHint).frame(width: 3, height: 3)
                            }
                        }
                    }
                    .frame(height: 56)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.cardBorder, lineWidth: 1))
    }
}

// MARK: - Category Spend Card
struct CategorySpendCard: View {
    let category: Category
    let amount: Double
    let totalNet: Double

    var pct: Double { totalNet > 0 ? amount / totalNet : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(category.icon)
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11).fill(category.color.opacity(0.18)))
                Spacer()
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(category.color.opacity(0.15)))
            }
            .padding(.bottom, 14)

            Text(category.name)
                .font(.system(size: 12))
                .foregroundStyle(DS.textSub)
                .lineLimit(1)
                .padding(.bottom, 4)

            Text(amount, format: .currency(code: DS.currencyCode))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.text)
        }
        .padding(16)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(category.color.opacity(0.22), lineWidth: 1))
    }
}

// MARK: - Action Tile
struct ActionTile: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(DS.surface))
                .overlay(Capsule().stroke(DS.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Page Header (used across all tabs)
struct AppPageHeader<Tab: RawRepresentable & CaseIterable & Hashable>: View
    where Tab.RawValue == String, Tab.AllCases: RandomAccessCollection {

    let pageTitle: String
    @Binding var selected: Tab
    var trailingButton: AnyView? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Budget Tracker")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(DS.text)
                        .tracking(-0.5)
                    Text(pageTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DS.textSub)
                }
                Spacer()
                trailingButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selected = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selected == tab ? .semibold : .regular))
                                .foregroundStyle(selected == tab ? DS.text : DS.textSub)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(selected == tab
                                    ? DS.pillSelectedBg
                                    : Color.clear))
                                .overlay(Capsule().stroke(selected == tab
                                    ? DS.pillSelectedBorder
                                    : DS.pillUnselectedBorder,
                                    lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Rectangle().fill(DS.cardBorder).frame(height: 1)
        }
    }
}

// MARK: - Shared Card Tile wrapper (matches Home card style)
struct PageTile<Content: View>: View {
    var header: String
    var chevron: Bool = true
    var onHeaderTap: (() -> Void)? = nil
    var trailingButton: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { onHeaderTap?() }) {
                    HStack(spacing: 4) {
                        Text(header.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.textSub)
                            .tracking(0.8)
                        if chevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DS.textHint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(onHeaderTap == nil)
                Spacer()
                trailingButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            content
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }
}

// MARK: - Shared Labels
struct NewsletterSectionLabel: View {
    let title: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textSub)
                .tracking(0.7)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }
}

// MARK: - Transaction Rows + Shared Components
struct TxListRow: View {
    @EnvironmentObject var store: DataStore
    let transaction: Transaction
    let isFirst: Bool
    let isLast: Bool

    var category: Category?           { store.category(for: transaction.categoryId) }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if transaction.isIncome {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DS.green)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: category?.icon ?? "questionmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(category?.color ?? DS.textSub)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill((category?.color ?? DS.textSub).opacity(0.15)))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.text)
                Text("\(category?.name ?? "") · \(transaction.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textSub)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if transaction.isIncome {
                    Text("+\(transaction.amountPaid, format: .currency(code: DS.currencyCode))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.green)
                    Text("Income")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.green.opacity(0.7))
                } else {
                    Text("-\(transaction.amountPaid, format: .currency(code: DS.currencyCode))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.red)
                    if transaction.amountBack > 0 {
                        Text("+\(transaction.amountBack, format: .currency(code: DS.currencyCode))")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.green)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.leading, 68)
            }
        }
    }
}

struct GroupedListCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(DS.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.cardBorder, lineWidth: 1))
    }
}

struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(DS.textHint)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DS.textSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DS.textSub)
            .tracking(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 10)
    }
}

struct TransactionRow: View {
    @EnvironmentObject var store: DataStore
    let transaction: Transaction
    var isLast: Bool = false

    var category: Category?           { store.category(for: transaction.categoryId) }

    var body: some View {
        HStack(spacing: 14) {
            Text(category?.icon ?? "❓")
                .font(.system(size: 15))
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(DS.surface))

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.text)
                Text("\(category?.name ?? "") · \(transaction.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textSub)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if transaction.isIncome {
                    Text("+\(transaction.amountPaid, format: .currency(code: DS.currencyCode))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.green)
                    Text("Income")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.green.opacity(0.7))
                } else {
                    Text("-\(transaction.amountPaid, format: .currency(code: DS.currencyCode))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.red)
                    if transaction.amountBack > 0 {
                        Text("+\(transaction.amountBack, format: .currency(code: DS.currencyCode))")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.green)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.leading, 68)
            }
        }
    }
}

struct AllTransactionsAllView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var selected: Transaction?

    var sorted: [Transaction] { store.transactions.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                if sorted.isEmpty {
                    EmptyStateView(message: "No transactions yet")
                } else {
                    ScrollView {
                        GroupedListCard {
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, tx in
                                TransactionRow(transaction: tx, isLast: idx == sorted.count - 1)
                                    .onTapGesture { selected = tx }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.blue)
                }
            }
            .sheet(item: $selected) { tx in TransactionFormView(transaction: tx) }
        }
        .preferredColorScheme(.dark)
    }
}
