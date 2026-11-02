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
    let action: FurtherAction
}

enum FurtherWindowContent {
    static let imageRequest = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute la reconnaissance de texte : « Joindre un fichier… » accepte aussi png, jpg, jpeg, heic, tiff, et les PDF sans texte ne sont plus refusés. Le texte est extrait sur le Mac avec Vision (RecognizeTextRequest, niveau précis, langues fr et en, détection automatique ; pour un PDF, chaque page rendue en image à 200 dpi puis reconnue, pages séparées par une ligne vide). Pendant le traitement : « Reconnaissance du texte… » avec indicateur d'activité ; le résultat devient le document joint, comme un .txt, badge « <nom> (texte reconnu, N jetons) ». Si rien n'est reconnu : « Aucun texte reconnu dans ce fichier. » Mets à jour la ligne « Fichiers acceptés », le message du PDF scanné, SPEC.md, README. Autotest : générer en mémoire une image contenant trois lignes de texte français et vérifier que le modèle en restitue un mot. Version : ajoute « + lecture d'images » à la version affichée. Un commit par étape, autotest depuis Terminal.app.
"""#
    static let webRequest = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute un bouton « Joindre une page web… » à côté de « Joindre un fichier… » : une fenêtre demande une adresse http(s) ; FM Mini la télécharge (URLSession, 15 s, 5 Mo maximum), convertit le HTML en texte (NSAttributedString html → string, puis lignes vides réduites), et l'ajoute comme document nommé par le titre de la page, badge « <titre> (page web, N jetons) ». Le document trop long passe par le découpage existant. Erreurs en ligne : « Adresse injoignable. », « Cette page ne contient pas de texte lisible. ». Mets à jour SPEC.md (section PRIVACY : cette fonction est l'unique appel réseau, uniquement vers l'adresse saisie) et README. Autotest : vérifier que sans utiliser cette fonction aucun socket n'est ouvert (lsof), et que la fonction convertit un HTML construit en mémoire. Version : ajoute « + pages web ». Un commit par étape, autotest depuis Terminal.app.
"""#
    static let folderRequest = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute un bouton « Choisir un dossier… » : la session reçoit deux outils FoundationModels (protocole Tool) limités à ce dossier : listerFichiers() → noms et tailles des fichiers .txt .md .csv .json .rtf .docx .pdf (sous-dossiers compris, 200 au plus) ; lireFichier(nom) → texte du fichier par le lecteur existant, tronqué à 3 000 mots avec la mention « (suite coupée) ». Sans macro : les Arguments de chaque outil sont écrits à la main (ConvertibleFromGeneratedContent + GenerationSchema statique). Badge « dossier : <nom> (N fichiers) ». Consigne ajoutée pour la session avec dossier : « Pour répondre sur les fichiers, commence par listerFichiers, puis lis seulement ceux qui sont utiles. » Erreurs en ligne. Mets à jour SPEC.md et README. Autotest : dossier temporaire en mémoire impossible → créer trois fichiers dans un dossier sous $TMPDIR, poser une question dont la réponse est dans le deuxième, vérifier l'appel des deux outils, supprimer le dossier. Version : ajoute « + dossier ». Un commit par étape, autotest depuis Terminal.app.
"""#

    static let sections = [
        FurtherSection(title: "Déjà sur votre Mac", cards: [
            FurtherCard(id: "dictation", title: "Parler au lieu de taper", benefit: "dictez votre message dans la zone de saisie ; la dictée du Mac fonctionne dans FM Mini sans réglage particulier.", data: "restent sur le Mac.", action: .dictation),
            FurtherCard(id: "shortcuts", title: "Automatiser avec Raccourcis", benefit: "l'action « Utiliser le modèle » de Raccourcis fait appel au même modèle que FM Mini : résumer chaque mail reçu, renommer les fichiers déposés dans un dossier, traduire une sélection — sans ouvrir FM Mini.", data: "restent sur le Mac.", action: .shortcuts),
            FurtherCard(id: "terminal", title: "L'utiliser depuis le Terminal et d'autres apps", benefit: "la commande fm répond en ligne de commande (fm respond \"votre question\") ; fm serve ouvre une porte locale compatible OpenAI (127.0.0.1:1976) pour les apps qui savent parler à ChatGPT.", data: "restent sur le Mac.", action: .terminal)
        ]),
        FurtherSection(title: "À ajouter à FM Mini avec votre assistant", cards: [
            FurtherCard(id: "images", title: "Lire des images et des scans", benefit: "joindre une photo, une capture d'écran ou un PDF scanné ; le texte est reconnu par le Mac puis donné au modèle.", data: "restent sur le Mac.", action: .copy(imageRequest)),
            FurtherCard(id: "web", title: "Lire une page web", benefit: "collez l'adresse d'une page ; FM Mini en récupère le texte et l'ajoute comme document.", data: "l'adresse de la page est envoyée sur internet pour la télécharger — c'est la seule exception à « tout reste sur le Mac » ; le reste de la conversation ne sort pas.", action: .copy(webRequest)),
            FurtherCard(id: "folder", title: "Interroger un dossier de documents", benefit: "choisissez un dossier ; le modèle peut lister ses fichiers texte et lire celui dont il a besoin pour répondre.", data: "restent sur le Mac.", action: .copy(folderRequest))
        ])
    ]

    static var cards: [FurtherCard] { sections.flatMap(\.cards) }
}

struct InstallationView: View {
    @Local private var copiedCardID: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("FM Mini fait exprès peu de choses. Voici ce que vous pouvez lui faire faire en plus — soit avec ce que votre Mac a déjà, soit en demandant à votre assistant de programmation (Claude Code, Codex…) de l'ajouter : le bouton « Copier la demande » met dans le presse-papiers un texte prêt à coller.")
                    .font(.callout).foregroundStyle(Color(red: 0.28, green: 0.28, blue: 0.30)).fixedSize(horizontal: false, vertical: true)
                ForEach(FurtherWindowContent.sections) { section in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(section.title).font(.headline)
                        ForEach(section.cards) { card in
                            FurtherCardView(card: card, copied: copiedCardID == card.id) { perform(card.action, cardID: card.id) }
                        }
                    }
                }
                Text("Rien n'est installé ni téléchargé par cette fenêtre : elle ouvre des apps déjà présentes ou copie du texte.")
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
    let card: FurtherCard
    let copied: Bool
    let action: () -> Void

    private var buttonTitle: String {
        if copied { return "Copié" }
        switch card.action {
        case .dictation: return "Ouvrir les réglages de la dictée"
        case .shortcuts: return "Ouvrir Raccourcis"
        case .terminal: return "Ouvrir le Terminal"
        case .copy: return "Copier la demande"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(card.title).font(.subheadline.weight(.bold))
            Text("Ce que ça apporte : \(card.benefit)").font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("Vos données : \(card.data)").font(.caption).foregroundStyle(Personnalisation.grisTexteSecondaire).fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action).controlSize(.small)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.18), lineWidth: 1))
    }
}
