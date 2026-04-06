# MoneyFlow - 계좌 입출금 관리 앱

macOS와 iOS에서 사용 가능한 Universal 계좌 입출금 내역 관리 앱입니다.

## 주요 기능

### 거래 관리
- 날짜별 입출금 내역 기록
- 입금/출금 구분
- 메모 기능
- 검색 및 필터링 (계좌별, 기간별, 유형별)

### 계좌 관리
- 계좌 추가/수정/삭제
- 5개 기본 계좌 제공:
  - 종합매매 (나무)
  - ISA (나무) - 연 2,000만원 한도
  - CMA (나무)
  - 연금저축 (한투) - 연 1,800만원 한도
  - IRP (한투) - 연 900만원 한도

### 납입 한도 관리
- 연간 납입 한도 설정
- 올해 입금액 / 남은 한도 실시간 확인
- 진행률 표시

### 통계
- 연간/월별 입출금 통계
- 계좌별 현황
- 차트 시각화

## 🔄 iCloud Drive 동기화 (무료 계정 지원!)

**무료 Apple 계정**으로도 맥북과 아이폰 간 데이터 동기화가 가능합니다.

### 동기화 설정 방법

1. **첫 번째 기기 (예: 맥북)**
   - 앱 실행 → "새 파일로 저장" 선택
   - **iCloud Drive** 폴더 선택 (예: `iCloud Drive/MoneyFlow/`)
   - `MoneyFlowData.json`으로 저장

2. **두 번째 기기 (예: 아이폰)**
   - 앱 실행 → "기존 파일 열기" 선택
   - iCloud Drive에서 같은 파일 선택

3. **완료!**
   - 이제 양쪽 기기에서 데이터가 자동 동기화됩니다
   - 한쪽에서 수정하면 다른 쪽에서도 반영됩니다

### 동기화 원리
- 앱은 iCloud Drive에 저장된 JSON 파일을 직접 읽고 씁니다
- iCloud Drive가 파일 변경을 감지하면 자동으로 다른 기기에 동기화
- 개발자 계정 없이 무료 계정만으로 동작합니다

## 개발 환경

- Swift 5
- SwiftUI
- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+

## 빌드 방법

```bash
# Xcode에서 열기
open MoneyFlow.xcodeproj

# 또는 터미널에서 빌드
xcodebuild -project MoneyFlow.xcodeproj -scheme MoneyFlow -destination 'platform=macOS' build
```

## 앱 실행 (개발자 모드)

1. Xcode에서 `MoneyFlow.xcodeproj` 열기
2. Signing & Capabilities에서 Team을 본인 Apple ID로 설정
3. ⌘R로 실행 (macOS) 또는 iPhone 연결 후 실행

## iPhone에 설치하기 (무료 계정)

1. Xcode에서 프로젝트 열기
2. Signing & Capabilities에서 Team을 본인 Apple ID로 설정
3. iPhone을 Mac에 USB로 연결
4. 실행 대상을 연결된 iPhone으로 선택
5. ⌘R로 실행

**참고**: 무료 계정은 7일마다 앱을 다시 설치해야 합니다.

## 파일 구조

```
MoneyFlow/
├── MoneyFlowApp.swift      # 앱 진입점
├── ContentView.swift       # 메인 뷰 + 파일 관리
├── Models/
│   ├── Models.swift        # 데이터 모델 (Account, Transaction)
│   ├── Extensions.swift    # 유틸리티 확장
│   └── ColorExtensions.swift
├── Views/
│   ├── TransactionListView.swift  # 거래 목록
│   ├── AddTransactionView.swift   # 거래 추가/수정
│   ├── AccountListView.swift      # 계좌 목록
│   ├── AccountEditView.swift      # 계좌 추가/수정
│   └── StatisticsView.swift       # 통계
└── Services/
    └── DataManager.swift   # 데이터 관리 + 파일 I/O
```

## 라이선스

개인 사용 목적
