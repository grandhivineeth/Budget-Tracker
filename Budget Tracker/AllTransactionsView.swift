import SwiftUI

struct AllTransactionsView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    let month: Date
    @State private var selectedTransaction: Transaction?

    var transactions: [Transaction] { store.transactions(for: month) }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Group {
                    if transactions.isEmpty {
                        EmptyStateView(message: "No transactions this month")
                    } else {
                        ScrollView {
                            GroupedListCard {
                                ForEach(Array(transactions.enumerated()), id: \.element.id) { idx, tx in
                                    TransactionRow(transaction: tx, isLast: idx == transactions.count - 1)
                                        .onTapGesture { selectedTransaction = tx }
                                }
                            }
                            .padding(.horizontal, 20).padding(.top, 16)
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationTitle(month.monthYearString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold).foregroundStyle(DS.blue)
                }
            }
            .sheet(item: $selectedTransaction) { tx in TransactionFormView(transaction: tx) }
        }
        .preferredColorScheme(.dark)
    }
}
