import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var colorHex: String
    var color: Color { Color(hex: colorHex) }
}

// MARK: - Net Worth Models

struct NetWorthAccount: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: AccountType
    var balance: Double
    var icon: String
    var colorHex: String

    var color: Color { Color(hex: colorHex) }

    enum AccountType: String, Codable, CaseIterable {
        case checkingOrSavings = "Checking / Savings"
        case investment        = "Investment"
        case creditCard        = "Credit Card"
        case loan              = "Loan"

        var isAsset: Bool { self == .checkingOrSavings || self == .investment }

        var icon: String {
            switch self {
            case .checkingOrSavings: return "building.columns.fill"
            case .investment:        return "chart.line.uptrend.xyaxis.circle.fill"
            case .creditCard:        return "creditcard.fill"
            case .loan:              return "doc.text.fill"
            }
        }

        var defaultColor: String {
            switch self {
            case .checkingOrSavings: return "#30D158"
            case .investment:        return "#4B8BFF"
            case .creditCard:        return "#FF453A"
            case .loan:              return "#FF9F0A"
            }
        }
    }
}

struct SplitEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var personName: String
    var amount: Double
    var direction: Direction
    var transactionId: UUID? = nil   // set when auto-created from a split spend

    enum Direction: String, Codable {
        case owesMe = "Owes me"
        case iOwe   = "I owe"
    }

    // Positive = asset, negative = liability
    var netValue: Double { direction == .owesMe ? amount : -amount }
}

struct NetWorthSnapshot: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var netWorth: Double
    var totalAssets: Double
    var totalLiabilities: Double
}

/// One person's portion of a split spend (the part they owe you).
struct SplitShare: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var personName: String
    var amount: Double
}

struct Transaction: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var title: String
    var categoryId: UUID
    var amountPaid: Double
    var amountBack: Double
    var type: TransactionType = .spend
    var accountId: UUID? = nil   // linked NetWorthAccount (nil = unlinked / legacy)
    var splitShares: [SplitShare] = []   // others' portions of this spend (each → an "Owes me" entry)
    var owedTo: String? = nil    // set when someone else paid and you owe them (→ an "I owe" entry)

    enum TransactionType: String, Codable, CaseIterable {
        case spend  = "Spend"
        case income = "Income"
    }

    var isIncome: Bool { type == .income }
    var isSplit: Bool { !splitShares.isEmpty }
    /// True when someone else paid this and you owe your share (no account was charged).
    var isOwed: Bool { (owedTo?.isEmpty == false) }

    /// Total others owe you on this spend.
    var othersShare: Double { splitShares.reduce(0) { $0 + $1.amount } }

    /// Your portion of a spend — what every spend report should count as your expense.
    /// (Full amount minus any legacy amount-back and minus others' shares.)
    var expenseAmount: Double {
        guard !isIncome else { return 0 }
        return max(0, amountPaid - amountBack - othersShare)
    }

    // Spend: your share (positive expense). Income: treated as negative spend (credit).
    var netAmount: Double {
        type == .income ? -amountPaid : expenseAmount
    }
}

final class NavState: ObservableObject {
    @Published var mainTab: String = "Home"
}

/// A payment from a bank/checking account to a credit card (pays down card debt).
/// Not visible in transaction lists — tracked separately so balances stay accurate.
struct AccountTransfer: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
    var fromAccountId: UUID   // bank / checking — balance decreases
    var toAccountId: UUID     // credit card / loan — balance decreases (debt reduced)
    var note: String = ""
}

// MARK: - File-Based Persistence

/// Stores each collection as a JSON file in ~/Documents/BudgetTrackerData/.
/// On first launch it transparently migrates any existing UserDefaults data to files
/// so no data is lost when the app updates.
private final class FilePersistence {
    static let shared = FilePersistence()

    private init() {
        try? FileManager.default.createDirectory(at: baseURL,
                                                  withIntermediateDirectories: true)
    }

    private var baseURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BudgetTrackerData", isDirectory: true)
    }

    /// ISO-8601 dates — human-readable, unambiguous across time zones.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting  = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func save<T: Encodable>(_ value: T, key: String) {
        let url = baseURL.appendingPathComponent("\(key).json")
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)   // atomic = no partial-write corruption
    }

    /// Loads from the JSON file first.
    /// If the file doesn't exist yet, checks UserDefaults (legacy migration path):
    /// reads the value, writes it to the file, and returns it so the next launch
    /// comes straight from the file.
    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        let url = baseURL.appendingPathComponent("\(key).json")
        if let data  = try? Data(contentsOf: url),
           let value = try? decoder.decode(type, from: data) {
            return value
        }
        // UserDefaults migration path (old JSONEncoder used .deferredToDate, so
        // use a plain JSONDecoder here to read the legacy format correctly)
        if let data  = UserDefaults.standard.data(forKey: key),
           let value = try? JSONDecoder().decode(type, from: data) {
            save(value, key: key)   // write to file — next launch skips UserDefaults
            return value
        }
        return nil
    }
}

// MARK: - Data Store

final class DataStore: ObservableObject {
    @Published var categories: [Category] = []
    @Published var transactions: [Transaction] = []
    @Published var netWorthAccounts: [NetWorthAccount] = []
    @Published var splitEntries: [SplitEntry] = []
    @Published var netWorthSnapshots: [NetWorthSnapshot] = []
    @Published var accountTransfers: [AccountTransfer] = []

    /// The local folder where all JSON data files live.
    static var dataDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BudgetTrackerData", isDirectory: true)
    }

    private let categoriesKey         = "categories_v2"
    private let paymentMethodsKey     = "paymentMethods_v1"
    private let transactionsKey       = "transactions_v1"
    private let netWorthAccountsKey   = "netWorthAccounts_v1"
    private let splitEntriesKey       = "splitEntries_v1"
    private let netWorthSnapshotsKey  = "netWorthSnapshots_v1"
    private let accountTransfersKey   = "accountTransfers_v1"

    init() { load() }

    // MARK: Net Worth Computed
    /// Pure bank/investment accounts only — does NOT include splitwise
    var totalAssets: Double {
        netWorthAccounts.filter { $0.type.isAsset }.reduce(0) { $0 + $1.balance }
    }
    /// Pure credit card / loan balances only — does NOT include splitwise
    var totalLiabilities: Double {
        netWorthAccounts.filter { !$0.type.isAsset }.reduce(0) { $0 + $1.balance }
    }
    /// Net amount owed to you (owesMe − iOwe) from splitwise entries
    var splitwiseNet: Double {
        let owesMe = splitEntries.filter { $0.direction == .owesMe }.reduce(0) { $0 + $1.amount }
        let iOwe   = splitEntries.filter { $0.direction == .iOwe   }.reduce(0) { $0 + $1.amount }
        return owesMe - iOwe
    }
    var netWorth: Double { totalAssets - totalLiabilities + splitwiseNet }

    // MARK: Snapshot — call after any Manager save
    func takeSnapshot() {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let snap  = NetWorthSnapshot(
            date: today,
            netWorth: netWorth,
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities
        )
        // Replace any existing snapshot for today, otherwise append
        if let idx = netWorthSnapshots.firstIndex(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            netWorthSnapshots[idx] = snap
        } else {
            netWorthSnapshots.append(snap)
        }
        netWorthSnapshots.sort { $0.date < $1.date }
        save()
    }

    // MARK: CRUD — Net Worth Accounts
    // Snapshot on add/update only — deletes don't write a graph point so a
    // mistaken delete (or a close-and-move-money flow) doesn't show a fake dip.
    func addNetWorthAccount(_ a: NetWorthAccount)    { netWorthAccounts.append(a); takeSnapshot() }
    func updateNetWorthAccount(_ a: NetWorthAccount) {
        if let i = netWorthAccounts.firstIndex(where: { $0.id == a.id }) { netWorthAccounts[i] = a; takeSnapshot() }
    }
    func deleteNetWorthAccount(_ a: NetWorthAccount) { netWorthAccounts.removeAll { $0.id == a.id }; save() }

    // MARK: CRUD — Split Entries
    // Same policy: snapshot on add/update, plain save on delete.
    func addSplitEntry(_ s: SplitEntry)    { splitEntries.append(s); takeSnapshot() }
    func updateSplitEntry(_ s: SplitEntry) {
        if let i = splitEntries.firstIndex(where: { $0.id == s.id }) { splitEntries[i] = s; takeSnapshot() }
    }
    func deleteSplitEntry(_ s: SplitEntry) { splitEntries.removeAll { $0.id == s.id }; save() }

    // MARK: Helpers
    func category(for id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    func transactions(for month: Date) -> [Transaction] {
        let cal = Calendar.current
        return transactions
            .filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    func totalPaid(for month: Date) -> Double {
        transactions(for: month).reduce(0) { $0 + $1.amountPaid }
    }
    func totalBack(for month: Date) -> Double {
        transactions(for: month).reduce(0) { $0 + $1.amountBack }
    }
    func netSpent(for month: Date) -> Double {
        transactions(for: month)
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.expenseAmount }
    }
    func netSpent(categoryId: UUID, month: Date) -> Double {
        transactions(for: month)
            .filter { $0.categoryId == categoryId && !$0.isIncome }
            .reduce(0) { $0 + $1.expenseAmount }
    }

    func totalIncome(for month: Date) -> Double {
        transactions(for: month)
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amountPaid }
    }

    func totalExpense(for month: Date) -> Double {
        transactions(for: month)
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.expenseAmount }
    }

    func allMonths() -> [Date] {
        let cal = Calendar.current
        var seen = Set<String>()
        var months: [Date] = []
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        for tx in transactions {
            let key = fmt.string(from: tx.date)
            if seen.insert(key).inserted {
                let comps = cal.dateComponents([.year, .month], from: tx.date)
                if let d = cal.date(from: comps) { months.append(d) }
            }
        }
        return months.sorted { $0 > $1 }
    }

    func transactions(categoryId: UUID) -> [Transaction] {
        transactions.filter { $0.categoryId == categoryId }.sorted { $0.date > $1.date }
    }

    func averageMonthlySpend(categoryId: UUID) -> Double {
        let monthsWithData = allMonths().filter { netSpent(categoryId: categoryId, month: $0) > 0 }
        guard !monthsWithData.isEmpty else { return 0 }
        let total = monthsWithData.reduce(0.0) { $0 + netSpent(categoryId: categoryId, month: $1) }
        return total / Double(monthsWithData.count)
    }

    func spentLast7Days() -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return transactions
            .filter { $0.date >= cutoff && $0.type == .spend }
            .reduce(0) { $0 + $1.netAmount }
    }

    func transactionsLast7Days() -> [Transaction] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return transactions
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    /// Daily spend for a month. Pass `categoryIds` to restrict to those categories
    /// (nil or empty = all categories).
    func dailySpend(for month: Date, categoryIds: Set<UUID>? = nil) -> [(day: Int, amount: Double)] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let filter = (categoryIds?.isEmpty == false) ? categoryIds : nil
        return range.map { day -> (Int, Double) in
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            guard let date = cal.date(from: comps) else { return (day, 0) }
            let total = transactions
                .filter {
                    cal.isDate($0.date, inSameDayAs: date) && !$0.isIncome
                    && (filter == nil || filter!.contains($0.categoryId))
                }
                .reduce(0) { $0 + $1.expenseAmount }
            return (day, total)
        }
    }

    func cumulativeSpend(for month: Date, categoryIds: Set<UUID>? = nil) -> [(day: Int, cumulative: Double)] {
        let daily = dailySpend(for: month, categoryIds: categoryIds)
        var running = 0.0
        return daily.map { entry in
            running += entry.amount
            return (entry.day, running)
        }
    }

    func monthlySpend(categoryId: UUID, months: Int = 6) -> [(month: Date, amount: Double)] {
        let start = Date().startOfMonth()
        return (0..<months).map { offset in
            let month = start.adding(months: -offset)
            return (month, netSpent(categoryId: categoryId, month: month))
        }.reversed()
    }

    // MARK: Balance Delta Helpers

    /// How much a transaction changes the linked account's balance.
    /// A spend moves the account by the FULL amount paid (the whole charge hits your
    /// card/account) — split shares are tracked separately as Splitwise receivables.
    /// Spend from asset (checking): balance goes down. Spend on liability (credit): balance goes up.
    /// Income to asset: balance goes up. Income to liability: balance goes down (paying off debt).
    private func balanceDelta(for tx: Transaction) -> Double {
        guard let accId = tx.accountId,
              let acc = netWorthAccounts.first(where: { $0.id == accId }) else { return 0 }
        switch tx.type {
        case .spend:  return acc.type.isAsset ? -tx.amountPaid : +tx.amountPaid
        case .income: return acc.type.isAsset ? +tx.amountPaid : -tx.amountPaid
        }
    }

    /// Reverses `old` delta then applies `new` delta, then saves/snapshots.
    private func applyBalanceDeltas(reverse old: Transaction?, apply new: Transaction?) {
        var changed = false
        if let o = old, let id = o.accountId,
           let i = netWorthAccounts.firstIndex(where: { $0.id == id }) {
            netWorthAccounts[i].balance -= balanceDelta(for: o)
            changed = true
        }
        if let n = new, let id = n.accountId,
           let i = netWorthAccounts.firstIndex(where: { $0.id == id }) {
            netWorthAccounts[i].balance += balanceDelta(for: n)
            changed = true
        }
        if changed { takeSnapshot() } else { save() }
    }

    // MARK: CRUD — Transfers (Credit Card Payments)
    func addTransfer(_ t: AccountTransfer) {
        if let i = netWorthAccounts.firstIndex(where: { $0.id == t.fromAccountId }) {
            netWorthAccounts[i].balance -= t.amount
        }
        if let i = netWorthAccounts.firstIndex(where: { $0.id == t.toAccountId }) {
            netWorthAccounts[i].balance -= t.amount
        }
        accountTransfers.append(t)
        takeSnapshot()
    }

    func deleteTransfer(_ t: AccountTransfer) {
        if let i = netWorthAccounts.firstIndex(where: { $0.id == t.fromAccountId }) {
            netWorthAccounts[i].balance += t.amount
        }
        if let i = netWorthAccounts.firstIndex(where: { $0.id == t.toAccountId }) {
            netWorthAccounts[i].balance += t.amount
        }
        accountTransfers.removeAll { $0.id == t.id }
        takeSnapshot()
    }

    // MARK: CRUD — Transactions
    func addTransaction(_ t: Transaction) {
        transactions.append(t)
        syncSplitEntries(for: t)
        applyBalanceDeltas(reverse: nil, apply: t)
    }
    func updateTransaction(_ t: Transaction) {
        guard let i = transactions.firstIndex(where: { $0.id == t.id }) else { return }
        let old = transactions[i]
        transactions[i] = t
        syncSplitEntries(for: t)
        applyBalanceDeltas(reverse: old, apply: t)
    }
    func deleteTransaction(_ t: Transaction) {
        transactions.removeAll { $0.id == t.id }
        splitEntries.removeAll { $0.transactionId == t.id }
        applyBalanceDeltas(reverse: t, apply: nil)
    }

    /// Wipes all activity — transactions, splitwise entries, transfers, and net-worth
    /// history — but keeps accounts (with current balances) and categories intact.
    func clearActivity() {
        transactions      = []
        splitEntries      = []
        accountTransfers  = []
        netWorthSnapshots = []
        save()
    }

    // MARK: Split spend ↔ Splitwise linkage

    /// Rebuilds the "Owes me" entries linked to a split spend. Called on add/update.
    /// Note: editing a split regenerates its receivables — any partial settlement on
    /// the prior entries is reset (the amounts may have changed).
    private func syncSplitEntries(for tx: Transaction) {
        splitEntries.removeAll { $0.transactionId == tx.id }
        guard !tx.isIncome else { return }
        // Others owe me (I paid, split among people).
        for share in tx.splitShares where share.amount > 0 {
            splitEntries.append(SplitEntry(
                personName: share.personName,
                amount: share.amount,
                direction: .owesMe,
                transactionId: tx.id
            ))
        }
        // I owe (someone else paid; my whole share is owed to them).
        if let person = tx.owedTo, !person.isEmpty, tx.amountPaid > 0 {
            splitEntries.append(SplitEntry(
                personName: person,
                amount: tx.amountPaid,
                direction: .iOwe,
                transactionId: tx.id
            ))
        }
    }

    /// A person's net balance: positive = they owe you, negative = you owe them.
    /// (Sum of their "Owes me" entries minus their "I owe" entries.)
    func netForPerson(_ name: String) -> Double {
        splitEntries
            .filter { $0.personName == name }
            .reduce(0) { $0 + ($1.direction == .owesMe ? $1.amount : -$1.amount) }
    }

    /// Records a person paying back their net balance (full or partial). Deposits the
    /// paid amount into `accountId` (a checking/asset account). A full settle squares the
    /// whole relationship — every entry for that person (both directions) is cleared.
    /// A partial payment reduces their "Owes me" entries oldest-first. Net worth is
    /// unchanged (asset up, receivable down) — never counted as income.
    func settlePerson(_ name: String, amount: Double, into accountId: UUID) {
        let net = netForPerson(name)
        guard net > 0.005 else { return }            // only a net-positive person can pay you
        let pay = min(max(0, amount), net)
        guard pay > 0 else { return }

        if let ai = netWorthAccounts.firstIndex(where: { $0.id == accountId }) {
            netWorthAccounts[ai].balance += pay      // money lands in checking
        }

        if pay >= net - 0.005 {
            // Full settle — clear the entire relationship (both directions).
            splitEntries.removeAll { $0.personName == name }
        } else {
            // Partial — reduce their "Owes me" entries oldest-first (net drops by `pay`).
            var remaining = pay
            var i = 0
            while i < splitEntries.count && remaining > 0.005 {
                if splitEntries[i].personName == name && splitEntries[i].direction == .owesMe {
                    let take = min(remaining, splitEntries[i].amount)
                    splitEntries[i].amount -= take
                    remaining -= take
                    if splitEntries[i].amount <= 0.005 {
                        splitEntries.remove(at: i)
                        continue
                    }
                }
                i += 1
            }
        }
        takeSnapshot()
    }

    /// Pays back a person you owe (full or partial). Money leaves `accountId` (checking).
    /// A full payment squares the relationship; a partial reduces your "I owe" entries
    /// oldest-first. Net worth unchanged (asset down, liability down).
    func payBackPerson(_ name: String, amount: Double, from accountId: UUID) {
        let owe = -netForPerson(name)            // positive = you owe them
        guard owe > 0.005 else { return }
        let pay = min(max(0, amount), owe)
        guard pay > 0 else { return }

        if let ai = netWorthAccounts.firstIndex(where: { $0.id == accountId }) {
            netWorthAccounts[ai].balance -= pay  // money leaves checking
        }

        if pay >= owe - 0.005 {
            splitEntries.removeAll { $0.personName == name }
        } else {
            var remaining = pay
            var i = 0
            while i < splitEntries.count && remaining > 0.005 {
                if splitEntries[i].personName == name && splitEntries[i].direction == .iOwe {
                    let take = min(remaining, splitEntries[i].amount)
                    splitEntries[i].amount -= take
                    remaining -= take
                    if splitEntries[i].amount <= 0.005 {
                        splitEntries.remove(at: i)
                        continue
                    }
                }
                i += 1
            }
        }
        takeSnapshot()
    }

    // MARK: Category color palette
    static let categoryColorPalette: [String] = [
        "#FF9F0A", "#4B8BFF", "#30D158", "#FF453A",
        "#BF5AF2", "#5AC8FA", "#FF6FAD", "#FFD60A",
        "#4CD9C0", "#AC8E68", "#FF8C42", "#6C9BD2"
    ]

    /// Returns the next palette color not already used by an existing category.
    /// If all palette colors are taken, returns the least-used one.
    func nextCategoryColor() -> String {
        let used = Set(categories.map(\.colorHex))
        for hex in DataStore.categoryColorPalette {
            if !used.contains(hex) { return hex }
        }
        // All colors used — find the least-used one
        let counts = Dictionary(grouping: categories, by: \.colorHex).mapValues(\.count)
        return DataStore.categoryColorPalette.min(by: {
            counts[$0, default: 0] < counts[$1, default: 0]
        }) ?? DataStore.categoryColorPalette[0]
    }

    // MARK: CRUD — Categories
    func addCategory(_ c: Category)    { categories.append(c); save() }
    func updateCategory(_ c: Category) {
        if let i = categories.firstIndex(where: { $0.id == c.id }) { categories[i] = c; save() }
    }
    func deleteCategory(_ c: Category) { categories.removeAll { $0.id == c.id }; save() }

    // MARK: Persistence
    func save() {
        let fp = FilePersistence.shared
        fp.save(categories,        key: categoriesKey)
        fp.save(transactions,      key: transactionsKey)
        fp.save(netWorthAccounts,  key: netWorthAccountsKey)
        fp.save(splitEntries,      key: splitEntriesKey)
        fp.save(netWorthSnapshots, key: netWorthSnapshotsKey)
        fp.save(accountTransfers,  key: accountTransfersKey)
    }

    func load() {
        let fp = FilePersistence.shared

        // Load ALL collections before calling any save()-invoking helpers
        // (prevents migrateCategoriesToUniquePaletteColors from saving empty arrays)
        if let v = fp.load([Category].self, key: categoriesKey)          { categories       = v }
        if let v = fp.load([Transaction].self, key: transactionsKey)      { transactions     = v }
        if let v = fp.load([NetWorthAccount].self, key: netWorthAccountsKey) { netWorthAccounts = v }
        if let v = fp.load([SplitEntry].self, key: splitEntriesKey)       { splitEntries     = v }
        if let v = fp.load([NetWorthSnapshot].self, key: netWorthSnapshotsKey) {
            netWorthSnapshots = v.sorted { $0.date < $1.date }
        }
        if let v = fp.load([AccountTransfer].self, key: accountTransfersKey) { accountTransfers = v }

        // Run category color migration AFTER all data is loaded, so save() is safe.
        migrateCategoriesToUniquePaletteColors()

        // Persist everything to files:
        //  • seeds that don't self-persist,
        //  • any UserDefaults → file migration that FilePersistence.load() already
        //    wrote individually (this just consolidates in one pass).
        save()
    }

    /// One-time fix: if any two categories share the same colorHex, reassign all
    /// duplicate-coloured categories unique palette colours and persist.
    private func migrateCategoriesToUniquePaletteColors() {
        var colorCounts: [String: Int] = [:]
        for cat in categories { colorCounts[cat.colorHex, default: 0] += 1 }
        guard colorCounts.values.contains(where: { $0 > 1 }) else { return }

        // Collect which palette colours are already uniquely claimed
        var usedHexes: Set<String> = Set(
            colorCounts.filter { $0.value == 1 }.keys
        )
        var paletteIdx = 0

        func nextPaletteColor() -> String {
            while true {
                let candidate = DataStore.categoryColorPalette[paletteIdx % DataStore.categoryColorPalette.count]
                paletteIdx += 1
                if !usedHexes.contains(candidate) {
                    usedHexes.insert(candidate)
                    return candidate
                }
            }
        }

        categories = categories.map { cat in
            guard colorCounts[cat.colorHex, default: 0] > 1 else { return cat }
            var updated = cat
            updated.colorHex = nextPaletteColor()
            return updated
        }
        save()
    }

}

// MARK: - Backup

struct AppBackup: Codable {
    let exportDate: Date
    let categories: [Category]
    let transactions: [Transaction]
    let netWorthAccounts: [NetWorthAccount]
    let splitEntries: [SplitEntry]
    let netWorthSnapshots: [NetWorthSnapshot]
    var accountTransfers: [AccountTransfer] = []
}

// Tolerant decoding so older backups (missing newer fields) still import cleanly.
extension AppBackup {
    private enum CodingKeys: String, CodingKey {
        case exportDate, categories, transactions, netWorthAccounts
        case splitEntries, netWorthSnapshots, accountTransfers
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exportDate        = try c.decode(Date.self, forKey: .exportDate)
        categories        = try c.decode([Category].self, forKey: .categories)
        transactions      = try c.decode([Transaction].self, forKey: .transactions)
        netWorthAccounts  = try c.decode([NetWorthAccount].self, forKey: .netWorthAccounts)
        splitEntries      = try c.decode([SplitEntry].self, forKey: .splitEntries)
        netWorthSnapshots = try c.decode([NetWorthSnapshot].self, forKey: .netWorthSnapshots)
        accountTransfers  = try c.decodeIfPresent([AccountTransfer].self, forKey: .accountTransfers) ?? []
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exportDate,        forKey: .exportDate)
        try c.encode(categories,        forKey: .categories)
        try c.encode(transactions,      forKey: .transactions)
        try c.encode(netWorthAccounts,  forKey: .netWorthAccounts)
        try c.encode(splitEntries,      forKey: .splitEntries)
        try c.encode(netWorthSnapshots, forKey: .netWorthSnapshots)
        try c.encode(accountTransfers,  forKey: .accountTransfers)
    }
}

extension Transaction {
    private enum CodingKeys: String, CodingKey {
        case id, date, title, categoryId, amountPaid, amountBack, type, accountId, splitShares, owedTo
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date        = try c.decode(Date.self, forKey: .date)
        title       = try c.decode(String.self, forKey: .title)
        categoryId  = try c.decode(UUID.self, forKey: .categoryId)
        amountPaid  = try c.decode(Double.self, forKey: .amountPaid)
        amountBack  = try c.decodeIfPresent(Double.self, forKey: .amountBack) ?? 0
        type        = try c.decodeIfPresent(TransactionType.self, forKey: .type) ?? .spend
        accountId   = try c.decodeIfPresent(UUID.self, forKey: .accountId)
        splitShares = try c.decodeIfPresent([SplitShare].self, forKey: .splitShares) ?? []
        owedTo      = try c.decodeIfPresent(String.self, forKey: .owedTo)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                 forKey: .id)
        try c.encode(date,               forKey: .date)
        try c.encode(title,              forKey: .title)
        try c.encode(categoryId,         forKey: .categoryId)
        try c.encode(amountPaid,         forKey: .amountPaid)
        try c.encode(amountBack,         forKey: .amountBack)
        try c.encode(type,               forKey: .type)
        try c.encodeIfPresent(accountId, forKey: .accountId)
        try c.encode(splitShares,        forKey: .splitShares)
        try c.encodeIfPresent(owedTo,    forKey: .owedTo)
    }
}

extension DataStore {
    func exportCSV() -> Data? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var rows = ["Date,Title,Category,Account,Type,Amount Paid,Owed by Others,My Share"]
        for tx in transactions.sorted(by: { $0.date > $1.date }) {
            let cat  = category(for: tx.categoryId)?.name ?? "Unknown"
            let acct = tx.accountId.flatMap { id in netWorthAccounts.first { $0.id == id }?.name } ?? ""
            let date = fmt.string(from: tx.date)
            // others owed = legacy amount-back + split shares; "My Share" is your expense
            let owed = tx.isIncome ? 0 : (tx.amountBack + tx.othersShare)
            let net  = tx.isIncome ? tx.amountPaid : tx.expenseAmount
            let type = tx.isIncome ? "Income" : "Spend"
            // Escape commas in text fields
            let title = tx.title.contains(",") ? "\"\(tx.title)\"" : tx.title
            let catE  = cat.contains(",")      ? "\"\(cat)\""      : cat
            let acctE = acct.contains(",")     ? "\"\(acct)\""     : acct
            rows.append("\(date),\(title),\(catE),\(acctE),\(type),\(tx.amountPaid),\(owed),\(net)")
        }
        return rows.joined(separator: "\n").data(using: .utf8)
    }

    func exportBackup() -> Data? {
        let backup = AppBackup(
            exportDate: Date(),
            categories: categories,
            transactions: transactions,
            netWorthAccounts: netWorthAccounts,
            splitEntries: splitEntries,
            netWorthSnapshots: netWorthSnapshots,
            accountTransfers: accountTransfers
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    /// Imports a backup. When `preservingAccounts` is true, only the transactions are
    /// restored (plus any categories they reference that you don't already have) — your
    /// current accounts, balances, splits, transfers, and history are left untouched.
    /// Restored transactions are unlinked to accounts, so balances are unaffected.
    func importBackup(from data: Data, preservingAccounts: Bool = false) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)
        if preservingAccounts {
            transactions = backup.transactions
            // Add any categories the restored transactions need but that aren't present.
            let existing = Set(categories.map { $0.id })
            for c in backup.categories where !existing.contains(c.id) { categories.append(c) }
            save()
        } else {
            categories        = backup.categories
            transactions      = backup.transactions
            netWorthAccounts  = backup.netWorthAccounts
            splitEntries      = backup.splitEntries
            netWorthSnapshots = backup.netWorthSnapshots
            accountTransfers  = backup.accountTransfers
            save()
        }
    }
}

// MARK: - Color Extension

extension UIColor {
    /// Convenience init so UIColor(dynamicProvider:) closures can use hex strings.
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = (int >> 16) & 0xFF
        let g = (int >> 8)  & 0xFF
        let b =  int        & 0xFF
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

// MARK: - Date Helpers

extension Date {
    var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: self)
    }
    var shortMonthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMM yy"; return f.string(from: self)
    }
    func startOfMonth() -> Date {
        Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: self)
        ) ?? self
    }
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
}
