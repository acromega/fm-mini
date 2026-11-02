# Audit de conformité et de sûreté — FM Mini 1.3.1

## Verdict

Non distribuable tel quel.
Les correctifs bloquants sont : la fenêtre « Compléter l’installation » affiche ses textes de carte littéralement, le script de construction n’effectue aucun prévol exigé, et l’autotest livré échoue sur cette machine tout en écrivant d’autres fichiers que son rapport.
Le binaire signé 1.3.1 ouvre l’accueil et la fenêtre d’installation ; les constats ci-dessous distinguent ce qui a été observé de ce qui n’a pas pu être reproduit sans modifier l’application ni la configuration du Mac.

## Méthode et périmètre

Sources de référence lues avant l’audit : `SPEC.md`, `AUDIT-DOSSIER.md`, `README.md`, `autotest-2026-11-02.txt` et `audit-fixtures/README-fixtures.md`. Le rapport porte sur le source présent et sur `build/FM Mini.app` (Info.plist : version 1.3.1 ; signature ad hoc). Aucun fichier de l’application n’a été modifié, et ce rapport n’est pas committé.

Commandes principales :

```sh
rg -n -i 'URLSession|Network|NWConnection|socket|Process|curl|http|localhost' Sources/FMMini/main.swift
.build/release/FMMini --autotest
swift - <<'SWIFT' # PDFKit : vérification du PDF sans couche texte
import Foundation; import PDFKit
let u = URL(fileURLWithPath: "~/fm-mini/audit-fixtures/scan-sans-texte.pdf")
print(PDFDocument(url: u)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? -1)
SWIFT
```

La fenêtre principale et la fenêtre d’installation ont aussi été examinées par l’arbre d’accessibilité et une capture locale, sans transmettre de document.

## 1. Vérité des promesses

### Réseau et confidentialité annoncée — **majeur : non vérifiable complètement**

**Preuve.** La recherche statique ne trouve qu’un appel réseau direct : `URLSession` vers `http://localhost:1234/v1/models`, à [main.swift:1020](~/fm-mini/Sources/FMMini/main.swift:1020), appelé par `InstallationChecker.checkAll()` lors de l’ouverture de cette fenêtre ([986-1003](~/fm-mini/Sources/FMMini/main.swift:986)). `URLSessionConfiguration.ephemeral`, le délai de 0,5 s et `waitsForConnectivity = false` sont bien présents ([1021-1032](~/fm-mini/Sources/FMMini/main.swift:1021)). Aucun `Network`, `NWConnection` ni socket n’est présent.

Un relevé `lsof -nP -a -c FMMini -i`, pendant que la fenêtre d’installation était ouverte, n’a montré aucun descripteur réseau persistant. Ce relevé ponctuel ne prouve pas les cinq minutes demandées et ne couvre pas l’usage avec Wi-Fi coupé. `fs_usage` n’est pas exploitable sans privilège root sur ce Mac ; le test a donc été arrêté après le message « must be run as root ».

Les URLs `https://…` restantes sont passées à `NSWorkspace.shared.open` après un clic sur « Ouvrir » ([1036-1085](~/fm-mini/Sources/FMMini/main.swift:1036)) : elles ouvrent un navigateur et peuvent donc provoquer du trafic hors du processus FM Mini. Elles ne transmettent pas le texte de la conversation, mais la promesse doit être comprise avec cette action explicite de l’utilisateur.

**Reproduction.** Ouvrir « Aller plus loin → Compléter l’installation », puis exécuter le `lsof` ci-dessus ; fermer la fenêtre et répéter. Un protocole de cinq minutes et de coupure Wi-Fi reste à faire dans un environnement de test autorisant cette perturbation réseau.

### Langues — **conforme (code et interface)**

**Preuve.** Le menu est dérivé de `SystemLanguageModel.default.supportedLanguages`, dédoublonné par code de langue et trié par nom français ([306-313](~/fm-mini/Sources/FMMini/main.swift:306)). L’interface observée affiche quinze langues de base (allemand, anglais, chinois, etc.) : les variantes de locale sont volontairement dédoublonnées, conformément à SPEC.md.

**Reproduction.** À l’accueil, ouvrir « Traduire en… » ; l’arbre d’accessibilité a relevé les quinze entrées et aucune liste codée en dur.

### « Gratuit », « 100 % local », « ≈ une seconde » — **majeur : promesse non établie**

**Preuve.** « Gratuit » ne peut pas être démontré par le code. La formulation locale est compatible avec le contrôle statique précédent, mais le contrôle d’exécution complet n’a pas été réalisable. Surtout, les dix réponses courtes sur conversations vierges n’ont pas pu être mesurées : l’exécution directe demandée de l’autotest s’arrête immédiatement avec :

```text
FM Mini autotest — début
AUTOTEST: ÉCHEC — The operation couldn’t be completed. (ModelManagerServices.ModelManagerError error 1008.)
```

Le rapport antérieur montrait aussi, pour une conversation longue, 4 620 ms à 12 170 ms par réponse ; ce n’est pas une mesure des dix conversations vierges, mais cela contredit une lecture générale de « je réponds en une seconde environ ».

**Reproduction.** Depuis le dépôt : `.build/release/FMMini --autotest`. L’accueil graphique, lui, indiquait un modèle disponible (jauge `74 / 8 192 jetons`) au moment de l’observation : l’échec est donc spécifiquement reproductible dans le parcours autotest en ligne de commande.

## 2. Conformité à SPEC.md

| Exigence | État | Preuve et reproduction |
|---|---|---|
| SwiftPM Swift 6, APIs Apple seulement, pas de dépendance tierce, `@Local` | Conforme | `Package.swift`; imports Apple et wrapper [11-17](~/fm-mini/Sources/FMMini/main.swift:11). |
| Prévol de `make-app.sh` (macOS, arm64, CLT, `/tmp/fmcheck.swift`, disponibilité du modèle) | **Non conforme — majeur** | [make-app.sh:4-26](~/fm-mini/make-app.sh:4) lance seulement `swift build`, fabrique et signe. Aucun `sw_vers`, `uname`, `xcode-select -p`, ni script `fmcheck.swift`. |
| Bundle 1.3.1, min. macOS 27, ad hoc | Conforme | `plutil -p build/FM Mini.app/Contents/Info.plist` : `1.3.1`, `27.0`; `codesign -dvvv` : `Signature=adhoc`, arm64. |
| Un commit par livraison | **Non conforme — mineur** | `git status --short` : `README.md`, `Sources/FMMini/main.swift` et `make-app.sh` sont modifiés, non commités. |
| Fenêtre 460×760, minimum 400×560, mémoire de cadre | Partiellement conforme | Valeurs et `frameAutosaveName` : [1245-1265](~/fm-mini/Sources/FMMini/main.swift:1245), [1289-1303](~/fm-mini/Sources/FMMini/main.swift:1289). Capture locale à 460×760 : en-tête centré hors défilement et tous les chips visibles. Le redimensionnement exact à 400×560 n’a pas été fiabilisé par l’automatisation, donc non vérifiable. |
| Pas d’ellipse/troncature | **Non conforme — mineur** | Le nom du fichier en puce et le badge chargé imposent `.lineLimit(1)` : [683](~/fm-mini/Sources/FMMini/main.swift:683), [695](~/fm-mini/Sources/FMMini/main.swift:695). Un nom long est donc tronqué. |
| Accueil, cinq suggestions et lien | Conforme à 460 px | Texte verbatim et grille adaptative : [752-791](~/fm-mini/Sources/FMMini/main.swift:752). Capture : heading, paragraphe, cinq contrôles et lien visibles. |
| Zone de saisie : trois lignes puis six | **Non conforme — mineur** | Seulement un cadre `minHeight: 64, maxHeight: 120` est appliqué ([702-703](~/fm-mini/Sources/FMMini/main.swift:702)); aucune mesure du contenu ni logique de croissance. La capture montre déjà une zone haute vide. |
| Disponibilité au lancement / Réglages Système | Conforme statiquement | Test de disponibilité [242-251](~/fm-mini/Sources/FMMini/main.swift:242), URL Réglages [610-619](~/fm-mini/Sources/FMMini/main.swift:610). Simulation Apple Intelligence désactivée non faite. |
| Consigne exacte, unique, sans clause document | Conforme | Une seule constante de consigne [224](~/fm-mini/Sources/FMMini/main.swift:224), utilisée à la création des sessions. |
| Document seulement au premier envoi, puis badge | Conforme statiquement | Injection conditionnelle [389-428](~/fm-mini/Sources/FMMini/main.swift:389), badge [680-700](~/fm-mini/Sources/FMMini/main.swift:680). L’autotest historique rapportait une injection `1/6`, mais la relance actuelle échoue avant ce test. |
| Jauge et seuils 60/85 % | Conforme statiquement | Comptage du transcript [491-495](~/fm-mini/Sources/FMMini/main.swift:491), couleurs [722-749](~/fm-mini/Sources/FMMini/main.swift:722), compression à `> 0.60` [530-535](~/fm-mini/Sources/FMMini/main.swift:530). |
| Compression : document intégral, résumé, deux derniers échanges | Conforme statiquement, exécution non vérifiée cette fois | Recréation de session et deux derniers tours [539-560](~/fm-mini/Sources/FMMini/main.swift:539), ordre du transcript comprimé [585-601](~/fm-mini/Sources/FMMini/main.swift:585). |
| Découpage : P/K prescrits, jamais au milieu d’une phrase | **Non conforme — majeur** | P est correct [302-304](~/fm-mini/Sources/FMMini/main.swift:302), mais une phrase trop longue est coupée par groupes de mots [153-175](~/fm-mini/Sources/FMMini/main.swift:153), donc au milieu d’une phrase. Avec le fixture : 50 paragraphes de 400 mots, P=3 510 sur ce Mac ; huit paragraphes font 3 200 mots et neuf 3 600, donc l’algorithme produit sept parties, pas `ceil(20 000 / 3 510)=6`. |
| Messages de taille, PDF scan et erreurs modèle | Conforme statiquement | Chaînes exactes [460-488](~/fm-mini/Sources/FMMini/main.swift:460). La limite utilise bien 5 000 000 octets [196-219](~/fm-mini/Sources/FMMini/main.swift:196). |
| Copie au survol et menu contextuel | Conforme statiquement ; interaction non vérifiée | Presse-papiers [181-187](~/fm-mini/Sources/FMMini/main.swift:181), cible 44 pt, délai et menu [834-900](~/fm-mini/Sources/FMMini/main.swift:834). |
| Fenêtre « Compléter l’installation », textes verbatim | **Non conforme — bloquant** | L’interface observée affiche à chaque carte `À quoi ça sert : (tool.about)`, `Vous en avez besoin si… (tool.needed)`, `Inutile si… (tool.unnecessary)`. La cause est visible à [1160-1165](~/fm-mini/Sources/FMMini/main.swift:1160) : ce sont des littéraux, pas des interpolations Swift. Les textes source existent aux [1093-1112](~/fm-mini/Sources/FMMini/main.swift:1093), mais ne sont jamais rendus. |
| Statuts locaux de cette fenêtre | Partiellement conforme | Statuts de fichiers et commandes locaux [986-1018](~/fm-mini/Sources/FMMini/main.swift:986), seul test localhost [1020-1033](~/fm-mini/Sources/FMMini/main.swift:1020). Capture : statuts résolus. Aucune limite de temps n’encadre `Process.waitUntilExit()` ; la garantie « en moins d’une seconde » n’est pas démontrée. |
| Autotest complet et sans comportement annexe | **Non conforme — majeur** | Échec direct ci-dessus ; écrit deux fichiers temporaires [1386-1412](~/fm-mini/Sources/FMMini/main.swift:1386). Les helpers DOCX/PDF [1534-1563](~/fm-mini/Sources/FMMini/main.swift:1534) ne sont jamais appelés. |

## 3. Robustesse avec les fixtures

| Cas | Résultat | Preuve / reproduction |
|---|---|---|
| `vide.txt` | Non vérifiable en UI ; pas de crash déductible | Le lecteur renvoie la chaîne vide sans la rejeter ([200-218](~/fm-mini/Sources/FMMini/main.swift:200)). Choisir ce fichier puis envoyer une question : parcours à confirmer dès que le modèle est disponible. |
| `binaire.txt` (64 KiB) | Conforme statiquement | `iconv` rejette l’UTF-8 ; le lecteur renvoie `unreadableText`, affiché « Le fichier doit être du texte UTF-8 lisible. » ([216](~/fm-mini/Sources/FMMini/main.swift:216), [478-488](~/fm-mini/Sources/FMMini/main.swift:478)). |
| `corrompu.docx` | Partiellement conforme | `unzip -t` échoue comme attendu. `NSAttributedString` lèvera une erreur ; l’UI la ramène au message générique « texte UTF-8 lisible » ([349-352](~/fm-mini/Sources/FMMini/main.swift:349)), inadapté à un DOCX corrompu mais non modal. |
| `scan-sans-texte.pdf` | Conforme | Exécution PDFKit : `PDFKit characters: 0`. Le garde [210-214](~/fm-mini/Sources/FMMini/main.swift:210) déclenche ensuite le message dédié exact et n’attache pas le fichier. |
| `4_9Mo.txt` / `5_1Mo.txt` | Conforme statiquement ; UI non vérifiée | Tailles mesurées : 4 900 000 et 5 100 000 octets. Comparaison `<= 5_000_000` [198-203](~/fm-mini/Sources/FMMini/main.swift:198), format décimal `bytes / 1_000_000` et virgule [478-483](~/fm-mini/Sources/FMMini/main.swift:478) : le second donnera bien `5,1 Mo`. |
| `long-20000-mots.txt` | **Non conforme — majeur** | `wc -w` = 20 000, 50 blocs de 400 mots. Voir défaut K=7 et coupe de phrase dans la section 2. |
| `arabe.txt` / RTL | Non vérifiable | UTF-8 valide (25 mots). La vue `Text` n’impose ni alignement ni direction RTL ([853-855](~/fm-mini/Sources/FMMini/main.swift:853)); l’absence de casse visuelle doit être testée à l’écran. |
| Collage de 50 000 caractères | Non vérifiable | Aucun plafond dans `NSTextView` ([1191-1243](~/fm-mini/Sources/FMMini/main.swift:1191)), mais aucun essai de charge n’a pu être conduit. |
| Envoi pendant flux / double clic | Partiellement conforme statiquement | `send()` protège `isSending` et vide l’entrée avant la tâche ([389-400](~/fm-mini/Sources/FMMini/main.swift:389)); le bouton est désactivé pendant le flux ([705-710](~/fm-mini/Sources/FMMini/main.swift:705)). Essai réel non possible, modèle indisponible au CLI. |
| Nouvelle conversation pendant flux | Partiellement conforme statiquement | Le bouton est désactivé [636-638](~/fm-mini/Sources/FMMini/main.swift:636), mais `newConversation()` lui-même n’a pas de garde de flux ([254-267](~/fm-mini/Sources/FMMini/main.swift:254)). |
| Emoji dans une bulle | Non vérifiable | `Text` et presse-papiers utilisent `String`; aucun essai de rendu n’a abouti. |
| Apple Intelligence désactivée / devient indisponible | Non vérifiable | Cas de lancement traité [242-251](~/fm-mini/Sources/FMMini/main.swift:242). En cours de session, l’erreur est seulement mise dans le chat [443-445](~/fm-mini/Sources/FMMini/main.swift:443) ; simulation non réalisable sans modifier l’état système. |

## 4. Sécurité et vie privée

### Écritures disque — **majeur : non conforme pour `--autotest`**

**Preuve.** Hors autotest, le seul stockage explicite de l’app est le cadre de fenêtre via `UserDefaults` ([1253-1278](~/fm-mini/Sources/FMMini/main.swift:1253)). Il n’existe aucune écriture de `messages`, `turns` ou `attachment.content` dans le parcours normal. Les découpes `DocumentPart` ne sont que des valeurs Swift en mémoire ([53-60](~/fm-mini/Sources/FMMini/main.swift:53)).

En revanche, `--autotest` crée son rapport dans `~/fm-mini` ([1341-1359](~/fm-mini/Sources/FMMini/main.swift:1341)) **et** laisse deux textes de test dans `FileManager.default.temporaryDirectory` ([1386-1389](~/fm-mini/Sources/FMMini/main.swift:1386), [1409-1412](~/fm-mini/Sources/FMMini/main.swift:1409)). Cela viole explicitement « n’écrit que son rapport ».

**Reproduction.** Exécuter `.build/release/FMMini --autotest`, puis rechercher les chemins `fm-mini-autotest-300-mots.txt` et `fm-mini-autotest-20k-mots.txt` dans le répertoire temporaire. La relance de cet audit a aussi produit/écrasé `autotest-2026-11-02.txt`, comme prévu par le code.

### Permissions, signature, Gatekeeper — **mineur**

**Preuve.** `codesign -d --entitlements :-` ne renvoie aucune entitlement ; le code ne demande pas de permission système, seulement un fichier choisi par `NSOpenPanel`. Le bundle est signé ad hoc (`Signature=adhoc`, pas de TeamIdentifier). `codesign --verify --deep --strict` réussit. `spctl --assess` a renvoyé ici une erreur interne du sous-système de signature, pas un verdict Gatekeeper.

README.md explique le clic droit → Ouvrir ([README.md:46](~/fm-mini/README.md:46)), mais ne dit ni que la signature est ad hoc, ni que Gatekeeper peut bloquer l’ouverture initiale pour cette raison. La documentation demandée est donc incomplète.

## 5. Accessibilité et langue

### Accessibilité — **majeur : partiellement vérifiable**

**Preuve.** L’arbre d’accessibilité de l’accueil expose des libellés pour les cinq suggestions, « Nouvelle conversation », « Joindre un fichier… », « Envoyer » et le lien d’installation. Le retrait de pièce jointe a explicitement le libellé « Retirer le fichier » ([685-687](~/fm-mini/Sources/FMMini/main.swift:685)). Les parties surdimensionnées reprennent leur texte dans le bouton ([914-924](~/fm-mini/Sources/FMMini/main.swift:914)).

Le champ `NSTextView` n’a pas de libellé d’accessibilité explicite ([1198-1210](~/fm-mini/Sources/FMMini/main.swift:1198)); l’arbre le nomme seulement « text entry area ». VoiceOver complet, l’ordre Tab, la sélection partielle puis Cmd-C, et le menu contextuel n’ont pas pu être exécutés de façon fiable avec le pilote disponible. Le code traite Entrée et Maj-Entrée ([1234-1242](~/fm-mini/Sources/FMMini/main.swift:1234)) et laisse la sélection native dans les bulles ([853-855](~/fm-mini/Sources/FMMini/main.swift:853)).

Le contraste ≥ 4,5:1 n’est **pas vérifiable** par inspection : plusieurs textes emploient `Color.secondary` et les couleurs système dépendent du rendu macOS ; aucune mesure colorimétrique n’a été produite.

### Français visible — **bloquant pour la fenêtre d’installation ; mineur ailleurs**

**Preuve.** La fenêtre d’installation affiche les trois littéraux erronés cités en section 2 : c’est une erreur visible sur toutes les cartes. Les chaînes françaises contiennent par ailleurs des espaces ordinaires avant une ponctuation double, alors que le dossier d’audit demande les espaces insécables : par exemple le paragraphe d’accueil [768](~/fm-mini/Sources/FMMini/main.swift:768), l’indication de fichier [288](~/fm-mini/Sources/FMMini/main.swift:288), les messages « document chargé : » [694](~/fm-mini/Sources/FMMini/main.swift:694) et « Conversation compressée : » [560](~/fm-mini/Sources/FMMini/main.swift:560). Le contenu de réponse du modèle reste, par nature, non auditable linguistiquement.

## 6. README

### Parcours non-développeur — **partiellement conforme**

**Preuve.** Les prérequis, les trois étapes de lancement, le clic droit Gatekeeper, les formats, les limites, les langues, le ralentissement et le découpage figurent clairement dans README.md ([README.md:8](~/fm-mini/README.md:8) à [README.md:53](~/fm-mini/README.md:53)). `make-app.sh` est exécutable.

Le texte de dépannage couvre bien l’erreur `ModelManagerServices` effectivement rencontrée pendant cet audit ([README.md:46](~/fm-mini/README.md:46)). En revanche :

- il promet que l’autotest vérifie DOCX, PDF, PDF sans texte et taille 5 Mo ([README.md:53](~/fm-mini/README.md:53)), alors que ces helpers ne sont jamais appelés ;
- il ne prévient pas que l’autotest laisse des fichiers temporaires ;
- il ne documente pas la signature ad hoc ;
- les prérequis sont listés mais le script ne les contrôle pas : le parcours « fonctionne du premier coup » n’est pas établi.

**Reproduction.** Suivre les trois étapes, puis exécuter l’autotest indiqué : il échoue ici dès le premier appel modèle avec l’erreur reproduite en section 1.

## Exigences non vérifiables dans cet audit et pourquoi

- Cinq minutes d’activité avec document joint sans socket, puis le même essai Wi-Fi coupé : la coupure Wi-Fi perturberait le poste et le relevé complet n’a pas été autorisé/obtenu ; seul un instantané `lsof` a été fait.
- Médiane de dix réponses courtes sur conversations vierges : le modèle échoue dans l’exécutable headless avec `ModelManagerServices.ModelManagerError 1008`.
- Rendu exact à 400×560, absence visuelle de troncature dans tous les cas, RTL arabe, emoji, collage de 50 000 caractères, et comportement pendant flux : le pilote GUI n’a pas permis de saisir/joindre les fixtures après l’échec du chemin modèle.
- Simulation d’Apple Intelligence désactivée ou de modèle devenu indisponible : elle exige une modification d’état système hors périmètre d’un audit non destructif.
- Contraste mesuré, navigation VoiceOver et Cmd-C sur une sélection partielle : aucune sonde VoiceOver/colorimétrique utilisable n’était disponible.
- Effet Gatekeeper final : `spctl` a échoué dans son propre sous-système au lieu de fournir un verdict.
