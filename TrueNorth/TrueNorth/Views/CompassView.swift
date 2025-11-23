import SwiftUI

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

struct CompassView: View {
    let heading: Double
    let isHeadTrackingActive: Bool
    let headingAccuracy: Double
    let deviceHeading: Double
    let smoothedDeviceHeading: Double
    let headOffset: Double

    private let compassSize: CGFloat = 250
    private let alignmentThreshold: Double = 5.0  // Degrees tolerance for alignment

    // Track cumulative rotation to avoid 360° wraparound issues
    @State private var cumulativeRotation: Double = 0
    @State private var previousHeading: Double = 0
    @State private var isAligned: Bool = false
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ZStack {
            // Rotating compass rose - rotates based on DEVICE heading only (not head rotation)
            // This shows where your phone/body is pointing relative to north
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: compassSize, height: compassSize)

                ForEach(0..<360, id: \.self) { degree in
                    if degree % 30 == 0 {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: degree % 90 == 0 ? 3 : 1,
                                   height: degree % 90 == 0 ? 20 : 10)
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

            HStack(alignment: .bottom, spacing: 20) {
                // Device heading (smaller, left)
                Text("\(Int(deviceHeading))°")
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                    .alignmentGuide(.bottom) { d in d[.bottom] }
                
                // Combined heading (prominent, center)
                VStack(spacing: 2) {
                    Text("\(Int(heading))°")
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 90)
                    
                    if headingAccuracy > 0 {
                        Text("±\(Int(headingAccuracy))°")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        // Placeholder to maintain spacing
                        Text(" ")
                            .font(.system(size: 12))
                    }
                }
                .frame(width: 90)
                
                // Head offset (smaller, right) - format with sign and padding
                Text(String(format: "%+4d°", Int(headOffset)))
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundColor(isHeadTrackingActive ? .green : .secondary)
                    .frame(width: 60, alignment: .leading)
                    .alignmentGuide(.bottom) { d in d[.bottom] }
            }
            .offset(y: compassSize / 2 + 40)
            
            if isHeadTrackingActive {
                Image(systemName: "airpodspro")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .offset(x: -compassSize / 2 + 20, y: -compassSize / 2 + 20)
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
            // Prepare haptic generator
            hapticGenerator.prepare()
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

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(heading: 45, isHeadTrackingActive: true, headingAccuracy: 5, deviceHeading: 50, smoothedDeviceHeading: 50, headOffset: -5)
    }
}
