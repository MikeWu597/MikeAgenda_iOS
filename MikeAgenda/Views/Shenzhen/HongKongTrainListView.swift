import SwiftUI
import Combine

struct HongKongTrainListView: View {
    @StateObject private var service = TrainTicketService.shared
    @State private var selectedTrain: TrainTicket?
    @State private var showList = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { _ in now = Date() }
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

    private func countdownView(train: TrainTicket) -> some View {
        let remaining = departureDate(train)?.timeIntervalSince(now)

        return VStack(spacing: 4) {
            if let remaining, remaining > 0 {
                Text(countdownText(remaining))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .contentTransition(.numericText())
                    .animation(.default, value: countdownText(remaining))

                Text("后开车")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("--:--:--")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
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
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
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
