// Views/PackageListView.swift
import SwiftUI

struct PackageListView: View {
    @EnvironmentObject var userState: UserState
    @State private var packages: [ServicePackage] = []
    @State private var trainingMaterials: [TrainingMaterial] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var selectedCategory: PackageCategory? = nil
    @State private var selectedTab = 0
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
            VStack(spacing: 0) {
                Picker("类型", selection: $selectedTab) {
                    Text("服务套餐").tag(0)
                    Text("培训材料").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    packagesView
                } else {
                    trainingView
                }
            }
            .navigationTitle(selectedTab == 0 ? "服务套餐" : "培训材料")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
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
    
    private var trainingView: some View {
        Group {
            if isLoading && trainingMaterials.isEmpty {
                List {
                    ForEach(0..<5) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 72)
                            .shimmering()
                    }
                }
                .listStyle(.plain)
            } else if trainingMaterials.isEmpty {
                EmptyStateView(
                    icon: "book.fill",
                    title: "暂无培训材料",
                    subtitle: "点击右上角添加PPT"
                )
                .padding(.top, 60)
            } else {
                List {
                    ForEach(trainingMaterials) { material in
                        TrainingMaterialRow(material: material)
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
                _ = try await supabase
                    .from("packages")
                    .delete()
                    .eq("id", value: package.id)
                    .execute()
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
                let request = DeletionRequestInsert(
                    requesterId: userState.currentUser?.id ?? UUID(),
                    targetType: "package",
                    targetId: package.id,
                    targetName: package.name,
                    reason: deleteReason.isEmpty ? nil : deleteReason
                )
                _ = try await supabase
                    .from("deletion_requests")
                    .insert(request)
                    .execute()
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
            async let packagesTask: [ServicePackage] = supabase
                .from("packages")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            async let trainingTask: [TrainingMaterial] = supabase
                .from("training_materials")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let (p, t) = try await (packagesTask, trainingTask)
            packages = p
            trainingMaterials = t
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

struct TrainingMaterialRow: View {
    let material: TrainingMaterial
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: material.fileType.icon)
                .font(.system(size: 24))
                .foregroundColor(.orange)
                .frame(width: 48, height: 48)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(material.title)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text("v\(material.version)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    Text(material.fileType.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let desc = material.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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

#Preview {
    PackageListView()
}
