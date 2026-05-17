# Budget Tracker

A personal iOS finance app built with SwiftUI for tracking spending, net worth, and split expenses.

## Features

- **Home** — Spending overview with 7-day summary and net worth card
- **Spend** — Monthly spend charts (line graph + calendar heat map), budget breakdown by category, transaction history
- **More** — Account & category management, splitwise balances, data export/import

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
- Backups are a single `AppBackup.json` file containing all transactions, accounts, categories, and split entries

## Screenshots

_Coming soon_

---

*Personal use only — not distributed on the App Store.*
