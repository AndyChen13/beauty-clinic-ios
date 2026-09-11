// Views/HomeView.swift
import SwiftUI

enum DashboardDetail: Identifiable {
    case customersByStore
    case todayTransactions
    case monthlyRevenue
    case pendingDeliveries
    case pendingCollections
    case monthlyTop
    case storeRebates
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
        case .storeRebates: return "storeRebates"
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
    @State private var storeRebatePeriods: [StoreRebatePeriod] = []
    @State private var isLoading = true
    
    // Dashboard summary cache
    @State private var summary: DashboardService.DashboardSummaryResponse? = nil
    @State private var selectedDetail: DashboardDetail?
    
    @State private var showAddCustomerSheet = false
    
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
    
    var totalCustomers: Int { summary?.customerCount ?? customers.count }
    var totalStores: Int { stores.count }
    
    var todayTransactionsList: [Transaction] {
        transactions.filter { $0.transactionDate >= startOfDay }
            .sorted { $0.transactionDate > $1.transactionDate }
    }
    var todayStoreRebate: Double {
        summary?.today.rebate ?? (storeRebatePeriods
            .filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentDay ?? false) }
            .reduce(0) { $0 + ($1.confirmedRebate ?? 0) })
    }
    var todayRebate: Double { todayStoreRebate }
    var todayRevenue: Double {
        todayReceived - todayStoreRebate
    }
    var todayReceived: Double {
        summary?.today.photoElectric.received ?? todayTransactionsList.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var todayPhotoReceived: Double {
        summary?.today.photoElectric.received ?? todayTransactionsList.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var todayMedicalReceived: Double {
        summary?.today.medicalBeauty.received ?? todayTransactionsList.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var todayPhotoRebate: Double {
        todayStoreRebate
    }
    var todayMedicalRebate: Double {
        0
    }
    var todayPhotoRevenue: Double {
        todayPhotoReceived - todayPhotoRebate
    }
    var todayMedicalRevenue: Double {
        todayMedicalReceived - todayMedicalRebate
    }
    var todayPhotoCount: Int {
        summary?.today.photoElectric.count ?? todayTransactionsList.filter { $0.branch == .photoElectric && ($0.amountReceived ?? 0) > 0 }.count
    }
    var todayMedicalCount: Int {
        summary?.today.medicalBeauty.count ?? todayTransactionsList.filter { $0.branch == .medicalBeauty && ($0.amountReceived ?? 0) > 0 }.count
    }
    var todayOutstanding: Double {
        summary?.today.photoElectric.outstanding ?? todayTransactionsList.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var todayReceivedCount: Int {
        summary?.today.photoElectric.count ?? todayTransactionsList.filter { ($0.amountReceived ?? 0) > 0 }.count
    }
    var todayRebateCount: Int {
        storeRebatePeriods.filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentDay ?? false) }.count
    }
    var todayNetCount: Int {
        todayReceivedCount
    }
    var todayOutstandingCount: Int {
        todayTransactionsList.filter { ($0.outstandingAmount ?? 0) > 0 }.count
    }
    
    var monthlyRevenue: Double {
        monthlyReceived - monthlyRebate
    }
    var monthlyReceived: Double {
        summary?.month.photoElectric.received ?? transactions.filter { $0.transactionDate >= startOfMonth }
            .reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var monthlyOutstanding: Double {
        summary?.month.photoElectric.outstanding ?? transactions.filter { $0.transactionDate >= startOfMonth }
            .reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var monthlyPhotoReceived: Double {
        summary?.month.photoElectric.received ?? monthTransactions.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var monthlyMedicalReceived: Double {
        summary?.month.medicalBeauty.received ?? monthTransactions.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.amountReceived ?? 0) }
    }
    var monthlyPhotoRebate: Double {
        monthlyStoreRebate
    }
    var monthlyMedicalRebate: Double {
        0
    }
    var monthlyPhotoRevenue: Double {
        monthlyPhotoReceived - monthlyPhotoRebate
    }
    var monthlyMedicalRevenue: Double {
        monthlyMedicalReceived - monthlyMedicalRebate
    }
    var monthlyPhotoCount: Int {
        summary?.month.photoElectric.count ?? monthTransactions.filter { $0.branch == .photoElectric && ($0.amountReceived ?? 0) > 0 }.count
    }
    var monthlyMedicalCount: Int {
        summary?.month.medicalBeauty.count ?? monthTransactions.filter { $0.branch == .medicalBeauty && ($0.amountReceived ?? 0) > 0 }.count
    }
    var monthlyPhotoOutstanding: Double {
        summary?.month.photoElectric.outstanding ?? monthTransactions.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var monthlyMedicalOutstanding: Double {
        summary?.month.medicalBeauty.outstanding ?? monthTransactions.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var todayPhotoOutstanding: Double {
        summary?.today.photoElectric.outstanding ?? todayTransactionsList.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var todayMedicalOutstanding: Double {
        summary?.today.medicalBeauty.outstanding ?? todayTransactionsList.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    var monthlyPhotoAmount: Double {
        summary?.month.photoElectric.amount ?? monthTransactions.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.amount ?? 0) }
    }
    var monthlyMedicalAmount: Double {
        summary?.month.medicalBeauty.amount ?? monthTransactions.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.amount ?? 0) }
    }
    var todayPhotoAmount: Double {
        summary?.today.photoElectric.amount ?? todayTransactionsList.filter { $0.branch == .photoElectric }.reduce(0) { $0 + ($1.amount ?? 0) }
    }
    var todayMedicalAmount: Double {
        summary?.today.medicalBeauty.amount ?? todayTransactionsList.filter { $0.branch == .medicalBeauty }.reduce(0) { $0 + ($1.amount ?? 0) }
    }
    
    var pendingTransactionsList: [Transaction] {
        transactions.filter {
            ($0.status == .pending || $0.status == .confirmed || $0.status == .inProgress)
            && $0.remainingSessions > 0
        }
    }
    var pendingCustomerCount: Int {
        summary?.pendingCount ?? Set(pendingTransactionsList.map { $0.customerId }).count
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
        if let top = summary?.topStores.first {
            return [(name: top.name, revenue: top.amount)]
        }
        return Dictionary(grouping: monthTransactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    var monthTopCustomers: [(name: String, revenue: Double)] {
        if let top = summary?.topCustomers.first {
            return [(name: top.name, revenue: top.amount)]
        }
        return Dictionary(grouping: monthTransactions, by: { $0.customerName ?? "未知客户" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    var topStore: (name: String, revenue: Double)? { monthTopStores.first }
    var topCustomer: (name: String, revenue: Double)? { monthTopCustomers.first }
    
    var monthlyStoreRebate: Double {
        summary?.month.rebate ?? (storeRebatePeriods
            .filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentMonth ?? false) }
            .reduce(0) { $0 + ($1.confirmedRebate ?? 0) })
    }
    var monthlyRebate: Double { monthlyStoreRebate }
    var monthlyReceivedCount: Int {
        summary?.month.photoElectric.count ?? monthTransactions.filter { ($0.amountReceived ?? 0) > 0 }.count
    }
    var monthlyRebateCount: Int {
        storeRebatePeriods.filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentMonth ?? false) }.count
    }
    var monthlyNetCount: Int {
        monthlyReceivedCount
    }
    var monthlyOutstandingCount: Int {
        monthTransactions.filter { ($0.outstandingAmount ?? 0) > 0 }.count
    }
    var storeRebatesByStore: [(name: String, rebate: Double)] {
        Dictionary(grouping: monthTransactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, rebate: $0.value.reduce(0) { $0 + ($1.storeRebateAmount ?? 0) }) }
            .sorted { $0.rebate > $1.rebate }
    }
    
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
                        todayRebate: todayRebate,
                        todayOutstanding: todayOutstanding,
                        todayReceivedCount: todayReceivedCount,
                        todayRebateCount: todayRebateCount,
                        todayNetCount: todayNetCount,
                        todayOutstandingCount: todayOutstandingCount,
                        todayPhotoReceived: todayPhotoReceived,
                        todayPhotoRevenue: todayPhotoRevenue,
                        todayPhotoOutstanding: todayPhotoOutstanding,
                        todayPhotoCount: todayPhotoCount,
                        todayMedicalReceived: todayMedicalReceived,
                        todayMedicalRevenue: todayMedicalRevenue,
                        todayMedicalOutstanding: todayMedicalOutstanding,
                        todayMedicalCount: todayMedicalCount,
                        monthlyRevenue: monthlyRevenue,
                        monthlyReceived: monthlyReceived,
                        monthlyOutstanding: monthlyOutstanding,
                        monthlyReceivedCount: monthlyReceivedCount,
                        monthlyRebateCount: monthlyRebateCount,
                        monthlyNetCount: monthlyNetCount,
                        monthlyOutstandingCount: monthlyOutstandingCount,
                        monthlyPhotoReceived: monthlyPhotoReceived,
                        monthlyPhotoRevenue: monthlyPhotoRevenue,
                        monthlyPhotoOutstanding: monthlyPhotoOutstanding,
                        monthlyPhotoCount: monthlyPhotoCount,
                        monthlyMedicalReceived: monthlyMedicalReceived,
                        monthlyMedicalRevenue: monthlyMedicalRevenue,
                        monthlyMedicalOutstanding: monthlyMedicalOutstanding,
                        monthlyMedicalCount: monthlyMedicalCount,
                        monthlyPhotoAmount: monthlyPhotoAmount,
                        monthlyMedicalAmount: monthlyMedicalAmount,
                        todayPhotoAmount: todayPhotoAmount,
                        todayMedicalAmount: todayMedicalAmount,
                        pendingCustomers: pendingCustomerCount,
                        pendingSessions: pendingSessionCount,
                        pendingCollectionCount: pendingCollectionCustomers.count,
                        totalOutstanding: totalOutstanding,
                        topStoreName: topStore?.name,
                        topStoreRevenue: topStore?.revenue ?? 0,
                        topCustomerRevenue: topCustomer?.revenue ?? 0,
                        monthlyRebate: monthlyRebate,
                        isLoading: isLoading,
                        onTap: { selectedDetail = $0 }
                    )
                    
                    QuickActionsSection(
                        onAddCustomer: { showAddCustomerSheet = true },
                        onRecordTransaction: {
                            customerPickerMode = .recordTransaction
                        },
                        onRecordDelivery: {
                            customerPickerMode = .recordDelivery
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
            .onAppear { Task { await loadDashboardData() } }
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
                            PendingDeliveriesView(transactions: pendingTransactionsList) {
                                await loadDashboardData()
                            }
                        case .pendingCollections:
                            PendingCollectionsView(customers: pendingCollectionCustomers, stores: stores)
                        case .monthlyTop:
                            MonthlyTopView(transactions: transactions)
                        case .storeRebates:
                            StoreRebatesView(stores: stores)
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
            .sheet(item: $customerPickerMode) { mode in
                CustomerPickerView(
                    customers: customers,
                    mode: mode,
                    stores: stores,
                    packages: packages,
                    onSelect: { customer in
                        if mode == .recordDelivery {
                            selectedCustomerForDelivery = customer
                        }
                        customerPickerMode = nil
                    },
                    onComplete: {
                        customerPickerMode = nil
                        Task { await loadDashboardData() }
                    }
                )
                .environmentObject(userState)
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
            // Fast path: summary API for dashboard stats
            async let summaryTask = DashboardService.shared.fetchSummary()
            
            // Slow path: full data for detail views
            async let customersTask = CustomerService.shared.listCustomers()
            async let transactionsTask = TransactionService.shared.listTransactions()
            async let storesTask = StoreService.shared.listStores()
            async let packagesTask = PackageService.shared.listPackages()
            
            let (sum, c, t, s, pkgResult) = try await (summaryTask, customersTask, transactionsTask, storesTask, packagesTask)
            
            var periods: [StoreRebatePeriod] = []
            try await withThrowingTaskGroup(of: [StoreRebatePeriod].self) { group in
                for store in s {
                    group.addTask {
                        try await StoreRebateService.shared.getRebateHistory(storeId: store.id.uuidString)
                    }
                }
                for try await history in group {
                    periods.append(contentsOf: history)
                }
            }
            
            await MainActor.run {
                summary = sum
                customers = c
                transactions = t
                stores = s
                packages = pkgResult.0
                storeRebatePeriods = periods
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                // 忽略取消错误（下拉刷新时旧请求被取消是正常的）
            } else {
                print("Dashboard load error: \(error)")
            }
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
    let todayRebate: Double
    let todayOutstanding: Double
    let todayReceivedCount: Int
    let todayRebateCount: Int
    let todayNetCount: Int
    let todayOutstandingCount: Int
    let todayPhotoReceived: Double
    let todayPhotoRevenue: Double
    let todayPhotoOutstanding: Double
    let todayPhotoCount: Int
    let todayMedicalReceived: Double
    let todayMedicalRevenue: Double
    let todayMedicalOutstanding: Double
    let todayMedicalCount: Int
    let monthlyRevenue: Double
    let monthlyReceived: Double
    let monthlyOutstanding: Double
    let monthlyReceivedCount: Int
    let monthlyRebateCount: Int
    let monthlyNetCount: Int
    let monthlyOutstandingCount: Int
    let monthlyPhotoReceived: Double
    let monthlyPhotoRevenue: Double
    let monthlyPhotoOutstanding: Double
    let monthlyPhotoCount: Int
    let monthlyMedicalReceived: Double
    let monthlyMedicalRevenue: Double
    let monthlyMedicalOutstanding: Double
    let monthlyMedicalCount: Int
    let monthlyPhotoAmount: Double
    let monthlyMedicalAmount: Double
    let todayPhotoAmount: Double
    let todayMedicalAmount: Double
    let pendingCustomers: Int
    let pendingSessions: Int
    let pendingCollectionCount: Int
    let totalOutstanding: Double
    let topStoreName: String?
    let topStoreRevenue: Double
    let topCustomerRevenue: Double
    let monthlyRebate: Double
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
                subtitle: {
                    BranchStack(
                        medicalAmount: monthlyMedicalAmount,
                        medicalReceived: monthlyMedicalReceived,
                        medicalOutstanding: monthlyMedicalOutstanding,
                        medicalCount: monthlyMedicalCount,
                        photoAmount: monthlyPhotoAmount,
                        photoReceived: monthlyPhotoReceived,
                        photoOutstanding: monthlyPhotoOutstanding,
                        photoCount: monthlyPhotoCount,
                        totalRebate: monthlyRebate
                    )
                },
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            ) { onTap(.monthlyRevenue) }

            StatCard(
                title: "今日成交",
                value: isLoading ? "--" : "¥\(Int(todayRevenue))",
                subtitle: {
                    BranchStack(
                        medicalAmount: todayMedicalAmount,
                        medicalReceived: todayMedicalReceived,
                        medicalOutstanding: todayMedicalOutstanding,
                        medicalCount: todayMedicalCount,
                        photoAmount: todayPhotoAmount,
                        photoReceived: todayPhotoReceived,
                        photoOutstanding: todayPhotoOutstanding,
                        photoCount: todayPhotoCount,
                        totalRebate: todayRebate
                    )
                },
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
            
            StatCard(
                title: "门店返利",
                value: isLoading ? "--" : "¥\(Int(monthlyRebate))",
                subtitle: isLoading ? nil : "本月已确认 \(monthlyRebateCount) 笔",
                icon: "arrowshape.turn.up.left.fill",
                color: .orange
            ) { onTap(.storeRebates) }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: AnyView?
    let icon: String
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle.map { AnyView(Text($0)) }
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    init(
        title: String,
        value: String,
        @ViewBuilder subtitle: () -> some View,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.subtitle = AnyView(subtitle())
        self.icon = icon
        self.color = color
        self.action = action
    }
    
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
                    subtitle
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

private struct DashboardMetricRow: View {
    let label: String
    let amount: Double
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 32, alignment: .leading)
            Text("¥\(Int(amount))")
                .frame(width: 62, alignment: .trailing)
            Text("(\(count)笔)")
                .frame(width: 44, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct BranchMetricRow: View {
    let label: String
    let color: Color
    let received: Double
    let revenue: Double
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
                .frame(width: 32, alignment: .leading)
            Text("实¥\(Int(received))")
                .frame(width: 60, alignment: .trailing)
            Text("净¥\(Int(revenue))")
                .frame(width: 60, alignment: .trailing)
            Text("(\(count)笔)")
                .frame(width: 40, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct BranchStack: View {
    let medicalAmount: Double
    let medicalReceived: Double
    let medicalOutstanding: Double
    let medicalCount: Int
    let photoAmount: Double
    let photoReceived: Double
    let photoOutstanding: Double
    let photoCount: Int
    let totalRebate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BranchBlock(label: "光电",
                        color: TransactionBranch.photoElectric.color,
                        amount: photoAmount,
                        received: photoReceived,
                        outstanding: photoOutstanding,
                        count: photoCount)

            BranchBlock(label: "医美",
                        color: TransactionBranch.medicalBeauty.color,
                        amount: medicalAmount,
                        received: medicalReceived,
                        outstanding: medicalOutstanding,
                        count: medicalCount)
            
            RebateSubItem(label: "返利", amount: totalRebate)
        }
    }
}

private struct BranchBlock: View {
    let label: String
    let color: Color
    let amount: Double
    let received: Double
    let outstanding: Double
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            SubItem(label: "应收", amount: amount, count: count)
            SubItem(label: "实收", amount: received)
            SubItem(label: "待收", amount: outstanding)
        }
    }
}

private struct RebateSubItem: View {
    let label: String
    let amount: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 28, alignment: .leading)
            Text("¥\(Int(amount))")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 0)
        }
    }
}

private struct SubItem: View {
    let label: String
    let amount: Double
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 28, alignment: .leading)
            Text("¥\(Int(amount))")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .layoutPriority(1)
            if let count = count {
                Text("(\(count)笔)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
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

extension Date {
    var isInCurrentMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    var isInCurrentDay: Bool {
        Calendar.current.isDate(self, inSameDayAs: Date())
    }
}

#Preview {
    HomeView()
        .environmentObject(UserState())
}
