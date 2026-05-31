# Budget Tracker

A personal iOS finance app built with SwiftUI for tracking spending, net worth, and split expenses.

## Features

### Home
- 7-day spending summary
- Net worth card (assets, liabilities, splitwise balance)
- Recent transaction feed

### Spend
- Monthly cumulative spend line chart (current vs. previous month)
- Calendar heat map
- Expense category breakdown with multi-select filter
- Full transaction history grouped by month

### Manager
- **Accounts** — Add and edit checking, savings, investment, credit card, and loan accounts
- **Net worth history** — Automatic daily snapshot chart
- **Splitwise** — Track who owes whom
- **Transfers** — Record credit card payments (bank → card); balances update automatically

### Transactions
- Link every transaction to an account — balance adjusts automatically on add, edit, or delete
- Spend transactions require an account; income transactions optionally link to one
- Category + account shown in each transaction row

### More
- Category management (custom icon, color)
- Export backup as JSON or CSV
- Import backup from JSON
- Appearance (dark / light / system) and auto-lock delay settings

## Account Balance Auto-Adjustment

When a transaction is saved:
- **Spend from checking/savings/investment** → account balance decreases by net amount (paid − returned)
- **Spend on credit card/loan** → liability balance increases (you owe more)
- **Income to checking/savings/investment** → account balance increases
- **Credit card payment (Transfer)** → bank balance decreases AND card balance decreases (debt paid off); never appears in transaction lists

Editing or deleting a transaction automatically reverses the old delta and applies the new one.

## Tech Stack

- SwiftUI + Swift Charts
- Local JSON persistence (no backend, no cloud dependency)
- Face ID / Touch ID lock screen
- iOS 18+ — built with Xcode 26

## Data & Privacy

All data is stored locally on-device in the app's Documents folder (`BudgetTrackerData/`). Nothing leaves the device unless you explicitly export via **More → Export Backup (JSON)**.

## Backup & Restore

- **Export**: More → Export Backup (JSON) → share sheet → save anywhere
- **Import**: More → Import Backup → pick a `.json` backup file
- Backups are a single `AppBackup.json` file containing all transactions, accounts, categories, split entries, transfers, and net worth snapshots

## Screenshots

_Coming soon_

---

*Personal use only — not distributed on the App Store.*
