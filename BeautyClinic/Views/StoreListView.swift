// Views/StoreListView.swift
import SwiftUI
import PhotosUI

struct StoreListView: View {
    @EnvironmentObject var userState: UserState
    @State private var stores: [Store] = []
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var showingDeleteRequest = false
    @State private var storeToDelete: Store?
    @State private var deleteReason = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && stores.isEmpty {
                    List {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(height: 80)
                                .shimmering()
                        }
                    }
                    .listStyle(.plain)
                } else if stores.isEmpty {
                    EmptyStateView(
                        icon: "building.2",
                        title: "暂无门店",
                        subtitle: "点击右上角添加门店"
                    )
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(stores) { store in
                            NavigationLink {
                                StoreDetailView(store: store, users: users)
                                    .environmentObject(userState)
                            } label: {
                                StoreRow(store: store, users: users)
                            }
                        }
                        .onDelete(perform: deleteStore)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("门店管理")
            .toolbar {
                if userState.isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                StoreEditView(mode: .create, users: users) { newStore in
                    stores.append(newStore)
                }
            }
            .task { await loadData() }
            .refreshable { await loadData() }
            .sheet(isPresented: $showingDeleteRequest) {
                DeleteRequestSheet(
                    itemName: storeToDelete?.name ?? "",
                    reason: $deleteReason,
                    onSubmit: submitDeleteRequest
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let storesTask: [Store] = supabase
                .from("stores")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            async let usersTask: [User] = supabase
                .from("users")
                .select()
                .execute()
                .value
            
            let (s, u) = try await (storesTask, usersTask)
            stores = s
            users = u
        } catch {
            print("Error loading stores: \(error)")
        }
    }
    
    private func deleteStore(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let store = stores[index]
        
        if userState.isAdmin {
            Task {
                do {
                    _ = try await supabase
                        .from("stores")
                        .delete()
                        .eq("id", value: store.id)
                        .execute()
                    await MainActor.run {
                        stores.remove(at: index)
                    }
                } catch {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        } else {
            storeToDelete = store
            showingDeleteRequest = true
        }
    }
    
    private func submitDeleteRequest() {
        guard let store = storeToDelete else { return }
        Task {
            do {
                let request = DeletionRequestInsert(
                    requesterId: userState.currentUser?.id ?? UUID(),
                    targetType: "store",
                    targetId: store.id,
                    targetName: store.name,
                    reason: deleteReason.isEmpty ? nil : deleteReason
                )
                _ = try await supabase
                    .from("deletion_requests")
                    .insert(request)
                    .execute()
                await MainActor.run {
                    deleteReason = ""
                    storeToDelete = nil
                }
            } catch {
                errorMessage = "提交失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Store Row
struct StoreRow: View {
    let store: Store
    let users: [User]
    
    private var managerName: String {
        if let managerId = store.managerId,
           let user = users.first(where: { $0.id == managerId }) {
            return user.name
        }
        return "未指定"
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 门店头像
            StoreAvatarView(imageUrl: store.imageUrl, status: store.status)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.subheadline.weight(.medium))
                
                if let address = store.address, !address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(address)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.status.color)
                        .frame(width: 6, height: 6)
                    Text(store.status.displayName)
                        .font(.caption2)
                        .foregroundStyle(store.status.color)
                    
                    Text("负责人: \(managerName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Store Avatar View
struct StoreAvatarView: View {
    let imageUrl: String?
    let status: StoreStatus
    var size: CGFloat = 48
    let imageUrl: String?
    let status: StoreStatus
    let size: CGFloat = 48
    
    var body: some View {
        if let urlString = imageUrl,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    defaultAvatar
                @unknown default:
                    defaultAvatar
                }
            }
        } else {
            defaultAvatar
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(status.color.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "building.2")
                    .font(.system(size: 18))
                    .foregroundColor(status.color)
            )
    }
}

// MARK: - Edit Mode
enum StoreEditMode {
    case create
    case edit(Store)
}

// MARK: - Store Edit View
struct StoreEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: StoreEditMode
    let users: [User]
    let onSave: (Store) -> Void
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var status = StoreStatus.active
    @State private var managerId: UUID?
    @State private var imageUrl: String?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Photo picker states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploadingImage = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("门店名称 *", text: $name)
                    TextField("地址", text: $address, axis: .vertical)
                        .lineLimit(2...3)
                    TextField("联系电话", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("负责人") {
                    if users.isEmpty {
                        Text("暂无可选负责人")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择负责人", selection: $managerId) {
                            Text("不指定").tag(nil as UUID?)
                            ForEach(users) { user in
                                Text(user.name).tag(user.id as UUID?)
                            }
                        }
                    }
                }
                
                Section("状态") {
                    Picker("运营状态", selection: $status) {
                        ForEach(StoreStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("门店头像") {
                    VStack(spacing: 16) {
                        // Preview
                        if let imageData = selectedImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let urlString = imageUrl,
                                  let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                default:
                                    placeholder
                                }
                            }
                        } else {
                            placeholder
                        }
                        
                        // Photo Picker
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 6) {
                                if isUploadingImage {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "photo")
                                    Text(selectedImageData != nil || imageUrl != nil ? "更换照片" : "选择照片")
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.accentColor)
                        }
                        .disabled(isUploadingImage)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveStore) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(name.isEmpty || isSaving || isUploadingImage)
                }
            }
            .alert("保存失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadAndUploadPhoto(item: newItem)
                }
            }
        }
    }
    
    private var modeTitle: String {
        switch mode {
        case .create: return "添加门店"
        case .edit: return "编辑门店"
        }
    }
    
    private var placeholder: some View {
        Circle()
            .fill(status.color.opacity(0.15))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "building.2")
                    .font(.system(size: 28))
                    .foregroundColor(status.color)
            )
    }
    
    // MARK: - Photo Loading & Upload
    private func loadAndUploadPhoto(item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "Photo", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法加载照片"])
            }
            
            // Compress image
            guard let compressedData = compressImage(data) else {
                throw NSError(domain: "Photo", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片压缩失败"])
            }
            
            await MainActor.run {
                selectedImageData = compressedData
            }
            
            // Upload to Supabase Storage
            let fileName = "store-\(UUID().uuidString).jpg"
            let response = try await supabase.storage
                .from("store-images")
                .upload(fileName, data: compressedData)
            
            // Build public URL
            let publicURL = try supabase.storage
                .from("store-images")
                .getPublicURL(path: response.path)
            
            await MainActor.run {
                imageUrl = publicURL.absoluteString
            }
        } catch {
            await MainActor.run {
                errorMessage = "上传失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Image Compression
    private func compressImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxSize: CGFloat = 512
        let size = image.size
        let ratio = size.width / size.height
        
        var newSize: CGSize
        if ratio > 1 {
            newSize = CGSize(width: maxSize, height: maxSize / ratio)
        } else {
            newSize = CGSize(width: maxSize * ratio, height: maxSize)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Target ~200KB
        var quality: CGFloat = 0.8
        var compressedData = resized.jpegData(compressionQuality: quality)
        
        while let data = compressedData, data.count > 200_000, quality > 0.3 {
            quality -= 0.1
            compressedData = resized.jpegData(compressionQuality: quality)
        }
        
        return compressedData
    }
    
    // MARK: - Save Store
    private func saveStore() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        Task {
            do {
                let storeData = StoreInsert(
                    name: name,
                    address: address.isEmpty ? nil : address,
                    phone: phone.isEmpty ? nil : phone,
                    status: status,
                    managerId: managerId,
                    imageUrl: imageUrl
                )
                
                let created: [Store] = try await supabase
                    .from("stores")
                    .insert(storeData)
                    .select()
                    .execute()
                    .value
                
                onSave(created.first!)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    StoreListView()
        .environmentObject(UserState())
}
