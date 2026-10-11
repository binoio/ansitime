import SwiftUI
import AnsiCore

public struct SauceInspectorView: View {
    public let sauce: SauceRecord?

    public init(sauce: SauceRecord?) {
        self.sauce = sauce
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SAUCE Metadata")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)

            if let s = sauce {
                Group {
                    metaRow(label: "Title", value: s.title.isEmpty ? "(None)" : s.title)
                    metaRow(label: "Author", value: s.author.isEmpty ? "(None)" : s.author)
                    metaRow(label: "Group", value: s.group.isEmpty ? "(None)" : s.group)
                    metaRow(label: "Date", value: s.formattedDate ?? "(Unknown)")
                    metaRow(label: "Dimensions", value: "\(s.width) x \(s.height)")
                    metaRow(label: "File Size", value: "\(s.fileSize) bytes")
                }

                if !s.comments.isEmpty {
                    Divider()
                    Text("Comments (\(s.comments.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(s.comments.enumerated()), id: \.offset) { _, comment in
                                Text(comment)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            } else {
                Text("No SAUCE record found in this ANSI file.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 75, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}
