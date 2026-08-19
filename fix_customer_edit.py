#!/usr/bin/env python3

path = '/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic/Views/CustomerEditView.swift'
content = open(path).read()

old_code = '''                var created: Customer
                if case .edit(let existing) = mode {
                    // Update existing customer
                    var updateData: [String: Any] = [
                        "phone": phone,
                        "name": name,
                        "gender": gender,
                        "associated_store_id": selectedStoreId?.uuidString as Any,
                        "medical_history": medicalHistory.isEmpty ? nil : medicalHistory,
                        "preferences": notes.isEmpty ? nil : parseNotes(notes)
                    ]
                    if hasBirthdate {
                        let formatter = ISO8601DateFormatter()
                        updateData["birthdate"] = formatter.string(from: birthdate)
                    }
                    if let photoUrl = photoUrl {
                        updateData["photo_url"] = photoUrl
                    }
                    
                    let result: [Customer] = try await supabase
                        .from("customers")
                        .update(updateData)
                        .eq("id", value: existing.id)
                        .select()
                        .execute()
                        .value
                    created = result.first!'''

new_code = '''                var created: Customer
                if case .edit(let existing) = mode {
                    struct CustomerUpdate: Encodable {
                        let phone: String
                        let name: String
                        let gender: String
                        let associated_store_id: String?
                        let medical_history: String?
                        let preferences: [String: String]?
                        let birthdate: String?
                        let photo_url: String?
                    }
                    
                    var birthdateString: String?
                    if hasBirthdate {
                        let formatter = ISO8601DateFormatter()
                        birthdateString = formatter.string(from: birthdate)
                    }
                    
                    let updateData = CustomerUpdate(
                        phone: phone,
                        name: name,
                        gender: gender,
                        associated_store_id: selectedStoreId?.uuidString,
                        medical_history: medicalHistory.isEmpty ? nil : medicalHistory,
                        preferences: notes.isEmpty ? nil : parseNotes(notes),
                        birthdate: birthdateString,
                        photo_url: photoUrl
                    )
                    
                    let result: [Customer] = try await supabase
                        .from("customers")
                        .update(updateData)
                        .eq("id", value: existing.id)
                        .select()
                        .execute()
                        .value
                    created = result.first!'''

if old_code in content:
    content = content.replace(old_code, new_code)
    open(path, 'w').write(content)
    print('Fixed CustomerEditView.swift')
else:
    print('Could not find old code block')
    # Try to find and show the actual text
    idx = content.find('var created: Customer')
    if idx >= 0:
        print('Found at index', idx)
        print('Actual text:')
        print(repr(content[idx:idx+500]))
