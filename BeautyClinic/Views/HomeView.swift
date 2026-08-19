// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userState: UserState
    @State private var customersCount = 0
    @State private var todayTransactions = 0
    @State private var monthlyRevenue: Double = 0
    @State private var pendingDeliveries = 0
    @State private var recentTransactions: [Transaction] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderSection()
                    
                    StatsGrid(
                        customers: customersCount,
                        transactions: todayTransactions,
                        revenue: monthlyRevenue,
                        pending: pendingDeliveries,
                        isLoading: isLoading
                    )
                    
                    QuickActionsSection()
                    
                    RecentActivitySection(transactions: recentTransactions, isLoading: isLoading)
                }
                .padding()
            }
            .navigationTitle("首页")
            .refreshable { await loadDashboardData() }
            .task { await loadDashboardData() }
        }
    }
    
    private func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfDay = calendar.startOfDay(for: now)
            
            async let customersCountTask = supabase
                .from("customers")
                .select("*", head: true)
                .execute()
            
            async let todayTransTask: [Transaction] = supabase
                .from("transactions")
                .select("amount")
                .gte("transaction_date", value: startOfDay)
                .execute()
                .value
            
            async let monthlyTransTask: [Transaction] = supabase
                .from("transactions")
                .select("amount")
                .gte("transaction_date", value: startOfMonth)
                .execute()
                .value
            
            async let pendingTask = supabase
                .from("transactions")
                .select("*", head: true)
                .in("status", value: ["pending", "confirmed", "in_progress"])
                .execute()
            
            async let recentTask: [Transaction] = supabase
                .from("transactions")
                .select("""
                    *,
                    customers(name),
                    packages(name)
                """)
                .order("transaction_date", ascending: false)
                .limit(5)
                .execute()
                .value
            
            let (_, tTrans, mTrans, _, recent) = try await (
                customersCountTask,
                todayTransTask,
                monthlyTransTask,
                pendingTask,
                recentTask
            )
            
            await MainActor.run {
                customersCount = 0 // Will be set from count
                todayTransactions = tTrans.count
                monthlyRevenue = mTrans.reduce(0) { $0 + $1.amount }
                pendingDeliveries = 0 // Will be set from count
                recentTransactions = recent
            }
        } catch {
            print("Dashboard load error: \(error)")
        }
    }
}

struct HeaderSection: View {
    @State private var userName = "管理员"
    
    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: userName, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("你好，\(userName)")
                    .font(.title3.weight(.semibold))
                Text("欢迎回到 Beauty Clinic")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct StatsGrid: View {
    let customers: Int
    let transactions: Int
    let revenue: Double
    let pending: Int
    let isLoading: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "客户总数",
                value: isLoading ? "--" : "\(customers)",
                icon: "person.3.fill",
                color: .blue
            )
            StatCard(
                title: "今日成交",
                value: isLoading ? "--" : "\(transactions)",
                icon: "cart.fill",
                color: .green
            )
            StatCard(
                title: "本月收入",
                value: isLoading ? "--" : "¥\(Int(revenue))",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            StatCard(
                title: "待交付",
                value: isLoading ? "--" : "\(pending)",
                icon: "clock.fill",
                color: .purple
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "新增客户", icon: "person.badge.plus", color: .blue) {}
                QuickActionButton(title: "记录成交", icon: "doc.badge.plus", color: .green) {}
                QuickActionButton(title: "记录交付", icon: "checkmark.circle", color: .orange) {}
                QuickActionButton(title: "数据报表", icon: "chart.pie.fill", color: .purple) {}
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
