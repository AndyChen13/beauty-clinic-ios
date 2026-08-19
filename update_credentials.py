#!/usr/bin/env python3
path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/App.swift'
content = open(path).read()

# Replace Supabase URL
content = content.replace(
    'private let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co")!',
    'private let supabaseURL = URL(string: "https://ugwhgxtutochaodgrrqn.supabase.co")!'
)

# Replace Supabase Key
content = content.replace(
    'private let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "your-anon-key"',
    'private let supabaseKey = "sb_publishable_a0iYjlquj72R2J06tZwzGA_1n1Cy_lv"'
)

open(path, 'w').write(content)
print('Supabase credentials updated successfully')
