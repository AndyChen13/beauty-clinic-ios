// Views/PackageListView.swift
import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var userState: UserState
    @State private var packages: [ServicePackage] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var packageToEdit: ServicePackage?
    @State private var selectedCategory: PackageCategory? = nil
    @State private var showingDeleteRequest = false
    @State private var packageToDelete: ServicePackage?
    @State private var deleteReason = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var filteredPackages: [ServicePackage] {
        guard let category = selectedCategory else { return packages.filter { $0.isActive } }
        return packages.filter { $0.category == category && $0.isActive }
    }
    
    var body: some View {
        NavigationStack {
            packagesView
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
            .sheet(item: $packageToEdit) { package in
                PackageEditView(mode: .edit(package)) { updated in
                    if let index = packages.firstIndex(where: { $0.id == updated.id }) {
                        packages[index] = updated
                    }
                }
            }
            .sheet(isPresented: $showingDeleteRequest) {
                DeleteRequestSheet(
                    itemName: packageToDelete?.name ?? "",
                    reason: $deleteReason,
                    onSubmit: submitDeleteRequest
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }
    
    private var packagesView: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "全部",
                        isSelected: selectedCategory == nil
                    ) { selectedCategory = nil }
                    
                    ForEach(PackageCategory.allCases.filter { $0 != .training }, id: \.self) { category in
                        FilterChip(
                            title: category.displayName,
                            isSelected: selectedCategory == category,
                            color: category.color
                        ) { selectedCategory = category }
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
                            .frame(height: 100)
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if userState.isAdmin {
                                    packageToEdit = package
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if userState.isAdmin {
                                    Button(role: .destructive) {
                                        deletePackage(package)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        packageToDelete = package
                                        showingDeleteRequest = true
                                    } label: {
                                        Label("申请删除", systemImage: "trash")
                                    }
                                    .tint(.orange)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func deletePackage(_ package: ServicePackage) {
        guard userState.isAdmin else { return }
        Task {
            do {
                try await PackageService.shared.deletePackage(id: package.id)
                await MainActor.run {
                    packages.removeAll { $0.id == package.id }
                }
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func submitDeleteRequest() {
        guard let package = packageToDelete else { return }
        Task {
            do {
                var payload: [String: JSONValue] = [:]
                payload["packageName"] = .string(package.name)
                if !deleteReason.isEmpty {
                    payload["reason"] = .string(deleteReason)
                }
                _ = try await AdminService.shared.createOperationApproval(
                    operationType: "delete",
                    targetType: "package",
                    targetId: package.id,
                    payload: payload
                )
                await MainActor.run {
                    deleteReason = ""
                    packageToDelete = nil
                }
            } catch {
                errorMessage = "提交失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (p, _) = try await PackageService.shared.listPackages()
            packages = p
        } catch {
            print("Error loading packages: \(error)")
        }
    }
}

struct PackageRow: View {
    let package: ServicePackage
    
    var body: some View {
        HStack(spacing: 14) {
            if let imageUrl = package.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    packagePlaceholder
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                packagePlaceholder
                    .frame(width: 60, height: 60)
            }
            
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
                    Text("\(package.durationMinutes)分钟 · \(package.totalSessions)次")
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
    
    private var packagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.accentColor.opacity(0.1))
            .overlay(
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor.opacity(0.5))
            )
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

#Preview {
    PackageListView()
}
