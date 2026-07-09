import SwiftUI

struct CourseFormView: View {
    let course: Course?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var courseCode = ""
    @State private var courseName = ""
    @State private var venue = ""
    @State private var courseColor = "#409eff"
    @State private var day = 1
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var isActive = true
    @State private var isLoading = false

    private let days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    init(course: Course? = nil, onSaved: @escaping () -> Void) {
        self.course = course
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("课程代码", text: $courseCode)
                TextField("课程名称", text: $courseName)
                TextField("地点（可选）", text: $venue)
                ColorPicker("颜色标签", selection: Binding(
                    get: { Color(hex: courseColor) },
                    set: { courseColor = $0.toHex() }
                ))
            }
            Section("时间") {
                Picker("星期", selection: $day) {
                    ForEach(0..<7, id: \.self) { i in Text(days[i]).tag(i) }
                }
                DatePicker("开始时间", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("结束时间", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            Section {
                Toggle("启用", isOn: $isActive)
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading { ProgressView() }
                        Text(course == nil ? "添加课程" : "保存修改")
                        Spacer()
                    }
                }
                .disabled(courseCode.isEmpty || courseName.isEmpty || isLoading)
            }
        }
        .navigationTitle(course == nil ? "添加课程" : "编辑课程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        }
        .onAppear {
            if let course {
                courseCode = course.courseCode
                courseName = course.courseName
                venue = course.venue ?? ""
                courseColor = course.courseColor ?? "#409eff"
                day = course.day
                isActive = course.isActive
                if let st = parseTime(course.startTime) { startTime = st }
                if let et = parseTime(course.endTime) { endTime = et }
            } else {
                courseCode = ""; courseName = ""; venue = ""; courseColor = "#409eff"
                day = 1; isActive = true; startTime = Date(); endTime = Date().addingTimeInterval(3600)
            }
        }
    }

    private func save() {
        isLoading = true
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"

        let course = Course(
            id: course?.id,
            courseCode: courseCode,
            courseName: courseName,
            courseColor: courseColor,
            venue: venue.isEmpty ? nil : venue,
            day: day,
            startTime: tf.string(from: startTime),
            endTime: tf.string(from: endTime),
            isActive: isActive
        )

        Task {
            try? await APIClient.shared.addOrUpdateCourse(course)
            await MainActor.run {
                onSaved()
                dismiss()
            }
        }
    }

    private func parseTime(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.date(from: s)
    }
}

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
