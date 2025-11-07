//
//  AuthenticationView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Login ViewModel
@MainActor
final class LoginViewModel: ObservableObject {
    enum Mode {
        case password
        case otp
    }
    
    @Published var identifier = ""
    @Published var password = ""
    @Published var otp = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var mode: Mode = .password
    @Published var otpSent = false
    @Published var countdown = 0
    
    private let authService: AuthService
    private var countdownTimer: Timer?
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    var identifierPlaceholder: String {
        switch mode {
        case .password:
            return "Enter your registered email or phone number"
        case .otp:
            return "Enter the phone number linked to your account"
        }
    }
    
    var identifierKeyboard: UIKeyboardType {
        mode == .otp ? .numberPad : .emailAddress
    }
    
    var identifierContentType: UITextContentType {
        mode == .otp ? .telephoneNumber : .username
    }
    
    var loginButtonTitle: String {
        mode == .otp ? "Login" : "Access Dashboard"
    }
    
    var isActionDisabled: Bool {
        if isLoading { return true }
        switch mode {
        case .password:
            return !isIdentifierValidForPassword || password.isEmpty
        case .otp:
            return !otpSent || otp.count != 6 || !isIdentifierValidForOTP
        }
    }
    
    var canSendOTP: Bool {
        !isLoading && countdown == 0 && isIdentifierValidForOTP
    }
    
    var maskedOTPRecipient: String {
        let digits = numericIdentifier
        guard !digits.isEmpty else { return "your phone" }
        if digits.count <= 4 { return digits }
        let lastFour = digits.suffix(4)
        return "••••\(lastFour)"
    }
    
    func switchMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        error = nil
        isLoading = false
        switch newMode {
        case .password:
            otp = ""
        case .otp:
            password = ""
        }
    }
    
    func sendOTP() {
        guard isIdentifierValidForOTP else {
            error = "Enter a valid phone number to receive the OTP."
            return
        }
        guard countdown == 0 else { return }
        
        isLoading = true
        error = nil
        authService.sendOTP(phoneNumber: numericIdentifier) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    self.otpSent = true
                    self.otp = ""
                    self.startCountdown()
                case .failure(let err):
                    self.error = "Failed to send OTP: \(err.localizedDescription)"
                }
            }
        }
    }
    
    func submit() {
        switch mode {
        case .password:
            guard isIdentifierValidForPassword else {
                error = "Enter a valid email address or phone number."
                return
            }
        case .otp:
            guard isIdentifierValidForOTP else {
                error = "Enter the phone number used to request the OTP."
                return
            }
        }
        
        isLoading = true
        error = nil
        
        switch mode {
        case .password:
            authService.login(identifier: sanitizedIdentifier, password: password) { [weak self] result in
                Task { @MainActor in
                    self?.handleAuthResult(result)
                }
            }
        case .otp:
            authService.verifyOTP(phoneNumber: numericIdentifier, otp: otp) { [weak self] result in
                Task { @MainActor in
                    self?.handleAuthResult(result)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var sanitizedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var numericIdentifier: String {
        sanitizedIdentifier.filter(\.isNumber)
    }
    
    private var isIdentifierValidForPassword: Bool {
        let trimmed = sanitizedIdentifier
        let digits = numericIdentifier
        if trimmed.contains("@"), trimmed.contains(".") {
            return true
        }
        return digits.count >= 6
    }
    
    private var isIdentifierValidForOTP: Bool {
        numericIdentifier.count >= 6
    }
    
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdown = 60
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                timer.invalidate()
                self.countdownTimer = nil
            }
        }
        if let timer = countdownTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func handleAuthResult(_ result: Result<AuthResponse, Error>) {
        isLoading = false
        switch result {
        case .success:
            error = nil
            otpSent = false
            countdownTimer?.invalidate()
            countdown = 0
        case .failure(let err):
            let prefix = mode == .otp ? "OTP verification failed" : "Login failed"
            error = "\(prefix): \(err.localizedDescription)"
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var viewModel: LoginViewModel
    @State private var showRegistration = false
    @FocusState private var isIdentifierFocused: Bool
    @FocusState private var isOTPFocused: Bool
    
    init(authService: AuthService) {
        _authService = ObservedObject(wrappedValue: authService)
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: authService))
    }
    
    var body: some View {
        VStack(spacing: 32) {
            header
            formContent
            submitButton
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(.caption)
            }
            registrationLink
        }
        .padding(.horizontal)
        .onAppear { isIdentifierFocused = true }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView(authService: authService)
        }
        .onChange(of: viewModel.mode) { _ in
            isIdentifierFocused = true
            isOTPFocused = false
        }
        .onChange(of: viewModel.otpSent) { sent in
            if sent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isOTPFocused = true
                }
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Image("SeedlingLabsLogo")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 6)
            Text("Sprout AI Parent Portal")
                .font(.title).fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
            Text("Sign in to access your child's progress")
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private var formContent: some View {
        VStack(spacing: 16) {
            identifierField
            modeToggle
            if viewModel.mode == .password {
                passwordField
            } else {
                otpField
            }
        }
    }
    
    private var identifierField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email or Phone")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.leading, 4)
            
            TextField(viewModel.identifierPlaceholder, text: $viewModel.identifier)
                .keyboardType(viewModel.identifierKeyboard)
                .textContentType(viewModel.identifierContentType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .foregroundColor(AppTheme.textPrimary)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isIdentifierFocused ? AppTheme.primary : Color.clear, lineWidth: 2)
                )
                .focused($isIdentifierFocused)
        }
    }
    
    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button("Password") {
                viewModel.switchMode(.password)
            }
            .foregroundColor(viewModel.mode == .password ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(viewModel.mode == .password ? AppTheme.primary : Color.clear)
            .cornerRadius(8)
            
            Button("OTP") {
                viewModel.switchMode(.otp)
            }
            .foregroundColor(viewModel.mode == .otp ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(viewModel.mode == .otp ? AppTheme.primary : Color.clear)
            .cornerRadius(8)
        }
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.leading, 4)
            
            SecureField("Enter your password", text: $viewModel.password)
                .padding()
                .foregroundColor(AppTheme.textPrimary)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.password.isEmpty ? Color.clear : AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var otpField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OTP")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.leading, 4)
            
            TextField("Enter 6-digit OTP", text: $viewModel.otp)
                .keyboardType(.numberPad)
                .padding()
                .foregroundColor(AppTheme.textPrimary)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.otp.isEmpty ? Color.clear : AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
                .focused($isOTPFocused)
                .onChange(of: viewModel.otp) { newValue in
                    if newValue.count > 6 {
                        viewModel.otp = String(newValue.prefix(6))
                    }
                }
            
            if viewModel.otpSent {
                HStack {
                    Text("OTP sent to \(viewModel.maskedOTPRecipient)")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Spacer()
                    
                    if viewModel.countdown > 0 {
                        Text("Resend in \(viewModel.countdown)s")
                            .foregroundColor(.gray)
                            .font(.caption)
                    } else {
                        Button("Resend OTP") {
                            viewModel.sendOTP()
                        }
                        .foregroundColor(AppTheme.primary)
                        .font(.caption)
                        .disabled(!viewModel.canSendOTP)
                    }
                }
            } else {
                Button("Send OTP") {
                    viewModel.sendOTP()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.canSendOTP ? AppTheme.secondary : AppTheme.secondary.opacity(0.5))
                .cornerRadius(8)
                .disabled(!viewModel.canSendOTP)
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: viewModel.submit) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primary.opacity(0.8))
                    .cornerRadius(12)
            } else {
                Text(viewModel.loginButtonTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isActionDisabled ? AppTheme.primary.opacity(0.5) : AppTheme.primary)
                    .cornerRadius(12)
            }
        }
        .disabled(viewModel.isActionDisabled)
    }
    
    private var registrationLink: some View {
        VStack(spacing: 12) {
            Button("Don't have an account? Register Here") {
                showRegistration = true
            }
            .font(.title3)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.secondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Registration View
struct RegistrationView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var selectedGrades: Set<String> = []
    @State private var selectedSections: Set<String> = []
    @State private var schoolId = ""
    @State private var isLoading = false
    @State private var error: String?
    
    let grades = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
    let sections = ["A", "B", "C", "D"]
    let schoolOptions = [
        ("content-development-school", "Content Development School"),
        ("sri-vidyaniketan-international-school-icse", "Sri Vidyaniketan International School (ICSE)"),
        ("sri-vidyaniketan-public-school-cbse", "Sri Vidyaniketan Public School (CBSE)")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Parent Registration")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.primary)
                        
                        Text("Create an account to track your child's progress")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    VStack(spacing: 16) {
                        TextField("Full Name", text: $fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("School")
                                .font(.headline)
                                .foregroundColor(AppTheme.primary)
                            
                            Picker("Select School", selection: $schoolId) {
                                Text("Select a school")
                                    .tag("")
                                ForEach(schoolOptions, id: \.0) { option in
                                    Text(option.1)
                                        .tag(option.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Grades:")
                            .font(.headline)
                            .foregroundColor(AppTheme.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                            ForEach(grades, id: \.self) { grade in
                                Button(grade) {
                                    if selectedGrades.contains(grade) {
                                        selectedGrades.remove(grade)
                                    } else {
                                        selectedGrades.insert(grade)
                                    }
                                }
                                .padding(8)
                                .background(selectedGrades.contains(grade) ? AppTheme.primary : Color.gray.opacity(0.2))
                                .foregroundColor(selectedGrades.contains(grade) ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Sections:")
                            .font(.headline)
                            .foregroundColor(AppTheme.primary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                            ForEach(sections, id: \.self) { section in
                                Button(section) {
                                    if selectedSections.contains(section) {
                                        selectedSections.remove(section)
                                    } else {
                                        selectedSections.insert(section)
                                    }
                                }
                                .padding(8)
                                .background(selectedSections.contains(section) ? AppTheme.primary : Color.gray.opacity(0.2))
                                .foregroundColor(selectedSections.contains(section) ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: register) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Register")
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isFormValid ? AppTheme.primary : AppTheme.primary.opacity(0.5))
                    .cornerRadius(12)
                    .disabled(!isFormValid || isLoading)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && !phoneNumber.isEmpty && 
        !password.isEmpty && !schoolId.isEmpty && 
        !selectedGrades.isEmpty && !selectedSections.isEmpty
    }
    
    private func register() {
        isLoading = true
        error = nil
        
        authService.register(
            fullName: fullName,
            email: email,
            phoneNumber: phoneNumber,
            password: password,
            grades: Array(selectedGrades),
            sections: Array(selectedSections),
            schoolId: schoolId
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    presentationMode.wrappedValue.dismiss()
                case .failure(let err):
                    error = "Registration failed: \(err.localizedDescription)"
                }
            }
        }
    }
}
