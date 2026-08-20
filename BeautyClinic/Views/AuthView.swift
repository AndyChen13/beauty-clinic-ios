// Views/RegisterView.swift
import SwiftUI
import Supabase

enum AuthMode {
    case login
    case register
}

struct AuthView: View {
    let onAuthSuccess: () -> Void
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundColor(.accentColor)
                        )
                    Text("Beauty Clinic")
                        .font(.largeTitle.weight(.bold))
                    Text("医美内部管理系统")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                // Mode Toggle
                Picker("模式", selection: $mode) {
                    Text("登录").tag(AuthMode.login)
                    Text("注册").tag(AuthMode.register)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Input Fields
                VStack(alignment: .leading, spacing: 14) {
                    // Name (register only)
                    if mode == .register {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("姓名 *")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("请输入姓名", text: $name)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("手机号")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("请输入手机号", text: $phone)
                                .keyboardType(.phonePad)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: phone) { _, newValue in
                                    phone = String(newValue.filter { $0.isNumber }.prefix(11))
                                }
                        }
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("邮箱 *")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("请输入邮箱", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码 *")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("请输入密码", text: $password)
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Confirm Password (register only)
                    if mode == .register {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("确认密码 *")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            SecureField("请再次输入密码", text: $confirmPassword)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                
                // Error
                if showError, let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Action Button
                Button(action: mode == .login ? login : register) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(mode == .login ? "登 录" : "注 册")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                            .opacity(isButtonEnabled ? 1.0 : 0.5)
                    )
                }
                .disabled(!isButtonEnabled)
                
                Spacer()
                
                Text("仅授权员工可使用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var isButtonEnabled: Bool {
        let base = !email.isEmpty && !password.isEmpty && !isProcessing
        if mode == .register {
            return base && !name.isEmpty && password == confirmPassword && password.count >= 6
        }
        return base
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await supabase.auth.signIn(email: email, password: password)
                onAuthSuccess()
            } catch {
                errorMessage = "登录失败: \(error.localizedDescription)"
                showError = true
            }
            isProcessing = false
        }
    }
    
    private func register() {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else { return }
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            showError = true
            return
        }
        guard password.count >= 6 else {
            errorMessage = "密码至少需要6位"
            showError = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                // 1. Create auth user
                let authResponse = try await supabase.auth.signUp(
                    email: email,
                    password: password
                )
                
                let userId = authResponse.user.id
                
                // 2. Insert into users table (role defaults to 'staff')
                    throw NSError(domain: "Register", code: -1, userInfo: [NSLocalizedDescriptionKey: "创建用户失败"])
                }
                
                // 2. Insert into users table (role defaults to 'staff')
                let userInsert = UserInsert(
                    id: userId,
                    email: email,
                    name: name,
                    phone: phone.isEmpty ? nil : phone,
                    role: .staff,
                    storeId: nil
                )
                
                let _: [User] = try await supabase
                    .from("users")
                    .insert(userInsert)
                    .select()
                    .execute()
                    .value
                
                onAuthSuccess()
            } catch {
                errorMessage = "注册失败: \(error.localizedDescription)"
                showError = true
            }
            isProcessing = false
        }
    }
}

#Preview {
    AuthView(onAuthSuccess: {})
}
