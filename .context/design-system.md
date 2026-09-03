# Socratiq — Design System v3 (Hybrid AI-Native)

## Design Philosophy
Seven techniques, each serving a specific purpose:
- Minimal = clarity (base of every screen)
- Bento = organization (Home + Progress only)
- Glass = AI interaction (voice, bottom sheets, floating nav)
- Aurora = atmosphere (behind AI experiences only)
- 3D Owl = personality (splash, home hero, upload, empty states, voice)
- Motion = AI state (4 voice states, micro-interactions)
- Material 3 = foundation underneath everything

## Color Tokens
- background:       #F8FAFF
- backgroundAlt:    #EEF2FF
- navyText:         #0A0F1E
- secondaryText:    #4B5675
- lightText:        #8B92A5
- primaryBlue:      #2355F5
- cyanAccent:       #06B6D4
- lavenderAccent:   #7C6FEC
- cardWhite:        #FFFFFF
- glassWhite:       rgba(255,255,255,0.85)
- glassBorder:      rgba(255,255,255,0.4)
- success:          #10B981
- error:            #EF4444
- warning:          #F59E0B

## Aurora Colors (AI experience backgrounds only)
- auroraBlue:       #1E40AF
- auroraCyan:       #0891B2
- auroraLavender:   #6D28D9
- Aurora is a radial gradient mesh — blue center, cyan mid, lavender edges
- Never use aurora on Library, Settings, or non-AI screens

## Typography — Poppins Only
- Hero:        Poppins Black (900) 40-52px letterSpacing -1
- Display:     Poppins Bold (700) 28-32px letterSpacing -0.5
- Title:       Poppins SemiBold (600) 20-24px
- Heading:     Poppins SemiBold (600) 16-18px
- Body:        Poppins Regular (400) 14-15px lineHeight 1.6
- Caption:     Poppins Regular (400) 12px
- Button:      Poppins SemiBold (600) 15px
- Score:       Poppins Black (900) 64-80px

## Spacing — 8dp Grid
- xs: 4dp
- sm: 8dp
- md: 16dp
- lg: 24dp
- xl: 32dp
- xxl: 48dp
- Screen horizontal padding: 20dp
- Card padding: 20dp
- Section gap: 24dp

## Border Radius
- Card large:    24dp
- Card medium:   20dp
- Card small:    16dp
- Button:        999dp (full pill)
- Input:         16dp
- Bottom sheet:  28dp top only
- Chip:          999dp
- Icon box:      14dp
- Touch minimum: 48dp

## Shadows
- Card:     0px 4px 20px rgba(10,15,30,0.06)
- Glass:    0px 8px 32px rgba(10,15,30,0.08), inset 0px 1px 0px rgba(255,255,255,0.5)
- Button:   0px 8px 24px rgba(35,85,245,0.3)
- Orb glow: 0px 0px 80px rgba(35,85,245,0.4), 0px 0px 160px rgba(6,182,212,0.2)
- Nav:      0px -4px 24px rgba(10,15,30,0.08)

## Glassmorphism (selective — AI surfaces only)
- background: rgba(255,255,255,0.75-0.85)
- blur: BackdropFilter ImageFilter.blur(sigmaX:16, sigmaY:16)
- border: 1px rgba(255,255,255,0.4)
- shadow: glass shadow above
- Use ONLY on: voice tutor screen, bottom sheets, floating nav, overlays, MCQ sheet
- Do NOT use on: library cards, settings rows, stat tiles, upload zone

## Glassmorphism Flutter Implementation
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: AppTheme.glassShadow,
      ),
    ),
  ),
)
```

## Aurora Background Flutter Implementation
```dart
Container(
  decoration: BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.8,
      colors: [
        Color(0xFF1E40AF).withOpacity(0.15),
        Color(0xFF0891B2).withOpacity(0.10),
        Color(0xFF6D28D9).withOpacity(0.08),
        Color(0xFFF8FAFF),
      ],
      stops: [0.0, 0.4, 0.7, 1.0],
    ),
  ),
)
```

## Navigation — Glass Floating Pill
- NOT a standard BottomNavigationBar
- Glass pill floating 20dp above bottom
- width: auto, centered, horizontal padding 8
- BackdropFilter blur 16
- 4 icons: Home, Library, Progress, Settings
- Active: filled blue circle 40px behind icon, icon white
- Inactive: icon #8B92A5
- Shadow: nav shadow
- Hides during voice session — AnimatedOpacity 150ms

## Animations
- Micro: 200-300ms, Curves.easeOut
- Screen transition: fade + slide up 16dp, 250ms
- Card entrance: fade + scale 0.96→1.0, 200ms
- Button tap: scale 0.97, 100ms spring back
- Bottom sheet: slide up 350ms easeOut
- Score animation: count up 800ms
- Voice orb: continuous, see Voice States below

## Voice Tutor — 4 States
### Idle
- Orb: gentle float +/-6dp, 3s sine loop
- Glow: slow pulse opacity 0.3→0.5, 3s loop
- Rings: none visible

### Listening
- Orb: scale reacts to mic input level 1.0→1.15
- Rings: 3 expanding rings, opacity 1→0, radius grows, staggered 400ms
- Glow: intensifies to opacity 0.7

### Thinking
- Orb: slow breathing scale 1.0→1.05, 1.5s loop
- Glow: steady soft pulse
- Rings: none — just the breathing

### Speaking
- Orb: waveform ripple outward, synced to TTS if possible
- Rings: steady pulse at 800ms interval
- Glow: full intensity

## Bento Grid (Home + Progress only)
- Mix of different card sizes: 1x1, 1x2, 2x1, 2x2
- Not a uniform grid — intentional size variation
- Achieved with Row + Expanded + Column combinations
- Cards have different heights within same row
- Creates visual hierarchy through size alone

## 3D Owl Mascot
- White body, navy details, glowing blue eyes
- Use on: Splash (large hero), Home AI hero card, Upload processing, Empty states, Voice tutor
- Do NOT use on: Library, Settings, Stats, Mode Select
- Implement as: Image.asset('assets/images/owl_3d.png') initially
- For voice tutor: animated owl with state-based expressions

## Touch Targets
- All interactive elements minimum 48dp height
- Bottom sheet options: minimum 56dp
- Voice mic button: 76dp circle
- Nav icons: 44dp touch area minimum

## Material 3 Foundation
- Use Material 3 theme (useMaterial3: true)
- Icon family: Icons (Material Symbols Rounded style)
- Consistent with M3 motion and accessibility
- Override visual styling completely with custom design tokens
- Do not use M3 default colors or shapes — only the architecture

## What To Avoid
- Excessive cards everywhere
- Heavy shadows on non-glass surfaces  
- Thick borders
- Generic chatbot bubbles
- Default Material appearance
- Neon or rainbow gradients
- Childish illustrations (owl is premium 3D, not cartoon)
- Unnecessary animation that doesn't communicate state
