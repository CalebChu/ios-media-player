import SwiftUI

public struct LiquidGlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let specularOpacity: Double
    public let content: Content

    public init(
        cornerRadius: CGFloat = 20,
        specularOpacity: Double = 0.35,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.specularOpacity = specularOpacity
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .liquidGlass(
                cornerRadius: cornerRadius,
                specularOpacity: specularOpacity
            )
    }
}
