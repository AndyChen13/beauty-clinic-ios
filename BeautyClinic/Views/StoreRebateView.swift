// Views/StoreRebateView.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct StoreRebateView: View {
    @EnvironmentObject var userState: UserState
    @Environment(\.dismiss) private var dismiss
    
    let store: Store
    
    @State private var activePeriod: StoreRebatePeriod?
    @State private var history: [StoreRebatePeriod] = []
    @State private var isLoading = false
    
    // 创建新周期
    @State private var startAt = Date()
    @State private var hasEndDate = false
    @State private var endAt = Date()
    @State private var threshold1 = ""
    @State private var rebate1 = ""
    @State private var threshold2 = ""
    @State private var rebate2 = ""
    @State private var threshold3 = ""
    @State private var rebate3 = ""
    @State private var createError: String?
    
    // 手动截止
    @State private var showCloseSheet = false
    @State private var manualRebate = ""
    
    // 编辑历史返利
    @State private var editingPeriod: StoreRebatePeriod?
    @State private var editConfirmedRebate = ""
    @State private var showDeleteConfirm = false
    
    private var isAdmin: Bool { userState.isAdmin }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                storeHeader
                activeSection
                historySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("\(store.name) 返利")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await loadData() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color(hex: "C9A24B"))
                }
            }
        }
        .task { await loadData() }
        .sheet(item: $editingPeriod) { period in
            editSheet(for: period)
        }
        .sheet(isPresented: $showCloseSheet) {
            closeSheet
        }
    }
    
    // MARK: - Header
    private var storeHeader: some View {
        VStack(spacing: 8) {
            Text(store.name)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            HStack(spacing: 6) {
                Circle()
                    .fill(store.status.color)
                    .frame(width: 8, height: 8)
                Text(store.status.displayName)
                    .font(.subheadline)
                    .foregroundColor(store.status.color)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Active Period
    @ViewBuilder
    private var activeSection: some View {
        if isLoading && activePeriod == nil {
            loadingCard
        } else if let active = activePeriod {
            activeCard(active)
        } else {
            createCard
        }
    }
    
    private func activeCard(_ active: StoreRebatePeriod) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("进行中返利周期")
                    .font(.headline)
                    .foregroundColor(Color(hex: "C9A24B"))
                Spacer()
                Text("进行中")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
            }
            
            InfoRow(label: "开始时间", value: active.startAt.formatted(date: .abbreviated, time: .shortened))
            if let endAt = active.endAt {
                InfoRow(label: "预计结束", value: endAt.formatted(date: .abbreviated, time: .shortened))
            }
            
            Divider().background(Color(UIColor.separator))
            
            thresholdRow(label: "第一档", threshold: active.threshold1, rebate: active.rebate1)
            thresholdRow(label: "第二档", threshold: active.threshold2, rebate: active.rebate2)
            thresholdRow(label: "第三档", threshold: active.threshold3, rebate: active.rebate3)
            
            Divider().background(Color(UIColor.separator))
            
            summaryRow(label: "当前累计实收", value: active.currentAmount ?? 0)
            summaryRow(label: "自动汇算返利", value: active.autoRebate ?? 0, valueColor: .orange)
            
            if isAdmin {
                Button {
                    manualRebate = ""
                    showCloseSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Text("手动截止本次返利周期")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color(hex: "C9A24B"))
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func thresholdRow(label: String, threshold: Double, rebate: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("实收 ≥ ¥\(Int(threshold))")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("返利 ¥\(Int(rebate))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(hex: "C9A24B"))
        }
    }
    
    private func summaryRow(label: String, value: Double, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("¥\(Int(value))")
                .font(.title3.weight(.bold))
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Create Card
    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("创建返利周期")
                .font(.headline)
                .foregroundColor(Color(hex: "C9A24B"))
            
            DatePicker("开始日期", selection: $startAt, displayedComponents: .date)
            Toggle("设置结束日期", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("结束日期", selection: $endAt, displayedComponents: .date)
            }
            
            Divider().background(Color(UIColor.separator))
            
            Text("返利档位")
                .font(.subheadline.weight(.medium))
            
            HStack(spacing: 12) {
                TextField("门限1", text: $threshold1)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("返利1", text: $rebate1)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                TextField("门限2", text: $threshold2)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("返利2", text: $rebate2)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                TextField("门限3", text: $threshold3)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("返利3", text: $rebate3)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let error = createError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if isAdmin {
                Button {
                    createRebate()
                } label: {
                    HStack {
                        Spacer()
                        Text("保存并开启返利周期")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color(hex: "C9A24B"))
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("历史返利")
                .font(.headline)
                .foregroundColor(.primary)
            
            if history.isEmpty {
                EmptyStateView(icon: "arrowshape.turn.up.left", title: "暂无历史返利", subtitle: "结束返利周期后将在此展示")
            } else {
                ForEach(history.sorted(by: { ($0.confirmedAt ?? .distantPast) > ($1.confirmedAt ?? .distantPast) })) { period in
                    Button {
                        if isAdmin {
                            editingPeriod = period
                            editConfirmedRebate = period.confirmedRebate.map { String(format: "%.0f", $0) } ?? ""
                        }
                    } label: {
                        historyRow(period)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAdmin)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func historyRow(_ period: StoreRebatePeriod) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let confirmedAt = period.confirmedAt {
                    Text(confirmedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                Text("确认人: \(period.confirmedByName ?? "-")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(Int(period.confirmedRebate ?? 0))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "C9A24B"))
                if isAdmin {
                    Text("点击修改")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.tertiarySystemBackground))
            .frame(height: 160)
            .shimmering()
    }
    
    // MARK: - Sheets
    private var closeSheet: some View {
        NavigationStack {
            Form {
                Section("本期返利") {
                    if let active = activePeriod {
                        InfoRow(label: "自动汇算返利", value: "¥\(Int(active.autoRebate ?? 0))")
                    }
                }
                
                Section("手动修改") {
                    TextField("手动修改返利额（留空用自动额）", text: $manualRebate)
                        .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    Button {
                        closeRebate()
                    } label: {
                        HStack {
                            Spacer()
                            Text("确认截止")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("截止返利周期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCloseSheet = false }
                }
            }
        }
    }
    
    private func editSheet(for period: StoreRebatePeriod) -> some View {
        NavigationStack {
            Form {
                Section("确认返利额") {
                    TextField("已确认返利", text: $editConfirmedRebate)
                        .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
                
                Section {
                    Button {
                        updateHistoricalRebate(period: period)
                    } label: {
                        HStack {
                            Spacer()
                            Text("保存")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除此返利记录")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("修改确认返利")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { editingPeriod = nil }
                }
            }
            .confirmationDialog(
                "确认删除该返利记录？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    deleteHistoricalRebate(period: period)
                }
            } message: {
                Text("删除后不可恢复")
            }
        }
    }
    
    // MARK: - Actions
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let active = try await StoreRebateService.shared.getActiveRebate(storeId: store.id.uuidString)
            let history = try await StoreRebateService.shared.getRebateHistory(storeId: store.id.uuidString)
            await MainActor.run {
                self.activePeriod = active
                self.history = history
            }
        } catch {
            print("[StoreRebate] load error: \(error)")
        }
    }
    
    private func createRebate() {
        guard let t1 = Double(threshold1), let r1 = Double(rebate1),
              let t2 = Double(threshold2), let r2 = Double(rebate2),
              let t3 = Double(threshold3), let r3 = Double(rebate3) else {
            createError = "请输入完整的门限与返利金额"
            return
        }
        guard t1 < t2 && t2 < t3 else {
            createError = "门限必须满足：门限1 < 门限2 < 门限3"
            return
        }
        guard r1 >= 0 && r2 >= 0 && r3 >= 0 else {
            createError = "返利金额不能为负数"
            return
        }
        
        createError = nil
        Task {
            do {
                let insert = StoreRebatePeriodInsert(
                    startAt: startAt,
                    endAt: hasEndDate ? endAt : nil,
                    threshold1: t1, rebate1: r1,
                    threshold2: t2, rebate2: r2,
                    threshold3: t3, rebate3: r3
                )
                let created = try await StoreRebateService.shared.createRebate(storeId: store.id.uuidString, insert: insert)
                await MainActor.run {
                    activePeriod = created
                    resetCreateForm()
                }
            } catch {
                createError = error.localizedDescription
            }
        }
    }
    
    private func closeRebate() {
        let manual = Double(manualRebate)
        Task {
            do {
                let closed = try await StoreRebateService.shared.closeRebate(storeId: store.id.uuidString, manualRebate: manual)
                await MainActor.run {
                    activePeriod = nil
                    history.insert(closed, at: 0)
                    showCloseSheet = false
                }
            } catch {
                print("[StoreRebate] close error: \(error)")
            }
        }
    }
    
    private func updateHistoricalRebate(period: StoreRebatePeriod) {
        guard let value = Double(editConfirmedRebate), value >= 0 else {
            editingPeriod = nil
            return
        }
        Task {
            do {
                let updated = try await StoreRebateService.shared.updateHistoricalRebate(
                    storeId: store.id.uuidString,
                    rebateId: period.id,
                    confirmedRebate: value
                )
                await MainActor.run {
                    if let index = history.firstIndex(where: { $0.id == updated.id }) {
                        history[index] = updated
                    }
                    editingPeriod = nil
                }
            } catch {
                print("[StoreRebate] update error: \(error)")
            }
        }
    }
    
    private func deleteHistoricalRebate(period: StoreRebatePeriod) {
        Task {
            do {
                try await StoreRebateService.shared.deleteHistoricalRebate(
                    storeId: store.id.uuidString,
                    rebateId: period.id
                )
                await MainActor.run {
                    history.removeAll { $0.id == period.id }
                    editingPeriod = nil
                }
            } catch {
                print("[StoreRebate] delete error: \(error)")
            }
        }
    }
    
    private func resetCreateForm() {
        threshold1 = ""
        rebate1 = ""
        threshold2 = ""
        rebate2 = ""
        threshold3 = ""
        rebate3 = ""
        hasEndDate = false
        createError = nil
    }
}

#Preview {
    NavigationStack {
        StoreRebateView(
            store: Store(
                id: UUID(),
                name: "测试门店",
                address: nil,
                phone: nil,
                status: .active,
                managerId: nil,
                imageUrl: nil,
                notes: nil,
                introduction: nil,
                recommendedHotel: nil,
                createdAt: nil,
                updatedAt: nil
            )
        )
        .environmentObject(UserState())
    }
}
