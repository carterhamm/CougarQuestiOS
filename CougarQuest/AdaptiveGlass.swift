//
//  AdaptiveGlass.swift
//  CougarQuest
//

import SwiftUI

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

extension View {
    @ViewBuilder
    func adaptiveGlassEffect(
        in shape: some Shape = RoundedRectangle(cornerRadius: 50),
        strokeColor: Color? = nil,
        strokeWidth: CGFloat = 1.2
    ) -> some View {
        self.modifier(AdaptiveGlassModifier(shape: AnyShape(shape), strokeColor: strokeColor, strokeWidth: strokeWidth))
    }

    @ViewBuilder
    func adaptiveGlassEffectTinted(color: Color, in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            // .regular renders a visible material surface, then we layer a
            // colored fill in the same shape behind it so the tint reads
            // even when the parent is itself a glass card. Plain
            // .clear.tint(color) was rendering effectively invisible when
            // applied to clear/transparent content.
            self
                .background(shape.fill(color))
                .glassEffect(.regular.tint(color), in: shape)
        } else {
            self
                .background(shape.fill(color))
                .background(shape.fill(.ultraThinMaterial))
        }
    }
}

private struct AdaptiveGlassModifier: ViewModifier {
    let shape: AnyShape
    let strokeColor: Color?
    let strokeWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(
                    Group {
                        if let strokeColor = strokeColor {
                            shape.stroke(strokeColor, lineWidth: strokeWidth).padding(0.4)
                        }
                    }
                )
        }
    }
}
