import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var userState: UserState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showPendingAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            CustomerListView()
                .tabItem {
                    Label("客户", systemImage: "person.2.fill")
                }
                .tag(1)
            
            PackageListView()
                .tabItem {
                    Label("套餐", systemImage: "sparkles")
                }
                .tag(2)
            
            StoreListView()
                .tabItem {
                    Label("门店", systemImage: "building.2.fill")
                }
                .tag(3)
            
            TransactionListView()
                .tabItem {
                    Label("成交", systemImage: "doc.text.fill")
                }
                .tag(4)
            
            TrainingMaterialsView()
                .tabItem {
                    Label("培训", systemImage: "folder.fill.badge.person.crop")
                }
                .tag(5)
            
            if userState.currentUser?.isSuperAdmin == true {
                UserManagementView()
                    .tabItem {
                        Label("用户", systemImage: "person.badge.key.fill")
                    }
                    .tag(6)
                
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(7)
            } else {
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(6)
            }
        }
        .environmentObject(userState)
        .onAppear {
            Task {
                await userState.checkPendingApprovals()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await userState.checkPendingApprovals()
                }
            }
        }
        .onChange(of: userState.pendingUserCount) { _, newValue in
            if newValue > 0 {
                showPendingAlert = true
            }
        }
        .alert("新用户注册待审批", isPresented: $showPendingAlert) {
            Button("去审批") {
                selectedTab = userState.currentUser?.isSuperAdmin == true ? 7 : 6
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 设置页面内再导航到 UserApprovalView 由用户手动操作
                }
            }
            Button("稍后", role: .cancel) { }
        } message: {
            Text("有 \(userState.pendingUserCount) 位新注册用户等待超级管理员审批")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(UserState())
}
