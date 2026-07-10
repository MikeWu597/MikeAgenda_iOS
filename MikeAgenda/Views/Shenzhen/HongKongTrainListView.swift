import SwiftUI
import Combine
import CoreLocation

struct HongKongTrainListView: View {
    @StateObject private var service = TrainTicketService.shared
    @ObservedObject private var locationService = LocationService.shared
    @State private var selectedTrain: TrainTicket?
    @State private var showList = false
    @State private var now = Date()
    @State private var arrivedCPs: Set<Int> = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let cpCoords: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 22.612176, longitude: 114.028875),
        CLLocationCoordinate2D(latitude: 22.610385, longitude: 114.030083),
    ]

    var body: some View {
        Group {
            if service.isLoading {
                Spacer()
                ProgressView("查询中...")
                Spacer()
            } else if let error = service.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await service.fetchTickets() }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            } else if service.tickets.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tram")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无车次")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                content
            }
        }
        .navigationTitle("深圳北 → 香港西九龙")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            now = Date()
            checkArrival()
        }
        .task {
            await service.fetchTickets()
            if selectedTrain == nil, let first = service.tickets.first {
                selectedTrain = first
            }
        }
        .onAppear {
            if selectedTrain == nil, let first = service.tickets.first {
                selectedTrain = first
            }
            locationService.startTracking()
        }
        .onDisappear {
            locationService.stopTracking()
        }
        .sheet(isPresented: $showList) {
            NavigationStack {
                trainListSheet
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let train = selectedTrain {
                trainSelector(train: train)
                Spacer()
                countdownView(train: train)
                Spacer()
                infoRow(train: train)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Train Selector

    private func trainSelector(train: TrainTicket) -> some View {
        Button {
            showList = true
        } label: {
            HStack(spacing: 6) {
                Text(train.trainNo)
                    .font(.headline)
                Text(train.fromTime)
                    .font(.subheadline.weight(.medium))
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(train.toTime)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }

    // MARK: - Countdown

    private struct CP {
        let label: String
        let deadline: Date
        let index: Int
    }

    private func countdownView(train: TrainTicket) -> some View {
        guard let departure = departureDate(train) else {
            return AnyView(Text("--:--:--")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary))
        }

        let checkpoints = [
            CP(label: "控制点1", deadline: departure.addingTimeInterval(-11 * 60), index: 0),
            CP(label: "控制点2", deadline: departure.addingTimeInterval(-6.5 * 60), index: 1),
            CP(label: "停止检票", deadline: departure.addingTimeInterval(-4 * 60), index: 2),
        ]

        let active = checkpoints.filter { cp in
            cp.deadline.timeIntervalSince(now) > 0 && !arrivedCPs.contains(cp.index)
        }

        if active.isEmpty {
            return AnyView(
                Text("停止检票")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.red)
            )
        }

        return AnyView(
            VStack(spacing: 12) {
                ForEach(Array(active.enumerated()), id: \.offset) { idx, cp in
                    let remaining = cp.deadline.timeIntervalSince(now)
                    let isFirst = idx == 0
                    let isGate = cp.index == 2

                    VStack(spacing: 2) {
                        Text(countdownText(max(remaining, 0)))
                            .font(.system(size: isFirst ? 64 : 36, weight: .bold, design: .monospaced))
                            .foregroundColor(clockColor(cp: cp, remaining: remaining))
                            .contentTransition(.numericText())
                            .animation(.default, value: countdownText(max(remaining, 0)))

                        Text(cp.label)
                            .font(isFirst ? .body : .subheadline)
                            .foregroundColor(isFirst ? .secondary : .secondary.opacity(0.7))

                        if !isGate, let speed = speedTo(cp.index, remaining: remaining) {
                            Text(speedText(speed))
                                .font(.system(size: isFirst ? 14 : 12, weight: .medium))
                                .foregroundColor(speedColor(speed))
                        }
                    }
                }
            }
        )
    }

    private func clockColor(cp: CP, remaining: TimeInterval) -> Color {
        if cp.index == 2 { return .secondary }
        guard let speed = speedTo(cp.index, remaining: remaining) else { return .orange }
        return speedColor(speed)
    }

    private func speedColor(_ speed: Double) -> Color {
        if speed < 1.5 { return .green }
        if speed < 2.5 { return .orange }
        return .red
    }

    private func speedText(_ speed: Double) -> String {
        String(format: "%.1f m/s", speed)
    }

    private func distanceTo(_ cpIndex: Int) -> CLLocationDistance {
        guard cpIndex < cpCoords.count,
              let loc = locationService.currentLocation else { return -1 }
        let target = CLLocation(latitude: cpCoords[cpIndex].latitude, longitude: cpCoords[cpIndex].longitude)
        return loc.distance(from: target)
    }

    private func speedTo(_ cpIndex: Int, remaining: TimeInterval) -> Double? {
        guard remaining > 0 else { return nil }
        let dist = distanceTo(cpIndex)
        guard dist > 0 else { return nil }
        return dist / remaining
    }

    private func checkArrival() {
        for i in 0..<2 where !arrivedCPs.contains(i) {
            let dist = distanceTo(i)
            if dist > 0 && dist < 15 {
                arrivedCPs.insert(i)
            }
        }
    }

    private func departureDate(_ train: TrainTicket) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = df.string(from: now)
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.date(from: "\(today) \(train.fromTime)")
    }

    private func countdownText(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Info Row

    private func infoRow(train: TrainTicket) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 40) {
                VStack(spacing: 2) {
                    Text(train.fromTime)
                        .font(.title3.weight(.semibold))
                    Text(train.fromStation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 2) {
                    Text(train.runTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 2) {
                    Text(train.toTime)
                        .font(.title3.weight(.semibold))
                    Text(train.toStation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Sheet List

    private var trainListSheet: some View {
        List {
            ForEach(service.tickets) { ticket in
                Button {
                    selectedTrain = ticket
                    showList = false
                } label: {
                    TicketRowView(ticket: ticket, isSelected: ticket.id == selectedTrain?.id)
                }
            }
        }
        .navigationTitle("选择车次")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { showList = false }
            }
        }
    }
}

private struct TicketRowView: View {
    let ticket: TrainTicket
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.trainNo)
                    .font(.headline)
                    .foregroundColor(isSelected ? .orange : .primary)
                HStack(spacing: 4) {
                    Text(ticket.fromTime)
                        .font(.subheadline.weight(.medium))
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ticket.toTime)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Text(ticket.runTime)
                .font(.caption)
                .foregroundColor(.secondary)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.orange)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        HongKongTrainListView()
    }
}
