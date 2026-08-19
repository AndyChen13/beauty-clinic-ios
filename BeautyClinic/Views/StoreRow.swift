// StoreRow.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct StoreRow: View {
    let store: Store
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(store.statusColor.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(store.address ?? "无地址")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Circle()
                        .fill(store.statusColor)
                        .frame(width: 8, height: 8)
                    Text(store.statusDisplay)
                        .font(.caption2)
                        .foregroundStyle(store.statusColor)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    StoreRow(store: Store(name: "上海静安店", address: "静安区南京西路1234号", status: "active"))
}