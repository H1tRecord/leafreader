# LeafReader

## About

LeafReader is a lightweight, unified document reader app designed for students and casual readers who need to access PDF, EPUB, and text files without installing multiple apps. Built with Flutter, it provides a seamless reading experience across different document formats in a single application.

## Features

### 📚 Multi-Format Support

- **PDF Reader**: Full-featured PDF viewing with Syncfusion PDF viewer
- **EPUB Reader**: Rich EPUB support with customizable reading settings
- **Text Reader**: Plain text file reading with search and formatting options
- **File Selection**: Text selection enabled across all formats for easy copying

### 🎨 Customizable Reading Experience

- **Theme Support**: Light, Dark, and System theme modes
- **Font Customization**: Multiple font families (Serif, Sans-serif, Monospace, Times New Roman, Courier New)
- **Font Size Control**: Adjustable font sizes from 8pt to 32pt
- **Accent Colors**: Multiple accent color options for personalization

### 📁 Library Management

- **Folder Selection**: Choose any folder containing your documents
- **File Organization**: Grid and List view options
- **Search & Sort**: Search by filename, sort by name, date, or file type
- **File Operations**: Rename and delete files directly from the app
- **Multi-Select**: Bulk operations for managing multiple files

### 🔍 Advanced Reading Features

- **Search Functionality**: Full-text search within documents (TXT files)
- **Progress Persistence**: Auto-save reading position across sessions
- **Reading Settings**: Persistent font and display preferences per format

### 📱 Android Integration

- **Intent Handling**: Open files directly from other apps
- **Storage Permissions**: Proper Android storage access management
- **Material Design**: Modern UI following Material Design 3 guidelines

## Technical Stack

- **Framework**: Flutter 3.8.1+
- **Language**: Dart
- **PDF Rendering**: Syncfusion Flutter PDF Viewer
- **EPUB Processing**: epubx & epub_view packages
- **State Management**: Provider pattern
- **Storage**: SharedPreferences for settings persistence
- **Permissions**: permission_handler for Android storage access

## Architecture

The app follows a clean architecture pattern with clear separation of concerns:

- **`/screens`**: UI layer containing all screen widgets (Home, Readers, Settings, Onboarding)
- **`/services`**: Business logic and state management (HomeService, ReaderServices, etc.)
- **`/utils`**: Helper functions, UI builders, and shared utilities
- **Provider Pattern**: Reactive state management throughout the app

## Setup & Installation

1. **Prerequisites**: Flutter SDK 3.8.1 or higher
2. **Clone Repository**: `git clone [repository-url]`
3. **Install Dependencies**: `flutter pub get`
4. **Build APK**: `flutter build apk`
5. **Install**: Transfer APK to Android device and install

## Supported File Types

| Format | Extension | Features                                   |
| ------ | --------- | ------------------------------------------ |
| PDF    | `.pdf`    | Full PDF viewing, zoom, navigation         |
| EPUB   | `.epub`   | Rich text rendering, chapter navigation    |
| Text   | `.txt`    | Search, font customization, text selection |

## Permissions

- **Storage Access**: Required to read documents from device storage
- **File Management**: Optional for advanced file operations

## Development Status

Current Version: 0.1.0

### Completed Features ✅

- Multi-format document reading (PDF, EPUB, TXT)
- Customizable themes and fonts
- File management and organization
- Search functionality
- Settings persistence
- Android intent handling
- Onboarding flow

### Future Enhancements 🚧

- Bookmarks and annotations
- Cloud storage integration
- Cross-device sync
- Additional file format support
- Reading statistics
