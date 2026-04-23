import SwiftUI

// MARK: - Manager Tab

enum ManagerTab: String, CaseIterable {
    case overview   = "Overview"
    case assets     = "Assets"
    case liabilities = "Liabilities"
    case splitwise  = "Splitwise"
}

struct ManagerView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var tab: ManagerTab = .overview
    @State private var showAddAccount = false
    @State private var showAddSplit   = false
    @State private var editAccount: NetWorthAccount?
    @State private var editSplit: SplitEntry?

    var isSheet: Bool = false

    var assets:      [NetWorthAccount] { store.netWorthAccounts.filter {  $0.type.isAsset } }
    var liabilities: [NetWorthAccount] { store.netWorthAccounts.filter { !$0.type.isAsset } }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    AppPageHeader(
                        pageTitle: "Manager",
                        selected: $tab,
                        trailingButton: isSheet ? AnyView(
                            Button("Done") { dismiss() }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.blue)
                        ) : nil
                    )

                    // + button row, just below pills
                    if tab != .overview {
                        HStack {
                            Spacer()
                            Button {
                                if tab == .splitwise { showAddSplit = true }
                                else { showAddAccount = true }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(tab == .splitwise ? "Add Person" : "Add Account")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(DS.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(DS.blue.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }

                    switch tab {
                    case .overview:
                        ManagerOverviewTab(
                            onAddAccount:  { showAddAccount = true },
                            onAddSplit:    { showAddSplit = true },
                            onEditAccount: { editAccount = $0 },
                            onEditSplit:   { editSplit = $0 }
                        )
                    case .assets:
                        ManagerAccountsTab(accounts: assets, onAdd: { showAddAccount = true }, onEdit: { editAccount = $0 })
                    case .liabilities:
                        ManagerAccountsTab(accounts: liabilities, onAdd: { showAddAccount = true }, onEdit: { editAccount = $0 })
                    case .splitwise:
                        ManagerSplitTab(onAdd: { showAddSplit = true }, onEdit: { editSplit = $0 })
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddAccount) { AccountFormView() }
            .sheet(isPresented: $showAddSplit)   { SplitFormView() }
            .sheet(item: $editAccount) { AccountFormView(account: $0) }
            .sheet(item: $editSplit)   { SplitFormView(entry: $0) }
        }
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.blue)
                .frame(width: 34, height: 34)
                .background(Circle().fill(DS.surface).overlay(Circle().stroke(DS.cardBorder)))
        }
    }
}

// MARK: - Overview Tab

struct ManagerOverviewTab: View {
    @EnvironmentObject var store: DataStore
    let onAddAccount:  () -> Void
    let onAddSplit:    () -> Void
    let onEditAccount: (NetWorthAccount) -> Void
    let onEditSplit:   (SplitEntry) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                NetWorthSummaryTile()

                ManagerAccountTile(
                    title: "Assets",
                    accounts: store.netWorthAccounts.filter { $0.type.isAsset },
                    emptyMessage: "No assets added yet",
                    onAdd: onAddAccount,
                    onEdit: onEditAccount
                )

                ManagerAccountTile(
                    title: "Liabilities",
                    accounts: store.netWorthAccounts.filter { !$0.type.isAsset },
                    emptyMessage: "No liabilities added yet",
                    onAdd: onAddAccount,
                    onEdit: onEditAccount
                )

                SplitwiseTile(onAdd: onAddSplit, onEdit: onEditSplit)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Accounts Tab (Assets or Liabilities)

struct ManagerAccountsTab: View {
    let accounts: [NetWorthAccount]
    let onAdd: () -> Void
    let onEdit: (NetWorthAccount) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if accounts.isEmpty {
                    EmptyStateView(message: "Nothing here yet — tap + to add")
                        .padding(.top, 60)
                } else {
                    PageTile(header: "\(accounts.count) account\(accounts.count == 1 ? "" : "s")", chevron: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, acct in
                                AccountRow(account: acct, isLast: idx == accounts.count - 1)
                                    .onTapGesture { onEdit(acct) }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Splitwise Tab

struct ManagerSplitTab: View {
    @EnvironmentObject var store: DataStore
    let onAdd: () -> Void
    let onEdit: (SplitEntry) -> Void

    var owesMe: [SplitEntry] { store.splitEntries.filter { $0.direction == .owesMe } }
    var iOwe:   [SplitEntry] { store.splitEntries.filter { $0.direction == .iOwe } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if store.splitEntries.isEmpty {
                    EmptyStateView(message: "No split entries yet — tap + to add")
                        .padding(.top, 60)
                } else {
                    // Owes me
                    if !owesMe.isEmpty {
                        PageTile(header: "Owes Me", chevron: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(owesMe.enumerated()), id: \.element.id) { idx, entry in
                                    SplitRow(entry: entry, isLast: idx == owesMe.count - 1)
                                        .onTapGesture { onEdit(entry) }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }

                    // I owe
                    if !iOwe.isEmpty {
                        PageTile(header: "I Owe", chevron: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(iOwe.enumerated()), id: \.element.id) { idx, entry in
                                    SplitRow(entry: entry, isLast: idx == iOwe.count - 1)
                                        .onTapGesture { onEdit(entry) }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Net Worth Summary Tile

struct NetWorthSummaryTile: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        PageTile(header: "Net Worth", chevron: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.netWorth, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                    .font(.system(size: 42, weight: .bold))
                    .tracking(-1.5)
                    .foregroundStyle(store.netWorth >= 0 ? DS.text : DS.red)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 18).padding(.bottom, 14)

                HStack(spacing: 0) {
                    NetWorthStatColumn(label: "Assets", value: store.totalAssets, color: DS.green)
                    NetWorthStatColumn(label: "Liabilities", value: store.totalLiabilities, color: DS.red)
                    NetWorthStatColumn(
                        label: "Splitwise",
                        value: store.splitEntries.reduce(0) { $0 + $1.netValue },
                        color: DS.blue
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }
}

private struct NetWorthStatColumn: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textSub)
            }
            Text(abs(value), format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Account Tile (for Overview)

struct ManagerAccountTile: View {
    let title: String
    let accounts: [NetWorthAccount]
    let emptyMessage: String
    let onAdd: () -> Void
    let onEdit: (NetWorthAccount) -> Void

    var total: Double { accounts.reduce(0) { $0 + $1.balance } }
    var isAsset: Bool { accounts.first?.type.isAsset ?? true }

    var body: some View {
        PageTile(
            header: title,
            trailingButton: AnyView(
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.blue)
                }
                .buttonStyle(.plain)
            )
        ) {
            if accounts.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textSub)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, acct in
                        AccountRow(account: acct, isLast: idx == accounts.count - 1)
                            .contentShape(Rectangle())
                            .onTapGesture { onEdit(acct) }
                    }
                }

                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 18)

                HStack {
                    Text("Total")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.textSub)
                    Spacer()
                    Text(total, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isAsset ? DS.green : DS.red)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Splitwise Tile (for Overview)

struct SplitwiseTile: View {
    @EnvironmentObject var store: DataStore
    let onAdd: () -> Void
    let onEdit: (SplitEntry) -> Void

    var netSplit: Double { store.splitEntries.reduce(0) { $0 + $1.netValue } }

    var body: some View {
        PageTile(
            header: "Splitwise",
            trailingButton: AnyView(
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.blue)
                }
                .buttonStyle(.plain)
            )
        ) {
            if store.splitEntries.isEmpty {
                Text("No split entries yet")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textSub)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.splitEntries.enumerated()), id: \.element.id) { idx, entry in
                        SplitRow(entry: entry, isLast: idx == store.splitEntries.count - 1)
                            .contentShape(Rectangle())
                            .onTapGesture { onEdit(entry) }
                    }
                }

                Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.horizontal, 18)

                HStack {
                    Text("Net")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.textSub)
                    Spacer()
                    Text(abs(netSplit), format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(netSplit >= 0 ? DS.green : DS.red)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Account Row
struct AccountRow: View {
    let account: NetWorthAccount
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: account.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(account.color)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(account.color.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.text)
                Text(account.type.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textSub)
            }

            Spacer()

            Text(account.balance, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(account.type.isAsset ? DS.green : DS.red)
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

// MARK: - Split Row
struct SplitRow: View {
    let entry: SplitEntry
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(String(entry.personName.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(entry.direction == .owesMe ? DS.green : DS.red)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill((entry.direction == .owesMe ? DS.green : DS.red).opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.personName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.text)
                Text(entry.direction.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textSub)
            }

            Spacer()

            Text(entry.amount, format: .currency(code: DS.currencyCode).precision(.fractionLength(0)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(entry.direction == .owesMe ? DS.green : DS.red)
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

// MARK: - Account Form
struct AccountFormView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    var account: NetWorthAccount?

    @State private var name: String = ""
    @State private var type: NetWorthAccount.AccountType = .checkingOrSavings
    @State private var balanceText: String = ""
    @State private var showConfirm = false

    private var isEditing: Bool { account != nil }
    private var newBalance: Double { Double(balanceText) ?? 0 }

    private static let currFmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0; return f
    }()
    private func fmt(_ v: Double) -> String { Self.currFmt.string(from: NSNumber(value: v)) ?? "$0" }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Form {
                    Section("Details") {
                        TextField("Account name", text: $name)
                            .foregroundStyle(DS.text)
                        Picker("Type", selection: $type) {
                            ForEach(NetWorthAccount.AccountType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                    }
                    Section(type.isAsset ? "Balance" : "Amount Owed") {
                        TextField("0", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(DS.text)
                    }
                    if isEditing {
                        Section {
                            Button("Delete Account", role: .destructive) {
                                store.deleteNetWorthAccount(account!)
                                dismiss()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(DS.bg)
            }
            .navigationTitle(isEditing ? "Update \(name)" : "Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing { showConfirm = true } else { commitSave() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.blue)
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let a = account {
                    name = a.name; type = a.type
                    balanceText = String(format: "%.2f", a.balance)
                }
            }
            .alert("Confirm Update", isPresented: $showConfirm) {
                Button("Edit", role: .cancel) { }
                Button("Confirm") { commitSave() }
            } message: {
                if let a = account {
                    Text("Updating \(a.name)\nfrom \(fmt(a.balance)) → \(fmt(newBalance))")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func commitSave() {
        let balance = newBalance
        if var a = account {
            a.name = name; a.type = type; a.balance = balance
            store.updateNetWorthAccount(a)
        } else {
            store.addNetWorthAccount(NetWorthAccount(
                name: name, type: type, balance: balance,
                icon: type.icon, colorHex: type.defaultColor
            ))
        }
        dismiss()
    }
}

// MARK: - Split Form
struct SplitFormView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    var entry: SplitEntry?

    @State private var personName: String = ""
    @State private var amountText: String = ""
    @State private var direction: SplitEntry.Direction = .owesMe
    @State private var showConfirm = false

    private var isEditing: Bool { entry != nil }
    private var newAmount: Double { Double(amountText) ?? 0 }

    private static let currFmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0; return f
    }()
    private func fmt(_ v: Double) -> String { Self.currFmt.string(from: NSNumber(value: v)) ?? "$0" }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Form {
                    Section("Person") {
                        TextField("Name", text: $personName)
                            .foregroundStyle(DS.text)
                    }
                    Section("Direction") {
                        Picker("Direction", selection: $direction) {
                            Text("Owes me").tag(SplitEntry.Direction.owesMe)
                            Text("I owe").tag(SplitEntry.Direction.iOwe)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Amount") {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(DS.text)
                    }
                    if isEditing {
                        Section {
                            Button("Delete Entry", role: .destructive) {
                                store.deleteSplitEntry(entry!)
                                dismiss()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(DS.bg)
            }
            .navigationTitle(isEditing ? "Update \(personName)" : "Add Split Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isEditing { showConfirm = true } else { commitSave() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.blue)
                    .disabled(personName.isEmpty)
                }
            }
            .onAppear {
                if let e = entry {
                    personName = e.personName
                    amountText = String(format: "%.2f", e.amount)
                    direction  = e.direction
                }
            }
            .alert("Confirm Update", isPresented: $showConfirm) {
                Button("Edit", role: .cancel) { }
                Button("Confirm") { commitSave() }
            } message: {
                if let e = entry {
                    Text("Updating \(e.personName)\nfrom \(fmt(e.amount)) → \(fmt(newAmount))")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func commitSave() {
        let amount = newAmount
        if var e = entry {
            e.personName = personName; e.amount = amount; e.direction = direction
            store.updateSplitEntry(e)
        } else {
            store.addSplitEntry(SplitEntry(personName: personName, amount: amount, direction: direction))
        }
        dismiss()
    }
}
