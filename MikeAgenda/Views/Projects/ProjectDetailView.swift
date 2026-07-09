import SwiftUI

struct ProjectDetailView: View {
    let project: Project

    @State private var records: [ProjectRecord] = []
    @State private var isLoading = true
    @State private var isParticipating = false

    var body: some View {
        List {
            Section {
                HStack {
                    ColorIndicator(color: Color(hex: project.color))
                    Text(project.name)
                        .font(.title3.bold())
                }

                Button {
                    participate()
                } label: {
                    Label(isParticipating ? "今日已打卡" : "今日打卡", systemImage: isParticipating ? "checkmark.circle.fill" : "hand.tap")
                }
                .disabled(isParticipating)
            }

            Section("活动日历") {
                CalendarHeatmap(records: records, color: Color(hex: project.color))
                    .frame(minHeight: 300)
            }
        }
        .navigationTitle("项目详情")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        records = (try? await APIClient.shared.getProjectRecords(projectID: project.id)) ?? []

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        isParticipating = records.contains { $0.timestamp.prefix(10) == today }
        isLoading = false
    }

    private func participate() {
        Task {
            try? await APIClient.shared.participateInProject(projectID: project.id)
            await load()
        }
    }
}

struct CalendarHeatmap: View {
    let records: [ProjectRecord]
    let color: Color

    private let calendar = Calendar.current

    var body: some View {
        let dates = last12Months()
        VStack(spacing: 12) {
            ForEach(dates, id: \.self) { monthStart in
                MonthGrid(month: monthStart, records: records, accent: color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func last12Months() -> [Date] {
        let now = Date()
        return (0..<3).compactMap { calendar.date(byAdding: .month, value: -$0, to: now) }
            .map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0))! }
    }
}

struct MonthGrid: View {
    let month: Date
    let records: [ProjectRecord]
    let accent: Color

    private let calendar = Calendar.current

    var body: some View {
        let days = daysInMonth()
        let recordDates = Set(records.compactMap { dateFromRecord($0) })

        VStack(spacing: 2) {
            Text(monthLabel)
                .font(.caption2.bold())
                .padding(4)
                .frame(maxWidth: .infinity)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 1), count: 7), spacing: 1) {
                let labels = ["日", "一", "二", "三", "四", "五", "六"]
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                }

                let firstWeekday = calendar.component(.weekday, from: days.first ?? month) - 1
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(width: 16, height: 16)
                }

                ForEach(days, id: \.self) { day in
                    let dayStr = formattedDate(day)
                    let hasRecord = recordDates.contains(dayStr)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasRecord ? accent : Color.secondary.opacity(0.15))
                        .frame(width: 16, height: 16)
                }
            }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: month)
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(bySetting: .day, value: $0, of: month) }
    }

    private func dateFromRecord(_ record: ProjectRecord) -> String {
        String(record.timestamp.prefix(10))
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
