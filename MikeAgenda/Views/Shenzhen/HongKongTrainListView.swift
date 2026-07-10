import SwiftUI

struct HongKongTrainListView: View {
    @StateObject private var service = TrainTicketService.shared

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
                ticketList
            }
        }
        .navigationTitle("深圳北 → 香港西九龙")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await service.fetchTickets()
        }
    }

    private var ticketList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(service.tickets) { ticket in
                    TicketRowView(ticket: ticket)
                    Divider().padding(.leading, 16)
                }
            }
        }
    }
}

private struct TicketRowView: View {
    let ticket: TrainTicket

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(ticket.trainNo)
                    .font(.headline)
                Spacer()
                Text(ticket.runTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(spacing: 2) {
                    Text(ticket.fromTime)
                        .font(.title2.weight(.bold))
                    Text(ticket.fromStation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(spacing: 2) {
                    Text(ticket.toTime)
                        .font(.title2.weight(.bold))
                    Text(ticket.toStation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .opacity(ticket.trainNo.isEmpty ? 0 : 1)
    }
}

#Preview {
    NavigationStack {
        HongKongTrainListView()
    }
}
