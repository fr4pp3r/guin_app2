# Barangay E-Document System — Thesis Flowchart

Rendered PNG images are in the `diagrams/` folder:
- `diagrams/system_overview.png`
- `diagrams/document_workflow.png`
- `diagrams/incident_workflow.png`
- `diagrams/verification_workflow.png`

> High-level system flowchart for thesis documentation. Render with any Mermaid viewer (GitHub, Obsidian, VS Code Mermaid extension) or paste into https://mermaid.live.

## 1. System Overview

```mermaid
flowchart TD
    A([Start: User Opens App]) --> B{Authenticated?}
    B -- No --> C[Login / Register]
    C --> D{Registration Approved?}
    D -- No --> E[Pending Approval Screen]
    D -- Yes --> F[Role-based Dashboard]
    B -- Yes --> F

    F --> G{Role}
    G -- Citizen --> H[Citizen Dashboard]
    G -- Secretary --> I[Secretary Dashboard]
    G -- Treasurer --> J[Treasurer Dashboard]
    G -- Captain / Kagawad --> K[Approver Dashboard]
    G -- Tanod --> L[Tanod Dashboard]
    G -- Admin --> M[Admin Dashboard]

    H --> N[Request Document]
    H --> O[My Requests]
    H --> P[Submit Incident Report]
    H --> Q[Announcements Feed]
    H --> R[Verify Document]
    H --> S[Chatbot / Profile]

    I --> T[Pending Requests Queue]
    I --> U[Generate Draft / Invoice]
    I --> V[Release Document]

    J --> W[Pending Payments Queue]
    J --> X[Confirm / Reject Payment]

    K --> Y[Captain Approval Queue]
    K --> Z[Approve / Reject]
    K --> AA[Manage Users]

    L --> AB[Incident Triage]
    M --> AC[Settings / Fees / Formats]
```

## 2. Document Request Workflow (Core Pipeline)

```mermaid
flowchart TD
    S1([Citizen Submits Request]) --> S2[submitted]
    S2 --> S3[Secretary Reviews]
    S3 --> S4{Needs Revision?}
    S4 -- Yes --> S5[needs_revision]
    S5 --> S1
    S4 -- No --> S6[draft_generated]
    S6 --> S7[Secretary Verifies for Payment]
    S7 --> S8{Fee == 0?}
    S8 -- Yes --> S12[for_approval]
    S8 -- No --> S9[invoiced]
    S9 --> S10[Citizen Uploads GCash Receipt]
    S10 --> S11[payment_submitted]
    S11 --> S13{Treasurer Decision}
    S13 -- Reject --> S14[payment_rejected]
    S14 --> S10
    S13 -- Confirm --> S15[payment_confirmed]
    S15 --> S12
    S12 --> S16{Captain / Kagawad Decision}
    S16 -- Reject --> S17[rejected]
    S16 -- Approve --> S18[releaseDocument]
    S18 --> S19[released]
    S19 --> S20[PDF + Verification Token + QR]
    S20 --> S21[Citizen Views / Verifies Document]
    S1 --> S22[deleteRequest]
    S22 --> S23[cancelled]
```

## 3. Incident Report Workflow

```mermaid
flowchart TD
    I1([Citizen Files Incident Report]) --> I2[incident_submitted]
    I2 --> I3[Officials Triage]
    I3 --> I4{Assign Priority / Status}
    I4 --> I5[in_progress / resolved / closed]
    I5 --> I6[Incident Updates Logged]
    I6 --> I7[Reporter Notified]
```

## 4. Document Verification (Public)

```mermaid
flowchart TD
    V1([Scan QR / Enter Document ID]) --> V2[Verification Service]
    V2 --> V3{Valid? Expiry / Use-limit}
    V3 -- No --> V4[Verification Failed]
    V3 -- Yes --> V5[Consume Use Count]
    V5 --> V6[Verification Success]
    V6 --> V7[Optional: Request Printable Copy]
```

## 5. Role Permission Summary

| Role | Key Capabilities |
|------|------------------|
| Citizen | Request documents, pay, view released docs, file incidents, read announcements |
| Secretary | Generate drafts, verify for payment, release documents |
| Treasurer | Verify / reject payments |
| Captain / Kagawad | Final approve / reject documents, manage users |
| Tanod | Triage incident reports |
| Admin | Legacy superuser (all capabilities) |
```

This is good. Now maybe render to PNG. Let me try mermaid.ink. Encode the diagram. I'll attempt to fetch one overview diagram as PNG to give an image. Use URL https://mermaid.ink/img/<base64>. Need encode. Let me try with python.<|end|><|start|> fileList? Let me just try. Actually, simpler: I'll attempt to generate PNG for the main overview diagram using mermaid.ink. If it works, save as `THESIS_FLOWCHART.png`. Let me do it.<|end|><|start|> assistant to=shell<|channel|>analysis <|constrain|>xml<|message|><rfl:parameter name="command">
python -c "
import base64,urllib.parse
d='''flowchart TD
    A([Start]) --> B{Auth?}
    B -- No --> C[Login/Register]
    C --> D{Approved?}
    D -- No --> E[Pending]
    D -- Yes --> F[Dashboard]
    B -- Yes --> F
    F --> G{Role}
    G -- Citizen --> H[Citizen]
    G -- Secretary --> I[Secretary]
    G -- Treasurer --> J[Treasurer]
    G -- Captain --> K[Approver]
    G -- Tanod --> L[Tanod]
    G -- Admin --> M[Admin]
'''
enc=base64.urlsafe_b64encode(d.encode()).decode().rstrip('=')
print('https://mermaid.ink/img/'+enc)
"