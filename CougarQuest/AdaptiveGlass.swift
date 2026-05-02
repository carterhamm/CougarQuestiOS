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
            self.glassEffect(.clear.tint(color), in: shape)
        } else {
            self.background(shape.fill(color))
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
