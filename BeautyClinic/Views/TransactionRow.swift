// TransactionRow.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(transaction.statusColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.packageName)
                        .font(.headline)
                    Text(formatDate(transaction.transactionDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("¥\(String(format: "%.0f", transaction.amount))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            if let customerName = transaction.customerName {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                    Text("客户: \(customerName)")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TransactionRow(transaction: Transaction(
        customerId: UUID(),
        storeId: UUID(),
        packageId: UUID(),
        amount: 888.0,
        transactionDate: Date(),
        status: "completed"
    ))
}