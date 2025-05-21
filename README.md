# SwiftUI Drawing Features

A collection of interactive SwiftUI components for iOS that provide various image processing and drawing capabilities. This project implements high-performance, animatable algorithms for creative image manipulation.

## Features

- 🎨 **FloodFill Tool**: Interactive flood fill with customizable colors and adjustable tolerance
- ✏️ **Stencil Creator**: Convert photos into line drawings perfect for coloring
- 🔄 Undo/Redo history management
- 💾 Save processed images
- 📱 Responsive UI with adaptive layout
- ✨ Animated effects with haptic feedback
- 📷 Photo library integration

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Manual Integration

1. Clone or download this repository
2. Drag the desired feature folder(s) into your Xcode project:
   - `FloodFillFeature/FloodFill` for flood fill functionality
   - `FloodFillFeature/DrawingImage` for stencil creation
3. Make sure to select "Copy items if needed" and add to your target

## Usage

### Basic Implementation

```swift
import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var inputImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isShowingFloodFill = false
    @State private var isShowingDrawingConverter = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            if let image = processedImage ?? inputImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            
            HStack(spacing: 20) {
                Button("Flood Fill") {
                    isShowingFloodFill = true
                }
                .disabled(inputImage == nil)
                
                Button("Create Stencil") {
                    isShowingDrawingConverter = true
                }
                .disabled(inputImage == nil)
            }
        }
        .sheet(isPresented: $isShowingFloodFill) {
            FloodFillView(inputImage: inputImage) { savedImage in
                self.processedImage = savedImage
                self.isShowingFloodFill = false
            }
        }
        .sheet(isPresented: $isShowingDrawingConverter) {
            DrawingImageView(inputImage: inputImage) { savedImage in
                self.processedImage = savedImage
                self.isShowingDrawingConverter = false
            }
        }
    }
}
```

## Components

### FloodFill Tool

Interactive flood fill algorithm with:
- Adjustable color tolerance for precise fills
- Animated fill effect
- Direct pixel manipulation for maximum performance
- Queue-based approach to efficiently fill connected areas

### Stencil Creator

Convert photos to line art drawings with:
- Adjustable edge intensity and line thickness
- Detail level control
- Advanced settings for professional results
- Multiple processing modes

## How It Works

### FloodFill Algorithm

The flood fill algorithm uses a queue-based approach to efficiently fill connected areas of similar colors:
1. **Color Tolerance**: Adjustable threshold for determining which pixels should be filled
2. **Animated Fill**: Progressive fill with visual updates as the algorithm runs
3. **Performance Optimization**: Uses queue-based breadth-first search instead of recursion

### Stencil Creator Algorithm

The stencil creation uses computer vision techniques to:
1. **Edge Detection**: Identify edges in the image
2. **Line Processing**: Convert edges to clean, drawable lines
3. **Detail Preservation**: Retain important details while simplifying the image

## License

This project is available under the MIT license. See the LICENSE file for more info.

## Author

Created by Saksham Shrey