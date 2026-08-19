//  Views/HomeView.swift
//  BeautyClinic
//

import SwiftUI

struct HomeView: View {
    @State private var customersCount = 0
    @State private var todayAppointments = 0
    @State private var monthlyRevenue: Double = 0
    @State private var isLoading = true
    @State private var recentTransactions: [Transaction] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HeaderSection()
                    
                    // Stats
                    StatsGrid(
                        customers: customersCount,
                        appointments: todayAppointments,
                        revenue: monthlyRevenue,
                        isLoading: isLoading
                    )
                    
                    // Quick Actions
                    QuickActionsSection()
                    
                    // Recent Activity
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
            async let customersTask = supabase.from("customers")
                .select("count", head: true)
                .execute()
            
            async let transactionsTask = supabase.from("transactions")
                .select("""
                    *,
                    customers(name),
                    packages(name)
                """)
                .order("transaction_date", ascending: false)
                .limit(5)
                .execute()
                .value as [Transaction]
            
            let _ = try await customersTask
            let transactions = try await transactionsTask
            
            await MainActor.run {
                recentTransactions = transactions
                customersCount = 0 // Will be populated from count response
            }
            
        } catch {
            print("Dashboard load error: \(error)")
        }
    }
}

// MARK: - Subviews

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
    let appointments: Int
    let revenue: Double
    let isLoading: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
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
                title: "今日预约",
                value: isLoading ? "--" : "\(appointments)",
                icon: "calendar.badge.clock",
                color: .orange
            )
            StatCard(
                title: "本月收入",
                value: isLoading ? "--" : "¥\(Int(revenue))",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
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
                QuickActionButton(title: "预约管理", icon: "calendar.badge.plus", color: .orange) {}
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
                Text(transaction.status.displayName)
                    .font(.caption2)
                    .foregroundStyle(transaction.status.color)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

#Preview {
    HomeView()
}
