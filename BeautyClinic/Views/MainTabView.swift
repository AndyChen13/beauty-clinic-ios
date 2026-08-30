import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var userState: UserState
    @State private var selectedTab = 0
    
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
    }
}

#Preview {
    MainTabView()
        .environmentObject(UserState())
}
