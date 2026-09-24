import SwiftUI
import Charts

enum ChartRange: String, CaseIterable, Identifiable {
    case fourHours = "4 Hours"
    case day       = "24 Hours"
    case week      = "7 Days"

    var id: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .fourHours: return 4 * 3600
        case .day:       return 24 * 3600
        case .week:      return 7 * 24 * 3600
        }
    }

    /// Tick + gridline spacing.
    var tickStride: (Calendar.Component, Int) {
        switch self {
        case .fourHours: return (.minute, 15)
        case .day:       return (.hour, 1)
        case .week:      return (.hour, 6)
        }
    }

    /// Label spacing — coarser than the ticks, or they collide on a phone.
    var labelStride: (Calendar.Component, Int) {
        switch self {
        case .fourHours: return (.hour, 1)
        case .day:       return (.hour, 6)
        case .week:      return (.day, 1)
        }
    }

    var format: Date.FormatStyle {
        switch self {
        case .fourHours, .day: return .dateTime.hour()
        case .week:            return .dateTime.weekday(.abbreviated)
        }
    }
}

struct HistoryChart: View {
    let samples: [Sample]
    let range: ChartRange
    let ceiling: Int
    let floor: Int

    var body: some View {
        let data = samples
        if data.count < 2 {
            ContentUnavailableView("Not enough data yet",
                                   systemImage: "chart.xyaxis.line",
                                   description: Text("Readings appear here about a minute apart while monitoring is on."))
        } else {
            Chart {
                ForEach(data, id: \.t) { s in
                    AreaMark(x: .value("Time", s.t), y: .value("Battery", s.p))
                        .foregroundStyle(.linearGradient(
                            colors: [.green.opacity(0.35), .green.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", s.t), y: .value("Battery", s.p))
                        .foregroundStyle(.green)
                        .lineStyle(.init(lineWidth: 2))
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("Charged", ceiling))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                RuleMark(y: .value("Low", floor))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) {
                    AxisGridLine()
                    AxisValueLabel(format: Decimal.FormatStyle.Percent.percent.scale(1))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: range.tickStride.0, count: range.tickStride.1)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.25))
                    AxisTick(length: 3)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                AxisMarks(values: .stride(by: range.labelStride.0, count: range.labelStride.1)) {
                    AxisGridLine()
                    AxisValueLabel(format: range.format)
                }
            }
        }
    }
}
