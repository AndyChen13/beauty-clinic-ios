// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userState: UserState
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        if let avatarUrl = userState.currentUser?.avatarUrl,
                           let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                AvatarView(name: userName, size: 60)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            AvatarView(name: userName, size: 60)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.headline)
                            Text(roleDisplay)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let storeId = userState.currentUser?.storeId {
                                Text("门店ID: \(storeId.uuidString.prefix(8))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("应用信息") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("构建号")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("关于") {
                    NavigationLink("功能介绍") {
                        AboutView()
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    Task { await logout() }
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
        }
    }
    
    private var userName: String {
        userState.currentUser?.name ?? "用户"
    }
    
    private var roleDisplay: String {
        userState.currentUser?.role.displayName ?? "员工"
    }
    
    private func logout() async {
        await userState.signOut()
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundColor(.accentColor)
                        )
                    Text("Beauty Clinic")
                        .font(.title2.weight(.bold))
                    Text("医美内部管理系统")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    InfoBlock(title: "功能介绍", content: "本应用为医美服务公司内部管理工具，提供客户管理、套餐管理、门店管理和成交记录等功能。帮助门店高效管理日常运营。")
                    
                    InfoBlock(title: "技术栈", content: "• SwiftUI 用户界面\n• Supabase 后端服务\n• PostgreSQL 数据库\n• iOS 17+")
                    
                    InfoBlock(title: "联系我们", content: "如有问题或建议，请联系技术支持团队。")
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(UserState())
}
