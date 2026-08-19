//  Views/LoginView.swift
//  BeautyClinic
//

import SwiftUI
import Supabase

struct LoginView: View {
    let onLoginSuccess: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
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
                
                // Input Fields
                VStack(alignment: .leading, spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("邮箱")
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
                        Text("密码")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        SecureField("请输入密码", text: $password)
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Error
                if showError, let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Login Button
                Button(action: login) {
                    HStack {
                        if isLoggingIn {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("登 录")
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
        !email.isEmpty && !password.isEmpty && !isLoggingIn
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoggingIn = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await supabase.auth.signIn(
                    email: email,
                    password: password
                )
                onLoginSuccess()
            } catch {
                errorMessage = "登录失败: 邮箱或密码错误"
                showError = true
            }
            isLoggingIn = false
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {})
}
