//  Views/MainTabView.swift
//  BeautyClinic
//

import SwiftUI

struct MainTabView: View {
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
        }
    }
}

#Preview {
    MainTabView()
}
