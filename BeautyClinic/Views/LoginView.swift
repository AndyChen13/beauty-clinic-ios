import SwiftUI

struct LoginView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var showCodeInput = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Text("Beauty Clinic")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.blue)
                    Text("内部管理系统")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("手机号")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        if !showCodeInput {
                            Button(action: sendVerificationCode) {
                                Text(isSendingCode ? "发送中..." : "发送验证码")
                                    .foregroundColor(.blue)
                            }
                            .disabled(phoneNumber.count < 11 || isSendingCode)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    if showCodeInput {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("验证码")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("", text: $verificationCode)
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Button(action: verifyAndLogin) {
                    Text(showCodeInput ? "登录" : "输入手机号")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .background(Color.blue)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func sendVerificationCode() {
        isSendingCode = true
        Task {
            do {
                _ = try await supabaseClient?.auth.signInWithOTP(
                    phoneNumber: "+86" + phoneNumber.dropFirst(3)
                )
                showCodeInput = true
            } catch {
                print("Error sending OTP: \(error)")
            }
            isSendingCode = false
        }
    }
    
    private func verifyAndLogin() {
        guard !verificationCode.isEmpty else { return }
        
        isVerifying = true
        Task {
            do {
                _ = try await supabaseClient?.auth.verifyOTP(
                    phoneNumber: "+86" + phoneNumber.dropFirst(3),
                    token: verificationCode
                )
                // Login successful - navigate to main app
            } catch {
                print("Error verifying OTP: \(error)")
            }
            isVerifying = false
        }
    }
}

#Preview {
    LoginView()
}