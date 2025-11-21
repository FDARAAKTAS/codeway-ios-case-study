# iOS Photo Scanner Case Study

## Overview
An iOS application that scans the device photo library, generates deterministic values for each photo, and groups them based on predefined ranges.

## 📱 Features

### Core Features
- ✅ PHAsset-based photo library scanning
- ✅ Deterministic hash generation (0.0 - 1.0)
- ✅ 20 photo groups with non-contiguous ranges
- ✅ "Others" category for ungrouped photos
- ✅ Progressive scan results visibility

### Bonus Features
- ✅ Real-time progress bar with percentage display
- ✅ Scan progress persistence (resume after app restart)
- ✅ Grouping results persistence
- ✅ Swipeable image detail view with TabView

## 🏗 Architecture

- **Pattern**: MVVM (Model-View-ViewModel)
- **Principles**: SOLID
- **UI Framework**: UIKit (Home Screen) + SwiftUI (Detail Screens)
- **Frameworks**: Combine, Photos, CryptoKit, UIKit, SwiftUI

## 🚀 How to Run

1. Clone the repository
2. Open `Photoscnanner.xcodeproj`
3. Select target device (iOS 15.0+)
4. Run (⌘R)
5. Grant photo library access when prompted

## 🎯 Technical Highlights

### Concurrency & Performance
- Concurrent scanning with batch processing (100 assets/batch)
- Separate queues for computation and UI updates
- Throttled UI updates (0.1s interval)
- Periodic state persistence (1s interval)

### Memory Optimization
- PHCachingImageManager for efficient image loading
- Progressive loading with on-demand image requests
- Request lifecycle management with cancellation
- Preloading strategy (±10 images around visible area)

### State Management
- Combine publishers with deduplication
- Thread-safe state mutations
- Proper cleanup and weak references

## 📊 Requirements

- **iOS**: 15.0+
- **Xcode**: 14.0+
- **Swift**: 5.7+

---

**Developer**: Fikret Aktaş  
**Date**: November 2024  
**Purpose**: iOS Developer (New Grad) - Technical Case Study
