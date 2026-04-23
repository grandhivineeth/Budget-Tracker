import SwiftUI

struct CategoryListView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var showAdd = false
    @State private var selected: Category?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                ScrollView {
                    if store.categories.isEmpty {
                        EmptyStateView(message: "No categories yet").padding(.top, 40)
                    } else {
                        GroupedListCard {
                            ForEach(Array(store.categories.enumerated()), id: \.element.id) { idx, cat in
                                CatRow(category: cat, isLast: idx == store.categories.count - 1)
                                    .onTapGesture { selected = cat }
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 16)
                    }
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(DS.blue) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus").foregroundStyle(DS.blue) }
                }
            }
            .sheet(isPresented: $showAdd) { CategoryFormView() }
            .sheet(item: $selected) { cat in CategoryFormView(category: cat) }
        }.preferredColorScheme(.dark)
    }
}

struct CatRow: View {
    let category: Category; var isLast: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(category.color.opacity(0.15)))
            Text(category.name).font(.system(size: 15, weight: .medium)).foregroundStyle(DS.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.textHint)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(DS.cardBorder).frame(height: 1).padding(.leading, 62) }
        }
    }
}

struct CategoryFormView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    var category: Category?
    @State private var name = ""
    @State private var selectedIcon = "cart.fill"
    @State private var selectedColor = "#4B8BFF"
    let icons = [
        "fork.knife", "cart.fill", "car.fill", "house.fill", "cross.fill",
        "film.fill", "bag.fill", "airplane", "figure.run", "book.fill",
        "cup.and.saucer.fill", "gamecontroller.fill", "laptopcomputer", "music.note",
        "drop.fill", "dollarsign.circle.fill", "gift.fill", "pawprint.fill",
        "leaf.fill", "bolt.fill", "banknote.fill", "creditcard.fill",
        "building.columns.fill", "doc.text.fill", "shippingbox.fill",
        "tram.fill", "bicycle", "stethoscope", "pills.fill", "dumbbell.fill",
        "graduationcap.fill", "wifi", "phone.fill", "wrench.fill", "tv.fill"
    ]
    var isEditing: Bool { category != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()
                Form {
                    Section { TextField("Category name", text: $name) }.listRowBackground(DS.card)
                    Section("Icon") {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                let active = selectedIcon == icon
                                let tint = active ? Color(hex: selectedColor) : DS.textSub
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(tint)
                                    .frame(width: 48, height: 48)
                                    .background(active ? Color(hex: selectedColor).opacity(0.2) : DS.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color(hex: selectedColor) : Color.clear, lineWidth: 2))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { selectedIcon = icon }
                            }
                        }.padding(.vertical, 4)
                    }.listRowBackground(DS.card)
                    
                    if isEditing {
                        Section {
                            Button(role: .destructive) { deleteAndDismiss() } label: {
                                Label("Delete Category", systemImage: "trash").frame(maxWidth: .infinity, alignment: .center)
                            }
                        }.listRowBackground(DS.card)
                    }
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(DS.blue) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).fontWeight(.semibold).foregroundStyle(DS.blue)
                }
            }.onAppear { prefill() }
        }.preferredColorScheme(.dark)
    }
    private func prefill() {
        guard let cat = category else {
            // New category — auto-assign next available palette color
            selectedColor = store.nextCategoryColor()
            return
        }
        name = cat.name; selectedIcon = cat.icon; selectedColor = cat.colorHex
    }
    private func saveAndDismiss() {
        let t = name.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        if let ex = category { var u = ex; u.name = t; u.icon = selectedIcon; u.colorHex = selectedColor; store.updateCategory(u) }
        else { store.addCategory(Category(name: t, icon: selectedIcon, colorHex: selectedColor)) }
        dismiss()
    }
    private func deleteAndDismiss() {
        guard let cat = category else { return }
        if store.transactions.contains(where: { $0.categoryId == cat.id }) { return }
        store.deleteCategory(cat); dismiss()
    }
}
