import SwiftUI
import Combine

struct ShenzhenTrainListView: View {
    @StateObject private var service = TrainTicketService(from: "XJA", to: "IOQ")
    @State private var selectedTrain: TrainTicket?
    @State private var showList = false
    @State private var now = Date()
    @State private var gateInfo: String?
    @State private var fetchingGate = false
    @State private var mtrStatus: MTRTrainStatus?
    @State private var fetchingMTR = false
    @State private var mtrTick = 0
    @State private var completedCPs: Set<String> = []
    @State private var portFlow: PortFlowData?
    @State private var fetchingPortFlow = false
    @State private var portFlowError: String?

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
        .navigationTitle("香港西九龙 → 深圳北")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            now = Date()
            mtrTick += 1
            if isMTRPrimary && mtrTick % 5 == 0 {
                Task {
                    mtrStatus = try? await APIClient.shared.fetchMTRToAustin()
                }
            }
            if showGate && gateInfo == nil && !fetchingGate, let train = selectedTrain {
                fetchingGate = true
                Task {
                    gateInfo = await service.fetchGateInfo(trainCode: train.trainNo)
                    fetchingGate = false
                }
            }
            if showGate && portFlow == nil && !fetchingPortFlow {
                fetchingPortFlow = true
                portFlowError = nil
                Task.detached { [service = PortAPIService.shared] in
                    do {
                        let flow = try await service.queryClearanceFlowToXJL()
                        await MainActor.run { portFlow = flow; fetchingPortFlow = false }
                    } catch {
                        await MainActor.run { portFlowError = error.localizedDescription; fetchingPortFlow = false }
                    }
                }
            }
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
            gateInfo = nil
            fetchingGate = false
            completedCPs = []
            portFlow = nil
            fetchingPortFlow = false
            portFlowError = nil
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
                if isMTRPrimary {
                    mtrInfoView
                }
                if showGate {
                    gateInfoView
                    if let flow = portFlow {
                        portFlowView(flow)
                    } else if fetchingPortFlow {
                        ProgressView("获取口岸信息...")
                            .font(.caption)
                    } else if let err = portFlowError {
                        Text("口岸: \(err)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                infoRow(train: train)
            }
        }
        .padding(.bottom, 20)
    }

    private var mtrCountdownMinutes: Int {
        guard let train = selectedTrain,
              let departure = departureDate(train) else { return 999 }
        let remaining = departure.addingTimeInterval(-29 * 60).timeIntervalSince(now)
        return max(0, Int(remaining / 60))
    }
    private var showGate: Bool {
        guard selectedTrain != nil else { return false }
        return completedCPs.contains("进站截止") || (departureDate(selectedTrain!) ?? Date()).addingTimeInterval(-15 * 60).timeIntervalSince(now) <= 0
    }

    private var isMTRPrimary: Bool {
        guard let train = selectedTrain else { return false }
        let departure = departureDate(train) ?? Date()
        let cpLabels: [(label: String, offset: TimeInterval)] = [
            ("售票截止", -45 * 60),
            ("MTR", -29 * 60),
            ("进站截止", -15 * 60),
            ("停止检票", -4 * 60),
        ]
        for (label, offset) in cpLabels {
            if !completedCPs.contains(label) && departure.addingTimeInterval(offset).timeIntervalSince(now) > 0 {
                return label == "MTR"
            }
        }
        return false
    }

    private var gateInfoView: some View {
        VStack(spacing: 4) {
            if let gate = gateInfo {
                Text(gate)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
            Text("检票口")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var mtrInfoView: some View {
        VStack(spacing: 4) {
            if let mtr = mtrStatus {
                let urgent = mtrCountdownMinutes < (Int(mtr.minutes) ?? 999)
                HStack(alignment: .bottom, spacing: 8) {
                    Text(mtr.minutes)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(urgent ? .red : .primary)
                    Text("分钟")
                        .font(.headline)
                }
                Text("红磡 → 柯士甸")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 8)
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
    }

    private func countdownView(train: TrainTicket) -> some View {
        guard let departure = departureDate(train) else {
            return AnyView(Text("--:--:--")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary))
        }

        let checkpoints = [
            CP(label: "售票截止", deadline: departure.addingTimeInterval(-45 * 60)),
            CP(label: "MTR", deadline: departure.addingTimeInterval(-29 * 60)),
            CP(label: "进站截止", deadline: departure.addingTimeInterval(-15 * 60)),
            CP(label: "停止检票", deadline: departure.addingTimeInterval(-4 * 60)),
        ]

        let active = checkpoints.filter { $0.deadline.timeIntervalSince(now) > 0 && !completedCPs.contains($0.label) }

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
                    let isGate = cp.label == "停止检票"

                    VStack(spacing: 2) {
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(countdownText(max(remaining, 0)))
                                .font(.system(size: isFirst ? 64 : 36, weight: .bold, design: .monospaced))
                                .foregroundColor(isFirst ? .blue : .secondary)
                                .contentTransition(.numericText())
                                .animation(.default, value: countdownText(max(remaining, 0)))

                            if isFirst && !isGate {
                                Button {
                                    completedCPs.insert(cp.label)
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Text(cp.label)
                            .font(isFirst ? .body : .subheadline)
                            .foregroundColor(isFirst ? .secondary : .secondary.opacity(0.7))
                    }
                }
            }
        )
    }

    private func portFlowView(_ flow: PortFlowData) -> some View {
        VStack(spacing: 4) {
            Text("≈\(flow.arrivalMinutes)分钟")
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundColor(flow.arrivalTransitSmooth == "畅通" ? .green : .orange)
            Text("实时通关")
                .font(.body)
                .foregroundColor(.secondary)
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
                    gateInfo = nil
                    fetchingGate = false
                    completedCPs = []
                    portFlow = nil
                    fetchingPortFlow = false
                    portFlowError = nil
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
        ShenzhenTrainListView()
    }
}
