# Socratiq — All Screens v3

## Splash Screen
- Background: Aurora gradient (blue→cyan→lavender→#F8FAFF)
- Centre: Large 3D owl mascot (hero size, 200px)
- "SocratiQ" Poppins Black 48px navyText below owl
- "Learn Smarter. Not Harder." Poppins Regular 16px secondaryText
- Page dots at bottom (3 dots, first blue active)
- Auto-navigate after 2.5s: Firebase auth check → home or login

## Login Screen
- Background: #F8FAFF base + subtle aurora top section
- "Welcome to\nSocratiQ" Poppins Bold 36px navyText, top padding 64
- Glass card, blur 16, border radius 24, padding 28, margin 20:
  - Google Sign-In: white solid pill, shadow, Google icon + label
  - Divider "or"
  - Email + Password: border radius 16, border glassBorder
  - Blue gradient pill login button
  - Sign up toggle in primaryBlue
- Error: SnackBar, real message

## Home Screen (Bento Layout)
Priority order top to bottom:
1. Top bar (avatar + greeting + icons)
2. AI Tutor Hero Card (large, glass + aurora, owl, CTA)
3. Bento row 1: Continue Learning (2/3 width) + Quick Action (1/3 width)
4. Bento row 2: Library (1/4) + Quiz Me (1/4) + Progress (1/2)
5. Recent PDFs horizontal scroll (compact cards)
6. Stats strip (minimal, secondary)
Glass floating pill nav at bottom

## AI Tutor Hero Card (Home — most important element)
- Full width card, border radius 24
- Background: aurora gradient mesh behind glass surface
- Glass overlay: rgba(255,255,255,0.65) blur 20
- Left side: Column
  - "Your Personal AI Tutor" Poppins SemiBold 13px cyanAccent
  - "Ready to learn?" Poppins Bold 22px navyText
  - Small subtitle "Ask anything from your PDFs" secondaryText 13px
  - SizedBox 16
  - Row of 2 buttons:
    - "Talk to Tutor" blue gradient pill primary
    - "Upload PDF" white glass outlined pill secondary
- Right side: 3D owl image, 100px, slightly overlapping card edge
- Padding 24

## Library Screen (Minimal + Functional)
- Background: #F8FAFF flat — no aurora
- Top: "Library" Poppins Bold 28px navyText, padding 20
- Search bar: white card border radius 16 shadow, search icon cyanAccent
- Filter chips: All / Recent — minimal pill chips
- PDF list — compact cards, border radius 16, white, shadow:
  - Row: coloured icon box 44x44 border radius 12 + title column + chevron
  - Title: Poppins SemiBold 15px navyText
  - Subtitle: "X pages · Last studied 2d ago" caption secondaryText
  - Tap → Mode Select
- Floating "+ Upload PDF" pill above glass nav
- Glass floating nav (index 1)

## Upload Screen
- Background: aurora top section fading to #F8FAFF
- "Give SocratiQ something to teach." Poppins Bold 28px navyText
- Large glass upload zone: border radius 24, blur 12, dashed border glassBorder
  - PDF illustration or owl holding PDF
  - "Choose PDF" blue gradient pill button
- After file selected: file name + size, solid border primaryBlue
- Processing states (sequential, with owl animation):
  1. "Reading document..." 
  2. "Understanding concepts..."
  3. "Preparing your tutor..."
  4. "Creating questions..."
  Each with aurora background intensifying + owl 3D animation
- Result: "Your tutor is ready" Poppins Bold 24px
  - Detected topics chips, key concepts list
  - "Start Learning" blue gradient full-width pill

## Mode Select Screen
- Background: #F8FAFF
- Document title + "How do you want to study?" subtitle
- Three large cards stacked, border radius 24:
  - Learn: soft blue tint background (#EEF2FF), book icon primaryBlue
    "Learn" Bold 20px, description Regular 14px, "Start Learning" blue pill
  - Revise: soft cyan tint (#ECFEFF), refresh icon cyanAccent
    "Revise" Bold 20px, description, "Start Revising" cyan pill
  - Test Yourself: soft lavender tint (#F5F3FF), quiz icon lavenderAccent
    "Test Yourself" Bold 20px, description, "Start Test" lavender pill

## Voice Tutor Screen (Signature Experience — most important)
- Background: aurora gradient mesh (blue→cyan→lavender) — full immersion
- NOT a chatbot interface — immersive voice experience
- Top bar: glass pill "Topic: [name]" centre + X button right
- LARGE CENTRE section (60% of screen):
  - 3D owl or voice orb (CustomPainter wireframe sphere) — 200px
  - Implements 4 state animations (Idle/Listening/Thinking/Speaking)
  - Owl glow: radial gradient behind it, orbGlow shadow
  - State label below: "Listening..." / "Thinking..." / "Speaking..." secondaryText
- Transcript (secondary, 25% of screen, scrollable):
  - AI: soft white glass card, border radius 16, Poppins Regular 14px
  - User: subtle blue glass bubble rgba(35,85,245,0.12), right aligned
- Bottom controls (glass surface, blur 16):
  - Contextual action chips row: "Explain differently" "Give example" "Quiz me" "Go deeper"
    — glass pill chips, Poppins Regular 13px navyText
  - SizedBox 16
  - Centre: 76dp mic button, blue gradient circle, shadow buttonShadow
    — animated listening rings expand from it when in Listening state
  - Side buttons: 48dp glass circles for pause (left) and end session (right)
- MCQ slides up as glass bottom sheet when question ready:
  - backdrop blur 20, border radius 28 top only
  - Question Poppins Bold 16px navyText
  - 4 option cards glass border radius 16
  - Selected: primaryBlue border + blue tint
  - Submit blue gradient pill
  - After submit: green/red feedback + explanation text
  - Continue pill → AI resumes teaching

## Test Screen (Focused, Minimal)
- Background: #F8FAFF — calm, no aurora during test
- "Question X of Y" Poppins SemiBold 16px + LinearProgressIndicator primaryBlue
- Question card: white, border radius 20, shadow
- 4 option cards: white border radius 16 shadow
- Selected: primaryBlue border + #EEF2FF background
- No feedback during test — correctness hidden
- "Next" blue gradient pill

## Result Screen (Rewarding)
- Background: aurora gradient — celebration atmosphere
- Large percentage score: Poppins Black 80px navyText, count-up animation 800ms
- Performance message: "Excellent!" / "Good work" / "Keep practicing"
- Animated score ring: circular arc, animated draw 600ms
- Correct/incorrect breakdown white glass card
- Weak topics list: Poppins SemiBold 14px + study suggestion
- Two CTAs: "Study Again" glass outlined + "Go Home" blue gradient pill

## Progress Screen (Bento + Minimal)
- Background: #F8FAFF
- Streak hero: large glass card with aurora, fire emoji + streak number Poppins Black 52px
- Bento row: Total Sessions (1/2) + Study Time (1/2)
- Weekly activity: 7 animated bars, height proportional to minutes, primaryBlue filled
- Topic mastery: each topic as progress row — name + linear bar + percentage
- Weak areas: compact recommendation cards, lavender tint
- Glass floating nav (index 2)

## Settings Screen (Minimalist)
- Background: #F8FAFF flat
- Profile card: white border radius 24, CircleAvatar 48px, name + email
- Section cards white border radius 20:
  - Voice Speed: segmented control Slow/Normal/Fast
  - Storage: info text + Clear Cache text button error colour
- Sign Out: full-width error red pill button, bottom of screen
- Glass floating nav (index 3)