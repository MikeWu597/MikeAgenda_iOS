import SwiftUI

struct MTRDoorListView: View {
    var body: some View {
        List {
            NavigationLink {
                EastRailSouthView()
            } label: {
                routeRow(
                    label: "东",
                    color: Color(red: 0.33, green: 0.72, blue: 0.91),
                    title: "东铁线南下",
                    subtitle: "落马洲 → 上水 → 红磡"
                )
            }

            NavigationLink {
                EastRailNorthView()
            } label: {
                routeRow(
                    label: "东",
                    color: Color(red: 0.33, green: 0.72, blue: 0.91),
                    title: "东铁线北上",
                    subtitle: "红磡 → 上水 → 落马洲"
                )
            }

            NavigationLink {
                TuenMaLineView()
            } label: {
                routeRow(
                    label: "屯",
                    color: Color(red: 0.57, green: 0.19, blue: 0.07),
                    title: "屯马线上学",
                    subtitle: "柯士甸 → 红磡"
                )
            }

            NavigationLink {
                TuenMaFromSchoolView()
            } label: {
                routeRow(
                    label: "屯",
                    color: Color(red: 0.57, green: 0.19, blue: 0.07),
                    title: "屯马线放学",
                    subtitle: "红磡 → 柯士甸"
                )
            }
        }
        .navigationTitle("MTR车门管理")
    }

    private func routeRow(label: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { MTRDoorListView() }
}
