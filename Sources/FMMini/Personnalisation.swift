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

    // Change le libellé de la puce de résumé ; gardez-le court pour qu’il reste lisible dans la fenêtre.
    static let puceResumeLibelle = "Résume ce texte en trois phrases : "
    // Change le texte inséré par la puce de résumé ; gardez l’espace final pour placer le curseur après la consigne.
    static let puceResumeTexte = "Résume ce texte en trois phrases : "
    // Change le libellé de la puce de correction ; gardez-le court pour qu’il reste lisible dans la fenêtre.
    static let puceCorrectionLibelle = "Corrige l’orthographe et la grammaire de ce texte : "
    // Change le texte inséré par la puce de correction ; gardez l’espace final pour placer le curseur après la consigne.
    static let puceCorrectionTexte = "Corrige l’orthographe et la grammaire de ce texte : "
    // Change le libellé de la puce de reformulation ; gardez-le court pour qu’il reste lisible dans la fenêtre.
    static let puceReformulationLibelle = "Reformule ce message pour qu’il soit plus clair et plus poli : "
    // Change le texte inséré par la puce de reformulation ; gardez l’espace final pour placer le curseur après la consigne.
    static let puceReformulationTexte = "Reformule ce message pour qu’il soit plus clair et plus poli : "
    // Change le libellé de la puce de traduction ; conservez les points de suspension pour indiquer le choix d’une langue.
    static let puceTraductionLibelle = "Traduire en…"
    // Change le texte inséré par la puce de traduction ; conservez %@ pour y insérer la langue choisie.
    static let puceTraductionTexte = "Traduis en %@ : "
    // Change le libellé de la puce de document ; gardez-le explicite car il ouvre le sélecteur de fichier.
    static let puceDocumentLibelle = "Joindre un document et en lister les points importants"
    // Change le texte inséré après la puce de document ; gardez une demande liée au document joint.
    static let puceDocumentTexte = "Liste les points importants de ce document."

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
