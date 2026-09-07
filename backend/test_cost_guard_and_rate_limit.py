import os
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_rate_limit_headers():
    res = client.get('/')
    assert res.status_code == 200
    assert 'x-ratelimit-limit' in res.headers
    assert 'x-ratelimit-remaining' in res.headers
    assert 'x-ratelimit-window' in res.headers
    print('[PASS] Rate limit headers present:', {
        'limit': res.headers.get('x-ratelimit-limit'),
        'remaining': res.headers.get('x-ratelimit-remaining'),
        'window': res.headers.get('x-ratelimit-window'),
    })

def test_login_rate_limiting():
    # Make 5 successful login requests
    for i in range(5):
        res = client.post('/auth/login', json={
            'uid': f'test_user_{i}',
            'email': 'test@example.com',
            'name': 'Test User',
            'provider': 'email',
        })
        assert res.status_code == 200, f'Attempt {i+1} failed with {res.status_code}'

    # 6th attempt should be rate limited (429)
    res6 = client.post('/auth/login', json={
        'uid': 'test_user_6',
        'email': 'test@example.com',
        'name': 'Test User',
        'provider': 'email',
    })
    assert res6.status_code == 429, f'Expected 429 on 6th attempt, got {res6.status_code}'
    data = res6.json()
    assert 'retry_after' in data.get('detail', {}), 'Expected retry_after in detail'
    print('[PASS] 6th login attempt returned 429 with retry_after:', data['detail']['retry_after'])

def test_large_interaction_text():
    # Text input > 2000 chars should return 400
    large_input = 'a' * 2001
    res = client.post('/interaction/interact', json={
        'session_id': 'test_sess',
        'user_input': large_input,
        'interaction_type': 'question',
    })
    assert res.status_code == 400, f'Expected 400 for large input, got {res.status_code}'
    print('[PASS] Large text input rejected with 400:', res.json())

def test_large_pdf_upload():
    # Upload > 10MB should return 413
    large_pdf = b'%PDF-1.4\n' + b'0' * (11 * 1024 * 1024)
    res = client.post(
        '/content/upload',
        files={'file': ('large.pdf', large_pdf, 'application/pdf')},
        data={'uid': 'test_user'},
    )
    assert res.status_code == 413, f'Expected 413 for PDF > 10MB, got {res.status_code}'
    print('[PASS] Large PDF upload rejected with 413:', res.json())

def test_invalid_pdf_content():
    # Upload non-PDF file should return 400
    invalid_file = b'Not a PDF at all'
    res = client.post(
        '/content/upload',
        files={'file': ('fake.pdf', invalid_file, 'application/pdf')},
        data={'uid': 'test_user'},
    )
    assert res.status_code == 400, f'Expected 400 for invalid magic bytes, got {res.status_code}'
    print('[PASS] Invalid PDF magic bytes rejected with 400:', res.json())

if __name__ == '__main__':
    test_rate_limit_headers()
    test_large_interaction_text()
    test_large_pdf_upload()
    test_invalid_pdf_content()
    test_login_rate_limiting()
    print('\nALL BACKEND TESTS PASSED!')
