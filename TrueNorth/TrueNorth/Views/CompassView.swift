import SwiftUI

struct CompassView: View {
    let heading: Double
    let isHeadTrackingActive: Bool
    let headingAccuracy: Double
    
    private let compassSize: CGFloat = 250
    
    var body: some View {
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
            
            Image(systemName: "location.north.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .rotationEffect(.degrees(-heading))
                .animation(.easeInOut(duration: 0.3), value: heading)
            
            VStack {
                Text("\(Int(heading))°")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.primary)
                
                if headingAccuracy > 0 {
                    Text("±\(Int(headingAccuracy))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        CompassView(heading: 45, isHeadTrackingActive: true, headingAccuracy: 5)
    }
}