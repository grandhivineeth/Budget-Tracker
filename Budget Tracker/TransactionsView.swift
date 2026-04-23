import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedTransaction: Transaction?
    @State private var showAdd = false

    var months: [Date] { store.allMonths() }

    func txs(for month: Date) -> [Transaction] {
        let all = store.transactions(for: month)
        guard let id = selectedCategoryId else { return all }
        return all.filter { $0.categoryId == id }
    }

    var hasAnyResults: Bool {
        months.contains { !txs(for: $0).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Category filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TxFilterChip(
                                label: "All",
                                isSelected: selectedCategoryId == nil,
                                color: DS.blue
                            ) { selectedCategoryId = nil }

                            ForEach(store.categories) { cat in
                                TxFilterChip(
                                    label: cat.name,
                                    isSelected: selectedCategoryId == cat.id,
                                    color: cat.color
                                ) {
                                    selectedCategoryId = selectedCategoryId == cat.id ? nil : cat.id
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .background(DS.bg)

                    Rectangle().fill(DS.cardBorder).frame(height: 1)

                    // ── Grouped list
                    if months.isEmpty || !hasAnyResults {
                        Spacer()
                        EmptyStateView(message: "No transactions yet")
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                                ForEach(months, id: \.self) { month in
                                    let monthTxs = txs(for: month)
                                    if !monthTxs.isEmpty {
                                        Section {
                                            GroupedListCard {
                                                ForEach(Array(monthTxs.enumerated()), id: \.element.id) { idx, tx in
                                                    TransactionRow(transaction: tx, isLast: idx == monthTxs.count - 1)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture { selectedTransaction = tx }
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 20)
                                        } header: {
                                            TxMonthHeader(month: month, transactions: monthTxs)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                            Spacer(minLength: 110)
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.blue)
                    }
                }
            }
            .sheet(item: $selectedTransaction) { tx in TransactionFormView(transaction: tx) }
            .sheet(isPresented: $showAdd) { TransactionFormView() }
        }
    }
}

// MARK: - Month Section Header

struct TxMonthHeader: View {
    let month: Date
    let transactions: [Transaction]

    var net: Double { transactions.reduce(0) { $0 + $1.netAmount } }

    var body: some View {
        HStack {
            Text(month.monthYearString)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.text)
            Spacer()
            Text(net, format: .currency(code: DS.currencyCode))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(net > 0 ? DS.red : DS.green)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(DS.bg)
    }
}

// MARK: - Filter Chip

struct TxFilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : DS.textSub)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? color : DS.surface))
                .overlay(Capsule().stroke(isSelected ? Color.clear : DS.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
