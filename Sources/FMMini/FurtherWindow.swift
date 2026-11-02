import AppKit
import SwiftUI

struct FurtherSection: Identifiable {
    let title: String
    let cards: [FurtherCard]
    var id: String { title }
}

enum FurtherAction { case dictation, shortcuts, terminal, copy(String) }

struct FurtherCard: Identifiable {
    let id: String
    let title: String
    let benefit: String
    let data: String
    let note: String?
    let action: FurtherAction
}

enum FurtherWindowContent {
    static func sections(_ langue: Langue) -> [FurtherSection] {
        let t = langue.texte
        let note: String? = nil
        return [
            FurtherSection(title: t(.sectionDejaSurMac), cards: [
                FurtherCard(id: "dictation", title: t(.carteDicteeTitre), benefit: t(.carteDicteeApport), data: t(.donneesRestentSurMac), note: nil, action: .dictation),
                FurtherCard(id: "shortcuts", title: t(.carteRaccourcisTitre), benefit: t(.carteRaccourcisApport), data: t(.donneesRestentSurMac), note: nil, action: .shortcuts),
                FurtherCard(id: "terminal", title: t(.carteTerminalTitre), benefit: t(.carteTerminalApport), data: t(.donneesRestentSurMac), note: nil, action: .terminal)
            ]),
            FurtherSection(title: t(.sectionAAjouter), cards: [
                FurtherCard(id: "images", title: t(.carteImagesTitre), benefit: t(.carteImagesApport), data: t(.donneesRestentSurMac), note: note, action: .copy(t(.demandeImages))),
                FurtherCard(id: "web", title: t(.carteWebTitre), benefit: t(.carteWebApport), data: t(.carteWebDonnees), note: note, action: .copy(t(.demandeWeb))),
                FurtherCard(id: "folder", title: t(.carteDossierTitre), benefit: t(.carteDossierApport), data: t(.donneesRestentSurMac), note: note, action: .copy(t(.demandeDossier)))
            ])
        ]
    }

    static func cards(_ langue: Langue) -> [FurtherCard] { sections(langue).flatMap(\.cards) }
}

struct InstallationView: View {
    @ObservedObject private var langues = Langues.shared
    @Local private var copiedCardID: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(langues.texte(.introAllerPlusLoin))
                    .font(.callout).foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.30)).fixedSize(horizontal: false, vertical: true)
                ForEach(FurtherWindowContent.sections(langues.courante)) { section in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(section.title).font(.headline)
                        ForEach(section.cards) { card in
                            FurtherCardView(card: card, copied: copiedCardID == card.id) { perform(card.action, cardID: card.id) }
                        }
                    }
                }
                Text(langues.texte(.piedAllerPlusLoin))
                    .font(.caption).foregroundStyle(Personnalisation.grisTexteSecondaire).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 4)
            }.padding(20)
        }.background(Color.white)
    }

    private func perform(_ action: FurtherAction, cardID: String) {
        switch action {
        case .dictation: NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
        case .shortcuts: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
        case .terminal: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        case .copy(let request):
            guard BubbleClipboard.copy(request) else { return }
            copiedCardID = cardID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copiedCardID == cardID { copiedCardID = nil } }
        }
    }
}

struct FurtherCardView: View {
    @ObservedObject private var langues = Langues.shared
    let card: FurtherCard
    let copied: Bool
    let action: () -> Void

    init(card: FurtherCard, copied: Bool, action: @escaping () -> Void) {
        self.card = card
        self.copied = copied
        self.action = action
    }

    private var buttonTitle: String {
        if copied { return langues.texte(.copie) }
        switch card.action {
        case .dictation: return langues.texte(.ouvrirReglagesDictee)
        case .shortcuts: return langues.texte(.ouvrirRaccourcis)
        case .terminal: return langues.texte(.ouvrirTerminal)
        case .copy: return langues.texte(.copierDemande)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(card.title).font(.subheadline.weight(.bold))
            Text(langues.texte(.ceQueCaApporte, card.benefit)).font(.caption).fixedSize(horizontal: false, vertical: true)
            Text(langues.texte(.vosDonnees, card.data)).font(.caption).foregroundStyle(Personnalisation.grisTexteSecondaire).fixedSize(horizontal: false, vertical: true)
            if let note = card.note {
                Text(note).font(.caption2).foregroundStyle(Personnalisation.grisTexteSecondaire)
            }
            Button(buttonTitle, action: action).controlSize(.small)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.18), lineWidth: 1))
    }
}
