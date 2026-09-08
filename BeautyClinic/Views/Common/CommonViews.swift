// Views/Common/CommonViews.swift
import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    
    private var initial: String {
        String(name.prefix(1))
    }
    
    private var bgColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        let hash = name.utf8.reduce(0) { $0 + Int($1) }
        return colors[hash % colors.count]
    }
    
    var body: some View {
        Circle()
            .fill(bgColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(bgColor)
            )
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - Info Block
struct InfoBlock: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Transaction Mini Row
struct TransactionMiniRow: View {
    @EnvironmentObject var userState: UserState
    let transaction: Transaction
    var onPay: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    
    private var isPaymentLike: Bool {
        transaction.status == .paid || transaction.status == .refunded
    }
    
    private var displayTitle: String {
        if transaction.status == .paid {
            return "收款 · \(transaction.packageName ?? "未知套餐")"
        } else if transaction.status == .refunded {
            return "退款 · \(transaction.packageName ?? "未知套餐")"
        }
        return transaction.packageName ?? "未知套餐"
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.subheadline.weight(.medium))
                Text(transaction.transactionDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !isPaymentLike {
                    Text("\(transaction.completedSessions)/\(transaction.totalSessions) 次 · 剩余 \(transaction.remainingSessions) 次")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(String(format: "%.0f", transaction.status == .paid ? (transaction.amountReceived ?? 0) : transaction.amount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(transaction.status == .refunded ? .red : (transaction.status == .paid ? .green : .accentColor))
                Text(transaction.status.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(transaction.status.color.opacity(0.15))
                    .foregroundColor(transaction.status.color)
                    .clipShape(Capsule())
                if let onPay = onPay, (transaction.outstandingAmount ?? 0) > 0 {
                    Button("收款") {
                        onPay()
                    }
                    .font(.caption2)
                    .foregroundColor(.green)
                }
                if userState.isAdmin, let onEdit = onEdit, !isPaymentLike {
                    Button("修改") {
                        onEdit()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
