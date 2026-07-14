import SwiftUI
import Charts

// MARK: - Spend Tab Enum
enum SpendTab: String, CaseIterable {
    case overview     = "Overview"
    case transactions = "Transactions"
    case breakdown    = "Breakdown & budget"
    case categories   = "Categories"
}

enum SpendChartMode { case line, calendar }

// MARK: - SpendView
struct SpendView: View {
    @EnvironmentObject var store: DataStore
    @State private var tab: SpendTab = .overview
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    AppPageHeader(
                        pageTitle: "Spend",
                        selected: $tab
                    )

                    switch tab {
                    case .overview:     SpendOverviewTab(tab: $tab)
                    case .breakdown:    SpendBreakdownTab()
                    case .transactions: SpendTransactionsTab()
                    case .categories:   SpendCategoriesTab()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdd) { TransactionFormView() }
        }
    }
}

// MARK: - Overview Tab
struct SpendOverviewTab: View {
    @Binding var tab: SpendTab
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                SpendThisMonthCard()
                SpendLatestTransactionsCard(tab: $tab)
                SpendExpenseCategoriesCard(tab: $tab)
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Spend This Month Card
struct SpendThisMonthCard: View {
    @EnvironmentObject var store: DataStore
    @State private var chartMode: SpendChartMode = .line
    @State private var showAdd = false
    @State private var calendarMonth: Date = Date().startOfMonth()
    @State private var selectedDate: Date? = nil
    @State private var categoryFilters: Set<UUID> = []   // empty = all categories

    private var currentMonth: Date { Date().startOfMonth() }
    private var prevMonth:    Date { currentMonth.adding(months: -1) }

    /// Categories that have any spend in the current or previous month (chip candidates).
    private var chartCategories: [Category] {
        store.categories.filter {
            store.netSpent(categoryId: $0.id, month: currentMonth) > 0
            || store.netSpent(categoryId: $0.id, month: prevMonth) > 0
        }
    }

    private var currentData: [(day: Int, cumulative: Double)] {
        store.cumulativeSpend(for: currentMonth, categoryIds: categoryFilters)
    }
    private var prevData: [(day: Int, cumulative: Double)] {
        store.cumulativeSpend(for: prevMonth, categoryIds: categoryFilters)
    }
    private var displayCurrentData: [(day: Int, cumulative: Double)] {
        let cal = Calendar.current
        let today = cal.component(.day, from: Date())
        let isThisMonth = cal.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
        return isThisMonth ? currentData.filter { $0.day <= today } : currentData
    }
    private var currentTotal: Double { displayCurrentData.last?.cumulative ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ──────────────────────────────────────────────
            HStack(alignment: .center) {
                Text("SPEND THIS MONTH")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textSub)
                    .tracking(0.8)
                Spacer()
                HStack(spacing: 6) {
                    chartToggleBtn(mode: .line,     icon: "chart.xyaxis.line")
                    chartToggleBtn(mode: .calendar, icon: "calendar")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // ── Amount ───────────────────────────────────────────────
            Text(currentTotal, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DS.text)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            // ── Legend (line mode only) ───────────────────────────────
            if chartMode == .line {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(DS.blue)
                            .frame(width: 20, height: 2)
                        Text(currentMonth.spendMonthName)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textSub)
                    }
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(DS.textSub)
                                    .frame(width: 4, height: 2)
                            }
                        }
                        Text(prevMonth.spendMonthName)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textSub)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            } else {
                // ── Calendar month nav ────────────────────────────────
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            calendarMonth = calendarMonth.adding(months: -1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.textSub)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(DS.surface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.cardBorder))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text(calendarMonth.spendMonthYearName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.text)
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            let next = calendarMonth.adding(months: 1)
                            if next <= Date().startOfMonth() { calendarMonth = next }
                        }
                    } label: {
                        let isCurrentMonth = Calendar.current.isDate(calendarMonth, equalTo: Date().startOfMonth(), toGranularity: .month)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isCurrentMonth ? DS.textHint : DS.textSub)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(DS.surface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.cardBorder))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }

            // ── Category filter chips ─────────────────────────────────
            if !chartCategories.isEmpty {
                categoryChips
            }

            // ── Chart ────────────────────────────────────────────────
            if chartMode == .line {
                SpendLineChart(
                    currentData: displayCurrentData,
                    prevData:    prevData
                )
                .frame(height: 200)
                .padding(.bottom, 18)
            } else {
                SpendCalendarHeatmap(month: calendarMonth, selectedDate: $selectedDate,
                                     categoryIds: categoryFilters)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
        .sheet(isPresented: $showAdd) { TransactionFormView() }
        .sheet(item: $selectedDate) { date in
            DayTransactionsSheet(date: date)
        }
    }

    // ── Category filter chips (multi-select) ──────────────────────────
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                let allActive = categoryFilters.isEmpty
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { categoryFilters.removeAll() }
                } label: {
                    Text("All")
                        .font(.system(size: 13, weight: allActive ? .semibold : .regular))
                        .foregroundStyle(allActive ? DS.text : DS.textSub)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            Capsule().fill(allActive ? DS.surface : Color.clear)
                                .overlay(Capsule().stroke(allActive ? DS.cardBorder : DS.textHint.opacity(0.3), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                ForEach(chartCategories) { c in
                    let active = categoryFilters.contains(c.id)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if active { categoryFilters.remove(c.id) }
                            else      { categoryFilters.insert(c.id) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: c.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(active ? .white : c.color)
                            Text(c.name)
                                .font(.system(size: 13, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? .white : DS.text)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            Capsule().fill(active ? c.color : Color.clear)
                                .overlay(Capsule().stroke(active ? c.color : DS.textHint.opacity(0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func chartToggleBtn(mode: SpendChartMode, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) { chartMode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(chartMode == mode ? DS.text : DS.textSub)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(chartMode == mode ? DS.surface : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(chartMode == mode ? DS.cardBorder : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spend Line Chart
struct SpendLineChart: View {
    let currentData: [(day: Int, cumulative: Double)]
    let prevData:    [(day: Int, cumulative: Double)]
    @State private var selectedDay: Int? = nil

    private var selectedPoint: (day: Int, cumulative: Double)? {
        guard let d = selectedDay, !currentData.isEmpty else { return nil }
        return currentData.min(by: { abs($0.day - d) < abs($1.day - d) })
    }
    private var selectedPrevPoint: (day: Int, cumulative: Double)? {
        guard let d = selectedDay, !prevData.isEmpty else { return nil }
        return prevData.min(by: { abs($0.day - d) < abs($1.day - d) })
    }
    private var currentMonthName: String { Date().spendMonthName }
    private var prevMonthName: String { Date().startOfMonth().adding(months: -1).spendMonthName }
    private var maxY: Double {
        let a = currentData.map(\.cumulative).max() ?? 0
        let b = prevData.map(\.cumulative).max() ?? 0
        return max(a, b, 50) * 1.15
    }

    var body: some View {
        Chart {
            ForEach(currentData, id: \.day) { pt in
                AreaMark(
                    x: .value("Day", pt.day),
                    yStart: .value("Base", 0),
                    yEnd:   .value("Amount", pt.cumulative)
                )
                .foregroundStyle(LinearGradient(
                    colors: [DS.blue.opacity(0.35), DS.blue.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.monotone)
            }
            ForEach(currentData, id: \.day) { pt in
                LineMark(x: .value("Day", pt.day), y: .value("Amount", pt.cumulative))
                    .foregroundStyle(by: .value("Series", "Current"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
            }
            ForEach(prevData, id: \.day) { pt in
                LineMark(x: .value("Day", pt.day), y: .value("Amount", pt.cumulative))
                    .foregroundStyle(by: .value("Series", "Previous"))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                    .interpolationMethod(.monotone)
            }
            if let pt = selectedPoint {
                RuleMark(x: .value("Day", pt.day))
                    .foregroundStyle(DS.cardBorder)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                PointMark(x: .value("Day", pt.day), y: .value("Amount", pt.cumulative))
                    .foregroundStyle(DS.blue).symbolSize(60)
                if let prev = selectedPrevPoint {
                    PointMark(x: .value("Day", prev.day), y: .value("Amount", prev.cumulative))
                        .foregroundStyle(DS.textSub).symbolSize(50)
                }
            }
        }
        .chartXSelection(value: $selectedDay)
        .chartForegroundStyleScale(["Current": DS.blue, "Previous": DS.textSub])
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: [1, 8, 15, 22, 29]) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.cardBorder)
                AxisValueLabel {
                    if let day = val.as(Int.self) {
                        Text(String(format: "%02d", day)).font(.system(size: 10)).foregroundStyle(DS.textSub)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.cardBorder)
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text("$\(Int(v))").font(.system(size: 9)).foregroundStyle(DS.textSub)
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxY)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let x = val.location.x - (proxy.plotFrame.map { geo[$0] }?.origin.x ?? 0)
                            if let day: Int = proxy.value(atX: x) {
                                selectedDay = day
                            }
                        }
                        .onEnded { _ in selectedDay = nil }
                    )
            }
        }
        .overlay(alignment: .top) {
            if let pt = selectedPoint {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Total expenses by day \(pt.day)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.text)
                    HStack {
                        Circle().fill(DS.blue).frame(width: 9, height: 9)
                        Text(currentMonthName).font(.system(size: 13)).foregroundStyle(DS.text)
                        Spacer()
                        Text(pt.cumulative, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.text)
                    }
                    if let prev = selectedPrevPoint {
                        HStack {
                            Circle().fill(DS.textSub).frame(width: 9, height: 9)
                            Text(prevMonthName).font(.system(size: 13)).foregroundStyle(DS.textSub)
                            Spacer()
                            Text(prev.cumulative, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.textSub)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#1E1E26")))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.cardBorder))
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 14)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: selectedDay)
        .padding(.horizontal, 14)
    }
}

// MARK: - Calendar Heatmap
struct SpendCalendarHeatmap: View {
    @EnvironmentObject var store: DataStore
    let month: Date
    @Binding var selectedDate: Date?
    var categoryIds: Set<UUID> = []

    private var dailyData: [(day: Int, amount: Double)] { store.dailySpend(for: month, categoryIds: categoryIds) }
    private var maxSpend: Double { max(dailyData.map(\.amount).max() ?? 1, 1) }
    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
    }
    private var firstWeekdayOffset: Int {
        var comps = Calendar.current.dateComponents([.year, .month], from: month)
        comps.day = 1
        let first = Calendar.current.date(from: comps) ?? month
        let wd = Calendar.current.component(.weekday, from: first)
        return (wd - 2 + 7) % 7
    }
    private func date(for day: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month], from: month)
        comps.day = day
        return Calendar.current.date(from: comps) ?? month
    }
    private func isSelected(_ day: Int) -> Bool {
        guard let sel = selectedDate else { return false }
        return Calendar.current.isDate(sel, equalTo: date(for: day), toGranularity: .day)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DS.textSub)
                        .frame(maxWidth: .infinity)
                }
            }
            let rows = Int(ceil(Double(firstWeekdayOffset + daysInMonth) / 7.0))
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7) { col in
                        let day = row * 7 + col - firstWeekdayOffset + 1
                        if day >= 1 && day <= daysInMonth {
                            let amt    = dailyData.first { $0.day == day }?.amount ?? 0
                            let intensity = amt / maxSpend
                            let sel    = isSelected(day)
                            let isToday = Calendar.current.isDateInToday(date(for: day))

                            Button {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    selectedDate = date(for: day)
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(sel
                                          ? DS.blue.opacity(0.85)
                                          : DS.blue.opacity(0.08 + intensity * 0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isToday && !sel ? DS.blue : Color.clear, lineWidth: 1.5)
                                    )
                                    .overlay(
                                        VStack(spacing: 1) {
                                            Text("\(day)")
                                                .font(.system(size: 9, weight: sel ? .bold : .medium))
                                                .foregroundStyle(sel ? .white : (intensity > 0.35 ? DS.text : DS.textSub))
                                            if amt > 0 {
                                                Text("$\(Int(amt))")
                                                    .font(.system(size: 7))
                                                    .foregroundStyle(sel ? .white.opacity(0.8) : DS.textSub)
                                            }
                                        }
                                    )
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 44).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day Transactions Sheet
struct DayTransactionsSheet: View {
    @EnvironmentObject var store: DataStore
    let date: Date
    @Environment(\.dismiss) private var dismiss

    private var transactions: [Transaction] {
        store.transactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private var totalSpend: Double {
        transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.expenseAmount }
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Summary bar
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Self.fmt.string(from: date))
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.textSub)
                                Text(totalSpend, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(DS.text)
                            }
                            Spacer()
                            Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.textSub)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(DS.surface))
                                .overlay(Capsule().stroke(DS.cardBorder))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        if transactions.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "tray")
                                    .font(.system(size: 28))
                                    .foregroundStyle(DS.textHint)
                                Text("No transactions this day")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.textSub)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(transactions.enumerated()), id: \.element.id) { idx, tx in
                                    TxDetailRow(tx: tx)
                                    if idx < transactions.count - 1 {
                                        Divider().background(DS.cardBorder).padding(.leading, 70)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
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
    }
}

// MARK: - Latest Transactions Card
struct SpendLatestTransactionsCard: View {
    @EnvironmentObject var store: DataStore
    @Binding var tab: SpendTab
    @State private var showAdd = false

    private var recent: [Transaction] {
        Array(store.transactions.sorted { $0.date > $1.date }.prefix(5))
    }

    var body: some View {
        PageTile(
            header: "Latest Transactions",
            chevron: true,
            onHeaderTap: { tab = .transactions },
            trailingButton: AnyView(
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.blue)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 9).fill(DS.surface))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(DS.cardBorder))
                }
                .buttonStyle(.plain)
            )
        ) {
            VStack(spacing: 0) {
                if recent.isEmpty {
                    Text("No transactions yet")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textSub)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, tx in
                        TxDetailRow(tx: tx)
                        if idx < recent.count - 1 {
                            Divider().background(DS.cardBorder).padding(.leading, 70)
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showAdd) { TransactionFormView() }
    }
}

// MARK: - Expense Categories Card
struct SpendExpenseCategoriesCard: View {
    @EnvironmentObject var store: DataStore
    @Binding var tab: SpendTab

    private var currentMonth: Date { Date().startOfMonth() }

    private struct CategorySlice: Identifiable {
        let id: UUID; let name: String; let icon: String
        let amount: Double; let chartColor: Color
    }

    private var slices: [CategorySlice] {
        store.categories.compactMap { cat -> CategorySlice? in
            let amt = store.netSpent(categoryId: cat.id, month: currentMonth)
            guard amt > 0 else { return nil }
            return CategorySlice(id: cat.id, name: cat.name, icon: cat.icon, amount: amt, chartColor: cat.color)
        }.sorted { $0.amount > $1.amount }
    }

    private var total: Double { slices.reduce(0) { $0 + $1.amount } }

    // Top 4 shown individually; the rest collapsed into "N others"
    private var topSlices: [CategorySlice]  { Array(slices.prefix(4)) }
    private var otherSlices: [CategorySlice] { Array(slices.dropFirst(4)) }
    private var otherTotal: Double { otherSlices.reduce(0) { $0 + $1.amount } }

    var body: some View {
        PageTile(
            header: "Expense Categories",
            chevron: true,
            onHeaderTap: { tab = .breakdown }
        ) {
            if slices.isEmpty {
                Text("No spend this month")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textSub)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    // Donut chart
                    ZStack {
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Amount", slice.amount),
                                innerRadius: .ratio(0.68),
                                angularInset: 2.5
                            )
                            .foregroundStyle(slice.chartColor)
                            .cornerRadius(4)
                        }
                        VStack(spacing: 2) {
                            Text(total, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DS.text)
                            Text("Total")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.textSub)
                        }
                    }
                    .frame(width: 130, height: 130)

                    // Legend
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(topSlices) { slice in
                            legendRow(
                                color: slice.chartColor,
                                label: slice.name,
                                pct: total > 0 ? slice.amount / total * 100 : 0
                            )
                        }
                        if !otherSlices.isEmpty {
                            legendRow(
                                color: DS.textSub,
                                label: "\(otherSlices.count) others",
                                pct: total > 0 ? otherTotal / total * 100 : 0
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private func legendRow(color: Color, label: String, pct: Double) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) • \(String(format: "%.1f", pct))%")
                .font(.system(size: 12))
                .foregroundStyle(DS.text)
                .lineLimit(1)
        }
    }
}

// MARK: - Transactions Tab
struct SpendTransactionsTab: View {
    @EnvironmentObject var store: DataStore
    @State private var sortOrder: TxSortOrder = .newest
    @State private var summaryExpanded = false
    @State private var showAdd    = false
    @State private var showFilter = false
    @State private var filter     = TxFilter()

    enum TxSortOrder: String, CaseIterable {
        case newest  = "Newest"
        case oldest  = "Oldest"
        case highest = "Highest"
        case lowest  = "Lowest"
    }

    // Apply filters then group by date
    private var filtered: [Transaction] {
        store.transactions.filter { tx in
            if let s = filter.startDate, tx.date < s { return false }
            if let e = filter.endDate,   tx.date > e { return false }
            if !filter.categoryIds.isEmpty,
               !filter.categoryIds.contains(tx.categoryId) { return false }
            if let lo = filter.minAmount, tx.amountPaid < lo { return false }
            if let hi = filter.maxAmount, tx.amountPaid > hi { return false }
            return true
        }
    }

    private struct MonthGroup: Identifiable {
        let id: Date
        var month: Date { id }
        let days: [(date: Date, txs: [Transaction])]
        var allTxs: [Transaction] { days.flatMap(\.txs) }
        var netExpense: Double { allTxs.filter { !$0.isIncome }.reduce(0) { $0 + $1.expenseAmount } }
    }

    @State private var expandedMonths: Set<Date> = [Date().startOfMonth()]

    private var groupedByMonth: [MonthGroup] {
        let cal = Calendar.current
        var monthMap: [Date: [Transaction]] = [:]
        for tx in filtered {
            let month = tx.date.startOfMonth()
            monthMap[month, default: []].append(tx)
        }
        let dateAsc = sortOrder == .oldest
        return monthMap.keys.sorted { dateAsc ? $0 < $1 : $0 > $1 }.map { month in
            var dateMap: [Date: [Transaction]] = [:]
            for tx in monthMap[month]! {
                let day = cal.startOfDay(for: tx.date)
                dateMap[day, default: []].append(tx)
            }
            let days = dateMap.keys.sorted { dateAsc ? $0 < $1 : $0 > $1 }.map { day -> (date: Date, txs: [Transaction]) in
                let sorted: [Transaction]
                switch self.sortOrder {
                case .newest:  sorted = dateMap[day]!.sorted { $0.date > $1.date }
                case .oldest:  sorted = dateMap[day]!.sorted { $0.date < $1.date }
                case .highest: sorted = dateMap[day]!.sorted { $0.amountPaid > $1.amountPaid }
                case .lowest:  sorted = dateMap[day]!.sorted { $0.amountPaid < $1.amountPaid }
                }
                return (date: day, txs: sorted)
            }
            return MonthGroup(id: month, days: days)
        }
    }

    private var totalExpenses: Double { filtered.filter { !$0.isIncome }.reduce(0) { $0 + $1.expenseAmount } }
    private var totalIncome:   Double { filtered.filter { $0.isIncome }.reduce(0) { $0 + $1.amountPaid } }
    private var dateRange: String {
        let fmt = DateFormatter()
        let dates = filtered.map(\.date)
        let start = dates.min() ?? Date().startOfMonth()
        let end   = dates.max() ?? Date()
        fmt.dateFormat = "MMM d"
        let s = fmt.string(from: start)
        fmt.dateFormat = "MMM d, yyyy"
        let e = fmt.string(from: end)
        return "\(s) – \(e)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // ── Sort + actions bar ───────────────────────────────
                HStack {
                    Menu {
                        ForEach(TxSortOrder.allCases, id: \.self) { order in
                            Button(order.rawValue) { sortOrder = order }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sortOrder.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DS.text)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.textSub)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(DS.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.cardBorder))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        // Filter button — highlighted when active
                        Button { showFilter = true } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(filter.isActive ? DS.blue : DS.text)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(filter.isActive ? DS.blue.opacity(0.15) : DS.surface))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(filter.isActive ? DS.blue.opacity(0.4) : DS.cardBorder))
                        }
                        .buttonStyle(.plain)

                        Button { showAdd = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.blue)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(DS.surface))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.cardBorder))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                // ── Summary card ─────────────────────────────────────
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.1)) { summaryExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("SUMMARY")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.textSub)
                                .tracking(0.8)
                            Spacer()
                            Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DS.textSub)
                        }
                        .padding(.horizontal, 18).padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    if summaryExpanded {
                        summaryRow("Total transactions", value: "\(filtered.count)", color: DS.text)
                        Divider().background(DS.cardBorder).padding(.horizontal, 18)
                        summaryRow("Date range", value: dateRange, color: DS.text)
                        Divider().background(DS.cardBorder).padding(.horizontal, 18)
                        summaryRow("Total expenses",
                                   value: "-\(totalExpenses.formatted(.currency(code: DS.currencyCode)))",
                                   color: DS.text)
                        Divider().background(DS.cardBorder).padding(.horizontal, 18)
                        summaryRow("Total income",
                                   value: "+\(totalIncome.formatted(.currency(code: DS.currencyCode)))",
                                   color: DS.green)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                .padding(.horizontal, 16)

                // ── Month-grouped list ───────────────────────────────
                if groupedByMonth.isEmpty {
                    Text("No transactions match your filters")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textSub)
                        .padding(.top, 40)
                } else {
                    ForEach(groupedByMonth) { mg in
                        let isOpen = expandedMonths.contains(mg.month)

                        VStack(alignment: .leading, spacing: 0) {
                            // Month header
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if expandedMonths.contains(mg.month) {
                                        expandedMonths.remove(mg.month)
                                    } else {
                                        expandedMonths.insert(mg.month)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(mg.month.monthYearLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.text)
                                    Text("· \(mg.allTxs.count)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DS.textSub)
                                    Spacer()
                                    Text(mg.netExpense, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DS.text)
                                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DS.textSub)
                                        .padding(.leading, 4)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                            }
                            .buttonStyle(.plain)

                            if isOpen {
                                ForEach(mg.days, id: \.date) { group in
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(group.date.txDateHeader)
                                            .font(.system(size: 13))
                                            .foregroundStyle(DS.textSub)
                                            .padding(.leading, 4)
                                            .padding(.top, 8)
                                            .padding(.bottom, 6)

                                        VStack(spacing: 0) {
                                            ForEach(Array(group.txs.enumerated()), id: \.element.id) { idx, tx in
                                                TxDetailRow(tx: tx)
                                                if idx < group.txs.count - 1 {
                                                    Divider().background(DS.cardBorder).padding(.leading, 70)
                                                }
                                            }
                                        }
                                        .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .sheet(isPresented: $showAdd)    { TransactionFormView() }
        .sheet(isPresented: $showFilter) { TxFilterSheet(filter: $filter) }
    }

    @ViewBuilder
    private func summaryRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(DS.text)
            Spacer()
            Text(value).font(.system(size: 15, weight: .medium)).foregroundStyle(color)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }
}

// MARK: - Filter Model
struct TxFilter {
    var startDate:        Date?     = nil
    var endDate:          Date?     = nil
    var categoryIds:      Set<UUID> = []
    var minAmount:        Double?   = nil
    var maxAmount:        Double?   = nil

    var isActive: Bool {
        startDate != nil || endDate != nil ||
        !categoryIds.isEmpty ||
        minAmount != nil || maxAmount != nil
    }

    mutating func reset() {
        startDate = nil; endDate = nil
        categoryIds = [];
        minAmount = nil; maxAmount = nil
    }
}

// MARK: - Filter Sheet
struct TxFilterSheet: View {
    @EnvironmentObject var store: DataStore
    @Binding var filter: TxFilter
    @Environment(\.dismiss) private var dismiss

    enum FilterSection { case none, date, accounts, categories, amount }
    @State private var expanded: FilterSection = .none
    @State private var minText = ""
    @State private var maxText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Filter by:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.text)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 14)

                        VStack(spacing: 0) {
                            filterRow(label: "Date", section: .date) {
                                VStack(spacing: 12) {
                                    DatePicker("From", selection: Binding(
                                        get: { filter.startDate ?? Date() },
                                        set: { filter.startDate = $0 }
                                    ), displayedComponents: .date)
                                    DatePicker("To", selection: Binding(
                                        get: { filter.endDate ?? Date() },
                                        set: { filter.endDate = $0 }
                                    ), displayedComponents: .date)
                                }
                                .padding(.horizontal, 18).padding(.bottom, 14)
                                .colorScheme(.dark)
                            }

                            Divider().background(DS.cardBorder)

                            filterRow(label: "Categories",
                                      categoryIcons: filter.categoryIds.compactMap { id in
                                          store.categories.first { $0.id == id }
                                      },
                                      section: .categories) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                                    ForEach(store.categories) { cat in
                                        let on = filter.categoryIds.contains(cat.id)
                                        Button {
                                            if on { filter.categoryIds.remove(cat.id) }
                                            else  { filter.categoryIds.insert(cat.id) }
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(on ? cat.color : cat.color.opacity(0.7))
                                                    .frame(width: 44, height: 44)
                                                    .background(Circle().fill(cat.color.opacity(on ? 0.25 : 0.12)))
                                                    .overlay(Circle().stroke(on ? cat.color : Color.clear, lineWidth: 1.5))
                                                Text(cat.name)
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(on ? DS.text : DS.textSub)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                            }
                                            .frame(width: 60)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 18).padding(.bottom, 14)
                            }

                            Divider().background(DS.cardBorder)

                            filterRow(label: "Amount",
                                      badge: (filter.minAmount != nil || filter.maxAmount != nil) ? "set" : nil,
                                      section: .amount) {
                                HStack(spacing: 12) {
                                    amountField("Min $", text: $minText, bind: { filter.minAmount = Double($0) })
                                    Text("–").foregroundStyle(DS.textSub)
                                    amountField("Max $", text: $maxText, bind: { filter.maxAmount = Double($0) })
                                }
                                .padding(.horizontal, 18).padding(.bottom, 14)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                        .padding(.horizontal, 16)

                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filter.reset()
                        minText = ""; maxText = ""
                    }
                    .foregroundStyle(filter.isActive ? DS.red : DS.textSub)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DS.blue)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(DS.bg, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func filterRow<Expanded: View>(
        label: String,
        badge: String? = nil,
        categoryIcons: [Category] = [],
        section: FilterSection,
        @ViewBuilder expandedContent: () -> Expanded
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.1)) {
                    expanded = expanded == section ? .none : section
                }
            } label: {
                HStack {
                    Text(label)
                        .font(.system(size: 16))
                        .foregroundStyle(DS.text)
                    Spacer()
                    // Category icons preview
                    if !categoryIcons.isEmpty {
                        HStack(spacing: -8) {
                            ForEach(categoryIcons.prefix(3)) { cat in
                                Image(systemName: cat.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(cat.color))
                            }
                        }
                        Text("\(categoryIcons.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textSub)
                            .padding(.leading, 12)
                    }
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.blue)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(DS.blue.opacity(0.15)))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.textSub)
                        .rotationEffect(.degrees(expanded == section ? 90 : 0))
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if expanded == section {
                expandedContent()
            }
        }
    }

    @ViewBuilder
    private func plainFilterRow(_ label: String) -> some View {
        HStack {
            Text(label).font(.system(size: 16)).foregroundStyle(DS.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.textSub)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
    }

    @ViewBuilder
    private func amountField(_ placeholder: String, text: Binding<String>, bind: @escaping (String) -> Void) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(.system(size: 14))
            .foregroundStyle(DS.text)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(DS.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.cardBorder))
            .onChange(of: text.wrappedValue) { _, newValue in bind(newValue) }
    }
}

// MARK: - Transaction Detail Row
struct TxDetailRow: View {
    @EnvironmentObject var store: DataStore
    let tx: Transaction
    @State private var showEdit = false

    private var category:      Category?      { store.category(for: tx.categoryId) }

    var body: some View {
        Button { showEdit = true } label: {
            HStack(spacing: 14) {
                Group {
                    if tx.isIncome {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(DS.green)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: category?.icon ?? "questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(category?.color ?? DS.blue)
                            .frame(width: 42, height: 42)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill((category?.color ?? DS.blue).opacity(0.15)))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tx.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.text)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if tx.isIncome {
                        Text("+\(tx.amountPaid.formatted(.currency(code: DS.currencyCode)))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.green)
                        Text("Income")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.green.opacity(0.7))
                    } else {
                        // Headline = your share
                        Text(tx.expenseAmount, format: .currency(code: DS.currencyCode))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.text)
                        if tx.isSplit {
                            Text("Split · \(tx.amountPaid.formatted(.currency(code: DS.currencyCode)))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.textSub)
                        } else if let owed = tx.owedTo, !owed.isEmpty {
                            Text("You owe \(owed)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.textSub)
                        } else if tx.amountBack > 0 {
                            Text("+\(tx.amountBack.formatted(.currency(code: DS.currencyCode)))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.green)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textHint)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdit) {
            TransactionFormView(transaction: tx)
        }
    }
}

// MARK: - Date header helper
private extension Date {
    var txDateHeader: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt.string(from: self)
    }
    var monthYearLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: self)
    }
}

// MARK: - Categories Tab
struct SpendCategoriesTab: View {
    @EnvironmentObject var store: DataStore
    @State private var selected: Category?
    @State private var showAdd = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if store.categories.isEmpty {
                    EmptyStateView(message: "No categories yet").padding(.top, 60)
                } else {
                    SectionLabel(title: "Categories")
                    GroupedListCard {
                        ForEach(Array(store.categories.enumerated()), id: \.element.id) { idx, cat in
                            CatRow(category: cat, isLast: idx == store.categories.count - 1)
                                .onTapGesture { selected = cat }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button { showAdd = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(DS.purple)
                        Text("Add Category")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(DS.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.purple.opacity(0.3)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .sheet(isPresented: $showAdd)    { CategoryFormView() }
        .sheet(item: $selected) { cat in CategoryFormView(category: cat) }
    }
}

// MARK: - Breakdown Tab
struct SpendBreakdownTab: View {
    @State private var selectedMonth: Date = Date().startOfMonth()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SpendTimePeriodCard(selectedMonth: $selectedMonth)
                SpendCategoryBreakdownCard(selectedMonth: selectedMonth)
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Time Period Card
struct SpendTimePeriodCard: View {
    @EnvironmentObject var store: DataStore
    @Binding var selectedMonth: Date

    private var months: [Date] {
        let cal = Calendar.current
        let current = Date().startOfMonth()
        return (0..<5).reversed().map { i in
            cal.date(byAdding: .month, value: -i, to: current)!
        }
    }

    private var maxValue: Double {
        let vals = months.flatMap { m in
            [store.totalIncome(for: m), store.totalExpense(for: m)]
        }
        return max(vals.max() ?? 1, 1)
    }

    private var selectedIncome:  Double { store.totalIncome(for: selectedMonth) }
    private var selectedExpense: Double { store.totalExpense(for: selectedMonth) }
    private var netFlow:         Double { selectedIncome - selectedExpense }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TIME PERIOD")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textSub)
                .tracking(0.8)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)

            // Grouped bar chart
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(months, id: \.self) { month in
                    let isSel = Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month)
                    let inc  = store.totalIncome(for: month)
                    let exp  = store.totalExpense(for: month)
                    Button { selectedMonth = month } label: {
                        VStack(spacing: 8) {
                            HStack(alignment: .bottom, spacing: 4) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(DS.blue.opacity(0.35))
                                    .frame(width: 14, height: max(5, CGFloat(inc / maxValue) * 72))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(DS.blue)
                                    .frame(width: 14, height: max(5, CGFloat(exp / maxValue) * 72))
                            }
                            .frame(height: 72, alignment: .bottom)
                            Text(month.timePeriodLabel)
                                .font(.system(size: 11, weight: isSel ? .semibold : .regular))
                                .foregroundStyle(isSel ? DS.text : DS.textSub)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                        .background(
                            isSel
                            ? RoundedRectangle(cornerRadius: 12).fill(DS.surface)
                              .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.cardBorder))
                            : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)

            Divider().background(DS.cardBorder).padding(.horizontal, 18)
            tpRow(dot: DS.blue.opacity(0.4), label: "Income",   value: selectedIncome.formatted(.currency(code: DS.currencyCode)))
            Divider().background(DS.cardBorder).padding(.horizontal, 18)
            tpRow(dot: DS.blue,              label: "Expenses", value: selectedExpense.formatted(.currency(code: DS.currencyCode)))
            Divider().background(DS.cardBorder).padding(.horizontal, 18)

            HStack {
                Text("Net Cash Flow")
                    .font(.system(size: 15)).foregroundStyle(DS.text)
                Spacer()
                Text(netFlow, format: .currency(code: DS.currencyCode))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(netFlow >= 0 ? DS.green : DS.red)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }

    @ViewBuilder
    private func tpRow(dot: Color, label: String, value: String) -> some View {
        HStack {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(label).font(.system(size: 15)).foregroundStyle(DS.text)
            Spacer()
            Text(value).font(.system(size: 15, weight: .medium)).foregroundStyle(DS.text)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }
}

// MARK: - Category Breakdown Card
struct SpendCategoryBreakdownCard: View {
    @EnvironmentObject var store: DataStore
    let selectedMonth: Date

    enum BSection { case expenses, income }
    @State private var section: BSection = .income
    @State private var showAll = false
    @State private var selectedCategoryId: UUID? = nil
    @State private var categoryFilters: Set<UUID> = []   // empty = show all

    private struct CatSlice: Identifiable {
        let id: UUID; let name: String; let icon: String
        let amount: Double; let chartColor: Color
    }

    private var expenseSlices: [CatSlice] {
        store.categories.compactMap { cat -> CatSlice? in
            let amt = store.netSpent(categoryId: cat.id, month: selectedMonth)
            guard amt > 0 else { return nil }
            return CatSlice(id: cat.id, name: cat.name, icon: cat.icon, amount: amt, chartColor: cat.color)
        }.sorted { $0.amount > $1.amount }
    }
    private var totalExpense: Double { expenseSlices.reduce(0) { $0 + $1.amount } }

    private var filteredSlices: [CatSlice] {
        categoryFilters.isEmpty ? expenseSlices : expenseSlices.filter { categoryFilters.contains($0.id) }
    }
    private var filteredTotal: Double { filteredSlices.reduce(0) { $0 + $1.amount } }

    private struct IncomeItem: Identifiable {
        let id: UUID
        let title: String
        let amount: Double
        let isCashback: Bool
    }

    private var incomeItems: [IncomeItem] {
        let cal = Calendar.current
        // Only real Income-type transactions count as income.
        // Amount-back on a spend stays a spend reduction — record incoming money
        // as its own Income transaction when it actually arrives.
        return store.transactions
            .filter { $0.isIncome && cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
            .map { IncomeItem(id: $0.id, title: $0.title, amount: $0.amountPaid, isCashback: false) }
    }
    private var totalIncome: Double { incomeItems.reduce(0) { $0 + $1.amount } }

    private let incomeColor = DS.green

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("CATEGORY BREAKDOWN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.textSub)
                    .tracking(0.8)
                Spacer()
                Text(selectedMonth.breakdownPickerLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.textSub)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)

            // Tab bar — Income first, Expenses second
            HStack(spacing: 0) {
                cbTabBtn("Income",   s: .income)
                cbTabBtn("Expenses", s: .expenses)
            }
            .padding(.horizontal, 18)

            Divider().background(DS.cardBorder)

            if section == .income {
                incomeBody
            } else {
                expensesBody
            }
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
        .onChange(of: selectedMonth) { _, _ in showAll = false; categoryFilters.removeAll() }
        .sheet(item: Binding(
            get: { selectedCategoryId.flatMap { id in expenseSlices.first { $0.id == id } } },
            set: { _ in selectedCategoryId = nil }
        )) { slice in
            CategoryTransactionsSheet(
                categoryId: slice.id,
                categoryName: slice.name,
                categoryIcon: slice.icon,
                chartColor: slice.chartColor,
                month: selectedMonth
            )
        }
    }

    @ViewBuilder
    private func cbTabBtn(_ label: String, s: BSection) -> some View {
        let active = section == s
        Button { withAnimation(.easeInOut(duration: 0.1)) { section = s } } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 15, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? DS.text : DS.textSub)
                    .padding(.bottom, 2)
                Rectangle()
                    .fill(active ? DS.text : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // ── Expenses ────────────────────────────────────────────────────────────
    @ViewBuilder
    private var expensesBody: some View {

        // ── Category filter chips ──────────────────────────────────────────
        if !expenseSlices.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" chip
                    let allActive = categoryFilters.isEmpty
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { categoryFilters.removeAll() }
                    } label: {
                        Text("All")
                            .font(.system(size: 13, weight: allActive ? .semibold : .regular))
                            .foregroundStyle(allActive ? DS.text : DS.textSub)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                Capsule().fill(allActive ? DS.surface : Color.clear)
                                    .overlay(Capsule().stroke(allActive ? DS.cardBorder : DS.textHint.opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(expenseSlices) { s in
                        let active = categoryFilters.contains(s.id)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if active { categoryFilters.remove(s.id) }
                                else      { categoryFilters.insert(s.id) }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: s.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(active ? .white : s.chartColor)
                                Text(s.name)
                                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? .white : DS.text)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                Capsule().fill(active ? s.chartColor : Color.clear)
                                    .overlay(Capsule().stroke(active ? s.chartColor : DS.textHint.opacity(0.3), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            Divider().background(DS.cardBorder)
        }

        // ── Donut ──────────────────────────────────────────────────────────
        ZStack {
            if filteredSlices.isEmpty {
                Circle().stroke(DS.surface, lineWidth: 14).frame(width: 170, height: 170)
            } else {
                Chart(filteredSlices) { s in
                    SectorMark(
                        angle: .value("Amount", s.amount),
                        innerRadius: .ratio(0.83),
                        angularInset: 2
                    )
                    .foregroundStyle(s.chartColor)
                    .cornerRadius(3)
                }
                .frame(width: 170, height: 170)
                .animation(.easeInOut(duration: 0.08), value: categoryFilters)
            }
            VStack(spacing: 3) {
                Text(filteredTotal, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(DS.text)
                Text(categoryFilters.isEmpty ? "Spent this month" : "Selected total")
                    .font(.system(size: 12)).foregroundStyle(DS.textSub)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)

        Divider().background(DS.cardBorder)

        // ── Category list ──────────────────────────────────────────────────
        let displayed = showAll ? filteredSlices : Array(filteredSlices.prefix(4))
        ForEach(displayed) { s in
            Button { selectedCategoryId = s.id } label: {
                HStack(spacing: 14) {
                    Image(systemName: s.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(s.chartColor)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(s.chartColor.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name)
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(DS.text)
                        Text(String(format: "%.1f%% of expenses", totalExpense > 0 ? s.amount / totalExpense * 100 : 0))
                            .font(.system(size: 12)).foregroundStyle(DS.textSub)
                    }
                    Spacer()
                    Text(s.amount, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.text)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.textHint)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().background(DS.cardBorder).padding(.leading, 70)
        }

        if filteredSlices.count > 4 {
            Button {
                withAnimation(.easeInOut(duration: 0.1)) { showAll.toggle() }
            } label: {
                Text(showAll ? "See less" : "See more")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(DS.blue)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.plain)
        } else {
            Spacer(minLength: 8)
        }
    }

    // ── Income ──────────────────────────────────────────────────────────────
    @ViewBuilder
    private var incomeBody: some View {
        // Single ring
        ZStack {
            Circle()
                .stroke(incomeItems.isEmpty ? DS.surface : incomeColor, lineWidth: 14)
                .frame(width: 170, height: 170)
            VStack(spacing: 3) {
                Text(totalIncome, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(DS.text)
                Text("Earned this month")
                    .font(.system(size: 12)).foregroundStyle(DS.textSub)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)

        Divider().background(DS.cardBorder)

        if incomeItems.isEmpty {
            Text("No income this month")
                .font(.system(size: 14)).foregroundStyle(DS.textSub)
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ForEach(incomeItems) { item in
                HStack(spacing: 14) {
                    Image(systemName: item.isCashback ? "arrow.uturn.left.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.green)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(DS.green.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15)).foregroundStyle(DS.text)
                        if item.isCashback {
                            Text("Cashback")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.green.opacity(0.8))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(DS.green.opacity(0.15)))
                        }
                    }
                    Spacer()
                    Text(item.amount, format: .currency(code: DS.currencyCode))
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.green)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                Divider().background(DS.cardBorder).padding(.leading, 70)
            }
            Spacer(minLength: 8)
        }
    }

}

// MARK: - Category Transactions Sheet
struct CategoryTransactionsSheet: View {
    @EnvironmentObject var store: DataStore
    let categoryId: UUID
    let categoryName: String
    let categoryIcon: String
    let chartColor: Color
    let month: Date
    @Environment(\.dismiss) private var dismiss

    private var transactions: [Transaction] {
        let cal = Calendar.current
        return store.transactions
            .filter { $0.categoryId == categoryId && !$0.isIncome && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }
    private var total: Double {
        transactions.reduce(0) { $0 + $1.expenseAmount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header summary
                        HStack(spacing: 14) {
                            Image(systemName: categoryIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(chartColor)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(chartColor.opacity(0.15)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(categoryName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(DS.text)
                                Text(month.breakdownPickerLabel)
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS.textSub)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(total, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(DS.text)
                                Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.textSub)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        if transactions.isEmpty {
                            EmptyStateView(message: "No transactions this month")
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(transactions.enumerated()), id: \.element.id) { idx, tx in
                                    TxDetailRow(tx: tx)
                                    if idx < transactions.count - 1 {
                                        Divider().background(DS.cardBorder).padding(.leading, 70)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(DS.card))
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
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
    }
}

// MARK: - Date helpers (breakdown)
private extension Date {
    var timePeriodLabel: String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.component(.year, from: self) == cal.component(.year, from: Date()) {
            f.dateFormat = "MMM"
        } else {
            f.dateFormat = "MMM''yy"
        }
        return f.string(from: self)
    }
    var breakdownPickerLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }
}

// MARK: - Date helper
extension Date {
    var spendMonthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: self)
    }
    var shortMonthName: String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: self)
    }
    var spendMonthYearName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: self)
    }
}

// Date needs to be Identifiable for .sheet(item:)
extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
