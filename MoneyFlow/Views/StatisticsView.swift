import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedViewType: ViewType = .yearly
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    enum ViewType: String, CaseIterable {
        case yearly = "연간"
        case monthly = "월간"
        case byAccount = "계좌별"
    }
    
    private var availableYears: [Int] {
        let years = Set(dataManager.appData.transactions.map { $0.date.year })
        let currentYear = Calendar.current.component(.year, from: Date())
        let allYears = years.union([currentYear])
        return Array(allYears).sorted(by: >)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 연도 선택
                yearPicker
                
                // 뷰 타입 선택
                Picker("보기", selection: $selectedViewType) {
                    ForEach(ViewType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 컨텐츠
                ScrollView {
                    switch selectedViewType {
                    case .yearly:
                        yearlyStatisticsView
                    case .monthly:
                        monthlyStatisticsView
                    case .byAccount:
                        accountStatisticsView
                    }
                }
            }
            .navigationTitle("통계")
        }
    }
    
    // MARK: - Year Picker
    private var yearPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        selectedYear = year
                    } label: {
                        Text("\(year)년")
                            .font(.subheadline)
                            .fontWeight(selectedYear == year ? .bold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedYear == year ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.systemBackground)
    }
    
    // MARK: - Yearly Statistics
    private var yearlyStatisticsView: some View {
        VStack(spacing: 16) {
            // 연간 총계
            let summary = dataManager.yearlySummary(year: selectedYear)
            
            VStack(spacing: 16) {
                HStack {
                    StatCard(title: "총 입금", value: summary.deposit, color: .green)
                    StatCard(title: "총 출금", value: summary.withdrawal, color: .red)
                }
                
                StatCard(
                    title: "순 이체액",
                    value: summary.deposit - summary.withdrawal,
                    color: summary.deposit >= summary.withdrawal ? .green : .red,
                    isLarge: true
                )
            }
            .padding(.horizontal)
            
            // 월별 차트
            VStack(alignment: .leading, spacing: 12) {
                Text("월별 추이")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(1...12, id: \.self) { month in
                    let monthSummary = dataManager.monthlySummary(year: selectedYear, month: month)
                    MonthlyBarRow(
                        month: month,
                        deposit: monthSummary.deposit,
                        withdrawal: monthSummary.withdrawal,
                        maxValue: getMaxMonthlyValue()
                    )
                }
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Monthly Statistics
    private var monthlyStatisticsView: some View {
        VStack(spacing: 16) {
            // 월 선택
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            selectedMonth = month
                        } label: {
                            Text("\(month)월")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedMonth == month ? Color.accentColor : Color.secondary.opacity(0.1))
                                .foregroundStyle(selectedMonth == month ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // 월간 총계
            let summary = dataManager.monthlySummary(year: selectedYear, month: selectedMonth)
            
            VStack(spacing: 16) {
                HStack {
                    StatCard(title: "입금", value: summary.deposit, color: .green)
                    StatCard(title: "출금", value: summary.withdrawal, color: .red)
                }
                
                StatCard(
                    title: "순 이체액",
                    value: summary.deposit - summary.withdrawal,
                    color: summary.deposit >= summary.withdrawal ? .green : .red,
                    isLarge: true
                )
            }
            .padding(.horizontal)
            
            // 해당 월 거래 목록
            let monthTransactions = dataManager.appData.transactions.filter {
                $0.date.year == selectedYear && $0.date.month == selectedMonth
            }.sorted { $0.date > $1.date }
            
            if !monthTransactions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("거래 내역")
                        .font(.headline)
                    
                    ForEach(monthTransactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dataManager.getAccount(by: transaction.accountId)?.displayName ?? "삭제된 계좌")
                                    .font(.subheadline)
                                Text(transaction.date.shortDateString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(transaction.type.symbol)\(transaction.amount.currencyFormatted)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(transaction.type == .deposit ? .green : .red)
                        }
                        .padding(.vertical, 4)
                        
                        if transaction.id != monthTransactions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Account Statistics
    private var accountStatisticsView: some View {
        VStack(spacing: 16) {
            let statistics = dataManager.getAllStatistics(year: selectedYear)
            
            ForEach(statistics, id: \.account.id) { stat in
                AccountStatCard(statistics: stat, year: selectedYear)
            }
        }
        .padding()
    }
    
    // MARK: - Helper
    private func getMaxMonthlyValue() -> Int {
        var maxValue = 0
        for month in 1...12 {
            let summary = dataManager.monthlySummary(year: selectedYear, month: month)
            maxValue = max(maxValue, max(summary.deposit, summary.withdrawal))
        }
        return max(maxValue, 1)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    var isLarge: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value.currencyFormatted)
                .font(isLarge ? .title2 : .headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Monthly Bar Row
struct MonthlyBarRow: View {
    let month: Int
    let deposit: Int
    let withdrawal: Int
    let maxValue: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(month)월")
                .font(.caption)
                .frame(width: 30, alignment: .trailing)
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    // 입금 바
                    Rectangle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(deposit) / CGFloat(maxValue) / 2)
                    
                    // 출금 바
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: geometry.size.width * CGFloat(withdrawal) / CGFloat(maxValue) / 2)
                    
                    Spacer()
                }
            }
            .frame(height: 16)
            
            Text((deposit - withdrawal).formatted)
                .font(.caption2)
                .foregroundStyle((deposit >= withdrawal) ? .green : .red)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

// MARK: - Account Stat Card
struct AccountStatCard: View {
    let statistics: AccountStatistics
    let year: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statistics.account.name)
                        .font(.headline)
                    Text(statistics.account.broker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let limit = statistics.account.yearlyLimit {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("한도")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(limit.currencyFormatted)
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(year)년 입금")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(statistics.yearlyDeposit.currencyFormatted)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                if let remaining = statistics.remainingLimit {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("남은 한도")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(remaining.currencyFormatted)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(remaining > 0 ? .green : .red)
                    }
                }
            }
            
            // 한도가 있는 경우 프로그레스 바
            if let limit = statistics.account.yearlyLimit, limit > 0 {
                let progress = Double(statistics.yearlyDeposit) / Double(limit)
                
                VStack(spacing: 4) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress <= 1.0 ? .green : .red)
                    
                    HStack {
                        Text("\(Int(progress * 100))% 사용")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatisticsView()
        .environmentObject(DataManager())
}
