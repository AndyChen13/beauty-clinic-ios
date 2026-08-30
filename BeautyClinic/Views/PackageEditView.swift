//  BeautyManager

import SwiftUI
import PhotosUI

enum PackageEditMode {
    case create
    case edit(ServicePackage)
}

struct PackageEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userState: UserState

    let mode: PackageEditMode
    let onSave: (ServicePackage) -> Void

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var selectedCategory: PackageCategory = .face
    @State private var price = ""
    @State private var durationMinutes = ""
    @State private var totalSessions = ""
    @State private var imageUrl = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploadingImage = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "编辑套餐" : "新增套餐"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("套餐名称 *", text: $name)

                    Picker("分类", selection: $selectedCategory) {
                        ForEach(PackageCategory.allCases.filter { $0 != .training }, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }

                    TextField("价格 *", text: $price)
                        .keyboardType(.decimalPad)

                    TextField("单次时长（分钟）", text: $durationMinutes)
                        .keyboardType(.numberPad)

                    TextField("总次数 *", text: $totalSessions)
                        .keyboardType(.numberPad)

                    Toggle("上架", isOn: $isActive)
                }

                Section("图片") {
                    VStack(spacing: 16) {
                        if let imageData = selectedImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if !imageUrl.isEmpty,
                                  let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                default:
                                    placeholder
                                }
                            }
                        } else {
                            placeholder
                        }
                        
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
                                    Text(selectedImageData != nil || !imageUrl.isEmpty ? "更换照片" : "从图库选择照片")
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

                Section("描述") {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(isSaving || !isFormValid)
                }
            }
            .alert("错误", isPresented: $showError) {
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
            .onAppear { loadExistingData() }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty
        && Double(price) != nil
        && Int(totalSessions) != nil
        && (durationMinutes.isEmpty || Int(durationMinutes) != nil)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            )
    }

    private func loadExistingData() {
        if case .edit(let package) = mode {
            name = package.name
            descriptionText = package.description ?? ""
            selectedCategory = package.category
            price = String(format: "%.2f", package.price)
            durationMinutes = String(package.durationMinutes)
            totalSessions = String(package.totalSessions)
            imageUrl = package.imageUrl ?? ""
            isActive = package.isActive
        }
    }

    private func loadAndUploadPhoto(item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "Photo", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法加载照片"])
            }

            guard let compressedData = compressImage(data) else {
                throw NSError(domain: "Photo", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片压缩失败"])
            }

            await MainActor.run {
                selectedImageData = compressedData
            }

            let fileName = "package-\(UUID().uuidString).jpg"
            let publicURL = try await TencentCOSUploadService.uploadImage(compressedData, key: fileName)

            await MainActor.run {
                imageUrl = publicURL
            }
        } catch {
            await MainActor.run {
                errorMessage = "上传失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }

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

        var quality: CGFloat = 0.8
        var compressedData = resized.jpegData(compressionQuality: quality)

        while let data = compressedData, data.count > 200_000, quality > 0.3 {
            quality -= 0.1
            compressedData = resized.jpegData(compressionQuality: quality)
        }

        return compressedData
    }

    private func save() {
        guard let priceValue = Double(price),
              let totalSessionsValue = Int(totalSessions) else {
            errorMessage = "请填写有效的价格和次数"
            showError = true
            return
        }

        let durationValue = Int(durationMinutes) ?? 0

        let insert = ServicePackageInsert(
            name: name,
            description: descriptionText.isEmpty ? nil : descriptionText,
            category: selectedCategory,
            price: priceValue,
            durationMinutes: durationValue,
            totalSessions: totalSessionsValue,
            imageUrl: imageUrl.isEmpty ? nil : imageUrl,
            trainingMaterials: nil
        )

        isSaving = true
        Task {
            do {
                let package: ServicePackage
                switch mode {
                case .create:
                    package = try await PackageService.shared.createPackage(insert)
                case .edit(let existing):
                    package = try await PackageService.shared.updatePackage(id: existing.id, insert: insert)
                }
                await MainActor.run {
                    isSaving = false
                    onSave(package)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存失败: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
