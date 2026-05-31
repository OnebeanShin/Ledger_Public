# Ledger — hledger 가계부 + 웹 대시보드 + AI 회계사

자연어로 기록하고, 웹에서 보는 개인 가계부 배포판.

- **hledger**(플레인 텍스트 복식부기 회계)로 데이터를 저장하고,
- **웹 대시보드(webui)** 로 요약·거래·분석·투자·결산을 시각적으로 조회하며,
- **`AGENTS.md`** 를 AI 도구에 물려 *"어제 점심 9천 원 썼어"* 같은 **자연어를 회계 거래로** 자동 기록한다.

> 데이터는 전부 **내 컴퓨터의 텍스트 파일**(`*.journal`)에 저장됩니다. 외부 전송 없음.

## 요구사항
- macOS (Linux도 대부분 동작) + Python 3.10+
- **hledger** 1.30 이상 — `-O json` 지원 필요
- **Flask** (Python 패키지)
- (선택) **pricehist** — 주식/코인 시세 자동 갱신용

## 설치
```bash
# 1) hledger 설치 (macOS, Homebrew)
brew install hledger

# 2) 웹 대시보드 의존성 설치
cd "<이 폴더>/webui"
pip3 install -r requirements.txt

# 3) (선택) 시세 자동 갱신 도구
python3 -m venv "../.venv-pricehist" && ../.venv-pricehist/bin/pip install pricehist
```

## 빠른 시작
```bash
# 웹 대시보드 실행 (둘 중 하나)
open webui/run.command          # Finder에서 더블클릭해도 됨
# 또는
./webui/run.sh
```
브라우저에서 **http://127.0.0.1:5001** 접속. (포트 변경: `PORT=5002 ./webui/run.sh`)

## 가계부 쓰는 법
### 방법 A — 직접 편집
`2026.journal`(올해 파일)에 거래를 추가한다. 형식은 파일 안 예시 참고. 새 연도는 `YYYY.journal`을 만들고
`main.journal`에 `include YYYY.journal` 한 줄 추가.

### 방법 B — 자연어(AI 회계사) ★추천
이 폴더(특히 `AGENTS.md`)를 **파일 접근이 되는 AI 도구**(Claude Code/Codex/Kiro 등)에 컨텍스트로 준 뒤
자연어로 말하면 된다.
- "어제 마트에서 3만 2천 원 장 봤어" → `expenses:food:grocery` 거래로 기록
- "월급 250 들어왔어" → `income:salary` 거래로 기록
AI는 `AGENTS.md` 규칙대로 복식부기로 기록하고 `hledger check`로 검증한다.

## 투자 시세 (선택)
주식/코인을 `{USD 190.00}` 처럼 매수 단가와 함께 기록했다면:
```bash
./scripts/update-prices.sh            # prices.journal 자동 갱신(pricehist 필요)
python3 scripts/investment-gain.py    # 평가손익(매수일 환율 기준)
```

## 폴더 구조
```
Ledger/
├── AGENTS.md            AI 회계사 운영 매뉴얼(자연어 기록 규칙)
├── README.md            이 문서
├── main.journal         시작 파일(연도/시세 파일 include)
├── 2026.journal         올해 거래 (예시 데이터 → 본인 것으로 교체)
├── prices.journal       자동 생성 시세
├── scripts/
│   ├── update-prices.sh     시세 갱신(Yahoo Finance, pricehist)
│   └── investment-gain.py   평가손익 계산
└── webui/               웹 대시보드 (Flask + 정적 모듈)
    ├── run.command / run.sh / run_silent.command
    ├── launchd/com.example.ledger-webui.plist  자동 시작 템플릿(선택)
    └── README.md            대시보드 상세 문서
```

## 결산 탭 (선택)
대시보드의 **결산** 탭은 `webui/report/<YYYY-MM>/` 폴더에 넣어둔 월별 리포트(`*.html`)를 보여줍니다.
리포트가 없으면 빈 상태로 표시되며(정상), HTML 리포트를 직접 만들어 해당 경로에 두면 자동으로 목록에 나타납니다.

## 보안
- 웹 서버는 기본적으로 **로컬(127.0.0.1)·동일 LAN·Tailscale 대역만** 허용한다. 같은 Wi‑Fi의 임의 기기는 차단(403).
- 외부 공개가 필요하면 `WEBUI_ALLOWED_CLIENT_NETWORKS` 환경변수로 직접 제어(주의해서 설정).
- 가계부 데이터는 로컬 텍스트 파일에만 저장되며 어디로도 전송되지 않는다.

## 자동 시작 (선택, macOS)
`webui/launchd/com.example.ledger-webui.plist` 템플릿의 `__LEDGER_DIR__`를 설치 경로로 바꾸고
`~/Library/LaunchAgents/`에 복사한 뒤 `launchctl load` 한다. (자세한 사용법은 plist 주석 참고)

## 처음 시작 시
1. `2026.journal`의 **예시 거래를 지우고** 본인 기초 잔액·거래로 시작.
2. 이 대시보드는 **KRW 기준**으로 집계한다(요약·대차대조표·예금잔액 모두 KRW). 다른 기준통화가 필요하면 `webui/hledger_api.py`의 `"KRW"`를 직접 수정한다.
3. 계정 분류는 `AGENTS.md`의 예시를 참고해 본인에 맞게 확장.

## 라이선스/주의
- 이 배포판에는 **개인 금융 데이터가 포함되어 있지 않습니다**(샘플 예시만 제공).
- 웹 대시보드 UI는 한국어입니다. Chart.js는 동봉(오프라인 동작).
