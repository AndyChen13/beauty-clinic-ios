import SwiftUI

struct HomeView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var customersCount = 0
    @State private var pendingAppointments = 0
    @State private var monthlyRevenue = 0.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderSection()
                    
                    StatsGrid()
                        .padding(.top, 8)
                    
                    RecentActivity()
                        .padding(.top, 8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("首页")
        }
        .onAppear { loadDashboardData() }
    }
    
    private func loadDashboardData() {
        // TODO: Implement data loading
    }
}

struct HeaderSection: View {
    @State private var userName = "管理员"
    
    var body: some View {
        HStack {
            AvatarView()
            VStack(alignment: .leading, spacing: 4) {
                Text("你好，\(userName)")
                    .font(.headline)
                Text("欢迎回到 Beauty Clinic")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct AvatarView: View {
    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: 48, height: 48)
            .overlay(
                Text("管")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.blue)
            )
    }
}

struct StatsGrid: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                StatCard(title: "客户总数", value: "1,234", icon: "person.3")
                StatCard(title: "待处理预约", value: "24", icon: "clock")
                StatCard(title: "月收入", value: "¥87,650", icon: "dollarsign.circle")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RecentActivity: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近活动")
                .font(.headline)
            
            ForEach(0..<5) { i in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("张女士 - 预约水光针")
                            .font(.subheadline)
                        Text("今天 14:00 · 门店A")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}