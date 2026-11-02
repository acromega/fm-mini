# AUDIT de conformité et de sûreté — FM Mini 1.3.1

Auditeur : Claude (session Claude Code), 2 novembre 2026, 12 h 48 → 13 h 45.
Machine : macOS 27.2 (26B123), Apple Silicon, Command Line Tools seuls (Swift 6.4.2), modèle `available`, contextSize 8 192, LM Studio actif sur le port 1234.

## Verdict (trois lignes)

1. **Non distribuable tel quel** (version 1.3.1 = commit `62cf2e4`, binaire construit par `./make-app.sh` à 12 h 52).
2. Distribuable **après correctifs** : B1 fenêtre « Compléter l'installation » (textes des cartes non affichés), B2 requête `localhost:1234` émise au lancement de l'app, M1 `make-app.sh` sans contrôle de prérequis, M2 clic droit sur le texte d'une bulle = menu système anglais, M3 Tab piégé dans la zone de saisie, M4 texte saisi perdu sur « conversation pleine », M5 conseil Gatekeeper du README inopérant, M6 puces de parties tronquées par « … ».
3. Les promesses de l'accueil sont tenues à l'exécution (aucune connexion sortante hors localhost, latence médiane 400 ms, 24 langues issues de `supportedLanguages`) ; aucun plantage ni gel sur les 13 scénarios de robustesse.

## Périmètre figé et évolution du dépôt pendant l'audit (à lire d'abord)

- **Cible auditée** : état du dossier au démarrage (HEAD `9fbc259` + modifications non commitées), que l'agent Codex a commité à 13 h 02 sous `62cf2e4` « WIP before audit fixes ». Vérifié : `git archive 62cf2e4` donne `Sources/FMMini/main.swift` de 76 197 octets / 1 565 lignes, identique au source lu et compilé. **Toutes les références `main.swift:N` ci-dessous sont relatives à `62cf2e4`.**
- **Dépôt modifié en parallèle** : entre 13 h 02 et 13 h 16, un autre agent a commité sept correctifs (`8716300` → `ca61989`, version **1.3.3**), reconstruit `build/FM Mini.app` (13 h 16) et écrit un `AUDIT-RAPPORT.md` (12 h 59). Ces correctifs **n'ont pas été ré-audités** ; une colonne « 1.3.3 » signale seulement ce que le diff prétend corriger.
- **`SPEC.md` écrasé** : à 12 h 56 le fichier `SPEC.md` (10 251 octets) a été remplacé par une page HTML de 675 Ko (`file SPEC.md` → « HTML document », dossier `SPEC_files/` créé). **Gravité : majeur (dossier)**. La spécification lue à 12 h 48 a été reconstituée à l'octet près (10 251 octets) dans `<scratchpad de session>/SPEC-recupere-12h48.md` ; elle n'a pas été réécrite dans le dépôt (aucune modification de fichier existant).
- **Pourquoi ce rapport s'appelle `AUDIT-RAPPORT-claude.md`** : le nom demandé `AUDIT-RAPPORT.md` était déjà occupé par le rapport d'un autre agent ; l'écraser aurait détruit son travail. Rien n'est commité.
- Environnement : trois processus `FMMini` lancés vers 1 h 11–1 h 21 (dont `/private/tmp/FM Mini Audit.app`) tournaient déjà avant l'audit ; ils n'ont pas été touchés et n'appartiennent pas au binaire audité.

Outils utilisés (tous dans le scratchpad, aucun ajout au dépôt) : petit binaire `AXUIElement` (lecture d'arbre d'accessibilité, clic souris CGEvent, saisie AXValue), `screencapture -l <CGWindowID>`, `lsof -nP -i -a -p PID` échantillonné, `find ~/Library -newer`, scripts Swift (`supportedLanguages`, découpage, contraste pixel).

---

## 1. Vérité des promesses

### 1.1 Réseau — statique

- `grep -nE 'URLSession|URLRequest|NWConnection|import Network|socket\(|Process\(|curl'` sur `main.swift` : un seul point réseau, `main.swift:1021-1028` (`URLSession` éphémère vers `http://localhost:1234/v1/models`, timeout 0,5 s) ; `Process()` à `main.swift:1006` pour `/usr/bin/which apfel`, `xcode-select -p` et `/usr/bin/env python3 -c "import apple_fm_sdk"`. Aucun `curl`, aucun socket, aucun `import Network`. **Conforme** pour le périmètre « seul appel autorisé ».

### 1.2 Réseau — exécution

- **B2 — Bloquant : la requête `localhost:1234` est émise au lancement de l'app, fenêtre « Compléter l'installation » fermée.**
  Preuve : `open "build/FM Mini.app"` puis `lsof -nP -i -a -p PID` toutes les 200 ms :
  ```
  t=400ms sockets=[FMMini 42392 … TCP 127.0.0.1:54209->127.0.0.1:1234 (ESTABLISHED)]
  … (même socket jusqu'à t=4000ms)
  windows: FM Mini          ← seule fenêtre ouverte
  ```
  Cause (lecture) : `InstallationView` déclare `@Local private var model = InstallationModel()` (`main.swift:1090`) et la scène `Window("Compléter l'installation")` (`main.swift:1298`) instancie la vue au démarrage ; `InstallationModel.init` lance `checkAll()` (requête HTTP + trois `Process`). Contredit SPEC « only while the window is open » et le pied de fenêtre « Toutes ces vérifications sont faites sur votre Mac ». Reproduction : LM Studio lancé avec serveur actif, ouvrir l'app, `lsof -i :1234` dans la seconde.
  Patch ≤ 3 lignes : créer `InstallationModel` dans `.onAppear` de `InstallationView` (ou `.task {}`) au lieu de l'initialiseur de `@Local`.
  Statut 1.3.3 : non traité par les commits lus.
- Aucune autre connexion : moniteur `lsof` à 1 s pendant 7 min (12 h 55 → 13 h 02, latence + fixtures) → `net.log` vide ; échantillonnage pendant la question avec document joint « Wi-Fi coupé » → 0 socket ; fenêtre d'installation ouverte via le menu Aide à 13 h 2x → aucun socket nouveau (la vérification a déjà eu lieu au lancement).
- **Wi-Fi coupé : non concluant (remarque).** Le Wi-Fi (`en1`) était déjà **éteint** avant l'audit, le Mac étant sur Ethernet (`en0`, route par défaut 192.168.1.254). Le couper n'isole donc pas la machine ; couper l'Ethernet exige `sudo`. L'état initial (Wi-Fi off) a été rétabli. La preuve d'absence de réseau repose sur `lsof` (0 socket) pendant les deux questions avec `court-312-mots.txt` joint (réponses 2 209 ms et 626 ms).

### 1.3 Langues

- `SystemLanguageModel.default.supportedLanguages` (script Swift, exécuté hors Terminal.app sans l'erreur `ModelManagerServices` citée par le README) : **24** entrées (fr, fr-CA, en-US/GB/AU/IN, es/es-US/es-419, pt-BR/pt-PT, zh-Hans/zh-HK/zh-TW, de, it, ja, ko, nl, da, nb, sv, tr, vi). Le chiffre « 24 » de l'accueil (`main.swift:777`) est codé en dur mais exact sur cette machine. **Conforme**.
- Menu « Traduire en… » : `main.swift:306-313` déduplique par `languageCode`, nomme en français, trie → 15 entrées (allemand, anglais, chinois, coréen, danois, espagnol, français, italien, japonais, néerlandais, norvégien bokmål, portugais, suédois, turc, vietnamien). **Conforme** (source = `supportedLanguages`). Remarque : « français » figure dans le menu de traduction.

### 1.4 Latence (10 questions courtes, conversation vide à chaque fois, ms affichés par l'app)

| Question | ms |
|---|---|
| Bonjour | 484 |
| Quelle est la capitale de la France ? | 412 |
| Donne un synonyme de rapide. | 341 |
| Traduis en anglais : bonjour tout le monde. | 329 |
| Combien font 2 et 3 ? | 387 |
| Écris une phrase sur la mer. | 631 |
| Corrige : je suis aller au marché. | 376 |
| Quel jour vient après lundi ? | 435 |
| Résume en trois mots : le chat dort sur le canapé. | 327 |
| Dis merci en espagnol. | 439 |

Médiane **400 ms** (< 1,5 s attendu). **Conforme**. Remarque (modèle, pas l'app) : « Dis merci en espagnol » → « Merci en espagnol, cela signifie « merci ». ».

### 1.5 « Gratuit », « 100 % local »

Aucun achat, aucun compte, aucune clé. Preuves réseau ci-dessus. **Conforme**, sous réserve de B2 (appel localhost non annoncé au lancement).

---

## 2. Conformité à SPEC.md

Tableau exigence par exigence (C = conforme, NC = non conforme, NV = non vérifiable). Gravité entre crochets pour les NC.

| Exigence SPEC | Statut | Preuve |
|---|---|---|
| Prérequis vérifiés par le script de build (macOS ≥ 27, arm64, CLT, script Swift de disponibilité) | **NC [majeur M1]** | `make-app.sh` @62cf2e4 : 27 lignes, aucun `sw_vers`, `uname`, `xcode-select` ni script Swift. Statut 1.3.3 : `8c462c0` ajoute ces contrôles (non ré-audité). |
| Build SwiftPM, Swift 6, sans dépendance, `@Local`, pas de macro | C | `Package.swift` (tools 6.4, macOS 27, aucune dépendance) ; `main.swift:11-17`. Build : `./make-app.sh` → « Build complete! (22,29 s) », app signée ad hoc, commande `open` imprimée. |
| Info.plist (id, version, LSMinimumSystemVersion 27.0, HiDPI) | C | `make-app.sh:13-24` ; `codesign -dvv` → `Identifier=org.local.fmmini`, `Signature=adhoc`. |
| « Un commit par changement livré » | NC [mineur] | Au démarrage, 1.3.1 (277 lignes de `main.swift`, README, make-app) était non commité ; commité ensuite par Codex sous `62cf2e4`. |
| Fenêtre 460×760 par défaut, min 400×560, mémorisée, centrée | C | AX : `FM Mini 730,103 460x760` ; `set size {400,560}` → 400×592 (560 de contenu + barre de titre) ; `{300,400}` refusé ; `defaults read org.local.fmmini` → `NSWindow Frame FMMiniWindow`. |
| Lisible à 400 px, sans troncature « … » | **NC [majeur M6]** | Capture `50-oversized-card.png` à 460 px : les 7 puces « Partie i/7 — mots … — « SECTION … L… » » sont tronquées par une ellipse (`OversizedDocumentCard`, `main.swift:912-921`, `Text` sans `fixedSize`). Accueil, chat, badge : pas de troncature observée. |
| En-tête centré, wordmark, sous-titre, bouton, jauge grise/orange/rouge | C | Capture `01-welcome-460x760.png` ; `main.swift:742-746` (seuils 0,60 / 0,85) ; texte « 74 / 8 192 jetons » recalculé après chaque tour (observé 103 → 2 524 → 5 277). |
| Accueil : titre, paragraphe verbatim, 5 puces, lien, visible sans défilement à 460×760 | C (remarque) | AX : paragraphe identique au mot près ; 5 puces + lien ; capture 01 : tout visible. Remarque : apostrophes typographiques « ’ » dans l'app contre « ' » dans SPEC (paragraphe, puces, lien, message de découpage). |
| « Traduire en… » depuis `supportedLanguages`, dédupliqué, trié, insère « Traduis en <langue> : » | C | `main.swift:306-313`, `799`. Remarque : rendu avec deux chevrons (système + `chevron.down` ajouté, `main.swift:822`). |
| Puce « Joindre un document… » → sélecteur puis « Liste les points importants de ce document. » | C | `main.swift:800-802`, `321-324`. |
| Bulles (gris / blanc bordé, ≤ 85 %, texte sélectionnable, auto-défilement, ms) | C (remarque) | Captures 20, 41. Largeur limitée par `Spacer(minLength: 65)` (`main.swift:851,888`), soit ≈ 84 % à 460 px mais > 85 % sur une fenêtre élargie. |
| Survol → bouton « Copier » (doc.on.doc, cible 44 pt), copie, « Copié » 1,5 s | C (mineur) | Survol → `AXButton «Copier»` ; clic → presse-papiers = texte de la bulle ; « Copié » puis retour « Copier » après 2 s. Mineur : le bouton recouvre la fin du texte des bulles courtes (captures 70, 73 : « de maison. » masqué) ; la cible 44 pt est un `.frame` externe au `Button` (`main.swift:880`), zone cliquable réelle = étiquette. Le bouton reste affiché sur une bulle quand le pointeur est parti (capture 72). |
| Clic droit → menu contextuel « Copier » | **NC [majeur M2]** | Clic droit **sur le texte** (zone principale) → menu système de `NSTextView` en anglais : Cut / Copy / Paste / Font / Spelling and Grammar… (capture `72-context-menu.png`) ; le `.contextMenu` (`main.swift:885`) n'apparaît qu'en cliquant hors du texte, p. ex. sur « 591 ms » (capture 73). Cause : `.textSelection(.enabled)` (`main.swift:854`). Reproduction : poser une question, clic droit sur la réponse. |
| Flux (`streamResponse`) | C | `main.swift:434` ; texte vu croître pendant les réponses longues. |
| Saisie 3→6 lignes, Entrée = envoi, Maj-Entrée = retour, « Joindre un fichier… », types acceptés | C (remarque) | Maj-Entrée → `ligne1⏎ligne2` ; Entrée envoie. `main.swift:1237` : tout retour sans Maj envoie (Cmd/Option-Entrée aussi) ; pavé numérique (code 76) insère un retour. Hauteur `minHeight 64 / maxHeight 120` (`main.swift:703`). |
| Ligne d'aide « Fichiers acceptés : … jusqu'à environ N mots », N = contextSize × 0,9 / 1,4 arrondi à la centaine | C | Affiché « … jusqu’à environ 5 300 mots » ; 8192×0,9/1,4 = 5 266 → 5 300. |
| « Envoyer » désactivé pendant le flux ou saisie vide | C (remarque) | AX `enabled=0` à vide ; libellé devient « Réponse… » pendant le flux (`main.swift:708`, non prévu par SPEC). |
| Indisponibilité au lancement : raison exacte + bouton Réglages | NV / remarque | Non simulé (voir § 7). Code : `String(describing: reason)` (`main.swift:247`) → nom de cas anglais (ex. `appleIntelligenceNotEnabled`), affiché après « Le modèle Apple n’est pas disponible : ». |
| Consigne de session exacte et unique | C | `main.swift:224` ; `newSession()` (`main.swift:516-527`) n'utilise que cette consigne ; aucun autre texte d'instruction (grep `instructions:`). |
| Clause document injectée uniquement avec pièce jointe, une seule fois, format exact | C | `main.swift:392-397` (texte identique à SPEC), `isPendingInjection` passé à `false` après le premier envoi (`main.swift:427-429`). Observé : badge « document chargé : compte-rendu-comite-des-fetes.docx (993 jetons) » ; 11 questions suivantes, jauge +≈400 jetons/tour (pas de réinjection) ; autotest 12 h 29 « injection 1/6 ». |
| Charger un autre fichier remplace et réinjecte une fois | C (remarque) | `main.swift:336-342` : si le précédent était injecté, la **conversation est effacée** (`messages = []`) — non demandé par SPEC. |
| Lecture txt/md/csv/json/log (UTF-8), rtf/docx (NSAttributedString), pdf (PDFKit) ; messages scan / trop lourd verbatim | C | `main.swift:201-216`, `480-488` ; § 3. |
| Contrôle avant envoi (a) fichier seul > 90 % → carte, P et K, coupe sur titres/lignes vides, jamais au milieu d'une phrase, puces, badge partie, rien sur disque | **partiel [mineur]** | P = 3 510 (`main.swift:303`) C. **K** = nombre de blocs empaquetés, pas `ceil(mots/P)` : `long-20000-mots.txt` → carte « découpé en 7 parties » alors que ceil(20 000/3 510) = 6 (script reproduisant `DocumentSplitter` : 6 parties de 3 200 mots + 1 de 800). « Jamais au milieu d'une phrase » : NC marginal — `sentenceFragments` (`main.swift:153-180`) coupe une phrase plus longue que P en tranches de P mots ; pour la fixture, les parties finissent au milieu d'une phrase parce que **les lignes de la fixture elles-mêmes** se terminent mi-phrase (« …apprendre et ») et que la coupe se fait sur ligne vide, conformément à l'autre règle. Rien sur disque : C (grep écriture § 4). Statut 1.3.3 : `6c25a35` garde les phrases longues entières ; K inchangé. |
| (b) Compression > 60 % : résumé greedy sur tous les échanges sauf les deux derniers, session neuve, document verbatim + résumé + 2 derniers échanges, ligne système, bulles conservées | C (remarque) | Observé : jauge 5 277/8 192 (64 %) → ligne « Conversation compressée : 5277 → 2158 jetons (le document est conservé en entier). », badge intact, bulles conservées (capture 41), « Quelle était ma première question ? » → « Votre première question était : « Liste les points importants de ce document. » ». Code `main.swift:530-566`. Remarques : SPEC dit « ask the current session » ; le code résume dans une session séparée sans le document (`compressionSourceSession`, `main.swift:567`) ; les nombres de la ligne système n'ont pas de séparateur de milliers (jauge « 5 277 », ligne « 5277 ») ; suffixe « (le document est conservé en entier) » omis sans document (`main.swift:559`). |
| Si toujours > 85 % → carte « La conversation est pleine (N / M jetons). » + 2 boutons | C (mineur) | `main.swift:549-553`, `420-422`. Mineur : avec ≤ 2 échanges et ≥ 85 % (ex. collage de 50 000 caractères), pas de carte avant envoi mais seulement « Conversation presque pleine. » dans la jauge (`main.swift:532-534`, `737`), texte hors SPEC. Le bouton « Nouvelle conversation en gardant le document » est proposé même sans document (observé après le collage). |
| Erreurs en ligne, jamais modales, mapping `LanguageModelError` | C (code) / NV (exécution) | `main.swift:461-475` textes identiques ; `GenerationError` absent. Aucune erreur modèle n'est survenue pendant l'audit (garde-fous non déclenchés). |
| Fenêtre « Compléter l'installation » : menu Aide + lien, 520×680, 4 sections, cartes (nom, point, 3 textes, Ouvrir), vérifications locales, pied verbatim | **NC [bloquant B1]** | AX de la fenêtre : chaque carte affiche littéralement « À quoi ça sert : (tool.about) », « Vous en avez besoin si… (tool.needed) », « Inutile si… (tool.unnecessary) » (capture `90-installation.png`). Cause : antislash manquant, `main.swift:1160,1162,1165` ; `strings` du binaire contient « a sert : (tool.about) ». Reproduction : menu Help → « Compléter l’installation… ». Patch : `"À quoi ça sert : \(tool.about)"` (idem ×3). Statut 1.3.3 : corrigé par `8716300` (non ré-audité). Le reste : 520×680 C ; sections C (titre 1 étendu « …, rien à installer ») ; statuts résolus en 0,07 s à l'ouverture (car calculés au lancement, voir B2) ; pied verbatim C ; textes « verbatim du prompt 1.3.1 » **NV** (prompt non fourni). « Raccourcis » : statut `.detected` codé en dur (`main.swift:994`), non vérifié localement [mineur]. |
| Vie privée (§ 4) | voir § 4 | |
| Autotest : tests 0,1,2,3,8,9,12 + fenêtre d'installation, n'écrit que le rapport | **partiel [mineur]** | Rapport 12 h 29 (1.3.1) : 0,1,2,3,8,9,12 présents et OK ; « installation window … statuses within 1 s » absent de l'autotest. Écrit **deux fichiers temporaires** dans `$TMPDIR` (`main.swift:1387-1388`, `1409-1411`), jamais supprimés, et modifie le presse-papiers (`main.swift:1403`). Rapport écrit à `~/fm-mini/autotest-<date>.txt` codé en dur (`main.swift:1346-1349`) : silencieusement absent si le dossier a été copié ailleurs. Le drapeau n'active rien d'autre (`main.swift:1321-1331`). Statut 1.3.3 : `60246f9` supprime les fichiers temporaires et ajoute des tests fixtures. |
| README (§ 6) | voir § 6 | |

---

## 3. Robustesse (audit-fixtures/)

Tous les scénarios : **aucun plantage, aucun gel** (processus 42392 vivant du début à la fin, UI toujours réactive sauf lenteur notée pour 4,9 Mo).

| Scénario | Résultat | Preuve / reproduction |
|---|---|---|
| `vide.txt` | Accepté comme pièce jointe « vide.txt · 1 jetons » | AX après sélection. Remarque : « 1 jetons » (pluriel) ; SPEC muette sur le fichier vide. |
| `binaire.txt` | « Le fichier doit être du texte UTF-8 lisible. », non joint | Capture `11-binaire.png`, `main.swift:214,487`. |
| `corrompu.docx` | « Le fichier doit être du texte UTF-8 lisible. », non joint | Message trompeur pour un .docx (erreur `NSAttributedString` capturée par le `catch` générique `main.swift:351-352`) [mineur]. 1.3.3 : `f42ae41` ajoute « Ce fichier est illisible (document endommagé ?) ». |
| `scan-sans-texte.pdf` | « Ce PDF ne contient pas de texte lisible (scan) : il faudrait d'abord le passer par la reconnaissance de texte. », non joint | Texte identique à SPEC. |
| `5_1Mo.txt` (5 100 000 o) | « Fichier trop lourd (5,1 Mo, maximum 5 Mo) », non joint | `maximumBytes = 5_000_000` (`main.swift:198`), division par `1_000_000` (`main.swift:481`) : Mo = 10⁶ dans le code et le message. **Conforme**. |
| `4_9Mo.txt` (4 900 000 o, 687 720 mots) | Accepté ; chip après 6,3 s (816 668 jetons) ; après Entrée, carte « 687 720 mots (816 668 jetons) … découpé en 197 parties » après **29 s** ; 26 puces rendues (liste paresseuse) ; RSS 270 Mo | Pendant les 29 s, lectures AX jusqu'à 1,6 s (interface ralentie, pas gelée), aucun indicateur d'attente [mineur]. « Nouvelle conversation » ensuite : 0,1 s. |
| `long-20000-mots.txt` | Carte « Ce document fait 20 000 mots (25 073 jetons). Je ne peux lire qu’environ 3 510 mots à la fois … Je l’ai découpé en 7 parties … » ; 7 puces ; question restituée dans la saisie ; « Partie 2/7 » → badge « long-20000-mots.txt — partie 2/7 (4 012 jetons) », réponse « La première section de ce document est la section 9. » (correct) ; « Partie 7/7 » → « Nouvelle partie chargée : la conversation a été réinitialisée. » | Capture 50, 51. K = 7 ≠ 6 (voir § 2). Puces tronquées (M6). Changer de partie efface la conversation (non prévu par SPEC, remarque). |
| `arabe.txt` | Joint (44 jetons) ; traduction correcte. Paragraphe arabe envoyé comme message : bulle alignée à droite, texte de droite à gauche, mise en page intacte | Capture `21-arabe-emoji.png`. |
| Collage de 50 000 caractères | Saisie instantanée (0,04 s), lecture AX 0,03 s ; Entrée → « La conversation est pleine (9195 / 8192 jetons). » en 0,4 s avec les deux boutons | **M4 [majeur] : la zone de saisie est vidée** (`input = ""` `main.swift:399` avant les contrôles ; restauration seulement pour la carte de découpage `main.swift:413`) → les 50 000 caractères sont perdus. Reproduction : coller > ~9 000 jetons, Entrée. Patch : `self.input = question` avant le `return` de `main.swift:420-423`. |
| Envoi pendant un flux | Entrée ignorée, « Envoyer » désactivé (« Réponse… »), « Nouvelle conversation » et « Joindre un fichier… » désactivés | `main.swift:385,708,662,705`. Remarque (code) : entre le clic et `isSending = true` (`main.swift:432`) il y a plusieurs `await tokenCount` ; pendant cette fenêtre (longue avec un gros document) un second envoi ou « Nouvelle conversation » restent possibles. Non reproduit à la main. |
| Double-clic / triple Entrée sur « Envoyer » | Une seule bulle « Dis bonjour. » | La saisie est vidée synchroniquement avant la tâche (`main.swift:399`). |
| « Nouvelle conversation » pendant un flux | Impossible (bouton désactivé) | `main.swift:662`. |
| Emoji | « ☕🎉🚀🇫🇷 » rendu correctement, 477 ms | Capture 21. |
| Apple Intelligence désactivé | **Non vérifié** (voir § 7) | Code : `main.swift:242-250` affiche la raison et le bouton Réglages. |
| Modèle indisponible en cours de session | **Non vérifié** (voir § 7) | Code : disponibilité lue une seule fois à l'init ; une erreur de session serait affichée en ligne (`main.swift:445-447`), aucune surveillance ensuite. |
| Fenêtre « Compléter l'installation » ouverte/fermée plusieurs fois | OK | Aucune nouvelle requête (vérification faite une fois au lancement). |

---

## 4. Sécurité et vie privée

| Point | Statut | Preuve |
|---|---|---|
| Rien sur disque hors préférences | C (remarque) | `find ~/Library -newer marker` avant/après 45 min d'usage (document, 20 questions, fenêtre d'installation, quitter) : seul fichier attribuable à l'app = `~/Library/Preferences/org.local.fmmini.plist` (clés `NSWindow Frame FMMiniWindow`, `… installation`, `… GoToSheet`, `NSNavPanel…`, `NSOSPLastRootDirectory` — ces deux dernières écrites par `NSOpenPanel`). Pas de `Saved Application State`, pas de `Caches/org.local.fmmini`, pas de conteneur. (Écritures des démons système `IntelligencePlatform`, `Shortcuts/ToolKit` constatées : non attribuables à l'app.) |
| Pas de journal avec le texte des conversations | C | `grep -nE 'print\(|NSLog|os_log|Logger'` : aucune occurrence hors `AutoTest` (`main.swift:1355`, stdout + rapport, par conception). |
| Découpage en mémoire | C | `DocumentSplitter` (`main.swift:65-182`) ne touche pas `FileManager` ; grep `write(to`/`createFile` : seulement `AutoTest`. |
| Aucune permission système demandée | C | Aucune clé `NSxxxUsageDescription` dans `Info.plist`, pas d'entitlement (`codesign -d --entitlements -` vide) ; aucune boîte TCC pendant l'audit. Remarque : sur un Mac **sans** Command Line Tools, `/usr/bin/env python3` (`main.swift:1000`) lancé au démarrage (B2) déclenche la boîte système « python3 requiert les outils de développement » ; non reproductible ici (CLT installés). |
| Signature ad hoc et effet Gatekeeper documentés | **NC [majeur M5]** | `codesign -dvv` : `Signature=adhoc`, `TeamIdentifier=not set` ; `spctl -a -t exec -vv` → `rejected` (avec ou sans quarantaine). Copie de l'app avec attribut `com.apple.quarantine` puis `open` → boîte CoreServicesUIAgent : « Élément « FM Mini » non ouvert — Apple n’a pas pu confirmer que « FM Mini » ne contenait pas de logiciel malveillant… », boutons **« Placer dans la corbeille » / « Terminé »** uniquement. Le conseil du README 1.3.1 (« clic droit → Ouvrir ») n'existe plus sur ce macOS ; le passage obligé est Réglages Système → Confidentialité et sécurité → « Ouvrir quand même ». Le README ne mentionne pas que la signature est ad hoc. Statut 1.3.3 : `ca61989` réécrit ce paragraphe (non ré-audité). |
| `--autotest` sans comportement caché, n'écrit que son rapport | partiel [mineur] | Voir § 2 : deux fichiers temporaires + presse-papiers remplacé par « Copie de bulle FM Mini ». Run de contrôle à 13 h 35 effectué **avec le binaire 1.3.3** reconstruit par l'autre agent (58 s, exit 0, rapport = stdout, aucun fichier temporaire) ; le rapport original de 12 h 29 a été sauvegardé puis restauré à l'identique. |
| Processus externes | remarque | `which`, `xcode-select`, `python3` lancés au démarrage (B2) ; `commandSucceeds` attend sans timeout (`main.swift:1006-1016`) — un `python3` lent bloquerait un thread du pool, pas l'interface. |

---

## 5. Accessibilité et langue

| Point | Statut | Preuve |
|---|---|---|
| Libellé VoiceOver des boutons et puces | C | Arbre AX : `AXButton desc=«Nouvelle conversation»`, puces `«Résume ce texte en trois phrases : »`, `«Corrige…»`, `«Reformule…»`, `AXMenuButton «Traduire en…»`, `«Joindre un document et en lister les points importants»`, lien `«Aller plus loin → Compléter l’installation»`, `«Joindre un fichier…»`, `«Envoyer»`, `«Retirer le fichier»` (`main.swift:688`), `«Copier»`, `«Ouvrir»`, puces de parties avec leur texte complet. |
| Éléments sans libellé | mineur | Zone de saisie : `AXTextArea desc=«» title=«»` (aucun `accessibilityLabel`) ; jauge `AXProgressIndicator desc=«»` ; le pastille de statut (`Circle`) de la fenêtre d'installation n'est pas exposée (le texte « détecté / non détecté » l'est). |
| Navigation clavier : Tab | **NC [majeur M3]** | Depuis la zone de saisie, 8 × Tab → le focus reste sur `AXTextArea` et la valeur devient `\t\t\t…` (tabulations insérées). Aucun bouton n'est atteignable au clavier depuis le champ ; `SendTextView` (`main.swift:1232-1241`) n'intercepte que Entrée. Reproduction : cliquer dans le champ, Tab. |
| Entrée / Maj-Entrée / Cmd-C | C | Entrée envoie, Maj-Entrée insère un retour (§ 2) ; sélection à la souris dans une bulle puis Cmd-C → presse-papiers « Vous pouvez utiliser « dem » (texte sélectionné). |
| Contraste des gris sur blanc ≥ 4,5:1 pour le texte courant | partiel [mineur] | Mesure pixel sur captures (fond #FFFEFF) : paragraphe d'accueil #504F54 → **8,07:1** C ; titre, bulles, puces, wordmark ≥ 12:1 C. En revanche tout ce qui est `.secondary` — sous-titre « votre IA locale gratuite », jauge « N / M jetons », ligne « Fichiers acceptés… », « N ms », badge « document chargé », lignes système, « Inutile si… », statuts — vaut nominalement `secondaryLabelColor` = noir à 50 % → #808080, **3,95:1**, et **3,10:1** mesuré (#929292, anticrénelage des petites tailles `caption2`). Ces textes ne sont pas le « texte courant » mais portent des informations utiles (jauge, limite de mots). |
| Français des chaînes visibles | mineur | Fautes : aucune. Accents : corrects. **Espaces insécables : aucune** dans `main.swift` (grep U+00A0/U+202F = 0) avant « : », « ? », « ; », « » » (« VOUS ?», « Fichiers acceptés :», « Question :», « Document « … » :») → risque de « ? » ou « : » rejeté en début de ligne. Apostrophes mixtes : typographique « ’ » dans l'accueil et les puces, droite « ' » dans « d'Apple », « d'abord », les cartes d'installation. « 1 jetons » (pluriel figé, `main.swift:684,694`). Statut 1.3.3 : `f42ae41` semble insérer des insécables (lignes modifiées sans différence visible). |
| Interface système en anglais | mineur | Aucune localisation déclarée (pas de `CFBundleDevelopmentRegion`, pas de `.lproj`) : menus « File / Edit / View / Window / Help », « Quit FM Mini », « New FM Mini Window », panneau d'ouverture « Open / Cancel », menu contextuel « Cut / Copy / Paste… » en anglais sur un système en français. SPEC parle du « menu Aide » : il s'appelle « Help ». Remarque : « File → New FM Mini Window » ouvre une seconde fenêtre partageant la même conversation (`WindowGroup`, modèle unique `main.swift:1286`). |

---

## 6. README (version 1.3.1, `62cf2e4`)

| Question | Constat |
|---|---|
| Les trois commandes suffisent-elles ? | **Oui sur cette machine** : `./make-app.sh` → 23 s, « Application prête. Ouvrir avec : open "…/FM Mini.app" », puis `open` ouvre la fenêtre. Mais le script ne vérifie aucun prérequis (M1) : sur un Mac sans CLT, l'erreur sera celle de `swift` (anglais, cryptique), pas un message du README. Le README omet `cd fm-mini` avant `./make-app.sh` ; « Copiez le dossier » ne dit pas où (le rapport d'autotest suppose `~/fm-mini`). |
| Limites annoncées vs observées | « 24 langues » et liste : C. « Vers une langue hors liste … sans garantie » : C (phrase présente). « Pas de comptage » : C (phrase présente ; non testé). « Plus la conversation est longue, plus chaque réponse est lente ; FM Mini la compresse automatiquement » : **observé** (2 209 ms → 20 450 ms sur 11 tours avec réponses de 250 mots, puis compression 5 277 → 2 158). Découpage : C (phrase et comportement cohérents, y compris « en respectant… les fins de phrase autant que possible », qui couvre honnêtement le cas de la fixture). « 4 096 ou 8 192 jetons », « 2 600 ou 5 300 mots » : cohérent avec 8 192 / 5 300 observés. « 5 Mo » : C. |
| Dépannage | Couvre : modèle indisponible, Gatekeeper (**faux**, M5), partie inadaptée, erreur `ModelManagerServices` des scripts. **Ne couvre pas** : la boîte « Placer dans la corbeille / Terminé » réellement affichée ; la perte de la saisie sur « conversation pleine » ; les 30 s d'attente sur un fichier de plusieurs Mo ; le message « UTF-8 » affiché pour un .docx endommagé ; le fait que l'autotest écrase le presse-papiers. |
| Exactitude de la section « Vérification technique » | **NC [mineur]** : le README affirme que l'autotest vérifie « les lectures DOCX et PDF, un PDF sans texte, la limite de 5 Mo » ; le code 1.3.1 ne contient aucun de ces tests (fonctions `writeDOCX`/`writeTextPDF`/`writeBlankPDF` `main.swift:1531-1565` jamais appelées ; rapport 12 h 29 : tests 0,1,2,3,8,9,12 seulement). 1.3.3 : `60246f9` ajoute ces tests. |
| Fenêtre d'installation | Le README dit « Les détections sont faites localement ; seul LM Studio est interrogé sur localhost » — vrai, mais tait que c'est fait **au lancement de l'app** (B2). |

---

## 7. Exigences non vérifiables et pourquoi

1. **Apple Intelligence désactivé / modèle indisponible en cours de session** — simuler exige de désactiver Apple Intelligence dans les Réglages de la machine de l'utilisateur (risque de re-téléchargement du modèle, état non remis à l'identique) ; non fait sans accord explicite. Constat par lecture : disponibilité lue une seule fois à l'init (`main.swift:242-250`), aucune réévaluation.
2. **Mapping des erreurs `LanguageModelError` à l'exécution** (garde-fous, langue non prise en charge, contexte dépassé) — aucune de ces erreurs ne s'est produite ; la carte « conversation pleine » du code empêche d'atteindre `contextSizeExceeded`. Vérifié par lecture seulement (`main.swift:461-475`).
3. **Textes des cartes d'installation « verbatim du prompt 1.3.1 »** — le prompt 1.3.1 n'est pas dans le dépôt ; et les textes ne s'affichent pas (B1).
4. **Usage « Wi-Fi coupé »** — Wi-Fi déjà coupé, Mac sur Ethernet ; isoler la machine exige `sudo`. Remplacé par la preuve `lsof` (0 socket) pendant les questions avec document.
5. **Lecture VoiceOver effective** — VoiceOver non activé (modifie l'environnement sonore de l'utilisateur) ; vérifié via les attributs AX (`AXDescription`) que VoiceOver lit.
6. **Cible 44 pt du bouton « Copier »** — la zone cliquable réelle d'un `Button` SwiftUI entouré d'un `.frame` ne se mesure pas via AX ; constat par lecture (`main.swift:880`).
7. **« Un commit par changement livré »** pour les versions antérieures à 1.3.1 — hors périmètre ; pour 1.3.1 : non commité au début de l'audit.
8. **Comportement sur un « Mac neuf »** (sans CLT, sans modèle) — une seule machine, déjà équipée.
9. **Les correctifs 1.3.3** (`8716300`…`ca61989`) — arrivés pendant l'audit, lus en diff, non exécutés dans ce rapport.

## Annexe — fichiers de preuve (scratchpad de session, non versionnés)

`<scratchpad de session>/` : `shots/01-welcome-460x760.png`, `11-binaire.png`, `20-arabe.png`, `21-arabe-emoji.png`, `30-50k-paste.png`, `41-after-q11.png`, `50-oversized-card.png`, `51-part2-loaded.png`, `60-4_9Mo.png`, `70-hover-copy.png`, `72-context-menu.png`, `73-context-menu-ms.png`, `80-chat-400x560.png`, `81-welcome-400x560.png`, `90-installation.png` ; `net.log` (moniteur 7 min, vide), `net-wifi-off.log` (vide), `latency.txt`, `autotest-run.stdout` (binaire 1.3.3), `autotest-2026-11-02.orig.txt` (copie du rapport 12 h 29), `SPEC-recupere-12h48.md`, `src/` (outils AX, découpage, contraste), `v131/` (`git archive 62cf2e4`, rebuild de contrôle).
