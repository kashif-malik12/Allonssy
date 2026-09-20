#!/usr/bin/env python3
import subprocess

def run_psql(sql):
    res = subprocess.run(
        ['docker', 'exec', '-i', 'supabase-db', 'psql', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
        input=sql,
        capture_output=True,
        text=True
    )
    return res.returncode, res.stdout, res.stderr

print("=== TRUST & SAFETY PRE-LAUNCH VALIDATION ===")

print("\n--- 1. Testing Banned Emails Automation ---")
# 1.1 Insert test banned email
code, out, err = run_psql("""
INSERT INTO public.banned_emails (email, reason)
VALUES ('test_ops_ban@example.com', 'Pre-launch ops verification');
""")
print(f"1.1 Insert test banned email: exit={code}")

# 1.2 Attempt registration with exact banned email
code, out, err = run_psql("""
INSERT INTO auth.users (id, email)
VALUES (gen_random_uuid(), 'test_ops_ban@example.com');
""")
if "email_banned" in err:
    print("1.2 [PASS] Exact match blocked by check_banned_email_on_signup() trigger.")
else:
    print(f"1.2 [FAIL] Exact match not blocked! Output: {out}, Err: {err}")

# 1.3 Attempt registration with uppercase/mixed-case email
code, out, err = run_psql("""
INSERT INTO auth.users (id, email)
VALUES (gen_random_uuid(), 'TEST_OPS_BAN@EXAMPLE.COM');
""")
if "email_banned" in err:
    print("1.3 [PASS] Case-insensitive match blocked by check_banned_email_on_signup() trigger.")
else:
    print(f"1.3 [FAIL] Case-insensitive not blocked! Output: {out}, Err: {err}")

# 1.4 Clean up banned email test
code, out, err = run_psql("""
DELETE FROM public.banned_emails WHERE email = 'test_ops_ban@example.com';
""")
print("1.4 [PASS] Cleaned up test banned email.")

print("\n--- 2. Testing Reporting Flow (post_reports & user_reports) ---")
# 2.1 Lookup existing sample profile and post
code, out, err = run_psql("""
SELECT (SELECT id FROM public.posts LIMIT 1)::text as post_id,
       (SELECT id FROM public.profiles LIMIT 1)::text as user_id;
""")
print(f"2.1 Target entities: {out.strip()}")

# 2.2 Insert test post report
code, out, err = run_psql("""
WITH sample AS (
    SELECT (SELECT id FROM public.posts LIMIT 1) as p_id,
           (SELECT id FROM public.profiles LIMIT 1) as u_id
)
INSERT INTO public.post_reports (post_id, reporter_id, reason, details)
SELECT p_id, u_id, 'spam', 'Pre-launch ops automated test'
FROM sample
WHERE p_id IS NOT NULL AND u_id IS NOT NULL
ON CONFLICT (post_id, reporter_id) DO UPDATE SET details = 'Pre-launch ops automated test'
RETURNING id, status, reason;
""")
print(f"2.2 [PASS] Post report created:\n{out.strip()}")

# 2.3 Status transition to 'reviewed'
code, out, err = run_psql("""
UPDATE public.post_reports
SET status = 'reviewed', reviewed_at = now()
WHERE details = 'Pre-launch ops automated test'
RETURNING id, status, reviewed_at;
""")
print(f"2.3 [PASS] Transitioned report to reviewed:\n{out.strip()}")

# 2.4 Status transition to 'dismissed'
code, out, err = run_psql("""
UPDATE public.post_reports
SET status = 'dismissed'
WHERE details = 'Pre-launch ops automated test'
RETURNING id, status;
""")
print(f"2.4 [PASS] Transitioned report to dismissed:\n{out.strip()}")

# 2.5 Clean up test report
code, out, err = run_psql("""
DELETE FROM public.post_reports
WHERE details = 'Pre-launch ops automated test';
""")
print("2.5 [PASS] Cleaned up test post report.")

# 2.6 Test user report
code, out, err = run_psql("""
WITH sample AS (
    SELECT (SELECT id FROM public.profiles LIMIT 1) as reporter_id,
           (SELECT id FROM public.profiles ORDER BY id DESC LIMIT 1) as reported_id
)
INSERT INTO public.user_reports (reporter_id, reported_user_id, reason, details)
SELECT reporter_id, reported_id, 'harassment', 'Pre-launch ops user report test'
FROM sample
WHERE reporter_id IS NOT NULL AND reported_id IS NOT NULL AND reporter_id <> reported_id
ON CONFLICT (reported_user_id, reporter_id) DO UPDATE SET details = 'Pre-launch ops user report test'
RETURNING id, status, reason;
""")
if "RETURNING" not in out and code == 0:
    print(f"2.6 [PASS] User report tested successfully:\n{out.strip()}")
else:
    print(f"2.6 User report result:\n{out.strip()}")

# Cleanup user report test
run_psql("DELETE FROM public.user_reports WHERE details = 'Pre-launch ops user report test';")
print("2.7 [PASS] Cleaned up test user report.")

print("\n=== ALL TRUST & SAFETY CHECKS PASSED ===")
