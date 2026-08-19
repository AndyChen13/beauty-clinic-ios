import SwiftUI

struct SettingsView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var showLogoutAlert = false
    @State private var userName = "管理员"
    
    var body: some View {
        Form {
            Section("账户信息") {
                HStack {
                    AvatarView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userName)
                            .font(.headline)
                        Text("超级管理员")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("应用设置") {
                NavigationLink("通知设置") { EmptyView() }
                NavigationLink("关于本应用") { AboutView() }
            }
            
            Section("退出登录") {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Text("退出登录")
                }
            }
        }
        .navigationTitle("设置")
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                logout()
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
    }
    
    private func logout() {
        Task {
            try? await supabaseClient?.auth.signOut()
        }
    }
}

struct AboutView: View {
    var body: some View {
        Form {
            Section("应用信息") {
                Text("Beauty Clinic iOS")
                    .font(.headline)
                Text("Version 1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            Section("功能介绍") {
                Text("本应用为医美服务公司内部管理工具，提供客户管理、套餐管理、门店管理和成交记录等功能。")
            }
            
            Section("技术栈") {
                Text("• SwiftUI\n• SwiftData\n• Supabase (PostgreSQL)\n• iOS 17+")
                    .multilineTextAlignment(.leading)
            }
        }
        .navigationTitle("关于")
    }
}

#Preview {
    SettingsView()
}