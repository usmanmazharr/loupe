import SwiftUI

/// Draggable floating button that opens the Loupe logger.
public struct FloatingDebugButton: View {

    @State private var position: CGPoint = CGPoint(x: 60, y: 120)
    @State private var isDragging = false
    @State private var isPresented = false

    private let size: CGFloat = 52

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if isPresented {
                    LoupeView(isPresented: $isPresented)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                button
                    .position(clamp(position, in: geo.size))
                    .gesture(dragGesture(bounds: geo.size))
                    .animation(.interactiveSpring(), value: position)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Private

    private var button: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

            Image(systemName: "network")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.blue)
        }
        .frame(width: size, height: size)
        .scaleEffect(isDragging ? 1.12 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isPresented = true
            }
        }
    }

    private func dragGesture(bounds: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                isDragging = true
                position = value.location
            }
            .onEnded { value in
                isDragging = false
                // Snap to nearest edge
                let snappedX: CGFloat = value.location.x < bounds.width / 2 ? size / 2 + 8 : bounds.width - size / 2 - 8
                withAnimation(.spring()) {
                    position = CGPoint(x: snappedX, y: value.location.y)
                }
            }
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, self.size / 2 + 8), size.width - self.size / 2 - 8),
            y: min(max(point.y, self.size / 2 + 8), size.height - self.size / 2 - 8)
        )
    }
}
