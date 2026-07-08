# User Guide — CSMs and CS Managers

## The health score, in one minute

Every customer gets a 0–100 score, recalculated nightly from four signals:

| Dimension  | What it reads                  | What moves it                                                       |
| ---------- | ------------------------------ | ------------------------------------------------------------------- |
| Adoption   | Product telemetry              | License utilization — shelfware drags it down                       |
| Support    | Open cases, escalations (90d)  | Escalations hurt roughly twice as much as open cases                |
| Engagement | NPS responses (rolling window) | Detractors pull hard; silence means "no signal", not zero           |
| Financial  | Renewal runway                 | Auto-renew is safe; a manual renewal inside 30 days is the red zone |

Score bands: **70+ Low risk · 40–69 Medium · below 40 High**. A dimension with no data is
excluded and its weight shifts to the others — you're never punished for an unmeasured account.

## On the account page (Customer 360)

- **Customer Health panel** — score, risk badge, trend, per-dimension bars and the recent
  trend line. _Recalculate_ refreshes it on demand (e.g., right after closing a wave of cases).
- **Subscriptions panel** — every subscription with ARR, renewal date and days-to-renewal.
  Sort by any column.
- **Log NPS Response** action — customer gave you a score verbally in a QBR? Log it there; the
  account NPS updates immediately.

## What happens automatically

- Activating a subscription opens its **Renewal opportunity** (close date = renewal date,
  amount = ARR). Moving the renewal date moves the opportunity; churn closes it as lost.
- Winning a Renewal opportunity marks the subscription **Renewed**.
- If an account escalates to **High risk**, the owner gets a high-priority task within moments
  — that's the churn playbook, and your admin can change what it does.
- Accounts with a CSM but no NPS signal generate a weekly "request a survey" task.

## CS Command Center (managers)

- **KPI tiles**: scored customers, active ARR, ARR at risk (High-risk accounts), renewals due
  in 90 days.
- **Churn risk distribution**: portfolio shape at a glance.
- **Triage list**: worst score first, filter by band, _Load more_ pages through.
- **Renewal workspace**: open renewals inside 30/60/90/180 days, most urgent first; scroll to
  load more, click through to the opportunity.

You see only the accounts your role and team grants you — the dashboards respect sharing, so a
manager's numbers are their team's book, not the whole company's.
