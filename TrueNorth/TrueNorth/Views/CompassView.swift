import SwiftUI

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Custom triangular arrow shape with notched base (like GPS pointer)
struct TriangularArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let notchDepth: CGFloat = rect.height * 0.15  // 15% indent at base

        // Create a triangular pointer with an indentation at the base
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))  // Top point
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))  // Bottom right
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notchDepth))  // Indent point (center)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))  // Bottom left
        path.closeSubpath()

        return path
    }
}

// Traditional 8-pointed compass rose pattern
struct TraditionalCompassRose: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Draw 8 points - 4 cardinal (longer) and 4 intercardinal (shorter)
        for i in 0..<8 {
            let angle = Double(i) * 45.0 - 90.0 // Start at top (North)
            let isCardinal = i % 2 == 0
            let outerLength = isCardinal ? radius * 0.95 : radius * 0.65
            let innerWidth = isCardinal ? radius * 0.12 : radius * 0.08

            // Calculate the 4 points of each diamond/rhombus
            let angleRad = angle * .pi / 180.0
            let leftAngleRad = (angle - 90) * .pi / 180.0
            let rightAngleRad = (angle + 90) * .pi / 180.0

            let tip = CGPoint(
                x: center.x + CGFloat(cos(angleRad)) * outerLength,
                y: center.y + CGFloat(sin(angleRad)) * outerLength
            )

            let leftEdge = CGPoint(
                x: center.x + CGFloat(cos(leftAngleRad)) * innerWidth,
                y: center.y + CGFloat(sin(leftAngleRad)) * innerWidth
            )

            let rightEdge = CGPoint(
                x: center.x + CGFloat(cos(rightAngleRad)) * innerWidth,
                y: center.y + CGFloat(sin(rightAngleRad)) * innerWidth
            )

            // Draw the diamond point
            path.move(to: tip)
            path.addLine(to: leftEdge)
            path.addLine(to: center)
            path.addLine(to: rightEdge)
            path.closeSubpath()
        }

        return path
    }
}

struct CompassView: View {
    let heading: Double
    let isHeadTrackingActive: Bool
    let headingAccuracy: Double
    let deviceHeading: Double
    let smoothedDeviceHeading: Double
    let headOffset: Double
    @Binding var volume: Float
    let onVolumeChange: (Float) -> Void

    private let compassSize: CGFloat = 250
    private let alignmentThreshold: Double = 5.0  // Degrees tolerance for alignment

    // Track cumulative rotation to avoid 360° wraparound issues
    @State private var cumulativeRotation: Double = 0
    @State private var previousHeading: Double = 0
    @State private var isAligned: Bool = false
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    @State private var tickHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var lastCrossedTick: Int = -1
    @State private var showBottomSheet: Bool = true
    @State private var selectedDetent: PresentationDetent = .height(120)

    var body: some View {
        ZStack {
            // Rotating compass rose - rotates based on DEVICE heading only (not head rotation)
            // This shows where your phone/body is pointing relative to north
            ZStack {
                // Traditional 8-pointed compass rose pattern (subtle background)
                TraditionalCompassRose()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: compassSize - 20, height: compassSize - 20)

                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: compassSize, height: compassSize)

                ForEach(0..<360, id: \.self) { degree in
                    if degree % 10 == 0 {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: degree % 90 == 0 ? 3 : (degree % 30 == 0 ? 1.5 : 1),
                                   height: degree % 90 == 0 ? 20 : (degree % 30 == 0 ? 12 : 8))
                            .offset(y: -compassSize / 2 + 10)
                            .rotationEffect(.degrees(Double(degree)))
                    }
                }

                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    Text(direction)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(direction == "N" ? .red : .primary)
                        .offset(y: -compassSize / 2 + 35)
                        .rotationEffect(.degrees(degrees(for: direction)))
                }
            }
            .rotationEffect(.degrees(-cumulativeRotation))  // Use cumulative rotation to avoid wraparound
            .animation(.easeInOut(duration: 0.3), value: cumulativeRotation)
            .onChange(of: smoothedDeviceHeading) { newHeading in
                // Calculate shortest path between previous and new heading
                var delta = newHeading - previousHeading

                // Handle wraparound: if delta > 180, go the other way
                if delta > 180 {
                    delta -= 360
                } else if delta < -180 {
                    delta += 360
                }

                // Update cumulative rotation by the delta
                cumulativeRotation += delta
                previousHeading = newHeading

                // Haptic feedback when crossing 10-degree marks
                let currentTick = Int(newHeading / 10) % 36
                if currentTick != lastCrossedTick {
                    tickHapticGenerator.impactOccurred(intensity: 0.5)
                    lastCrossedTick = currentTick
                }
            }
            .onAppear {
                // Initialize with current heading
                cumulativeRotation = smoothedDeviceHeading
                previousHeading = smoothedDeviceHeading
            }

            // Fixed heading indicator (red) - shows which way you're facing - centered
            TriangularArrow()
                .fill(Color.red.opacity(0.7))  // Red arrow
                .frame(width: 50, height: 60)

            // Head tracking arrow (blue) - shows head direction relative to device
            // Only visible when head tracking is active
            // When aligned with red, creates purple overlay
            if isHeadTrackingActive {
                TriangularArrow()
                    .fill(Color.blue.opacity(0.6))  // Blue arrow - overlays red to make purple when aligned
                    .frame(width: 50, height: 60)
                    .rotationEffect(.degrees(-headOffset))  // Negated to fix inversion
                    .animation(.easeInOut(duration: 0.2), value: headOffset)
            }

            // Warning when AirPods not connected
            if !isHeadTrackingActive {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                    Text("No AirPods")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .offset(x: -compassSize / 2 + 35, y: -compassSize / 2 + 35)
            }
        }
        .frame(width: compassSize + 60, height: compassSize + 100)
        .onChange(of: headOffset) { newOffset in
            // Check if arrows are now aligned
            let nowAligned = abs(newOffset) < alignmentThreshold && isHeadTrackingActive

            // Trigger haptic when transitioning to aligned state
            if nowAligned && !isAligned {
                hapticGenerator.impactOccurred()
            }

            isAligned = nowAligned
        }
        .onAppear {
            // Prepare haptic generators
            hapticGenerator.prepare()
            tickHapticGenerator.prepare()
        }
        .sheet(isPresented: $showBottomSheet) {
            BottomSheetContent(
                volume: $volume,
                onVolumeChange: onVolumeChange,
                heading: heading,
                deviceHeading: deviceHeading,
                headOffset: headOffset,
                headingAccuracy: headingAccuracy,
                isHeadTrackingActive: isHeadTrackingActive,
                selectedDetent: $selectedDetent
            )
            .presentationDetents([.height(120), .height(200), .medium], selection: $selectedDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }

    private func degrees(for direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

// Bottom sheet content view
struct BottomSheetContent: View {
    @Binding var volume: Float
    let onVolumeChange: (Float) -> Void
    let heading: Double
    let deviceHeading: Double
    let headOffset: Double
    let headingAccuracy: Double
    let isHeadTrackingActive: Bool
    @Binding var selectedDetent: PresentationDetent

    var body: some View {
        VStack(spacing: 16) {
            // Volume control - always visible
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.secondary)
                    Text("Volume")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(value: $volume, in: 0...1) { _ in
                    onVolumeChange(volume)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Debug info - visible at larger detents
            if selectedDetent != .height(120) {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 20)

                    HStack(alignment: .bottom, spacing: 20) {
                        // Device heading
                        VStack(spacing: 2) {
                            Text("Device")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(Int(deviceHeading))°")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        // Combined heading
                        VStack(spacing: 2) {
                            Text("Combined")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(Int(heading))°")
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)

                            if headingAccuracy > 0 {
                                Text("±\(Int(headingAccuracy))°")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Head offset
                        VStack(spacing: 2) {
                            Text("Offset")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(String(format: "%+d°", Int(headOffset)))
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(isHeadTrackingActive ? .green : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .padding(.bottom, 20)
    }
}

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(
            heading: 45,
            isHeadTrackingActive: true,
            headingAccuracy: 5,
            deviceHeading: 50,
            smoothedDeviceHeading: 50,
            headOffset: -5,
            volume: .constant(0.5),
            onVolumeChange: { _ in }
        )
    }
}
