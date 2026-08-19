#!/usr/bin/env python3

path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Views/HomeView.swift'
content = open(path).read()

# Fix the count query issue - remove type annotations for count queries
content = content.replace(
    'async let customersCountTask = supabase\n                .from("customers")\n                .select("count", head: true)\n                .execute()',
    'async let customersCountTask = supabase\n                .from("customers")\n                .select("*", head: true)\n                .execute()'
)

content = content.replace(
    'async let pendingTask: [Transaction] = supabase\n                .from("transactions")\n                .select("count", head: true)\n                .in("status", value: ["pending", "confirmed", "in_progress"])\n                .execute()',
    'async let pendingTask = supabase\n                .from("transactions")\n                .select("*", head: true)\n                .in("status", value: ["pending", "confirmed", "in_progress"])\n                .execute()'
)

# Fix the tuple destructuring
content = content.replace(
    'let (cCount, tTrans, mTrans, pTrans, recent) = try await (',
    'let (_, tTrans, mTrans, _, recent) = try await ('
)

open(path, 'w').write(content)
print('Fixed HomeView.swift')
