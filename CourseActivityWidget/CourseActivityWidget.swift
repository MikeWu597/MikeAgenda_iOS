import WidgetKit
import SwiftUI
import ActivityKit

struct CourseActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseActivityAttributes.self) { context in
            // Lock Screen / banner view
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(context.state.courseCode)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(context.state.venue)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text(context.state.courseName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                        Text("\(context.state.startTime) - \(context.state.endTime)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "book.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            .padding(16)
            .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.courseCode)
                            .font(.system(size: 16, weight: .bold))
                        Text(context.state.venue)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.startTime)-\(context.state.endTime)")
                            .font(.system(size: 13, design: .monospaced))
                        Text(context.state.courseName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.state.courseCode)
                    .font(.system(size: 13, weight: .bold))
            } compactTrailing: {
                Text(context.state.venue)
                    .font(.system(size: 13))
            } minimal: {
                Image(systemName: "book.fill")
                    .font(.system(size: 12))
            }
        }
    }
}
