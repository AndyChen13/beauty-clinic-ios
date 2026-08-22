// Views/AuthView.swift
import SwiftUI

enum AuthMode {
    case login       // 手机号验证码登录
    case password    // 密码登录（admin fallback）
}

enum AuthStep {
    case inputPhone
    case inputCode
    case inputPassword
}

struct AuthView: View {
    let onAuthSuccess: () -> Void
    
    @State private var mode: AuthMode = .login
    @State private var step: AuthStep = .inputPhone
    
    @State private var phone = ""
    @State private var code = ""
    @State private var name = ""
    @State private var password = ""
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var countdown = 0
    
    private let codeLength = 6
    
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
                    Text("手机验证码").tag(AuthMode.login)
                    Text("密码登录").tag(AuthMode.password)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: mode) { _, _ in
                    step = mode == .login ? .inputPhone : .inputPassword
                    errorMessage = nil
                    showError = false
                }
                
                // Input Fields
                VStack(alignment: .leading, spacing: 14) {
                    // Phone (always needed)
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
                    
                    if mode == .login {
                        switch step {
                        case .inputPhone:
                            EmptyView()
                            
                        case .inputCode:
                            // Name (for new user)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("姓名 *（新用户必填）")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("请输入姓名", text: $name)
                                    .textInputAutocapitalization(.never)
                                    .padding(12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Verification code
                            VStack(alignment: .leading, spacing: 6) {
                                Text("验证码 *")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    TextField("6位验证码", text: $code)
                                        .keyboardType(.numberPad)
                                        .padding(12)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Button(action: sendCode) {
                                        Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(countdown > 0 || phone.count < 11 ? .gray : .accentColor)
                                            .frame(width: 100)
                                            .padding(.vertical, 12)
                                            .background(Color(UIColor.secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .disabled(countdown > 0 || phone.count < 11 || isProcessing)
                                }
                            }
                            
                        case .inputPassword:
                            EmptyView()
                        }
                    } else {
                        // Password mode
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
                Button(action: actionButtonTapped) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(actionButtonTitle)
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
    
    private var actionButtonTitle: String {
        if mode == .login {
            return step == .inputPhone ? "获取验证码" : "登 录"
        }
        return "登 录"
    }
    
    private var isButtonEnabled: Bool {
        if isProcessing { return false }
        if phone.count < 11 { return false }
        
        if mode == .login {
            if step == .inputPhone {
                return true
            }
            return code.count == codeLength
        } else {
            return !password.isEmpty
        }
    }
    
    private func actionButtonTapped() {
        if mode == .login {
            if step == .inputPhone {
                sendCode()
            } else {
                verifyCode()
            }
        } else {
            passwordLogin()
        }
    }
    
    private func sendCode() {
        guard phone.count == 11 else { return }
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await AuthService.shared.sendCode(phone: phone)
                step = .inputCode
                startCountdown()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "发送验证码失败"
                showError = true
            }
            isProcessing = false
        }
    }
    
    private func verifyCode() {
        guard code.count == codeLength else { return }
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                let userName = name.isEmpty ? nil : name
                try await AuthService.shared.verifyCode(phone: phone, code: code, name: userName)
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
    
    private func passwordLogin() {
        guard !password.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await AuthService.shared.loginWithPassword(phone: phone, password: password)
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
    
    private func startCountdown() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    AuthView(onAuthSuccess: {})
}
