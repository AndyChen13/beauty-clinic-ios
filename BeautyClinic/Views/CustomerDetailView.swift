// Views/CustomerDetailView.swift
import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    let stores: [Store]
    @State private var transactions: [Transaction] = []
    @State private var photos: [CustomerPhoto] = []
    @State private var serviceRecords: [ServiceRecord] = []
    @State private var isLoading = false
    @State private var isEditing = false
    @State private var showingServiceSheet = false
    @State private var selectedRecord: ServiceRecord?
    
    private var storeName: String {
        if let storeId = customer.associatedStoreId,
           let store = stores.first(where: { $0.id == storeId }) {
            return store.name
        }
        return "未分配门店"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileCard
                infoCard
                
                if let history = customer.medicalHistory, !history.isEmpty {
                    medicalHistoryCard(history: history)
                }
                
                if let prefs = customer.preferences, !prefs.isEmpty {
                    preferencesCard(prefs: prefs)
                }
                
                customerStatsCard
                photosSection
                serviceRecordsSection
                transactionsSection
            }
            .padding()
        }
        .navigationTitle(customer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingServiceSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    Button("编辑") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            CustomerEditView(mode: .edit(customer), stores: stores) { _ in }
        }
        .sheet(isPresented: $showingServiceSheet) {
            ServiceRecordEditView(
                customer: customer,
                transactions: transactions
            ) { _ in
                Task {
                    await loadServiceRecords()
                    await loadTransactions()
                }
            }
        }
        .task {
            await loadTransactions()
            await loadPhotos()
            await loadServiceRecords()
        }
    }
    
    private var profileCard: some View {
        VStack(spacing: 14) {
            if let photoUrl = customer.photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AvatarView(name: customer.name, size: 72)
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
            } else {
                AvatarView(name: customer.name, size: 72)
            }
            
            Text(customer.name)
                .font(.title2.weight(.bold))
            Text(customer.phone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("归属: \(storeName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                InfoBadge(label: "性别", value: customer.genderDisplay)
                if let age = customer.age {
                    InfoBadge(label: "年龄", value: "\(age)岁")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            InfoRow(label: "手机号", value: customer.phone)
            Divider()
            InfoRow(label: "性别", value: customer.genderDisplay)
            if let birthdate = customer.birthdate {
                Divider()
                InfoRow(label: "出生日期", value: birthdate)
            }
            if let lastVisit = customer.lastVisit {
                Divider()
                InfoRow(label: "最近到访", value: lastVisit.formatted())
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func medicalHistoryCard(history: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("医疗记录")
                .font(.headline)
            Text(history)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func preferencesCard(prefs: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("客户偏好")
                .font(.headline)
            ForEach(Array(prefs.keys.sorted()), id: \.self) { key in
                if let value = prefs[key] {
                    InfoRow(label: key, value: value)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("照片记录")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if photos.isEmpty && !isLoading {
                Text("暂无照片")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos) { photo in
                            if let url = URL(string: photo.photoUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("消费记录")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if transactions.isEmpty && !isLoading {
                Text("暂无消费记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(transactions) { transaction in
                    TransactionMiniRow(transaction: transaction)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var customerStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("客户状态")
                .font(.headline)
            
            HStack(spacing: 20) {
                if let outstanding = customer.outstandingAmount, outstanding > 0 {
                    VStack(spacing: 4) {
                        Text("¥\(String(format: "%.0f", outstanding))")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.orange)
                        Text("待收款项")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let probability = customer.conversionProbability {
                    VStack(spacing: 4) {
                        Text("\(probability)%")
                            .font(.title3.weight(.bold))
                            .foregroundColor(probability >= 70 ? .green : probability >= 40 ? .orange : .red)
                        Text("成交概率")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !serviceRecords.isEmpty {
                    VStack(spacing: 4) {
                        Text("\(serviceRecords.count)")
                            .font(.title3.weight(.bold))
                        Text("服务次数")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var serviceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("服务记录")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            if serviceRecords.isEmpty && !isLoading {
                Text("暂无服务记录")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(serviceRecords.prefix(5)) { record in
                    Button {
                        selectedRecord = record
                    } label: {
                        ServiceRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
                
                if serviceRecords.count > 5 {
                    Text("还有 \(serviceRecords.count - 5) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedRecord) { record in
            NavigationStack {
                ServiceRecordDetailView(record: record)
            }
        }
    }
    
    private func loadTransactions() async {
        do {
            let result: [Transaction] = try await supabase
                .from("transactions")
                .select("""
                    *,
                    packages(name),
                    stores(name)
                """)
                .eq("customer_id", value: customer.id)
                .order("transaction_date", ascending: false)
                .limit(10)
                .execute()
                .value
            transactions = result
        } catch {
            print("Error loading transactions: \(error)")
        }
    }
    
    private func loadPhotos() async {
        do {
            let result: [CustomerPhoto] = try await supabase
                .from("customer_photos")
                .select()
                .eq("customer_id", value: customer.id)
                .order("created_at", ascending: false)
                .execute()
                .value
            photos = result
        } catch {
            print("Error loading photos: \(error)")
        }
    }
    
    private func loadServiceRecords() async {
        do {
            let result: [ServiceRecord] = try await supabase
                .from("service_records")
                .select()
                .eq("customer_id", value: customer.id)
                .order("service_date", ascending: false)
                .execute()
                .value
            await MainActor.run {
                serviceRecords = result
            }
        } catch {
            print("Error loading service records: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        CustomerDetailView(
            customer: Customer(
                id: UUID(),
                phone: "13800138000",
                name: "张女士",
                gender: "female",
                birthdate: "1990-01-01",
                medicalHistory: "对玻尿酸过敏",
                preferences: ["偏好项目": "水光针"],
                photoUrl: nil,
                associatedStoreId: nil,
                createdBy: nil,
                lastVisit: nil,
                outstandingAmount: 500,
                conversionProbability: 75,
                createdAt: nil,
                updatedAt: nil
            ),
            stores: []
        )
    }
}
