# Allonssy Project Guidelines

## 📧 Email Architecture & Cloudflare Routing Reminder
- **Forwarding Destination:** All domain emails (e.g. `@allonssy.com`, `contact@allonssy.com`) routed via Cloudflare Email Routing forward to `ali.kashifmalik@gmail.com`.
- **Testing Reminder (Gmail Deduplication):**
  - **Issue:** Sending a test email *from* `ali.kashifmalik@gmail.com` *to* any forwarded domain alias will **not** show up in your Gmail inbox.
  - **Reason:** Gmail deduplicates emails originating from the same account and skips the inbox because the message is already in "Sent Mail".
  - **Rule:** Always test inbound routing from a completely different sender email address.
  - **Reference:** [Cloudflare Email Routing Documentation](https://developers.cloudflare.com/email-routing/enable-email-routing#test-your-configuration).
