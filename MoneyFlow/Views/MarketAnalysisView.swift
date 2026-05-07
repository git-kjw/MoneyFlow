import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct MarketAnalysisView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var tickerInput: String = "SPY"
    @State private var result: MarketAnalysisResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showDetails = true
    @State private var lastAnalyzedTicker: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    inputSection
                    summarySection
                    detailsSection
                    warningSection
                    apiIssueSection
                }
                .padding()
            }
            .navigationTitle("시장분석")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        runLastAnalysis()
                    } label: {
                        Label("새로고침", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(isLoading)
                }
            }
            #endif
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("분석 설정")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("티커")
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack {
                    TextField("예: AAPL, QQQ, SPY", text: $tickerInput)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Button {
                        analyzeTicker()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("분석")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
            }

            HStack(spacing: 8) {
                ForEach(["SPY", "QQQ", "AAPL"], id: \.self) { ticker in
                    Button(ticker) {
                        tickerInput = ticker
                        analyzeTicker()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var summarySection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        if let result {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.ticker)
                            .font(.headline)
                        Text(result.analyzedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(result.signal.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(signalColor(result.signal))
                }

                HStack(spacing: 16) {
                    statItem(title: "총점", value: "\(result.totalScore)점")
                    statItem(title: "신뢰도", value: result.confidence.rawValue)
                    statItem(title: "완성도", value: "\(result.dataCompleteness)%")
                }

                if let overrideReason = result.overrideReason {
                    Text(overrideReason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !result.adjustments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("보정 점수")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(result.adjustments, id: \.self) { adjustment in
                            Text("• \(adjustment)")
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        if let result {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("상세 점수 보기", isOn: $showDetails)
                    .toggleStyle(.switch)

                if showDetails {
                    ForEach(result.indicatorScores) { score in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(score.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(score.valueText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let note = score.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(score.score)")
                                .font(.headline)
                                .foregroundStyle(scoreColor(score.score))
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var apiIssueSection: some View {
        if let result, !result.apiIssues.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("API 호출 오류 상세")
                    .font(.subheadline)
                    .fontWeight(.medium)
                ForEach(result.apiIssues) { issue in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(issue.endpoint)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("사유: \(issue.reason)")
                            .font(.caption)
                        Text(issue.url)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                        Button("URL 복사") {
                            copyToClipboard(issue.url)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var warningSection: some View {
        if let result, !result.warnings.isEmpty {
            let visibleWarnings = Array(result.warnings.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                Text("데이터 경고")
                    .font(.subheadline)
                    .fontWeight(.medium)
                ForEach(visibleWarnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption)
                }
                if result.warnings.count > visibleWarnings.count {
                    Text("외 \(result.warnings.count - visibleWarnings.count)개")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func analyzeTicker() {
        let ticker = tickerInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !ticker.isEmpty else {
            errorMessage = "티커를 입력해주세요."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            let analyzed = await dataManager.analyzeMarket(for: ticker)
            await MainActor.run {
                result = analyzed
                lastAnalyzedTicker = ticker
                isLoading = false
            }
        }
    }

    private func runLastAnalysis() {
        if let lastAnalyzedTicker {
            tickerInput = lastAnalyzedTicker
        }
        analyzeTicker()
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func signalColor(_ signal: MarketSignal) -> Color {
        switch signal {
        case .buy:
            return .green
        case .stay:
            return .orange
        case .sell:
            return .red
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score > 0 { return .green }
        if score < 0 { return .red }
        return .secondary
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

#Preview {
    MarketAnalysisView()
        .environmentObject(DataManager())
}
