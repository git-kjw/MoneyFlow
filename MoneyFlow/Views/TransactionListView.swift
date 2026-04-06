import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSheet = false
    @State private var showingQuickEntry = false
    @State private var showingFilterSheet = false
    @State private var filterOptions = FilterOptions()
    @State private var selectedTransaction: Transaction?
    @State private var searchText = ""
    
    private var filteredTransactions: [Transaction] {
        var transactions = dataManager.filteredTransactions(options: filterOptions)
        
        if !searchText.isEmpty {
            transactions = transactions.filter { transaction in
                if let memo = transaction.memo, memo.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let account = dataManager.getAccount(by: transaction.accountId),
                   account.displayName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }
        
        return transactions.sorted { $0.date > $1.date }
    }
    
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        filteredTransactions.groupedByDate()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 거래 목록
                if groupedTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("거래내역")
            .searchable(text: $searchText, prompt: "계좌명 또는 메모 검색")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingQuickEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: filterOptions.selectedAccountIds.isEmpty && filterOptions.dateFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionView()
            }
            .sheet(isPresented: $showingQuickEntry) {
                QuickEntryView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(options: $filterOptions)
            }
            .sheet(item: $selectedTransaction) { transaction in
                AddTransactionView(editTransaction: transaction)
            }
        }
    }
    
    // MARK: - Transaction List
    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    dataManager.deleteTransaction(transaction)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(group.date.dateString)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // 일자별 합계
                        let dayTotal = group.transactions.reduce(0) { sum, tx in
                            sum + (tx.type == .deposit ? tx.amount : -tx.amount)
                        }
                        Text(dayTotal >= 0 ? "+\(dayTotal.currencyFormatted)" : "\(dayTotal.currencyFormatted)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(dayTotal >= 0 ? Color.depositColor : Color.withdrawalColor)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("거래내역이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddSheet = true
            } label: {
                Label("거래 추가하기", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    @EnvironmentObject var dataManager: DataManager
    let transaction: Transaction
    
    private var account: Account? {
        dataManager.getAccount(by: transaction.accountId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 계좌 색상 인디케이터
            Rectangle()
                .fill(account.map { Color.accountColor(for: $0) } ?? .gray)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            
            // 거래 아이콘
            Image(systemName: transaction.type == .deposit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(transaction.type == .deposit ? Color.depositColor : Color.withdrawalColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account?.displayName ?? "삭제된 계좌")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let memo = transaction.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("\(transaction.type.symbol)\(transaction.amount.currencyFormatted)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(transaction.type == .deposit ? Color.depositColor : Color.withdrawalColor)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Account Mini Card
struct AccountMiniCard: View {
    @EnvironmentObject var dataManager: DataManager
    let account: Account
    
    private var stats: AccountStatistics {
        dataManager.getStatistics(for: account)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.accountColor(for: account))
                    .frame(width: 10, height: 10)
                
                Text(account.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(stats.netAmount.currencyFormatted)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
            
            if let limit = account.yearlyLimit {
                let progress = Double(stats.yearlyDeposit) / Double(limit)
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress <= 1.0 ? Color.accountColor(for: account) : .red)
                        .frame(height: 4)
                    
                    Text("남은 한도: \((stats.remainingLimit ?? 0).currencyFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(account.broker)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter View
struct FilterView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @Binding var options: FilterOptions
    
    private var activeAccounts: [Account] {
        dataManager.appData.accounts.filter { $0.isActive }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                accountFilterSection
                dateFilterSection
                typeFilterSection
                resetSection
            }
            .navigationTitle("필터")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var accountFilterSection: some View {
        Section("계좌") {
            ForEach(activeAccounts) { account in
                AccountFilterRow(account: account, selectedIds: $options.selectedAccountIds)
            }
            
            if !options.selectedAccountIds.isEmpty {
                Button("선택 해제") {
                    options.selectedAccountIds.removeAll()
                }
            }
        }
    }
    
    private var dateFilterSection: some View {
        Section("기간") {
            Picker("기간", selection: $options.dateFilter) {
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            
            if options.dateFilter == .custom {
                DatePicker("시작일", selection: Binding(
                    get: { options.customStartDate ?? Date() },
                    set: { options.customStartDate = $0 }
                ), displayedComponents: .date)
                
                DatePicker("종료일", selection: Binding(
                    get: { options.customEndDate ?? Date() },
                    set: { options.customEndDate = $0 }
                ), displayedComponents: .date)
            }
        }
    }
    
    private var typeFilterSection: some View {
        Section("거래 유형") {
            Picker("유형", selection: $options.transactionType) {
                Text("전체").tag(TransactionType?.none)
                ForEach(TransactionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(TransactionType?.some(type))
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var resetSection: some View {
        Section {
            Button("필터 초기화") {
                options = FilterOptions()
            }
            .foregroundStyle(.red)
        }
    }
}

struct AccountFilterRow: View {
    let account: Account
    @Binding var selectedIds: Set<UUID>
    
    private var isSelected: Bool {
        selectedIds.contains(account.id)
    }
    
    var body: some View {
        HStack {
            Text(account.displayName)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedIds.remove(account.id)
            } else {
                selectedIds.insert(account.id)
            }
        }
    }
}

#Preview {
    TransactionListView()
        .environmentObject(DataManager())
}
