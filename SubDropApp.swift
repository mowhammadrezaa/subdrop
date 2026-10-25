import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct SubDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = SubDropModel.shared

    var body: some Scene {
        WindowGroup {
            DropView()
                .environmentObject(model)
        }
        .defaultSize(width: 560, height: 620)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open files: [URL]) {
        SubDropModel.shared.enqueue(files: files)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct SubtitleLanguage: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    var id: String { code }

    var displayTitle: String { "\(name) (\(code))" }
}

enum LanguageCatalog {
    static func load() -> [SubtitleLanguage] {
        if let url = Bundle.main.url(forResource: "languages", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SubtitleLanguage].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return [
            SubtitleLanguage(code: "fa", name: "Persian"),
            SubtitleLanguage(code: "en", name: "English"),
            SubtitleLanguage(code: "fr", name: "French"),
        ]
    }
}

@MainActor
final class SubDropModel: ObservableObject {
    static let shared = SubDropModel()

    let languages: [SubtitleLanguage] = LanguageCatalog.load()

    @Published var selectedLanguage: SubtitleLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.code, forKey: "subdrop.language")
            Self.syncConfigFile(code: selectedLanguage.code)
            updateDetailHint()
        }
    }

    @Published var status = "Drop video files or folders here"
    @Published var detail = ""
    @Published var busy = false
    @Published var languageSearch = ""

    private var queue: [URL] = []
    private var workerRunning = false

    init() {
        let saved = UserDefaults.standard.string(forKey: "subdrop.language")
        if let saved,
           let match = languages.first(where: { $0.code == saved }) {
            selectedLanguage = match
        } else if let fa = languages.first(where: { $0.code == "fa" }) {
            selectedLanguage = fa
        } else {
            selectedLanguage = languages[0]
        }
        updateDetailHint()
        Self.syncConfigFile(code: selectedLanguage.code)
    }

    var filteredLanguages: [SubtitleLanguage] {
        let q = languageSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return languages }
        let lower = q.lowercased()
        return languages.filter {
            $0.name.lowercased().contains(lower) || $0.code.lowercased().contains(lower)
        }
    }

    private func updateDetailHint() {
        detail = "\(selectedLanguage.name) · same name · UTF-8"
    }

    private static func syncConfigFile(code: String) {
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/subdrop")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = "# Updated by SubDrop\nSUBDROP_LANG=\(code)\n"
        try? text.write(to: dir.appendingPathComponent("config"), atomically: true, encoding: .utf8)
    }

    func enqueue(files: [URL]) {
        queue.append(contentsOf: files)
        pumpQueue()
    }

    private func pumpQueue() {
        guard !workerRunning, !queue.isEmpty else { return }
        workerRunning = true
        let next = queue.removeFirst()
        busy = true
        status = "Working on \(next.lastPathComponent)…"
        detail = selectedLanguage.displayTitle

        let langCode = selectedLanguage.code
        Task {
            let result = await Self.runFetch(for: next, languageCode: langCode)
            await MainActor.run {
                switch result {
                case .success(let message):
                    status = "Done"
                    detail = message
                case .failure(let message):
                    status = "Failed"
                    detail = message
                }
                busy = false
                workerRunning = false
                updateDetailHint()
                if !queue.isEmpty {
                    pumpQueue()
                }
            }
        }
    }

    private static func fetchScriptURL() -> URL? {
        if let url = Bundle.main.url(forResource: "fetch", withExtension: "sh") {
            return url
        }
        let fallback = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications/SubDrop.app/Contents/Resources/fetch.sh")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    private enum FetchOutcome {
        case success(String)
        case failure(String)
    }

    private nonisolated static func friendlyFailure(from log: String) -> String {
        if log.contains("subliminal not found") || log.contains("return 127") {
            return "subliminal is not installed. In Terminal: pip3 install subliminal --break-system-packages"
        }
        if log.contains("found no subtitles") || log.contains("No subtitle found") {
            return "No subtitle found for this file. Try another language or check /tmp/subdrop-last.log"
        }
        let tail = log.split(separator: "\n").suffix(4).joined(separator: "\n")
        if !tail.isEmpty { return tail }
        return "Download failed. See /tmp/subdrop-last.log"
    }

    private static func runFetch(for url: URL, languageCode: String) async -> FetchOutcome {
        guard let script = fetchScriptURL() else {
            return .failure("fetch.sh not found inside SubDrop.app")
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [script.path, url.path]

                var env = ProcessInfo.processInfo.environment
                env["SUBDROP_LANG"] = languageCode
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                if env["HOME"] == nil {
                    env["HOME"] = NSHomeDirectory()
                }
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let log = String(data: data, encoding: .utf8) ?? ""
                    if process.terminationStatus == 0 {
                        let msg = log.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: .success(msg.isEmpty ? url.lastPathComponent : msg))
                    } else {
                        let friendly = Self.friendlyFailure(from: log)
                        continuation.resume(returning: .failure(friendly))
                    }
                } catch {
                    continuation.resume(returning: .failure(error.localizedDescription))
                }
            }
        }
    }
}

struct DropView: View {
    @EnvironmentObject private var model: SubDropModel
    @Namespace private var bannerMorph
    @State private var targeted = false
    @State private var languageSwapFlash = false
    @State private var languagePickerExpanded = false

    private var bannerSpring: Animation {
        .spring(response: 0.48, dampingFraction: 0.78, blendDuration: 0.12)
    }

    private let dropZoneHeight: CGFloat = 200
    private let windowHeight: CGFloat = 640
    private let creatorEmail = "m.hosseini.eng@outlook.com"
    private let windowWidth: CGFloat = 560
    private let outerPadding: CGFloat = 20

    /// Space above the fixed drop zone (banner + optional language list).
    private var upperSectionHeight: CGFloat {
        windowHeight - (outerPadding * 2) - dropZoneHeight - 52
    }

    private var compactBannerHeight: CGFloat { 48 }

    private var languageListHeight: CGFloat {
        let searchChrome: CGFloat = 56
        let panelPadding: CGFloat = 20
        let gaps: CGFloat = 16
        let stackSpacing: CGFloat = 8
        return max(
            160,
            upperSectionHeight
                - compactBannerHeight
                - searchChrome
                - panelPadding
                - gaps
                - stackSpacing
        )
    }

    private var languageSelection: Binding<SubtitleLanguage> {
        Binding(
            get: { model.selectedLanguage },
            set: { newValue in
                guard newValue != model.selectedLanguage else { return }
                languageSwapFlash = true
                withAnimation(bannerSpring) {
                    model.selectedLanguage = newValue
                    languagePickerExpanded = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        languageSwapFlash = false
                    }
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                morphingLanguageBanner
                if languagePickerExpanded {
                    languagePickerPanel
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(height: upperSectionHeight, alignment: .top)

            dropZone
                .frame(height: dropZoneHeight)

            statusSection

            creatorFooter
        }
        .padding(outerPadding)
        .frame(width: windowWidth, height: windowHeight)
        .animation(bannerSpring, value: languagePickerExpanded)
    }

    private var morphingLanguageBanner: some View {
        let expanded = languagePickerExpanded
        let corner: CGFloat = expanded ? 12 : 16
        let bannerHeight: CGFloat = expanded ? compactBannerHeight : upperSectionHeight

        return ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(languageGradient)
                .matchedGeometryEffect(id: "banner-bg", in: bannerMorph)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(Color.white.opacity(languageSwapFlash ? 0.35 : 0))

            HStack(alignment: .center, spacing: expanded ? 10 : 16) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: expanded ? 18 : 40))
                    .foregroundStyle(.white.opacity(0.95))
                    .symbolEffect(.bounce, value: model.selectedLanguage.code)
                    .matchedGeometryEffect(id: "banner-icon", in: bannerMorph)

                if expanded {
                    HStack(spacing: 8) {
                        languageTitleText(compact: true)
                        languageCodeBadge(compact: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subtitles will download in")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .matchedGeometryEffect(id: "banner-caption", in: bannerMorph)

                        languageTitleText(compact: false)
                        languageCodeBadge(compact: false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

                changeLanguageButton
                    .matchedGeometryEffect(id: "banner-action", in: bannerMorph)
            }
            .padding(.horizontal, expanded ? 14 : 22)
            .padding(.vertical, expanded ? 10 : 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .scaleEffect(languageSwapFlash ? 1.015 : 1.0)
        .animation(bannerSpring, value: languageSwapFlash)
        .animation(bannerSpring, value: model.selectedLanguage.code)
    }

    private func languageTitleText(compact: Bool) -> some View {
        Text(model.selectedLanguage.name)
            .font(.system(size: compact ? 17 : 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(compact ? 1 : 2)
            .minimumScaleFactor(0.85)
            .matchedGeometryEffect(id: "banner-title", in: bannerMorph)
    }

    private func languageCodeBadge(compact: Bool) -> some View {
        Text(model.selectedLanguage.code.uppercased())
            .font(compact ? .caption2.weight(.bold).monospaced() : .caption.weight(.bold).monospaced())
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 2 : 4)
            .background(.white.opacity(0.22), in: Capsule())
            .foregroundStyle(.white)
            .matchedGeometryEffect(id: "banner-code", in: bannerMorph)
    }

    private var changeLanguageButton: some View {
        Button {
            withAnimation(bannerSpring) {
                languagePickerExpanded.toggle()
            }
        } label: {
            Label(
                languagePickerExpanded ? "Done" : "Change language",
                systemImage: languagePickerExpanded ? "checkmark.circle.fill" : "chevron.down.circle"
            )
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .disabled(model.busy)
    }

    private var languagePickerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Search by language name or code")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("e.g. Persian, fa, English, en", text: $model.languageSearch)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.filteredLanguages) { language in
                        Button {
                            languageSelection.wrappedValue = language
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(language.name)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 12)
                                Text(language.code.uppercased())
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                model.selectedLanguage == language
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: languageListHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.2))
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var languageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.92),
                Color.accentColor.opacity(0.55),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(targeted ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    targeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: targeted ? [] : [8, 6])
                )

            VStack(spacing: 10) {
                Image(systemName: model.busy ? "arrow.down.circle.fill" : "square.and.arrow.down.on.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(model.busy ? Color.accentColor : Color.secondary)
                    .symbolEffect(.pulse, isActive: model.busy)

                if model.busy {
                    Text(model.status)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Drag and drop video files here")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Drop as many files as you want. Each video gets a matching .srt file beside it (UTF-8).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460)
                }
            }
            .padding(24)
        }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            loadDropped(providers)
            return true
        }
    }

    private var statusSection: some View {
        Group {
            if !model.detail.isEmpty {
                Text(model.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var creatorFooter: some View {
        Link(
            "Report issues: \(creatorEmail)",
            destination: URL(string: "mailto:\(creatorEmail)")!
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func loadDropped(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    SubDropModel.shared.enqueue(files: [url])
                }
            }
        }
    }
}
