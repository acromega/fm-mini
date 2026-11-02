// Pour corriger une traduction : modifiez le texte entre guillemets, relancez ./make-app.sh.
//
// Chaque langue a exactement les mêmes clés (enum Cle). Les « %@ » sont remplacés par des valeurs
// à l'exécution ; gardez-les dans le même ordre. « COUNT » est remplacé par le nombre de langues.

import Foundation

enum Langue: String, CaseIterable, Identifiable {
    case fr, en, es, de, it, pt

    var id: String { rawValue }

    /// Nom de la langue, écrit dans la langue elle-même (menu Présentation → Langue).
    var nomNatif: String {
        switch self {
        case .fr: "Français"
        case .en: "English"
        case .es: "Español"
        case .de: "Deutsch"
        case .it: "Italiano"
        case .pt: "Português"
        }
    }

    /// Locale utilisée pour les nombres et les noms de langues du menu de traduction.
    var locale: Locale {
        switch self {
        case .fr: Locale(identifier: "fr_FR")
        case .en: Locale(identifier: "en_US")
        case .es: Locale(identifier: "es_ES")
        case .de: Locale(identifier: "de_DE")
        case .it: Locale(identifier: "it_IT")
        case .pt: Locale(identifier: "pt_BR")
        }
    }

    /// Première langue des préférences du Mac présente dans l'enum, sinon l'anglais.
    static func automatique() -> Langue {
        for identifier in Locale.preferredLanguages {
            let code = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { String($0).lowercased() } ?? ""
            if let langue = Langue(rawValue: code) { return langue }
        }
        return .en
    }

    func texte(_ cle: Cle) -> String {
        Textes.tous[self]?[cle] ?? Textes.tous[.fr]?[cle] ?? cle.rawValue
    }

    func texte(_ cle: Cle, _ arguments: CVarArg...) -> String {
        String(format: texte(cle), locale: locale, arguments: arguments)
    }
}

/// Langue par défaut choisie dans Personnalisation.swift : `.auto` suit le Mac, `.fixe(.en)` impose une langue.
enum ChoixLangue: Equatable {
    case auto
    case fixe(Langue)
}

enum Cle: String, CaseIterable {
    // Accueil
    case titreAccueil, paragrapheAccueil
    case puceResume, puceCorrection, puceQuiz, puceExtraction, puceTraductionLibelle, puceTraductionTexte
    case lienAllerPlusLoin, aucuneLangueDisponible
    // En-tête et jauge
    case nouvelleConversation, jeton, jetons, conversationPresquePleine
    // Saisie
    case boutonAjouterPJ, aidePJ, badgePJ, retirerFichier, analyseDocument, envoyer, reponseEnCours, champMessage, choisirDocument
    // Bulles
    case copier, copie, nouvelleConversationGardantDocument
    // Modèle indisponible
    case modeleIndisponible, ouvrirReglagesSysteme, raisonInconnue
    // Messages d'erreur
    case partieTropLongue, nouvellePartieChargee, fenetreContexteInconnue, conversationPleine
    case gardeFous, conversationTropLongue, langueNonPriseEnCharge
    case fichierTropLourd, fichierVide, pdfSansTexte, texteNonUTF8, documentEndommage
    // Découpage et compression
    case documentDecoupe, libellePartie, phraseTresLongueCoupee, nomPartie, documentSansNom
    case conversationCompressee, documentConserve, langueChangee
    // Consigne et textes envoyés au modèle
    case consigneModele, promptDocument, promptCompression, resumeEchangesPrecedents, documentCharge
    // Menus
    case menuFichier, menuEdition, menuPresentation, menuFenetre, menuAide, menuLangue
    case fermer, quitter, masquer, masquerLesAutres, toutAfficher
    case annuler, retablir, couper, coller, supprimer, toutSelectionner, copierDerniereReponse
    case minimiser, pleinEcran, aideFMMini, allerPlusLoinMenu, aProposDeFMMini
    // Fenêtres « Aller plus loin » et « À propos »
    case titreAllerPlusLoin, titreAPropos, aProposTourne, iconeFMMini
    case introAllerPlusLoin, sectionDejaSurMac, sectionAAjouter, ceQueCaApporte, vosDonnees
    case ouvrirReglagesDictee, ouvrirRaccourcis, ouvrirTerminal, copierDemande, piedAllerPlusLoin, demandeEnAnglais
    case donneesRestentSurMac
    case carteDicteeTitre, carteDicteeApport
    case carteRaccourcisTitre, carteRaccourcisApport
    case carteTerminalTitre, carteTerminalApport
    case carteImagesTitre, carteImagesApport
    case carteWebTitre, carteWebApport, carteWebDonnees
    case carteDossierTitre, carteDossierApport
    case demandeImages, demandeWeb, demandeDossier
}

enum Textes {
    static let tous: [Langue: [Cle: String]] = [.fr: fr, .en: en, .es: es, .de: de, .it: it, .pt: pt]

    // Demandes prêtes à coller pour un assistant (fenêtre « Aller plus loin »). Version française, puis anglaise.
    static let demandeImagesFR = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute la reconnaissance de texte : « Ajouter une PJ… » accepte aussi png, jpg, jpeg, heic, tiff, et les PDF sans texte ne sont plus refusés. Le texte est extrait sur le Mac avec Vision (RecognizeTextRequest, niveau précis, langues fr et en, détection automatique ; pour un PDF, chaque page rendue en image à 200 dpi puis reconnue, pages séparées par une ligne vide). Pendant le traitement : « Reconnaissance du texte… » avec indicateur d'activité ; le résultat devient le document joint, comme un .txt, badge « <nom> (texte reconnu, N jetons) ». Si rien n'est reconnu : « Aucun texte reconnu dans ce fichier. » Mets à jour la ligne « PJ acceptées », le message du PDF scanné, SPEC.md, README. Autotest : générer en mémoire une image contenant trois lignes de texte français et vérifier que le modèle en restitue un mot. Version : ajoute « + lecture d'images » à la version affichée. Un commit par étape, autotest depuis Terminal.app.
"""#
    static let demandeWebFR = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute un bouton « Joindre une page web… » à côté de « Ajouter une PJ… » : une fenêtre demande une adresse http(s) ; FM Mini la télécharge (URLSession, 15 s, 5 Mo maximum), convertit le HTML en texte (NSAttributedString html → string, puis lignes vides réduites), et l'ajoute comme document nommé par le titre de la page, badge « <titre> (page web, N jetons) ». Le document trop long passe par le découpage existant. Erreurs en ligne : « Adresse injoignable. », « Cette page ne contient pas de texte lisible. ». Mets à jour SPEC.md (section PRIVACY : cette fonction est l'unique appel réseau, uniquement vers l'adresse saisie) et README. Autotest : vérifier que sans utiliser cette fonction aucun socket n'est ouvert (lsof), et que la fonction convertit un HTML construit en mémoire. Version : ajoute « + pages web ». Un commit par étape, autotest depuis Terminal.app.
"""#
    static let demandeDossierFR = #"""
Dans ~/fm-mini, lis POUR-LES-ASSISTANTS.md puis SPEC.md. Ajoute un bouton « Choisir un dossier… » : la session reçoit deux outils FoundationModels (protocole Tool) limités à ce dossier : listerFichiers() → noms et tailles des fichiers .txt .md .csv .json .rtf .docx .pdf (sous-dossiers compris, 200 au plus) ; lireFichier(nom) → texte du fichier par le lecteur existant, tronqué à 3 000 mots avec la mention « (suite coupée) ». Sans macro : les Arguments de chaque outil sont écrits à la main (ConvertibleFromGeneratedContent + GenerationSchema statique). Badge « dossier : <nom> (N fichiers) ». Consigne ajoutée pour la session avec dossier : « Pour répondre sur les fichiers, commence par listerFichiers, puis lis seulement ceux qui sont utiles. » Erreurs en ligne. Mets à jour SPEC.md et README. Autotest : dossier temporaire en mémoire impossible → créer trois fichiers dans un dossier sous $TMPDIR, poser une question dont la réponse est dans le deuxième, vérifier l'appel des deux outils, supprimer le dossier. Version : ajoute « + dossier ». Un commit par étape, autotest depuis Terminal.app.
"""#

    static let fr: [Cle: String] = [
        .titreAccueil: "BONJOUR, QUE PUIS-JE FAIRE POUR VOUS ?",
        .paragrapheAccueil: "Je suis gratuit et je travaille localement sur votre Mac, sans jamais transférer vos documents dans le cloud. Je suis spécialisé dans le traitement du texte en COUNT langues (dont le français) : je sais résumer, corriger, analyser, reformuler, traduire et extraire des informations de la plupart des textes que vous me confierez. En revanche, je ne connais pas l'actualité et mes connaissances encyclopédiques sont très limitées. Essayez-moi !",
        .puceResume: "Résume la PJ en 200 mots environ.",
        .puceCorrection: "Corrige l'orthographe et la grammaire de la PJ, en gardant le sens.",
        .puceQuiz: "Crée un quiz de cinq questions à partir de la PJ, avec les réponses.",
        .puceExtraction: "Extrais les noms, dates et chiffres de la PJ.",
        .puceTraductionLibelle: "Traduire la PJ en…",
        .puceTraductionTexte: "Traduis la PJ en %@.",
        .lienAllerPlusLoin: "Aller plus loin →",
        .aucuneLangueDisponible: "Aucune langue disponible",
        .nouvelleConversation: "Nouvelle conversation",
        .jeton: "jeton",
        .jetons: "jetons",
        .conversationPresquePleine: "Conversation presque pleine.",
        .boutonAjouterPJ: "Ajouter une PJ…",
        .aidePJ: "PJ acceptées : .txt .md .csv .json .rtf .docx .pdf (texte, pas de scan) — jusqu'à environ %@ mots",
        .badgePJ: "PJ : %@ (%@)",
        .retirerFichier: "Retirer le fichier",
        .analyseDocument: "Analyse du document…",
        .envoyer: "Envoyer",
        .reponseEnCours: "Réponse…",
        .champMessage: "Message",
        .choisirDocument: "Choisissez un document texte",
        .copier: "Copier",
        .copie: "Copié",
        .nouvelleConversationGardantDocument: "Nouvelle conversation en gardant le document",
        .modeleIndisponible: "Le modèle Apple n’est pas disponible : %@",
        .ouvrirReglagesSysteme: "Ouvrir Réglages Système",
        .raisonInconnue: "Raison inconnue",
        .partieTropLongue: "Cette partie reste trop longue pour la fenêtre du modèle.",
        .nouvellePartieChargee: "Nouvelle partie chargée : la conversation a été réinitialisée.",
        .fenetreContexteInconnue: "Impossible de connaître la fenêtre de contexte du modèle.",
        .conversationPleine: "La conversation est pleine (%@).",
        .gardeFous: "Les garde-fous d’Apple ont bloqué cette réponse.",
        .conversationTropLongue: "La conversation est trop longue pour le modèle : cliquez sur Nouvelle conversation.",
        .langueNonPriseEnCharge: "Langue non prise en charge.",
        .fichierTropLourd: "Fichier trop lourd (%@ Mo, maximum 5 Mo)",
        .fichierVide: "Ce fichier est vide.",
        .pdfSansTexte: "Ce PDF ne contient pas de texte lisible (scan) : il faudrait d’abord le passer par la reconnaissance de texte.",
        .texteNonUTF8: "Le fichier doit être du texte UTF-8 lisible.",
        .documentEndommage: "Ce fichier est illisible (document endommagé ?).",
        .documentDecoupe: "Ce document fait %@ mots (%@). Je ne peux lire qu’environ %@ mots à la fois — c’est la limite de mémoire du modèle, pas un bogue. Je l’ai découpé en %@ parties ; choisissez celle à charger, ou posez votre question partie par partie.",
        .libellePartie: "Partie %@/%@ — mots %@ à %@ — « %@ »",
        .phraseTresLongueCoupee: "(phrase très longue coupée)",
        .nomPartie: "%@ — partie %@/%@",
        .documentSansNom: "document",
        .conversationCompressee: "Conversation compressée : %@ → %@%@",
        .documentConserve: " (le document est conservé en entier).",
        .langueChangee: "Langue changée : les réponses suivantes seront en français.",
        .consigneModele: "Tu es un assistant. Tu réponds toujours en français, quelle que soit la langue du message. Tu vouvoies la personne.",
        .promptDocument: "Réponds uniquement à partir du document ci-dessous.\n\nDocument « %@ » :\n%@\n\nQuestion : %@",
        .promptCompression: "Résume en moins de 200 mots les questions posées et les réponses données, en gardant les faits, chiffres et noms exacts. Ne résume pas le document lui-même.",
        .resumeEchangesPrecedents: "Résumé des échanges précédents :",
        .documentCharge: "Document chargé.",
        .menuFichier: "Fichier",
        .menuEdition: "Édition",
        .menuPresentation: "Présentation",
        .menuFenetre: "Fenêtre",
        .menuAide: "Aide",
        .menuLangue: "Langue",
        .fermer: "Fermer",
        .quitter: "Quitter FM Mini",
        .masquer: "Masquer FM Mini",
        .masquerLesAutres: "Masquer les autres",
        .toutAfficher: "Tout afficher",
        .annuler: "Annuler",
        .retablir: "Rétablir",
        .couper: "Couper",
        .coller: "Coller",
        .supprimer: "Supprimer",
        .toutSelectionner: "Tout sélectionner",
        .copierDerniereReponse: "Copier la dernière réponse",
        .minimiser: "Minimiser",
        .pleinEcran: "Activer le mode plein écran",
        .aideFMMini: "Aide FM Mini",
        .allerPlusLoinMenu: "Aller plus loin…",
        .aProposDeFMMini: "À propos de FM Mini",
        .titreAllerPlusLoin: "Aller plus loin",
        .titreAPropos: "À propos",
        .aProposTourne: "Tourne entièrement sur votre Mac avec le modèle Apple Foundation Models.",
        .iconeFMMini: "Icône FM Mini",
        .introAllerPlusLoin: "FM Mini fait exprès peu de choses. Voici ce que vous pouvez lui faire faire en plus — soit avec ce que votre Mac a déjà, soit en demandant à votre assistant de programmation (Claude Code, Codex…) de l'ajouter : le bouton « Copier la demande » met dans le presse-papiers un texte prêt à coller.",
        .sectionDejaSurMac: "Déjà sur votre Mac",
        .sectionAAjouter: "À ajouter à FM Mini avec votre assistant",
        .ceQueCaApporte: "Ce que ça apporte : %@",
        .vosDonnees: "Vos données : %@",
        .ouvrirReglagesDictee: "Ouvrir les réglages de la dictée",
        .ouvrirRaccourcis: "Ouvrir Raccourcis",
        .ouvrirTerminal: "Ouvrir le Terminal",
        .copierDemande: "Copier la demande",
        .piedAllerPlusLoin: "Rien n'est installé ni téléchargé par cette fenêtre : elle ouvre des apps déjà présentes ou copie du texte.",
        .demandeEnAnglais: "(demande en anglais)",
        .donneesRestentSurMac: "restent sur le Mac.",
        .carteDicteeTitre: "Parler au lieu de taper",
        .carteDicteeApport: "dictez votre message dans la zone de saisie ; la dictée du Mac fonctionne dans FM Mini sans réglage particulier.",
        .carteRaccourcisTitre: "Automatiser avec Raccourcis",
        .carteRaccourcisApport: "l'action « Utiliser le modèle » de Raccourcis fait appel au même modèle que FM Mini : résumer chaque mail reçu, renommer les fichiers déposés dans un dossier, traduire une sélection — sans ouvrir FM Mini.",
        .carteTerminalTitre: "L'utiliser depuis le Terminal et d'autres apps",
        .carteTerminalApport: "la commande fm répond en ligne de commande (fm respond \"votre question\") ; fm serve ouvre une porte locale compatible OpenAI (127.0.0.1:1976) pour les apps qui savent parler à ChatGPT.",
        .carteImagesTitre: "Lire des images et des scans",
        .carteImagesApport: "joindre une photo, une capture d'écran ou un PDF scanné ; le texte est reconnu par le Mac puis donné au modèle.",
        .carteWebTitre: "Lire une page web",
        .carteWebApport: "collez l'adresse d'une page ; FM Mini en récupère le texte et l'ajoute comme document.",
        .carteWebDonnees: "l'adresse de la page est envoyée sur internet pour la télécharger — c'est la seule exception à « tout reste sur le Mac » ; le reste de la conversation ne sort pas.",
        .carteDossierTitre: "Interroger un dossier de documents",
        .carteDossierApport: "choisissez un dossier ; le modèle peut lister ses fichiers texte et lire celui dont il a besoin pour répondre.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]

    static let en: [Cle: String] = [
        .titreAccueil: "HELLO, WHAT CAN I DO FOR YOU?",
        .paragrapheAccueil: "I'm free and I run entirely on your Mac, without ever sending your documents to the cloud. I specialize in working with text in COUNT languages (including English): I can summarize, proofread, analyze, rewrite, translate and pull facts out of most texts you give me. On the other hand, I know nothing about current events and very little by heart. Try me!",
        .puceResume: "Summarize the attachment in about 200 words.",
        .puceCorrection: "Correct the spelling and grammar of the attachment, keeping the meaning.",
        .puceQuiz: "Create a five-question quiz from the attachment, with the answers.",
        .puceExtraction: "Extract the names, dates and figures from the attachment.",
        .puceTraductionLibelle: "Translate into…",
        .puceTraductionTexte: "Translate the attachment into %@.",
        .lienAllerPlusLoin: "Go further →",
        .aucuneLangueDisponible: "No language available",
        .nouvelleConversation: "New conversation",
        .jeton: "token",
        .jetons: "tokens",
        .conversationPresquePleine: "Conversation almost full.",
        .boutonAjouterPJ: "Add an attachment…",
        .aidePJ: "Accepted attachments: .txt .md .csv .json .rtf .docx .pdf (text, not scans) — up to about %@ words",
        .badgePJ: "Attachment: %@ (%@)",
        .retirerFichier: "Remove the file",
        .analyseDocument: "Analyzing the document…",
        .envoyer: "Send",
        .reponseEnCours: "Answering…",
        .champMessage: "Message",
        .choisirDocument: "Choose a text document",
        .copier: "Copy",
        .copie: "Copied",
        .nouvelleConversationGardantDocument: "New conversation keeping the document",
        .modeleIndisponible: "The Apple model is not available: %@",
        .ouvrirReglagesSysteme: "Open System Settings",
        .raisonInconnue: "Unknown reason",
        .partieTropLongue: "This part is still too long for the model's window.",
        .nouvellePartieChargee: "New part loaded: the conversation has been reset.",
        .fenetreContexteInconnue: "Unable to determine the model's context window.",
        .conversationPleine: "The conversation is full (%@).",
        .gardeFous: "Apple's guardrails blocked this answer.",
        .conversationTropLongue: "The conversation is too long for the model: click New conversation.",
        .langueNonPriseEnCharge: "Language not supported.",
        .fichierTropLourd: "File too large (%@ MB, maximum 5 MB)",
        .fichierVide: "This file is empty.",
        .pdfSansTexte: "This PDF contains no readable text (scan): it would first need to go through text recognition.",
        .texteNonUTF8: "The file must be readable UTF-8 text.",
        .documentEndommage: "This file is unreadable (damaged document?).",
        .documentDecoupe: "This document is %@ words long (%@). I can only read about %@ words at a time — that is the model's memory limit, not a bug. I split it into %@ parts; choose the one to load, or ask your question part by part.",
        .libellePartie: "Part %@/%@ — words %@ to %@ — “%@”",
        .phraseTresLongueCoupee: "(very long sentence cut)",
        .nomPartie: "%@ — part %@/%@",
        .documentSansNom: "document",
        .conversationCompressee: "Conversation compressed: %@ → %@%@",
        .documentConserve: " (the document is kept in full).",
        .langueChangee: "Language changed: the next answers will be in English.",
        .consigneModele: "You are an assistant. You always answer in English, whatever the language of the message. You address the person politely.",
        .promptDocument: "Answer only from the document below.\n\nDocument “%@”:\n%@\n\nQuestion: %@",
        .promptCompression: "Summarize in under 200 words the questions asked and the answers given, keeping the exact facts, figures and names. Do not summarize the document itself.",
        .resumeEchangesPrecedents: "Summary of the previous exchanges:",
        .documentCharge: "Document loaded.",
        .menuFichier: "File",
        .menuEdition: "Edit",
        .menuPresentation: "View",
        .menuFenetre: "Window",
        .menuAide: "Help",
        .menuLangue: "Language",
        .fermer: "Close",
        .quitter: "Quit FM Mini",
        .masquer: "Hide FM Mini",
        .masquerLesAutres: "Hide Others",
        .toutAfficher: "Show All",
        .annuler: "Undo",
        .retablir: "Redo",
        .couper: "Cut",
        .coller: "Paste",
        .supprimer: "Delete",
        .toutSelectionner: "Select All",
        .copierDerniereReponse: "Copy Last Answer",
        .minimiser: "Minimize",
        .pleinEcran: "Enter Full Screen",
        .aideFMMini: "FM Mini Help",
        .allerPlusLoinMenu: "Go further…",
        .aProposDeFMMini: "About FM Mini",
        .titreAllerPlusLoin: "Go further",
        .titreAPropos: "About",
        .aProposTourne: "Runs entirely on your Mac with the Apple Foundation Models model.",
        .iconeFMMini: "FM Mini icon",
        .introAllerPlusLoin: "FM Mini deliberately does few things. Here is what you can get it to do on top — either with what your Mac already has, or by asking your coding assistant (Claude Code, Codex…) to add it: the “Copy the request” button puts a ready-to-paste text on the clipboard.",
        .sectionDejaSurMac: "Already on your Mac",
        .sectionAAjouter: "To add to FM Mini with your assistant",
        .ceQueCaApporte: "What it brings: %@",
        .vosDonnees: "Your data: %@",
        .ouvrirReglagesDictee: "Open dictation settings",
        .ouvrirRaccourcis: "Open Shortcuts",
        .ouvrirTerminal: "Open Terminal",
        .copierDemande: "Copy the request",
        .piedAllerPlusLoin: "Nothing is installed or downloaded by this window: it opens apps already present or copies text.",
        .demandeEnAnglais: "(request in English)",
        .donneesRestentSurMac: "stay on the Mac.",
        .carteDicteeTitre: "Speak instead of typing",
        .carteDicteeApport: "dictate your message in the input field; the Mac's dictation works in FM Mini without any special setting.",
        .carteRaccourcisTitre: "Automate with Shortcuts",
        .carteRaccourcisApport: "the “Use Model” action in Shortcuts calls the same model as FM Mini: summarize each incoming email, rename files dropped into a folder, translate a selection — without opening FM Mini.",
        .carteTerminalTitre: "Use it from Terminal and other apps",
        .carteTerminalApport: "the fm command answers on the command line (fm respond \"your question\"); fm serve opens a local OpenAI-compatible door (127.0.0.1:1976) for apps that know how to talk to ChatGPT.",
        .carteImagesTitre: "Read images and scans",
        .carteImagesApport: "attach a photo, a screenshot or a scanned PDF; the text is recognized by the Mac and then given to the model.",
        .carteWebTitre: "Read a web page",
        .carteWebApport: "paste a page's address; FM Mini fetches its text and adds it as a document.",
        .carteWebDonnees: "the page's address is sent over the internet to download it — the only exception to “everything stays on the Mac”; the rest of the conversation does not leave.",
        .carteDossierTitre: "Query a folder of documents",
        .carteDossierApport: "choose a folder; the model can list its text files and read the one it needs to answer.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]

    static let es: [Cle: String] = [
        .titreAccueil: "HOLA, ¿QUÉ PUEDO HACER POR USTED?",
        .paragrapheAccueil: "Soy gratuito y trabajo localmente en su Mac, sin enviar nunca sus documentos a la nube. Estoy especializado en el tratamiento de texto en COUNT idiomas (incluido el español): sé resumir, corregir, analizar, reformular, traducir y extraer información de la mayoría de los textos que me confíe. En cambio, no conozco la actualidad y mis conocimientos enciclopédicos son muy limitados. ¡Pruébeme!",
        .puceResume: "Resume el adjunto en unas 200 palabras.",
        .puceCorrection: "Corrige la ortografía y la gramática del adjunto, conservando el sentido.",
        .puceQuiz: "Crea un cuestionario de cinco preguntas a partir del adjunto, con las respuestas.",
        .puceExtraction: "Extrae los nombres, fechas y cifras del adjunto.",
        .puceTraductionLibelle: "Traducir al…",
        .puceTraductionTexte: "Traduce el adjunto al %@.",
        .lienAllerPlusLoin: "Ir más lejos →",
        .aucuneLangueDisponible: "Ningún idioma disponible",
        .nouvelleConversation: "Nueva conversación",
        .jeton: "token",
        .jetons: "tokens",
        .conversationPresquePleine: "Conversación casi llena.",
        .boutonAjouterPJ: "Añadir un adjunto…",
        .aidePJ: "Adjuntos aceptados: .txt .md .csv .json .rtf .docx .pdf (texto, no escaneos) — hasta unas %@ palabras",
        .badgePJ: "Adjunto: %@ (%@)",
        .retirerFichier: "Quitar el archivo",
        .analyseDocument: "Analizando el documento…",
        .envoyer: "Enviar",
        .reponseEnCours: "Respondiendo…",
        .champMessage: "Mensaje",
        .choisirDocument: "Elija un documento de texto",
        .copier: "Copiar",
        .copie: "Copiado",
        .nouvelleConversationGardantDocument: "Nueva conversación conservando el documento",
        .modeleIndisponible: "El modelo de Apple no está disponible: %@",
        .ouvrirReglagesSysteme: "Abrir Ajustes del Sistema",
        .raisonInconnue: "Motivo desconocido",
        .partieTropLongue: "Esta parte sigue siendo demasiado larga para la ventana del modelo.",
        .nouvellePartieChargee: "Nueva parte cargada: la conversación se ha reiniciado.",
        .fenetreContexteInconnue: "No se puede conocer la ventana de contexto del modelo.",
        .conversationPleine: "La conversación está llena (%@).",
        .gardeFous: "Las salvaguardas de Apple han bloqueado esta respuesta.",
        .conversationTropLongue: "La conversación es demasiado larga para el modelo: haga clic en Nueva conversación.",
        .langueNonPriseEnCharge: "Idioma no admitido.",
        .fichierTropLourd: "Archivo demasiado grande (%@ MB, máximo 5 MB)",
        .fichierVide: "Este archivo está vacío.",
        .pdfSansTexte: "Este PDF no contiene texto legible (escaneo): primero habría que pasarlo por el reconocimiento de texto.",
        .texteNonUTF8: "El archivo debe ser texto UTF-8 legible.",
        .documentEndommage: "Este archivo es ilegible (¿documento dañado?).",
        .documentDecoupe: "Este documento tiene %@ palabras (%@). Solo puedo leer unas %@ palabras a la vez: es el límite de memoria del modelo, no un error. Lo he dividido en %@ partes; elija la que desea cargar, o haga su pregunta parte por parte.",
        .libellePartie: "Parte %@/%@ — palabras %@ a %@ — «%@»",
        .phraseTresLongueCoupee: "(frase muy larga cortada)",
        .nomPartie: "%@ — parte %@/%@",
        .documentSansNom: "documento",
        .conversationCompressee: "Conversación comprimida: %@ → %@%@",
        .documentConserve: " (el documento se conserva entero).",
        .langueChangee: "Idioma cambiado: las próximas respuestas serán en español.",
        .consigneModele: "Eres un asistente. Respondes siempre en español, sea cual sea el idioma del mensaje. Tratas a la persona de usted.",
        .promptDocument: "Responde únicamente a partir del documento siguiente.\n\nDocumento «%@»:\n%@\n\nPregunta: %@",
        .promptCompression: "Resume en menos de 200 palabras las preguntas planteadas y las respuestas dadas, conservando los hechos, cifras y nombres exactos. No resumas el documento en sí.",
        .resumeEchangesPrecedents: "Resumen de los intercambios anteriores:",
        .documentCharge: "Documento cargado.",
        .menuFichier: "Archivo",
        .menuEdition: "Edición",
        .menuPresentation: "Visualización",
        .menuFenetre: "Ventana",
        .menuAide: "Ayuda",
        .menuLangue: "Idioma",
        .fermer: "Cerrar",
        .quitter: "Salir de FM Mini",
        .masquer: "Ocultar FM Mini",
        .masquerLesAutres: "Ocultar otros",
        .toutAfficher: "Mostrar todo",
        .annuler: "Deshacer",
        .retablir: "Rehacer",
        .couper: "Cortar",
        .coller: "Pegar",
        .supprimer: "Eliminar",
        .toutSelectionner: "Seleccionar todo",
        .copierDerniereReponse: "Copiar la última respuesta",
        .minimiser: "Minimizar",
        .pleinEcran: "Usar pantalla completa",
        .aideFMMini: "Ayuda de FM Mini",
        .allerPlusLoinMenu: "Ir más lejos…",
        .aProposDeFMMini: "Acerca de FM Mini",
        .titreAllerPlusLoin: "Ir más lejos",
        .titreAPropos: "Acerca de",
        .aProposTourne: "Funciona íntegramente en su Mac con el modelo Apple Foundation Models.",
        .iconeFMMini: "Icono de FM Mini",
        .introAllerPlusLoin: "FM Mini hace pocas cosas a propósito. Esto es lo que puede hacerle hacer además, ya sea con lo que su Mac ya tiene, o pidiéndole a su asistente de programación (Claude Code, Codex…) que lo añada: el botón «Copiar la solicitud» pone en el portapapeles un texto listo para pegar.",
        .sectionDejaSurMac: "Ya en su Mac",
        .sectionAAjouter: "Para añadir a FM Mini con su asistente",
        .ceQueCaApporte: "Qué aporta: %@",
        .vosDonnees: "Sus datos: %@",
        .ouvrirReglagesDictee: "Abrir los ajustes de dictado",
        .ouvrirRaccourcis: "Abrir Atajos",
        .ouvrirTerminal: "Abrir Terminal",
        .copierDemande: "Copiar la solicitud",
        .piedAllerPlusLoin: "Esta ventana no instala ni descarga nada: abre apps ya presentes o copia texto.",
        .demandeEnAnglais: "(solicitud en inglés)",
        .donneesRestentSurMac: "se quedan en el Mac.",
        .carteDicteeTitre: "Hablar en lugar de escribir",
        .carteDicteeApport: "dicte su mensaje en el campo de texto; el dictado del Mac funciona en FM Mini sin ningún ajuste especial.",
        .carteRaccourcisTitre: "Automatizar con Atajos",
        .carteRaccourcisApport: "la acción «Usar modelo» de Atajos recurre al mismo modelo que FM Mini: resumir cada correo recibido, renombrar los archivos depositados en una carpeta, traducir una selección, sin abrir FM Mini.",
        .carteTerminalTitre: "Usarlo desde Terminal y otras apps",
        .carteTerminalApport: "el comando fm responde en la línea de comandos (fm respond \"su pregunta\"); fm serve abre una puerta local compatible con OpenAI (127.0.0.1:1976) para las apps que saben hablar con ChatGPT.",
        .carteImagesTitre: "Leer imágenes y escaneos",
        .carteImagesApport: "adjuntar una foto, una captura de pantalla o un PDF escaneado; el Mac reconoce el texto y se lo pasa al modelo.",
        .carteWebTitre: "Leer una página web",
        .carteWebApport: "pegue la dirección de una página; FM Mini recupera su texto y lo añade como documento.",
        .carteWebDonnees: "la dirección de la página se envía por internet para descargarla: es la única excepción a «todo se queda en el Mac»; el resto de la conversación no sale.",
        .carteDossierTitre: "Consultar una carpeta de documentos",
        .carteDossierApport: "elija una carpeta; el modelo puede listar sus archivos de texto y leer el que necesite para responder.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]

    static let de: [Cle: String] = [
        .titreAccueil: "HALLO, WAS KANN ICH FÜR SIE TUN?",
        .paragrapheAccueil: "Ich bin kostenlos und arbeite lokal auf Ihrem Mac, ohne Ihre Dokumente jemals in die Cloud zu übertragen. Ich bin auf die Verarbeitung von Text in COUNT Sprachen (darunter Deutsch) spezialisiert: Ich kann zusammenfassen, korrigieren, analysieren, umformulieren, übersetzen und Informationen aus den meisten Texten herausziehen, die Sie mir anvertrauen. Dagegen kenne ich das aktuelle Geschehen nicht, und mein enzyklopädisches Wissen ist sehr begrenzt. Probieren Sie mich aus!",
        .puceResume: "Fasse den Anhang in etwa 200 Wörtern zusammen.",
        .puceCorrection: "Korrigiere Rechtschreibung und Grammatik des Anhangs, ohne den Sinn zu verändern.",
        .puceQuiz: "Erstelle aus dem Anhang ein Quiz mit fünf Fragen, mit den Antworten.",
        .puceExtraction: "Extrahiere die Namen, Daten und Zahlen aus dem Anhang.",
        .puceTraductionLibelle: "Übersetzen auf…",
        .puceTraductionTexte: "Übersetze den Anhang auf %@.",
        .lienAllerPlusLoin: "Mehr erfahren →",
        .aucuneLangueDisponible: "Keine Sprache verfügbar",
        .nouvelleConversation: "Neue Unterhaltung",
        .jeton: "Token",
        .jetons: "Token",
        .conversationPresquePleine: "Unterhaltung fast voll.",
        .boutonAjouterPJ: "Anhang hinzufügen…",
        .aidePJ: "Zulässige Anhänge: .txt .md .csv .json .rtf .docx .pdf (Text, keine Scans) — bis etwa %@ Wörter",
        .badgePJ: "Anhang: %@ (%@)",
        .retirerFichier: "Datei entfernen",
        .analyseDocument: "Dokument wird analysiert…",
        .envoyer: "Senden",
        .reponseEnCours: "Antwort…",
        .champMessage: "Nachricht",
        .choisirDocument: "Wählen Sie ein Textdokument",
        .copier: "Kopieren",
        .copie: "Kopiert",
        .nouvelleConversationGardantDocument: "Neue Unterhaltung mit demselben Dokument",
        .modeleIndisponible: "Das Apple-Modell ist nicht verfügbar: %@",
        .ouvrirReglagesSysteme: "Systemeinstellungen öffnen",
        .raisonInconnue: "Unbekannter Grund",
        .partieTropLongue: "Dieser Teil ist immer noch zu lang für das Fenster des Modells.",
        .nouvellePartieChargee: "Neuer Teil geladen: Die Unterhaltung wurde zurückgesetzt.",
        .fenetreContexteInconnue: "Das Kontextfenster des Modells lässt sich nicht ermitteln.",
        .conversationPleine: "Die Unterhaltung ist voll (%@).",
        .gardeFous: "Die Schutzmechanismen von Apple haben diese Antwort blockiert.",
        .conversationTropLongue: "Die Unterhaltung ist zu lang für das Modell: Klicken Sie auf „Neue Unterhaltung“.",
        .langueNonPriseEnCharge: "Sprache nicht unterstützt.",
        .fichierTropLourd: "Datei zu groß (%@ MB, maximal 5 MB)",
        .fichierVide: "Diese Datei ist leer.",
        .pdfSansTexte: "Dieses PDF enthält keinen lesbaren Text (Scan): Es müsste zuerst durch eine Texterkennung laufen.",
        .texteNonUTF8: "Die Datei muss lesbarer UTF-8-Text sein.",
        .documentEndommage: "Diese Datei ist nicht lesbar (beschädigtes Dokument?).",
        .documentDecoupe: "Dieses Dokument hat %@ Wörter (%@). Ich kann nur etwa %@ Wörter auf einmal lesen — das ist die Speichergrenze des Modells, kein Fehler. Ich habe es in %@ Teile aufgeteilt; wählen Sie den zu ladenden Teil, oder stellen Sie Ihre Frage Teil für Teil.",
        .libellePartie: "Teil %@/%@ — Wörter %@ bis %@ — „%@“",
        .phraseTresLongueCoupee: "(sehr langer Satz geteilt)",
        .nomPartie: "%@ — Teil %@/%@",
        .documentSansNom: "Dokument",
        .conversationCompressee: "Unterhaltung komprimiert: %@ → %@%@",
        .documentConserve: " (das Dokument bleibt vollständig erhalten).",
        .langueChangee: "Sprache geändert: Die nächsten Antworten sind auf Deutsch.",
        .consigneModele: "Du bist ein Assistent. Du antwortest immer auf Deutsch, unabhängig von der Sprache der Nachricht. Du sprichst die Person mit Sie an.",
        .promptDocument: "Antworte ausschließlich anhand des folgenden Dokuments.\n\nDokument „%@“:\n%@\n\nFrage: %@",
        .promptCompression: "Fasse in weniger als 200 Wörtern die gestellten Fragen und die gegebenen Antworten zusammen und behalte die genauen Fakten, Zahlen und Namen bei. Fasse nicht das Dokument selbst zusammen.",
        .resumeEchangesPrecedents: "Zusammenfassung der bisherigen Unterhaltung:",
        .documentCharge: "Dokument geladen.",
        .menuFichier: "Ablage",
        .menuEdition: "Bearbeiten",
        .menuPresentation: "Darstellung",
        .menuFenetre: "Fenster",
        .menuAide: "Hilfe",
        .menuLangue: "Sprache",
        .fermer: "Schließen",
        .quitter: "FM Mini beenden",
        .masquer: "FM Mini ausblenden",
        .masquerLesAutres: "Andere ausblenden",
        .toutAfficher: "Alle einblenden",
        .annuler: "Widerrufen",
        .retablir: "Wiederholen",
        .couper: "Ausschneiden",
        .coller: "Einsetzen",
        .supprimer: "Löschen",
        .toutSelectionner: "Alles auswählen",
        .copierDerniereReponse: "Letzte Antwort kopieren",
        .minimiser: "Im Dock ablegen",
        .pleinEcran: "Vollbild ein",
        .aideFMMini: "FM Mini-Hilfe",
        .allerPlusLoinMenu: "Mehr erfahren…",
        .aProposDeFMMini: "Über FM Mini",
        .titreAllerPlusLoin: "Mehr erfahren",
        .titreAPropos: "Über",
        .aProposTourne: "Läuft vollständig auf Ihrem Mac mit dem Modell Apple Foundation Models.",
        .iconeFMMini: "FM Mini-Symbol",
        .introAllerPlusLoin: "FM Mini kann absichtlich wenig. Hier ist, was Sie zusätzlich herausholen können — entweder mit dem, was Ihr Mac schon hat, oder indem Sie Ihren Programmierassistenten (Claude Code, Codex…) bitten, es hinzuzufügen: Die Taste „Anfrage kopieren“ legt einen fertigen Text in die Zwischenablage.",
        .sectionDejaSurMac: "Bereits auf Ihrem Mac",
        .sectionAAjouter: "Mit Ihrem Assistenten zu FM Mini hinzufügen",
        .ceQueCaApporte: "Was es bringt: %@",
        .vosDonnees: "Ihre Daten: %@",
        .ouvrirReglagesDictee: "Diktat-Einstellungen öffnen",
        .ouvrirRaccourcis: "Kurzbefehle öffnen",
        .ouvrirTerminal: "Terminal öffnen",
        .copierDemande: "Anfrage kopieren",
        .piedAllerPlusLoin: "Dieses Fenster installiert und lädt nichts herunter: Es öffnet bereits vorhandene Apps oder kopiert Text.",
        .demandeEnAnglais: "(Anfrage auf Englisch)",
        .donneesRestentSurMac: "bleiben auf dem Mac.",
        .carteDicteeTitre: "Sprechen statt tippen",
        .carteDicteeApport: "diktieren Sie Ihre Nachricht ins Eingabefeld; das Diktat des Mac funktioniert in FM Mini ohne besondere Einstellung.",
        .carteRaccourcisTitre: "Mit Kurzbefehlen automatisieren",
        .carteRaccourcisApport: "die Aktion „Modell verwenden“ in Kurzbefehle nutzt dasselbe Modell wie FM Mini: jede eingehende E-Mail zusammenfassen, in einen Ordner gelegte Dateien umbenennen, eine Auswahl übersetzen — ohne FM Mini zu öffnen.",
        .carteTerminalTitre: "Aus dem Terminal und anderen Apps nutzen",
        .carteTerminalApport: "der Befehl fm antwortet in der Kommandozeile (fm respond \"Ihre Frage\"); fm serve öffnet eine lokale OpenAI-kompatible Tür (127.0.0.1:1976) für Apps, die mit ChatGPT sprechen können.",
        .carteImagesTitre: "Bilder und Scans lesen",
        .carteImagesApport: "ein Foto, ein Bildschirmfoto oder ein gescanntes PDF anhängen; der Text wird vom Mac erkannt und dann dem Modell übergeben.",
        .carteWebTitre: "Eine Webseite lesen",
        .carteWebApport: "fügen Sie die Adresse einer Seite ein; FM Mini holt ihren Text und fügt ihn als Dokument hinzu.",
        .carteWebDonnees: "die Adresse der Seite wird ins Internet gesendet, um sie herunterzuladen — die einzige Ausnahme von „alles bleibt auf dem Mac“; der Rest der Unterhaltung verlässt den Mac nicht.",
        .carteDossierTitre: "Einen Ordner mit Dokumenten befragen",
        .carteDossierApport: "wählen Sie einen Ordner; das Modell kann seine Textdateien auflisten und die lesen, die es für die Antwort braucht.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]

    static let it: [Cle: String] = [
        .titreAccueil: "BUONGIORNO, COSA POSSO FARE PER LEI?",
        .paragrapheAccueil: "Sono gratuito e lavoro localmente sul suo Mac, senza mai trasferire i suoi documenti nel cloud. Sono specializzato nel trattamento del testo in COUNT lingue (tra cui l'italiano): so riassumere, correggere, analizzare, riformulare, tradurre ed estrarre informazioni dalla maggior parte dei testi che mi affiderà. In compenso, non conosco l'attualità e le mie conoscenze enciclopediche sono molto limitate. Mi metta alla prova!",
        .puceResume: "Riassumi l'allegato in circa 200 parole.",
        .puceCorrection: "Correggi l'ortografia e la grammatica dell'allegato, mantenendo il senso.",
        .puceQuiz: "Crea un quiz di cinque domande a partire dall'allegato, con le risposte.",
        .puceExtraction: "Estrai i nomi, le date e le cifre dall'allegato.",
        .puceTraductionLibelle: "Tradurre in…",
        .puceTraductionTexte: "Traduci l'allegato in %@.",
        .lienAllerPlusLoin: "Andare oltre →",
        .aucuneLangueDisponible: "Nessuna lingua disponibile",
        .nouvelleConversation: "Nuova conversazione",
        .jeton: "token",
        .jetons: "token",
        .conversationPresquePleine: "Conversazione quasi piena.",
        .boutonAjouterPJ: "Aggiungi un allegato…",
        .aidePJ: "Allegati accettati: .txt .md .csv .json .rtf .docx .pdf (testo, non scansioni) — fino a circa %@ parole",
        .badgePJ: "Allegato: %@ (%@)",
        .retirerFichier: "Rimuovi il file",
        .analyseDocument: "Analisi del documento…",
        .envoyer: "Invia",
        .reponseEnCours: "Risposta…",
        .champMessage: "Messaggio",
        .choisirDocument: "Scelga un documento di testo",
        .copier: "Copia",
        .copie: "Copiato",
        .nouvelleConversationGardantDocument: "Nuova conversazione mantenendo il documento",
        .modeleIndisponible: "Il modello Apple non è disponibile: %@",
        .ouvrirReglagesSysteme: "Apri Impostazioni di Sistema",
        .raisonInconnue: "Motivo sconosciuto",
        .partieTropLongue: "Questa parte resta troppo lunga per la finestra del modello.",
        .nouvellePartieChargee: "Nuova parte caricata: la conversazione è stata azzerata.",
        .fenetreContexteInconnue: "Impossibile conoscere la finestra di contesto del modello.",
        .conversationPleine: "La conversazione è piena (%@).",
        .gardeFous: "Le protezioni di Apple hanno bloccato questa risposta.",
        .conversationTropLongue: "La conversazione è troppo lunga per il modello: faccia clic su Nuova conversazione.",
        .langueNonPriseEnCharge: "Lingua non supportata.",
        .fichierTropLourd: "File troppo grande (%@ MB, massimo 5 MB)",
        .fichierVide: "Questo file è vuoto.",
        .pdfSansTexte: "Questo PDF non contiene testo leggibile (scansione): bisognerebbe prima passarlo dal riconoscimento del testo.",
        .texteNonUTF8: "Il file deve essere testo UTF-8 leggibile.",
        .documentEndommage: "Questo file è illeggibile (documento danneggiato?).",
        .documentDecoupe: "Questo documento è di %@ parole (%@). Posso leggere solo circa %@ parole alla volta: è il limite di memoria del modello, non un errore. L'ho diviso in %@ parti; scelga quella da caricare, oppure ponga la sua domanda parte per parte.",
        .libellePartie: "Parte %@/%@ — parole da %@ a %@ — «%@»",
        .phraseTresLongueCoupee: "(frase molto lunga tagliata)",
        .nomPartie: "%@ — parte %@/%@",
        .documentSansNom: "documento",
        .conversationCompressee: "Conversazione compressa: %@ → %@%@",
        .documentConserve: " (il documento è conservato per intero).",
        .langueChangee: "Lingua cambiata: le prossime risposte saranno in italiano.",
        .consigneModele: "Sei un assistente. Rispondi sempre in italiano, qualunque sia la lingua del messaggio. Ti rivolgi alla persona dando del Lei.",
        .promptDocument: "Rispondi unicamente a partire dal documento qui sotto.\n\nDocumento «%@»:\n%@\n\nDomanda: %@",
        .promptCompression: "Riassumi in meno di 200 parole le domande poste e le risposte date, mantenendo esatti fatti, cifre e nomi. Non riassumere il documento stesso.",
        .resumeEchangesPrecedents: "Riepilogo degli scambi precedenti:",
        .documentCharge: "Documento caricato.",
        .menuFichier: "File",
        .menuEdition: "Modifica",
        .menuPresentation: "Vista",
        .menuFenetre: "Finestra",
        .menuAide: "Aiuto",
        .menuLangue: "Lingua",
        .fermer: "Chiudi",
        .quitter: "Esci da FM Mini",
        .masquer: "Nascondi FM Mini",
        .masquerLesAutres: "Nascondi altre",
        .toutAfficher: "Mostra tutte",
        .annuler: "Annulla",
        .retablir: "Ripeti",
        .couper: "Taglia",
        .coller: "Incolla",
        .supprimer: "Elimina",
        .toutSelectionner: "Seleziona tutto",
        .copierDerniereReponse: "Copia l'ultima risposta",
        .minimiser: "Contrai",
        .pleinEcran: "Attiva schermo intero",
        .aideFMMini: "Aiuto FM Mini",
        .allerPlusLoinMenu: "Andare oltre…",
        .aProposDeFMMini: "Informazioni su FM Mini",
        .titreAllerPlusLoin: "Andare oltre",
        .titreAPropos: "Informazioni",
        .aProposTourne: "Funziona interamente sul suo Mac con il modello Apple Foundation Models.",
        .iconeFMMini: "Icona di FM Mini",
        .introAllerPlusLoin: "FM Mini fa poche cose di proposito. Ecco cosa può fargli fare in più — con quello che il suo Mac ha già, oppure chiedendo al suo assistente di programmazione (Claude Code, Codex…) di aggiungerlo: il pulsante «Copia la richiesta» mette negli appunti un testo pronto da incollare.",
        .sectionDejaSurMac: "Già sul suo Mac",
        .sectionAAjouter: "Da aggiungere a FM Mini con il suo assistente",
        .ceQueCaApporte: "Cosa apporta: %@",
        .vosDonnees: "I suoi dati: %@",
        .ouvrirReglagesDictee: "Apri le impostazioni della dettatura",
        .ouvrirRaccourcis: "Apri Comandi rapidi",
        .ouvrirTerminal: "Apri il Terminale",
        .copierDemande: "Copia la richiesta",
        .piedAllerPlusLoin: "Questa finestra non installa né scarica nulla: apre app già presenti o copia del testo.",
        .demandeEnAnglais: "(richiesta in inglese)",
        .donneesRestentSurMac: "restano sul Mac.",
        .carteDicteeTitre: "Parlare invece di scrivere",
        .carteDicteeApport: "detti il suo messaggio nel campo di testo; la dettatura del Mac funziona in FM Mini senza impostazioni particolari.",
        .carteRaccourcisTitre: "Automatizzare con Comandi rapidi",
        .carteRaccourcisApport: "l'azione «Usa modello» di Comandi rapidi ricorre allo stesso modello di FM Mini: riassumere ogni mail ricevuta, rinominare i file depositati in una cartella, tradurre una selezione — senza aprire FM Mini.",
        .carteTerminalTitre: "Usarlo dal Terminale e da altre app",
        .carteTerminalApport: "il comando fm risponde dalla riga di comando (fm respond \"la sua domanda\"); fm serve apre una porta locale compatibile OpenAI (127.0.0.1:1976) per le app che sanno parlare con ChatGPT.",
        .carteImagesTitre: "Leggere immagini e scansioni",
        .carteImagesApport: "allegare una foto, una schermata o un PDF scansionato; il testo è riconosciuto dal Mac e poi passato al modello.",
        .carteWebTitre: "Leggere una pagina web",
        .carteWebApport: "incolli l'indirizzo di una pagina; FM Mini ne recupera il testo e lo aggiunge come documento.",
        .carteWebDonnees: "l'indirizzo della pagina è inviato su internet per scaricarla: è l'unica eccezione a «tutto resta sul Mac»; il resto della conversazione non esce.",
        .carteDossierTitre: "Interrogare una cartella di documenti",
        .carteDossierApport: "scelga una cartella; il modello può elencare i suoi file di testo e leggere quello che gli serve per rispondere.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]

    static let pt: [Cle: String] = [
        .titreAccueil: "OLÁ, O QUE POSSO FAZER POR VOCÊ?",
        .paragrapheAccueil: "Sou gratuito e trabalho localmente no seu Mac, sem nunca transferir seus documentos para a nuvem. Sou especializado no tratamento de texto em COUNT idiomas (incluindo o português): sei resumir, corrigir, analisar, reformular, traduzir e extrair informações da maioria dos textos que você me confiar. Em contrapartida, não conheço a atualidade e meus conhecimentos enciclopédicos são muito limitados. Experimente-me!",
        .puceResume: "Resuma o anexo em cerca de 200 palavras.",
        .puceCorrection: "Corrija a ortografia e a gramática do anexo, mantendo o sentido.",
        .puceQuiz: "Crie um quiz de cinco perguntas a partir do anexo, com as respostas.",
        .puceExtraction: "Extraia os nomes, datas e números do anexo.",
        .puceTraductionLibelle: "Traduzir para…",
        .puceTraductionTexte: "Traduza o anexo para %@.",
        .lienAllerPlusLoin: "Ir além →",
        .aucuneLangueDisponible: "Nenhum idioma disponível",
        .nouvelleConversation: "Nova conversa",
        .jeton: "token",
        .jetons: "tokens",
        .conversationPresquePleine: "Conversa quase cheia.",
        .boutonAjouterPJ: "Adicionar um anexo…",
        .aidePJ: "Anexos aceitos: .txt .md .csv .json .rtf .docx .pdf (texto, sem digitalizações) — até cerca de %@ palavras",
        .badgePJ: "Anexo: %@ (%@)",
        .retirerFichier: "Remover o arquivo",
        .analyseDocument: "Analisando o documento…",
        .envoyer: "Enviar",
        .reponseEnCours: "Respondendo…",
        .champMessage: "Mensagem",
        .choisirDocument: "Escolha um documento de texto",
        .copier: "Copiar",
        .copie: "Copiado",
        .nouvelleConversationGardantDocument: "Nova conversa mantendo o documento",
        .modeleIndisponible: "O modelo da Apple não está disponível: %@",
        .ouvrirReglagesSysteme: "Abrir Ajustes do Sistema",
        .raisonInconnue: "Motivo desconhecido",
        .partieTropLongue: "Esta parte continua longa demais para a janela do modelo.",
        .nouvellePartieChargee: "Nova parte carregada: a conversa foi reiniciada.",
        .fenetreContexteInconnue: "Não foi possível conhecer a janela de contexto do modelo.",
        .conversationPleine: "A conversa está cheia (%@).",
        .gardeFous: "As salvaguardas da Apple bloquearam esta resposta.",
        .conversationTropLongue: "A conversa está longa demais para o modelo: clique em Nova conversa.",
        .langueNonPriseEnCharge: "Idioma não suportado.",
        .fichierTropLourd: "Arquivo grande demais (%@ MB, máximo 5 MB)",
        .fichierVide: "Este arquivo está vazio.",
        .pdfSansTexte: "Este PDF não contém texto legível (digitalização): seria preciso primeiro passá-lo pelo reconhecimento de texto.",
        .texteNonUTF8: "O arquivo deve ser texto UTF-8 legível.",
        .documentEndommage: "Este arquivo está ilegível (documento danificado?).",
        .documentDecoupe: "Este documento tem %@ palavras (%@). Só consigo ler cerca de %@ palavras de cada vez: é o limite de memória do modelo, não um defeito. Eu o dividi em %@ partes; escolha a que deseja carregar, ou faça sua pergunta parte por parte.",
        .libellePartie: "Parte %@/%@ — palavras %@ a %@ — “%@”",
        .phraseTresLongueCoupee: "(frase muito longa cortada)",
        .nomPartie: "%@ — parte %@/%@",
        .documentSansNom: "documento",
        .conversationCompressee: "Conversa compactada: %@ → %@%@",
        .documentConserve: " (o documento é mantido na íntegra).",
        .langueChangee: "Idioma alterado: as próximas respostas serão em português.",
        .consigneModele: "Você é um assistente. Responde sempre em português, qualquer que seja o idioma da mensagem. Trata a pessoa por você, com cortesia.",
        .promptDocument: "Responda apenas com base no documento abaixo.\n\nDocumento “%@”:\n%@\n\nPergunta: %@",
        .promptCompression: "Resuma em menos de 200 palavras as perguntas feitas e as respostas dadas, mantendo os fatos, números e nomes exatos. Não resuma o documento em si.",
        .resumeEchangesPrecedents: "Resumo das trocas anteriores:",
        .documentCharge: "Documento carregado.",
        .menuFichier: "Arquivo",
        .menuEdition: "Editar",
        .menuPresentation: "Visualizar",
        .menuFenetre: "Janela",
        .menuAide: "Ajuda",
        .menuLangue: "Idioma",
        .fermer: "Fechar",
        .quitter: "Encerrar FM Mini",
        .masquer: "Ocultar FM Mini",
        .masquerLesAutres: "Ocultar outros",
        .toutAfficher: "Mostrar tudo",
        .annuler: "Desfazer",
        .retablir: "Refazer",
        .couper: "Cortar",
        .coller: "Colar",
        .supprimer: "Apagar",
        .toutSelectionner: "Selecionar tudo",
        .copierDerniereReponse: "Copiar a última resposta",
        .minimiser: "Minimizar",
        .pleinEcran: "Usar tela cheia",
        .aideFMMini: "Ajuda do FM Mini",
        .allerPlusLoinMenu: "Ir além…",
        .aProposDeFMMini: "Sobre o FM Mini",
        .titreAllerPlusLoin: "Ir além",
        .titreAPropos: "Sobre",
        .aProposTourne: "Funciona inteiramente no seu Mac com o modelo Apple Foundation Models.",
        .iconeFMMini: "Ícone do FM Mini",
        .introAllerPlusLoin: "O FM Mini faz poucas coisas de propósito. Veja o que você pode fazer com ele além disso — seja com o que seu Mac já tem, seja pedindo ao seu assistente de programação (Claude Code, Codex…) que o adicione: o botão “Copiar o pedido” coloca na área de transferência um texto pronto para colar.",
        .sectionDejaSurMac: "Já no seu Mac",
        .sectionAAjouter: "Para adicionar ao FM Mini com seu assistente",
        .ceQueCaApporte: "O que isso traz: %@",
        .vosDonnees: "Seus dados: %@",
        .ouvrirReglagesDictee: "Abrir os ajustes de ditado",
        .ouvrirRaccourcis: "Abrir Atalhos",
        .ouvrirTerminal: "Abrir o Terminal",
        .copierDemande: "Copiar o pedido",
        .piedAllerPlusLoin: "Esta janela não instala nem baixa nada: ela abre apps já presentes ou copia texto.",
        .demandeEnAnglais: "(pedido em inglês)",
        .donneesRestentSurMac: "ficam no Mac.",
        .carteDicteeTitre: "Falar em vez de digitar",
        .carteDicteeApport: "dite sua mensagem no campo de texto; o ditado do Mac funciona no FM Mini sem nenhum ajuste especial.",
        .carteRaccourcisTitre: "Automatizar com Atalhos",
        .carteRaccourcisApport: "a ação “Usar modelo” dos Atalhos recorre ao mesmo modelo do FM Mini: resumir cada e-mail recebido, renomear os arquivos colocados em uma pasta, traduzir uma seleção — sem abrir o FM Mini.",
        .carteTerminalTitre: "Usá-lo no Terminal e em outros apps",
        .carteTerminalApport: "o comando fm responde na linha de comando (fm respond \"sua pergunta\"); fm serve abre uma porta local compatível com OpenAI (127.0.0.1:1976) para os apps que sabem falar com o ChatGPT.",
        .carteImagesTitre: "Ler imagens e digitalizações",
        .carteImagesApport: "anexar uma foto, uma captura de tela ou um PDF digitalizado; o texto é reconhecido pelo Mac e depois entregue ao modelo.",
        .carteWebTitre: "Ler uma página web",
        .carteWebApport: "cole o endereço de uma página; o FM Mini recupera o texto dela e o adiciona como documento.",
        .carteWebDonnees: "o endereço da página é enviado pela internet para baixá-la — é a única exceção a “tudo fica no Mac”; o resto da conversa não sai.",
        .carteDossierTitre: "Consultar uma pasta de documentos",
        .carteDossierApport: "escolha uma pasta; o modelo pode listar seus arquivos de texto e ler o que precisar para responder.",
        .demandeImages: demandeImagesFR,
        .demandeWeb: demandeWebFR,
        .demandeDossier: demandeDossierFR
    ]
}

// MARK: - Langue courante

import AppKit
import Combine

/// Langue de l'interface, observée par les vues ; mémorisée dans UserDefaults (clé « langue »).
@MainActor
final class Langues: ObservableObject {
    static let shared = Langues()
    static let cleDefaults = "langue"

    @Published private(set) var courante: Langue

    private init() {
        if let code = UserDefaults.standard.string(forKey: Self.cleDefaults), let langue = Langue(rawValue: code) {
            courante = langue
        } else {
            switch Personnalisation.langueParDefaut {
            case .auto: courante = Langue.automatique()
            case .fixe(let langue): courante = langue
            }
        }
    }

    func choisir(_ langue: Langue) {
        guard langue != courante else { return }
        courante = langue
        UserDefaults.standard.set(langue.rawValue, forKey: Self.cleDefaults)
        // Les menus standard d'AppKit (Fenêtre, Outils d'écriture…) suivront aussi au prochain lancement.
        UserDefaults.standard.set([langue.rawValue], forKey: "AppleLanguages")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { MenuLocalizer.apply(langue) }
    }

    func texte(_ cle: Cle) -> String { courante.texte(cle) }
    func texte(_ cle: Cle, _ arguments: CVarArg...) -> String {
        String(format: courante.texte(cle), locale: courante.locale, arguments: arguments)
    }
}

/// Renomme les menus standard d'AppKit (titres et commandes système) dans la langue choisie.
@MainActor
enum MenuLocalizer {
    private static var observers: [NSObjectProtocol] = []

    static func installer() {
        guard observers.isEmpty else { return }
        for name in [NSApplication.didFinishLaunchingNotification, NSMenu.didBeginTrackingNotification, NSWindow.didBecomeKeyNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in apply(Langues.shared.courante) }
            })
        }
    }

    static func apply(_ langue: Langue) {
        guard let menu = NSApp.mainMenu else { return }
        let titres: [Cle] = [.menuFichier, .menuEdition, .menuPresentation, .menuFenetre, .menuAide]
        for (offset, cle) in titres.enumerated() where menu.items.count > offset + 1 {
            let item = menu.items[offset + 1]
            item.title = langue.texte(cle)
            item.submenu?.title = langue.texte(cle)
        }
        let parSelecteur: [String: Cle] = [
            "performClose:": .fermer, "terminate:": .quitter, "hide:": .masquer,
            "hideOtherApplications:": .masquerLesAutres, "unhideAllApplications:": .toutAfficher,
            "undo:": .annuler, "redo:": .retablir, "cut:": .couper, "copy:": .copier, "paste:": .coller,
            "delete:": .supprimer, "selectAll:": .toutSelectionner, "performMiniaturize:": .minimiser,
            "toggleFullScreen:": .pleinEcran, "showHelp:": .aideFMMini
        ]
        // Les éléments fournis par SwiftUI n'ont pas toujours le sélecteur AppKit attendu : repli sur leur titre français.
        let parTitreFrancais: [String: Cle] = [
            "Fermer": .fermer, "Quitter FM Mini": .quitter, "Masquer FM Mini": .masquer, "Masquer les autres": .masquerLesAutres,
            "Tout afficher": .toutAfficher, "Annuler": .annuler, "Rétablir": .retablir, "Couper": .couper, "Copier": .copier,
            "Coller": .coller, "Supprimer": .supprimer, "Tout sélectionner": .toutSelectionner, "Minimiser": .minimiser,
            "Activer le mode plein écran": .pleinEcran, "Aide FM Mini": .aideFMMini
        ]
        renommer(menu, parSelecteur, parTitreFrancais, langue)
    }

    private static func renommer(_ menu: NSMenu, _ parSelecteur: [String: Cle], _ parTitre: [String: Cle], _ langue: Langue) {
        for item in menu.items {
            if let action = item.action, let cle = parSelecteur[NSStringFromSelector(action)] { item.title = langue.texte(cle) }
            else if let cle = parTitre[item.title] { item.title = langue.texte(cle) }
            if let sous = item.submenu { renommer(sous, parSelecteur, parTitre, langue) }
        }
    }
}
