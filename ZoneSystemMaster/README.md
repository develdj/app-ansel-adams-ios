# Zone System Master - Photo Editor Engine

A professional black and white photo editor that faithfully replicates Ansel Adams' darkroom techniques using Metal compute shaders, Core Image filters, and SwiftUI.

## Features

### 1. Luminosity Masks (Zone System)
- **Lights Mask** (Zone VIII-X) - Highlights
- **Lights Medium** (Zone VI-VII) - Bright midtones
- **Midtones** (Zone V) - Middle gray (18%)
- **Darks Medium** (Zone III-IV) - Dark midtones
- **Darks** (Zone 0-II) - Shadows
- Progressive feathering with Gaussian blur
- Custom zone range masks
- Mask operations (intersect, union, subtract)

### 2. Dodge & Burn
- Simulates darkroom dodging (lightening)
- Simulates darkroom burning (darkening)
- Dynamic brush shapes: circular, elliptical, freeform
- Adjustable intensity and exposure time
- Brush hardness control
- Accumulation-based exposure simulation
- Full undo/redo support

### 3. Tonal Curves (H&D Curve Simulation)
- Characteristic curve simulation
- Black/white point control
- Gamma adjustment
- Toe and shoulder compression
- Contrast control
- Zone-optimized curves
- Ansel Adams style presets
- Real-time curve editing with control points

### 4. Split Grade Printing
- Multigrade paper simulation (00-5)
- Dual exposure simulation
- Mask-based selective grading
- Low/high grade blending

### 5. Film Grain Simulation
- **HP5 Plus** - Moderate grain, good detail
- **Tri-X** - Classic grain, high contrast
- **Delta 100/400** - Fine grain
- **T-Max 100/400** - Very fine, sharp
- **FP4 Plus** - Traditional fine grain
- **Pan F Plus** - Ultra fine grain
- Push/pull processing simulation
- Luminance-dependent grain visibility

### 6. Annotation Overlay
- Zone markers (Ansel Adams style)
- Exposure adjustment indicators (+/- stops)
- Circles, arrows, rectangles
- Freehand drawing
- Bezier curves
- Text annotations
- Multiple layers

### 7. Additional Features
- Vignetting (lens/darkroom edge darkening)
- Sharpening (unsharp mask)
- B&W conversion with color filter simulation
- Non-destructive layer system
- Full undo/redo history
- Export in multiple formats (TIFF, JPEG, PNG, HEIC)

## Architecture

### Core Components

```
ZoneSystemMaster/
├── Shaders/
│   └── ZoneSystemShaders.metal    # Metal compute shaders
├── Core/
│   ├── EditorEngine.swift          # Main processing engine
│   ├── LayerManager.swift          # Non-destructive layer system
│   └── LuminosityMaskEngine.swift  # Mask generation
├── Tools/
│   ├── DodgeBurnTool.swift         # Dodge & Burn tool
│   ├── CurveEditor.swift           # Tonal curve editor
│   ├── AnnotationOverlay.swift     # Annotation system
│   └── FilmGrainSimulator.swift    # Film grain simulation
├── Models/
│   └── ZoneSystemModels.swift      # Data models
├── UI/
│   ├── ZoneSystemEditorView.swift  # Main editor view
│   └── Panels.swift                # Tool panels
└── Utilities/
    └── Extensions.swift            # Utility extensions
```

### Metal Shaders

The engine includes 15+ compute shaders:

- `generateLuminosityMask` - Creates luminosity-based masks
- `generateZoneMasks` - Generates all zone masks at once
- `applyDodgeBurn` - Applies dodge/burn with brush
- `generateBrushPattern` - Creates brush textures
- `applyCharacteristicCurve` - H&D curve simulation
- `applyPaperGradeCurve` - Multigrade paper simulation
- `applyFilmGrain` - Film grain generation
- `applySplitGrade` - Split grade printing
- `applyVignetting` - Vignette effect
- `convertToBlackAndWhite` - B&W conversion
- `applyUnsharpMask` - Sharpening
- `blendLayers` - Layer blending
- `gaussianBlurHorizontal/Vertical` - Separable Gaussian blur
- `analyzeZones` - Zone histogram analysis

## Usage

### Basic Workflow

1. **Load Image**
   ```swift
   await engine.loadImage(from: imageURL)
   ```

2. **Apply B&W Conversion**
   - Choose color filter simulation
   - Adjust contrast and brightness

3. **Adjust Tonal Curves**
   - Use presets or custom curves
   - Optimize for zone system

4. **Generate Luminosity Masks**
   - Generate all zone masks
   - Or create custom range masks

5. **Apply Dodge & Burn**
   - Select dodge or burn mode
   - Adjust brush size and intensity
   - Paint on image

6. **Add Film Grain**
   - Select film type
   - Adjust intensity and size
   - Apply push/pull if needed

7. **Export**
   - Choose format and quality
   - Select color space
   - Save or share

### Example Code

```swift
import ZoneSystemMaster

// Create engine
guard let engine = EditorEngine() else {
    return
}

// Load image
await engine.loadImage(from: imageURL)

// Configure B&W conversion
engine.bwSettings = BWConversionSettings(
    redFilter: 0.299,
    greenFilter: 0.587,
    blueFilter: 0.114,
    contrast: 1.2,
    brightness: 0.0
)

// Configure curves
engine.curveSettings = TonalCurveSettings(
    blackPoint: 0.02,
    whitePoint: 0.98,
    gamma: 1.0,
    toe: 0.1,
    shoulder: 0.1,
    contrast: 1.1
)

// Configure film grain
engine.filmGrainSettings = FilmGrainSettings(
    filmType: .hp5,
    intensity: 0.6,
    grainSize: 1.0,
    pushPull: 0
)

// Process image
await engine.processImage()

// Export
let exportSettings = ExportSettings(
    format: .tiff,
    quality: 1.0,
    resolution: .original,
    colorSpace: .grayGamma22
)
let imageData = try await engine.export(with: exportSettings)
```

## Zone System Reference

| Zone | Description | Luminance | Typical Subject |
|------|-------------|-----------|-----------------|
| 0 | Pure black | 0% | Maximum black |
| I | Near black | 1% | Slight tonality |
| II | Dark gray | 3.5% | First texture |
| III | Dark gray | 9% | Shadow detail |
| IV | Medium dark | 18% | Dark foliage |
| V | Middle gray | 36% | 18% gray card |
| VI | Light gray | 50% | Caucasian skin |
| VII | Light gray | 68% | Light skin |
| VIII | Very light | 81% | White with texture |
| IX | Very light | 91% | Glaring snow |
| X | Pure white | 100% | Paper white |

## Requirements

- iOS 17.0+
- iPadOS 17.0+
- macOS 14.0+
- Xcode 15.0+
- Swift 6.0+
- Metal 3.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ZoneSystemMaster.git", from: "1.0.0")
]
```

### Manual Installation

1. Clone the repository
2. Add files to your Xcode project
3. Link required frameworks:
   - Metal
   - MetalKit
   - CoreImage
   - SwiftUI

## Performance

- GPU-accelerated processing via Metal
- Real-time preview at reduced resolution
- Background processing for full resolution
- Texture caching for repeated operations
- Efficient memory management

## Credits

Inspired by the Zone System developed by Ansel Adams and Fred Archer.

Film characteristics based on published data from:
- Ilford Photo
- Kodak Alaris
- Fujifilm

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

## Roadmap

- [ ] RAW processing pipeline
- [ ] Batch processing
- [ ] Custom film profiles
- [ ] Plugin system
- [ ] Cloud sync
- [ ] iCloud Drive integration
- [ ] Shortcuts app support
