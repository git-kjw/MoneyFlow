import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedViewType: ViewType = .yearly
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    enum ViewType: String, CaseIterable {
        case yearly = "연간"
        case monthly = "월간"
        case goals = "목표"
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
                    case .goals:
                        goalsView
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
                        Text(String(year))
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
            // 연간 총계 요약
            yearlyOverviewCards
            
            // 월별 추이 차트
            monthlyTrendChart
            
            // 계좌별 연간 통계
            let statistics = dataManager.getAllStatistics(year: selectedYear)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("계좌별 현황")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(statistics, id: \.account.id) { stat in
                    AccountYearlyStatCard(statistics: stat, year: selectedYear)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
    
    private var yearlyOverviewCards: some View {
        let summary = dataManager.yearlySummary(year: selectedYear)
        let netAmount = summary.deposit - summary.withdrawal
        
        return HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("총 입금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.deposit.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(Color.depositColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.depositColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 8) {
                Text("총 출금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.withdrawal.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(Color.withdrawalColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.withdrawalColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 8) {
                Text("순증감")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(netAmount.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(netAmount >= 0 ? Color.depositColor : Color.withdrawalColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background((netAmount >= 0 ? Color.depositColor : Color.withdrawalColor).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    private var monthlyTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("월별 추이")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(1...12, id: \.self) { month in
                    let summary = dataManager.monthlySummary(year: selectedYear, month: month)
                    
                    BarMark(
                        x: .value("월", "\(month)월"),
                        y: .value("입금", summary.deposit)
                    )
                    .foregroundStyle(Color.depositColor)
                    .opacity(0.8)
                    
                    BarMark(
                        x: .value("월", "\(month)월"),
                        y: .value("출금", -summary.withdrawal)
                    )
                    .foregroundStyle(Color.withdrawalColor)
                    .opacity(0.8)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(doubleValue.chartFormatted)
                                .font(.caption)
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
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
            
            // 월간 총계 요약
            monthlyOverviewCards
            
            // 계좌별 월간 통계
            let activeAccounts = dataManager.appData.accounts.filter { $0.isActive }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("계좌별 현황")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(activeAccounts) { account in
                    AccountMonthlyStatCard(account: account, year: selectedYear, month: selectedMonth)
                        .padding(.horizontal)
                }
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
                        Text("목표")
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
                    Text("\(String(year))년 입금")
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
            
            // 목표가 있는 경우 프로그레스 바
            if let limit = statistics.account.yearlyLimit, limit > 0 {
                let progress = Double(statistics.yearlyDeposit) / Double(limit)
                
                VStack(spacing: 4) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress <= 1.0 ? .green : .red)
                    
                    HStack {
                        Text("\(Int(progress * 100))% 달성")
                            .font(.caption2)
                            .foregroundStyle(progress <= 1.0 ? .green : .orange)
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

// MARK: - Account Yearly Stat Card
struct AccountYearlyStatCard: View {
    @EnvironmentObject var dataManager: DataManager
    let statistics: AccountStatistics
    let year: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.accountColor(for: statistics.account))
                    .frame(width: 14, height: 14)
                
                Text(statistics.account.name)
                    .font(.headline)
                
                Spacer()
                
                Text(statistics.account.broker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(Color.depositColor)
                        Text("입금")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(statistics.yearlyDeposit.currencyFormatted)
                        .font(.headline)
                        .foregroundStyle(Color.depositColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.withdrawalColor)
                        Text("출금")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // 연간 출금 계산
                    let yearWithdrawal = dataManager.appData.transactions
                        .filter { $0.accountId == statistics.account.id && $0.type == .withdrawal && $0.date.year == year }
                        .reduce(0) { $0 + $1.amount }
                    Text(yearWithdrawal.currencyFormatted)
                        .font(.headline)
                        .foregroundStyle(Color.withdrawalColor)
                }
                
                Spacer()
            }
            
            // 목표가 있는 경우
            if let limit = statistics.account.yearlyLimit {
                Divider()
                
                let progress = Double(statistics.yearlyDeposit) / Double(limit)
                
                VStack(spacing: 8) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress <= 1.0 ? Color.accountColor(for: statistics.account) : .red)
                        .frame(height: 8)
                    
                    HStack {
                        Text("목표 \(limit.currencyFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if (statistics.remainingLimit ?? 0) > 0 {
                            Text("목표까지 \((statistics.remainingLimit ?? 0).currencyFormatted)")
                                .font(.caption2)
                                .foregroundStyle(Color.accountColor(for: statistics.account))
                                .fontWeight(.medium)
                        } else {
                            Text("목표 달성!")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Account Monthly Stat Card
struct AccountMonthlyStatCard: View {
    @EnvironmentObject var dataManager: DataManager
    let account: Account
    let year: Int
    let month: Int
    
    private var monthDeposit: Int {
        dataManager.appData.transactions
            .filter { $0.accountId == account.id && $0.type == .deposit && $0.date.year == year && $0.date.month == month }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var monthWithdrawal: Int {
        dataManager.appData.transactions
            .filter { $0.accountId == account.id && $0.type == .withdrawal && $0.date.year == year && $0.date.month == month }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        // 거래가 없으면 표시하지 않음
        if monthDeposit == 0 && monthWithdrawal == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.accountColor(for: account))
                        .frame(width: 14, height: 14)
                    
                    Text(account.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(account.broker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(Color.depositColor)
                            Text("입금")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(monthDeposit.currencyFormatted)
                            .font(.headline)
                            .foregroundStyle(Color.depositColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundStyle(Color.withdrawalColor)
                            Text("출금")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(monthWithdrawal.currencyFormatted)
                            .font(.headline)
                            .foregroundStyle(Color.withdrawalColor)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension StatisticsView {
    // MARK: - Monthly Overview Cards  
    private var monthlyOverviewCards: some View {
        let summary = dataManager.monthlySummary(year: selectedYear, month: selectedMonth)
        let netAmount = summary.deposit - summary.withdrawal
        
        return HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("총 입금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.deposit.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(Color.depositColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.depositColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 8) {
                Text("총 출금")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.withdrawal.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(Color.withdrawalColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.withdrawalColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 8) {
                Text("순증감")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(netAmount.currencyFormatted)
                    .font(.headline)
                    .foregroundStyle(netAmount >= 0 ? Color.depositColor : Color.withdrawalColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background((netAmount >= 0 ? Color.depositColor : Color.withdrawalColor).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Goals View
    private var goalsView: some View {
        VStack(spacing: 16) {
            // 임시 placeholder - 추후 완전한 목표 관리 기능 구현 예정
            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("목표 관리")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("연간 목표 달성률과 저축 목표를\n관리할 수 있습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Button("추후 구현 예정") {
                    // TODO: 목표 관리 기능 구현
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(DataManager())
}
