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
- **Split a spend** with one or more people — see your true share while the card keeps the full charge

### More
- Category management (custom icon, color)
- Export backup as JSON or CSV
- Import backup from JSON
- Appearance (dark / light / system) and auto-lock delay settings

## Account Balance Auto-Adjustment

A **Spend** is always the full amount you paid, and money coming back (a friend repaying you, cashback, a refund) is logged as a separate **Income** transaction when it actually arrives. This keeps every account balance matching your real statements.

- **Spend from checking/savings/investment** → account balance decreases by the full amount
- **Spend on credit card/loan** → liability balance increases by the full amount (you owe more)
- **Income to checking/savings/investment** → account balance increases
- **Income to credit card/loan** → liability balance decreases (debt reduced)
- **Credit card payment (Transfer)** → bank balance decreases AND card balance decreases (debt paid off); never appears in transaction lists

Editing or deleting a transaction automatically reverses the old delta and applies the new one.

## Splitting a Shared Expense

When a spend is partly owed back by others (e.g. shared rent), turn on **Split this expense** on the transaction and assign each person a share:

- **Card / account** → charged the **full amount** (matches your real statement)
- **Your expense** (graphs, breakdown, totals) → shows **only your share**
- **Splitwise** → one **"Owes me"** entry per person is auto-created and linked to the transaction

When someone pays you back, tap **Mark as paid** on their Splitwise entry, enter the amount (full or partial), and pick the **checking account** the money landed in. The receivable shrinks (or clears), the account is credited, and net worth stays correct — repayments are never counted as income. Deleting the spend removes its linked receivables.

### When someone else paid (you owe your share)

On a spend, turn on **Someone else paid** and pick the person you owe. The amount you enter is **your share**:

- **Your expense** (graphs, breakdown, totals) → counts your share, as normal
- **No account is charged** (you didn't pay) — instead an **"I owe"** entry is created
- **Net worth** drops by your share (a liability) until you pay them back

To pay them back, tap **Pay back** on their entry, enter the amount, and pick the account the money leaves from. The "I owe" entry shrinks/clears and the account is debited.

### One balance per person

The Splitwise list shows a **single net row per person** — if someone both owes you and you owe them, it nets to one number (and disappears when fully settled). Tap a person to see the individual entries behind their balance.

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
