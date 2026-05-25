#!/usr/bin/env swift
// Renders the Fitness Planner app icon: a cute smiling dumbbell on a peach→coral
// gradient. Run from the repo root:
//   swift scripts/generate_app_icon.swift FitnessPlanner/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import AppKit
import SwiftUI

@available(macOS 13.0, *)
struct AppIcon: View {
    var body: some View {
        ZStack {
            background
            shine
            dumbbell
                .rotationEffect(.degrees(-8))
            sparkles
        }
        .frame(width: 1024, height: 1024)
        .drawingGroup()
    }

    // MARK: - Palette

    private var bgTop: Color { Color(red: 1.00, green: 0.84, blue: 0.69) }
    private var bgBottom: Color { Color(red: 1.00, green: 0.52, blue: 0.43) }
    private var ironDark: Color { Color(red: 0.20, green: 0.14, blue: 0.19) }
    private var ironMid: Color { Color(red: 0.30, green: 0.22, blue: 0.27) }
    private var cheek: Color { Color(red: 1.00, green: 0.58, blue: 0.62) }

    // MARK: - Pieces

    private var background: some View {
        LinearGradient(
            colors: [bgTop, bgBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shine: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 420, height: 420)
                .offset(x: -240, y: -260)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .offset(x: 280, y: -300)
        }
    }

    private var dumbbell: some View {
        ZStack {
            // Bar
            RoundedRectangle(cornerRadius: 70)
                .fill(
                    LinearGradient(
                        colors: [ironMid, ironDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 560, height: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 70)
                        .stroke(Color.black.opacity(0.25), lineWidth: 6)
                )

            weight.offset(x: -310, y: 0)
            weight.offset(x: 310, y: 0)

            face
        }
    }

    private var weight: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 70)
                .fill(
                    LinearGradient(
                        colors: [ironMid, ironDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 260, height: 360)
                .overlay(
                    RoundedRectangle(cornerRadius: 70)
                        .stroke(Color.black.opacity(0.25), lineWidth: 6)
                )

            // Inset plate
            RoundedRectangle(cornerRadius: 46)
                .stroke(Color.white.opacity(0.18), lineWidth: 4)
                .frame(width: 170, height: 270)

            // Soft top-left highlight
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.white.opacity(0.16))
                .frame(width: 70, height: 130)
                .offset(x: -60, y: -100)
        }
    }

    private var face: some View {
        ZStack {
            HStack(spacing: 82) {
                eye
                eye
            }
            .offset(y: -4)

            Smile()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 140, height: 56)
                .offset(y: 40)

            HStack(spacing: 196) {
                Capsule().fill(cheek.opacity(0.9)).frame(width: 42, height: 20)
                Capsule().fill(cheek.opacity(0.9)).frame(width: 42, height: 20)
            }
            .offset(y: 32)
        }
    }

    private var eye: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 56, height: 56)
            Circle().fill(ironDark).frame(width: 26, height: 26).offset(x: 5, y: 5)
            Circle().fill(Color.white).frame(width: 10, height: 10).offset(x: -2, y: -2)
        }
    }

    private var sparkles: some View {
        ZStack {
            SparkleShape().fill(Color.white.opacity(0.95))
                .frame(width: 90, height: 90)
                .offset(x: 340, y: -340)
            SparkleShape().fill(Color.white.opacity(0.85))
                .frame(width: 52, height: 52)
                .offset(x: -370, y: 320)
                .rotationEffect(.degrees(18))
            SparkleShape().fill(Color.white.opacity(0.7))
                .frame(width: 36, height: 36)
                .offset(x: 380, y: 280)
            SparkleShape().fill(Color.white.opacity(0.7))
                .frame(width: 28, height: 28)
                .offset(x: -300, y: -360)
        }
    }
}

@available(macOS 13.0, *)
struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: r.minX, y: r.midY)
        let end = CGPoint(x: r.maxX, y: r.midY)
        let ctrl = CGPoint(x: r.midX, y: r.maxY + 32)
        p.move(to: start)
        p.addQuadCurve(to: end, control: ctrl)
        return p
    }
}

@available(macOS 13.0, *)
struct SparkleShape: Shape {
    func path(in r: CGRect) -> Path {
        let cx = r.midX, cy = r.midY
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.30
        var p = Path()
        for i in 0..<8 {
            let angle = .pi * 2 * Double(i) / 8 - .pi / 2
            let radius = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Render to PNG

@available(macOS 13.0, *)
@MainActor
func render(to outURL: URL) throws {
    let renderer = ImageRenderer(content: AppIcon())
    renderer.scale = 1.0

    guard let rendered = renderer.cgImage else {
        fputs("error: ImageRenderer produced no image\n", stderr)
        exit(1)
    }

    // Re-draw onto an opaque RGB context so the PNG has no alpha channel
    // (App Store rejects icons with alpha).
    let width = 1024, height = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
        fputs("error: could not create CGContext\n", stderr)
        exit(1)
    }
    ctx.interpolationQuality = .high
    ctx.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let flat = ctx.makeImage() else {
        fputs("error: could not flatten image\n", stderr)
        exit(1)
    }

    let rep = NSBitmapImageRep(cgImage: flat)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("error: could not encode PNG\n", stderr)
        exit(1)
    }

    try png.write(to: outURL)
    print("wrote \(outURL.path) (\(png.count) bytes)")
}

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: generate_app_icon.swift <output.png>\n", stderr)
    exit(1)
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])

guard #available(macOS 13.0, *) else {
    fputs("error: requires macOS 13+\n", stderr)
    exit(1)
}

// Top-level script runs on the main thread; assume main-actor isolation
// so we can call SwiftUI's @MainActor ImageRenderer synchronously.
try MainActor.assumeIsolated {
    try render(to: outURL)
}
