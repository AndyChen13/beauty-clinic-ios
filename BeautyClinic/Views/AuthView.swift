// Views/AuthView.swift
import SwiftUI

enum AuthMode {
    case login
    case register
}

struct AuthView: View {
    let onAuthSuccess: () -> Void
    
    @State private var mode: AuthMode = .login
    
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    
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
                    Text("Beauty Manager")
                        .font(.largeTitle.weight(.bold))
                    Text("内部管理系统")
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
                .onChange(of: mode) { _, _ in
                    errorMessage = nil
                    showError = false
                }
                
                // Input Fields
                VStack(alignment: .leading, spacing: 14) {
                    // Phone
                    VStack(alignment: .leading, spacing: 6) {
                        Text("手机号 *")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("请输入手机号", text: $phone)
                            .keyboardType(.phonePad)
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onChange(of: phone) { _, newValue in
                                phone = String(newValue.filter { $0.isNumber }.prefix(11))
                            }
                    }
                    
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
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密码 *")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("请输入密码（至少6位）", text: $password)
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
        if isProcessing { return false }
        if phone.count < 11 { return false }
        if password.count < 6 { return false }
        
        if mode == .register {
            return !name.isEmpty && password == confirmPassword
        }
        return true
    }
    
    private func login() {
        guard phone.count == 11, password.count >= 6 else { return }
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await AuthService.shared.login(phone: phone, password: password)
                onAuthSuccess()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "登录失败"
                showError = true
            }
            isProcessing = false
        }
    }
    
    private func register() {
        guard phone.count == 11, !name.isEmpty, password.count >= 6 else { return }
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            showError = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await AuthService.shared.register(phone: phone, password: password, name: name)
                onAuthSuccess()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "注册失败"
                showError = true
            }
            isProcessing = false
        }
    }
}

#Preview {
    AuthView(onAuthSuccess: {})
}
