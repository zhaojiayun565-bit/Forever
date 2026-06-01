import SwiftUI

// MARK: - Onboarding Investment Screen

struct OnboardingInvestmentView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Invest in your forever")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Watch your connection grow stronger over time, instead of drifting apart.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 8)

            Spacer()

            RelationshipGraphView()
                .frame(height: 320)
                .padding(.horizontal, 24)
                .accessibilityHidden(true)

            Spacer()

            OnboardingContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - Brand Colors (Splash palette)

private enum ForeverBrandColors {
    static let pink = Color(red: 1.0, green: 0.55, blue: 0.72)
    static let rose = Color(red: 0.95, green: 0.35, blue: 0.55)
    static let purple = Color(red: 0.72, green: 0.32, blue: 0.82)
    static let warmOrange = Color(red: 1.0, green: 0.45, blue: 0.62)
    static let warmGold = Color(red: 0.95, green: 0.45, blue: 0.62)
}

// MARK: - Relationship Graph

struct RelationshipGraphView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Reference anchor Y (0 = chart bottom, 1 = chart top)
    private let brandY: [CGFloat] = [0.20, 0.50, 0.60, 0.95]
    private let warningY: [CGFloat] = [0.05, 0.40, 0.25, 0.15]
    private let xFractions: [CGFloat] = [0, 1.0 / 3.0, 2.0 / 3.0, 1.0]
    private let xLabels = ["Today", "1 Year", "2 Years", "3 Years"]
    private let warningLabels = ["Routine", "Boredom", "Breakup"]

    /// Per-segment Bézier control points in normalized chart space (x, y from top-left of chartRect).
    private static let brandSegments: [GraphSegment] = [
        GraphSegment(cp1: CGPoint(x: 0.08, y: 0.55), cp2: CGPoint(x: 0.28, y: 0.48)),
        GraphSegment(cp1: CGPoint(x: 0.42, y: 0.50), cp2: CGPoint(x: 0.58, y: 0.58)),
        GraphSegment(cp1: CGPoint(x: 0.78, y: 0.62), cp2: CGPoint(x: 0.92, y: 0.35))
    ]

    private static let warningSegments: [GraphSegment] = [
        GraphSegment(cp1: CGPoint(x: 0.10, y: 0.88), cp2: CGPoint(x: 0.26, y: 0.42)),
        GraphSegment(cp1: CGPoint(x: 0.48, y: 0.38), cp2: CGPoint(x: 0.58, y: 0.72)),
        GraphSegment(cp1: CGPoint(x: 0.82, y: 0.78), cp2: CGPoint(x: 0.94, y: 0.82))
    ]

    private var palette: GraphPalette {
        GraphPalette(colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let chartRect = chartRect(in: geometry.size)
            let baselineY = chartRect.maxY
            let brandAnchors = chartPoints(in: chartRect, yValues: brandY)
            let warningAnchors = chartPoints(in: chartRect, yValues: warningY)
            let brandLine = curvedPath(anchors: brandAnchors, segments: Self.brandSegments, in: chartRect)
            let warningLine = curvedPath(anchors: warningAnchors, segments: Self.warningSegments, in: chartRect)
            let brandFill = areaPath(linePath: brandLine, anchors: brandAnchors, baselineY: baselineY)
            let warningFill = areaPath(linePath: warningLine, anchors: warningAnchors, baselineY: baselineY)

            ZStack {
                warningFill
                    .fill(palette.warningAreaGradient)
                brandFill
                    .fill(palette.brandAreaGradient)

                warningLine
                    .stroke(palette.warningStrokeGradient, style: strokeStyle)
                brandLine
                    .stroke(palette.brandStrokeGradient, style: strokeStyle)

                ForEach(Array(warningAnchors.enumerated()), id: \.offset) { index, point in
                    knotMarker(
                        at: point,
                        style: .solid,
                        lineColor: palette.warningKnotFill
                    )
                }
                ForEach(Array(brandAnchors.enumerated()), id: \.offset) { index, point in
                    knotMarker(
                        at: point,
                        style: knotStyle(line: .brand, index: index),
                        lineColor: palette.brandKnotFill
                    )
                }
            }
            .overlay {
                graphLabels(
                    size: geometry.size,
                    chartRect: chartRect,
                    warningAnchors: warningAnchors
                )
            }
        }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
    }

    private enum GraphLineKind {
        case brand
    }

    private enum KnotStyle {
        case solid
        case ring
    }

    private func knotStyle(line: GraphLineKind, index: Int) -> KnotStyle {
        switch line {
        case .brand:
            (index == 0 || index == 3) ? .solid : .ring
        }
    }

    @ViewBuilder
    private func knotMarker(at point: CGPoint, style: KnotStyle, lineColor: Color) -> some View {
        switch style {
        case .solid:
            Circle()
                .fill(lineColor)
                .frame(width: 8, height: 8)
                .position(point)
        case .ring:
            ZStack {
                Circle()
                    .stroke(lineColor, lineWidth: 2.5)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 6, height: 6)
            }
            .position(point)
        }
    }

    @ViewBuilder
    private func graphLabels(
        size: CGSize,
        chartRect: CGRect,
        warningAnchors: [CGPoint]
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0 ..< xLabels.count, id: \.self) { index in
                Text(xLabels[index])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .position(
                        x: chartRect.minX + chartRect.width * xFractions[index],
                        y: size.height - 10
                    )
            }

            Text(warningLabels[0])
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.warningLabel)
                .position(x: warningAnchors[1].x, y: warningAnchors[1].y - 22)

            let boredomX = (warningAnchors[1].x + warningAnchors[2].x) / 2
            let boredomY = warningAnchors[1].y + (warningAnchors[2].y - warningAnchors[1].y) * 0.45 - 22
            Text(warningLabels[1])
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.warningLabel)
                .position(x: boredomX, y: boredomY)

            Text(warningLabels[2])
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.warningLabel)
                .position(x: warningAnchors[3].x, y: warningAnchors[3].y - 22)

            let foreverPoint = CGPoint(
                x: chartRect.minX + chartRect.width * 0.75,
                y: chartRect.minY + chartRect.height * 0.55
            )
            HStack(spacing: 0) {
                Text("with ")
                    .foregroundStyle(.secondary)
                Text("forever.")
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .font(.caption)
            .position(foreverPoint)
        }
    }

    private func chartRect(in size: CGSize) -> CGRect {
        CGRect(
            x: 8,
            y: 48,
            width: max(size.width - 16, 1),
            height: max(size.height - 76, 1)
        )
    }

    private func chartPoints(in rect: CGRect, yValues: [CGFloat]) -> [CGPoint] {
        zip(xFractions, yValues).map { xFrac, yNorm in
            CGPoint(
                x: rect.minX + rect.width * xFrac,
                y: rect.maxY - rect.height * yNorm
            )
        }
    }

    private func pointInChartRect(_ normalized: CGPoint, _ rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * normalized.x,
            y: rect.minY + rect.height * normalized.y
        )
    }

    private func curvedPath(
        anchors: [CGPoint],
        segments: [GraphSegment],
        in chartRect: CGRect
    ) -> Path {
        guard anchors.count >= 2, segments.count == anchors.count - 1 else { return Path() }

        var path = Path()
        path.move(to: anchors[0])

        for index in segments.indices {
            let control1 = pointInChartRect(segments[index].cp1, chartRect)
            let control2 = pointInChartRect(segments[index].cp2, chartRect)
            path.addCurve(to: anchors[index + 1], control1: control1, control2: control2)
        }

        return path
    }

    private func areaPath(linePath: Path, anchors: [CGPoint], baselineY: CGFloat) -> Path {
        var path = linePath
        guard let first = anchors.first, let last = anchors.last else { return path }

        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.addLine(to: CGPoint(x: first.x, y: baselineY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Graph Geometry

private struct GraphSegment {
    let cp1: CGPoint
    let cp2: CGPoint
}

// MARK: - Graph Palette

private struct GraphPalette {
    let fillOpacity: Double

    init(colorScheme: ColorScheme) {
        fillOpacity = colorScheme == .dark ? 0.42 : 0.28
    }

    var brandStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [ForeverBrandColors.pink, ForeverBrandColors.rose, ForeverBrandColors.purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var warningStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [ForeverBrandColors.warmOrange, ForeverBrandColors.warmGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var brandAreaGradient: LinearGradient {
        LinearGradient(
            colors: [
                ForeverBrandColors.pink.opacity(fillOpacity),
                ForeverBrandColors.rose.opacity(fillOpacity * 0.7),
                ForeverBrandColors.purple.opacity(fillOpacity * 0.35),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var warningAreaGradient: LinearGradient {
        LinearGradient(
            colors: [
                ForeverBrandColors.warmOrange.opacity(fillOpacity),
                ForeverBrandColors.warmGold.opacity(fillOpacity * 0.45),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var brandKnotFill: Color { ForeverBrandColors.pink }
    var warningKnotFill: Color { ForeverBrandColors.warmOrange }
    var warningLabel: Color { ForeverBrandColors.warmOrange }
}

// MARK: - Previews

#Preview("Light") {
    OnboardingInvestmentView(onContinue: {})
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.14).opacity(0.08),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
        )
}

#Preview("Dark") {
    OnboardingInvestmentView(onContinue: {})
        .preferredColorScheme(.dark)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.14).opacity(0.08),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
        )
}

#Preview("Graph") {
    RelationshipGraphView()
        .frame(height: 320)
        .padding(.horizontal, 24)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#if DEBUG
#Preview("Graph vs Reference") {
    ZStack {
        Color.black.ignoresSafeArea()
        RelationshipGraphView()
            .frame(height: 320)
            .padding(.horizontal, 24)
    }
    .preferredColorScheme(.dark)
}
#endif
