// Views/ServiceRecordDetailView.swift
import SwiftUI
import Photos

struct ServiceRecordDetailView: View {
    let sourceRecord: ServiceRecord
    let customer: Customer
    let transactions: [Transaction]
    var onDelete: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var displayRecord: ServiceRecord
    @State private var fullPhotoURL: URL?
    @State private var showFirstConfirm = false
    @State private var showSecondConfirm = false
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingEditSheet = false
    
    init(record: ServiceRecord, customer: Customer, transactions: [Transaction], onDelete: (() -> Void)? = nil, onSave: (() -> Void)? = nil) {
        self.sourceRecord = record
        self.customer = customer
        self.transactions = transactions
        self.onDelete = onDelete
        self.onSave = onSave
        _displayRecord = State(initialValue: record)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                        Text(displayRecord.serviceDate.formatted(date: .long, time: .shortened))
                            .font(.headline)
                        Spacer()
                        if let branch = TransactionBranch(rawValue: displayRecord.branch) {
                            Text(branch.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(branch.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(branch.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if displayRecord.extraPayment > 0 {
                        HStack {
                            Image(systemName: "yensign.circle.fill")
                                .foregroundColor(.green)
                            Text("额外付款: ¥\(String(format: "%.2f", displayRecord.extraPayment))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        
                        if let note = displayRecord.extraPaymentNote, !note.isEmpty {
                            Text("备注: \(note)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Operator Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("操作人信息")
                        .font(.headline)
                    
                    if let name = displayRecord.operatorName, !name.isEmpty {
                        InfoRow(label: "姓名", value: name)
                    }
                    if let phone = displayRecord.operatorPhone, !phone.isEmpty {
                        Divider()
                        InfoRow(label: "联系方式", value: phone)
                    }
                    if let part = displayRecord.bodyPart, !part.isEmpty {
                        Divider()
                        InfoRow(label: "操作部位", value: part)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Sessions
                VStack(alignment: .leading, spacing: 12) {
                    Text("次数记录")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(displayRecord.sessionsUsed)")
                                .font(.title3.weight(.bold))
                            Text("本次消耗")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let remaining = displayRecord.remainingSessions {
                            VStack(spacing: 4) {
                                Text("\(remaining)")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(remaining <= 1 ? .orange : .primary)
                                Text("剩余次数")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Service Details
                if let details = displayRecord.serviceDetails, !details.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服务记录")
                            .font(.headline)
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Customer Feedback
                if let feedback = displayRecord.customerFeedback, !feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("客户反馈")
                            .font(.headline)
                        Text(feedback)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Photos
                if let photos = displayRecord.photos, !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("照片留存")
                                .font(.headline)
                            Spacer()
                            Text("\(photos.count) 张")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)], spacing: 12) {
                            ForEach(photos.indices, id: \.self) { index in
                                if let url = URL(string: photos[index]) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.tertiarySystemBackground))
                                                .frame(height: 100)
                                                .overlay(ProgressView())
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        case .failure:
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.tertiarySystemBackground))
                                                .frame(height: 100)
                                                .overlay(Image(systemName: "photo"))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .onTapGesture {
                                        if let url = URL(string: displayRecord.photos?[index] ?? "") {
                                            fullPhotoURL = url
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle("服务记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("编辑")
                }
                .disabled(isDeleting)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showFirstConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(isDeleting)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ServiceRecordEditView(
                record: displayRecord,
                customer: customer,
                transactions: transactions
            ) { updated in
                displayRecord = updated
                onSave?()
                dismiss()
            }
        }
        .confirmationDialog("删除服务记录", isPresented: $showFirstConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                showSecondConfirm = true
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("删除后将恢复该记录消耗的剩余次数。")
        }
        .alert("确认删除", isPresented: $showSecondConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认删除", role: .destructive) {
                Task { await deleteRecord() }
            }
        } message: {
            Text("此操作不可恢复，确定删除这条服务记录吗？")
        }
        .alert("删除失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(item: $fullPhotoURL) { url in
            PhotoViewer(
                url: url,
                customerName: customer.name,
                storeName: customer.storeName ?? "未分配门店",
                serviceDate: displayRecord.serviceDate.watermarkDateString,
                onDismiss: { fullPhotoURL = nil }
            )
        }
    }

    private func deleteRecord() async {
        isDeleting = true
        do {
            try await ServiceRecordService.shared.deleteRecord(id: displayRecord.id)
            onDelete?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isDeleting = false
    }
}

// MARK: - Photo Viewer
struct PhotoViewer: View {
    let url: URL
    let customerName: String
    let storeName: String
    let serviceDate: String
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadStarted = false
    @State private var errorMessage: String?
    @State private var showSavedToast = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .onLongPressGesture(minimumDuration: 0.5) {
                            saveToAlbum()
                        }
                } else if let errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("重试") {
                            retry()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2), in: Capsule())
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }

                // 保存成功提示
                if showSavedToast {
                    VStack {
                        Spacer()
                        Label("已保存到相册", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.black.opacity(0.75), in: Capsule())
                            .padding(.bottom, 44)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 长按保存提示（图片加载成功后显示）
                if image != nil && !showSavedToast {
                    VStack {
                        Spacer()
                        Text("长按图片可保存到相册（自动添加水印）")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.bottom, 16)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("确定", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .task(id: url) {
                await loadImage()
            }
            .onAppear {
                // 兜底：个别 iOS 版本 sheet 首次弹出时 .task 可能不触发，onAppear 保证加载一定被发起
                if image == nil && errorMessage == nil {
                    Task { await loadImage() }
                }
            }
        }
    }

    private func retry() {
        errorMessage = nil
        isLoading = true
        loadStarted = false
        Task { await loadImage() }
    }

    private func loadImage() async {
        guard !loadStarted else { return }
        loadStarted = true
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "加载失败：HTTP \(httpResponse.statusCode)"
                isLoading = false
                return
            }
            guard let uiImage = UIImage(data: data) else {
                errorMessage = "无法解析图片数据"
                isLoading = false
                return
            }
            image = uiImage
            isLoading = false
        } catch is CancellationError {
            loadStarted = false
        } catch let urlError as URLError where urlError.code == .cancelled {
            loadStarted = false
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            isLoading = false
        }
    }

    private func saveToAlbum() {
        guard let image else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let imageToSave = watermarkedImage(image)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    saveError = "没有相册写入权限，请在系统设置中允许 Beauty Manager 访问相册"
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: imageToSave)
            }) { success, error in
                Task { @MainActor in
                    if success {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSavedToast = true
                        }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSavedToast = false
                        }
                    } else {
                        saveError = error?.localizedDescription ?? "保存失败，请重试"
                    }
                }
            }
        }
    }

    /// 与导出功能一致的水印：左下角半透明黑底 + 白字三行（客户/门店/交付日期）
    private func watermarkedImage(_ source: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1  // 按原图像素绘制，保证原图质量
        let renderer = UIGraphicsImageRenderer(size: source.size, format: format)
        return renderer.image { _ in
            source.draw(at: .zero)
            let lines = [
                "客户: \(customerName)",
                "门店: \(storeName)",
                "交付日期: \(serviceDate)"
            ]
            // 字号按「最长行占图宽 1/3」反推：先用参考字号测量最长行宽度，再按比例缩放
            let refFont = UIFont.systemFont(ofSize: 100, weight: .medium)
            let refAttrs: [NSAttributedString.Key: Any] = [.font: refFont]
            var refMaxWidth: CGFloat = 0
            for line in lines {
                let size = line.size(withAttributes: refAttrs)
                refMaxWidth = max(refMaxWidth, size.width)
            }
            let targetWidth = source.size.width / 3
            let fontSize = max(18, 100 * targetWidth / max(refMaxWidth, 1))
            let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            let margin = fontSize * 0.55
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            // 用文本实际排版高度计算行距，避免中文行间距过小叠字
            var maxWidth: CGFloat = 0
            var maxLineHeight: CGFloat = 0
            for line in lines {
                let rect = line.boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                maxWidth = max(maxWidth, rect.width)
                maxLineHeight = max(maxLineHeight, rect.height)
            }
            let lineHeight = maxLineHeight * 1.2
            let boxWidth = maxWidth + margin * 2
            let boxHeight = lineHeight * CGFloat(lines.count) + margin * 2
            let boxX = margin
            let boxY = source.size.height - boxHeight - margin
            UIColor.black.withAlphaComponent(0.22).setFill()
            UIBezierPath(roundedRect: CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight),
                         cornerRadius: fontSize * 0.25).fill()
            for (i, line) in lines.enumerated() {
                let y = boxY + margin + CGFloat(i) * lineHeight
                line.draw(at: CGPoint(x: boxX + margin, y: y), withAttributes: attrs)
            }
        }
    }
}

// MARK: - 水印日期格式（与导出端 YYYY-MM-DD 一致）
extension Date {
    var watermarkDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}

#Preview {
    NavigationStack {
        ServiceRecordDetailView(
            record: ServiceRecord(
                id: UUID(),
                customerId: UUID(),
                transactionId: nil,
                serviceDate: Date(),
                operatorId: nil,
                operatorName: "李技师",
                operatorPhone: "13800138000",
                bodyPart: "面部",
                serviceDetails: nil,
                photos: nil,
                customerFeedback: "效果很满意，下次再来",
                extraPayment: 500,
                rebateAmount: 0,
                extraPaymentNote: "加购精华导入",
                sessionsUsed: 1,
                remainingSessions: 5,
                branch: "光电",
                createdAt: Date()
            ),
            customer: Customer(
                id: UUID(),
                phone: "13800138000",
                name: "张女士",
                remainingSessions: 5
            ),
            transactions: []
        )
    }
}
