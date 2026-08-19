//  Views/PackageListView.swift
//  BeautyClinic
//

import SwiftUI

struct PackageListView: View {
    @State private var packages: [ServicePackage] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var selectedCategory: PackageCategory? = nil
    
    var filteredPackages: [ServicePackage] {
        guard let category = selectedCategory else { return packages }
        return packages.filter { $0.category == category }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "全部",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(PackageCategory.allCases, id: \.self) { category in
                            FilterChip(
                                title: category.displayName,
                                isSelected: selectedCategory == category,
                                color: category.color
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                if isLoading && packages.isEmpty {
                    List {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 80)
                                .shimmering()
                        }
                    }
                    .listStyle(.plain)
                } else if filteredPackages.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: selectedCategory == nil ? "暂无套餐" : "该分类暂无套餐",
                        subtitle: "点击右上角添加套餐"
                    )
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(filteredPackages) { package in
                            PackageRow(package: package)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("服务套餐")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                PackageEditView(mode: .create) { newPackage in
                    packages.append(newPackage)
                }
            }
            .task { await loadPackages() }
            .refreshable { await loadPackages() }
        }
    }
    
    private func loadPackages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result: [ServicePackage] = try await supabase
                .from("packages")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            packages = result
        } catch {
            print("Error loading packages: \(error)")
        }
    }
}

struct PackageRow: View {
    let package: ServicePackage
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(package.category.color.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(package.category.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(package.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(package.category.color.opacity(0.12))
                        .foregroundColor(package.category.color)
                        .clipShape(Capsule())
                    Text("\(package.durationMinutes)分钟")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let desc = package.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("¥\(String(format: "%.0f", package.price))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 6)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isSelected ? color : .primary)
                .clipShape(Capsule())
        }
    }
}

enum PackageEditMode {
    case create
    case edit(ServicePackage)
}

struct PackageEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: PackageEditMode
    let onSave: (ServicePackage) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var category = PackageCategory.face
    @State private var price = ""
    @State private var duration = "60"
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("套餐名称 *", text: $name)
                    TextField("描述", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    Picker("分类", selection: $category) {
                        ForEach(PackageCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
                
                Section("定价") {
                    TextField("价格 (¥) *", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("时长 (分钟) *", text: $duration)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("添加套餐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: savePackage) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(name.isEmpty || price.isEmpty || isSaving)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePackage() {
        guard let priceValue = Double(price),
              let durationValue = Int(duration),
              !name.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                let packageData = ServicePackageInsert(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    category: category,
                    price: priceValue,
                    durationMinutes: durationValue,
                    imageUrl: nil,
                    trainingMaterials: nil
                )
                
                let created: ServicePackage = try await supabase
                    .from("packages")
                    .insert(packageData)
                    .select()
                    .single()
                    .execute()
                    .value
                
                onSave(created)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    PackageListView()
}
