// Views/ServiceRecordDetailView.swift
import SwiftUI

struct ServiceRecordDetailView: View {
    let sourceRecord: ServiceRecord
    let customer: Customer
    let transactions: [Transaction]
    var onDelete: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var displayRecord: ServiceRecord
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoViewer = false
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
                                        selectedPhotoIndex = index
                                        showPhotoViewer = true
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
        .sheet(isPresented: $showPhotoViewer) {
            if let photos = displayRecord.photos,
               let index = selectedPhotoIndex,
               index < photos.count,
               let url = URL(string: photos[index]) {
                PhotoViewer(url: url, onDismiss: { showPhotoViewer = false })
            }
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
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("加载失败，无法访问图片")
                                .foregroundColor(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
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
                extraPaymentNote: "加购精华导入",
                sessionsUsed: 1,
                remainingSessions: 5,
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
