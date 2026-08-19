#!/usr/bin/env python3

path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Views/TransactionListView.swift'
content = open(path).read()

old = '''                _ = try await supabase
                    .from("transactions")
                    .update([
                        "completed_sessions": nextSession,
                        "first_delivery_date": existingDeliveries.isEmpty ? ISO8601DateFormatter().string(from: Date()) : nil,
                        "status": nextSession >= transaction.totalSessions ? "completed" : "in_progress"
                    ])'''

new = '''                _ = try await supabase
                    .from("transactions")
                    .update([
                        "completed_sessions": String(nextSession),
                        "first_delivery_date": existingDeliveries.isEmpty ? ISO8601DateFormatter().string(from: Date()) : nil,
                        "status": nextSession >= transaction.totalSessions ? "completed" : "in_progress"
                    ])'''

if old in content:
    content = content.replace(old, new)
    open(path, 'w').write(content)
    print('Fixed TransactionListView.swift')
else:
    print('Could not find old code')
