import SwiftUI

struct TransactionFormView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    var transaction: Transaction?

    @State private var txType                = Transaction.TransactionType.spend
    @State private var date                  = Date()
    @State private var title                 = ""
    @State private var selectedCategoryId:   UUID?
    @State private var selectedAccountId:    UUID?
    @State private var amountPaid            = ""
    @State private var amountBack            = ""
    @State private var showCategoryPicker    = false
    @State private var showAccountPicker     = false
    @State private var triedSave             = false   // shows "Required" hints on failed save attempt

    var isEditing: Bool { transaction != nil }

    private var selectedCategory: Category? { selectedCategoryId.flatMap { store.category(for: $0) } }
    private var selectedAccount:  NetWorthAccount? {
        selectedAccountId.flatMap { id in store.netWorthAccounts.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Form {
                    // Spend / Income toggle
                    Section {
                        Picker("Type", selection: $txType) {
                            ForEach(Transaction.TransactionType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(DS.bg)

                    Section {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        TextField("Title", text: $title)

                        // Category — only for Spend
                        if txType == .spend {
                            Button { showCategoryPicker = true } label: {
                                HStack {
                                    Text("Category").foregroundStyle(DS.text)
                                    Spacer()
                                    if let cat = selectedCategory {
                                        HStack(spacing: 5) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(cat.color)
                                            Text(cat.name).foregroundStyle(DS.textSub)
                                        }
                                    } else {
                                        Text(triedSave ? "Required" : "Select…")
                                            .foregroundStyle(triedSave ? DS.red : DS.textHint)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DS.textHint)
                                }
                            }
                        }

                        // Account picker — required for Spend, optional for Income
                        Button { showAccountPicker = true } label: {
                            HStack {
                                Text("Account").foregroundStyle(DS.text)
                                Spacer()
                                if let acct = selectedAccount {
                                    HStack(spacing: 5) {
                                        Image(systemName: acct.type.icon)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(acct.color)
                                        Text(acct.name).foregroundStyle(DS.textSub)
                                    }
                                } else {
                                    Text(txType == .spend && triedSave ? "Required" : txType == .income ? "Optional" : "Select…")
                                        .foregroundStyle(txType == .spend && triedSave ? DS.red : DS.textHint)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DS.textHint)
                            }
                        }
                    }
                    .listRowBackground(DS.card)

                    Section("Amount") {
                        if txType == .spend {
                            HStack {
                                Text("Amount paid")
                                Spacer()
                                TextField("0.00", text: $amountPaid)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(DS.red)
                            }
                            HStack {
                                Text("Amount back")
                                Spacer()
                                TextField("0.00", text: $amountBack)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(DS.green)
                            }
                        } else {
                            HStack {
                                Text("Income amount")
                                Spacer()
                                TextField("0.00", text: $amountPaid)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(DS.green)
                            }
                        }
                    }
                    .listRowBackground(DS.card)

                    if isEditing {
                        Section {
                            Button(role: .destructive) { deleteAndDismiss() } label: {
                                Label("Delete Transaction", systemImage: "trash")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .listRowBackground(DS.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isValid { saveAndDismiss() } else { triedSave = true }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.blue)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(selection: $selectedCategoryId)
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(selection: $selectedAccountId, required: txType == .spend)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && (txType == .income || selectedCategoryId != nil)
        && (txType == .income || selectedAccountId != nil)   // account required for spend
        && (Double(amountPaid) ?? 0) > 0
    }

    private func prefill() {
        guard let tx = transaction else {
            selectedCategoryId = store.categories.first?.id
            return
        }
        txType             = tx.type
        date               = tx.date
        title              = tx.title
        selectedCategoryId = tx.categoryId
        selectedAccountId  = tx.accountId
        amountPaid         = String(tx.amountPaid)
        amountBack         = tx.amountBack > 0 ? String(tx.amountBack) : ""
    }

    private func saveAndDismiss() {
        let catId = selectedCategoryId ?? store.categories.first?.id ?? UUID()
        let paid = Double(amountPaid) ?? 0
        let back = txType == .income ? 0.0 : (Double(amountBack) ?? 0)
        if let ex = transaction {
            var u = ex
            u.type = txType; u.date = date; u.title = title
            u.amountPaid = paid; u.amountBack = back
            u.accountId  = selectedAccountId
            store.updateTransaction(u)
        } else {
            store.addTransaction(Transaction(
                date: date, title: title,
                categoryId: catId,
                amountPaid: paid, amountBack: back,
                type: txType,
                accountId: selectedAccountId
            ))
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        if let tx = transaction { store.deleteTransaction(tx) }
        dismiss()
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    @EnvironmentObject var store: DataStore
    @Binding var selection: UUID?
    var required: Bool = false
    @Environment(\.dismiss) var dismiss

    var assets:      [NetWorthAccount] { store.netWorthAccounts.filter {  $0.type.isAsset } }
    var liabilities: [NetWorthAccount] { store.netWorthAccounts.filter { !$0.type.isAsset } }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                List {
                    if !assets.isEmpty {
                        Section("Assets") {
                            ForEach(assets) { acct in accountRow(acct) }
                        }
                    }
                    if !liabilities.isEmpty {
                        Section("Liabilities") {
                            ForEach(liabilities) { acct in accountRow(acct) }
                        }
                    }
                    if store.netWorthAccounts.isEmpty {
                        Section {
                            Text("No accounts — add one in Manager first.")
                                .foregroundStyle(DS.textSub)
                                .font(.system(size: 14))
                        }
                        .listRowBackground(DS.card)
                    }
                    // Allow deselecting for optional (income) transactions
                    if !required, selection != nil {
                        Section {
                            Button {
                                selection = nil
                                dismiss()
                            } label: {
                                Label("Clear selection", systemImage: "xmark.circle")
                                    .foregroundStyle(DS.red)
                            }
                        }
                        .listRowBackground(DS.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func accountRow(_ acct: NetWorthAccount) -> some View {
        Button {
            selection = acct.id
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: acct.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(acct.color)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(acct.color.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(acct.name)
                        .foregroundStyle(DS.text)
                        .font(.system(size: 15))
                    Text(acct.balance, format: .currency(code: DS.currencyCode))
                        .foregroundStyle(DS.textSub)
                        .font(.system(size: 12))
                }
                Spacer()
                if selection == acct.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(DS.card)
    }
}

// MARK: - Category Picker Sheet
struct CategoryPickerSheet: View {
    @EnvironmentObject var store: DataStore
    @Binding var selection: UUID?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                List {
                    ForEach(store.categories) { cat in
                        Button {
                            selection = cat.id
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(cat.color)
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(cat.color.opacity(0.15)))
                                Text(cat.name)
                                    .foregroundStyle(DS.text)
                                    .font(.system(size: 15))
                                Spacer()
                                if selection == cat.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DS.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(DS.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
