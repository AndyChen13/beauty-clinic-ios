//  Views/Common/FilterBar.swift
//  BeautyClinic
//

import SwiftUI

struct FilterBar: View {
    @State private var selectedStatus = "all"
    
    let statuses: [(value: String, label: String)] = [
        ("all", "全部"),
        ("pending", "待处理"),
        ("confirmed", "已确认"),
        ("completed", "已完成")
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            Text("状态:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Status", selection: $selectedStatus) {
                ForEach(statuses, id: \.value) { status in
                    Text(status.label).tag(status.value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    FilterBar()
}
