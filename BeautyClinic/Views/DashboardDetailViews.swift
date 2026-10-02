// Views/DashboardDetailViews.swift
import SwiftUI
import Charts
import UIKit
import UniformTypeIdentifiers
import QuickLook

// MARK: - Customers by Store
struct StoreCustomerBreakdownView: View {
    let stores: [Store]
    let customers: [Customer]
    
    var storeCustomerCounts: [(store: Store, count: Int)] {
        stores.map { store in
            let count = customers.filter { $0.associatedStoreId == store.id }.count
            return (store, count)
        }
        .sorted { $0.count > $1.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(title: "客户总数", value: "\(customers.count)", subtitle: "归属 \(stores.count) 家门店")
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("门店分布")
                        .font(.headline)
                    
                    if storeCustomerCounts.isEmpty {
                        EmptyStateView(icon: "building.2", title: "暂无数据", subtitle: "门店或客户为空")
                    } else {
                        Chart(storeCustomerCounts, id: \.store.id) { item in
                            SectorMark(
                                angle: .value("客户数", max(item.count, 1)),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("门店", item.store.name))
                        }
                        .frame(height: 220)
                        .chartLegend(position: .bottom, spacing: 16)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("门店明细")
                        .font(.headline)
                    
                    ForEach(storeCustomerCounts, id: \.store.id) { item in
                        HStack {
                            Text(item.store.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count) 人")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("客户分布")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Today's Transactions
struct TodayTransactionsView: View {
    let transactions: [Transaction]
    
    var totalRevenue: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "今日成交",
                    value: "¥\(Int(totalRevenue))",
                    subtitle: "共 \(transactions.count) 笔"
                )
                
                if transactions.isEmpty {
                    EmptyStateView(icon: "cart", title: "今日暂无成交", subtitle: "去记录第一笔成交")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("成交明细")
                            .font(.headline)
                        
                        ForEach(transactions) { transaction in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(transaction.customerName ?? "未知客户")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("¥\(String(format: "%.0f", transaction.amount))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                }
                                
                                HStack(spacing: 12) {
                                    Label(transaction.packageName ?? "未知套餐", systemImage: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Label(transaction.storeName ?? "未知门店", systemImage: "building.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("\(transaction.transactionDate.formatted(date: .abbreviated, time: .shortened)) · \(transaction.completedSessions)/\(transaction.totalSessions)次")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("今日成交")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Monthly Revenue Trend
struct MonthlyRevenueTrendView: View {
    let transactions: [Transaction]
    /// 统计锚点日期：默认本月；传入上月初可查看上月
    var anchor: Date = Date()
    
    @State private var selectedDate: Date?
    
    private var calendar: Calendar { Calendar.current }
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))!
    }
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: anchor)!.count
    }
    private var isCurrentMonth: Bool {
        calendar.isDate(anchor, equalTo: Date(), toGranularity: .month)
    }
    private var periodTitle: String {
        isCurrentMonth ? "本月收入" : anchor.formatted(.dateTime.year().month()) + "收入"
    }
    
    struct DailyRevenue: Identifiable {
        let id = UUID()
        let day: Int
        let date: Date
        let revenue: Double
        let storeBreakdown: [(storeName: String, amount: Double)]
    }
    
    var dailyRevenues: [DailyRevenue] {
        let monthTransactions = transactions.filter { $0.transactionDate >= startOfMonth }
        return (1...daysInMonth).map { day in
            let components = calendar.dateComponents([.year, .month], from: anchor)
            let dayComponents = DateComponents(year: components.year, month: components.month, day: day)
            let date = calendar.date(from: dayComponents)!
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let dayTransactions = monthTransactions.filter { $0.transactionDate >= start && $0.transactionDate < end }
            let revenue = dayTransactions.reduce(0) { $0 + $1.amount }
            let storeBreakdown = Dictionary(grouping: dayTransactions, by: { $0.storeName ?? "未知门店" })
                .map { (storeName: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.amount > $1.amount }
            return DailyRevenue(day: day, date: date, revenue: revenue, storeBreakdown: storeBreakdown)
        }
    }
    
    var monthlyTotal: Double {
        dailyRevenues.reduce(0) { $0 + $1.revenue }
    }
    
    var selectedDayData: DailyRevenue? {
        guard let selectedDate else { return nil }
        return dailyRevenues.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: periodTitle,
                    value: "¥\(Int(monthlyTotal))",
                    subtitle: startOfMonth.formatted(.dateTime.year().month())
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("收入走势")
                        .font(.headline)
                    
                    Chart(dailyRevenues) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("收入", item.revenue)
                        )
                        .foregroundStyle(
                            selectedDate != nil && calendar.isDate(item.date, inSameDayAs: selectedDate!)
                            ? Color.accentColor
                            : Color.accentColor.opacity(0.6)
                        )
                        .cornerRadius(4)
                    }
                    .frame(height: 240)
                    .chartXSelection(value: Binding(
                        get: { selectedDate },
                        set: { newValue in
                            if let newValue {
                                selectedDate = newValue
                            }
                        }
                    ))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("¥\(Int(doubleValue))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    
                    if let selected = selectedDayData {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(selected.date.formatted(.dateTime.month().day()))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("¥\(Int(selected.revenue))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            
                            Divider()
                            
                            ForEach(selected.storeBreakdown, id: \.storeName) { item in
                                HStack {
                                    Text(item.storeName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("¥\(Int(item.amount))")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("收入统计")
                        .font(.headline)
                    
                    let nonEmptyDays = dailyRevenues.filter { $0.revenue > 0 }
                    InfoRow(label: "有成交天数", value: "\(nonEmptyDays.count) 天")
                    InfoRow(label: "日均收入", value: "¥\(nonEmptyDays.isEmpty ? 0 : Int(monthlyTotal / Double(nonEmptyDays.count)))")
                    InfoRow(label: "最高单日", value: "¥\(Int(nonEmptyDays.max { $0.revenue < $1.revenue }?.revenue ?? 0))")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle(periodTitle)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Year Revenue Trend
struct YearRevenueTrendView: View {
    let transactions: [Transaction]
    
    private var calendar: Calendar { Calendar.current }
    private var startOfYear: Date {
        calendar.date(from: calendar.dateComponents([.year], from: Date()))!
    }
    
    struct MonthlyRevenue: Identifiable {
        let id = UUID()
        let month: Int
        let date: Date
        let revenue: Double
    }
    
    var monthlyRevenues: [MonthlyRevenue] {
        let yearComponents = calendar.dateComponents([.year], from: Date())
        return (1...12).map { month in
            let date = calendar.date(from: DateComponents(year: yearComponents.year, month: month, day: 1))!
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            let monthTransactions = transactions.filter { $0.transactionDate >= start && $0.transactionDate < end }
            let revenue = monthTransactions.reduce(0) { $0 + $1.amount }
            return MonthlyRevenue(month: month, date: date, revenue: revenue)
        }
    }
    
    var yearTotal: Double {
        monthlyRevenues.reduce(0) { $0 + $1.revenue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "全年收入",
                    value: "¥\(Int(yearTotal))",
                    subtitle: startOfYear.formatted(.dateTime.year())
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("月度收入走势")
                        .font(.headline)
                    
                    Chart(monthlyRevenues) { item in
                        BarMark(
                            x: .value("月份", item.date, unit: .month),
                            y: .value("收入", item.revenue)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                        .cornerRadius(4)
                    }
                    .frame(height: 240)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("¥\(Int(doubleValue))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("收入统计")
                        .font(.headline)
                    
                    let nonEmptyMonths = monthlyRevenues.filter { $0.revenue > 0 }
                    InfoRow(label: "有成交月数", value: "\(nonEmptyMonths.count) 个月")
                    InfoRow(label: "月均收入", value: "¥\(nonEmptyMonths.isEmpty ? 0 : Int(yearTotal / Double(nonEmptyMonths.count)))")
                    InfoRow(label: "最高单月", value: "¥\(Int(nonEmptyMonths.max { $0.revenue < $1.revenue }?.revenue ?? 0))")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("全年累计收入")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Pending Deliveries
struct PendingDeliveriesView: View {
    let transactions: [Transaction]
    let onReload: () async -> Void
    
    var groupedByCustomer: [(name: String, count: Int, sessions: Int)] {
        let dict = Dictionary(grouping: transactions, by: { $0.customerId })
        return dict.compactMap { (_, txs) in
            guard let first = txs.first else { return nil }
            let sessions = txs.reduce(0) { $0 + $1.remainingSessions }
            return (name: first.customerName ?? "未知客户", count: txs.count, sessions: sessions)
        }
        .sorted { $0.sessions > $1.sessions }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "待交付",
                    value: "\(groupedByCustomer.count)/\(transactions.reduce(0) { $0 + $1.remainingSessions })",
                    subtitle: "客户数/待交付次数"
                )
                
                if groupedByCustomer.isEmpty {
                    EmptyStateView(icon: "checkmark.circle", title: "没有待交付", subtitle: "所有客户已完成交付")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("客户明细")
                            .font(.headline)
                        
                        ForEach(Array(groupedByCustomer.enumerated()), id: \.offset) { _, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(item.count) 个套餐未完成")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("剩 \(item.sessions) 次")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.purple)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("待交付")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await onReload() }
    }
}

// MARK: - Pending Collections
struct PendingCollectionsView: View {
    let customers: [Customer]
    let stores: [Store]
    
    var totalOutstanding: Double {
        customers.reduce(0) { $0 + ($1.outstandingAmount ?? 0) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "待收款",
                    value: "¥\(Int(totalOutstanding))",
                    subtitle: "共 \(customers.count) 位客户待收款"
                )
                
                if customers.isEmpty {
                    EmptyStateView(icon: "creditcard", title: "暂无待收款", subtitle: "所有客户已结清")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("客户明细")
                            .font(.headline)
                        
                        ForEach(customers) { customer in
                            NavigationLink {
                                CustomerDetailView(customer: customer, stores: stores)
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(name: customer.name, size: 44)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(customer.name)
                                            .font(.subheadline.weight(.medium))
                                        Text(customer.phone)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("待收 ¥\(Int(customer.outstandingAmount ?? 0))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("待收款")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Monthly Top
struct MonthlyTopView: View {
    let transactions: [Transaction]
    
    private var calendar: Calendar { Calendar.current }
    private var now: Date { Date() }
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    }
    
    private var monthTransactions: [Transaction] {
        transactions.filter { $0.transactionDate >= startOfMonth }
    }
    
    var totalRevenue: Double {
        monthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var topStores: [(name: String, revenue: Double)] {
        Dictionary(grouping: monthTransactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var topCustomers: [(name: String, revenue: Double)] {
        Dictionary(grouping: monthTransactions, by: { $0.customerName ?? "未知客户" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "当月成交",
                    value: "¥\(Int(totalRevenue))",
                    subtitle: "共 \(monthTransactions.count) 笔 · \(startOfMonth.formatted(.dateTime.year().month()))"
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("最佳门店")
                        .font(.headline)
                    
                    if topStores.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topStores.enumerated()), id: \.offset) { index, item in
                            HStack {
                                rankBadge(index)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(Int(item.revenue))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("最佳客户")
                        .font(.headline)
                    
                    if topCustomers.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topCustomers.enumerated()), id: \.offset) { index, item in
                            HStack {
                                rankBadge(index)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(Int(item.revenue))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("当月最佳成交")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func rankBadge(_ index: Int) -> some View {
        let medals: [Color] = [.yellow, .gray, .brown]
        let isTopThree = index < 3
        let badgeColor = isTopThree ? medals[index] : Color(UIColor.tertiarySystemBackground)
        return Text("\(index + 1)")
            .font(.caption.weight(.bold))
            .foregroundColor(isTopThree ? .black : .secondary)
            .frame(width: 24, height: 24)
            .background(badgeColor)
            .clipShape(Circle())
    }
}

// MARK: - 历史最佳成交（自使用 App 至今）
struct AllTimeTopView: View {
    let transactions: [Transaction]
    
    var totalRevenue: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    /// 最早一笔成交日期（即开始使用 App 至今的起点）
    var sinceDate: Date? {
        transactions.map { $0.transactionDate }.min()
    }
    
    var topStores: [(name: String, revenue: Double)] {
        Dictionary(grouping: transactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var topCustomers: [(name: String, revenue: Double)] {
        Dictionary(grouping: transactions, by: { $0.customerName ?? "未知客户" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "历史累计成交",
                    value: "¥\(Int(totalRevenue))",
                    subtitle: {
                        if let since = sinceDate {
                            return "共 \(transactions.count) 笔 · 自 \(since.formatted(.dateTime.year().month().day())) 至今"
                        }
                        return "共 \(transactions.count) 笔"
                    }()
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("最佳门店")
                        .font(.headline)
                    
                    if topStores.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topStores.enumerated()), id: \.offset) { index, item in
                            HStack {
                                rankBadge(index)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(Int(item.revenue))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("最佳客户")
                        .font(.headline)
                    
                    if topCustomers.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(topCustomers.enumerated()), id: \.offset) { index, item in
                            HStack {
                                rankBadge(index)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(Int(item.revenue))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("历史最佳成交")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func rankBadge(_ index: Int) -> some View {
        let medals: [Color] = [.yellow, .gray, .brown]
        let isTopThree = index < 3
        let badgeColor = isTopThree ? medals[index] : Color(UIColor.tertiarySystemBackground)
        return Text("\(index + 1)")
            .font(.caption.weight(.bold))
            .foregroundColor(isTopThree ? .black : .secondary)
            .frame(width: 24, height: 24)
            .background(badgeColor)
            .clipShape(Circle())
    }
}

// MARK: - Revenue Report
struct RevenueReportView: View {
    let transactions: [Transaction]
    let stores: [Store]
    
    private var calendar: Calendar { Calendar.current }
    private var now: Date { Date() }
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    }
    private var startOfDay: Date {
        calendar.startOfDay(for: now)
    }
    
    var totalRevenue: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    var monthlyRevenue: Double {
        transactions.filter { $0.transactionDate >= startOfMonth }.reduce(0) { $0 + $1.amount }
    }
    var todayRevenue: Double {
        transactions.filter { $0.transactionDate >= startOfDay }.reduce(0) { $0 + $1.amount }
    }
    
    var revenueByStore: [(name: String, revenue: Double)] {
        Dictionary(grouping: transactions, by: { $0.storeName ?? "未知门店" })
            .map { (name: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var revenueByStatus: [(status: TransactionStatus, revenue: Double, count: Int)] {
        Dictionary(grouping: transactions, by: { $0.status })
            .map { (status: $0.key, revenue: $0.value.reduce(0) { $0 + $1.amount }, count: $0.value.count) }
            .sorted { $0.revenue > $1.revenue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    SummaryCard(title: "总营收", value: "¥\(Int(totalRevenue))", subtitle: "累计")
                    SummaryCard(title: "本月", value: "¥\(Int(monthlyRevenue))", subtitle: startOfMonth.formatted(.dateTime.month()))
                }
                
                SummaryCard(title: "今日", value: "¥\(Int(todayRevenue))", subtitle: "\(transactions.filter { $0.transactionDate >= startOfDay }.count) 笔")
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("门店营收排行")
                        .font(.headline)
                    
                    if revenueByStore.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(revenueByStore.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(Int(item.revenue))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("成交状态分布")
                        .font(.headline)
                    
                    if revenueByStatus.isEmpty {
                        Text("暂无数据")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(revenueByStatus, id: \.status) { item in
                            BarMark(
                                x: .value("金额", item.revenue),
                                y: .value("状态", item.status.displayName)
                            )
                            .foregroundStyle(item.status.color)
                            .cornerRadius(4)
                        }
                        .frame(height: CGFloat(revenueByStatus.count * 44))
                        .chartXAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text("¥\(Int(doubleValue))")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("数据报表")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Shared Components
struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.bold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}


// MARK: - Revenue Split Calculator
enum SplitPayer: String, Codable, CaseIterable {
    case partnerA, partnerB
    
    var label: String {
        switch self {
        case .partnerA: return "合伙人A"
        case .partnerB: return "合伙人B"
        }
    }
    var short: String { self == .partnerA ? "A" : "B" }
}

struct SplitItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var amountString: String
    var note: String
    var payer: SplitPayer
    
    var amount: Double { Double(amountString) ?? 0 }
    
    init(name: String, amountString: String = "", note: String = "", payer: SplitPayer = .partnerA) {
        self.id = UUID()
        self.name = name
        self.amountString = amountString
        self.note = note
        self.payer = payer
    }
}

struct RevenueSplitState: Codable {
    var partnerARevenue: [SplitItem]
    var partnerAAdvance: [SplitItem]
    var partnerAReimbursement: [SplitItem]
    var partnerBRevenue: [SplitItem]
    var partnerBAdvance: [SplitItem]
    var partnerBReimbursement: [SplitItem]
    var operatorFees: [SplitItem]
    var salonCollects: [SplitItem]
    var storeActualReimbursement: [SplitItem]
    var salonRatioString: String
    var hasGenerated: Bool
}

struct RevenueSplitView: View {
    private let storageKey = "revenueSplitState"
    
    @State private var partnerARevenue: [SplitItem] = [SplitItem(name: "营收1")]
    @State private var partnerAAdvance: [SplitItem] = [SplitItem(name: "垫付1")]
    @State private var partnerAReimbursement: [SplitItem] = [SplitItem(name: "应报1")]
    @State private var partnerBRevenue: [SplitItem] = [SplitItem(name: "营收1")]
    @State private var partnerBAdvance: [SplitItem] = [SplitItem(name: "垫付1")]
    @State private var partnerBReimbursement: [SplitItem] = [SplitItem(name: "应报1")]
    @State private var operatorFees: [SplitItem] = [
        SplitItem(name: "成本1", payer: .partnerA),
        SplitItem(name: "成本2", payer: .partnerB)
    ]
    @State private var salonCollects: [SplitItem] = [SplitItem(name: "代收1")]
    @State private var storeActualReimbursement: [SplitItem] = [SplitItem(name: "实报1")]
    @State private var salonRatioString: String = "30"
    @State private var hasGenerated: Bool = false
    
    private let partnerAColor: Color = .orange
    private let partnerBColor: Color = .pink
    private let salonColor: Color = .green
    private let operatorColor: Color = .cyan
    private let reimbursementColor: Color = .indigo
    
    // MARK: - Computed totals
    private var salonRatio: Double { Double(salonRatioString) ?? 30 }
    
    private var aRev: Double { partnerARevenue.reduce(0) { $0 + $1.amount } }
    private var bRev: Double { partnerBRevenue.reduce(0) { $0 + $1.amount } }
    private var aAdv: Double { partnerAAdvance.reduce(0) { $0 + $1.amount } }
    private var bAdv: Double { partnerBAdvance.reduce(0) { $0 + $1.amount } }
    private var salonCollect: Double { salonCollects.reduce(0) { $0 + $1.amount } }
    private var operatorFeeTotal: Double { operatorFees.reduce(0) { $0 + $1.amount } }
    private var operatorFeeA: Double { operatorFees.filter { $0.payer == .partnerA }.reduce(0) { $0 + $1.amount } }
    private var operatorFeeB: Double { operatorFees.filter { $0.payer == .partnerB }.reduce(0) { $0 + $1.amount } }
    private var aShouldReimburse: Double { partnerAReimbursement.reduce(0) { $0 + $1.amount } }
    private var bShouldReimburse: Double { partnerBReimbursement.reduce(0) { $0 + $1.amount } }
    private var actualReimburseA: Double { storeActualReimbursement.filter { $0.payer == .partnerA }.reduce(0) { $0 + $1.amount } }
    private var actualReimburseB: Double { storeActualReimbursement.filter { $0.payer == .partnerB }.reduce(0) { $0 + $1.amount } }
    
    private var totalRevenue: Double { aRev + bRev + salonCollect }
    private var salonReturn: Double { totalRevenue * (salonRatio / 100) }
    private var afterSalon: Double { totalRevenue - salonReturn }
    private var totalAdvance: Double { aAdv + bAdv }
    private var totalCost: Double { operatorFeeTotal + totalAdvance }
    private var net: Double { afterSalon - totalCost }
    private var eachProfit: Double { net / 2 }
    private var aFinal: Double { eachProfit + aAdv + operatorFeeA + aShouldReimburse }
    private var bFinal: Double { eachProfit + bAdv + operatorFeeB + bShouldReimburse }
    
    private var partnerRevenue: Double { aRev + bRev }
    private var aReturnShare: Double {
        partnerRevenue > 0 ? (aRev / partnerRevenue) * salonReturn : salonReturn / 2
    }
    private var bReturnShare: Double { salonReturn - aReturnShare }
    private var aNetHold: Double { aRev - aReturnShare + actualReimburseA }
    private var bNetHold: Double { bRev - bReturnShare + actualReimburseB }
    private var aDiff: Double { aNetHold - aFinal }
    private var bDiff: Double { bNetHold - bFinal }
    private var transferAmount: Double { abs(aDiff) }
    private var transferText: String {
        if aDiff > 0 {
            return "合伙人A 需转给 合伙人B"
        } else if aDiff < 0 {
            return "合伙人B 需转给 合伙人A"
        } else {
            return "无需转账"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: Partner A
                inputSection(
                    title: "合伙人A — 营收",
                    color: partnerAColor,
                    items: $partnerARevenue,
                    showNote: false,
                    showPayer: false,
                    defaultName: "营收"
                )
                inputSection(
                    title: "合伙人A — 垫付",
                    color: partnerAColor,
                    items: $partnerAAdvance,
                    showNote: true,
                    showPayer: false,
                    defaultName: "垫付"
                )
                inputSection(
                    title: "合伙人A — 应报实销（A 垫付待店家报销）",
                    color: partnerAColor,
                    items: $partnerAReimbursement,
                    showNote: true,
                    showPayer: false,
                    defaultName: "应报"
                )
                
                // MARK: Partner B
                inputSection(
                    title: "合伙人B — 营收",
                    color: partnerBColor,
                    items: $partnerBRevenue,
                    showNote: false,
                    showPayer: false,
                    defaultName: "营收"
                )
                inputSection(
                    title: "合伙人B — 垫付",
                    color: partnerBColor,
                    items: $partnerBAdvance,
                    showNote: true,
                    showPayer: false,
                    defaultName: "垫付"
                )
                inputSection(
                    title: "合伙人B — 应报实销（B 垫付待店家报销）",
                    color: partnerBColor,
                    items: $partnerBReimbursement,
                    showNote: true,
                    showPayer: false,
                    defaultName: "应报"
                )
                
                // MARK: Operator fees
                inputSection(
                    title: "营销/运营成本（利润内扣除 · 两人分摊 · 点击切换垫付人）",
                    color: operatorColor,
                    items: $operatorFees,
                    showNote: true,
                    showPayer: true,
                    defaultName: "成本"
                )
                
                // MARK: Salon collect
                inputSection(
                    title: "门店 — 代收",
                    color: salonColor,
                    items: $salonCollects,
                    showNote: false,
                    showPayer: false,
                    defaultName: "代收"
                )
                
                // MARK: Store actual reimbursement
                inputSection(
                    title: "店家实际报销（实际给了谁多少 · 点击切换 A/B）",
                    color: reimbursementColor,
                    items: $storeActualReimbursement,
                    showNote: true,
                    showPayer: true,
                    defaultName: "实报"
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("实报实销说明")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("上方分别填 A/B「应报实销」金额（各自垫付、待店家报销的部分）；这里填店家实际报销给了谁多少。若店家把 B 的报销错给了 A，差额会自动在两人之间转账找平。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // MARK: Salon ratio
                ratioSection
                
                // MARK: Confirm
                confirmSection
                
                // MARK: Results
                if hasGenerated {
                    resultSection
                }
            }
            .padding()
        }
        .navigationTitle("营收分账")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadState()
        }
    }
    
    // MARK: - Persistence
    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(RevenueSplitState.self, from: data) else { return }
        partnerARevenue = state.partnerARevenue
        partnerAAdvance = state.partnerAAdvance
        partnerAReimbursement = state.partnerAReimbursement
        partnerBRevenue = state.partnerBRevenue
        partnerBAdvance = state.partnerBAdvance
        partnerBReimbursement = state.partnerBReimbursement
        operatorFees = state.operatorFees
        salonCollects = state.salonCollects
        storeActualReimbursement = state.storeActualReimbursement
        salonRatioString = state.salonRatioString
        hasGenerated = state.hasGenerated
    }
    
    private func saveState() {
        let state = RevenueSplitState(
            partnerARevenue: partnerARevenue,
            partnerAAdvance: partnerAAdvance,
            partnerAReimbursement: partnerAReimbursement,
            partnerBRevenue: partnerBRevenue,
            partnerBAdvance: partnerBAdvance,
            partnerBReimbursement: partnerBReimbursement,
            operatorFees: operatorFees,
            salonCollects: salonCollects,
            storeActualReimbursement: storeActualReimbursement,
            salonRatioString: salonRatioString,
            hasGenerated: hasGenerated
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func clearData() {
        partnerARevenue = [SplitItem(name: "营收1")]
        partnerAAdvance = [SplitItem(name: "垫付1")]
        partnerAReimbursement = [SplitItem(name: "应报1")]
        partnerBRevenue = [SplitItem(name: "营收1")]
        partnerBAdvance = [SplitItem(name: "垫付1")]
        partnerBReimbursement = [SplitItem(name: "应报1")]
        operatorFees = [
            SplitItem(name: "成本1", payer: .partnerA),
            SplitItem(name: "成本2", payer: .partnerB)
        ]
        salonCollects = [SplitItem(name: "代收1")]
        storeActualReimbursement = [SplitItem(name: "实报1")]
        salonRatioString = "30"
        hasGenerated = false
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    
    // MARK: - Sections
    private func binding(for items: Binding<[SplitItem]>, at index: Int) -> Binding<SplitItem> {
        Binding(
            get: { items.wrappedValue[index] },
            set: { items.wrappedValue[index] = $0 }
        )
    }
    
    @ViewBuilder
    private func inputSection(
        title: String,
        color: Color,
        items: Binding<[SplitItem]>,
        showNote: Bool,
        showPayer: Bool,
        defaultName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
            
            VStack(spacing: 8) {
                ForEach(Array(items.wrappedValue.enumerated()), id: \.element.id) { element in
                    SplitInputRow(
                        item: binding(for: items, at: element.offset),
                        showNote: showNote,
                        showPayer: showPayer,
                        color: color,
                        canDelete: items.wrappedValue.count > 1
                    ) {
                        items.wrappedValue.remove(at: element.offset)
                    }
                }
            }
            
            Button {
                let newIndex = items.wrappedValue.count + 1
                items.wrappedValue.append(
                    SplitItem(name: "\(defaultName)\(newIndex)", payer: .partnerA)
                )
            } label: {
                Label("添加一笔", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var ratioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("门店返款比例设置")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(salonColor)
            
            HStack(spacing: 12) {
                TextField("比例", text: $salonRatioString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(width: 80)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("% 返款给门店")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("计算逻辑")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("总营收 = 合伙人A营收 + 合伙人B营收 + 门店代收\n返款 = 总营收 × 比例\n返款后收入 = 总营收 − 返款\n【利润内成本】= 营销/运营成本 + 垫付\n净利润 = 返款后收入 − 利润内成本\n每人利润 = 净利润 ÷ 2\n【应报实销】= 各自垫付待店家报销的金额\n【店家实报】= 店家实际报销给 A/B 的金额\n最终结算 = 每人利润 + 各自垫付 + 各自垫付成本 + 各自应报\n差额 = 店家实报 − 各自应报，多拿者转给少拿者")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(4)
            }
            .padding(12)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var confirmSection: some View {
        VStack(spacing: 12) {
            Button {
                hasGenerated = true
                saveState()
            } label: {
                Text(hasGenerated ? "重新生成" : "确认生成")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            Button {
                clearData()
            } label: {
                Text("清空数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("计算结果")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                resultCard(title: "总营收（含代收）", value: totalRevenue, color: .primary)
                resultCard(title: "返款给门店", value: salonReturn, color: salonColor)
                resultCard(title: "返款后收入", value: afterSalon, color: partnerAColor)
                resultCard(title: "总运营成本", value: totalCost, color: operatorColor)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(label: "合伙人A 营收合计", value: aRev, color: partnerAColor)
                summaryRow(label: "合伙人B 营收合计", value: bRev, color: partnerBColor)
                summaryRow(label: "门店代收合计", value: salonCollect, color: salonColor)
                Divider()
                sectionLabel("利润内成本（两人分摊）", color: operatorColor)
                summaryRow(label: "营销/运营成本合计", value: operatorFeeTotal, color: operatorColor)
                summaryRow(label: "其中 合伙人A 垫付", value: operatorFeeA, color: partnerAColor)
                summaryRow(label: "其中 合伙人B 垫付", value: operatorFeeB, color: partnerBColor)
                summaryRow(label: "合伙人A 垫付合计", value: aAdv, color: partnerAColor)
                summaryRow(label: "合伙人B 垫付合计", value: bAdv, color: partnerBColor)
                Divider()
                sectionLabel("实报实销（应报 vs 店家实报）", color: reimbursementColor)
                summaryRow(label: "合伙人A 应报实销", value: aShouldReimburse, color: partnerAColor)
                summaryRow(label: "合伙人B 应报实销", value: bShouldReimburse, color: partnerBColor)
                summaryRow(label: "店家实报给 合伙人A", value: actualReimburseA, color: reimbursementColor)
                summaryRow(label: "店家实报给 合伙人B", value: actualReimburseB, color: reimbursementColor)
                Divider()
                summaryRow(label: "净利润", value: net, color: .primary)
                summaryRow(label: "每人应分利润", value: eachProfit, color: .primary)
                Divider()
                summaryRow(label: "合伙人A 最终结算", value: aFinal, color: partnerAColor, bold: true)
                summaryRow(label: "合伙人B 最终结算", value: bFinal, color: partnerBColor, bold: true)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(label: "合伙人A 自己营收", value: aRev, color: partnerAColor)
                summaryRow(label: "合伙人A 分摊返款", value: aReturnShare, color: .primary)
                summaryRow(label: "合伙人A 店家实报", value: actualReimburseA, color: reimbursementColor)
                summaryRow(label: "合伙人A 净持有", value: aNetHold, color: partnerAColor)
                summaryRow(label: "合伙人A 应得金额", value: aFinal, color: partnerAColor)
                summaryRow(label: "合伙人A 差额", value: aDiff, color: aDiff >= 0 ? partnerAColor : partnerBColor)
                Divider()
                summaryRow(label: "合伙人B 自己营收", value: bRev, color: partnerBColor)
                summaryRow(label: "合伙人B 分摊返款", value: bReturnShare, color: .primary)
                summaryRow(label: "合伙人B 店家实报", value: actualReimburseB, color: reimbursementColor)
                summaryRow(label: "合伙人B 净持有", value: bNetHold, color: partnerBColor)
                summaryRow(label: "合伙人B 应得金额", value: bFinal, color: partnerBColor)
                summaryRow(label: "合伙人B 差额", value: bDiff, color: bDiff >= 0 ? partnerBColor : partnerAColor)
                Divider()
                HStack {
                    Text(transferText)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(currency(transferAmount))
                        .font(.title3.weight(.bold))
                }
                .foregroundColor(aDiff > 0 ? partnerAColor : aDiff < 0 ? partnerBColor : .secondary)
                .padding(.top, 4)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func resultCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currency(value))
                .font(.title3.weight(.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func sectionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundColor(color)
            .padding(.top, 2)
    }
    
    private func summaryRow(label: String, value: Double, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(currency(value))
                .font(bold ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundColor(color)
        }
    }
    
    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "¥0.00"
    }
}

// MARK: - Split Input Row
struct SplitInputRow: View {
    @Binding var item: SplitItem
    let showNote: Bool
    let showPayer: Bool
    let color: Color
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("事项", text: $item.name)
                .font(.subheadline)
            if showNote {
                TextField("备注", text: $item.note)
                    .font(.caption)
                    .frame(minWidth: 40, maxWidth: 80)
            }
            if showPayer {
                Button {
                    item.payer = item.payer == .partnerA ? .partnerB : .partnerA
                } label: {
                    Text(item.payer.short)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(item.payer == .partnerA ? Color.orange : Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            TextField("金额", text: $item.amountString)
                .font(.subheadline)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 78)
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Training Materials
import UIKit
import UniformTypeIdentifiers

struct TrainingMaterialsView: View {
    @EnvironmentObject var userState: UserState
    @State private var materials: [TrainingMaterial] = []
    @State private var stores: [Store] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedCategory: TrainingMaterialCategory?
    @State private var showUploadSheet = false
    
    private var canUpload: Bool {
        userState.currentUser?.role == .superAdmin
    }
    
    private var canManage: Bool {
        userState.currentUser?.role == .superAdmin
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilterBar
                
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(groupedMaterials.keys.sorted { categorySort($0) < categorySort($1) }, id: \.self) { category in
                            Section(header: Text(category.displayName)) {
                                ForEach(groupedMaterials[category] ?? []) { material in
                                    TrainingMaterialRow(
                                        material: material,
                                        canManage: canManage,
                                        stores: stores,
                                        onUpdated: { updated in
                                            if let index = materials.firstIndex(where: { $0.id == updated.id }) {
                                                materials[index] = updated
                                            }
                                        },
                                        onDelete: {
                                            materials.removeAll { $0.id == material.id }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("培训资料")
            .toolbar {
                if canUpload {
                    Button(action: { showUploadSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadTrainingMaterialSheet(onCompleted: {
                showUploadSheet = false
                Task { await load() }
            })
        }
        .task { await load() }
    }
    
    private var groupedMaterials: [TrainingMaterialCategory: [TrainingMaterial]] {
        let filtered = selectedCategory == nil ? materials : materials.filter { $0.category == selectedCategory }
        return Dictionary(grouping: filtered, by: { $0.category })
    }
    
    private func categorySort(_ category: TrainingMaterialCategory) -> Int {
        TrainingMaterialCategory.allCases.firstIndex(of: category) ?? 99
    }
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(title: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(TrainingMaterialCategory.allCases, id: \.self) { category in
                    CategoryChip(title: category.displayName, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let materialsTask = TrainingMaterialService.shared.listMaterials()
            async let storesTask = StoreService.shared.listStores()
            materials = try await materialsTask
            stores = try await storesTask
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("[TrainingMaterials] Request cancelled")
        } catch is CancellationError {
            print("[TrainingMaterials] Load cancelled")
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                .foregroundStyle(isSelected ? .blue : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum MaterialSheet: Identifiable {
    case downloadOptions
    case share
    case preview
    case export
    case openInMenu
    case rename
    case transfer

    var id: String {
        switch self {
        case .downloadOptions: return "downloadOptions"
        case .share: return "share"
        case .preview: return "preview"
        case .export: return "export"
        case .openInMenu: return "openInMenu"
        case .rename: return "rename"
        case .transfer: return "transfer"
        }
    }
}

struct TrainingMaterialRow: View {
    let material: TrainingMaterial
    let canManage: Bool
    let stores: [Store]
    let onUpdated: (TrainingMaterial) -> Void
    let onDelete: () -> Void
    
    @State private var shareURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var downloadProgress: Double = 0
    @State private var activeSheet: MaterialSheet?
    @State private var renameTitle = ""
    @State private var renameError: String?
    @State private var isRenaming = false
    @State private var transferCategory: TrainingMaterialCategory = .general
    @State private var transferStore: Store?
    @State private var transferError: String?
    @State private var isTransferring = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: material.fileType.icon)
                .font(.title2)
                .foregroundStyle(material.category.color)
                .frame(width: 40, height: 40)
                .background(material.category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(material.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(material.fileType.displayName) · \(material.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { Task { await downloadFile() } }) {
                ZStack {
                    if isDownloading {
                        VStack(spacing: 2) {
                            ProgressView(value: downloadProgress)
                                .frame(width: 44)
                                .tint(.blue)
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isDownloading)
            
            Menu {
                Button { Task { await downloadFile() } } label: {
                    Label("下载", systemImage: "square.and.arrow.down")
                }
                Button { activeSheet = .preview } label: {
                    Label("预览", systemImage: "eye")
                }
                Button { activeSheet = .export } label: {
                    Label("保存到文件", systemImage: "folder")
                }
                Button { activeSheet = .openInMenu } label: {
                    Label("用其他应用打开", systemImage: "square.and.arrow.up")
                }
                Button { activeSheet = .share } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                if canManage {
                    Divider()
                    Button {
                        renameTitle = material.title
                        activeSheet = .rename
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button {
                        transferCategory = material.category
                        transferStore = stores.first { $0.id == material.storeId }
                        activeSheet = .transfer
                    } label: {
                        Label("转移分类", systemImage: "rectangle.2.swap")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .downloadOptions:
                downloadOptionsSheet
            case .share:
                Group {
                    if let url = shareURL {
                        ShareSheet(activityItems: [url])
                    }
                }
            case .preview:
                Group {
                    if let url = shareURL {
                        QLPreviewView(url: url)
                    }
                }
            case .export:
                Group {
                    if let url = shareURL {
                        DocumentPickerExport(url: url)
                    }
                }
            case .openInMenu:
                EmptyView()
            case .rename:
                renameSheet
            case .transfer:
                transferSheet
            }
        }
        .alert("操作失败", isPresented: .constant(downloadError != nil)) {
            Button("确定") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
        .confirmationDialog("确认删除？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { Task { await deleteMaterial() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不可恢复")
        }
        .background {
            OpenInMenuAnchor(url: $shareURL, isPresented: .init(
                get: { activeSheet == .openInMenu },
                set: { if !$0 { activeSheet = nil } }
            ))
                .frame(width: 0, height: 0)
        }
    }
    
    private func downloadFile() async {
        guard let url = URL(string: material.fileUrl) else { return }
        isDownloading = true
        downloadProgress = 0
        defer { isDownloading = false }
        do {
            let filename = material.title + "." + material.fileType.rawValue
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            let delegate = DownloadProgressDelegate(destinationURL: destination) { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                }
            }
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            let finalURL = try await delegate.downloadResult(for: task)
            session.finishTasksAndInvalidate()
            
            await MainActor.run {
                shareURL = finalURL
                activeSheet = .downloadOptions
            }
        } catch {
            await MainActor.run {
                downloadError = error.localizedDescription
            }
        }
    }
    
    private var renameSheet: some View {
        NavigationStack {
            Form {
                Section("文件名称") {
                    TextField("名称", text: $renameTitle)
                }
                if let error = renameError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { activeSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await saveRename() } }) {
                        Text(isRenaming ? "保存中" : "保存")
                    }
                    .disabled(renameTitle.isEmpty || isRenaming)
                }
            }
        }
    }
    
    private func saveRename() async {
        isRenaming = true
        renameError = nil
        do {
            let updated = try await TrainingMaterialService.shared.updateMaterial(
                id: material.id,
                data: TrainingMaterialUpdate(title: renameTitle, category: nil, version: nil, description: nil, storeId: nil)
            )
            await MainActor.run {
                isRenaming = false
                activeSheet = nil
                onUpdated(updated)
            }
        } catch {
            await MainActor.run {
                isRenaming = false
                renameError = error.localizedDescription
            }
        }
    }
    
    private var downloadOptionsSheet: some View {
        NavigationStack {
            List {
                Button {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .preview
                    }
                } label: {
                    Label("预览", systemImage: "eye")
                }
                Button {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .share
                    }
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Button {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .export
                    }
                } label: {
                    Label("保存到文件", systemImage: "folder")
                }
                Button {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .openInMenu
                    }
                } label: {
                    Label("用其他应用打开", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("已下载")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { activeSheet = nil }
                }
            }
        }
    }

    private var transferSheet: some View {
        NavigationStack {
            Form {
                Section("分类") {
                    ForEach(TrainingMaterialCategory.allCases, id: \.self) { category in
                        Button {
                            transferCategory = category
                        } label: {
                            HStack {
                                Text(category.displayName)
                                Spacer()
                                if transferCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                if transferCategory == .storeSpecific {
                    Section("指定门店") {
                        Button {
                            transferStore = nil
                        } label: {
                            HStack {
                                Text("请选择门店")
                                Spacer()
                                if transferStore == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        ForEach(stores) { store in
                            Button {
                                transferStore = store
                            } label: {
                                HStack {
                                    Text(store.name)
                                    Spacer()
                                    if transferStore?.id == store.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let error = transferError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("转移分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { activeSheet = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await saveTransfer() } }) {
                        Text(isTransferring ? "保存中" : "保存")
                    }
                    .disabled(isTransferring || (transferCategory == .storeSpecific && transferStore == nil))
                }
            }
        }
    }
    
    private func saveTransfer() async {
        isTransferring = true
        transferError = nil
        do {
            let storeIdUpdate: UUID?? = {
                switch transferCategory {
                case .storeSpecific:
                    return transferStore.map { .some($0.id) } ?? .some(nil)
                default:
                    return .some(nil)
                }
            }()
            let updated = try await TrainingMaterialService.shared.updateMaterial(
                id: material.id,
                data: TrainingMaterialUpdate(
                    title: nil,
                    category: transferCategory,
                    version: nil,
                    description: nil,
                    storeId: storeIdUpdate
                )
            )
            await MainActor.run {
                isTransferring = false
                activeSheet = nil
                onUpdated(updated)
            }
        } catch {
            await MainActor.run {
                isTransferring = false
                transferError = error.localizedDescription
            }
        }
    }
    
    private func deleteMaterial() async {
        do {
            try await TrainingMaterialService.shared.deleteMaterial(id: material.id)
            await MainActor.run {
                onDelete()
            }
        } catch {
            await MainActor.run {
                downloadError = error.localizedDescription
            }
        }
    }
}

// 用于触发 UIDocumentInteractionController 的 OpenInMenu 的透明锚点
struct OpenInMenuAnchor: UIViewControllerRepresentable {
    @Binding var url: URL?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, let url = url else { return }
        let doc = UIDocumentInteractionController(url: url)
        doc.delegate = context.coordinator
        context.coordinator.controller = doc
        doc.presentOpenInMenu(from: uiViewController.view.bounds, in: uiViewController.view, animated: true)
        DispatchQueue.main.async { isPresented = false }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIDocumentInteractionControllerDelegate {
        weak var controller: UIDocumentInteractionController?
    }
}

struct UploadTrainingMaterialSheet: View {
    @EnvironmentObject var userState: UserState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: TrainingMaterialCategory = .general
    @State private var selectedStore: Store?
    @State private var stores: [Store] = []
    @State private var pickedURL: URL?
    @State private var pickedData: Data?
    @State private var fileName = ""
    @State private var fileType: FileType = .pdf
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    
    let onCompleted: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("分类") {
                    ForEach(TrainingMaterialCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Text(category.displayName)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }

                    if selectedCategory == .storeSpecific {
                        Button {
                            selectedStore = nil
                        } label: {
                            HStack {
                                Text("请选择门店")
                                Spacer()
                                if selectedStore == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        ForEach(stores) { store in
                            Button {
                                selectedStore = store
                            } label: {
                                HStack {
                                    Text(store.name)
                                    Spacer()
                                    if selectedStore?.id == store.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("文件") {
                    Button(action: { showFileImporter = true }) {
                        HStack {
                            Text(pickedURL == nil ? "选择 PPT/PDF 文件" : fileName)
                                .foregroundStyle(pickedURL == nil ? .blue : .primary)
                            Spacer()
                            if pickedURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    if let data = pickedData {
                        Text("已读取 \(data.count) 字节")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if isUploading {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("上传中 \(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            ProgressView(value: uploadProgress)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("上传培训资料")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, UTType(filenameExtension: "pptx")!, UTType(filenameExtension: "ppt")!]) { result in
                switch result {
                case .success(let url):
                    let didStart = url.startAccessingSecurityScopedResource()
                    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        self.pickedURL = url
                        self.pickedData = data
                        self.fileName = url.deletingPathExtension().lastPathComponent
                        self.fileType = inferFileType(from: url.pathExtension.lowercased())
                        self.errorMessage = nil
                    } catch {
                        self.errorMessage = "读取文件失败: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    self.errorMessage = "选择文件失败: \(error.localizedDescription)"
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await upload() } }) {
                        Text(isUploading ? "上传中" : "上传")
                    }
                    .disabled(pickedData == nil || isUploading || (selectedCategory == .storeSpecific && selectedStore == nil))
                }
            }
        }
        .task { await loadStores() }
    }
    
    private func loadStores() async {
        do {
            stores = try await StoreService.shared.listStores()
        } catch {
            print("load stores failed", error)
        }
    }
    
    private func upload() async {
        guard let data = pickedData else { return }
        isUploading = true
        uploadProgress = 0
        errorMessage = nil
        do {
            let ext = fileType.rawValue
            let key = "training/\(UUID().uuidString).\(ext)"
            let fileUrl = try await TencentCOSUploadService.uploadFile(data, key: key, contentType: fileType.mimeType) { progress in
                DispatchQueue.main.async {
                    self.uploadProgress = progress
                }
            }
            let insert = TrainingMaterialInsert(
                title: fileName,
                version: "1.0",
                fileUrl: fileUrl,
                fileType: fileType.rawValue,
                category: selectedCategory,
                storeId: selectedStore?.id,
                description: nil
            )
            _ = try await TrainingMaterialService.shared.createMaterial(insert)
            await MainActor.run {
                isUploading = false
                onCompleted()
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func inferFileType(from ext: String) -> FileType {
        switch ext {
        case "pdf": return .pdf
        case "ppt": return .ppt
        case "pptx": return .pptx
        default: return .pdf
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let supportedTypes: [UTType]
    let onPick: (URL, Data) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL, Data) -> Void
        init(onPick: @escaping (URL, Data) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                onPick(url, data)
            } catch {
                print("read file error", error)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Save to Files
struct DocumentPickerExport: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

// MARK: - QuickLook Preview
struct QLPreviewView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL as QLPreviewItem
        }
    }
}

// MARK: - Download Progress Delegate
final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let destinationURL: URL
    private let onProgress: (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    
    init(destinationURL: URL, onProgress: @escaping (Double) -> Void) {
        self.destinationURL = destinationURL
        self.onProgress = onProgress
    }
    
    func downloadResult(for task: URLSessionDownloadTask) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: location, to: destinationURL)
            continuation?.resume(returning: destinationURL)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - Store Rebates
struct StoreRebatesView: View {
    @EnvironmentObject var userState: UserState
    let stores: [Store]
    
    @State private var histories: [UUID: [StoreRebatePeriod]] = [:]
    @State private var activePeriods: [UUID: StoreRebatePeriod] = [:]
    @State private var isLoading = false
    
    var allHistories: [StoreRebatePeriod] {
        histories.values.flatMap { $0 }
    }
    
    var monthlyTotal: Double {
        allHistories
            .filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentMonth ?? false) }
            .reduce(0) { $0 + ($1.confirmedRebate ?? 0) }
    }
    
    var monthlyCount: Int {
        allHistories
            .filter { $0.status == "confirmed" && ($0.confirmedAt?.isInCurrentMonth ?? false) }
            .count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(
                    title: "门店返利",
                    value: "¥\(Int(monthlyTotal))",
                    subtitle: "本月已确认 \(monthlyCount) 笔"
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("门店返利汇总")
                        .font(.headline)
                    
                    if isLoading && histories.isEmpty {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .frame(height: 64)
                                .shimmering()
                        }
                    } else if stores.isEmpty {
                        EmptyStateView(icon: "building.2", title: "暂无门店", subtitle: "请先创建门店")
                    } else {
                        ForEach(stores) { store in
                            let active = activePeriods[store.id]
                            let history = histories[store.id] ?? []
                            NavigationLink {
                                StoreRebateView(store: store)
                                    .environmentObject(userState)
                            } label: {
                                StoreRebateOverviewRow(store: store, active: active, history: history)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("门店返利")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadData() }
    }
    
    private func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        for store in stores {
            do {
                async let activeTask = StoreRebateService.shared.getActiveRebate(storeId: store.id.uuidString)
                async let historyTask = StoreRebateService.shared.getRebateHistory(storeId: store.id.uuidString)
                let (active, history) = try await (activeTask, historyTask)
                await MainActor.run {
                    if let active = active {
                        activePeriods[store.id] = active
                    }
                    histories[store.id] = history
                }
            } catch {
                print("[StoreRebates] load store \(store.id) error: \(error)")
            }
        }
    }
}

struct StoreRebateOverviewRow: View {
    let store: Store
    let active: StoreRebatePeriod?
    let history: [StoreRebatePeriod]
    
    private var confirmedTotal: Double {
        history
            .filter { $0.status == "confirmed" }
            .reduce(0) { $0 + ($1.confirmedRebate ?? 0) }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.subheadline.weight(.medium))
                Text(active != nil ? "进行中周期" : "无进行中周期")
                    .font(.caption)
                    .foregroundStyle(active != nil ? .green : .secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("历史已确认 ¥\(Int(confirmedTotal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let active = active, let computed = active.autoRebate {
                    Text("当前汇算 ¥\(Int(computed))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

