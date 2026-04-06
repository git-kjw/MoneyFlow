import Foundation

// MARK: - Date Extensions
extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components)!
    }
    
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    
    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components)!
    }
    
    var endOfYear: Date {
        var components = DateComponents()
        components.year = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfYear)!
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    var yearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self)
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self)
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self)
    }
}

// MARK: - Int Extensions (Currency Formatting)
extension Int {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    var currencyFormatted: String {
        "\(formatted)원"
    }
}

// MARK: - Array Extensions
extension Array where Element == Transaction {
    func filtered(by options: FilterOptions, accounts: [Account]) -> [Transaction] {
        var result = self
        
        // 계좌 필터
        if !options.selectedAccountIds.isEmpty {
            result = result.filter { options.selectedAccountIds.contains($0.accountId) }
        }
        
        // 날짜 필터
        let now = Date()
        switch options.dateFilter {
        case .all:
            break
        case .thisMonth:
            result = result.filter { $0.date >= now.startOfMonth && $0.date <= now.endOfMonth }
        case .thisYear:
            result = result.filter { $0.date >= now.startOfYear && $0.date <= now.endOfYear }
        case .custom:
            if let start = options.customStartDate {
                result = result.filter { $0.date >= start.startOfDay }
            }
            if let end = options.customEndDate {
                result = result.filter { $0.date <= end.endOfDay }
            }
        }
        
        // 거래 유형 필터
        if let type = options.transactionType {
            result = result.filter { $0.type == type }
        }
        
        return result
    }
    
    func groupedByDate() -> [(date: Date, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: self) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, transactions: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
    
    func groupedByMonth() -> [(yearMonth: String, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: self) { transaction in
            transaction.date.yearMonth
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (yearMonth: $0.key, transactions: $0.value) }
    }
    
    func groupedByYear() -> [(year: Int, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: self) { transaction in
            transaction.date.year
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (year: $0.key, transactions: $0.value) }
    }
}
