# Socratiq — Project Overview

## What It Is
- Voice-first AI tutoring mobile app
- Built personally for one friend who asked for it
- User uploads any PDF — textbook, notes, chapter
- App becomes a personal tutor for that content
- Instead of reading passively, friend talks to app like a real teacher
- App explains, questions, evaluates, and challenges
- Through voice + on-screen MCQs

## App Identity
- Name: Socratiq
- Tagline: "Learn smarter. Not harder."
- Named after Socrates — taught entirely by asking questions
- Design identity: bright premium — opposite of Kino (no dark, no purple, no gold)

## Core Philosophy
- Learning = interaction not consumption
- AI must ask, challenge, correct, guide
- Not a chatbot — a structured tutor

## Privacy Model
- Study content stays fully on device — never leaves the phone
- Only analytics go to cloud — scores, streaks, study time
- App works fully offline for studying
- Internet only needed for AI API calls and analytics sync

## Three Learning Modes
- Learn → Tutor explains → MCQ generated → user answers → scored → Reasoning fires if score below 6
- Revise → Skip explanation → MCQ fires immediately → quick feedback
- Test → Full MCQ set → no feedback during test → scored at end → Result screen

## Current Status
- Phase 0 → Done (project scaffolded, all API keys obtained)
- Phase 1 → Done (PDF upload, PyMuPDF extraction, Content Agent working with Groq fallback, Hive storage)
- Phase 2 → In progress (Firebase Auth, app shell, navigation)
