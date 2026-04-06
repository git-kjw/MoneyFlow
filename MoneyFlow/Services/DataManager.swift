import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class DataManager: ObservableObject {
    @Published var appData: AppData
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentFileURL: URL?
    @Published var hasUnsavedChanges = false
    
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var lastModifiedDate: Date?
    
    init() {
        self.appData = AppData.defaultData
        loadFromUserDefaults()
        
        // 앱 시작 시 자동으로 기본 파일 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupDefaultFile()
        }
    }
    
    deinit {
        fileMonitor?.cancel()
    }
    
    // MARK: - UserDefaults (앱 내부 백업용)
    private let userDefaultsKey = "MoneyFlowAppData"
    
    private func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                appData = try decoder.decode(AppData.self, from: data)
            } catch {
                appData = AppData.defaultData
            }
        }
    }
    
    private func saveToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(appData)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("UserDefaults 저장 실패: \(error)")
        }
    }
    
    // MARK: - File Operations (iCloud Drive 지원)
    
    func loadFromFile(url: URL) {
        isLoading = true
        errorMessage = nil
        
        // 보안 스코프 접근 시작
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            appData = try decoder.decode(AppData.self, from: data)
            currentFileURL = url
            hasUnsavedChanges = false
            
            // 북마크 저장 (다음에 자동으로 열기 위해)
            saveBookmark(for: url)
            
            // 로컬 백업도 업데이트
            saveToUserDefaults()
            
            // 파일 모니터링 시작
            startFileMonitoring(url: url)
        } catch {
            errorMessage = "파일 로드 실패: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func saveToFile(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            appData.lastUpdated = Date()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(appData)
            try data.write(to: url)
            currentFileURL = url
            hasUnsavedChanges = false
            
            saveBookmark(for: url)
            saveToUserDefaults()
        } catch {
            errorMessage = "파일 저장 실패: \(error.localizedDescription)"
        }
    }
    
    func saveToCurrentFile() {
        guard let url = currentFileURL else { return }
        saveToFile(url: url)
    }
    
    // MARK: - Bookmark (마지막 파일 기억)
    private let bookmarkKey = "MoneyFlowFileBookmark"
    
    private func saveBookmark(for url: URL) {
        do {
            #if os(iOS)
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            print("북마크 저장 실패: \(error)")
        }
    }
    
    func loadFromBookmark() -> Bool {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return false
        }
        
        do {
            var isStale = false
            #if os(iOS)
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            #endif
            
            if isStale {
                return false
            }
            
            loadFromFile(url: url)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - File Monitoring
    private func startFileMonitoring(url: URL) {
        fileMonitor?.cancel()
        
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: .main
        )
        
        fileMonitor?.setEventHandler { [weak self] in
            self?.reloadFromCurrentFile()
        }
        
        fileMonitor?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileMonitor?.resume()
    }
    
    private func reloadFromCurrentFile() {
        guard let url = currentFileURL else { return }
        
        // 외부에서 파일이 변경된 경우에만 리로드
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attrs[.modificationDate] as? Date,
           let lastMod = lastModifiedDate,
           modDate > lastMod {
            loadFromFile(url: url)
        }
    }
    
    // MARK: - Export Data (JSON)
    func exportData() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(appData)
        } catch {
            errorMessage = "데이터 내보내기 실패: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Account Operations
    func addAccount(_ account: Account) {
        appData.accounts.append(account)
        markAsChanged()
    }
    
    func updateAccount(_ account: Account) {
        if let index = appData.accounts.firstIndex(where: { $0.id == account.id }) {
            appData.accounts[index] = account
            markAsChanged()
        }
    }
    
    func deleteAccount(_ account: Account) {
        appData.accounts.removeAll { $0.id == account.id }
        appData.transactions.removeAll { $0.accountId == account.id }
        markAsChanged()
    }
    
    func getAccount(by id: UUID) -> Account? {
        appData.accounts.first { $0.id == id }
    }
    
    // MARK: - Transaction Operations
    func addTransaction(_ transaction: Transaction) {
        appData.transactions.append(transaction)
        markAsChanged()
    }
    
    func updateTransaction(_ transaction: Transaction) {
        if let index = appData.transactions.firstIndex(where: { $0.id == transaction.id }) {
            appData.transactions[index] = transaction
            markAsChanged()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        appData.transactions.removeAll { $0.id == transaction.id }
        markAsChanged()
    }
    
    // MARK: - Mark Changed & Auto Save
    private func markAsChanged() {
        hasUnsavedChanges = true
        saveToUserDefaults()
        
        // 파일이 열려있으면 자동 저장
        if currentFileURL != nil {
            saveToCurrentFile()
        }
    }
    
    // MARK: - Statistics
    func getStatistics(for account: Account, year: Int? = nil) -> AccountStatistics {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())
        return AccountStatistics(account: account, transactions: appData.transactions, year: targetYear)
    }
    
    func getAllStatistics(year: Int? = nil) -> [AccountStatistics] {
        appData.accounts.filter { $0.isActive }.map { getStatistics(for: $0, year: year) }
    }
    
    func filteredTransactions(options: FilterOptions) -> [Transaction] {
        appData.transactions.filtered(by: options, accounts: appData.accounts)
    }
    
    func monthlySummary(year: Int, month: Int) -> (deposit: Int, withdrawal: Int) {
        let calendar = Calendar.current
        let transactions = appData.transactions.filter {
            calendar.component(.year, from: $0.date) == year &&
            calendar.component(.month, from: $0.date) == month
        }
        
        let deposit = transactions.filter { $0.type == .deposit }.reduce(0) { $0 + $1.amount }
        let withdrawal = transactions.filter { $0.type == .withdrawal }.reduce(0) { $0 + $1.amount }
        
        return (deposit, withdrawal)
    }
    
    func yearlySummary(year: Int) -> (deposit: Int, withdrawal: Int) {
        let calendar = Calendar.current
        let transactions = appData.transactions.filter {
            calendar.component(.year, from: $0.date) == year
        }
        
        let deposit = transactions.filter { $0.type == .deposit }.reduce(0) { $0 + $1.amount }
        let withdrawal = transactions.filter { $0.type == .withdrawal }.reduce(0) { $0 + $1.amount }
        
        return (deposit, withdrawal)
    }
    
    // MARK: - Auto File Setup
    private func setupDefaultFile() {
        // 이미 파일이 열려있거나 bookmark에서 로드 성공하면 건너뛰기
        if currentFileURL != nil || loadFromBookmark() {
            return
        }
        
        // iCloud Drive의 기본 위치에 MoneyFlow 데이터 파일 생성/사용
        if let iCloudURL = getDefaultiCloudFileURL() {
            if FileManager.default.fileExists(atPath: iCloudURL.path) {
                // 기존 파일이 있으면 로드
                loadFromFile(url: iCloudURL)
            } else {
                // 없으면 새로 생성
                createDefaultiCloudFile(at: iCloudURL)
            }
        }
    }
    
    private func getDefaultiCloudFileURL() -> URL? {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        
        let documentsURL = iCloudURL.appendingPathComponent("Documents")
        
        // Documents 폴더가 없으면 생성
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        
        return documentsURL.appendingPathComponent("MoneyFlowData.json")
    }
    
    private func createDefaultiCloudFile(at url: URL) {
        // 현재 데이터를 기본 파일로 저장
        saveToFile(url: url)
        print("✅ 기본 iCloud 파일 생성: \(url.path)")
    }
}
