//  Views/LoginView.swift
//  BeautyClinic
//

import SwiftUI
import Supabase

struct LoginView: View {
    let onLoginSuccess: () -> Void
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var showCodeInput = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var countdown = 0
    
    private var formattedPhone: String {
        let digits = phoneNumber.filter { $0.isNumber }
        return "+86" + digits
    }
    
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
                    // Phone
                    VStack(alignment: .leading, spacing: 6) {
                        Text("手机号")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Text("+86")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 12)
                            
                            TextField("请输入手机号", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .onChange(of: phoneNumber) { _, newValue in
                                    phoneNumber = String(newValue.filter { $0.isNumber }.prefix(11))
                                }
                            
                            if !showCodeInput {
                                Button(action: sendCode) {
                                    Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                        .font(.subheadline.weight(.medium))
                                }
                                .disabled(phoneNumber.count < 11 || isSendingCode || countdown > 0)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.trailing, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Verification Code
                    if showCodeInput {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("验证码")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("请输入6位验证码", text: $verificationCode)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onChange(of: verificationCode) { _, newValue in
                                    verificationCode = String(newValue.filter { $0.isNumber }.prefix(6))
                                }
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: resendCode) {
                                Text(countdown > 0 ? "\(countdown)秒后重新发送" : "重新发送验证码")
                                    .font(.caption)
                                    .foregroundStyle(countdown > 0 ? .secondary : Color.accentColor)
                            }
                            .disabled(countdown > 0)
                        }
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
                Button(action: verifyAndLogin) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(showCodeInput ? "登 录" : "下一步")
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
        if showCodeInput {
            return verificationCode.count == 6 && !isVerifying
        } else {
            return phoneNumber.count == 11 && !isSendingCode
        }
    }
    
    private func sendCode() {
        isSendingCode = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await supabase.auth.signInWithOTP(phone: formattedPhone)
                showCodeInput = true
                startCountdown()
            } catch {
                errorMessage = "发送失败: \(error.localizedDescription)"
                showError = true
            }
            isSendingCode = false
        }
    }
    
    private func resendCode() {
        sendCode()
    }
    
    private func verifyAndLogin() {
        if !showCodeInput {
            sendCode()
            return
        }
        
        guard verificationCode.count == 6 else { return }
        
        isVerifying = true
        errorMessage = nil
        showError = false
        
        Task {
            do {
                try await supabase.auth.verifyOTP(
                    phone: formattedPhone,
                    token: verificationCode,
                    type: .sms
                )
                onLoginSuccess()
            } catch {
                errorMessage = "验证失败: 验证码错误或已过期"
                showError = true
            }
            isVerifying = false
        }
    }
    
    private func startCountdown() {
        countdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {})
}
