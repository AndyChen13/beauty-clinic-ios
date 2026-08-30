// Views/HomeView.swift
import SwiftUI

enum DashboardDetail: Identifiable {
    case customersByStore
    case todayTransactions
    case monthlyRevenue
    case pendingDeliveries
    case pendingCollections
    case monthlyTop
    case revenueReport
    case revenueSplit
    
    var id: String {
        switch self {
        case .customersByStore: return "customersByStore"
        case .todayTransactions: return "todayTransactions"
        case .monthlyRevenue: return "monthlyRevenue"
        case .pendingDeliveries: return "pendingDeliveries"
        case .pendingCollections: return "pendingCollections"
        case .monthlyTop: return "monthlyTop"
        case .revenueReport: return "revenueReport"
        case .revenueSplit: return "revenueSplit"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var userState: UserState
    @State private var customers: [Customer] = []
    @State private var transactions: [Transaction] = []
    @State private var stores: [Store] = []
    @State private var packages: [ServicePackage] = []
    @State private var isLoading = true
    @State private var selectedDetail: DashboardDetail?
    
    @State private var showAddCustomerSheet = false
    
    @State private var showCustomerPicker = false
    @State private var customerPickerMode: CustomerPickerMode?
    @State private var selectedCustomerForDelivery: Customer?
    
    private var calendar: Calendar { Calendar.current }
    private var now: Date { Date() }
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    }
    private var startOfDay: Date {
        calendar.startOfDay(for: now)
    }
    
    var totalCustomers: Int { customers.count }
    var totalStores: Int { stores.count }
    
    var todayTransactionsList: [Transaction] {
        transactions.filter { $0.transactionDate >= startOfDay }
            .sorted { $0.transactionDate > $1.transactionDate }
    }
    var todayRevenue: Double {
        todayTransactionsList.reduce(0) { $0 + $1.amount }
    }
    var todayReceived: Double {
        todayTransactionsList.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var todayOutstanding: Double {
        todayTransactionsList.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    
    var monthlyRevenue: Double {
        transactions.filter { $0.transactionDate >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
    }
    var monthlyReceived: Double {
        transactions.filter { $0.transactionDate >= startOfMonth }
            .reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var monthlyOutstanding: Double {
        transactions.filter { $0.transactionDate >= startOfMonth }
            .reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    
    var pendingTransactionsList: [Transaction] {
        transactions.filter {
            ($0.status == .pending || $0.status == .confirmed || $0.status == .inProgress)
            && $0.remainingSessions > 0
        }
    }
    var pendingCustomerCount: Int {
        Set(pendingTransactionsList.map { $0.customerId }).count
    }
    var pendingSessionCount: Int {
        pendingTransactionsList.reduce(0) { $0 + $1.remainingSessions }
    }
    
    var pendingCollectionCustomers: [Customer] {
        customers.filter { ($0.outstandingAmount ?? 0) > 0 }
            .sorted { ($0.outstandingAmount ?? 0) > ($1.outstandingAmount ?? 0) }
    }
    var totalOutstanding: Double {
        pendingCollectionCustomers.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    
    var monthTransactions: [Transaction] {
        transactions.filter { $0.transactionDate >= startOfMonth }
    }
    var monthTopStores: [(name: String, revenue: Double)] {
        Dictionary(grouping: monthTransactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    var monthTopCustomers: [(name: String, revenue: Double)] {
        Dictionary(grouping: monthTransactions, by: { $0.customerName ?? "未知客户" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    var topStore: (name: String, revenue: Double)? { monthTopStores.first }
    var topCustomer: (name: String, revenue: Double)? { monthTopCustomers.first }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderSection(userName: userState.currentUser?.name ?? "管理员")
                    
                    StatsGrid(
                        customers: totalCustomers,
                        stores: totalStores,
                        todayCount: todayTransactionsList.count,
                        todayRevenue: todayRevenue,
                        todayReceived: todayReceived,
                        todayOutstanding: todayOutstanding,
                        monthlyRevenue: monthlyRevenue,
                        monthlyReceived: monthlyReceived,
                        monthlyOutstanding: monthlyOutstanding,
                        pendingCustomers: pendingCustomerCount,
                        pendingSessions: pendingSessionCount,
                        pendingCollectionCount: pendingCollectionCustomers.count,
                        totalOutstanding: totalOutstanding,
                        topStoreName: topStore?.name,
                        topStoreRevenue: topStore?.revenue ?? 0,
                        topCustomerRevenue: topCustomer?.revenue ?? 0,
                        isLoading: isLoading,
                        onTap: { selectedDetail = $0 }
                    )
                    
                    QuickActionsSection(
                        onAddCustomer: { showAddCustomerSheet = true },
                        onRecordTransaction: {
                            customerPickerMode = .recordTransaction
                            showCustomerPicker = true
                        },
                        onRecordDelivery: {
                            customerPickerMode = .recordDelivery
                            showCustomerPicker = true
                        },
                        onDataReport: { selectedDetail = .revenueReport },
                        onRevenueSplit: { selectedDetail = .revenueSplit }
                    )
                    
                    RecentActivitySection(transactions: recentTransactions, isLoading: isLoading)
                }
                .padding()
            }
            .navigationTitle("首页")
            .refreshable { await loadDashboardData() }
            .task { await loadDashboardData() }
            .sheet(item: $selectedDetail) { detail in
                NavigationStack {
                    Group {
                        switch detail {
                        case .customersByStore:
                            StoreCustomerBreakdownView(stores: stores, customers: customers)
                        case .todayTransactions:
                            TodayTransactionsView(transactions: todayTransactionsList)
                        case .monthlyRevenue:
                            MonthlyRevenueTrendView(transactions: transactions)
                        case .pendingDeliveries:
                            PendingDeliveriesView(transactions: pendingTransactionsList)
                        case .pendingCollections:
                            PendingCollectionsView(customers: pendingCollectionCustomers, stores: stores)
                        case .monthlyTop:
                            MonthlyTopView(transactions: transactions)
                        case .revenueReport:
                            RevenueReportView(transactions: transactions, stores: stores)
                        case .revenueSplit:
                            RevenueSplitView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { selectedDetail = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCustomerSheet) {
                CustomerEditView(mode: .create, stores: stores) { _ in
                    Task { await loadDashboardData() }
                }
            }
            .sheet(item: $selectedCustomerForDelivery) { customer in
                NavigationStack {
                    TransactionListView(filterCustomer: customer)
                }
            }
            .sheet(isPresented: $showCustomerPicker) {
                if let mode = customerPickerMode {
                    CustomerPickerView(
                        customers: customers,
                        mode: mode,
                        stores: stores,
                        packages: packages,
                        onSelect: { customer in
                            if mode == .recordDelivery {
                                showCustomerPicker = false
                                selectedCustomerForDelivery = customer
                            }
                            customerPickerMode = nil
                        },
                        onComplete: {
                            Task { await loadDashboardData() }
                        }
                    )
                }
            }
        }
    }
    
    private var recentTransactions: [Transaction] {
        transactions.sorted { $0.transactionDate > $1.transactionDate }.prefix(5).map { $0 }
    }
    
    private func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let customersTask = CustomerService.shared.listCustomers()
            async let transactionsTask = TransactionService.shared.listTransactions()
            async let storesTask = StoreService.shared.listStores()
            async let packagesTask = PackageService.shared.listPackages()
            
            let (c, t, s, pkgResult) = try await (customersTask, transactionsTask, storesTask, packagesTask)
            
            await MainActor.run {
                customers = c
                transactions = t
                stores = s
                packages = pkgResult.0
            }
        } catch {
            print("Dashboard load error: \(error)")
        }
    }
}

struct HeaderSection: View {
    let userName: String
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: userName, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("你好，\(userName)")
                    .font(.title3.weight(.semibold))
                Text("欢迎回到 Beauty Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct StatsGrid: View {
    let customers: Int
    let stores: Int
    let todayCount: Int
    let todayRevenue: Double
    let todayReceived: Double
    let todayOutstanding: Double
    let monthlyRevenue: Double
    let monthlyReceived: Double
    let monthlyOutstanding: Double
    let pendingCustomers: Int
    let pendingSessions: Int
    let pendingCollectionCount: Int
    let totalOutstanding: Double
    let topStoreName: String?
    let topStoreRevenue: Double
    let topCustomerRevenue: Double
    let isLoading: Bool
    let onTap: (DashboardDetail) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "客户总数",
                value: isLoading ? "--" : "\(customers)/\(stores)",
                subtitle: isLoading ? nil : "客户/门店",
                icon: "person.3.fill",
                color: .blue
            ) { onTap(.customersByStore) }
            
            StatCard(
                title: "待交付",
                value: isLoading ? "--" : "\(pendingCustomers)/\(pendingSessions)",
                subtitle: isLoading ? nil : "客户/次数",
                icon: "clock.fill",
                color: .purple
            ) { onTap(.pendingDeliveries) }
            
            StatCard(
                title: "本月收入",
                value: isLoading ? "--" : "¥\(Int(monthlyRevenue))",
                subtitle: isLoading ? nil : "实收 ¥\(Int(monthlyReceived)) · 应收 ¥\(Int(monthlyReceived + monthlyOutstanding)) · 待收 ¥\(Int(monthlyOutstanding))",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            ) { onTap(.monthlyRevenue) }
            
            StatCard(
                title: "今日成交",
                value: isLoading ? "--" : "¥\(Int(todayRevenue))",
                subtitle: isLoading ? nil : "实收 ¥\(Int(todayReceived)) · 应收 ¥\(Int(todayReceived + todayOutstanding)) · 待收 ¥\(Int(todayOutstanding)) · \(todayCount) 笔",
                icon: "cart.fill",
                color: .green
            ) { onTap(.todayTransactions) }
            
            StatCard(
                title: "待收款",
                value: isLoading ? "--" : "\(pendingCollectionCount)/¥\(Int(totalOutstanding))",
                subtitle: isLoading ? nil : "客户数/待收金额",
                icon: "creditcard.fill",
                color: .red
            ) { onTap(.pendingCollections) }
            
            StatCard(
                title: "当月最佳成交",
                value: isLoading ? "--" : (topStoreName ?? "暂无"),
                subtitle: isLoading ? nil : "门店 ¥\(Int(topStoreRevenue)) · 客户 ¥\(Int(topCustomerRevenue))",
                icon: "trophy.fill",
                color: .yellow
            ) { onTap(.monthlyTop) }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionsSection: View {
    let onAddCustomer: () -> Void
    let onRecordTransaction: () -> Void
    let onRecordDelivery: () -> Void
    let onDataReport: () -> Void
    let onRevenueSplit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "新增客户", icon: "person.badge.plus", color: .blue, action: onAddCustomer)
                QuickActionButton(title: "记录成交", icon: "doc.badge.plus", color: .green, action: onRecordTransaction)
                QuickActionButton(title: "记录交付", icon: "checkmark.circle", color: .orange, action: onRecordDelivery)
                QuickActionButton(title: "数据报表", icon: "chart.pie.fill", color: .purple, action: onDataReport)
                QuickActionButton(title: "营收精算", icon: "arrow.left.arrow.right.circle", color: .pink, action: onRevenueSplit)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct RecentActivitySection: View {
    let transactions: [Transaction]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近成交")
                    .font(.headline)
                Spacer()
                if !transactions.isEmpty {
                    Text("共 \(transactions.count) 笔")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isLoading {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 64)
                        .shimmering()
                }
            } else if transactions.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "暂无成交记录",
                    subtitle: "添加第一笔成交记录"
                )
            } else {
                ForEach(transactions) { transaction in
                    ActivityRow(transaction: transaction)
                }
            }
        }
    }
}

struct ActivityRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(transaction.status.color.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(transaction.status.color)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.packageName ?? "未知套餐")
                    .font(.subheadline.weight(.medium))
                Text(transaction.customerName ?? "未知客户")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text("¥\(String(format: "%.0f", transaction.amount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text("\(transaction.completedSessions)/\(transaction.totalSessions)次")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .environmentObject(UserState())
}
