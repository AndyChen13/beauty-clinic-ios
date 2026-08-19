import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            CustomerListView()
                .tabItem {
                    Label("客户管理", systemImage: "person.crop.circle")
                }
            
            PackageListView()
                .tabItem {
                    Label("服务套餐", systemImage: "sparkles") // 使用 Sparkle 代替医美图标
                }
            
            StoreListView()
                .tabItem {
                    Label("门店管理", systemImage: "building.fill")
                }
            
            TransactionListView()
                .tabItem {
                    Label("成交记录", systemImage: "card.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
}