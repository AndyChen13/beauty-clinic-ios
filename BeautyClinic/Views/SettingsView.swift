//  Views/SettingsView.swift
//  BeautyClinic
//

import SwiftUI
import Supabase

struct SettingsView: View {
    @State private var showLogoutAlert = false
    @State private var userName = "管理员"
    @State private var userEmail = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        AvatarView(name: userName, size: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.headline)
                            Text("超级管理员")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // App Info
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
                
                // About
                Section("关于") {
                    NavigationLink("功能介绍") {
                        AboutView()
                    }
                }
                
                // Logout
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
    
    private func logout() async {
        do {
            try await supabase.auth.signOut()
            // App will detect session change and show login
        } catch {
            print("Logout error: \(error)")
        }
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

struct InfoBlock: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SettingsView()
}
