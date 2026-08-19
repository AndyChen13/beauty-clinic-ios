// CustomerRow.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct CustomerRow: View {
    let customer: Customer
    
    var body: some View {
        HStack {
            AvatarView(name: customer.name)
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.name)
                    .font(.headline)
                Text(customer.phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    CustomerRow(customer: Customer(phone: "13800138000", name: "张女士"))
}