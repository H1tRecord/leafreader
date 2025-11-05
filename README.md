# leafreader

## Abstract

Lightweight reader app for average casual readers like students who need to open a PDF, EPUB, or plain text without installing multiple apps.

## App Project Infographic Blueprint

### Project Overview & Background

- **App Name & Logo**: LeafReader (logo: stylized green leaf bookmark).
- **Problem Statement**: Students and casual readers waste time juggling separate apps for PDFs, EPUBs, and text documents; LeafReader unifies core formats in a single lightweight tool.

### Core Objectives

1. Launch documents in under three taps across PDF, EPUB, and TXT formats.
2. Provide distraction-free reading with adjustable themes and fonts.
3. Enable seamless file import from local storage and cloud drives.

### Key Features

- **Universal Library**: One shelf for PDF, EPUB, TXT (screenshot: `Image – homepage with PDF, TXT, and EPUB cards`).
- **Quick Import**: File picker for local/cloud sources with recent history.
- **Reader Modes**: Day/Night/Focus modes with font scaling (screenshot: `Image – reader view in night mode`).
- **Progress Sync**: Auto-save last page and highlights per file (icon: bookmark ribbon).

### Target Users

- **Demographics**: Ages 16–30, students or early-career professionals, urban campuses, basic tech literacy.
- **Psychographics**: Goal-driven learners who value efficiency, frustrated by app clutter, comfortable with mobile productivity tools.
- **Persona Snapshot**: "Alex, 19-year-old university student juggling lecture PDFs, EPUB study guides for coursework, and EPUB novels for leisure on an entry-level Android phone."

### Scope and Limitations

- **Scope**: mobile build with onboarding, unified library, document import, multi-format reader, reading progress persistence.
- **Limitations**: lacks handwritten notes or margin comments (highlight-only markup), does not open DRM-protected or password-locked files, reading progress stored locally with no cross-device sync, file imports limited to local storage, large PDFs (>50 MB) load slowly on low-memory devices.

### Technical Stack & UI/UX Snapshot

- **Technical Stack**: Flutter, Dart, Syncfusion PDF viewer, open-source EPUB parser, Firebase Analytics.
- **Visual Mockups**:
  - `Image – onboarding carousel introducing format support`.
  - `Image – document import sheet with storage providers`.

### Design & Delivery Notes

- Emphasize objectives and features with larger typography and accent colors from the app palette (#2D6A4F green, #95D5B2 mint, #FFFFFF neutral).
- Maintain left-to-right flow: Problem → Objectives → Features → Users → Scope → Stack.
- Deliverable: PDF named `Act3-Infographic_Group#` submitted by single group member before Monday presentation.
