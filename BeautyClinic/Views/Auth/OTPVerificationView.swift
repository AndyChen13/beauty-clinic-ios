// OTPVerificationView.swift
// BeautyClinic
//
// Created by Andy Chen on 2026-08-19.
//

import SwiftUI

struct OTPVerificationView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    let phoneNumber: String
    
    @State private var verificationCode = ""
    @State private var isVerifying = false
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("验证码已发送到 \(formatPhoneNumber(phoneNumber))")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 52)
                        .overlay(
                            Text("\(verificationCode.dropFirst(index).prefix(1))")
                                .font(.title2.weight(.bold))
                                .frame(width: 44, height: 52)
                        )
                }
            }
            
            TextField("", text: $verificationCode)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .multilineTextAlignment(.center)
                .frame(height: 60)
                .onReceive(verificationCode.publisher.dropFirst()) { _ in
                    if verificationCode.count > 6 {
                        verificationCode = String(verificationCode.prefix(6))
                    }
                }
            
            Button(action: verifyAndLogin) {
                Text(isVerifying ? "验证中..." : "确认登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(Color.blue)
            .cornerRadius(12)
            
            if showError {
                Text("验证码错误，请重试")
                    .foregroundColor(.red)
                    .animation(.none)
            }
        }
        .padding()
    }
    
    private func formatPhoneNumber(_ phone: String) -> String {
        guard phone.count >= 11 else { return phone }
        let last4 = String(phone.suffix(4))
        return "****-****-\(last4)"
    }
    
    private func verifyAndLogin() {
        guard verificationCode.count == 6 else { showError = true; return }
        
        isVerifying = true
        Task {
            do {
                _ = try await supabaseClient?.auth.verifyOTP(
                    phoneNumber: "+86" + phoneNumber.dropFirst(3),
                    token: verificationCode
                )
                // Login successful - navigate to main app
                showError = false
            } catch {
                print("Error verifying OTP: \(error)")
                showError = true
            }
            isVerifying = false
        }
    }
}

#Preview {
    OTPVerificationView(phoneNumber: "13800138000")
}