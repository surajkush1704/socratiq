$body = @{
  user_id = "test_user_001"
  document_name = "lecture.pdf"
  summary = "This document covers prompt engineering fundamentals including chain of thought, few shot prompting and role prompting."
  key_points = @("Chain of thought improves reasoning", "Few shot examples guide output", "Role prompting sets context")
  topics = @("Chain of Thought", "Few Shot Prompting", "Role Prompting")
  mode = "learn"
} | ConvertTo-Json -Depth 5

$session = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/session/start" `
  -ContentType "application/json" `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

$session | Format-List
$sessionId = $session.session_id
Write-Host "Session ID: $sessionId"

Write-Host "`n--- TEST 2: INTERACT ---"
$body2 = @{
  session_id = $sessionId
  user_input = "Can you explain chain of thought to me?"
  interaction_type = "question"
} | ConvertTo-Json

$r2 = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/interaction/interact" `
  -ContentType "application/json" `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body2))
$r2 | Format-List

Write-Host "`n--- TEST 3: REQUEST MCQ ---"
$body3 = @{
  session_id = $sessionId
  user_input = "Quiz me"
  interaction_type = "request_mcq"
} | ConvertTo-Json

$r3 = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/interaction/interact" `
  -ContentType "application/json" `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body3))
$r3 | Format-List

Write-Host "`n--- TEST 4: ANSWER MCQ ---"
$body4 = @{
  session_id = $sessionId
  user_input = "Chain of thought helps models reason step by step"
  interaction_type = "answer"
} | ConvertTo-Json

$r4 = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/interaction/interact" `
  -ContentType "application/json" `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body4))
$r4 | Format-List

Write-Host "`n--- TEST 5: END SESSION ---"
$r5 = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/session/end?session_id=$sessionId&user_id=test_user_001"
$r5 | Format-List
