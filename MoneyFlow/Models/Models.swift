import Foundation

// MARK: - Account Model
struct Account: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var broker: String  // 증권사
    var yearlyLimit: Int?  // 연간 납입 목표 (원)
    var colorName: String  // 색상 이름
    var isActive: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, broker: String, yearlyLimit: Int? = nil, colorName: String = "blue", isActive: Bool = true) {
        self.id = id
        self.name = name
        self.broker = broker
        self.yearlyLimit = yearlyLimit
        self.colorName = colorName
        self.isActive = isActive
        self.createdAt = Date()
    }
    
    // 기존 JSON 호환성을 위한 커스텀 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        broker = try container.decode(String.self, forKey: .broker)
        yearlyLimit = try container.decodeIfPresent(Int.self, forKey: .yearlyLimit)
        
        // colorName이 없으면 계좌명으로 기본 색상 자동 할당
        if let savedColor = try container.decodeIfPresent(String.self, forKey: .colorName) {
            colorName = savedColor
        } else {
            // 기존 데이터: 계좌명으로 색상 매핑
            switch name {
            case "종합매매":
                colorName = "blue"
            case "ISA":
                colorName = "purple"
            case "연금저축":
                colorName = "orange"
            case "IRP":
                colorName = "pink"
            case "CMA":
                colorName = "teal"
            default:
                colorName = "blue"
            }
        }
        
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    var displayName: String {
        "\(name) (\(broker))"
    }
    
    var color: AccountColor {
        AccountColor(rawValue: colorName) ?? .blue
    }
}

// MARK: - Transaction Type
enum TransactionType: String, Codable, CaseIterable {
    case deposit = "입금"
    case withdrawal = "출금"
    
    var symbol: String {
        switch self {
        case .deposit: return "+"
        case .withdrawal: return "-"
        }
    }
}

// MARK: - Transaction Model
struct Transaction: Identifiable, Codable, Equatable {
    var id: UUID
    var accountId: UUID
    var amount: Int  // 금액 (원)
    var type: TransactionType
    var date: Date
    var memo: String?
    var createdAt: Date
    
    init(id: UUID = UUID(), accountId: UUID, amount: Int, type: TransactionType, date: Date, memo: String? = nil) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.type = type
        self.date = date
        self.memo = memo
        self.createdAt = Date()
    }
}

// MARK: - App Data (Root)
struct AppData: Codable {
    var accounts: [Account]
    var transactions: [Transaction]
    var savingsGoals: [SavingsGoal] = []
    var lastUpdated: Date
    
    init(accounts: [Account] = [], transactions: [Transaction] = [], savingsGoals: [SavingsGoal] = []) {
        self.accounts = accounts
        self.transactions = transactions
        self.savingsGoals = savingsGoals
        self.lastUpdated = Date()
    }
    
    static var defaultData: AppData {
        let defaultAccounts = [
            Account(name: "종합매매", broker: "나무", colorName: "blue"),
            Account(name: "ISA", broker: "나무", yearlyLimit: 20000000, colorName: "purple"),
            Account(name: "CMA", broker: "나무", colorName: "teal"),
            Account(name: "연금저축", broker: "한투", yearlyLimit: 18000000, colorName: "orange"),
            Account(name: "IRP", broker: "한투", yearlyLimit: 9000000, colorName: "pink")
        ]
        return AppData(accounts: defaultAccounts, transactions: [])
    }
}

// MARK: - Statistics Helper
struct AccountStatistics {
    let account: Account
    let totalDeposit: Int
    let totalWithdrawal: Int
    let netAmount: Int
    let yearlyDeposit: Int  // 올해 입금액
    let remainingLimit: Int?  // 남은 한도
    
    init(account: Account, transactions: [Transaction], year: Int = Calendar.current.component(.year, from: Date())) {
        self.account = account
        
        let accountTransactions = transactions.filter { $0.accountId == account.id }
        
        self.totalDeposit = accountTransactions
            .filter { $0.type == .deposit }
            .reduce(0) { $0 + $1.amount }
        
        self.totalWithdrawal = accountTransactions
            .filter { $0.type == .withdrawal }
            .reduce(0) { $0 + $1.amount }
        
        self.netAmount = totalDeposit - totalWithdrawal
        
        // 올해 입금액 계산
        let calendar = Calendar.current
        self.yearlyDeposit = accountTransactions
            .filter { $0.type == .deposit && calendar.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amount }
        
        // 남은 한도 계산
        if let limit = account.yearlyLimit {
            self.remainingLimit = limit - yearlyDeposit
        } else {
            self.remainingLimit = nil
        }
    }
}

// MARK: - Savings Goal Model
struct SavingsGoal: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var targetAmount: Int  // 목표 금액
    var currentAmount: Int = 0  // 현재 금액
    var targetDate: Date?  // 목표 달성 날짜
    var accountIds: [UUID] = []  // 관련 계좌들
    var isActive: Bool = true
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, targetAmount: Int, targetDate: Date? = nil, accountIds: [UUID] = []) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.accountIds = accountIds
        self.createdAt = Date()
    }
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return Double(currentAmount) / Double(targetAmount)
    }
    
    var remainingAmount: Int {
        max(0, targetAmount - currentAmount)
    }
}

// MARK: - Filter Options
enum DateFilter: String, CaseIterable {
    case all = "전체"
    case thisMonth = "이번 달"
    case thisYear = "올해"
    case custom = "기간 선택"
}

struct FilterOptions {
    var selectedAccountIds: Set<UUID> = []
    var dateFilter: DateFilter = .all
    var customStartDate: Date?
    var customEndDate: Date?
    var transactionType: TransactionType?
}
