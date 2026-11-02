# FM Mini 1.3.11

FM Mini est une petite application de discussion qui utilise uniquement le modèle Apple présent sur votre Mac. Sans fichier joint, elle répond normalement. Avec un seul fichier joint, elle répond uniquement à partir de ce document.

Crédits : acromega + Claude, 2026.

Un document joint n’est envoyé qu’avec la première question : le badge « document chargé » confirme ensuite qu’il reste dans la conversation. La jauge sous l’en-tête indique l’occupation du contexte ; FM Mini compresse automatiquement les anciens échanges lorsqu’elle approche de la limite, sans retirer les bulles visibles. Les bulles peuvent être copiées par survol ou clic droit.

## Prérequis

- macOS 27 ou ultérieur ;
- un Mac Apple Silicon ;
- Apple Intelligence activée dans Réglages Système, avec le modèle entièrement téléchargé ;
- les Command Line Tools Apple (installez-les avec `xcode-select --install` si nécessaire). Xcode n’est pas requis.

## Installation et démarrage

1. Copiez le dossier `fm-mini` dans votre dossier personnel, pour obtenir `~/fm-mini`.
2. Dans Terminal, lancez `cd ~/fm-mini`, puis `./make-app.sh`.
3. Lancez `open "build/FM Mini.app"`.

La fenêtre s’ouvre pour la première fois au centre de l’écran en format vertical (460 × 760), peut être réduite jusqu’à 400 × 560, et mémorise ensuite sa taille et sa position.

## Personnaliser FM Mini

Vous pouvez adapter les textes, les couleurs, les crédits et la taille de la fenêtre dans [Personnalisation.swift](Sources/FMMini/Personnalisation.swift), sans toucher au reste du dossier.

1. Dans le Finder, faites un clic droit sur `Sources/FMMini/Personnalisation.swift`, choisissez **Ouvrir avec**, puis **TextEdit**.
2. Modifiez seulement le texte entre guillemets (ou les deux nombres de `CGSize` pour la taille de la fenêtre), puis enregistrez.
3. Dans Terminal, à la racine de `fm-mini`, relancez `./make-app.sh`.

Par exemple, vous pouvez changer une puce en remplaçant le texte de `puceResumeLibelle` et `puceResumeTexte`, tutoyer en remplaçant « vous » par « tu » dans `consigneModele`, ou agrandir la fenêtre en augmentant `width` et `height` de `tailleFenetreParDefaut`. Ne modifiez ni les noms des constantes, ni les commentaires, ni un autre fichier du dossier.

## Aller plus loin

Le menu **Aide → Aller plus loin…**, ou le lien au bas de l’accueil, ouvre une fenêtre de six cartes. Elle explique trois capacités déjà présentes sur le Mac (dictée, Raccourcis et Terminal), puis trois ajouts que vous pouvez demander à votre assistant de programmation : lecture d’images et de scans, pages web, ou dossier de documents. Les trois dernières cartes copient une demande prête à coller ; la fenêtre ne détecte rien, n’exécute rien et ne télécharge rien.

Les demandes copiées renvoient à [POUR-LES-ASSISTANTS.md](POUR-LES-ASSISTANTS.md) et à [SPEC.md](SPEC.md), qui décrivent les règles de travail du projet.

Vous pouvez joindre un fichier `.txt`, `.md`, `.csv`, `.json`, `.log`, `.rtf`, `.docx` ou `.pdf` contenant du texte. Les PDF issus d’un scan sans texte ne peuvent pas être lus. Appuyez sur Entrée pour envoyer ; Maj-Entrée ajoute une ligne. Le temps de réponse est affiché sous chaque réponse du modèle.

## Menus et clavier

Le menu **Fichier** propose **Nouvelle conversation** (⌘N), **Joindre un fichier…** (⌘O) et **Fermer** (⌘W). Le menu **Édition** propose aussi **Copier la dernière réponse** (⌘⇧C). Ces raccourcis fonctionnent même lorsque vous écrivez votre message.

Tab passe de **Message** à **Envoyer**, **Joindre un fichier…**, puis **Nouvelle conversation**, avant de revenir au message ; Maj-Tab suit le chemin inverse. Un bouton indisponible est ignoré. Le bouton actif est entouré et s’active avec Espace ou Entrée.

## Et si mon document est trop long ?

Le modèle ne peut lire qu’une quantité limitée de texte à la fois : ce n’est pas un bogue. FM Mini découpe alors automatiquement le document en parties, en respectant les titres, les paragraphes et les fins de phrase autant que possible. Choisissez une partie ; elle devient le document chargé pour la prochaine question, et vous pouvez revenir à une autre partie à tout moment. Si cette découpe ne correspond pas à votre besoin, copiez vous-même la section utile dans un petit fichier `.txt`.

## Limites

Un fichier ne peut pas dépasser 5 Mo. Le modèle a aussi une fenêtre de contexte limitée (selon le Mac, habituellement 4 096 ou 8 192 jetons) : l’application indique sous le bouton de pièce jointe une estimation en mots (environ 2 600 ou 5 300 mots). Plus la conversation est longue, plus chaque réponse est lente ; FM Mini la compresse automatiquement. Lorsqu’un document dépasse cette fenêtre, FM Mini propose ses parties ; lorsque la conversation devient longue, elle conserve le document et résume automatiquement les anciens échanges. Il n’a pas de connaissance du monde en temps réel et les garde-fous d’Apple peuvent refuser certaines demandes.

## Langues

Les 24 langues prises en charge sont : fr, fr-CA, en ×4, es ×3, pt ×2, zh ×3, de, it, ja, ko, nl, da, nb, sv, tr, vi. Vers une langue hors liste, le modèle produit du texte mais sans aucune garantie (constaté : arabe très correct, thaï trompeur) ; seule la qualité du français a été mesurée.

## Ce qu’il ne sait pas faire

FM Mini ne sait pas compter, comparer, détecter une contradiction ou dire de façon fiable « le texte ne le dit pas » : il restitue, il ne vérifie pas.

## Dépannage

- Si l’application indique que le modèle n’est pas disponible, ouvrez Réglages Système, activez Apple Intelligence et attendez la fin du téléchargement.
- FM Mini est signé ad hoc : il est signé localement, sans certificat Apple de distribution. Gatekeeper peut d’abord afficher seulement **Placer dans la corbeille** et **Terminé**. Cliquez sur **Terminé**, puis ouvrez **Réglages Système → Confidentialité et sécurité** et choisissez **Ouvrir quand même** pour FM Mini.
- Si une partie sélectionnée ne répond pas à votre question, choisissez une autre partie dans la carte du document ou joignez un extrait plus court.
- Un fichier de plusieurs Mo peut demander quelques dizaines de secondes à lire et à découper ; l’indication **Analyse du document…** reste visible pendant ce travail.
- Lors de la vérification, un script Swift isolé a pu afficher une erreur Apple `ModelManagerServices` alors que l’application signée fonctionnait. Dans ce cas, construisez et ouvrez l’application avec les trois commandes ci-dessus plutôt que d’essayer le modèle depuis un script de shell.
- Si l’ancienne icône reste affichée après une reconstruction, c’est généralement le cache du Finder ou du Dock : exécutez `touch "build/FM Mini.app"`, puis rouvrez l’application. Si cela ne suffit pas, relancez le Finder ou le Dock.

## Vérification technique

Si l’interface ne peut pas être contrôlée automatiquement, ouvrez **Terminal.app**, placez-vous dans le dossier `fm-mini`, puis exécutez `build/FM Mini.app/Contents/MacOS/FMMini --autotest`. Il vérifie la réponse normale sans document, « salut », un résumé, la fenêtre de contexte, la lecture du DOCX et du PDF sans texte des fixtures, la limite de 5 Mo, le découpage d’un document de 20 000 mots et la compression d’une conversation.
