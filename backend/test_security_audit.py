import os
from fastapi.testclient import TestClient

# Ensure test runs in a controlled environment
os.environ['ENV'] = 'production'
from main import app

client = TestClient(app)

def run_security_test_suite():
    print("=================================================================")
    print("               RUNNING DEFENSIVE SECURITY AUDIT                 ")
    print("=================================================================\n")
    passed = 0
    total = 0

    # -------------------------------------------------------------------------
    # TEST 1: Path Traversal Attack on Content Upload
    # -------------------------------------------------------------------------
    total += 1
    print("[TEST 1] Simulating Path Traversal attack in uploaded PDF filename...")
    traversal_filename = "../../../../../../../etc/passwd.pdf"
    res = client.post(
        "/content/upload",
        files={"file": (traversal_filename, b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF", "application/pdf")},
        data={"uid": "attacker_01"},
    )
    # Filename should be sanitized to passwd.pdf and no file written to disk traversal path
    data = res.json()
    if res.status_code == 200 and data.get("document_name") == "passwd.pdf":
        print("  -> PASSED: Filename traversal sanitized successfully:", data.get("document_name"))
        passed += 1
    else:
        print(f"  -> FAILED: Unexpected response: {res.status_code} {res.text}")

    # -------------------------------------------------------------------------
    # TEST 2: Disguised Executable Upload (Polyglot / Extension spoofing)
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 2] Simulating Malware / Executable upload spoofed as PDF...")
    fake_exe_bytes = b"MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00"
    res = client.post(
        "/content/upload",
        files={"file": ("virus.pdf", fake_exe_bytes, "application/pdf")},
        data={"uid": "attacker_02"},
    )
    if res.status_code == 400 and "Invalid file type" in res.text:
        print("  -> PASSED: Magic byte inspection blocked non-PDF executable (HTTP 400)")
        passed += 1
    else:
        print(f"  -> FAILED: Malware upload was not blocked with 400: {res.status_code} {res.text}")

    # -------------------------------------------------------------------------
    # TEST 3: Denial of Service (DoS) via Oversized PDF Payload
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 3] Simulating Resource Exhaustion via 20MB PDF payload...")
    oversized_pdf = b"%PDF-1.4\n" + (b"A" * (20 * 1024 * 1024))
    res = client.post(
        "/content/upload",
        files={"file": ("oversized.pdf", oversized_pdf, "application/pdf")},
        data={"uid": "attacker_03"},
    )
    if res.status_code == 413:
        print("  -> PASSED: Oversized payload rejected by Cost Guard with HTTP 413")
        passed += 1
    else:
        print(f"  -> FAILED: Expected 413 Payload Too Large, got: {res.status_code}")

    # -------------------------------------------------------------------------
    # TEST 4: Denial of Service via Oversized Audio File
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 4] Simulating Resource Exhaustion via 30MB Audio payload on /voice/stt...")
    oversized_audio = b"\x00" * (30 * 1024 * 1024)
    res = client.post(
        "/voice/stt",
        files={"audio": ("huge_recording.m4a", oversized_audio, "audio/m4a")},
        data={"session_id": "sess_01", "uid": "attacker_04"},
    )
    if res.status_code == 413:
        print("  -> PASSED: Oversized audio rejected by Cost Guard with HTTP 413")
        passed += 1
    else:
        print(f"  -> FAILED: Expected 413 for oversized audio, got: {res.status_code}")

    # -------------------------------------------------------------------------
    # TEST 5: Prompt Flooding / Token Abuse on AI Interaction
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 5] Simulating Token Depletion Attack (50,000 char prompt flood)...")
    flood_input = "Tell me everything: " * 2500
    res = client.post(
        "/interaction/interact",
        json={
            "session_id": "sess_flood",
            "user_input": flood_input,
            "interaction_type": "question",
        },
    )
    if res.status_code == 400 and "Input too large" in res.text:
        print("  -> PASSED: Excessive token request rejected before LLM invocation (HTTP 400)")
        passed += 1
    else:
        print(f"  -> FAILED: Expected 400 for input > 2000 chars, got: {res.status_code}")

    # -------------------------------------------------------------------------
    # TEST 6: Unauthorized Account Deletion (BOLA / IDOR without token)
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 6] Simulating BOLA/IDOR attack: deleting account without Auth token...")
    res = client.delete("/auth/account/victim_user_123")
    if res.status_code in [401, 403]:
        print(f"  -> PASSED: Unauthorized account deletion rejected with HTTP {res.status_code}")
        passed += 1
    else:
        print(f"  -> FAILED: Unauthorized deletion not blocked: {res.status_code} {res.text}")

    # -------------------------------------------------------------------------
    # TEST 7: Unauthorized Account Deletion with Forged / Fake Token
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 7] Simulating BOLA/IDOR attack: forged Bearer token...")
    res = client.delete(
        "/auth/account/victim_user_123",
        headers={"Authorization": "Bearer forged_fake_jwt_token_12345"},
    )
    if res.status_code in [401, 403]:
        print(f"  -> PASSED: Forged token rejected with HTTP {res.status_code}")
        passed += 1
    else:
        print(f"  -> FAILED: Forged token was not blocked: {res.status_code} {res.text}")

    # -------------------------------------------------------------------------
    # TEST 8: Brute-Force Throttling on Authentication Endpoint
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 8] Simulating Credential Brute-Force attack on /auth/login...")
    # Send rapid requests until rate limit trips
    tripped_429 = False
    for i in range(10):
        res = client.post(
            "/auth/login",
            json={"uid": f"attacker_{i}", "email": "victim@example.com", "name": "Hack"},
        )
        if res.status_code == 429:
            tripped_429 = True
            break

    if tripped_429:
        print("  -> PASSED: Login rate limiter triggered HTTP 429 (Too Many Requests)")
        passed += 1
    else:
        print("  -> FAILED: 10 rapid login attempts were not throttled")

    # -------------------------------------------------------------------------
    # TEST 9: Quota Depletion Attack (Triggering Daily Quota Limit)
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 9] Simulating Daily PDF Quota Exhaustion (exceeding 20 uploads)...")
    valid_pdf = b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF"
    quota_tripped = False
    for i in range(25):
        res = client.post(
            "/content/upload",
            files={"file": (f"test_{i}.pdf", valid_pdf, "application/pdf")},
            data={"uid": "quota_test_user"},
        )
        if res.status_code == 429:
            quota_tripped = True
            break

    if quota_tripped:
        print("  -> PASSED: Daily user quota enforced; returned HTTP 429 once limit exceeded")
        passed += 1
    else:
        print("  -> FAILED: Quota did not trigger 429 after 20 operations")

    # -------------------------------------------------------------------------
    # TEST 10: Production Swagger/OpenAPI Exposure Check
    # -------------------------------------------------------------------------
    total += 1
    print("\n[TEST 10] Checking Swagger/OpenAPI interface exposure in Production mode...")
    docs_res = client.get("/docs")
    openapi_res = client.get("/openapi.json")
    if docs_res.status_code == 404 and openapi_res.status_code == 404:
        print("  -> PASSED: /docs and /openapi.json are disabled in production (HTTP 404)")
        passed += 1
    else:
        print(f"  -> FAILED: API documentation accessible in production: {docs_res.status_code}, {openapi_res.status_code}")

    print("\n=================================================================")
    print(f" AUDIT RESULT: {passed}/{total} SECURITY TEST CASES PASSED ({(passed/total)*100:.1f}%)")
    print("=================================================================")

if __name__ == "__main__":
    run_security_test_suite()
