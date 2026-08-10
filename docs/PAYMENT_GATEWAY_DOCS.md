# Payment Gateway Developer Documentation & Implementation Prompts

This document provides complete technical specifications, API contracts, architectural flows, and exact developer prompts for both **Direct Payment Gateways** and **Escrow Payment Gateways** using Flutterwave v3 in Flutter/Dart.

---

## 1. Developer Prompt: Direct Payment Gateway (Instant Settlement)

Use this prompt when building or instructing an AI assistant to build a **Direct Payment Gateway** (where money goes straight to the merchant/landlord account immediately without holding in an Escrow vault):

```markdown
### TASK: Implement Direct Flutterwave Instant Payment Gateway

Build a Flutter payment service using Flutterwave API v3 to process instant payments for property bookings.

#### REQUIREMENTS:
1. API Endpoint: `POST https://api.flutterwave.com/v3/virtual-account-numbers` (or Flutterwave Standard Checkout `POST https://api.flutterwave.com/v3/payments`).
2. Authentication: `Authorization: Bearer FLWSECK-xxx`
3. Behavior:
   - Generate a dedicated NUBAN account number (Wema / Providus / Sterling Bank).
   - The user opens any Nigerian bank app (GTBank, Zenith, Kuda, OPay, PalmPay) and transfers funds.
   - Upon payment confirmation via Flutterwave Webhook (`verificaton_status == successful`), immediately credit the merchant/landlord account balance.
4. Error Handling:
   - Handle network failures gracefully.
   - Format account details cleanly on a bottom modal sheet with an instant clipboard copy button.
```

---

## 2. Developer Prompt: Escrow Payment Gateway (Dual-PIN Release)

Use this prompt when building an **Escrow Payment Gateway** (where funds are held in a secure vault until key handover confirmation):

```markdown
### TASK: Implement Flutterwave Escrow Payment Gateway with 6-Digit Handshake PIN

Build an Escrow Payment workflow in Flutter using Flutterwave API v3 & Firebase Firestore.

#### REQUIREMENTS:
1. Vault Hold:
   - Call Flutterwave API to generate dedicated live NUBAN virtual accounts.
   - Tenant transfers funds -> Money enters AGENT LIMITED Flutterwave Merchant Wallet (Status: `held`).
   - Neither tenant nor landlord can withdraw funds while locked in Escrow.
2. Dual 6-Digit Handshake PIN:
   - Generate unique `tenantPin` and `landlordPin` upon transaction initialization.
   - Tenant inputs Landlord's PIN upon receiving property keys.
   - Landlord inputs Tenant's PIN upon handing over keys.
3. Automated Settlement Split:
   - When both PINs are verified (`tenantPinVerified == true` && `landlordPinVerified == true`), transition status to `released`.
   - Call `/transactions/escrow/settle` to disburse **95% Net Payout** to Landlord's bank account and retain **5% Escrow Protection Fee** for platform profit.
```

---

## 3. Flutterwave API v3 Contracts

### Virtual Account Generation Request
- **URL**: `POST https://api.flutterwave.com/v3/virtual-account-numbers`
- **Headers**:
  ```http
  Authorization: Bearer FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X
  Content-Type: application/json
  ```
- **Payload**:
  ```json
  {
    "email": "tenant@example.com",
    "is_permanent": false,
    "tx_ref": "FLW-ESC-TX_17861",
    "firstname": "Victor",
    "lastname": "Odulana",
    "narration": "Escrow Rent FLW-ESC-TX_17861"
  }
  ```

### NIBSS Bank App Name Resolution
When a user opens any commercial banking app (PalmPay, Kuda, GTBank, Zenith, OPay, etc.) and inputs the generated 10-digit NUBAN:
- **NIBSS Response**: `Escrow Rent FLWESCTX17861`
- **Bank Partner**: `Flutterwave MFB` / `Wema Bank`

---

## 4. Code Architecture Reference (`lib/features/payments`)

| File Path | Description |
| :--- | :--- |
| `[EscrowApiService](file:///c:/agent_app/lib/core/services/escrow_api_service.dart)` | Direct HTTP client calling Flutterwave REST endpoints (`/virtual-account-numbers`, `/settle`). |
| `[PaymentRepository](file:///c:/agent_app/lib/features/payments/data/payment_repository.dart)` | Atomic Firestore transaction manager, PIN handshake validator, and payout trigger. |
| `[PaymentScreen](file:///c:/agent_app/lib/features/payments/presentation/screens/payment_screen.dart)` | Responsive bottom modal sheet displaying live NUBAN virtual account details without layout overflow. |
| `[EscrowDetailsScreen](file:///c:/agent_app/lib/features/payments/presentation/screens/escrow_details_screen.dart)` | Dual 6-Digit PIN input screen for tenant and landlord key delivery verification. |
| `[PaymentReceiptDialog](file:///c:/agent_app/lib/features/payments/presentation/widgets/payment_receipt_dialog.dart)` | Printable receipt modal showing official Flutterwave Escrow transaction breakdown. |

---

## 5. Amount Limit & Self-Healing Retry Logic

Flutterwave caps fixed amount parameters on single virtual account creations at **₦7,390,000**.
If a property total package exceeds ₦7.39M (e.g. ₦315,000,000):
- `[EscrowApiService](file:///c:/agent_app/lib/core/services/escrow_api_service.dart)` automatically omits the fixed `"amount"` parameter constraint.
- If Flutterwave ever returns `amount should be between...`, the self-healing retry logic catches the error, strips the amount constraint, and retries instantly to return a live open NUBAN account.
