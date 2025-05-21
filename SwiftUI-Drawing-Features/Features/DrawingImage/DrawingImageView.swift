//
//  DrawingImageView.swift
//  FloodFillFeature
//
//  Created by Saksham Shrey on 03/05/25.
//

import SwiftUI
import PhotosUI

struct DrawingImageView: View {
    @StateObject private var viewModel = DrawingImageViewModel()
    var inputImage: UIImage?
    var onSave: (UIImage) -> Void
    
    // UI state
    @State private var showingSettings = false
    @State private var showAdvancedControls = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // Display either processed or input image
                ZStack {
                    if let processedImage = viewModel.processedImage {
                        Image(uiImage: processedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .shadow(radius: 5)
                    } else if let currentImage = viewModel.currentImage {
                        Image(uiImage: currentImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .shadow(radius: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Text("No Image Selected")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Processing indicator
                    if viewModel.isProcessing {
                        Color.black.opacity(0.5)
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(2)
                                    
                                    Text("Processing...")
                                        .foregroundColor(.white)
                                        .padding(.top)
                                }
                            )
                    }
                }
                .cornerRadius(10)
                .padding()
                
                Text("Creates a stencil drawing suitable for coloring")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Mode Selection
                Picker("Mode", selection: $viewModel.processingMode) {
                    ForEach(DrawingImageViewModel.ProcessingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Main controls
                        VStack(alignment: .leading) {
                            // Edge intensity slider
                            VStack(alignment: .leading) {
                                Text("Edge Intensity: \(viewModel.edgeIntensity, specifier: "%.1f")")
                                    .font(.headline)
                                
                                Slider(value: $viewModel.edgeIntensity, in: 1.0...20.0, step: 0.5)
                            }
                            .padding(.horizontal)
                            
                            // Line thickness slider
                            VStack(alignment: .leading) {
                                Text("Line Thickness: \(viewModel.lineThickness, specifier: "%.2f")")
                                    .font(.headline)
                                
                                Slider(value: $viewModel.lineThickness, in: 0.1...2.0, step: 0.05)
                            }
                            .padding(.horizontal)
                            
                            // Detail level slider
                            VStack(alignment: .leading) {
                                Text("Detail Level: \(viewModel.detailLevel, specifier: "%.2f")")
                                    .font(.headline)
                                
                                Slider(value: $viewModel.detailLevel, in: 0.0...1.0, step: 0.05)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Advanced controls toggle
                        DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedControls) {
                            VStack(spacing: 16) {
                                // Threshold slider
                                VStack(alignment: .leading) {
                                    Text("Threshold: \(viewModel.threshold, specifier: "%.2f")")
                                        .font(.headline)
                                    
                                    Slider(value: $viewModel.threshold, in: 0.01...1.0, step: 0.01)
                                }
                                .padding(.horizontal)
                                
                                // Stroke distance slider
                                VStack(alignment: .leading) {
                                    Text("Stroke Distance: \(viewModel.strokeDistance, specifier: "%.2f")")
                                        .font(.headline)
                                        .help("Controls the merging of nearby strokes. Higher values merge closer strokes.")
                                    
                                    HStack {
                                        Text("Close")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        Slider(value: $viewModel.strokeDistance, in: 0.0...1.0, step: 0.01)
                                        
                                        Text("Far")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Smoothing level slider
                                VStack(alignment: .leading) {
                                    Text("Edge Smoothing: \(viewModel.smoothingLevel, specifier: "%.2f")")
                                        .font(.headline)
                                    
                                    Slider(value: $viewModel.smoothingLevel, in: 0.0...1.0, step: 0.05)
                                }
                                .padding(.horizontal)
                                
                                // Preserve black areas toggle
                                Toggle("Preserve Black Areas", isOn: $viewModel.preserveBlackAreas)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                // Adaptive threshold toggle
                                Toggle("Use Adaptive Threshold", isOn: $viewModel.useAdaptiveThreshold)
                                    .font(.headline)
                                    .padding(.horizontal)
                            }
                            .padding(.top)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        
                        // Convert button
                        Button(action: {
                            viewModel.convertToDrawing()
                        }) {
                            Text("Create Stencil Drawing")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.isProcessing || viewModel.currentImage == nil)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                
                // Bottom toolbar
                HStack {
                    Button(action: {
                        viewModel.resetImage()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.undo()
                    }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.canUndo)
                    
                    Button(action: {
                        viewModel.redo()
                    }) {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.canRedo)
                    
                    Spacer()
                    
                    Button(action: {
                        if let processedImage = viewModel.processedImage {
                            onSave(processedImage)
                        }
                    }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .padding(10)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.processedImage == nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Stencil Creator")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let inputImage = inputImage {
                    viewModel.initializeWithImage(inputImage)
                }
            }
        }
    }
}

#Preview {
    DrawingImageView(inputImage: UIImage(named: "testImage")) { _ in }
} 