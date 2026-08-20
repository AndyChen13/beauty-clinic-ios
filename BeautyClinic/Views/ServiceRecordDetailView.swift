// Views/ServiceRecordDetailView.swift
import SwiftUI

struct ServiceRecordDetailView: View {
    let record: ServiceRecord
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoViewer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.accent)
                        Text(record.serviceDate.formatted(date: .long, time: .shortened))
                            .font(.headline)
                        Spacer()
                    }
                    
                    if record.extraPayment > 0 {
                        HStack {
                            Image(systemName: "yensign.circle.fill")
                                .foregroundColor(.green)
                            Text("额外付款: ¥\(String(format: "%.2f", record.extraPayment))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        
                        if let note = record.extraPaymentNote, !note.isEmpty {
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
                    
                    if let name = record.operatorName, !name.isEmpty {
                        InfoRow(label: "姓名", value: name)
                    }
                    if let phone = record.operatorPhone, !phone.isEmpty {
                        Divider()
                        InfoRow(label: "联系方式", value: phone)
                    }
                    if let part = record.bodyPart, !part.isEmpty {
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
                            Text("\(record.sessionsUsed)")
                                .font(.title3.weight(.bold))
                            Text("本次消耗")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let remaining = record.remainingSessions {
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
                
                // Customer Feedback
                if let feedback = record.customerFeedback, !feedback.isEmpty {
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
                if let photos = record.photos, !photos.isEmpty {
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
        .sheet(isPresented: $showPhotoViewer) {
            if let photos = record.photos,
               let index = selectedPhotoIndex,
               index < photos.count,
               let url = URL(string: photos[index]) {
                PhotoViewer(url: url, onDismiss: { showPhotoViewer = false })
            }
        }
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
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("加载失败")
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
                operatorName: "李医生",
                operatorPhone: "13800138000",
                bodyPart: "面部",
                photos: nil,
                customerFeedback: "效果很满意，下次再来",
                extraPayment: 500,
                extraPaymentNote: "加购精华导入",
                sessionsUsed: 1,
                remainingSessions: 5,
                createdAt: Date()
            )
        )
    }
}
