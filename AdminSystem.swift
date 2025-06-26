// AdminSystem.swift - Timely Admin Paneli Sistemi

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

// MARK: - Admin Data Models
struct UserStats {
    var totalUsers: Int = 0
    var activeUsers: Int = 0
    var newUsersThisWeek: Int = 0
    var totalMeetings: Int = 0
    var meetingsThisWeek: Int = 0
    var completedOnboarding: Int = 0
    var onboardingCompletionRate: Int = 0
}

struct AdminSystemLog: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let details: String
    let timestamp: Date
    
    enum LogLevel {
        case info, warning, error
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
}

struct AdminMeeting: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let duration: Int
    let organizerEmail: String
    let participantEmail: String
}

// MARK: - Admin UserProfile Model
struct AdminUserProfile: Identifiable {
    let id: String
    var firstName: String
    var lastName: String
    var email: String
    var purpose: String = ""
    var schedulingPreference: String = ""
    var calendarProvider: String = ""
    var isOnboardingCompleted: Bool = false
    var createdAt: Date = Date()
    var phoneNumber: String? = nil
    var avatarURL: String? = nil
    
    var displayName: String {
        if lastName.isEmpty {
            return firstName
        }
        return "\(firstName) \(lastName)"
    }
}

// MARK: - Admin Manager
class AdminManager: ObservableObject {
    static let shared = AdminManager()
    
    @Published var isAdmin = false
    @Published var currentUser: User?
    
    private let adminEmails = ["ilsu.erdal@gmail.com"]
    
    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.checkAdminStatus(user)
            }
        }
        
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.checkAdminStatus(user)
        }
    }
    
    func checkAdminStatus(_ user: User?) {
        guard let user = user, let email = user.email else {
            isAdmin = false
            return
        }
        
        isAdmin = adminEmails.contains(email.lowercased())
        print("🔑 Admin kontrolü: \(email) -> \(isAdmin ? "ADMIN" : "USER")")
    }
}

// MARK: - Admin Data Manager
class AdminDataManager {
    static let shared = AdminDataManager()
    
    private init() {}
    
    func fetchUserStats(completion: @escaping (UserStats) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Admin: Error fetching user stats: \(error)")
                let stats = UserStats()
                completion(stats)
                return
            }
            
            let users = snapshot?.documents ?? []
            let totalUsers = users.count
            
            let completedOnboarding = users.filter { doc in
                return doc.data()["isOnboardingCompleted"] as? Bool ?? false
            }.count
            
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let newUsersThisWeek = users.filter { doc in
                if let timestamp = doc.data()["createdAt"] as? Timestamp {
                    return timestamp.dateValue() > oneWeekAgo
                }
                return false
            }.count
            
            let stats = UserStats(
                totalUsers: totalUsers,
                activeUsers: totalUsers,
                newUsersThisWeek: newUsersThisWeek,
                totalMeetings: 342,
                meetingsThisWeek: 45,
                completedOnboarding: completedOnboarding,
                onboardingCompletionRate: totalUsers > 0 ? (completedOnboarding * 100) / totalUsers : 0
            )
            
            completion(stats)
        }
    }
    
    func fetchAllUsers(completion: @escaping ([AdminUserProfile]) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Admin: Error fetching users: \(error)")
                completion([])
                return
            }
            
            var users: [AdminUserProfile] = []
            
            snapshot?.documents.forEach { document in
                let data = document.data()
                
                var user = AdminUserProfile(
                    id: document.documentID,
                    firstName: data["firstName"] as? String ?? "Bilinmiyor",
                    lastName: data["lastName"] as? String ?? "",
                    email: data["email"] as? String ?? "Bilinmiyor"
                )
                
                user.purpose = data["purpose"] as? String ?? ""
                user.schedulingPreference = data["schedulingPreference"] as? String ?? ""
                user.calendarProvider = data["calendarProvider"] as? String ?? ""
                user.isOnboardingCompleted = data["isOnboardingCompleted"] as? Bool ?? false
                user.phoneNumber = data["phoneNumber"] as? String ?? ""
                user.avatarURL = data["avatarURL"] as? String ?? ""
                
                if let timestamp = data["createdAt"] as? Timestamp {
                    user.createdAt = timestamp.dateValue()
                }
                
                users.append(user)
            }
            
            completion(users)
        }
    }
    
    func deleteUser(userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).delete { error in
            if let error = error {
                print("❌ Admin: Error deleting user: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func fetchAllMeetings(for dateRange: AdminMeetingManagementView.DateRange, completion: @escaping ([AdminMeeting]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mockMeetings = [
                AdminMeeting(
                    title: "Proje Toplantısı",
                    date: Date(),
                    duration: 60,
                    organizerEmail: "user1@example.com",
                    participantEmail: "user2@example.com"
                ),
                AdminMeeting(
                    title: "Müşteri Görüşmesi",
                    date: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    duration: 45,
                    organizerEmail: "sales@company.com",
                    participantEmail: "client@example.com"
                )
            ]
            completion(mockMeetings)
        }
    }
}

// MARK: - Admin Dashboard View
struct AdminDashboardView: View {
    @EnvironmentObject var adminManager: AdminManager
    @State private var selectedTab = 0
    @State private var userStats = UserStats()
    @State private var isLoading = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AdminOverviewView(userStats: userStats)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Genel Bakış")
                }
                .tag(0)
            
            AdminUserManagementView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Kullanıcılar")
                }
                .tag(1)
            
            AdminMeetingManagementView()
                .tabItem {
                    Image(systemName: "calendar.badge.clock")
                    Text("Toplantılar")
                }
                .tag(2)
            
            AdminSettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Ayarlar")
                }
                .tag(3)
        }
        .accentColor(.purple)
        .onAppear {
            loadAdminData()
        }
    }
    
    private func loadAdminData() {
        isLoading = true
        
        AdminDataManager.shared.fetchUserStats { stats in
            DispatchQueue.main.async {
                self.userStats = stats
                self.isLoading = false
            }
        }
    }
}

// MARK: - Admin Overview View
struct AdminOverviewView: View {
    let userStats: UserStats
    @State private var showingDetailedStats = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    adminHeaderView
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        AdminStatCard(
                            title: "Toplam Kullanıcı",
                            value: "\(userStats.totalUsers)",
                            icon: "person.3.fill",
                            color: .blue,
                            trend: "+\(userStats.newUsersThisWeek) bu hafta"
                        )
                        
                        AdminStatCard(
                            title: "Aktif Kullanıcı",
                            value: "\(userStats.activeUsers)",
                            icon: "person.circle.fill",
                            color: .green,
                            trend: "Son 7 gün"
                        )
                        
                        AdminStatCard(
                            title: "Toplantı Sayısı",
                            value: "\(userStats.totalMeetings)",
                            icon: "calendar.badge.clock",
                            color: .orange,
                            trend: "+\(userStats.meetingsThisWeek) bu hafta"
                        )
                        
                        AdminStatCard(
                            title: "Tamamlanan Onboarding",
                            value: "\(userStats.completedOnboarding)",
                            icon: "checkmark.circle.fill",
                            color: .purple,
                            trend: "%\(userStats.onboardingCompletionRate) tamamlama"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100)
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var adminHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hoş geldiniz, Admin!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Timely Admin Paneli")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Admin User Management View
struct AdminUserManagementView: View {
    @State private var users: [AdminUserProfile] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedFilter: UserFilter = .all
    
    enum UserFilter: String, CaseIterable {
        case all = "Tümü"
        case onboardingCompleted = "Onboarding Tamamlanan"
        case onboardingPending = "Onboarding Bekleyen"
    }
    
    var filteredUsers: [AdminUserProfile] {
        let filtered = users.filter { user in
            switch selectedFilter {
            case .all:
                return true
            case .onboardingCompleted:
                return user.isOnboardingCompleted
            case .onboardingPending:
                return !user.isOnboardingCompleted
            }
        }
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { user in
                user.firstName.localizedCaseInsensitiveContains(searchText) ||
                user.lastName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(UserFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                if isLoading {
                    ProgressView("Kullanıcılar yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            AdminUserRow(user: user)
                        }
                        .onDelete(perform: deleteUsers)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Kullanıcı Yönetimi")
            .onAppear {
                loadUsers()
            }
        }
    }
    
    private func loadUsers() {
        isLoading = true
        
        AdminDataManager.shared.fetchAllUsers { fetchedUsers in
            DispatchQueue.main.async {
                self.users = fetchedUsers
                self.isLoading = false
            }
        }
    }
    
    private func deleteUsers(at offsets: IndexSet) {
        for index in offsets {
            let user = filteredUsers[index]
            AdminDataManager.shared.deleteUser(userId: user.id) { success in
                if success {
                    DispatchQueue.main.async {
                        self.loadUsers()
                    }
                }
            }
        }
    }
}

// MARK: - Admin Meeting Management View
struct AdminMeetingManagementView: View {
    @State private var meetings: [AdminMeeting] = []
    @State private var isLoading = true
    @State private var selectedDateRange = DateRange.thisWeek
    
    enum DateRange: String, CaseIterable {
        case today = "Bugün"
        case thisWeek = "Bu Hafta"
        case thisMonth = "Bu Ay"
        case all = "Tümü"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Tarih Aralığı", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                if isLoading {
                    ProgressView("Toplantılar yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(meetings) { meeting in
                        AdminMeetingRow(meeting: meeting)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Toplantı Yönetimi")
            .onAppear {
                loadMeetings()
            }
            .onChange(of: selectedDateRange) { _, _ in
                loadMeetings()
            }
        }
    }
    
    private func loadMeetings() {
        isLoading = true
        
        AdminDataManager.shared.fetchAllMeetings(for: selectedDateRange) { fetchedMeetings in
            DispatchQueue.main.async {
                self.meetings = fetchedMeetings
                self.isLoading = false
            }
        }
    }
}

// MARK: - Admin Settings View
struct AdminSettingsView: View {
    @State private var showingSystemLogs = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sistem Yönetimi") {
                    AdminSettingRow(
                        icon: "doc.text.fill",
                        title: "Sistem Logları",
                        subtitle: "Hata logları ve sistem kayıtları",
                        action: { showingSystemLogs = true }
                    )
                }
                
                Section("Güvenlik") {
                    AdminSettingRow(
                        icon: "key.fill",
                        title: "Admin Yetkiler",
                        subtitle: "Admin kullanıcı yönetimi",
                        action: { }
                    )
                    
                    Button("Çıkış Yap") {
                        try? Auth.auth().signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Admin Ayarları")
            .sheet(isPresented: $showingSystemLogs) {
                AdminSystemLogsView()
            }
        }
    }
}

// MARK: - Supporting Views
struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(trend)
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Kullanıcı ara...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct AdminUserRow: View {
    let user: AdminUserProfile
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                    Text(String(user.firstName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Label {
                        Text(user.isOnboardingCompleted ? "Tamamlandı" : "Beklemede")
                            .font(.caption2)
                    } icon: {
                        Image(systemName: user.isOnboardingCompleted ? "checkmark.circle.fill" : "clock.fill")
                            .font(.caption2)
                    }
                    .foregroundColor(user.isOnboardingCompleted ? .green : .orange)
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: user.createdAt, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AdminMeetingRow: View {
    let meeting: AdminMeeting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.title)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Text(formatTime(meeting.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(meeting.organizerEmail, systemImage: "person.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(meeting.duration) dk")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

struct AdminSettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AdminSystemLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [AdminSystemLog] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(log.level.color)
                                .frame(width: 8, height: 8)
                            
                            Text(log.message)
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            Text(log.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !log.details.isEmpty {
                            Text(log.details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Sistem Logları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadLogs()
            }
        }
    }
    
    private func loadLogs() {
        // Mock logs
        logs = [
            AdminSystemLog(
                level: .info,
                message: "Sistem başlatıldı",
                details: "Tüm servisler aktif",
                timestamp: Date()
            ),
            AdminSystemLog(
                level: .warning,
                message: "Yüksek bellek kullanımı",
                details: "RAM kullanımı %85",
                timestamp: Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date()
            ),
            AdminSystemLog(
                level: .error,
                message: "Veritabanı bağlantı hatası",
                details: "Bağlantı timeout",
                timestamp: Calendar.current.date(byAdding: .minute, value: -10, to: Date()) ?? Date()
            )
        ]
    }
}
