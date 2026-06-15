import SwiftUI

/// Editable row in the "Split this expense" section (one person + their share).
private struct SplitRowInput: Identifiable {
    let id = UUID()
    var personName: String = ""
    var amountText: String = ""
}

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
    @State private var showCategoryPicker    = false
    @State private var showAccountPicker     = false
    @State private var triedSave             = false   // shows "Required" hints on failed save attempt

    // Split this expense
    @State private var isSplit               = false
    @State private var splitRows: [SplitRowInput] = []
    @State private var pendingNewPersonRowID: UUID? = nil
    @State private var newPersonName         = ""
    @State private var isSaving              = false   // guards against a double-tapped Save

    // Someone else paid (I owe my share)
    @State private var paidByOther           = false
    @State private var owedToPerson          = ""
    @State private var showOwedNewAlert      = false
    @State private var owedNewName           = ""

    var isEditing: Bool { transaction != nil }

    private var selectedCategory: Category? { selectedCategoryId.flatMap { store.category(for: $0) } }
    private var selectedAccount:  NetWorthAccount? {
        selectedAccountId.flatMap { id in store.netWorthAccounts.first { $0.id == id } }
    }

    private var existingPeople: [String] {
        Array(Set(store.splitEntries.map { $0.personName })).sorted()
    }
    private var totalAmount: Double { Double(amountPaid) ?? 0 }
    private var assignedToOthers: Double {
        splitRows.reduce(0) { $0 + (Double($1.amountText) ?? 0) }
    }
    private var myShare: Double { totalAmount - assignedToOthers }
    private var splitValid: Bool {
        guard isSplit else { return true }
        return assignedToOthers > 0
            && assignedToOthers <= totalAmount + 0.005
            && splitRows.allSatisfy {
                !$0.personName.trimmingCharacters(in: .whitespaces).isEmpty
                && (Double($0.amountText) ?? 0) > 0
            }
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

                        // Someone else paid (I owe my share) — Spend only
                        if txType == .spend {
                            Toggle(isOn: $paidByOther.animation()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.minus")
                                        .foregroundStyle(DS.blue)
                                    Text("Someone else paid").foregroundStyle(DS.text)
                                }
                            }
                        }

                        if txType == .spend && paidByOther {
                            // I owe — pick the person who paid
                            Menu {
                                ForEach(existingPeople, id: \.self) { name in
                                    Button(name) { owedToPerson = name }
                                }
                                Button { owedNewName = ""; showOwedNewAlert = true } label: {
                                    Label("New person…", systemImage: "plus")
                                }
                            } label: {
                                HStack {
                                    Text("I owe").foregroundStyle(DS.text)
                                    Spacer()
                                    Text(owedToPerson.isEmpty ? (triedSave ? "Required" : "Choose person") : owedToPerson)
                                        .foregroundStyle(owedToPerson.isEmpty ? (triedSave ? DS.red : DS.textHint) : DS.textSub)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DS.textHint)
                                }
                            }
                        } else {
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
                    }
                    .listRowBackground(DS.card)

                    Section("Amount") {
                        HStack {
                            Text(txType == .income ? "Income amount" : (paidByOther ? "My share" : "Amount"))
                            Spacer()
                            TextField("0.00", text: $amountPaid)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(txType == .spend ? DS.red : DS.green)
                        }
                    }
                    .listRowBackground(DS.card)

                    // Split this expense — only when I paid (Spend, not owed)
                    if txType == .spend && !paidByOther {
                        Section("Split") {
                            Toggle(isOn: $isSplit.animation()) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill").foregroundStyle(DS.blue)
                                    Text("Split this expense").foregroundStyle(DS.text)
                                }
                            }

                            if isSplit {
                                ForEach($splitRows) { $row in
                                    HStack(spacing: 10) {
                                        Menu {
                                            ForEach(existingPeople, id: \.self) { name in
                                                Button(name) { row.personName = name }
                                            }
                                            Button {
                                                newPersonName = ""
                                                pendingNewPersonRowID = row.id
                                            } label: { Label("New person…", systemImage: "plus") }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(row.personName.isEmpty ? "Choose person" : row.personName)
                                                    .foregroundStyle(row.personName.isEmpty ? DS.textHint : DS.text)
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 10)).foregroundStyle(DS.textHint)
                                            }
                                        }
                                        Spacer()
                                        TextField("0.00", text: $row.amountText)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 80)
                                            .foregroundStyle(DS.blue)
                                        Button {
                                            splitRows.removeAll { $0.id == row.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(DS.red.opacity(0.85))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Button {
                                    splitRows.append(SplitRowInput())
                                } label: {
                                    Label("Add person", systemImage: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(DS.blue)
                                }

                                HStack {
                                    Text("Your share").foregroundStyle(DS.text)
                                    Spacer()
                                    Text(myShare, format: .currency(code: DS.currencyCode))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(myShare < -0.005 ? DS.red : DS.green)
                                }
                                if assignedToOthers > totalAmount + 0.005 {
                                    Text("Others' shares exceed the amount.")
                                        .font(.system(size: 12)).foregroundStyle(DS.red)
                                } else if triedSave && assignedToOthers <= 0 {
                                    Text("Add at least one person's share.")
                                        .font(.system(size: 12)).foregroundStyle(DS.red)
                                }
                            }
                        }
                        .listRowBackground(DS.card)
                    }

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
            .onChange(of: isSplit) { _, on in
                if on && splitRows.isEmpty { splitRows = [SplitRowInput()] }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(selection: $selectedCategoryId)
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(selection: $selectedAccountId, required: txType == .spend)
            }
            .alert("New person", isPresented: Binding(
                get: { pendingNewPersonRowID != nil },
                set: { if !$0 { pendingNewPersonRowID = nil } }
            )) {
                TextField("Name", text: $newPersonName)
                Button("Cancel", role: .cancel) { pendingNewPersonRowID = nil; newPersonName = "" }
                Button("Add") {
                    let name = newPersonName.trimmingCharacters(in: .whitespaces)
                    if let id = pendingNewPersonRowID,
                       let idx = splitRows.firstIndex(where: { $0.id == id }), !name.isEmpty {
                        splitRows[idx].personName = name
                    }
                    pendingNewPersonRowID = nil; newPersonName = ""
                }
            }
            .alert("New person", isPresented: $showOwedNewAlert) {
                TextField("Name", text: $owedNewName)
                Button("Cancel", role: .cancel) { owedNewName = "" }
                Button("Add") {
                    let name = owedNewName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { owedToPerson = name }
                    owedNewName = ""
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              (Double(amountPaid) ?? 0) > 0 else { return false }
        if txType == .income { return true }
        // Spend
        guard selectedCategoryId != nil else { return false }
        if paidByOther {
            return !owedToPerson.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return selectedAccountId != nil && splitValid   // account required when I paid
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
        if let person = tx.owedTo, !person.isEmpty {
            paidByOther  = true
            owedToPerson = person
        }
        if !tx.splitShares.isEmpty {
            isSplit   = true
            splitRows = tx.splitShares.map {
                SplitRowInput(personName: $0.personName, amountText: String($0.amount))
            }
        }
    }

    /// Builds the SplitShare list from the editable rows (spend + split only).
    /// Rows for the same person are merged into a single share so one person never
    /// produces multiple Splitwise entries on the same transaction.
    private var splitSharesForSave: [SplitShare] {
        guard txType == .spend, isSplit else { return [] }
        var totals: [String: Double] = [:]
        var order: [String] = []
        for r in splitRows {
            let amt  = Double(r.amountText) ?? 0
            let name = r.personName.trimmingCharacters(in: .whitespaces)
            guard amt > 0, !name.isEmpty else { continue }
            if totals[name] == nil { order.append(name) }
            totals[name, default: 0] += amt
        }
        return order.map { SplitShare(personName: $0, amount: totals[$0] ?? 0) }
    }

    private func saveAndDismiss() {
        guard !isSaving else { return }   // ignore a second tap while dismissing
        isSaving = true
        let catId = selectedCategoryId ?? store.categories.first?.id ?? UUID()
        let paid = Double(amountPaid) ?? 0
        let back = 0.0   // Setup A: spends are the full amount; money coming back is logged as separate Income

        // "Someone else paid" → no account, an "I owe" link, and no split shares.
        let isOwed = (txType == .spend && paidByOther)
        let acctId: UUID?   = isOwed ? nil : selectedAccountId
        let owed:   String? = isOwed ? owedToPerson.trimmingCharacters(in: .whitespaces) : nil
        let shares = isOwed ? [] : splitSharesForSave

        if let ex = transaction {
            var u = ex
            u.type = txType; u.date = date; u.title = title
            u.amountPaid = paid; u.amountBack = back
            u.accountId  = acctId
            u.splitShares = shares
            u.owedTo = owed
            store.updateTransaction(u)
        } else {
            store.addTransaction(Transaction(
                date: date, title: title,
                categoryId: catId,
                amountPaid: paid, amountBack: back,
                type: txType,
                accountId: acctId,
                splitShares: shares,
                owedTo: owed
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
