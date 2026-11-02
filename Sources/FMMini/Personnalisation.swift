import SwiftUI

enum Personnalisation {
    // Change la consigne fixe du modèle ; conservez le français et le vouvoiement si vous voulez le comportement prévu.
    static let consigneModele = "Tu es un assistant. Tu réponds toujours en français, quelle que soit la langue du message. Tu vouvoies la personne."

    static let boutonAjouterPJ = "Ajouter une PJ…"
    static let aidePJ = "PJ acceptées : .txt .md .csv .json .rtf .docx .pdf (texte, pas de scan) — jusqu'à environ %@ mots"
    static let badgePJ = "PJ : %@ (%@)"

    // Change le titre affiché quand la conversation est vide ; ne retirez pas la ponctuation française.
    static let titreAccueil = "BONJOUR, QUE PUIS-JE FAIRE POUR VOUS ?"
    // Change le mot remplacé par le nombre de langues ; laissez-le présent dans le paragraphe d’accueil.
    static let marqueurNombreLangues = "COUNT"
    // Change le paragraphe affiché à l’accueil ; conservez le marqueur COUNT pour afficher le nombre réel de langues.
    static let paragrapheAccueil = "Je suis gratuit et je travaille localement sur votre Mac, sans jamais transférer vos documents dans le cloud. Je suis spécialisé dans le traitement du texte en COUNT langues (dont le français) : je sais résumer, corriger, analyser, reformuler, traduire et extraire des informations de la plupart des textes que vous me confierez. En revanche, je ne connais pas l'actualité et mes connaissances encyclopédiques sont très limitées. Essayez-moi !"

    static let puceResume = "Résume la PJ en 200 mots environ."
    static let puceCorrection = "Corrige l'orthographe et la grammaire de la PJ, en gardant le sens."
    static let puceQuiz = "Crée un quiz de cinq questions à partir de la PJ, avec les réponses."
    static let puceExtraction = "Extrais les noms, dates et chiffres de la PJ."
    static let puceTraductionLibelle = "Traduire la PJ en…"
    static let puceTraductionTexte = "Traduis la PJ en %@."

    // Change la taille de la fenêtre au premier lancement ; gardez un format assez grand pour l’accueil complet.
    static let tailleFenetreParDefaut = CGSize(width: 460, height: 760)
    // Change la plus petite taille autorisée ; ne descendez pas au point de couper les libellés et les boutons.
    static let tailleFenetreMinimale = CGSize(width: 400, height: 560)

    // Change le gris des textes secondaires ; gardez un contraste suffisant sur fond blanc.
    static let grisTexteSecondaire = Color(white: 0.42)
    // Change la couleur d’accent des contrôles ; gardez une couleur visible sur fond blanc.
    static let couleurAccent = Color.accentColor

    // Change la ligne de crédits de la fenêtre À propos ; gardez les crédits des auteurs.
    static let ligneCredits = "acromega + Claude — 2026"
    // Change le nom de l’image des crédits dans Resources ; conservez une image JPG intégrée à l’application.
    static let nomImageCredits = "credits"
}
