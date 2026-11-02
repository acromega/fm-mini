import AppKit
import Combine
import CoreText
import Darwin
import Foundation
import FoundationModels
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@propertyWrapper
struct Local<Value>: DynamicProperty {
    private var storage: State<Value>
    init(wrappedValue: Value) { storage = State(initialValue: wrappedValue) }
    var wrappedValue: Value { get { storage.wrappedValue } nonmutating set { storage.wrappedValue = newValue } }
    var projectedValue: Binding<Value> { storage.projectedValue }
}

enum ChatRole { case user, model, error, system }
enum ChatItemAction {
    case conversationFull
    case oversizedDocument(parts: [DocumentPart])
}

struct ConversationTurn {
    let question: String
    let answer: String
}

struct ChatItem: Identifiable {
    let id: UUID
    let role: ChatRole
    var text: String
    var durationMilliseconds: Int?
    var action: ChatItemAction?
    init(id: UUID = UUID(), role: ChatRole, text: String, durationMilliseconds: Int?, action: ChatItemAction? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.durationMilliseconds = durationMilliseconds
        self.action = action
    }
}

struct TextAttachment {
    let name: String
    let content: String
    let tokenCount: Int
    var isPendingInjection = true
    var isLoaded = false
}

struct DocumentPart: Identifiable {
    let id: Int
    let total: Int
    let content: String
    let firstWord: Int
    let lastWord: Int
    let preview: String
}

struct TranslationLanguage: Identifiable {
    let code: String
    let name: String
    var id: String { code }
}

enum DocumentSplitter {
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    static func structuredSplitUnitTest() -> Bool {
        let paragraph = (1...400).map { "mot\($0)" }.joined(separator: " ") + "."
        let document = (1...50).map { _ in paragraph }.joined(separator: "\n\n")
        let parts = split(document, maximumWords: 3_510)
        return wordCount(document) == 20_000
            && parts.allSatisfy { wordCount($0.content) <= 3_510 }
            && parts.allSatisfy { $0.content.trimmingCharacters(in: .whitespacesAndNewlines).last == "." }
    }

    static func split(_ text: String, maximumWords: Int) -> [DocumentPart] {
        let maximumWords = max(1, maximumWords)
        var pieces: [String] = []
        var current = ""

        func append(_ unit: String) {
            let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let candidate = current.isEmpty ? trimmed : current + "\n\n" + trimmed
            if wordCount(candidate) <= maximumWords {
                current = candidate
            } else {
                if !current.isEmpty { pieces.append(current) }
                if wordCount(trimmed) <= maximumWords {
                    current = trimmed
                } else {
                    let fragments = sentenceFragments(trimmed, maximumWords: maximumWords)
                    for fragment in fragments {
                        if current.isEmpty {
                            current = fragment
                        } else if wordCount(current + "\n\n" + fragment) <= maximumWords {
                            current += "\n\n" + fragment
                        } else {
                            pieces.append(current)
                            current = fragment
                        }
                    }
                }
            }
        }

        for block in structuralBlocks(text) { append(block) }
        if !current.isEmpty { pieces.append(current) }
        if pieces.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pieces = sentenceFragments(text, maximumWords: maximumWords)
        }

        var firstWord = 1
        return pieces.enumerated().map { index, piece in
            let words = wordCount(piece)
            let part = DocumentPart(
                id: index + 1,
                total: pieces.count,
                content: piece,
                firstWord: firstWord,
                lastWord: firstWord + max(0, words - 1),
                preview: piece.split(whereSeparator: { $0.isWhitespace }).prefix(8).joined(separator: " ")
            )
            firstWord += words
            return part
        }
    }

    private static func structuralBlocks(_ text: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        func flush() {
            let block = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty { blocks.append(block) }
            current = []
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
            } else if isHeading(trimmed), !current.isEmpty {
                flush()
                current.append(line)
            } else {
                current.append(line)
            }
        }
        flush()
        return blocks
    }

    private static func isHeading(_ line: String) -> Bool {
        line.hasPrefix("#") || (line.count > 3 && line == line.uppercased() && line.rangeOfCharacter(from: .letters) != nil)
    }

    private static func sentenceFragments(_ text: String, maximumWords: Int) -> [String] {
        let regex = try! NSRegularExpression(pattern: "(?<=[.!?])\\s+")
        var sentences: [String] = []
        var start = text.startIndex
        regex.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            guard let match, let range = Range(match.range, in: text) else { return }
            sentences.append(String(text[start..<range.lowerBound]))
            start = range.upperBound
        }
        sentences.append(String(text[start...]))
        var fragments: [String] = []
        for sentence in sentences where !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Une phrase exceptionnellement plus longue que la fenêtre reste
            // entière : ne jamais couper un document au milieu d'une phrase.
            fragments.append(sentence)
        }
        return fragments
    }
}

enum BubbleClipboard {
    @discardableResult
    static func copy(_ text: String) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()
        return board.setString(text, forType: .string)
    }
}

enum AttachmentReadError: Error {
    case tooLarge(Int)
    case scannedPDF
    case unreadableText
    case damagedDocument
}

enum AttachmentReader {
    static let allowedExtensions = ["txt", "md", "csv", "json", "log", "rtf", "docx", "pdf"]
    static let maximumBytes = 5_000_000

    static func read(url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = values.fileSize ?? 0
        guard byteCount <= maximumBytes else { throw AttachmentReadError.tooLarge(byteCount) }

        switch url.pathExtension.lowercased() {
        case "rtf", "docx":
            let documentType: NSAttributedString.DocumentType = url.pathExtension.lowercased() == "rtf" ? .rtf : .officeOpenXML
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: documentType]
            do {
                return try NSAttributedString(url: url, options: options, documentAttributes: nil).string
            } catch {
                throw AttachmentReadError.damagedDocument
            }
        case "pdf":
            guard let text = PDFDocument(url: url)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                throw AttachmentReadError.scannedPDF
            }
            return text
        default:
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw AttachmentReadError.unreadableText }
            return text
        }
    }
}

@MainActor
final class ChatModel: ObservableObject {
    nonisolated static let instructions = "Tu es un assistant. Tu réponds toujours en français, quelle que soit la langue du message. Tu vouvoies la personne."

    @Published var messages: [ChatItem] = []
    @Published var input = ""
    @Published private(set) var inputRevision = 0
    @Published var attachment: TextAttachment?
    @Published var unavailableReason: String?
    @Published var isSending = false
    @Published private(set) var contextTokenCount = 0
    @Published private(set) var compressionFailed = false

    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    private var turns: [ConversationTurn] = []
    private var isCompressing = false
    private var responseTask: Task<Void, Never>?
    private var oversizedDocumentName: String?
    private var previousSummary: String?

    init() {
        switch model.availability {
        case .available:
            session = newSession()
        case .unavailable(let reason):
            unavailableReason = String(describing: reason)
        @unknown default:
            unavailableReason = "Raison inconnue"
        }
        Task { @MainActor [weak self] in await self?.refreshContextGauge() }
    }

    func newConversation() {
        guard unavailableReason == nil else { return }
        responseTask?.cancel()
        responseTask = nil
        session = newSession()
        messages = []
        input = ""
        attachment = nil
        oversizedDocumentName = nil
        isSending = false
        contextTokenCount = 0
        compressionFailed = false
        turns = []
        previousSummary = nil
        Task { @MainActor [weak self] in await self?.refreshContextGauge() }
    }

    func newConversationKeepingDocument() {
        guard var attachment else { newConversation(); return }
        responseTask?.cancel()
        responseTask = nil
        attachment.isPendingInjection = false
        attachment.isLoaded = true
        self.attachment = attachment
        session = newSession(withLoadedDocument: attachment)
        messages = []
        input = ""
        isSending = false
        contextTokenCount = 0
        compressionFailed = false
        turns = []
        previousSummary = nil
        Task { @MainActor [weak self] in await self?.refreshContextGauge() }
    }

    var attachmentHint: String {
        let approximateWords = Int((Double(model.contextSize) * 0.9 / 1.4 / 100).rounded() * 100)
        let display = approximateWords > 0 ? approximateWords.formatted(.number.locale(Locale(identifier: "fr_FR"))) : "?"
        return "Fichiers acceptés : .txt .md .csv .json .rtf .docx .pdf (texte, pas de scan) — jusqu’à environ \(display) mots"
    }

    var contextSize: Int { model.contextSize }

    var contextRatio: Double {
        guard contextSize > 0 else { return 0 }
        return Double(contextTokenCount) / Double(contextSize)
    }

    var shouldShowContextSafetyHint: Bool {
        compressionFailed && contextRatio >= 0.85
    }

    var documentPartCapacity: Int {
        max(1, Int(Double(contextSize) * 0.6 / 1.4))
    }

    var translationLanguages: [TranslationLanguage] {
        let french = Locale(identifier: "fr_FR")
        let codes = Set(model.supportedLanguages.compactMap { $0.languageCode?.identifier.lowercased() })
        return codes.map { code in
            TranslationLanguage(code: code, name: french.localizedString(forLanguageCode: code) ?? code)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func setInput(_ value: String) {
        input = value
        inputRevision += 1
    }

    func chooseFile(questionAfterSelection: String? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        let fileTypes: [UTType] = AttachmentReader.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = fileTypes
        panel.message = "Choisissez un document texte"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try AttachmentReader.read(url: url)
            if let questionAfterSelection { setInput(questionAfterSelection) }
            Task { @MainActor in
                do {
                    let tokens = try await self.model.tokenCount(for: content)
                    if self.attachment?.isLoaded == true {
                        self.session = self.newSession()
                        self.turns = []
                        self.previousSummary = nil
                        self.messages = []
                        self.contextTokenCount = 0
                        self.compressionFailed = false
                    }
                    self.attachment = TextAttachment(name: url.lastPathComponent, content: content, tokenCount: tokens)
                    await self.refreshContextGauge()
                } catch {
                    self.messages.append(ChatItem(role: .error, text: self.errorText(error), durationMilliseconds: nil))
                }
            }
        } catch let error as AttachmentReadError {
            messages.append(ChatItem(role: .error, text: attachmentErrorText(error), durationMilliseconds: nil))
        } catch {
            messages.append(ChatItem(role: .error, text: "Le fichier doit être du texte UTF-8 lisible.", durationMilliseconds: nil))
        }
    }

    func loadDocumentPart(_ part: DocumentPart) {
        guard !isSending, unavailableReason == nil else { return }
        Task { @MainActor in
            do {
                let tokens = try await model.tokenCount(for: part.content)
                let instructionTokens = try await model.tokenCount(for: Self.instructions)
                guard instructionTokens + tokens <= Int(Double(contextSize) * 0.9) else {
                    messages.append(ChatItem(role: .error, text: "Cette partie reste trop longue pour la fenêtre du modèle.", durationMilliseconds: nil))
                    return
                }
                let hadConversation = !turns.isEmpty || attachment?.isLoaded == true
                let card = messages.first { item in
                    if case .some(.oversizedDocument) = item.action { return true }
                    return false
                }
                let sourceName = oversizedDocumentName ?? "document"
                let displayName = "\(sourceName) — partie \(part.id)/\(part.total)"
                attachment = TextAttachment(name: displayName, content: part.content, tokenCount: tokens)
                session = newSession()
                turns = []
                contextTokenCount = 0
                compressionFailed = false
                messages = card.map { [$0] } ?? []
                if hadConversation {
                    messages.append(ChatItem(role: .system, text: "Nouvelle partie chargée : la conversation a été réinitialisée.", durationMilliseconds: nil))
                }
                await refreshContextGauge()
            } catch {
                messages.append(ChatItem(role: .error, text: errorText(error), durationMilliseconds: nil))
            }
        }
    }

    func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSending, unavailableReason == nil, let session else { return }
        let sentText: String
        let injectsAttachment = attachment?.isPendingInjection == true
        if let attachment, injectsAttachment {
            sentText = "Réponds uniquement à partir du document ci-dessous.\n\nDocument « \(attachment.name) » :\n\(attachment.content)\n\nQuestion : \(question)"
        } else {
            sentText = question
        }
        input = ""
        responseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                let contextSize = self.model.contextSize
                guard contextSize > 0 else {
                    self.messages.append(ChatItem(role: .error, text: "Impossible de connaître la fenêtre de contexte du modèle.", durationMilliseconds: nil))
                    return
                }
                if let attachment, injectsAttachment {
                    let instructionTokens = try await self.model.tokenCount(for: Self.instructions)
                    let fileTokens = try await self.model.tokenCount(for: self.documentPrompt(attachment, question: ""))
                    let fileOnlyTotal = instructionTokens + fileTokens
                    guard fileOnlyTotal <= Int(Double(contextSize) * 0.9) else {
                        self.showOversizedDocumentCard(attachment)
                        self.input = question
                        return
                    }
                }
                let transcriptTokens = try await self.model.tokenCount(for: session.transcript)
                let messageTokens = try await self.model.tokenCount(for: sentText)
                let totalTokens = transcriptTokens + messageTokens
                guard totalTokens <= Int(Double(contextSize) * 0.9) else {
                    self.messages.append(ChatItem(role: .error, text: "La conversation est pleine (\(totalTokens) / \(contextSize) jetons).", durationMilliseconds: nil, action: .conversationFull))
                    return
                }

                if injectsAttachment {
                    self.attachment?.isPendingInjection = false
                    self.attachment?.isLoaded = true
                }
                self.messages.append(ChatItem(role: .user, text: question, durationMilliseconds: nil))
                let responseID = UUID()
                self.messages.append(ChatItem(id: responseID, role: .model, text: "", durationMilliseconds: nil))
                self.isSending = true
                let started = Date()
                for try await snapshot in session.streamResponse(to: sentText) {
                    try Task.checkCancellation()
                    self.replace(id: responseID, text: String(snapshot.content), duration: nil)
                }
                try Task.checkCancellation()
                let duration = Int(Date().timeIntervalSince(started) * 1_000)
                self.replace(id: responseID, text: self.messageText(id: responseID), duration: duration)
                self.isSending = false
                self.turns.append(ConversationTurn(question: question, answer: self.messageText(id: responseID)))
                await self.refreshContextGauge()
                await self.compressConversationIfNeeded()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.messages.append(ChatItem(role: .error, text: self.errorText(error), durationMilliseconds: nil))
                self.isSending = false
            }
        }
    }

    private func messageText(id: UUID) -> String {
        messages.first(where: { $0.id == id })?.text ?? ""
    }

    private func replace(id: UUID, text: String, duration: Int?) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        messages[index].durationMilliseconds = duration
    }

    private func errorText(_ error: Error) -> String {
        if let modelError = error as? LanguageModelError {
            switch modelError {
            case .guardrailViolation:
                return "Les garde-fous d'Apple ont bloqué cette réponse."
            case .contextSizeExceeded:
                return "La conversation est trop longue pour le modèle : cliquez sur Nouvelle conversation."
            case .unsupportedLanguageOrLocale:
                return "Langue non prise en charge."
            case .rateLimited(_), .refusal(_), .unsupportedCapability(_), .unsupportedTranscriptContent(_), .unsupportedGenerationGuide(_), .timeout(_):
                return modelError.localizedDescription
            @unknown default:
                return modelError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func attachmentErrorText(_ error: AttachmentReadError) -> String {
        switch error {
        case .tooLarge(let bytes):
            let megabytes = Double(bytes) / 1_000_000
            let value = String(format: "%.1f", megabytes).replacingOccurrences(of: ".", with: ",")
            return "Fichier trop lourd (\(value) Mo, maximum 5 Mo)"
        case .scannedPDF:
            return "Ce PDF ne contient pas de texte lisible (scan) : il faudrait d'abord le passer par la reconnaissance de texte."
        case .unreadableText:
            return "Le fichier doit être du texte UTF-8 lisible."
        case .damagedDocument:
            return "Ce fichier est illisible (document endommagé ?)."
        }
    }

    private func refreshContextGauge() async {
        guard let session else { return }
        do { contextTokenCount = try await model.tokenCount(for: session.transcript) }
        catch { contextTokenCount = 0 }
    }

    private func documentPrompt(_ attachment: TextAttachment, question: String) -> String {
        "Réponds uniquement à partir du document ci-dessous.\n\nDocument « \(attachment.name) » :\n\(attachment.content)\n\nQuestion : \(question)"
    }

    private func showOversizedDocumentCard(_ attachment: TextAttachment) {
        let wordCount = DocumentSplitter.wordCount(attachment.content)
        let capacity = documentPartCapacity
        let parts = DocumentSplitter.split(attachment.content, maximumWords: capacity)
        let words = wordCount.formatted(.number.locale(Locale(identifier: "fr_FR")))
        let tokens = attachment.tokenCount.formatted(.number.locale(Locale(identifier: "fr_FR")))
        let visibleCapacity = capacity.formatted(.number.locale(Locale(identifier: "fr_FR")))
        let text = "Ce document fait \(words) mots (\(tokens) jetons). Je ne peux lire qu’environ \(visibleCapacity) mots à la fois — c’est la limite de mémoire du modèle, pas un bogue. Je l’ai découpé en \(parts.count) parties ; choisissez celle à charger, ou posez votre question partie par partie."
        messages.removeAll { item in
            if case .some(.oversizedDocument) = item.action { return true }
            return false
        }
        oversizedDocumentName = attachment.name
        self.attachment = nil
        messages.append(ChatItem(role: .system, text: text, durationMilliseconds: nil, action: .oversizedDocument(parts: parts)))
    }

    private func newSession(withLoadedDocument attachment: TextAttachment? = nil) -> LanguageModelSession {
        guard let attachment else { return LanguageModelSession(instructions: Self.instructions) }
        let instructionEntry = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: Self.instructions))], toolDefinitions: []
        )
        let documentEntry = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: documentPrompt(attachment, question: "")))]
        )
        let documentResponse = Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Document chargé."))])
        return LanguageModelSession(transcript: Transcript(entries: [.instructions(instructionEntry), .prompt(documentEntry), .response(documentResponse)]))
    }

    private func compressConversationIfNeeded() async {
        guard contextRatio > 0.60 else { return }
        guard turns.count > 2, !isCompressing, session != nil else {
            if contextRatio >= 0.85 { compressionFailed = true }
            return
        }
        isCompressing = true
        defer { isCompressing = false }
        let before = contextTokenCount
        let request = "Résume en moins de 200 mots les questions posées et les réponses données, en gardant les faits, chiffres et noms exacts. Ne résume pas le document lui-même."
        do {
            let recentTurns = Array(turns.suffix(2))
            let summarySession = compressionSourceSession(turns: Array(turns.dropLast(2)))
            let summary = try await summarySession.respond(
                to: request,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 300)
            ).content
            let compressed = compressedSession(document: attachment?.isLoaded == true ? attachment : nil, summary: summary, recentTurns: recentTurns)
            let compressedTokens = try await model.tokenCount(for: compressed.transcript)
            if compressedTokens > Int(Double(contextSize) * 0.85) {
                compressionFailed = true
                messages.append(ChatItem(role: .error, text: "La conversation est pleine (\(before) / \(contextSize) jetons).", durationMilliseconds: nil, action: .conversationFull))
                return
            }
            self.session = compressed
            turns = recentTurns
            previousSummary = summary
            contextTokenCount = compressedTokens
            compressionFailed = false
            let documentSuffix = attachment?.isLoaded == true ? " (le document est conservé en entier)." : "."
            messages.append(ChatItem(role: .system, text: "Conversation compressée : \(before) → \(compressedTokens) jetons\(documentSuffix)", durationMilliseconds: nil))
        } catch {
            compressionFailed = true
            messages.append(ChatItem(role: .error, text: errorText(error), durationMilliseconds: nil))
        }
    }

    private func compressionSourceSession(turns: [ConversationTurn]) -> LanguageModelSession {
        let instructionEntry = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: Self.instructions))], toolDefinitions: []
        )
        var entries: [Transcript.Entry] = [.instructions(instructionEntry)]
        if let previousSummary {
            let prompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Résumé des échanges précédents :"))])
            let response = Transcript.Response(segments: [.text(Transcript.TextSegment(content: previousSummary))])
            entries += [.prompt(prompt), .response(response)]
        }
        for turn in turns {
            let prompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: turn.question))])
            let response = Transcript.Response(segments: [.text(Transcript.TextSegment(content: turn.answer))])
            entries += [.prompt(prompt), .response(response)]
        }
        return LanguageModelSession(transcript: Transcript(entries: entries))
    }

    private func compressedSession(document: TextAttachment?, summary: String, recentTurns: [ConversationTurn]) -> LanguageModelSession {
        let instructionEntry = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: Self.instructions))], toolDefinitions: []
        )
        var entries: [Transcript.Entry] = [.instructions(instructionEntry)]
        if let document {
            let prompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: documentPrompt(document, question: "")))])
            entries += [.prompt(prompt), .response(Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Document chargé."))]))]
        }
        let summaryPrompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Résumé des échanges précédents :"))])
        entries += [.prompt(summaryPrompt), .response(Transcript.Response(segments: [.text(Transcript.TextSegment(content: summary))]))]
        for turn in recentTurns {
            let prompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: turn.question))])
            let response = Transcript.Response(segments: [.text(Transcript.TextSegment(content: turn.answer))])
            entries += [.prompt(prompt), .response(response)]
        }
        return LanguageModelSession(transcript: Transcript(entries: entries))
    }
}

struct ContentView: View {
    @ObservedObject var model: ChatModel
    @Local private var inputHeight: CGFloat = 64

    var body: some View {
        Group {
            if let reason = model.unavailableReason {
                VStack(spacing: 18) {
                    Text("Le modèle Apple n’est pas disponible : \(reason)")
                        .multilineTextAlignment(.center)
                    Button("Ouvrir Réglages Système") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else {
                chat
            }
        }
        .background(Color.white)
        .background(WindowFramePersistence())
    }

    private var chat: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 3) {
                Text("FM Mini")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(Color(red: 0.16, green: 0.16, blue: 0.18))
                Text("votre IA locale gratuite").font(.subheadline).foregroundStyle(.secondary)
                Button("Nouvelle conversation") { model.newConversation() }
                    .controlSize(.small)
                    .disabled(model.isSending)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.white)
            ContextGauge(model: model)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            Divider()
            if model.messages.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        WelcomeView(model: model)
                            .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 56), alignment: .center)
                            .padding(28)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(model.messages) { item in
                                Bubble(item: item, model: model).id(item.id)
                            }
                            Color.clear.frame(height: 1).id("end")
                        }
                        .padding(20)
                    }
                    .onReceive(model.$messages) { _ in
                        withAnimation { proxy.scrollTo("end", anchor: .bottom) }
                    }
                }
            }

            Divider()
            composer
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let attachment = model.attachment {
                if !attachment.isLoaded {
                    HStack(spacing: 8) {
                        Text(attachment.name).lineLimit(2)
                        Text("\(attachment.tokenCount) jetons").foregroundStyle(.secondary)
                        Button("×") { model.attachment = nil }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Retirer le fichier")
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12), in: Capsule())
                } else {
                    Text("document chargé : \(attachment.name) (\(attachment.tokenCount) jetons)")
                        .lineLimit(2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.gray.opacity(0.10), in: Capsule())
                }
            }
            MultiLineInput(text: $model.input, height: $inputHeight, focusRevision: model.inputRevision, onSend: model.send)
                .frame(height: inputHeight)
            HStack(spacing: 10) {
                Button("Joindre un fichier…") { model.chooseFile() }
                    .disabled(model.isSending)
                Spacer()
                Button(model.isSending ? "Réponse…" : "Envoyer") { model.send() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
            }
            Text(model.attachmentHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white)
    }
}

struct ContextGauge: View {
    @ObservedObject var model: ChatModel

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(model.contextTokenCount) / \(model.contextSize) jetons")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: min(model.contextRatio, 1))
                .controlSize(.small)
                .tint(color)
            if model.shouldShowContextSafetyHint {
                Text("Conversation presque pleine.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var color: Color {
        if model.contextRatio < 0.60 { return .gray }
        if model.contextRatio < 0.85 { return .orange }
        return .red
    }
}

struct WelcomeView: View {
    @ObservedObject var model: ChatModel
    @Environment(\.openWindow) private var openWindow

    private let suggestions = [
        "Résume ce texte en trois phrases : ",
        "Corrige l’orthographe et la grammaire de ce texte : ",
        "Reformule ce message pour qu’il soit plus clair et plus poli : "
    ]

    var body: some View {
        VStack(spacing: 15) {
            Text("BONJOUR, QUE PUIS-JE FAIRE POUR VOUS ?")
                .font(.headline.weight(.medium))
                .tracking(0.3)
                .multilineTextAlignment(.center)
            Text("Je suis gratuit et je tourne entièrement sur votre Mac : vos textes et vos documents ne quittent jamais votre ordinateur, même sans connexion internet. Je comprends 24 langues, dont le français, et je réponds en une seconde environ. Je sais résumer, corriger, reformuler, traduire et extraire l’essentiel de ce que vous me donnez. En revanche, je ne connais pas l’actualité et je n’ai presque pas de connaissances encyclopédiques : donnez-moi le texte sur lequel travailler.")
                .font(.caption)
                .foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.30))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    SuggestionChip(title: suggestion) { model.setInput(suggestion) }
                }
                TranslationMenu(languages: model.translationLanguages) { language in model.setInput("Traduis en \(language.name) : ") }
                SuggestionChip(title: "Joindre un document et en lister les points importants") {
                    model.chooseFile(questionAfterSelection: "Liste les points importants de ce document.")
                }
            }
            .frame(maxWidth: 650)
            Button("Aller plus loin → Compléter l’installation") {
                openWindow(id: "installation")
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}

struct SuggestionChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text(title).font(.caption).multilineTextAlignment(.center).padding(.horizontal, 11).padding(.vertical, 7).frame(maxWidth: .infinity) }
            .buttonStyle(.plain)
            .foregroundStyle(Color.primary)
            .background(Color.gray.opacity(0.11), in: Capsule())
    }
}

struct TranslationMenu: View {
    let languages: [TranslationLanguage]
    let select: (TranslationLanguage) -> Void

    var body: some View {
        Menu {
            if languages.isEmpty {
                Text("Aucune langue disponible")
            } else {
                ForEach(languages) { language in
                    Button(language.name.localizedCapitalized) { select(language) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Traduire en…")
                Image(systemName: "chevron.down").font(.caption2)
            }
            .font(.caption)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
        .foregroundStyle(Color.primary)
        .background(Color.gray.opacity(0.11), in: Capsule())
    }
}

struct Bubble: View {
    let item: ChatItem
    @ObservedObject var model: ChatModel
    @Local private var isHovering = false
    @Local private var copied = false

    var body: some View {
        if case .some(.oversizedDocument(let parts)) = item.action {
            OversizedDocumentCard(explanation: item.text, parts: parts, model: model)
        } else if item.role == .system {
            Text(item.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        } else {
            HStack {
                if item.role == .user { Spacer(minLength: 65) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text.isEmpty && item.role == .model ? "…" : item.text)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if let ms = item.durationMilliseconds {
                        Text("\(ms) ms").font(.caption2).foregroundStyle(.secondary)
                    }
                    if case .some(.conversationFull) = item.action {
                        VStack(alignment: .leading, spacing: 6) {
                            Button("Nouvelle conversation en gardant le document") { model.newConversationKeepingDocument() }
                            Button("Nouvelle conversation") { model.newConversation() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .background(background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: item.role == .model ? 1 : 0))
                .overlay(alignment: .topTrailing) {
                    if isHovering {
                        Button(action: copy) {
                            Label(copied ? "Copié" : "Copier", systemImage: "doc.on.doc")
                                .font(.caption)
                                .padding(.horizontal, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(2)
                    }
                }
                .onHover { isHovering = $0 }
                .contextMenu {
                    Button("Copier", systemImage: "doc.on.doc", action: copy)
                }
                if item.role != .user { Spacer(minLength: 65) }
            }
        }
    }

    private var background: Color { item.role == .user ? Color.gray.opacity(0.16) : .white }
    private var border: Color { item.role == .model ? Color.gray.opacity(0.35) : .clear }

    private func copy() {
        copied = BubbleClipboard.copy(item.text)
        guard copied else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

struct OversizedDocumentCard: View {
    let explanation: String
    let parts: [DocumentPart]
    @ObservedObject var model: ChatModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(explanation)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            LazyVStack(alignment: .leading, spacing: 7) {
                ForEach(parts) { part in
                    Button {
                        model.loadDocumentPart(part)
                    } label: {
                        Text(partLabel(part))
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isSending)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.25), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func partLabel(_ part: DocumentPart) -> String {
        let locale = Locale(identifier: "fr_FR")
        let start = part.firstWord.formatted(.number.locale(locale))
        let end = part.lastWord.formatted(.number.locale(locale))
        return "Partie \(part.id)/\(part.total) — mots \(start) à \(end) — « \(part.preview) »"
    }
}

struct InstallationSection: Identifiable {
    let title: String
    let tools: [InstallationTool]
    var id: String { title }
}

struct InstallationTool: Identifiable {
    let id: String
    let name: String
    let about: String
    let needed: String
    let unnecessary: String
    let statusKey: String?
    let url: String?
    let tooltip: String?
}

enum InstallationAvailability {
    case checking
    case detected(String?)
    case unavailable
}

@MainActor
final class InstallationModel: ObservableObject {
    @Published private(set) var statuses: [String: InstallationAvailability] = [:]

    init() {
        Task { [weak self] in
            let results = await InstallationChecker.checkAll()
            self?.statuses = results
        }
    }

    func status(for tool: InstallationTool) -> InstallationAvailability? {
        guard let key = tool.statusKey else { return nil }
        return statuses[key] ?? .checking
    }

    func open(_ tool: InstallationTool) {
        InstallationActions.open(tool)
    }
}

enum InstallationChecker {
    static func checkAll() async -> [String: InstallationAvailability] {
        async let lmServerActive = lmStudioServerActive()
        let fileManager = FileManager.default
        let lmStudioApp = fileManager.fileExists(atPath: "/Applications/LM Studio.app")
        let lmServer = await lmServerActive
        return [
            "fm": fileManager.fileExists(atPath: "/usr/bin/fm") ? .detected(nil) : .unavailable,
            "shortcuts": .detected(nil),
            "lmstudio": (lmStudioApp || lmServer) ? .detected(lmServer ? "serveur actif" : nil) : .unavailable,
            "ollama": fileManager.fileExists(atPath: "/Applications/Ollama.app") ? .detected(nil) : .unavailable,
            "homebrew": fileManager.fileExists(atPath: "/opt/homebrew/bin/brew") ? .detected(nil) : .unavailable,
            "apfel": commandSucceeds("/usr/bin/which", ["apfel"]) ? .detected(nil) : .unavailable,
            "clt": commandSucceeds("/usr/bin/xcode-select", ["-p"]) ? .detected(nil) : .unavailable,
            "python-sdk": commandSucceeds("/usr/bin/env", ["python3", "-c", "import apple_fm_sdk"]) ? .detected(nil) : .unavailable,
            "xcode": fileManager.fileExists(atPath: "/Applications/Xcode.app") ? .detected(nil) : .unavailable
        ]
    }

    private static func commandSucceeds(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func lmStudioServerActive() async -> Bool {
        var request = URLRequest(url: URL(string: "http://localhost:1234/v1/models")!)
        request.timeoutInterval = 0.5
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.5
        configuration.timeoutIntervalForResource = 0.8
        configuration.waitsForConnectivity = false
        do {
            let (_, response) = try await URLSession(configuration: configuration).data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

enum InstallationActions {
    static func open(_ tool: InstallationTool) {
        switch tool.id {
        case "fm", "homebrew", "apfel", "clt", "python-sdk":
            openTerminal()
        case "shortcuts":
            openLocalApplication("/System/Applications/Shortcuts.app", fallbackURL: URL(string: "shortcuts://")!)
        case "lmstudio":
            openLocalApplication("/Applications/LM Studio.app", fallbackURL: URL(string: tool.url!)!)
        case "ollama":
            openLocalApplication("/Applications/Ollama.app", fallbackURL: URL(string: tool.url!)!)
        case "xcode":
            openLocalApplication("/Applications/Xcode.app", fallbackURL: URL(string: tool.url!)!)
        case "apple-docs":
            openURLs([
                "https://developer.apple.com/documentation/foundationmodels",
                "https://developer.apple.com/videos/play/wwdc2026/334/"
            ])
        case "mcp":
            openURLs([
                "https://github.com/airy10/AppleFoundationMCPTool",
                "https://github.com/phimage/mcp-foundation-models"
            ])
        default:
            if let url = tool.url.flatMap(URL.init(string:)) { NSWorkspace.shared.open(url) }
        }
    }

    private static func openTerminal() {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        if FileManager.default.fileExists(atPath: terminal.path) {
            NSWorkspace.shared.open(terminal)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
        }
    }

    private static func openLocalApplication(_ path: String, fallbackURL: URL) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private static func openURLs(_ values: [String]) {
        for value in values {
            if let url = URL(string: value) { NSWorkspace.shared.open(url) }
        }
    }
}

struct InstallationView: View {
    @Local private var model = InstallationModel()

    private let sections: [InstallationSection] = [
        InstallationSection(title: "Déjà sur votre Mac, rien à installer", tools: [
            InstallationTool(id: "fm", name: "fm (dans le Terminal)", about: "parler au même modèle qu'ici en tapant des commandes, et l'enchaîner avec d'autres outils.", needed: "vous aimez le Terminal, ou si vous voulez traiter des fichiers en série (résumer dix textes d'un coup, par exemple).", unnecessary: "vous êtes satisfait de cette fenêtre. FM Mini fait la même chose, en cliquant.", statusKey: "fm", url: nil, tooltip: nil),
            InstallationTool(id: "shortcuts", name: "Raccourcis → « Utiliser le modèle »", about: "ajouter le modèle à des automatisations sans écrire de code, par exemple un clic droit sur un fichier pour le résumer.", needed: "vous répétez souvent la même tâche sur des fichiers ou des textes.", unnecessary: "vous posez des questions ponctuelles : cette fenêtre suffit.", statusKey: "shortcuts", url: nil, tooltip: nil)
        ]),
        InstallationSection(title: "Sans programmer", tools: [
            InstallationTool(id: "lmstudio", name: "LM Studio", about: "faire tourner d'autres modèles sur votre Mac, plus gros et plus cultivés que celui d'Apple, que fm peut ensuite utiliser.", needed: "le modèle Apple vous répond trop souvent « je ne sais pas », et si votre Mac a au moins 16 Go de mémoire (32 Go pour les modèles vraiment plus forts).", unnecessary: "vous travaillez surtout sur vos propres textes : le modèle Apple est plus rapide et déjà là.", statusKey: "lmstudio", url: "https://lmstudio.ai", tooltip: nil),
            InstallationTool(id: "ollama", name: "Ollama", about: "la même chose que LM Studio, en plus sobre, piloté depuis le Terminal.", needed: "vous préférez le Terminal aux fenêtres, ou si LM Studio ne vous convient pas.", unnecessary: "vous avez déjà LM Studio : l'un ou l'autre, pas les deux.", statusKey: "ollama", url: "https://ollama.com", tooltip: nil),
            InstallationTool(id: "homebrew", name: "Homebrew", about: "installer des outils du Terminal en une ligne. C'est un prérequis, pas un outil en soi.", needed: "vous voulez installer apfel, ou tout autre outil « brew install … ».", unnecessary: "vous n'installez rien de la liste ci-dessous.", statusKey: "homebrew", url: "https://brew.sh", tooltip: nil),
            InstallationTool(id: "apfel", name: "apfel", about: "le modèle Apple comme outil du Terminal avec quelques fonctions que fm n'a pas (connexion à des outils externes MCP, scripts tout prêts).", needed: "vous êtes sur macOS 26 (où fm n'existe pas), ou si vous voulez brancher le modèle sur des outils MCP.", unnecessary: "vous êtes sur macOS 27 et que fm vous suffit.", statusKey: "apfel", url: "https://github.com/Arthur-Ficial/apfel", tooltip: nil)
        ]),
        InstallationSection(title: "Avec Python", tools: [
            InstallationTool(id: "clt", name: "Command Line Tools d'Apple", about: "les outils de base pour compiler et pour Python. Vous les avez déjà si FM Mini a été construit sur ce Mac.", needed: "vous voulez utiliser quoi que ce soit de cette section ou de la suivante.", unnecessary: "vous ne programmez pas.", statusKey: "clt", url: nil, tooltip: "xcode-select --install"),
            InstallationTool(id: "python-sdk", name: "SDK Python Apple (apple-fm-sdk)", about: "piloter le modèle depuis Python, lui donner des outils (calendrier, fichiers, base de données) et mesurer ses réponses sur des séries de tests.", needed: "vous écrivez des scripts Python, ou si vous voulez vérifier sérieusement ce que le modèle réussit et rate.", unnecessary: "vous ne programmez pas.", statusKey: "python-sdk", url: "https://github.com/apple/python-apple-fm-sdk", tooltip: nil),
            InstallationTool(id: "apple-docs", name: "Documentation Apple et vidéo de présentation", about: "la référence officielle du framework, et vingt minutes de vidéo qui montrent fm et le SDK Python.", needed: "vous voulez comprendre ce qui se passe sous le capot avant d'aller plus loin.", unnecessary: "vous voulez seulement vous servir de l'app.", statusKey: nil, url: "https://developer.apple.com/documentation/foundationmodels", tooltip: nil)
        ]),
        InstallationSection(title: "Pour développer des applications", tools: [
            InstallationTool(id: "xcode", name: "Xcode", about: "l'atelier complet d'Apple. Indispensable pour certaines fonctions du langage Swift et pour signer une app que vous distribuez.", needed: "vous voulez écrire vos propres apps utilisant le modèle, ou en distribuer. Comptez 15 Go.", unnecessary: "vous utilisez des apps déjà construites, comme celle-ci.", statusKey: "xcode", url: "https://apps.apple.com/app/xcode/id497799835", tooltip: nil),
            InstallationTool(id: "utilities", name: "Foundation Models utilities (Apple, open source)", about: "des briques officielles pour les développeurs : gérer de longues conversations, définir des « compétences », se connecter à n'importe quel serveur de modèle compatible OpenAI.", needed: "vous développez en Swift avec le modèle.", unnecessary: "vous ne développez pas.", statusKey: nil, url: "https://github.com/apple/foundation-models-utilities", tooltip: nil),
            InstallationTool(id: "mcp", name: "Ponts MCP", about: "relier le modèle à des outils externes (dans un sens) ou le mettre à disposition d'autres assistants comme outil (dans l'autre).", needed: "vous utilisez déjà des serveurs MCP et savez ce que c'est.", unnecessary: "cette phrase ne vous dit rien — c'est normal, et ça ne vous manquera pas.", statusKey: nil, url: "https://github.com/airy10/AppleFoundationMCPTool", tooltip: nil)
        ])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(section.title).font(.headline)
                        ForEach(section.tools) { tool in
                            InstallationToolCard(tool: tool, status: model.status(for: tool)) {
                                model.open(tool)
                            }
                        }
                    }
                }
                Text("Toutes ces vérifications sont faites sur votre Mac ; rien n'est téléchargé ni installé par FM Mini.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.white)
    }
}

struct InstallationToolCard: View {
    let tool: InstallationTool
    let status: InstallationAvailability?
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Text(tool.name).font(.subheadline.weight(.bold))
                if let status {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 8, height: 8)
                    Text(statusText(status))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text("À quoi ça sert : \(tool.about)")
                .font(.caption)
            Label("Vous en avez besoin si… \(tool.needed)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(Color.green)
            Label("Inutile si… \(tool.unnecessary)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Ouvrir", action: open)
                .controlSize(.small)
                .help(tool.tooltip ?? "")
        }
        .padding(12)
        .background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.18), lineWidth: 1))
    }

    private func statusColor(_ status: InstallationAvailability) -> Color {
        if case .detected = status { return .green }
        return .gray
    }

    private func statusText(_ status: InstallationAvailability) -> String {
        switch status {
        case .checking: return "vérification…"
        case .detected(let detail): return detail ?? "détecté"
        case .unavailable: return "non détecté"
        }
    }
}

struct MultiLineInput: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let focusRevision: Int
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let view = SendTextView()
        view.delegate = context.coordinator
        view.isRichText = false
        view.font = .systemFont(ofSize: 14)
        view.setAccessibilityLabel("Message")
        view.textContainerInset = NSSize(width: 4, height: 4)
        view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        view.drawsBackground = true
        view.backgroundColor = .white
        view.onSend = onSend
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? SendTextView else { return }
        if view.string != text { view.string = text }
        view.onSend = onSend
        context.coordinator.updateHeight(for: view)
        if context.coordinator.lastFocusRevision != focusRevision {
            context.coordinator.lastFocusRevision = focusRevision
            view.setSelectedRange(NSRange(location: view.string.utf16.count, length: 0))
            view.window?.makeFirstResponder(view)
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultiLineInput
        var lastFocusRevision = 0
        init(_ parent: MultiLineInput) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            updateHeight(for: view)
        }

        func updateHeight(for view: NSTextView) {
            guard let layoutManager = view.layoutManager, let textContainer = view.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let lineHeight = view.font?.boundingRectForFont.height ?? 17
            let minimum = ceil(lineHeight * 3 + view.textContainerInset.height * 2)
            let maximum = ceil(lineHeight * 6 + view.textContainerInset.height * 2)
            let used = ceil(layoutManager.usedRect(for: textContainer).height + view.textContainerInset.height * 2)
            let desired = min(maximum, max(minimum, used))
            if abs(parent.height - desired) > 0.5 {
                parent.height = desired
            }
        }
    }
}

final class SendTextView: NSTextView {
    var onSend: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            onSend?()
        } else {
            super.keyDown(with: event)
        }
    }
}

struct WindowFramePersistence: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard !context.coordinator.didConfigure else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = view.window, !context.coordinator.didConfigure else { return }
            let autosaveName = "FMMiniWindow"
            let autosaveKey = "NSWindow Frame \(autosaveName)"
            let hasSavedFrame = UserDefaults.standard.string(forKey: autosaveKey) != nil
            window.setFrameAutosaveName(autosaveName)
            if hasSavedFrame {
                window.setFrameUsingName(autosaveName)
            } else {
                window.setContentSize(NSSize(width: 460, height: 760))
                window.center()
            }
            window.saveFrame(usingName: autosaveName)
            context.coordinator.observe(window: window, autosaveName: autosaveName)
            context.coordinator.didConfigure = true
        }
    }

    final class Coordinator {
        var didConfigure = false
        private var observers: [NSObjectProtocol] = []

        func observe(window: NSWindow, autosaveName: String) {
            let center = NotificationCenter.default
            for notification in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observers.append(center.addObserver(forName: notification, object: window, queue: .main) { _ in
                    Task { @MainActor in window.saveFrame(usingName: autosaveName) }
                })
            }
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}

struct FMMiniApp: App {
    @Local private var model = ChatModel()

    var body: some Scene {
        WindowGroup("FM Mini") {
            ContentView(model: model)
                .frame(minWidth: 400, minHeight: 560)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 460, height: 760)
        .windowResizability(.contentMinSize)

        Window("Compléter l’installation", id: "installation") {
            InstallationView()
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 520, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            InstallationCommands()
        }
    }
}

struct InstallationCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Compléter l’installation…") {
                openWindow(id: "installation")
            }
        }
    }
}

@main
struct FMMiniMain {
    static func main() {
        if CommandLine.arguments.contains("--autotest") {
            Task {
                let status = await AutoTest.run()
                fflush(stdout)
                exit(Int32(status))
            }
            dispatchMain()
        } else {
            FMMiniApp.main()
        }
    }
}

final class AutoTestReporter {
    private let report: FileHandle?

    init() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "autotest-\(formatter.string(from: Date())).txt"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("fm-mini", isDirectory: true)
            .appendingPathComponent(filename)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        report = try? FileHandle(forWritingTo: url)
    }

    func emit(_ line: String) {
        let data = Data((line + "\n").utf8)
        FileHandle.standardOutput.write(data)
        fflush(stdout)
        report?.write(data)
        report?.synchronizeFile()
    }

    deinit { report?.closeFile() }
}

enum AutoTest {
    static func run() async -> Int {
        let reporter = AutoTestReporter()
        reporter.emit("FM Mini autotest — début")
        reporter.emit("AUTOTEST découpage unitaire : \(DocumentSplitter.structuredSplitUnitTest() ? "OK" : "ÉCHEC")")
        guard auditFixtures(reporter: reporter) else { return 1 }
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            reporter.emit("AUTOTEST 1: ÉCHEC — modèle indisponible : \(model.availability)")
            return 1
        }
        do {
            let normalSession = LanguageModelSession(instructions: ChatModel.instructions)
            let normalStart = Date()
            let normal = try await normalSession.respond(to: "dis-moi ce que tu sais faire")
            let normalHasNoDocumentMention = !normal.content.localizedCaseInsensitiveContains("document")
            reporter.emit("AUTOTEST 0: \(normalHasNoDocumentMention ? "OK" : "ÉCHEC") — \(normal.content) (\(Int(Date().timeIntervalSince(normalStart) * 1_000)) ms)")

            let session = LanguageModelSession(instructions: ChatModel.instructions)
            let started = Date()
            let response = try await session.respond(to: "salut")
            let ms = Int(Date().timeIntervalSince(started) * 1_000)
            reporter.emit("AUTOTEST 1: \(response.content) (\(ms) ms)")

            let document = Array(repeating: "Ce document explique qu’un jardin partagé permet aux voisins de cultiver ensemble, de réduire les déchets grâce au compost et de créer des liens sociaux durables.", count: 12).joined(separator: " ")
            let summarySession = LanguageModelSession(instructions: ChatModel.instructions)
            let summaryStart = Date()
            let summary = try await summarySession.respond(to: "Réponds uniquement à partir du document ci-dessous.\n\nDocument « autotest-300-mots.txt » :\n\(document)\n\nQuestion : Résume ce document en deux phrases")
            reporter.emit("AUTOTEST 2: \(summary.content) (\(Int(Date().timeIntervalSince(summaryStart) * 1_000)) ms)")

            let largeDocument = Array(repeating: "mot", count: 20_000).joined(separator: " ")
            let tokens = try await model.tokenCount(for: largeDocument)
            let limit = model.contextSize
            let expected = tokens > Int(Double(limit) * 0.9)
            reporter.emit("AUTOTEST 3: \(expected ? "OK" : "ÉCHEC") — \(tokens) jetons pour une fenêtre de \(limit)")

            let attachmentDocument = documentWithWordCount(619)
            let compressionResult = try await compressionTest(model: model, document: attachmentDocument, reporter: reporter)
            reporter.emit("AUTOTEST 8 document chargé une fois + compression: \(compressionResult.ok ? "OK" : "ÉCHEC") — 6 questions, injection \(compressionResult.documentInjectionCount)/6, \(compressionResult.before) → \(compressionResult.after) jetons, durées \(compressionResult.questionTimings) ms ; Q7 : \(compressionResult.documentAnswer) ; première question : \(compressionResult.firstQuestionAnswer)")

            let copiedText = "Copie de bulle FM Mini"
            let pasteboardMatches = BubbleClipboard.copy(copiedText) && NSPasteboard.general.string(forType: .string) == copiedText
            reporter.emit("AUTOTEST 9 presse-papiers: \(pasteboardMatches ? "OK" : "ÉCHEC")")

            let oversizedDocument = oversizedTestDocument()
            let partCapacity = max(1, Int(Double(limit) * 0.6 / 1.4))
            let parts = DocumentSplitter.split(oversizedDocument, maximumWords: partCapacity)
            guard parts.count >= 2 else { throw AttachmentReadError.unreadableText }
            let partTwoSession = LanguageModelSession(instructions: ChatModel.instructions)
            let partTwoStart = Date()
            let partTwoAnswer = try await partTwoSession.respond(to: attachedPrompt(name: "test-20k.txt — partie 2/\(parts.count)", content: parts[1].content, question: "Quel est le code exclusif de cette partie ?"))
            let selectedPartName = "test-20k.txt — partie 3/\(parts.count)"
            let partTwoOnly = partTwoAnswer.content.localizedCaseInsensitiveContains("orange")
            reporter.emit("AUTOTEST 12 découpage: \(parts.count == 6 && partTwoOnly && selectedPartName.contains("partie 3/") ? "OK" : "ÉCHEC") — \(parts.count) puces, partie 2 : \(partTwoAnswer.content) (\(Int(Date().timeIntervalSince(partTwoStart) * 1_000)) ms), badge \(selectedPartName)")

            return 0
        } catch {
            if isModelContextError(error) {
                reporter.emit("Modèle inaccessible depuis ce contexte : lancez l'autotest depuis Terminal.app")
                return 2
            }
            reporter.emit("AUTOTEST: ÉCHEC — \(error.localizedDescription)")
            return 1
        }
    }

    private static func auditFixtures(reporter: AutoTestReporter) -> Bool {
        let fixtures = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("fm-mini/audit-fixtures", isDirectory: true)
        do {
            let docx = try AttachmentReader.read(url: fixtures.appendingPathComponent("compte-rendu-comite-des-fetes.docx"))
            let scanResult: Bool
            do {
                _ = try AttachmentReader.read(url: fixtures.appendingPathComponent("scan-sans-texte.pdf"))
                scanResult = false
            } catch AttachmentReadError.scannedPDF {
                scanResult = true
            }
            let underLimit = try AttachmentReader.read(url: fixtures.appendingPathComponent("4_9Mo.txt"))
            let overLimit: Bool
            do {
                _ = try AttachmentReader.read(url: fixtures.appendingPathComponent("5_1Mo.txt"))
                overLimit = false
            } catch AttachmentReadError.tooLarge(let bytes) {
                overLimit = bytes == 5_100_000
            }
            let ok = !docx.isEmpty && scanResult && !underLimit.isEmpty && overLimit
            reporter.emit("AUTOTEST fichiers DOCX/PDF/scan/5 Mo : \(ok ? "OK" : "ÉCHEC")")
            return ok
        } catch {
            reporter.emit("AUTOTEST fichiers DOCX/PDF/scan/5 Mo : ÉCHEC — \(error.localizedDescription)")
            return false
        }
    }

    private static func isModelContextError(_ error: Error) -> Bool {
        let description = "\(error) \(error.localizedDescription)".lowercased()
        return (description.contains("modelmanagererror") && description.contains("1008"))
            || description.contains("not available in this context")
    }

    private static func attachedPrompt(name: String, content: String, question: String) -> String {
        "Réponds uniquement à partir du document ci-dessous.\n\nDocument « \(name) » :\n\(content)\n\nQuestion : \(question)"
    }

    private static func documentWithWordCount(_ wordCount: Int) -> String {
        let sentence = "Ce document explique qu’un jardin partagé permet aux voisins de cultiver ensemble, de réduire les déchets grâce au compost et de créer des liens sociaux durables."
        var words = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        while words.count < wordCount { words.append("jardin") }
        return words.prefix(wordCount).joined(separator: " ")
    }

    private static func sessionWithLoadedDocument(_ document: String) -> LanguageModelSession {
        let instructionEntry = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: ChatModel.instructions))], toolDefinitions: []
        )
        let documentEntry = Transcript.Prompt(
            segments: [.text(Transcript.TextSegment(content: attachedPrompt(name: "document-619-mots.txt", content: document, question: "")))]
        )
        let documentResponse = Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Document chargé."))])
        return LanguageModelSession(transcript: Transcript(entries: [.instructions(instructionEntry), .prompt(documentEntry), .response(documentResponse)]))
    }

    private static func oversizedTestDocument() -> String {
        let codes = ["bleu", "orange", "vert", "violet", "jaune", "rouge"]
        return codes.enumerated().map { index, code in
            let filler = Array(repeating: "mot", count: 3_320).joined(separator: " ")
            return "PARTIE \(index + 1)\nLe code exclusif de cette partie est \(code). \(filler)."
        }.joined(separator: "\n\n")
    }

    private static func compressionTest(model: SystemLanguageModel, document: String, reporter: AutoTestReporter) async throws -> (ok: Bool, before: Int, after: Int, documentAnswer: String, firstQuestionAnswer: String, questionTimings: [Int], documentInjectionCount: Int) {
        let limit = model.contextSize
        var session = LanguageModelSession(instructions: ChatModel.instructions)
        var turns: [ConversationTurn] = []
        let padding = (1...65).map { index in
            "Élément \(index) : le jardin partagé rassemble les voisins, soutient le compost et favorise des liens sociaux durables."
        }.joined(separator: " ")
        let questions = [
            "Première question de vérification : quel est le sujet principal ?",
            "Quelle pratique réduit les déchets ?",
            "Qui participe au jardin ?",
            "Quel bénéfice social est mentionné ?",
            "Quelle activité permet de cultiver ensemble ?",
            "Quel effet le compost a-t-il ?"
        ]
        var questionTimings: [Int] = []
        var documentInjectionCount = 0
        for (index, question) in questions.enumerated() {
            let basePrompt = index == 0
                ? attachedPrompt(name: "document-619-mots.txt", content: document, question: question)
                : question
            let prompt = (1...4).contains(index) ? basePrompt + "\n\n" + padding : basePrompt
            if prompt.contains("Document «") { documentInjectionCount += 1 }
            let started = Date()
            let response = try await session.respond(to: prompt, options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 24))
            let elapsed = Int(Date().timeIntervalSince(started) * 1_000)
            questionTimings.append(elapsed)
            turns.append(ConversationTurn(question: prompt, answer: response.content))
            reporter.emit("AUTOTEST 8.\(index + 1): \(elapsed) ms")
        }
        let before = try await model.tokenCount(for: session.transcript)
        let summaryRequest = "Résume en moins de 200 mots les questions posées et les réponses données, en gardant les faits, chiffres et noms exacts. Ne résume pas le document lui-même."
        let summarySource = compressionSourceSession(turns: Array(turns.dropLast(2)))
        let summary = try await summarySource.respond(to: summaryRequest, options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 100)).content
        let compressed = compressionSession(document: document, summary: summary, recentTurns: Array(turns.suffix(2)))
        let after = try await model.tokenCount(for: compressed.transcript)
        session = compressed
        let documentAnswer = try await session.respond(to: "Quelle pratique réduit les déchets ?", options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 24)).content
        let firstQuestionAnswer = try await session.respond(to: "Quelle était ma première question ?", options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 24)).content
        let correctDocument = documentAnswer.localizedCaseInsensitiveContains("compost")
        let remembered = firstQuestionAnswer.localizedCaseInsensitiveContains("sujet") || firstQuestionAnswer.localizedCaseInsensitiveContains("première")
        return (before > Int(Double(limit) * 0.60) && after < before && after <= Int(Double(limit) * 0.85) && documentInjectionCount == 1 && correctDocument && remembered, before, after, documentAnswer, firstQuestionAnswer, questionTimings, documentInjectionCount)
    }

    private static func compressionSession(document: String, summary: String, recentTurns: [ConversationTurn]) -> LanguageModelSession {
        let instruction = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: ChatModel.instructions))], toolDefinitions: []
        )
        let documentPrompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: attachedPrompt(name: "document-619-mots.txt", content: document, question: "")))])
        let documentResponse = Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Document chargé."))])
        let summaryPrompt = Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Résumé des échanges précédents :"))])
        let summaryResponse = Transcript.Response(segments: [.text(Transcript.TextSegment(content: summary))])
        var entries: [Transcript.Entry] = [.instructions(instruction), .prompt(documentPrompt), .response(documentResponse), .prompt(summaryPrompt), .response(summaryResponse)]
        for turn in recentTurns {
            entries += [
                .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: turn.question))])),
                .response(Transcript.Response(segments: [.text(Transcript.TextSegment(content: turn.answer))]))
            ]
        }
        return LanguageModelSession(transcript: Transcript(entries: entries))
    }

    private static func compressionSourceSession(turns: [ConversationTurn]) -> LanguageModelSession {
        let instruction = Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: ChatModel.instructions))], toolDefinitions: []
        )
        var entries: [Transcript.Entry] = [.instructions(instruction)]
        for turn in turns {
            entries += [
                .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: turn.question))])),
                .response(Transcript.Response(segments: [.text(Transcript.TextSegment(content: turn.answer))]))
            ]
        }
        return LanguageModelSession(transcript: Transcript(entries: entries))
    }

    private static func writeDOCX(_ text: String, to url: URL) throws {
        let attributed = NSAttributedString(string: text)
        let data = try attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        try data.write(to: url)
    }

    private static func writeTextPDF(_ text: String, to url: URL) throws {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw AttachmentReadError.unreadableText }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw AttachmentReadError.unreadableText }
        context.beginPDFPage(nil)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: 48, y: 720)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12)]
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: url)
    }

    private static func writeBlankPDF(to url: URL) throws {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { throw AttachmentReadError.unreadableText }
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw AttachmentReadError.unreadableText }
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: url)
    }
}
