import SwiftUI

// Les textes visibles (accueil, puces, menus, messages, consigne du modèle) sont dans Langues.swift, en six langues.
enum Personnalisation {
    // Change la langue par défaut de l'interface : `.auto` suit la langue du Mac ; `.fixe(.en)` impose une langue.
    // Le choix fait dans le menu Présentation → Langue est mémorisé et l'emporte ensuite.
    static let langueParDefaut: ChoixLangue = .auto

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
