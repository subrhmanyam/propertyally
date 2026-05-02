"""
Pre-built notification templates for common property management events.

Each template returns a dict with keys:
  subject      — email subject
  html_body    — HTML email body
  text_body    — plain-text email body (also used for SMS/WhatsApp fallback)
  sms_body     — short SMS body (≤160 chars recommended)
  whatsapp_body — WhatsApp body (can include emojis, slightly richer than SMS)

Call render(event_type, **vars) to get the rendered template dict.
Unknown event types raise KeyError.
"""

from __future__ import annotations

from typing import Any


def _html_wrap(title: str, content: str) -> str:
    """Minimal HTML email wrapper with Bogineni branding."""
    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 0; }}
  .container {{ max-width: 600px; margin: 32px auto; background: #fff;
                border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,.08); }}
  .header {{ background: #1a1a2e; color: #fff; padding: 24px 32px; }}
  .header h1 {{ margin: 0; font-size: 20px; font-weight: 600; }}
  .header p {{ margin: 4px 0 0; font-size: 13px; opacity: .7; }}
  .body {{ padding: 32px; color: #333; line-height: 1.6; }}
  .body h2 {{ margin-top: 0; color: #1a1a2e; }}
  .highlight {{ background: #f0f4ff; border-left: 4px solid #4361ee;
                padding: 12px 16px; border-radius: 4px; margin: 16px 0; }}
  .footer {{ background: #f8f8f8; padding: 16px 32px; font-size: 12px; color: #999; }}
  .btn {{ display: inline-block; background: #4361ee; color: #fff; padding: 12px 24px;
          border-radius: 6px; text-decoration: none; font-weight: 600; margin-top: 16px; }}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>Bogineni Group</h1>
    <p>Property Management</p>
  </div>
  <div class="body">
    <h2>{title}</h2>
    {content}
  </div>
  <div class="footer">
    This is an automated message from Bogineni Group Property Management.
    Please do not reply to this email.
  </div>
</div>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Template definitions
# ---------------------------------------------------------------------------

_TEMPLATES: dict[str, Any] = {

    # ------------------------------------------------------------------
    # Rent invoice generated
    # ------------------------------------------------------------------
    "invoice_generated": {
        "subject": "Invoice #{invoice_no} — {month} | {company_name}",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>Your invoice for <strong>{v['month']}</strong> has been generated.</p>
<div class="highlight">
  <strong>Invoice No:</strong> {v['invoice_no']}<br>
  <strong>Amount:</strong> ₹{v['amount']:,.2f}<br>
  <strong>Due Date:</strong> {v['due_date']}
</div>
<p>Please make the payment by the due date to avoid late charges.</p>
{f'<a href="{v["payment_url"]}" class="btn">Pay Now</a>' if v.get('payment_url') else ''}
<p>For any queries, contact us at {v.get('owner_email', 'admin@bogineni.com')}.</p>
""",
        "text_content": lambda v: (
            f"Dear {v['tenant_name']},\n\n"
            f"Invoice #{v['invoice_no']} for {v['month']} — Amount: ₹{v['amount']:,.2f}\n"
            f"Due Date: {v['due_date']}\n\n"
            f"{'Pay online: ' + v['payment_url'] + chr(10) if v.get('payment_url') else ''}"
            f"Contact: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
        "sms_content": lambda v: (
            f"Bogineni Group: Invoice #{v['invoice_no']} for {v['month']} "
            f"Amt: Rs.{v['amount']:,.0f} Due: {v['due_date']}"
        ),
        "whatsapp_content": lambda v: (
            f"*Bogineni Group — Invoice Generated* 🧾\n\n"
            f"Dear {v['tenant_name']},\n"
            f"Invoice *#{v['invoice_no']}* for *{v['month']}*\n"
            f"Amount: *₹{v['amount']:,.2f}*\n"
            f"Due Date: {v['due_date']}\n\n"
            f"{('Pay online: ' + v['payment_url'] + chr(10)) if v.get('payment_url') else ''}"
            f"Queries: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
    },

    # ------------------------------------------------------------------
    # Rent overdue
    # ------------------------------------------------------------------
    "rent_overdue": {
        "subject": "REMINDER: Rent overdue for {month} — ₹{amount:,.0f}",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>This is a reminder that your rent for <strong>{v['month']}</strong> is overdue.</p>
<div class="highlight" style="border-color:#e74c3c;background:#fff5f5">
  <strong>Invoice No:</strong> {v['invoice_no']}<br>
  <strong>Amount Due:</strong> ₹{v['amount']:,.2f}<br>
  <strong>Original Due Date:</strong> {v['due_date']}<br>
  <strong>Days Overdue:</strong> {v.get('days_overdue', 'N/A')}
</div>
<p>Please clear this immediately to avoid further charges.</p>
{f'<a href="{v["payment_url"]}" class="btn">Pay Now</a>' if v.get('payment_url') else ''}
""",
        "text_content": lambda v: (
            f"REMINDER: Rent for {v['month']} overdue.\n"
            f"Invoice #{v['invoice_no']} — Amount: ₹{v['amount']:,.2f}\n"
            f"Original due: {v['due_date']}. Please pay immediately."
        ),
        "sms_content": lambda v: (
            f"REMINDER: Bogineni Group — Rent overdue for {v['month']} "
            f"Rs.{v['amount']:,.0f}. Please pay immediately."
        ),
        "whatsapp_content": lambda v: (
            f"⚠️ *Rent Overdue — Action Required*\n\n"
            f"Dear {v['tenant_name']},\n"
            f"Rent for *{v['month']}* is overdue.\n"
            f"Amount: *₹{v['amount']:,.2f}*\n"
            f"Due Date: {v['due_date']}\n\n"
            f"Please pay immediately to avoid late charges.\n"
            f"{('Pay: ' + v['payment_url']) if v.get('payment_url') else ''}"
        ),
    },

    # ------------------------------------------------------------------
    # Payment received
    # ------------------------------------------------------------------
    "payment_received": {
        "subject": "Payment Received — ₹{amount:,.0f} for {month}",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>We have received your payment. Thank you!</p>
<div class="highlight" style="border-color:#27ae60;background:#f0fff4">
  <strong>Amount Paid:</strong> ₹{v['amount']:,.2f}<br>
  <strong>Month:</strong> {v['month']}<br>
  <strong>Reference No:</strong> {v.get('reference_no', 'N/A')}<br>
  <strong>Date:</strong> {v['payment_date']}
</div>
<p>Your account is now clear. Thank you for timely payment.</p>
""",
        "text_content": lambda v: (
            f"Payment received: ₹{v['amount']:,.2f} for {v['month']}.\n"
            f"Ref: {v.get('reference_no', 'N/A')}. Date: {v['payment_date']}. Thank you!"
        ),
        "sms_content": lambda v: (
            f"Bogineni Group: Payment of Rs.{v['amount']:,.0f} received for {v['month']}. "
            f"Ref: {v.get('reference_no', 'N/A')}. Thank you!"
        ),
        "whatsapp_content": lambda v: (
            f"✅ *Payment Received*\n\n"
            f"Dear {v['tenant_name']},\n"
            f"Amount: *₹{v['amount']:,.2f}*\n"
            f"Month: {v['month']}\n"
            f"Ref No: {v.get('reference_no', 'N/A')}\n"
            f"Date: {v['payment_date']}\n\n"
            f"Thank you for your timely payment! 🙏"
        ),
    },

    # ------------------------------------------------------------------
    # Welcome tenant
    # ------------------------------------------------------------------
    "welcome_tenant": {
        "subject": "Welcome to {property_name} — Bogineni Group",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>Welcome to <strong>{v['property_name']}</strong>! We are delighted to have you as our tenant.</p>
<div class="highlight">
  <strong>Unit:</strong> {v['unit_name']}<br>
  <strong>Lease Start:</strong> {v['lease_start']}<br>
  <strong>Rent:</strong> ₹{v['rent_amount']:,.2f} / month<br>
  <strong>Due Date:</strong> {v.get('due_day', '5th')} of each month
</div>
{f'<p>Access your tenant portal: <a href="{v["portal_url"]}">Click here</a></p>' if v.get('portal_url') else ''}
<p>For any assistance, contact us at {v.get('owner_email', 'admin@bogineni.com')}.</p>
""",
        "text_content": lambda v: (
            f"Welcome to {v['property_name']}!\n"
            f"Unit: {v['unit_name']} | Lease from: {v['lease_start']}\n"
            f"Rent: ₹{v['rent_amount']:,.2f}/month | Due: {v.get('due_day', '5th')} of month\n"
            f"Contact: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
        "sms_content": lambda v: (
            f"Welcome to {v['property_name']}! Unit: {v['unit_name']} "
            f"Lease from {v['lease_start']}. Rent: Rs.{v['rent_amount']:,.0f}/month."
        ),
        "whatsapp_content": lambda v: (
            f"🎉 *Welcome to {v['property_name']}!*\n\n"
            f"Dear {v['tenant_name']},\n"
            f"We're glad to have you! Here are your details:\n\n"
            f"🏢 Unit: *{v['unit_name']}*\n"
            f"📅 Lease Start: {v['lease_start']}\n"
            f"💰 Rent: *₹{v['rent_amount']:,.2f}/month*\n"
            f"📆 Due: {v.get('due_day', '5th')} of each month\n\n"
            f"Contact: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
    },

    # ------------------------------------------------------------------
    # Lease expiry reminder
    # ------------------------------------------------------------------
    "lease_expiry": {
        "subject": "Lease Expiry Reminder — {days_left} days remaining",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>Your lease for <strong>{v['unit_name']}</strong> at {v['property_name']} is expiring soon.</p>
<div class="highlight" style="border-color:#f39c12;background:#fffbf0">
  <strong>Lease End Date:</strong> {v['lease_end']}<br>
  <strong>Days Remaining:</strong> {v['days_left']}
</div>
<p>Please contact us to discuss renewal or vacating procedures.</p>
<p>Contact: {v.get('owner_email', 'admin@bogineni.com')}</p>
""",
        "text_content": lambda v: (
            f"Your lease for {v['unit_name']} at {v['property_name']} "
            f"expires on {v['lease_end']} ({v['days_left']} days left). "
            f"Contact: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
        "sms_content": lambda v: (
            f"Bogineni Group: Your lease for {v['unit_name']} expires on {v['lease_end']} "
            f"({v['days_left']} days). Please contact us to renew."
        ),
        "whatsapp_content": lambda v: (
            f"⏰ *Lease Expiry Reminder*\n\n"
            f"Dear {v['tenant_name']},\n"
            f"Your lease for *{v['unit_name']}* at {v['property_name']} "
            f"expires on *{v['lease_end']}* ({v['days_left']} days remaining).\n\n"
            f"Please contact us to discuss renewal.\n"
            f"📧 {v.get('owner_email', 'admin@bogineni.com')}"
        ),
    },

    # ------------------------------------------------------------------
    # Maintenance request update
    # ------------------------------------------------------------------
    "maintenance_update": {
        "subject": "Maintenance Request #{ticket_id} — {status}",
        "html_content": lambda v: f"""
<p>Dear {v['tenant_name']},</p>
<p>Your maintenance request has been updated.</p>
<div class="highlight">
  <strong>Ticket:</strong> #{v['ticket_id']}<br>
  <strong>Issue:</strong> {v['issue']}<br>
  <strong>Status:</strong> <strong>{v['status']}</strong><br>
  {f"<strong>Notes:</strong> {v['notes']}<br>" if v.get('notes') else ''}
  {f"<strong>Scheduled:</strong> {v['scheduled_date']}<br>" if v.get('scheduled_date') else ''}
</div>
<p>For queries, contact {v.get('owner_email', 'admin@bogineni.com')}.</p>
""",
        "text_content": lambda v: (
            f"Maintenance #{v['ticket_id']} — {v['issue']}\n"
            f"Status: {v['status']}\n"
            f"{('Notes: ' + v['notes'] + chr(10)) if v.get('notes') else ''}"
            f"{('Scheduled: ' + v['scheduled_date']) if v.get('scheduled_date') else ''}"
        ),
        "sms_content": lambda v: (
            f"Bogineni Group: Maintenance #{v['ticket_id']} ({v['issue']}) "
            f"status: {v['status']}."
        ),
        "whatsapp_content": lambda v: (
            f"🔧 *Maintenance Update*\n\n"
            f"Ticket *#{v['ticket_id']}*: {v['issue']}\n"
            f"Status: *{v['status']}*\n"
            f"{('Notes: ' + v['notes'] + chr(10)) if v.get('notes') else ''}"
            f"{('Scheduled: ' + v['scheduled_date'] + chr(10)) if v.get('scheduled_date') else ''}"
            f"\nContact: {v.get('owner_email', 'admin@bogineni.com')}"
        ),
    },

    # ------------------------------------------------------------------
    # New maintenance request (to owner/manager)
    # ------------------------------------------------------------------
    "maintenance_new_request": {
        "subject": "New Maintenance Request from {tenant_name} — {unit_name}",
        "html_content": lambda v: f"""
<p>A new maintenance request has been submitted.</p>
<div class="highlight">
  <strong>Tenant:</strong> {v['tenant_name']}<br>
  <strong>Unit:</strong> {v['unit_name']}<br>
  <strong>Category:</strong> {v['category']}<br>
  <strong>Issue:</strong> {v['issue']}<br>
  <strong>Priority:</strong> {v.get('priority', 'Normal')}<br>
  <strong>Submitted:</strong> {v['submitted_at']}
</div>
""",
        "text_content": lambda v: (
            f"New maintenance request from {v['tenant_name']} ({v['unit_name']}):\n"
            f"{v['issue']} [{v.get('priority', 'Normal')}]"
        ),
        "sms_content": lambda v: (
            f"New maintenance: {v['tenant_name']}/{v['unit_name']} — "
            f"{v['issue']} [{v.get('priority', 'Normal')}]"
        ),
        "whatsapp_content": lambda v: (
            f"🔔 *New Maintenance Request*\n\n"
            f"Tenant: {v['tenant_name']} | Unit: {v['unit_name']}\n"
            f"Issue: *{v['issue']}*\n"
            f"Priority: {v.get('priority', 'Normal')}\n"
            f"Category: {v['category']}\n"
            f"Submitted: {v['submitted_at']}"
        ),
    },
}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def render(event_type: str, **variables: Any) -> dict[str, str]:
    """
    Render a notification template for the given event type.

    Returns:
        {
          "subject": "...",
          "html_body": "...",
          "text_body": "...",
          "sms_body": "...",
          "whatsapp_body": "...",
        }
    Raises:
        KeyError if event_type is unknown.
    """
    tpl = _TEMPLATES[event_type]
    subject_tpl: str = tpl["subject"]

    try:
        subject = subject_tpl.format(**variables)
    except KeyError:
        subject = subject_tpl

    html_content: str = tpl["html_content"](variables)
    text_content: str = tpl["text_content"](variables)
    sms_content: str = tpl["sms_content"](variables)
    whatsapp_content: str = tpl["whatsapp_content"](variables)

    return {
        "subject": subject,
        "html_body": _html_wrap(subject, html_content),
        "text_body": text_content,
        "sms_body": sms_content,
        "whatsapp_body": whatsapp_content,
    }


def list_event_types() -> list[str]:
    return list(_TEMPLATES.keys())
