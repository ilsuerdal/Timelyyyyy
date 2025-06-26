// RootView.swift - Ana kontrol dosyası (Auto Layout Constraint Hatası Düzeltildi)

import SwiftUI
import Firebase
import FirebaseAuth

struct RootView: View {
    @ObservedObject private var authManager = FirebaseAuthManager.shared
    @StateObject private var viewModel = TimelyViewModel()
    @State private var isLoading = true
    @State private var userProfile: TimelyUserProfile?
    
    var body: some View {
        Group {
            if isLoading {
               LoadingView()
            } else if authManager.isLoggedIn {
                // Kullanıcı giriş yapmış
                if let profile = userProfile, profile.isOnboardingCompleted {
                    // Onboarding tamamlanmış → HomeView (TAB BAR YOK)
                    HomeView()
                        .environmentObject(authManager)
                        .environmentObject(viewModel)
                } else {
                    // Onboarding tamamlanmamış → Yeni Sorular
                    NewQuestionFlowView(
                        firstName: userProfile?.firstName ?? extractFirstName(from: authManager.currentUser?.displayName ?? authManager.currentUser?.email ?? "User"),
                        email: userProfile?.email ?? authManager.currentUser?.email ?? ""
                    )
                }
            } else {
                // Kullanıcı giriş yapmamış → Login
                MainLoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            checkAuthenticationState()
        }
        .onChange(of: authManager.isLoggedIn) {
            if authManager.isLoggedIn {
                loadUserProfile()
            } else {
                userProfile = nil
                isLoading = false
            }
        }
    }
    
    private func checkAuthenticationState() {
        isLoading = true
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                if authManager.isLoggedIn {
                    loadUserProfile()
                } else {
                    isLoading = false
                }
            }
        }
    }
    
    private func loadUserProfile() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        UserDataManager.shared.getUserProfile(userId: currentUser.uid) { profile, error in
            Task { @MainActor in
                if let profile = profile {
                    // Profil var, TimelyUserProfile'a çevir
                    self.userProfile = TimelyUserProfile(
                        id: profile.id,
                        firstName: profile.firstName,
                        lastName: profile.lastName,
                        email: profile.email,
                        purpose: profile.purpose,
                        schedulingPreference: profile.schedulingPreference,
                        calendarProvider: profile.calendarProvider,
                        isOnboardingCompleted: profile.isOnboardingCompleted,
                        createdAt: profile.createdAt,
                        phoneNumber: profile.phoneNumber ?? "",
                        avatarURL: profile.avatarURL ?? ""
                    )
                    print("✅ Mevcut kullanıcı profili yüklendi: \(profile.firstName)")
                } else {
                    // Profil yok, yeni kullanıcı
                    print("❌ Kullanıcı profili bulunamadı, yeni kullanıcı olarak işaretlendi")
                    self.userProfile = TimelyUserProfile(
                        id: currentUser.uid,
                        firstName: self.extractFirstName(from: currentUser.displayName ?? currentUser.email ?? "User"),
                        email: currentUser.email ?? "",
                        isOnboardingCompleted: false // YENİ KULLANICI
                    )
                }
                self.isLoading = false
            }
        }
    }
    
    private func extractFirstName(from fullName: String) -> String {
        return fullName.components(separatedBy: " ").first ?? "User"
    }
}

// MARK: - TimelyUserProfile Model (Güncellenmiş)
struct TimelyUserProfile {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var purpose: String
    var schedulingPreference: String
    var calendarProvider: String
    var isOnboardingCompleted: Bool
    var createdAt: Date
    var phoneNumber: String
    var avatarURL: String
    
    init(id: String, firstName: String, lastName: String = "", email: String,
         purpose: String = "", schedulingPreference: String = "",
         calendarProvider: String = "", isOnboardingCompleted: Bool = false,
         createdAt: Date = Date(), phoneNumber: String = "", avatarURL: String = "") {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.purpose = purpose
        self.schedulingPreference = schedulingPreference
        self.calendarProvider = calendarProvider
        self.isOnboardingCompleted = isOnboardingCompleted
        self.createdAt = createdAt
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
    }
}

// MARK: - YENİ QuestionFlowView (AUTO LAYOUT CONSTRAINT HATASI DÜZELTİLDİ)
struct NewQuestionFlowView: View {
    let firstName: String
    let email: String
    
    @State private var currentPage = 0
    @State private var selectedOption = ""
    @State private var textFieldAnswer = "" // Metin giriş için
    @State private var isSavingProfile = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Profil bilgileri
    @State private var purpose = ""
    @State private var title = ""
    @State private var department = ""
    @State private var bio = ""
    @State private var schedulingPreference = ""
    
    @ObservedObject private var authManager = FirebaseAuthManager.shared
    
    // YENİ SORULAR
    let questions = [
        ProfileQuestion(
            title: "Timely'yi ne için kullanmak istiyorsunuz?",
            type: .multipleChoice,
            options: [
                ("Kişisel", "person"),
                ("İş", "briefcase"),
                ("Her ikisi", "person.2")
            ]
        ),
        ProfileQuestion(
            title: "Unvanınız nedir?",
            type: .textInput,
            placeholder: "Örn: iOS Developer, Proje Yöneticisi"
        ),
        ProfileQuestion(
            title: "Hangi departmanda çalışıyorsunuz?",
            type: .textInput,
            placeholder: "Örn: Mobil Geliştirme, İnsan Kaynakları"
        ),
        ProfileQuestion(
            title: "Kendinizi kısaca tanıtır mısınız?",
            type: .textInput,
            placeholder: "Örn: 5 yıllık deneyimli iOS geliştiricisi...",
            isLongText: true
        ),
        ProfileQuestion(
            title: "Toplantıları nasıl planlamayı tercih edersiniz?",
            type: .multipleChoice,
            options: [
                ("Manuel", "hand.tap"),
                ("Otomatik", "sparkles"),
                ("Karma", "slider.horizontal.3")
            ]
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient - mor tema
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.3, blue: 0.9),
                        Color(red: 0.6, green: 0.4, blue: 0.9),
                        Color(red: 0.5, green: 0.3, blue: 0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                
                // SCROLLVIEW İLE DÜZELTİLDİ - Spacer kullanımı kaldırıldı
                ScrollView {
                    VStack(spacing: 30) {
                        // Progress Bar
                        VStack(spacing: 8) {
                            HStack {
                                Text("Soru \(currentPage + 1) / \(questions.count)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            
                            ProgressView(value: Double(currentPage + 1), total: Double(questions.count))
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Welcome Message (sadece ilk soruda)
                        if currentPage == 0 {
                            VStack(spacing: 8) {
                                Text("Hoş geldiniz, \(firstName)!")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Profilinizi oluşturmak için birkaç soru sormak istiyoruz")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                        
                        // Soru Ekranı
                        VStack(spacing: 25) {
                            // Soru Başlığı
                            Text(questions[currentPage].title)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            // Soru Tipi
                            if questions[currentPage].type == .multipleChoice {
                                // Çoktan Seçmeli
                                LazyVStack(spacing: 16) {
                                    ForEach(questions[currentPage].options, id: \.0) { option, icon in
                                        Button(action: {
                                            selectedOption = option
                                            textFieldAnswer = option
                                        }) {
                                            HStack(spacing: 16) {
                                                // Icon
                                                ZStack {
                                                    Circle()
                                                        .fill(selectedOption == option ? Color.white : Color.white.opacity(0.2))
                                                        .frame(width: 50, height: 50)
                                                    
                                                    Image(systemName: icon)
                                                        .font(.system(size: 20))
                                                        .foregroundColor(selectedOption == option ? .purple : .white)
                                                }
                                                
                                                // Text
                                                Text(option)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                // Checkmark
                                                if selectedOption == option {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(selectedOption == option ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                                                    .stroke(selectedOption == option ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 24)
                            } else {
                                // Text Input - CONSTRAINT HATASI DÜZELTİLDİ
                                VStack(spacing: 16) {
                                    if questions[currentPage].isLongText {
                                        // Uzun metin için TextEditor - Frame conflict çözüldü
                                        VStack(alignment: .leading, spacing: 0) {
                                            if textFieldAnswer.isEmpty {
                                                HStack {
                                                    Text(questions[currentPage].placeholder)
                                                        .foregroundColor(.white.opacity(0.6))
                                                        .font(.system(size: 16))
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.top, 12)
                                            }
                                            
                                            TextEditor(text: $textFieldAnswer)
                                                .foregroundColor(.white)
                                                .font(.system(size: 16))
                                                .scrollContentBackground(.hidden)
                                                .background(Color.clear)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, textFieldAnswer.isEmpty ? 0 : 8)
                                        }
                                        .frame(height: 120)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.white.opacity(0.1))
                                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                        )
                                    } else {
                                        // Kısa metin için TextField
                                        TextField(questions[currentPage].placeholder, text: $textFieldAnswer)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white.opacity(0.1))
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            )
                                            .font(.system(size: 18))
                                            .accentColor(.white)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .onChange(of: textFieldAnswer) { newValue in
                                    selectedOption = newValue
                                }
                            }
                        }
                        
                        // Content spacer - Flexible height
                        Color.clear
                            .frame(height: max(50, geometry.size.height - 600))
                        
                        // Next/Finish Button - Fixed at bottom
                        VStack(spacing: 16) {
                            Button(action: handleNextButton) {
                                HStack {
                                    if isSavingProfile {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                            .scaleEffect(0.9)
                                    } else {
                                        Text(currentPage == questions.count - 1 ? "Profili Oluştur" : "Devam Et")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.purple)
                                        
                                        if currentPage < questions.count - 1 {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.purple)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .disabled(selectedOption.isEmpty || isSavingProfile)
                            .opacity(selectedOption.isEmpty ? 0.6 : 1.0)
                            .padding(.horizontal, 24)
                            
                            // Skip Button (sadece son soru değilse ve text input değilse)
                            if currentPage < questions.count - 1 && questions[currentPage].type == .multipleChoice {
                                Button("Atla") {
                                    selectedOption = "Belirtilmedi"
                                    textFieldAnswer = "Belirtilmedi"
                                    handleNextButton()
                                }
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .alert("Hata", isPresented: $showingAlert) {
            Button("Tamam") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // İlk soruya geçerken değerleri sıfırla
            if currentPage == 0 {
                selectedOption = ""
                textFieldAnswer = ""
            }
        }
    }
    
    private func handleNextButton() {
        // Cevabı kaydet
        let answerToSave = textFieldAnswer.isEmpty ? selectedOption : textFieldAnswer
        saveCurrentPageResponse(answerToSave)
        
        // Son soru mu?
        if currentPage == questions.count - 1 {
            // Profili database'e kaydet
            finishOnboarding()
        } else {
            // Sonraki soruya geç
            currentPage += 1
            selectedOption = ""
            textFieldAnswer = ""
        }
    }
    
    private func saveCurrentPageResponse(_ answer: String) {
        switch currentPage {
        case 0: purpose = answer
        case 1: title = answer
        case 2: department = answer
        case 3: bio = answer
        case 4: schedulingPreference = answer
        default: break
        }
    }
    
    private func finishOnboarding() {
        guard let currentUser = authManager.currentUser else {
            alertMessage = "Kullanıcı bilgisi bulunamadı."
            showingAlert = true
            return
        }
        
        isSavingProfile = true
        
        // PublicUserProfile oluştur (Profil sayfası için)
        let userProfile = PublicUserProfile(
            userID: currentUser.uid,
            name: firstName + " Erdal", // Soyadı ekleyebilirsiniz
            email: currentUser.email ?? "",
            title: title.isEmpty ? "Çalışan" : title,
            department: department.isEmpty ? "Genel" : department,
            profileImageURL: nil,
            bio: bio.isEmpty ? "Timely kullanıcısı" : bio,
            workingHours: createDefaultWorkingHours(),
            timeZone: TimeZone.current.identifier,
            isPublic: true,
            lastSeen: Date(),
            linkedinURL: nil,
            twitterURL: nil,
            websiteURL: nil,
            preferredMeetingDuration: 30,
            bufferTime: 15,
            maxMeetingsPerDay: 6
        )
        
        // UserProfile oluştur (Uyumluluk için)
        var basicProfile = UserProfile(
            id: currentUser.uid,
            firstName: firstName,
            email: currentUser.email ?? ""
        )
        
        basicProfile.purpose = purpose
        basicProfile.schedulingPreference = schedulingPreference
        basicProfile.isOnboardingCompleted = true
        
        // UserDefaults'a profil kaydet (geçici çözüm)
        saveProfileToUserDefaults(userProfile)
        
        // Basic profile'ı Firebase'e kaydet
        UserDataManager.shared.saveUserProfile(basicProfile) { success, error in
            DispatchQueue.main.async {
                isSavingProfile = false
                
                if success {
                    print("✅ Profil bilgileri başarıyla kaydedildi")
                    print("📋 Kaydedilen veriler:")
                    print("   - Name: \(userProfile.name)")
                    print("   - Title: \(userProfile.title)")
                    print("   - Department: \(userProfile.department)")
                    print("   - Bio: \(userProfile.bio)")
                    
                    // Auth manager'ın state'ini yeniden yüklemesi için trigger
                    // Bu sayede RootView HomeView'e geçecek
                } else {
                    alertMessage = "Profil kaydedilirken hata oluştu."
                    showingAlert = true
                }
            }
        }
    }
    
    private func saveProfileToUserDefaults(_ profile: PublicUserProfile) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "UserProfile_\(profile.userID)")
            print("✅ PublicUserProfile UserDefaults'a kaydedildi")
        }
    }
    
    private func createDefaultWorkingHours() -> PublicWorkingHours {
        let workingDay = PublicDaySchedule(
            isWorkingDay: true,
            startTime: "09:00",
            endTime: "17:00",
            breaks: [PublicTimeSlot(startTime: "12:00", endTime: "13:00", title: "Öğle Arası")]
        )
        
        let weekend = PublicDaySchedule(
            isWorkingDay: false,
            startTime: "",
            endTime: "",
            breaks: []
        )
        
        return PublicWorkingHours(
            monday: workingDay,
            tuesday: workingDay,
            wednesday: workingDay,
            thursday: workingDay,
            friday: workingDay,
            saturday: weekend,
            sunday: weekend
        )
    }
}

// MARK: - Profile Question Model
struct ProfileQuestion {
    let title: String
    let type: ProfileQuestionType
    let options: [(String, String)] // (text, icon) - sadece multipleChoice için
    let placeholder: String // sadece textInput için
    let isLongText: Bool // uzun metin alanı için
    
    init(title: String, type: ProfileQuestionType, options: [(String, String)] = [], placeholder: String = "", isLongText: Bool = false) {
        self.title = title
        self.type = type
        self.options = options
        self.placeholder = placeholder
        self.isLongText = isLongText
    }
}

enum ProfileQuestionType {
    case multipleChoice
    case textInput
}

// MARK: - MainLoginView (Constraint hataları düzeltildi)
struct MainLoginView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSignUp = false
    @State private var rememberMe = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.3, blue: 0.9),
                    Color(red: 0.6, green: 0.4, blue: 0.9),
                    Color(red: 0.5, green: 0.3, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            // SCROLLVIEW İÇERİĞİ DÜZELTİLDİ - Spacer'lar kaldırıldı
            ScrollView {
                VStack(spacing: 30) {
                    // Top spacing
                    Color.clear.frame(height: 40)
                    
                    // Logo ve başlık
                    VStack(spacing: 25) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Timely")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Toplantılarınızı kolayca yönetin")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Giriş Formu
                    VStack(spacing: 24) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            TextField("example@email.com", text: $email)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Şifre")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            SecureField("••••••••", text: $password)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                        }
                        
                        // Remember Me & Forgot Password
                        HStack {
                            Button(action: { rememberMe.toggle() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.white)
                                    Text("Beni hatırla")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: resetPassword) {
                                Text("Şifremi Unuttum?")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                    .padding(.horizontal, 30)
                    
                    // Login Button
                    Button(action: loginWithEmail) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    .scaleEffect(0.9)
                            } else {
                                Text("Giriş Yap")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.horizontal, 30)
                    
                    // Sign Up Link
                    HStack {
                        Text("Hesabınız yok mu?")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button("Kayıt Ol") {
                            showingSignUp = true
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .underline()
                    }
                    .font(.system(size: 16))
                    
                    // Bottom spacing
                    Color.clear.frame(height: 50)
                }
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .alert("Bilgi", isPresented: $showingAlert) {
            Button("Tamam") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        return !email.isEmpty && email.contains("@") && !password.isEmpty && password.count >= 6
    }
    
    private func loginWithEmail() {
        isLoading = true
        
        AuthService.shared.login(email: email, password: password) { result in
            Task { @MainActor in
                isLoading = false
                
                switch result {
                case .success(let authResult):
                    print("✅ GİRİŞ BAŞARILI - Mevcut kullanıcı HomeView'e yönlendirilecek")
                    // Firebase auth manager otomatik olarak durumu güncelleyecek
                    // RootView bu değişikliği algılayıp HomeView'e götürecek
                    
                case .failure(let error):
                    alertMessage = getFirebaseErrorMessage(error)
                    showingAlert = true
                    print("❌ Giriş hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else {
            alertMessage = "Lütfen önce email adresinizi girin."
            showingAlert = true
            return
        }
        
        AuthService.shared.resetPassword(email: email) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    alertMessage = "Şifre sıfırlama bağlantısı \(email) adresine gönderildi."
                case .failure(let error):
                    alertMessage = "Şifre sıfırlama hatası: \(error.localizedDescription)"
                }
                showingAlert = true
            }
        }
    }
    
    private func getFirebaseErrorMessage(_ error: Error) -> String {
        guard let errorCode = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        
        switch errorCode {
        case .userNotFound:
            return "Bu email adresi ile kayıtlı kullanıcı bulunamadı."
        case .wrongPassword:
            return "Hatalı şifre girdiniz."
        case .invalidEmail:
            return "Geçersiz email adresi."
        case .networkError:
            return "İnternet bağlantınızı kontrol edin."
        case .tooManyRequests:
            return "Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin."
        case .userDisabled:
            return "Bu hesap devre dışı bırakılmış."
        default:
            return error.localizedDescription
        }
    }
}

