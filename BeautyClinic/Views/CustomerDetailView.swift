//  Views/CustomerDetailView.swift
//  BeautyClinic
//

import SwiftUI

struct CustomerDetailView: View {
    let customer: Customer
    @State private var isEditing = false
    @State private var transactions: [Transaction] = []
    @State private var isLoadingTransactions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Card
                profileCard
                
                // Info Card
                infoCard
                
                // Medical History
                if let history = customer.medicalHistory, !history.isEmpty {
                    medicalHistoryCard(history: history)
                }
                
                // Preferences
                if let prefs = customer.preferences, !prefs.isEmpty {
                    preferencesCard(prefs: prefs)
                }
                
                // Recent Transactions
                recentTransactionsSection
            }
            .padding()
        }
        .navigationTitle(customer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            CustomerEditView(mode: .edit(customer)) { _ in }
        }
        .task { await loadTransactions() }
    }
    
    private var profileCard: some View {
        VStack(spacing: 14) {
            AvatarView(name: customer.name, size: 72)
            Text(customer.name)
                .font(.title2.weight(.bold))
            Text(customer.phone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                InfoBadge(label: "性别", value: customer.genderDisplay)
                if let age = customer.age {
                    InfoBadge(label: "年龄", value: "\(age)岁")
                }
                if let birthdate = customer.birthdate {
                    InfoBadge(
                        label: "生日",
                        value: birthdate.formatted(.dateTime.month().day())
                    )
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
                InfoRow(label: "出生日期", value: birthdate.formatted(date: .long, time: .omitted))
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
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("消费记录")
                    .font(.headline)
                Spacer()
                if isLoadingTransactions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if transactions.isEmpty && !isLoadingTransactions {
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
    
    private func loadTransactions() async {
        isLoadingTransactions = true
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
        isLoadingTransactions = false
    }
}

struct InfoBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

struct TransactionMiniRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.packageName ?? "未知套餐")
                    .font(.subheadline.weight(.medium))
                Text(transaction.transactionDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("¥\(String(format: "%.0f", transaction.amount))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        CustomerDetailView(customer: Customer(
            id: UUID(),
            phone: "13800138000",
            name: "张女士",
            gender: "female",
            birthdate: Date(timeIntervalSince1970: 631152000),
            medicalHistory: "对玻尿酸过敏",
            preferences: ["偏好项目": "水光针", "来源渠道": "小红书"],
            associatedStoreId: nil,
            lastVisit: nil,
            createdAt: nil,
            updatedAt: nil
        ))
    }
}
