// PackageRow.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct PackageRow: View {
    let package: Package
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(package.categoryColor.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.headline)
                Text("\(package.categoryDisplay) • \(package.durationMinutes)分钟")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("¥\(String(format: "%.2f", package.price))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PackageRow(package: Package(name: "水光针基础版", description: nil,
                                 category: "skin", price: 888.0,
                                 durationMinutes: 60))
}