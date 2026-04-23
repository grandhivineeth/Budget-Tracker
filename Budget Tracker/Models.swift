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

struct Transaction: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var title: String
    var categoryId: UUID
    var amountPaid: Double
    var amountBack: Double
    var type: TransactionType = .spend

    enum TransactionType: String, Codable, CaseIterable {
        case spend  = "Spend"
        case income = "Income"
    }

    // Spend: positive (expense). Income: treated as negative spend (credit).
    var netAmount: Double {
        type == .income ? -amountPaid : amountPaid - amountBack
    }
    var isIncome: Bool { type == .income }
}

final class NavState: ObservableObject {
    @Published var mainTab: String = "Home"
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

    private let categoriesKey        = "categories_v2"
    private let paymentMethodsKey    = "paymentMethods_v1"
    private let transactionsKey      = "transactions_v1"
    private let netWorthAccountsKey  = "netWorthAccounts_v1"
    private let splitEntriesKey      = "splitEntries_v1"
    private let netWorthSnapshotsKey = "netWorthSnapshots_v1"

    init() { load() }

    // MARK: Net Worth Computed
    var totalAssets: Double {
        netWorthAccounts.filter { $0.type.isAsset }.reduce(0) { $0 + $1.balance }
        + splitEntries.filter { $0.direction == .owesMe }.reduce(0) { $0 + $1.amount }
    }
    var totalLiabilities: Double {
        netWorthAccounts.filter { !$0.type.isAsset }.reduce(0) { $0 + $1.balance }
        + splitEntries.filter { $0.direction == .iOwe }.reduce(0) { $0 + $1.amount }
    }
    var netWorth: Double { totalAssets - totalLiabilities }

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
            .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
    }
    func netSpent(categoryId: UUID, month: Date) -> Double {
        transactions(for: month)
            .filter { $0.categoryId == categoryId && !$0.isIncome }
            .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
    }

    func totalIncome(for month: Date) -> Double {
        transactions(for: month)
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amountPaid }
    }

    func totalExpense(for month: Date) -> Double {
        transactions(for: month)
            .filter { !$0.isIncome }
            .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
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

    func dailySpend(for month: Date) -> [(day: Int, amount: Double)] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        return range.map { day -> (Int, Double) in
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            guard let date = cal.date(from: comps) else { return (day, 0) }
            let total = transactions
                .filter { cal.isDate($0.date, inSameDayAs: date) && !$0.isIncome }
                .reduce(0) { $0 + max(0, $1.amountPaid - $1.amountBack) }
            return (day, total)
        }
    }

    func cumulativeSpend(for month: Date) -> [(day: Int, cumulative: Double)] {
        let daily = dailySpend(for: month)
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

    // MARK: CRUD — Transactions
    func addTransaction(_ t: Transaction)    { transactions.append(t); save() }
    func updateTransaction(_ t: Transaction) {
        if let i = transactions.firstIndex(where: { $0.id == t.id }) { transactions[i] = t; save() }
    }
    func deleteTransaction(_ t: Transaction) { transactions.removeAll { $0.id == t.id }; save() }

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
    }

    func load() {
        let fp = FilePersistence.shared

        // Load ALL collections before calling any save()-invoking helpers
        // (prevents migrateCategoriesToUniquePaletteColors from saving empty arrays)
        if let v = fp.load([Category].self, key: categoriesKey) {
            categories = v
        } else { seedCategories() }

        if let v = fp.load([Transaction].self, key: transactionsKey) {
            transactions = v
        } else { seedTransactions() }

        if let v = fp.load([NetWorthAccount].self, key: netWorthAccountsKey) {
            netWorthAccounts = v
        } else { seedNetWorthAccounts() }

        if let v = fp.load([SplitEntry].self, key: splitEntriesKey) {
            splitEntries = v
        } else { seedSplitEntries() }

        if let v = fp.load([NetWorthSnapshot].self, key: netWorthSnapshotsKey) {
            netWorthSnapshots = v.sorted { $0.date < $1.date }
        } else { seedSnapshots() }

        // Run category color migration AFTER all data is loaded, so save() is safe.
        migrateCategoriesToUniquePaletteColors()

        // One-time imports from spreadsheet screenshots.
        seedMarchTransactions()
        seedAprilTransactions()
        seedAprilLateTransactions()
        seedSalaryIncome()
        seedAccountBalances()
        seedSplitwiseBalances()

        // Persist everything to files:
        //  • seeds that don't self-persist,
        //  • any UserDefaults → file migration that FilePersistence.load() already
        //    wrote individually (this just consolidates in one pass).
        save()
    }

    // MARK: - March 2026 one-time seed
    /// Imports all 45 March 2026 transactions exactly once.
    /// Guarded by a UserDefaults flag so it never runs twice.
    private func seedMarchTransactions() {
        let flagKey = "march2026DataSeeded"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        // Helper: look up category UUID by name (falls back to first category)
        func catID(_ name: String) -> UUID {
            (categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
             ?? categories.first)?.id ?? UUID()
        }

        // Helper: build a Date for March 2026
        let cal = Calendar.current
        func d(_ day: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 3, day: day))!
        }

        // (day, title, category, amountPaid, amountBack)
        let rows: [(Int, String, String, Double, Double)] = [
            (1,  "Room Rent",              "Payments",  1079.22, 405.00),
            (1,  "UPS",                    "Payments",    72.08,   0.00),
            (1,  "Walmart Subscription",   "Payments",    13.86,   0.00),
            (1,  "Walmart",                "Groceries",   46.67,   0.00),
            (3,  "Lyft",                   "Travel",      11.87,   0.00),
            (3,  "Eurest Cafe",            "Food",         9.35,   0.00),
            (5,  "Eurest Cafe",            "Food",         5.83,   0.00),
            (5,  "Lyft",                   "Travel",      13.58,   0.00),
            (6,  "Birthday Expense",       "Luxury",     726.44,   0.00),
            (6,  "Leapfinance",            "EMI",        931.23,   0.00),
            (7,  "Merll's",                "Food",        30.79,   0.00),
            (8,  "Black Cat",              "Food",         7.42,   0.00),
            (9,  "Indymart Kitchen",       "Food",         5.35,   0.00),
            (9,  "Walmart",                "Groceries",    1.34,   0.00),
            (10, "JJ Thai",                "Food",        27.80,   0.00),
            (10, "Indymart",               "Groceries",   10.00,   0.00),
            (11, "Costco",                 "Groceries",   31.66,   0.00),
            (13, "Costco Gas",             "Travel",      10.02,   0.00),
            (13, "Desi Fresh",             "Groceries",   14.99,   0.00),
            (13, "Desi Fresh Kitchen",     "Food",        14.97,   0.00),
            (14, "Costco",                 "Luxury",      42.79,   0.00),
            (14, "Indymart",               "Groceries",    5.49,   0.00),
            (15, "Indymart",               "Groceries",   30.00,   0.00),
            (15, "Indymart Kitchen",       "Food",        45.42,  29.94),
            (15, "Costco Gas",             "Travel",      10.00,   0.00),
            (16, "Dominos",                "Food",        14.96,   0.00),
            (17, "Eurest Cafe",            "Food",         5.83,   0.00),
            (17, "Burger Shop",            "Food",        13.64,   0.00),
            (18, "Eurest Cafe",            "Food",         5.83,   0.00),
            (19, "South Union Bread Cafe", "Food",        15.25,   0.00),
            (19, "Persis Biryani",         "Food",        20.00,   0.00),
            (19, "Walmart",                "Groceries",   33.36,   0.00),
            (19, "Walmart",                "Luxury",      65.00,   0.00),
            (20, "Visible",                "Payments",    25.00,   0.00),
            (21, "Jordan Creek",           "Luxury",      11.18,   0.00),
            (21, "Indymart",               "Groceries",   69.17,   0.00),
            (22, "Costco",                 "Groceries",   35.80,   0.00),
            (22, "Lyft",                   "Travel",       6.91,   0.00),
            (23, "T-Mobile",               "Payments",    87.70,   0.00),
            (26, "Eurest Cafe",            "Food",         5.83,   0.00),
            (27, "Naveen Marriage Gift",   "Luxury",      67.99,  13.00),
            (28, "Great Clips",            "Payments",    29.60,   0.00),
            (29, "Walmart",                "Groceries",   38.85,   0.00),
            (31, "Indymart",               "Groceries",   28.17,   0.00),
            (31, "Lyft",                   "Travel",       7.98,   0.00),
        ]

        for (day, title, catName, paid, back) in rows {
            transactions.append(Transaction(
                date:        d(day),
                title:       title,
                categoryId:  catID(catName),
                amountPaid:  paid,
                amountBack:  back
            ))
        }
    }

    // MARK: - April 2026 one-time seed
    private func seedAprilTransactions() {
        let flagKey = "april2026DataSeeded"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        func catID(_ name: String) -> UUID {
            (categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
             ?? categories.first)?.id ?? UUID()
        }
        let cal = Calendar.current
        func d(_ day: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 4, day: day))!
        }

        // (day, title, category, amountPaid, amountBack)
        let rows: [(Int, String, String, Double, Double)] = [
            (1,  "Room Rent",            "Payments",  1049.95,   0.00),
            (1,  "Walmart Subscription", "Payments",    13.86,   0.00),
            (2,  "Eurest Cafe",          "Food",         5.83,   0.00),
            (5,  "Whole Food Market",    "Groceries",   17.43,   0.00),
            (5,  "Indymart",             "Groceries",   17.73,   0.00),
            (5,  "Persis Biryani",       "Food",        20.00,   0.00),
            (5,  "Pittsburg Temple Trip","Luxury",     583.13, 324.35),
            (5,  "Passport Services",    "Payments",   137.10,   0.00),
            (7,  "Leapfinance",          "EMI",        931.23,   0.00),
            (8,  "Walmart",              "Groceries",   49.32,   0.00),
            (9,  "Lyft",                 "Travel",      14.40,   0.00),
            (12, "Indymart Kitchen",     "Food",        21.69,   0.00),
            (14, "Desi Bites",           "Food",        14.87,   0.00),
            (14, "Cinemark",             "Luxury",       7.00,   0.00),
            (15, "Oral Surgeons PC",     "Payments",   299.00,   0.00),
            (15, "Lyft",                 "Travel",      25.88,   0.00),
            (18, "Persis Biryani",       "Food",        20.00,   0.00),
            (18, "Walmart",              "Groceries",   59.86,   0.00),
        ]

        for (day, title, catName, paid, back) in rows {
            transactions.append(Transaction(
                date:       d(day),
                title:      title,
                categoryId: catID(catName),
                amountPaid: paid,
                amountBack: back
            ))
        }
    }

    // MARK: - Splitwise balances one-time seed
    private func seedSplitwiseBalances() {
        let flagKey = "splitwiseBalancesSeed2026"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        // Net balances from Splitwise (all positive = others owe us)
        let entries: [(String, Double, SplitEntry.Direction)] = [
            ("Anjaan",                  5.80,    .owesMe),
            ("Lavan Theja",           195.63,    .owesMe),
            ("Sateesh Reddy",           7.48,    .owesMe),
            ("Srinivas Mullamuri",    134.75,    .owesMe),
            ("Thaluru Hemanth",         7.48,    .owesMe),
            ("Tharun Reddy Sabbasani", 6680.55,  .owesMe),
        ]

        for (name, amount, direction) in entries {
            // Skip if this person already exists
            guard !splitEntries.contains(where: {
                $0.personName.caseInsensitiveCompare(name) == .orderedSame
            }) else { continue }

            splitEntries.append(SplitEntry(
                personName: name,
                amount:     amount,
                direction:  direction
            ))
        }
        takeSnapshot()
    }

    // MARK: - April 2026 late transactions (4/21–4/22)
    private func seedAprilLateTransactions() {
        let flagKey = "aprilLate2026DataSeeded"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        func catID(_ name: String) -> UUID {
            (categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
             ?? categories.first)?.id ?? UUID()
        }
        let cal = Calendar.current
        func d(_ day: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 4, day: day))!
        }

        let rows: [(Int, String, String, Double)] = [
            (21, "Eurest Cafe", "Food",      5.83),
            (21, "Lyft",        "Travel",    6.91),
            (21, "Indymart",    "Groceries", 62.61),
            (21, "Amazon",      "Luxury",    26.93),
            (22, "Lyft",        "Travel",    16.92),
            (22, "Eurest Cafe", "Food",       4.23),
        ]

        for (day, title, catName, paid) in rows {
            transactions.append(Transaction(
                date:       d(day),
                title:      title,
                categoryId: catID(catName),
                amountPaid: paid,
                amountBack: 0
            ))
        }
    }

    // MARK: - Salary income one-time seed
    private func seedSalaryIncome() {
        let flagKey = "salaryIncomeSeed2026"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        // Use first category as fallback (income type is what matters)
        let fallbackCatID = categories.first?.id ?? UUID()

        let cal = Calendar.current
        func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }

        let salaries: [(Date, Double)] = [
            (d(2026, 3, 13), 1871.17),
            (d(2026, 3, 27), 2207.49),
            (d(2026, 4, 10), 2885.32),
        ]

        for (date, amount) in salaries {
            transactions.append(Transaction(
                date:       date,
                title:      "Salary",
                categoryId: fallbackCatID,
                amountPaid: amount,
                amountBack: 0,
                type:       .income
            ))
        }
    }

    // MARK: - Account balances one-time seed
    /// Upserts all known accounts with current balances exactly once.
    /// Matching is by name (case-insensitive); creates the account if not found.
    private func seedAccountBalances() {
        let flagKey = "accountBalancesSeedApril2026"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        typealias AccountSeed = (name: String, type: NetWorthAccount.AccountType, balance: Double, icon: String, color: String)

        let seeds: [AccountSeed] = [
            // ── Checking / Savings ──────────────────────────────────
            ("Bank of America", .checkingOrSavings, 1000.00,  "building.columns.fill",                  "#30D158"),
            ("Chase",           .checkingOrSavings,  979.23,  "building.columns.fill",                  "#4B8BFF"),
            ("Capital One",     .checkingOrSavings,    7.20,  "building.columns.fill",                  "#FF9F0A"),
            ("Wells Fargo",     .checkingOrSavings, 3448.74,  "building.columns.fill",                  "#30D158"),
            ("Rewards",         .checkingOrSavings,  134.87,  "star.fill",                              "#BF5AF2"),
            // ── Credit Cards ────────────────────────────────────────
            ("BofA Credit",        .creditCard, 2765.00, "creditcard.fill", "#FF453A"),
            ("Chase Freedom",      .creditCard,    0.00, "creditcard.fill", "#4B8BFF"),
            ("Chase Prime",        .creditCard,    0.00, "creditcard.fill", "#4B8BFF"),
            ("Capital One Credit", .creditCard,    0.00, "creditcard.fill", "#FF9F0A"),
            ("Capital One Savour", .creditCard,    0.00, "creditcard.fill", "#FF9F0A"),
            ("Capital One BJs",    .creditCard,    0.00, "creditcard.fill", "#FF9F0A"),
            ("Apple",              .creditCard,    0.00, "creditcard.fill", "#8A8A9A"),
            ("Zolve",              .creditCard,    0.00, "creditcard.fill", "#9B7BFF"),
            ("Discover",           .creditCard,  950.13, "creditcard.fill", "#FF9F0A"),
            ("Amex",               .creditCard,  152.26, "creditcard.fill", "#5AC8FA"),
        ]

        for seed in seeds {
            if let idx = netWorthAccounts.firstIndex(where: {
                $0.name.caseInsensitiveCompare(seed.name) == .orderedSame
            }) {
                // Update balance on existing account
                netWorthAccounts[idx].balance = seed.balance
            } else {
                // Create new account
                netWorthAccounts.append(NetWorthAccount(
                    name:     seed.name,
                    type:     seed.type,
                    balance:  seed.balance,
                    icon:     seed.icon,
                    colorHex: seed.color
                ))
            }
        }
        takeSnapshot()  // Record net worth after balance update
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

    private func seedNetWorthAccounts() {
        netWorthAccounts = [
            NetWorthAccount(name: "Chase Checking",  type: .checkingOrSavings, balance: 6000, icon: "building.columns.fill",                  colorHex: "#30D158"),
            NetWorthAccount(name: "Chase Savings",   type: .checkingOrSavings, balance: 3500, icon: "banknote.fill",                           colorHex: "#4B8BFF"),
            NetWorthAccount(name: "Investments",     type: .investment,         balance: 1500, icon: "chart.line.uptrend.xyaxis.circle.fill",   colorHex: "#9B7BFF"),
            NetWorthAccount(name: "Chase Credit",    type: .creditCard,         balance: 2321, icon: "creditcard.fill",                         colorHex: "#FF453A"),
        ]
        // save() called by load() after all collections are seeded
    }

    private func seedSplitEntries() {
        splitEntries = [
            SplitEntry(personName: "Alex", amount: 150, direction: .owesMe),
            SplitEntry(personName: "Sam",  amount: 350, direction: .owesMe),
        ]
        // save() called by load() after all collections are seeded
    }

    private func seedSnapshots() {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }
        netWorthSnapshots = [
            NetWorthSnapshot(date: daysAgo(90), netWorth: 6200,  totalAssets: 8400,  totalLiabilities: 2200),
            NetWorthSnapshot(date: daysAgo(75), netWorth: 6850,  totalAssets: 8900,  totalLiabilities: 2050),
            NetWorthSnapshot(date: daysAgo(60), netWorth: 7100,  totalAssets: 9200,  totalLiabilities: 2100),
            NetWorthSnapshot(date: daysAgo(45), netWorth: 7600,  totalAssets: 9800,  totalLiabilities: 2200),
            NetWorthSnapshot(date: daysAgo(30), netWorth: 8100,  totalAssets: 10300, totalLiabilities: 2200),
            NetWorthSnapshot(date: daysAgo(15), netWorth: 8679,  totalAssets: 11000, totalLiabilities: 2321),
        ]
    }

    private func seedCategories() {
        // Use palette colours so seed data is consistent with the auto-assign palette
        categories = [
            Category(name: "Food & Drink",  icon: "fork.knife",   colorHex: "#FF9F0A"),
            Category(name: "Groceries",     icon: "cart.fill",    colorHex: "#4B8BFF"),
            Category(name: "Transport",     icon: "car.fill",     colorHex: "#30D158"),
            Category(name: "Shopping",      icon: "bag.fill",     colorHex: "#FF453A"),
            Category(name: "Health",        icon: "cross.fill",   colorHex: "#5AC8FA"),
            Category(name: "Entertainment", icon: "film.fill",    colorHex: "#BF5AF2"),
        ]
    }


    private func seedTransactions() {
        guard !categories.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }
        let food = categories[0].id; let transport = categories[1].id
        let shopping = categories[2].id; let health = categories[3].id; let ent = categories[4].id
        transactions = [
            Transaction(date: daysAgo(1),  title: "Grocery run",   categoryId: food,      amountPaid: 85.50,  amountBack: 0),
            Transaction(date: daysAgo(2),  title: "Uber to work",  categoryId: transport, amountPaid: 22.00,  amountBack: 0),
            Transaction(date: daysAgo(3),  title: "Pharmacy",      categoryId: health,    amountPaid: 45.00,  amountBack: 30.00),
            Transaction(date: daysAgo(4),  title: "Netflix",       categoryId: ent,       amountPaid: 15.49,  amountBack: 0),
            Transaction(date: daysAgo(5),  title: "New jacket",    categoryId: shopping,  amountPaid: 120.00, amountBack: 0),
            Transaction(date: daysAgo(20), title: "Dinner out",    categoryId: food,      amountPaid: 68.00,  amountBack: 0),
            Transaction(date: daysAgo(22), title: "Gas",           categoryId: transport, amountPaid: 55.00,  amountBack: 0),
            Transaction(date: daysAgo(24), title: "Movie tickets", categoryId: ent,       amountPaid: 32.00,  amountBack: 0),
        ]
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
}

extension DataStore {
    func exportCSV() -> Data? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var rows = ["Date,Title,Category,Type,Amount Paid,Amount Back,Net Amount"]
        for tx in transactions.sorted(by: { $0.date > $1.date }) {
            let cat  = category(for: tx.categoryId)?.name ?? "Unknown"
            let date = fmt.string(from: tx.date)
            let net  = tx.isIncome ? tx.amountPaid : max(0, tx.amountPaid - tx.amountBack)
            let type = tx.isIncome ? "Income" : "Spend"
            // Escape commas in text fields
            let title = tx.title.contains(",") ? "\"\(tx.title)\"" : tx.title
            let catE  = cat.contains(",")      ? "\"\(cat)\""      : cat
            rows.append("\(date),\(title),\(catE),\(type),\(tx.amountPaid),\(tx.amountBack),\(net)")
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
            netWorthSnapshots: netWorthSnapshots
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    func importBackup(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)
        categories        = backup.categories
        transactions      = backup.transactions
        netWorthAccounts  = backup.netWorthAccounts
        splitEntries      = backup.splitEntries
        netWorthSnapshots = backup.netWorthSnapshots
        save()
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
