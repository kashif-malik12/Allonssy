# Allonssy Project Guidelines

## 📧 Email Architecture & Cloudflare Routing Reminder
- **Forwarding Destination:** All domain emails (e.g. `@allonssy.com`, `contact@allonssy.com`) routed via Cloudflare Email Routing forward to `ali.kashifmalik@gmail.com`.
- **Testing Reminder (Gmail Deduplication):**
  - **Issue:** Sending a test email *from* `ali.kashifmalik@gmail.com` *to* any forwarded domain alias will **not** show up in your Gmail inbox.
  - **Reason:** Gmail deduplicates emails originating from the same account and skips the inbox because the message is already in "Sent Mail".
  - **Rule:** Always test inbound routing from a completely different sender email address.
  - **Reference:** [Cloudflare Email Routing Documentation](https://developers.cloudflare.com/email-routing/enable-email-routing#test-your-configuration).

## 🔒 Secret Zero-Leakage & API Key Policy (CRITICAL)
- **Zero Hardcoded Secrets:** Never commit, push, or hardcode API keys (Resend, Cloudflare, Supabase, Stripe, etc.), passwords, or high-entropy tokens in source files, scripts, or backup vaults (even private GitHub repos).
- **Environment Variables Only:** Always inject secrets dynamically using `getenv()` / process environment variables or secure `.env` files strictly excluded via `.gitignore`.
- **Automated Backup Sanitization:** Any script syncing directories to remote git repositories (e.g., GitHub backup vaults) must exclude `.env`, sensitive credentials, and verify no raw secrets exist before running `git add` and `git push`.
- **Pre-Commit / Pre-Push Secret Verification:** Always audit staged diffs (`git diff --staged`) or run secret pattern scanning before pushing code to any remote.
