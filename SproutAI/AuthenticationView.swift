//
//  AuthenticationView.swift
//  SproutAI
//
//  Created by First April 76 on 04/10/25.
//

import SwiftUI

// MARK: - Login View
struct LoginView: View {
    @ObservedObject var authService: AuthService
    @State private var phoneNumber = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showRegistration = false
    
    var body: some View {
        VStack(spacing: 32) {
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
            
            VStack(spacing: 16) {
                ZStack(alignment: .leading) {
                    if phoneNumber.isEmpty {
                        Text("Phone Number")
                            .foregroundColor(AppTheme.textPrimary.opacity(0.7))
                            .padding(.leading, 16)
                    }
                    TextField("", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .padding()
                        .foregroundColor(AppTheme.textPrimary)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                ZStack(alignment: .leading) {
                    if name.isEmpty {
                        Text("Name (optional)")
                            .foregroundColor(AppTheme.textPrimary.opacity(0.7))
                            .padding(.leading, 16)
                    }
                    TextField("", text: $name)
                        .padding()
                        .foregroundColor(AppTheme.textPrimary)
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            
            Button(action: handleLogin) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primary.opacity(0.8))
                        .cornerRadius(12)
                } else {
                    Text("Access Dashboard")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((isLoading || phoneNumber.count != 10) ? AppTheme.primary.opacity(0.5) : AppTheme.primary)
                        .cornerRadius(12)
                }
            }
            .disabled(isLoading || phoneNumber.count != 10)
            
            if let error = error {
                Text(error)
                    .foregroundColor(AppTheme.error)
                    .font(.caption)
            }
            
            HStack(spacing: 16) {
                Button(action: { /* TODO: Home action */ }) {
                    Label("Home", systemImage: "house.fill")
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(8)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(8)
                }
                Button(action: { /* TODO: Help action */ }) {
                    Label("Help", systemImage: "questionmark.circle")
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(8)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(8)
                }
            }
            
            Button("Don't have an account? Register Here") {
                showRegistration = true
            }
            .font(.footnote)
            .foregroundColor(AppTheme.secondary)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showRegistration) {
            RegistrationView(authService: authService)
        }
    }
    
    private func handleLogin() {
        isLoading = true
        error = nil
        authService.login(phoneNumber: phoneNumber, name: name.isEmpty ? nil : name) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    error = nil
                case .failure(let err):
                    error = "Login failed: \(err.localizedDescription)"
                }
            }
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
                        
                        TextField("School ID", text: $schoolId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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