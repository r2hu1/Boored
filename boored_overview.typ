#set page(
  paper: "a4",
  margin: (x: 1.8cm, top: 1.8cm, bottom: 1.8cm),
  header: none,
  footer: none
)

#set text(
  font: "Avenir Next",
  size: 9.5pt,
  fill: rgb("#1e293b"),
  spacing: 110%
)

#set par(
  leading: 0.62em,
  justify: false
)

#let primary = rgb("#2563eb")
#let primary-dark = rgb("#1d4ed8")
#let text-main = rgb("#0f172a")
#let text-muted = rgb("#64748b")
#let border-subtle = rgb("#e2e8f0")
#let bg-canvas = rgb("#f8fafc")
#let bg-card = rgb("#ffffff")

#let device-frame(img-path, width: 4.4cm, radius: 10pt) = {
  box(
    stroke: 1pt + rgb("#cbd5e1"),
    radius: radius,
    inset: 2pt,
    fill: rgb("#0f172a"),
    clip: true,
    [
      #box(
        radius: radius - 2pt,
        clip: true,
        [#image(img-path, width: width)]
      )
    ]
  )
}

#let feature-card(title, body, tag: none) = {
  rect(
    width: 100%,
    stroke: 1pt + border-subtle,
    radius: 8pt,
    fill: bg-card,
    inset: (x: 10pt, y: 8pt),
    [
      #if tag != none [
        #text(size: 7pt, weight: "bold", fill: primary)[#upper(tag)]
        #v(1pt)
      ]
      #text(size: 10pt, weight: "bold", fill: text-main)[#title]
      #v(3pt)
      #text(size: 8.8pt, fill: text-muted)[#body]
    ]
  )
}

// =============================================================
// PAGE 1: COVER & OVERVIEW
// =============================================================

#v(0.2cm)
#grid(
  columns: (auto, 1fr),
  gutter: 14pt,
  align: horizon,
  [
    #image("apps/mobile/assets/logo.png", width: 2.2cm)
  ],
  [
    #text(size: 28pt, weight: "bold", fill: text-main)[Boored]
    #v(-6pt)
    #text(size: 13pt, weight: "medium", fill: primary)[Classroom Whiteboard Digitization & Timeline Notes]
    #v(2pt)
    #text(size: 8.5pt, fill: text-muted)[Native Android Application • On-Device OpenCV • ML Kit Neural Segmentation • Vector PDF Export]
  ]
)

#v(0.4cm)
#line(length: 100%, stroke: 1.5pt + primary)
#v(0.5cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  [
    #text(size: 12pt, weight: "bold", fill: text-main)[The Classroom Problem]
    #v(4pt)
    #text(size: 9pt, fill: rgb("#334155"))[
      Documenting university and technical whiteboard lectures with standard phone cameras fails for four clear physical reasons:
    ]
    #v(6pt)
    
    #rect(
      width: 100%,
      fill: rgb("#fef2f2"),
      stroke: 0.8pt + rgb("#fecaca"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: rgb("#991b1b"))[1. Wiped Content Loss]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#7f1d1d"))[Professors erase board sections to make space. If you don't take a photo at that exact second, the notes are gone permanently.]
      ]
    )
    #v(6pt)
    #rect(
      width: 100%,
      fill: rgb("#fff7ed"),
      stroke: 0.8pt + rgb("#ffedd5"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: rgb("#9a3412"))[2. Lecturer Body Occlusion]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#7c2d12"))[Instructors stand in front of diagrams and formulas, blocking 30% to 50% of the active board content.]
      ]
    )
    #v(6pt)
    #rect(
      width: 100%,
      fill: rgb("#f8fafc"),
      stroke: 0.8pt + rgb("#e2e8f0"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: rgb("#1e293b"))[3. Desk Perspective & Lighting Glare]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#475569"))[Desk photos suffer from steep perspective angles, fluorescent whiteboard glare, and low marker contrast.]
      ]
    )
  ],
  [
    #text(size: 12pt, weight: "bold", fill: text-main)[The Boored Solution]
    #v(4pt)
    #text(size: 9pt, fill: rgb("#334155"))[
      Boored automates lecture capture with on-device computer vision and background machine learning.
    ]
    #v(6pt)
    
    #rect(
      width: 100%,
      fill: rgb("#eff6ff"),
      stroke: 0.8pt + rgb("#bfdbfe"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: primary-dark)[Automated Perspective Rectification]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#1e40af"))[Draggable 4-corner board handles warp angled desk shots into flat, planar direct whiteboard views.]
      ]
    )
    #v(6pt)
    #rect(
      width: 100%,
      fill: rgb("#f0fdf4"),
      stroke: 0.8pt + rgb("#bbf7d0"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: rgb("#166534"))[Pre-Erase Keyframe Trigger]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#14532d"))[Frame difference analysis detects when a board area is wiped and commits the full content right before the erase.]
      ]
    )
    #v(6pt)
    #rect(
      width: 100%,
      fill: rgb("#faf5ff"),
      stroke: 0.8pt + rgb("#e9d5ff"),
      radius: 6pt,
      inset: 8pt,
      [
        #text(size: 9pt, weight: "bold", fill: rgb("#6b21a8"))[Multi-Frame Lecturer Removal]
        #v(1pt)
        #text(size: 8.5pt, fill: rgb("#581c87"))[Neural segmentation reconstructs blocked board text by sampling background pixels across moving frames.]
      ]
    )
  ]
)

#v(0.6cm)

#rect(
  width: 100%,
  stroke: 1pt + border-subtle,
  radius: 8pt,
  fill: bg-canvas,
  inset: 10pt,
  [
    #grid(
      columns: (1fr, 1fr, 1fr, 1fr),
      gutter: 8pt,
      align: center,
      [
        #text(size: 15pt, weight: "bold", fill: primary)[100%]\
        #text(size: 7.5pt, weight: "medium", fill: text-muted)[On-Device Processing]
      ],
      [
        #text(size: 15pt, weight: "bold", fill: primary)[Zero]\
        #text(size: 7.5pt, weight: "medium", fill: text-muted)[Cloud Latency in Class]
      ],
      [
        #text(size: 15pt, weight: "bold", fill: primary)[Dual Export]\
        #text(size: 7.5pt, weight: "medium", fill: text-muted)[Vector PDF & OCR Text]
      ],
      [
        #text(size: 15pt, weight: "bold", fill: primary)[Android]\
        #text(size: 7.5pt, weight: "medium", fill: text-muted)[API 24 to 36 Target]
      ]
    )
  ]
)

#pagebreak()

// =============================================================
// PAGE 2: CAPTURE & CORNERS
// =============================================================

#text(size: 16pt, weight: "bold", fill: text-main)[1. Setup, Capture & Perspective Rectification]
#v(2pt)
#text(size: 9pt, fill: text-muted)[From desk seating to clean, flat whiteboard captures]
#v(10pt)

#grid(
  columns: (auto, 1fr),
  gutter: 18pt,
  align: top,
  [
    #device-frame("assets/screenshots/camera-screen.jpeg", width: 4.4cm)
    #v(3pt)
    #align(center)[#text(size: 7.5pt, fill: text-muted)[Live Capture with 4 Drag Handles]]
  ],
  [
    #feature-card(
      "Interactive 4-Corner Polygon Snapping",
      "Classroom seating is rarely centered. The live camera overlay provides 4 draggable normalized corner pins that snap directly to the physical whiteboard frame. An automated contour detector calculates initial bounds, with full manual touch adjustment.",
      tag: "Perspective Transform"
    )
    #v(6pt)
    #feature-card(
      "Continuous Interval Capture & Display Wakelock",
      "Selectable 3s, 5s, 10s, 15s, or 30s background intervals quietly record the board without shutter clicks interrupting the class. Integrated Wakelock ensures the device display remains active and acquisition runs uninterrupted.",
      tag: "Engine Lifecycle"
    )
    #v(6pt)
    #feature-card(
      "Native Homography Warp (OpenCV)",
      "Each periodic camera frame is passed into OpenCV's warpPerspective routine, transforming the angled trapezoid into an orthogonal rectangular frame with zero perspective distortion.",
      tag: "Computer Vision"
    )
  ]
)

#v(12pt)

#grid(
  columns: (auto, 1fr),
  gutter: 18pt,
  align: top,
  [
    #device-frame("assets/screenshots/record-upload-or-create-folder-options.jpeg", width: 4.4cm)
    #v(3pt)
    #align(center)[#text(size: 7.5pt, fill: text-muted)[Quick Action Menu (Record, Import, Folders)]]
  ],
  [
    #feature-card(
      "Multi-Source Lecture Intake",
      "Record live in class with automated interval capture, import existing lecture video recordings from phone storage, or create structured subject folders to keep coursework organized.",
      tag: "Flexible Intake"
    )
    #v(6pt)
    #feature-card(
      "Offline-First SQLite Architecture",
      "Every note session operates fully offline. All keyframe records, timestamps, event markers, and OCR texts reside in secure app-private storage, with cloud sync queued in the background.",
      tag: "Data Isolation"
    )
  ]
)

#pagebreak()

// =============================================================
// PAGE 3: PROFESSOR REMOVAL & OCR
// =============================================================

#text(size: 16pt, weight: "bold", fill: text-main)[2. Professor Removal & Note Processing]
#v(2pt)
#text(size: 9pt, fill: text-muted)[Eliminating occlusions, restoring hidden notes, and flexible document generation]
#v(10pt)

#grid(
  columns: (auto, 1fr),
  gutter: 18pt,
  align: top,
  [
    #device-frame("assets/screenshots/generate-options.jpeg", width: 4.4cm)
    #v(3pt)
    #align(center)[#text(size: 7.5pt, fill: text-muted)[Granular Regeneration Options]]
  ],
  [
    #feature-card(
      "Multi-Frame Temporal Board Reconstruction",
      "When a professor moves across the whiteboard, Boored tracks the neural segmentation mask across the session. Obscured coordinates are restored with the real handwriting from temporally adjacent frames where the board was exposed, rather than inpainting blank spaces.",
      tag: "Lecturer Removal"
    )
    #v(6pt)
    #feature-card(
      "Granular On-Demand Processing",
      "Students choose exactly what to build: standard Document PDF, Clean Copy with lecturer removed, Digital Copy with OCR text extraction, or run the complete pipeline with one tap.",
      tag: "Processing Options"
    )
    #v(6pt)
    #feature-card(
      "Soft Alpha Blending & Boundary Feathering",
      "Native OpenCV applies morphological dilation to expand masks around gestures and clothing fringes, followed by Gaussian blurring to create natural transitions without harsh cutout artifacts.",
      tag: "Compositing"
    )
  ]
)

#v(12pt)

#grid(
  columns: (auto, 1fr),
  gutter: 18pt,
  align: top,
  [
    #device-frame("assets/screenshots/home-screen.jpeg", width: 4.4cm)
    #v(3pt)
    #align(center)[#text(size: 7.5pt, fill: text-muted)[Subject Folders & Notes Feed]]
  ],
  [
    #feature-card(
      "Subject Folder Hierarchy",
      "Organize lectures into customized subject folders (Physics, CS, Math) with note count badges and quick folder management.",
      tag: "Course Organization"
    )
    #v(6pt)
    #feature-card(
      "Selective Page Editing & Management",
      "Dedicated Edit Pages view allows selecting and deleting specific unwanted keyframes or bad shots, automatically re-indexing pages and updating all PDFs in sync.",
      tag: "Page Editing"
    )
  ]
)

#pagebreak()

// =============================================================
// PAGE 4: TIMELINE PLAYER & EXPORTS
// =============================================================

#text(size: 16pt, weight: "bold", fill: text-main)[3. Timeline Player & Document Exports]
#v(2pt)
#text(size: 9pt, fill: text-muted)[Review lectures chronologically or export to vector and digital PDF formats]
#v(10pt)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 12pt,
  align: top,
  [
    #align(center)[
      #device-frame("assets/screenshots/timeline.jpeg", width: 4.5cm)
      #v(3pt)
      #text(size: 8pt, weight: "bold", fill: text-main)[Timeline Player]
    ]
    #v(2pt)
    #text(size: 7.5pt, fill: text-muted)[
      Scrub through lecture keyframes with 0.5x–2.0x playback and ADD/ERASE markers.
    ]
  ],
  [
    #align(center)[
      #device-frame("assets/screenshots/pdf-screen.jpeg", width: 4.5cm)
      #v(3pt)
      #text(size: 8pt, weight: "bold", fill: text-main)[Vector Visual PDF]
    ]
    #v(2pt)
    #text(size: 7.5pt, fill: text-muted)[
      Landscape A4 document compiling all rectified keyframes for printing or sharing.
    ]
  ],
  [
    #align(center)[
      #device-frame("assets/screenshots/removed-professor-pdf.jpeg", width: 4.5cm)
      #v(3pt)
      #text(size: 8pt, weight: "bold", fill: text-main)[Clean Copy (Professor Removed)]
    ]
    #v(2pt)
    #text(size: 7.5pt, fill: text-muted)[
      De-occluded whiteboard PDF with temporal reconstruction restoring actual board notes.
    ]
  ]
)

#v(14pt)

#grid(
  columns: (1fr, 1fr),
  gutter: 14pt,
  [
    #feature-card(
      "Interactive Timeline Scrubbing",
      "Reconstruct lecture delivery stroke-by-stroke. Replay speeds allow quick skimming of long lectures while event badges highlight exactly when the board was wiped.",
      tag: "Chronological Review"
    )
  ],
  [
    #feature-card(
      "Triple-Tier Document Generation",
      "Students receive a high-fidelity visual PDF of the physical board, a Clean Copy with the lecturer de-occluded, and a lightweight text-first PDF suitable for searching and fast mobile study.",
      tag: "Document Pipeline"
    )
  ]
)

#pagebreak()

// =============================================================
// PAGE 5: ARCHITECTURE
// =============================================================

#text(size: 16pt, weight: "bold", fill: text-main)[4. Architecture & Technical Specifications]
#v(2pt)
#text(size: 9pt, fill: text-muted)[Complete system overview from mobile client to backend cloud storage]
#v(12pt)

#rect(
  width: 100%,
  stroke: 1pt + border-subtle,
  radius: 8pt,
  fill: bg-canvas,
  inset: 12pt,
  [
    #text(size: 10.5pt, weight: "bold", fill: text-main)[Mobile Client Pipeline (On-Device)]
    #v(6pt)
    #grid(
      columns: (1.2fr, 2fr),
      gutter: 6pt,
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Platform & UI]], [#text(size: 8.5pt)[Flutter 3.x with Riverpod (State Notifier pattern) on Android (API 24 to 36)]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Computer Vision]], [#text(size: 8.5pt)[Native OpenCV 4.5.3 (C++/Kotlin bridge via MethodChannel)]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Image Transforms]], [#text(size: 8.5pt)[Canny contour detection, warpPerspective homography, unsharp masking]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Normalization]], [#text(size: 8.5pt)[L-channel CLAHE (2.2 clip limit) in LAB space for glare & shadow correction]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Change Detection]], [#text(size: 8.5pt)[Frame-to-frame pixel differencing classifying ADD (>=4%), ERASE, or NONE]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Lecturer Removal]], [#text(size: 8.5pt)[ML Kit Selfie Segmentation (0.15 threshold) + temporal multi-frame coordinate recovery]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[OCR Engine]], [#text(size: 8.5pt)[Gaussian adaptive threshold binarization + ML Kit Latin Text Recognition]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Local Database]], [#text(size: 8.5pt)[Drift SQLite ORM tracking Notes, Keyframes, Event Types, and OCR Text]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[PDF Generation]], [#text(size: 8.5pt)[Multi-tier PDF engine (Document A4 + Clean De-occluded A4 + Digital Text Document)]]
    )
  ]
)

#v(10pt)

#rect(
  width: 100%,
  stroke: 1pt + border-subtle,
  radius: 8pt,
  fill: bg-canvas,
  inset: 12pt,
  [
    #text(size: 10.5pt, weight: "bold", fill: text-main)[Cloud Backend & Storage Pipeline]
    #v(6pt)
    #grid(
      columns: (1.2fr, 2fr),
      gutter: 6pt,
      [#text(size: 8.5pt, weight: "bold", fill: primary)[API Framework]], [#text(size: 8.5pt)[Hono + TypeScript running on Node.js runtime]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Authentication]], [#text(size: 8.5pt)[Google ID token verification via jose, issuing JWT access + rotating refresh tokens]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Primary Database]], [#text(size: 8.5pt)[PostgreSQL 16 with Drizzle ORM, schema migrations, and full-text search]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[Object Storage]], [#text(size: 8.5pt)[S3-compatible bucket storage (MinIO locally, AWS S3 / Cloudflare R2 in production)]],
      [#text(size: 8.5pt, weight: "bold", fill: primary)[API Contracts]], [#text(size: 8.5pt)[Zod validation schemas generating OpenAPI 3.0 specifications]]
    )
  ]
)

#v(14pt)

#rect(
  width: 100%,
  stroke: 1.2pt + primary,
  radius: 8pt,
  fill: rgb("#eff6ff"),
  inset: 12pt,
  [
    #grid(
      columns: (auto, 1fr),
      gutter: 12pt,
      align: horizon,
      [
        #image("apps/mobile/assets/logo.png", width: 1.5cm)
      ],
      [
        #text(size: 10pt, weight: "bold", fill: primary-dark)[Boored — Open Source Classroom Whiteboard Digitization System]
        #v(2pt)
        #text(size: 8.5pt, fill: rgb("#334155"))[
          Designed for university students and technical lectures. Built to turn hours of board writing into permanent, readable, and searchable notes.
        ]
      ]
    )
  ]
)
