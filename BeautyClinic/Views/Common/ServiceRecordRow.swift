// Views/Common/ServiceRecordRow.swift
import SwiftUI

struct ServiceRecordRow: View {
    let record: ServiceRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.serviceDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Spacer()
                if record.extraPayment > 0 {
                    Text("+¥\(String(format: "%.0f", record.extraPayment))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 12) {
                if let operatorName = record.operatorName {
                    Label(operatorName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let bodyPart = record.bodyPart {
                    Label(bodyPart, systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let feedback = record.customerFeedback, !feedback.isEmpty {
                Text("反馈: \(feedback)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                if let remaining = record.remainingSessions {
                    Text("剩余: \(remaining)次")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                if let photos = record.photos, !photos.isEmpty {
                    Label("\(photos.count)张照片", systemImage: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
