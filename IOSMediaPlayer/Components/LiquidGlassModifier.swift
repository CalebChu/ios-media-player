import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var specularOpacity: Double
    public var material: Material
    public var shadowRadius: CGFloat

    public init(
        cornerRadius: CGFloat = 20,
        specularOpacity: Double = 0.35,
        material: Material = .ultraThinMaterial,
        shadowRadius: CGFloat = 12
    ) {
        self.cornerRadius = cornerRadius
        self.specularOpacity = specularOpacity
        self.material = material
        self.shadowRadius = shadowRadius
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(specularOpacity), location: 0.0),
                                    .init(color: .white.opacity(specularOpacity * 0.4), location: 0.3),
                                    .init(color: .white.opacity(specularOpacity * 0.05), location: 0.7),
                                    .init(color: .white.opacity(specularOpacity * 0.2), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
                .shadow(
                    color: Color.black.opacity(0.22),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowRadius * 0.4
                )
        }
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    public var specularOpacity: Double
    public var material: Material

    public init(
        specularOpacity: Double = 0.4,
        material: Material = .ultraThinMaterial
    ) {
        self.specularOpacity = specularOpacity
        self.material = material
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background {
                    Capsule()
                        .fill(material)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(specularOpacity), location: 0.0),
                                    .init(color: .white.opacity(specularOpacity * 0.3), location: 0.35),
                                    .init(color: .white.opacity(0.0), location: 0.65),
                                    .init(color: .white.opacity(specularOpacity * 0.25), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        }
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 20,
        specularOpacity: Double = 0.35,
        material: Material = .ultraThinMaterial,
        shadowRadius: CGFloat = 12
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                specularOpacity: specularOpacity,
                material: material,
                shadowRadius: shadowRadius
            )
        )
    }

    func liquidGlassPill(
        specularOpacity: Double = 0.4,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(
            LiquidGlassPillModifier(
                specularOpacity: specularOpacity,
                material: material
            )
        )
    }
}
