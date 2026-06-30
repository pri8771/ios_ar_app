//
//  TimeScrubberView.swift
//  Umbra
//
//  Date picker + time-of-day slider. Scrubbing the slider re-runs the solar
//  math live. Sunrise/sunset markers give context. Accessible + Dynamic Type.
//

import SwiftUI

struct TimeScrubberView: View {
    @ObservedObject var viewModel: ARLensViewModel

    @State private var hours: Double = 12

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeZone = viewModel.timeZone
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { viewModel.previewDate },
                        set: { viewModel.setPreviewDate($0) }),
                    displayedComponents: .date)
                .labelsHidden()

                Button {
                    viewModel.setToNow()
                    Haptics.select()
                } label: {
                    Text("Now")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            viewModel.isPreviewingNow
                                ? AnyShapeStyle(UmbraTheme.sunGradient)
                                : AnyShapeStyle(Color.secondary.opacity(0.25)),
                            in: Capsule())
                        .foregroundStyle(viewModel.isPreviewingNow ? UmbraTheme.indigoDeep : .primary)
                }
                .accessibilityLabel("Jump to now")
                .accessibilityHint("Sets the time to the current moment so you can compare the projected shadow to the real one")

                Spacer()

                Text(timeFormatter.string(from: viewModel.previewDate))
                    .font(.headline.monospacedDigit())
                    .accessibilityLabel("Preview time")
            }

            Slider(
                value: Binding(
                    get: { viewModel.previewHours },
                    set: { viewModel.setTimeOfDay(hours: $0) }),
                in: 0...24,
                step: 1.0 / 12.0  // 5-minute increments
            ) {
                Text("Time of day")
            } minimumValueLabel: {
                Image(systemName: "sunrise").font(.caption2)
            } maximumValueLabel: {
                Image(systemName: "sunset").font(.caption2)
            }
            .accessibilityValue(timeFormatter.string(from: viewModel.previewDate))

            sunEventsRow
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var sunEventsRow: some View {
        if let day = viewModel.solarDay {
            HStack(spacing: 16) {
                if day.isPolarDay {
                    Label("Midnight sun", systemImage: "sun.max")
                } else if day.isPolarNight {
                    Label("Polar night", systemImage: "moon.stars")
                } else {
                    if let sunrise = day.sunrise {
                        Label(timeFormatter.string(from: sunrise), systemImage: "sunrise")
                    }
                    if let sunset = day.sunset {
                        Label(timeFormatter.string(from: sunset), systemImage: "sunset")
                    }
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
