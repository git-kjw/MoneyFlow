import Foundation

// MARK: - Account Model
struct Account: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var broker: String  // 증권사
    var yearlyLimit: Int?  // 연간 납입 한도 (원)
    var isActive: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, broker: String, yearlyLimit: Int? = nil, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.broker = broker
        self.yearlyLimit = yearlyLimit
        self.isActive = isActive
        self.createdAt = Date()
    }
    
    var displayName: String {
        "\(name) (\(broker))"
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
    var lastUpdated: Date
    
    init(accounts: [Account] = [], transactions: [Transaction] = []) {
        self.accounts = accounts
        self.transactions = transactions
        self.lastUpdated = Date()
    }
    
    static var defaultData: AppData {
        let defaultAccounts = [
            Account(name: "종합매매", broker: "나무"),
            Account(name: "ISA", broker: "나무", yearlyLimit: 20000000),
            Account(name: "CMA", broker: "나무"),
            Account(name: "연금저축", broker: "한투", yearlyLimit: 18000000),
            Account(name: "IRP", broker: "한투", yearlyLimit: 9000000)
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
