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
                    VStack(alignment: .leading, spacing: 12) {
                        // 메인 금액 입력
                        HStack {
                            TextField("0", text: $amount)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                #endif
                                .font(.title2)
                                .fontWeight(.semibold)
                                .onChange(of: amount) { oldValue, newValue in
                                    formatAmountInput(newValue)
                                }
                            Text("원")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 실제 숫자 표시
                        if let numericAmount = extractNumericValue(from: amount), numericAmount > 0 {
                            Text(numericAmount.currencyFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 빠른 금액 버튼 - 일반적인 금액들
                        VStack(alignment: .leading, spacing: 8) {
                            Text("빠른 입력")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(quickAmountButtons, id: \.amount) { button in
                                    Button {
                                        setAmount(button.amount)
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(button.title)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text(button.amount.formatted + "원")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // 추가 금액 버튼 - 큰 금액들
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([5000000, 10000000, 20000000, 50000000], id: \.self) { value in
                                    Button {
                                        setAmount(value)
                                    } label: {
                                        Text(value.formatted + "원")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 1)
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
    
    private var quickAmountButtons: [QuickAmountButton] {
        [
            QuickAmountButton(title: "1만원", amount: 10000),
            QuickAmountButton(title: "5만원", amount: 50000),
            QuickAmountButton(title: "10만원", amount: 100000),
            QuickAmountButton(title: "50만원", amount: 500000),
            QuickAmountButton(title: "100만원", amount: 1000000),
            QuickAmountButton(title: "500만원", amount: 5000000)
        ]
    }
    
    private func formatAmountInput(_ input: String) {
        // 숫자만 추출
        let numbersOnly = input.filter { $0.isNumber }
        
        // 너무 긴 숫자 제한 (10자리까지)
        let limitedNumbers = String(numbersOnly.prefix(10))
        
        // 포매팅된 문자열로 업데이트
        if let number = Int(limitedNumbers), number > 0 {
            amount = number.formatted
        } else if limitedNumbers.isEmpty {
            amount = ""
        }
    }
    
    private func extractNumericValue(from input: String) -> Int? {
        let numbersOnly = input.filter { $0.isNumber }
        return Int(numbersOnly)
    }
    
    private func setAmount(_ value: Int) {
        amount = value.formatted
    }
    
    private var isValid: Bool {
        selectedAccountId != nil && (extractNumericValue(from: amount) ?? 0) > 0
    }
    
    private func saveTransaction() {
        guard let accountId = selectedAccountId,
              let amountValue = extractNumericValue(from: amount),
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

// MARK: - Quick Amount Button
struct QuickAmountButton {
    let title: String
    let amount: Int
}

#Preview {
    AddTransactionView()
        .environmentObject(DataManager())
}
