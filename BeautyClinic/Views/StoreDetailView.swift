// Views/StoreDetailView.swift
import SwiftUI

struct StoreDetailView: View {
    let store: Store
    let users: [User]
    @EnvironmentObject var userState: UserState
    
    private var managerName: String {
        if let managerId = store.managerId,
           let user = users.first(where: { $0.id == managerId }) {
            return user.name
        }
        return "未指定"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 16) {
                    StoreAvatarView(imageUrl: store.imageUrl, status: store.status, size: 80)
                    
                    Text(store.name)
                        .font(.title2.weight(.bold))
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(store.status.color)
                            .frame(width: 8, height: 8)
                        Text(store.status.displayName)
                            .font(.subheadline)
                            .foregroundStyle(store.status.color)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("门店信息")
                        .font(.headline)
                    
                    if let address = store.address, !address.isEmpty {
                        InfoRow(label: "地址", value: address)
                        Divider()
                    }
                    
                    if let phone = store.phone, !phone.isEmpty {
                        InfoRow(label: "联系电话", value: phone)
                        Divider()
                    }
                    
                    InfoRow(label: "负责人", value: managerName)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Meta Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("其他信息")
                        .font(.headline)
                    
                    if let createdAt = store.createdAt {
                        InfoRow(label: "创建时间", value: createdAt.formatted())
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StoreDetailView(
            store: Store(
                id: UUID(),
                name: "测试门店",
                address: "上海市静安区",
                phone: "13800138000",
                status: .active,
                managerId: nil,
                imageUrl: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            users: []
        )
        .environmentObject(UserState())
    }
}
