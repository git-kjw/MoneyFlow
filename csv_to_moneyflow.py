#!/usr/bin/env python3
"""
CSV to MoneyFlow JSON Converter
CSV 파일의 입출금 내역을 MoneyFlow 앱의 JSON 형식으로 변환합니다.
"""

import csv
import json
import uuid
from datetime import datetime
from pathlib import Path

# 계좌 이름 매핑 (CSV 컬럼명 -> MoneyFlow 계좌명)
ACCOUNT_MAPPING = {
    "종합매매": {"name": "종합매매", "broker": "나무", "color": "blue"},
    "ISA": {"name": "ISA", "broker": "나무", "color": "purple"},
    "연금저축": {"name": "연금저축", "broker": "한투", "color": "orange"},
    "IRP": {"name": "IRP", "broker": "한투", "color": "pink"},
    "CMA": {"name": "CMA", "broker": "나무", "color": "teal"}
}

def parse_amount(amount_str):
    """금액 문자열을 숫자로 변환 (예: "13,000,000" -> 13000000)"""
    if not amount_str or amount_str.strip() == "":
        return None
    # 음수 처리 (예: "-10,000,000")
    is_negative = amount_str.strip().startswith("-")
    # 쉼표 제거하고 숫자만 추출
    cleaned = amount_str.replace(",", "").replace("-", "").strip()
    if not cleaned:
        return None
    amount = int(cleaned)
    return -amount if is_negative else amount

def parse_date(date_str):
    """날짜 문자열을 ISO 8601 형식으로 변환"""
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        return dt.isoformat() + "Z"
    except:
        return None

def create_account(name, broker, color="blue", yearly_limit=None):
    """MoneyFlow 계좌 객체 생성"""
    return {
        "id": str(uuid.uuid4()).upper(),
        "name": name,
        "broker": broker,
        "yearlyLimit": yearly_limit,
        "colorName": color,
        "isActive": True,
        "createdAt": datetime.now().isoformat() + "Z"
    }

def create_transaction(account_id, amount, transaction_type, date, memo=None):
    """MoneyFlow 거래 객체 생성"""
    return {
        "id": str(uuid.uuid4()).upper(),
        "accountId": account_id,
        "amount": abs(amount),
        "type": transaction_type,
        "date": date,
        "memo": memo,
        "createdAt": datetime.now().isoformat() + "Z"
    }

def convert_csv_to_moneyflow(csv_path, existing_json_path=None):
    """CSV 파일을 MoneyFlow JSON 형식으로 변환"""
    
    # 기존 JSON 로드 (있는 경우)
    if existing_json_path and Path(existing_json_path).exists():
        with open(existing_json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print(f"✅ 기존 JSON 파일 로드: {existing_json_path}")
        print(f"   - 계좌 {len(data['accounts'])}개, 거래내역 {len(data['transactions'])}개")
    else:
        # 새로운 데이터 구조 생성
        data = {
            "accounts": [],
            "transactions": [],
            "lastUpdated": datetime.now().isoformat() + "Z"
        }
    
    # 계좌 ID 매핑 (계좌명 -> UUID)
    account_ids = {}
    
    # 기존 계좌 확인 및 새 계좌 추가
    for account_name, account_info in ACCOUNT_MAPPING.items():
        # 기존 계좌 찾기
        existing = next(
            (acc for acc in data['accounts'] 
             if acc['name'] == account_info['name'] and acc['broker'] == account_info['broker']),
            None
        )
        
        if existing:
            account_ids[account_name] = existing['id']
        else:
            # 새 계좌 생성
            yearly_limit = None
            if account_name == "ISA":
                yearly_limit = 20000000
            elif account_name == "연금저축":
                yearly_limit = 18000000
            elif account_name == "IRP":
                yearly_limit = 9000000
            
            new_account = create_account(
                account_info['name'],
                account_info['broker'],
                account_info['color'],
                yearly_limit
            )
            data['accounts'].append(new_account)
            account_ids[account_name] = new_account['id']
            print(f"✨ 새 계좌 추가: {account_info['name']} ({account_info['broker']})")
    
    # CSV 파일 읽기
    transactions_added = 0
    with open(csv_path, 'r', encoding='utf-8') as f:
        # 첫 번째 행(설명) 건너뛰기
        next(f)
        reader = csv.DictReader(f)
        
        for row in reader:
            date_str = row.get('날짜', '').strip()
            if not date_str or date_str == "":
                continue
            
            date_iso = parse_date(date_str)
            if not date_iso:
                continue
            
            # 각 계좌별 거래 처리
            for account_name in ACCOUNT_MAPPING.keys():
                amount_str = row.get(account_name, '').strip()
                amount = parse_amount(amount_str)
                
                if amount is None:
                    continue
                
                # 입금/출금 구분 (음수는 출금, 양수는 입금)
                if amount < 0:
                    transaction_type = "출금"
                else:
                    transaction_type = "입금"
                
                # 거래 생성
                transaction = create_transaction(
                    account_id=account_ids[account_name],
                    amount=amount,
                    transaction_type=transaction_type,
                    date=date_iso,
                    memo=f"{date_str} {account_name}"
                )
                
                data['transactions'].append(transaction)
                transactions_added += 1
    
    # lastUpdated 갱신
    data['lastUpdated'] = datetime.now().isoformat() + "Z"
    
    print(f"\n✅ 변환 완료!")
    print(f"   - 총 계좌: {len(data['accounts'])}개")
    print(f"   - 총 거래내역: {len(data['transactions'])}개")
    print(f"   - 새로 추가된 거래: {transactions_added}개")
    
    return data

def main():
    import sys
    
    if len(sys.argv) < 2:
        print("사용법: python csv_to_moneyflow.py <CSV파일경로> [기존JSON파일경로]")
        print("예시: python csv_to_moneyflow.py input.csv")
        print("예시: python csv_to_moneyflow.py input.csv existing.json")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    existing_json = sys.argv[2] if len(sys.argv) > 2 else None
    
    # 변환
    data = convert_csv_to_moneyflow(csv_path, existing_json)
    
    # JSON 파일로 저장
    output_path = "MoneyFlowData.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\n💾 저장 완료: {output_path}")
    print(f"\n다음 단계:")
    print(f"1. MoneyFlow 앱 실행")
    print(f"2. '기존 파일 열기' 선택")
    print(f"3. {output_path} 파일 선택")

if __name__ == "__main__":
    main()
