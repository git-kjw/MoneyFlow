import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    let editTransaction: Transaction?
    
    @State private var selectedAccountId: UUID?
    @State private var amount: String = ""
    @State private var transactionType: TransactionType = .deposit
    @State private var date: Date = Date()
    @State private var memo: String = ""
    
    init(editTransaction: Transaction? = nil) {
        self.editTransaction = editTransaction
    }
    
    private var isEditing: Bool {
        editTransaction != nil
    }
    
    private var isValid: Bool {
        selectedAccountId != nil && (Int(amount) ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 계좌 선택
                Section("계좌") {
                    Picker("계좌 선택", selection: $selectedAccountId) {
                        Text("선택하세요").tag(UUID?.none)
                        ForEach(dataManager.appData.accounts.filter { $0.isActive }) { account in
                            Text(account.displayName).tag(UUID?.some(account.id))
                        }
                    }
                    
                    // 선택된 계좌의 한도 정보 표시
                    if let accountId = selectedAccountId,
                       let account = dataManager.getAccount(by: accountId),
                       let limit = account.yearlyLimit {
                        let stats = dataManager.getStatistics(for: account)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("올해 한도")
                                Spacer()
                                Text(limit.currencyFormatted)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("올해 입금액")
                                Spacer()
                                Text(stats.yearlyDeposit.currencyFormatted)
                                    .foregroundStyle(.blue)
                            }
                            HStack {
                                Text("남은 한도")
                                Spacer()
                                Text((stats.remainingLimit ?? 0).currencyFormatted)
                                    .foregroundStyle((stats.remainingLimit ?? 0) > 0 ? .green : .red)
                            }
                            
                            // 한도 프로그레스 바
                            ProgressView(value: Double(stats.yearlyDeposit), total: Double(limit))
                                .tint(stats.yearlyDeposit <= limit ? .green : .red)
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                    }
                }
                
                // 거래 유형
                Section("거래 유형") {
                    Picker("유형", selection: $transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 금액
                Section("금액") {
                    HStack {
                        TextField("금액 입력", text: $amount)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            #endif
                        Text("원")
                            .foregroundStyle(.secondary)
                    }
                    
                    // 빠른 금액 버튼
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([100000, 500000, 1000000, 5000000, 10000000], id: \.self) { value in
                                Button {
                                    amount = "\(value)"
                                } label: {
                                    Text("+\(value.formatted)")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // 날짜
                Section("날짜") {
                    DatePicker("거래 날짜", selection: $date, displayedComponents: .date)
                }
                
                // 메모
                Section("메모 (선택)") {
                    TextField("메모 입력", text: $memo, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                // 삭제 버튼 (편집 모드)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let transaction = editTransaction {
                                dataManager.deleteTransaction(transaction)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("거래 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "거래 수정" : "거래 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let transaction = editTransaction {
                    selectedAccountId = transaction.accountId
                    amount = "\(transaction.amount)"
                    transactionType = transaction.type
                    date = transaction.date
                    memo = transaction.memo ?? ""
                } else if dataManager.appData.accounts.filter({ $0.isActive }).count == 1 {
                    // 계좌가 하나뿐이면 자동 선택
                    selectedAccountId = dataManager.appData.accounts.first { $0.isActive }?.id
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func saveTransaction() {
        guard let accountId = selectedAccountId,
              let amountValue = Int(amount),
              amountValue > 0 else {
            return
        }
        
        if let existingTransaction = editTransaction {
            var updated = existingTransaction
            updated.accountId = accountId
            updated.amount = amountValue
            updated.type = transactionType
            updated.date = date
            updated.memo = memo.isEmpty ? nil : memo
            dataManager.updateTransaction(updated)
        } else {
            let transaction = Transaction(
                accountId: accountId,
                amount: amountValue,
                type: transactionType,
                date: date,
                memo: memo.isEmpty ? nil : memo
            )
            dataManager.addTransaction(transaction)
        }
        
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .environmentObject(DataManager())
}
