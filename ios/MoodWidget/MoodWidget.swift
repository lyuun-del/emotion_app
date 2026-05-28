import SwiftUI
import WidgetKit

struct MoodWidgetEntry: TimelineEntry {
    let date: Date
}

struct MoodWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodWidgetEntry {
        MoodWidgetEntry(date: Date())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (MoodWidgetEntry) -> Void
    ) {
        completion(MoodWidgetEntry(date: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<MoodWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [MoodWidgetEntry(date: Date())], policy: .never))
    }
}

struct MoodWidgetView: View {
    let entry: MoodWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            Image("CloudCompanion")
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: family == .systemMedium ? 236 : 142,
                    maxHeight: family == .systemMedium ? 136 : 142
                )
                .shadow(color: Color.blue.opacity(0.12), radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(4)
        .modifier(WidgetBackground())
    }
}

struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                Color(red: 0.98, green: 1.00, blue: 1.00)
            }
        } else {
            content.background(Color(red: 0.98, green: 1.00, blue: 1.00))
        }
    }
}

@main
struct MoodWidget: Widget {
    let kind = "MoodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodWidgetProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("moodland 云朵")
        .description("把云朵放在桌面上。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
