import SwiftUI
import UniformTypeIdentifiers

enum MoreTab: String, CaseIterable {
    case settings = "Settings"
}

struct MoreView: View {
    @EnvironmentObject var store: DataStore
    @AppStorage("appearanceMode")          private var appearanceMode:          String = "dark"
    @AppStorage("profileName")             private var profileName:             String = ""
    @AppStorage("profileEmail")            private var profileEmail:            String = ""
    @AppStorage("autoLockDelay")           private var autoLockDelay:           String = "immediately"
    @AppStorage("weeklyNotificationEnabled") private var weeklyNotifEnabled:    Bool   = false
    @AppStorage("defaultCurrency")         private var defaultCurrency:         String = "USD"

    @State private var tab: MoreTab = .settings
    @State private var editingProfile    = false
    @State private var showFilePicker    = false
    @State private var showImportAlert   = false
    @State private var importError: String?
    @State private var showImportSuccess = false


    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    AppPageHeader(pageTitle: "More", selected: $tab)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            // ── Profile ───────────────────────────────────
                            moreSectionCard(header: "PROFILE") {
                                Button { editingProfile = true } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: [DS.blue, DS.purple],
                                                                     startPoint: .topLeading,
                                                                     endPoint: .bottomTrailing))
                                                .frame(width: 50, height: 50)
                                            Text(initials)
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(profileName.isEmpty ? "Set your name" : profileName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(profileName.isEmpty ? DS.textSub : DS.text)
                                            Text(profileEmail.isEmpty ? "Add email" : profileEmail)
                                                .font(.system(size: 13))
                                                .foregroundStyle(DS.textSub)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(DS.textHint)
                                    }
                                    .padding(.horizontal, 18).padding(.vertical, 16)
                                }
                                .buttonStyle(.plain)
                            }

                            // ── Security ──────────────────────────────────
                            moreSectionCard(header: "SECURITY") {
                                VStack(alignment: .leading, spacing: 0) {
                                    settingsLabel("Auto-Lock")
                                    // Equal-width segmented control
                                    HStack(spacing: 2) {
                                        ForEach([("Immediately", "immediately"),
                                                 ("1 min",       "1min"),
                                                 ("5 min",       "5min")], id: \.1) { label, val in
                                            Button { autoLockDelay = val } label: {
                                                Text(label)
                                                    .font(.system(size: 13,
                                                                  weight: autoLockDelay == val ? .semibold : .regular))
                                                    .foregroundStyle(autoLockDelay == val ? DS.text : DS.textSub)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 9)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(autoLockDelay == val
                                                                  ? DS.card
                                                                  : Color.clear)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(3)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(DS.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(DS.cardBorder, lineWidth: 1))
                                    .padding(.horizontal, 18)
                                    .padding(.bottom, 16)
                                }
                            }

                            // ── Appearance ────────────────────────────────
                            moreSectionCard(header: "APPEARANCE") {
                                appearanceRow(label: "Light",  mode: "light",  icon: "sun.max.fill",           color: .orange,    isLast: false)
                                Divider().background(DS.cardBorder).padding(.leading, 70)
                                appearanceRow(label: "Dark",   mode: "dark",   icon: "moon.fill",              color: DS.blue,    isLast: false)
                                Divider().background(DS.cardBorder).padding(.leading, 70)
                                appearanceRow(label: "System", mode: "system", icon: "circle.lefthalf.filled", color: DS.textSub, isLast: true)
                            }

                            // ── Preferences ───────────────────────────────
                            moreSectionCard(header: "PREFERENCES") {
                                // Currency
                                VStack(spacing: 0) {
                                    settingsLabel("Default Currency")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(currencies, id: \.code) { c in
                                                currencyPill(c)
                                            }
                                        }
                                        .padding(.horizontal, 18).padding(.bottom, 16)
                                    }
                                }
                            }

                            // ── Notifications ─────────────────────────────
                            moreSectionCard(header: "NOTIFICATIONS") {
                                HStack(spacing: 14) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DS.purple)
                                        .frame(width: 42, height: 42)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(DS.purple.opacity(0.15)))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Weekly Summary")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(DS.text)
                                        Text("Every Sunday at 9 AM")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.textSub)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $weeklyNotifEnabled)
                                        .labelsHidden()
                                        .tint(DS.blue)
                                        .onChange(of: weeklyNotifEnabled) { _, enabled in
                                            if enabled {
                                                NotificationManager.shared.scheduleWeeklySummary()
                                            } else {
                                                NotificationManager.shared.cancelWeeklySummary()
                                            }
                                        }
                                }
                                .padding(.horizontal, 18).padding(.vertical, 14)
                            }

                            // ── Data ──────────────────────────────────────
                            moreSectionCard(header: "DATA") {
                                dataActionRow(icon: "square.and.arrow.up.fill",   color: DS.blue,
                                              label: "Export Backup (JSON)",
                                              sublabel: "\(store.transactions.count) transactions · \(store.categories.count) categories",
                                              isLast: false) { exportJSON() }

                                Divider().background(DS.cardBorder).padding(.leading, 70)

                                dataActionRow(icon: "tablecells.fill",            color: DS.green,
                                              label: "Export as CSV",
                                              sublabel: "Open in Excel or Numbers",
                                              isLast: false) { exportCSV() }

                                Divider().background(DS.cardBorder).padding(.leading, 70)

                                dataActionRow(icon: "square.and.arrow.down.fill", color: DS.purple,
                                              label: "Import Backup",
                                              sublabel: "Restore from a .json backup file",
                                              isLast: true) { showFilePicker = true }
                            }

                            // ── iCloud Backup ─────────────────────────────
                            // ── About ─────────────────────────────────────
                            moreSectionCard(header: "ABOUT") {
                                HStack {
                                    Text("Version")
                                        .font(.system(size: 15))
                                        .foregroundStyle(DS.text)
                                    Spacer()
                                    Text(appVersion)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(DS.textSub)
                                }
                                .padding(.horizontal, 18).padding(.vertical, 16)
                            }

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16).padding(.top, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $editingProfile) {
                ProfileEditSheet(name: $profileName, email: $profileEmail)
            }
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { handleImport(result: $0) }
            .alert("Import failed", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "The file could not be read.") }
            .alert("Backup restored ✓", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: { Text("Your categories and transactions have been restored.") }
        }
    }

    // MARK: - Actions
    private func exportJSON() {
        guard let data = store.exportBackup() else { return }
        let name = "BudgetTracker-\(datestamp()).json"
        presentShareSheet(data: data, name: name)
    }

    private func exportCSV() {
        guard let data = store.exportCSV() else { return }
        let name = "BudgetTracker-\(datestamp()).csv"
        presentShareSheet(data: data, name: name)
    }

    private func presentShareSheet(data: Data, name: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        // Walk up to the topmost presented controller
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(av, animated: true)
    }

    private func datestamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            importError = err.localizedDescription; showImportAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try store.importBackup(from: data)
                showImportSuccess = true
            } catch {
                importError = error.localizedDescription; showImportAlert = true
            }
        }
    }

    // MARK: - Helpers
    private var initials: String {
        let parts = profileName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"]            as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - Currency data
    struct CurrencyOption { let code: String; let symbol: String; let name: String }
    private let currencies: [CurrencyOption] = [
        .init(code: "USD", symbol: "$",  name: "US Dollar"),
        .init(code: "EUR", symbol: "€",  name: "Euro"),
        .init(code: "GBP", symbol: "£",  name: "British Pound"),
        .init(code: "INR", symbol: "₹",  name: "Indian Rupee"),
        .init(code: "CAD", symbol: "CA$", name: "Canadian Dollar"),
        .init(code: "AUD", symbol: "A$", name: "Australian Dollar"),
        .init(code: "JPY", symbol: "¥",  name: "Japanese Yen"),
        .init(code: "SGD", symbol: "S$", name: "Singapore Dollar"),
    ]

    // MARK: - Sub-views
    @ViewBuilder
    private func settingsLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DS.textSub)
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)
    }

    @ViewBuilder
    private func currencyPill(_ c: CurrencyOption) -> some View {
        let active = defaultCurrency == c.code
        Button {
            defaultCurrency = c.code
            UserDefaults.standard.set(c.code, forKey: "defaultCurrency")
        } label: {
            VStack(spacing: 3) {
                Text(c.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? DS.blue : DS.text)
                Text(c.code)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(active ? DS.blue : DS.textSub)
            }
            .frame(width: 60, height: 52)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(active ? DS.blue.opacity(0.12) : DS.surface))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(active ? DS.blue.opacity(0.4) : DS.cardBorder))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dataActionRow(icon: String, color: Color,
                                label: String, sublabel: String,
                                isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(DS.text)
                    Text(sublabel).font(.system(size: 12)).foregroundStyle(DS.textSub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(DS.textHint)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func moreSectionCard<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textSub)
                .tracking(0.8)
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)
            content()
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(DS.card))
    }

    @ViewBuilder
    private func appearanceRow(label: String, mode: String, icon: String, color: Color, isLast: Bool) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { appearanceMode = mode } } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
                Text(label)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(DS.text)
                Spacer()
                if appearanceMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(DS.blue)
                } else {
                    Circle().stroke(DS.cardBorder, lineWidth: 1.5).frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Edit Sheet
struct ProfileEditSheet: View {
    @Binding var name: String
    @Binding var email: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Form {
                    Section {
                        TextField("Full name", text: $name)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .listRowBackground(DS.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DS.blue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }.fontWeight(.semibold).foregroundStyle(DS.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

