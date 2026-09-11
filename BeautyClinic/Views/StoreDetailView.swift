// Views/StoreDetailView.swift
import SwiftUI

struct StoreDetailView: View {
    @State var store: Store
    let users: [User]
    @EnvironmentObject var userState: UserState
    @State private var showingEditSheet = false
    @State private var showingRebateSheet = false
    
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
                    HStack {
                        Text("其他信息")
                            .font(.headline)
                        
                        Spacer()
                        
                        if userState.isAdmin {
                            Button {
                                showingEditSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("编辑")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("门店简介")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let introduction = store.introduction, !introduction.isEmpty {
                            Text(introduction)
                                .font(.subheadline)
                        } else {
                            Text("暂无简介，点击右上角编辑添加")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("门店备注")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let notes = store.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                        } else {
                            Text("暂无备注，点击右上角编辑添加")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("推荐酒店")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let recommendedHotel = store.recommendedHotel, !recommendedHotel.isEmpty {
                            Text(recommendedHotel)
                                .font(.subheadline)
                        } else {
                            Text("暂无推荐酒店，点击右上角编辑添加")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

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
        .toolbar {
            if userState.isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("返利") {
                        showingRebateSheet = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            StoreEditView(mode: .edit(store), users: users) { updatedStore in
                store = updatedStore
            }
            .environmentObject(userState)
        }
        .sheet(isPresented: $showingRebateSheet) {
            NavigationStack {
                StoreRebateView(store: store)
                    .environmentObject(userState)
            }
        }
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
                notes: "测试备注",
                introduction: "测试简介",
                recommendedHotel: nil,
                createdAt: Date(),
                updatedAt: nil
            ),
            users: []
        )
        .environmentObject(UserState())
    }
}
