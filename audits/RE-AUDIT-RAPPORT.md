# Ré-audit de conformité et de sûreté — FM Mini 1.3.3

## Verdict

Non distribuable tel quel.
Les trois constats bloquants ou majeurs initiaux portant sur la fenêtre d’installation, le prévol et l’autotest sont fermés par des preuves d’exécution.
Un constat majeur demeure : avec le fixture réel `long-20000-mots.txt`, le découpage ferme des parties au milieu d’une phrase. Les essais UI restants sont explicitement séparés ci-dessous de ce qui a été prouvé.

## Méthode et limites de référence

Audit en lecture seule des sources, du bundle `build/FM Mini.app` 1.3.3 et des fixtures. Aucun fichier de code n’a été modifié et ce rapport n’est pas committé. La copie temporaire du bundle, à identifiant distinct, n’a servi qu’à lire l’interface puis a été supprimée.

`SPEC.md`, demandé comme spécification 1.3.3, est actuellement un document HTML de 58 653 caractères par ligne, et non un document de spécification Markdown lisible. Les exigences ci-dessous sont donc contrôlées contre la demande de ré-audit, `AUDIT-RAPPORT.md` et les artefacts présents ; les écarts non couverts par ces sources restent non vérifiables.

Commandes principales :

```sh
./make-app.sh
PATH="$audit_path" /bin/zsh ./make-app.sh     # audit_path ne contient pas xcode-select
build/FM\ Mini.app/Contents/MacOS/FMMini --autotest   # lancé depuis Terminal.app
wc -w audit-fixtures/long-20000-mots.txt
git status --short
```

## 1. Fermeture des constats bloquants et majeurs du premier audit

### Fenêtre « Compléter l’installation » — **conforme, constat bloquant fermé**

**Preuve.** [main.swift:1187](~/fm-mini/Sources/FMMini/main.swift:1187) à [1192](~/fm-mini/Sources/FMMini/main.swift:1192) interpolent désormais `tool.about`, `tool.needed` et `tool.unnecessary`. La copie temporaire du bundle 1.3.3 a été ouverte ; son arbre d’accessibilité décrit les 12 cartes, chacune avec les trois phrases résolues. Exemple observé pour `fm (dans le Terminal)` : « À quoi ça sert : parler au même modèle… », « Vous en avez besoin si… vous aimez le Terminal… », « Inutile si… vous êtes satisfait de cette fenêtre… ». Les cartes LM Studio, Ollama, Homebrew, apfel, CLT, SDK Python, documentation Apple, Xcode, utilities et MCP sont elles aussi textuelles, sans `(tool.about)`, `(tool.needed)` ni `(tool.unnecessary)`.

**Reproduction.** Dans FM Mini : **Aide → Compléter l’installation…** ; faire défiler les quatre sections. L’arbre d’accessibilité de la fenêtre observée contient les trois phrases complètes pour chaque carte.

### Prévol de `make-app.sh` — **conforme, constat majeur fermé**

**Preuve.** Le script contrôle macOS à [make-app.sh:7](~/fm-mini/make-app.sh:7), `arm64` à [14](~/fm-mini/make-app.sh:14), `xcode-select -p` à [19](~/fm-mini/make-app.sh:19), puis écrit/exécute `/tmp/fmcheck.swift` à [24](~/fm-mini/make-app.sh:24)–[43](~/fm-mini/make-app.sh:43). Exécution réelle :

```text
availability: available
contextSize: 8192
Build complete! (0,29 s)
Application prête. Ouvrir avec :
open "~/fm-mini/build/FM Mini.app"
```

Simulation avec un `PATH` ne contenant que `sw_vers` et `uname`, sans `xcode-select` : sortie et arrêt non nul :

```text
Les Command Line Tools Apple sont nécessaires. Installez-les avec : xcode-select --install
```

**Reproduction.** Lancer `./make-app.sh`. Pour la branche CLT, préparer un répertoire temporaire avec seulement ces deux liens symboliques et l’utiliser comme `PATH` : le script s’arrête avant toute construction.

### Autotest, fixtures et fichiers temporaires — **conforme, constat majeur fermé**

**Preuve.** `AutoTest.auditFixtures()` appelle effectivement DOCX, PDF scan et seuil 5 Mo à [main.swift:1478](~/fm-mini/Sources/FMMini/main.swift:1478)–[1504](~/fm-mini/Sources/FMMini/main.swift:1504). Aucune occurrence de `temporaryDirectory` ni de nom `fm-mini-*` n’existe dans les sources. Avant et après un autotest complet lancé dans **Terminal.app**, `find $TMPDIR -maxdepth 1 -name 'fm-mini-*' -type f` n’a rien renvoyé.

Rapport produit : [autotest-2026-11-02.txt](~/fm-mini/autotest-2026-11-02.txt). Extraits :

```text
AUTOTEST découpage unitaire : OK
AUTOTEST fichiers DOCX/PDF/scan/5 Mo : OK
AUTOTEST 8 document chargé une fois + compression: OK — 6 questions, injection 1/6, 8154 → 2729 jetons
AUTOTEST 9 presse-papiers: OK
AUTOTEST 12 découpage: OK — 6 puces
```

**Reproduction.** Ouvrir Terminal.app, puis exécuter `build/FM\ Mini.app/Contents/MacOS/FMMini --autotest`. Le seul fichier créé par l’exécutable est le rapport daté à la racine du dépôt.

### Découpage sur le fixture réel — **majeur, non conforme, constat non fermé**

**Preuve.** Le test unitaire source ne couvre qu’un document artificiel dont chaque paragraphe se termine par un point ([main.swift:73](~/fm-mini/Sources/FMMini/main.swift:73)–[80](~/fm-mini/Sources/FMMini/main.swift:80)). Le fixture réel contient 20 000 mots en 50 paragraphes de 400 mots (`wc -w` = `20000`), mais des paragraphes se terminent par exemple par `apprendre et` : la phrase continue au paragraphe suivant. Sur ce Mac, P vaut `floor(8192 × 0,6 / 1,4) = 3 510` mots. L’algorithme assemble des blocs structurels jusqu’à P ([main.swift:87](~/fm-mini/Sources/FMMini/main.swift:87)–[114](~/fm-mini/Sources/FMMini/main.swift:114)) : huit paragraphes font 3 200 mots, le neuvième ferait 3 600. La première partie se ferme donc à la fin du huitième paragraphe, dont le dernier caractère est `u`, pas `.`, `!` ou `?`.

Le nombre annoncé est bien le nombre réel de parts (`parts.count`, [main.swift:524](~/fm-mini/Sources/FMMini/main.swift:524)–[535](~/fm-mini/Sources/FMMini/main.swift:535)) : pour ce fixture, sept parties de 3 200, 3 200, 3 200, 3 200, 3 200, 3 200 et 800 mots. K réel = **7**. Cela ne corrige pas la coupure de phrase.

**Reproduction.** Joindre `audit-fixtures/long-20000-mots.txt`, déclencher la carte de découpage, puis inspecter la fin de « Partie 1/7 » : elle termine sur « … cultiver, apprendre et ». Le même résultat se déduit directement de la commande `awk` qui compte les paragraphes et de P=3 510.

**Correctif suggéré (3 lignes maximum).** Ne traiter une limite de paragraphe que comme une préférence : avant de fermer `current`, prolonger jusqu’à la prochaine borne de phrase ; si elle dépasse P, signaler explicitement la phrase indivisible au lieu de prétendre respecter P.

### État du dépôt — **mineur, non conforme à « dépôt propre »**

**Preuve.** Avant la création du présent rapport, `git status --short` renvoyait déjà :

```text
?? .build/
?? AUDIT-DOSSIER.md
?? AUDIT-RAPPORT.md
?? SPEC.md
?? SPEC_files/
?? autotest-2026-11-02.txt
?? build/
```

Les correctifs eux-mêmes sont committés (`8716300`, `8c462c0`, `6c25a35`, `60246f9`, `f42ae41`, `ca61989`). Le dépôt n’est toutefois pas propre au sens demandé ; le présent rapport s’ajoute volontairement aux non suivis et ne doit pas être committé.

**Reproduction.** `git status --short` à la racine.

## 2. Ce que le contexte Terminal permet maintenant de vérifier

### Latence de dix conversations vierges — **conforme**

**Preuve.** Depuis Terminal.app, dix nouvelles `LanguageModelSession` avec la consigne de FM Mini, une requête courte « Bonjour » et 12 jetons de réponse maximum ont donné, en ms : `350, 231, 228, 233, 227, 225, 239, 237, 231, 230`. Médiane (cinquième valeur triée) : **231 ms**, inférieure à 1,5 s.

**Reproduction.** Créer dix sessions indépendantes dans Terminal.app, mesurer `Date()` autour de `respond(to:)`, trier les durées et retenir la médiane. Ce test évite le premier appel chaud/froid ambigu en mesurant dix sessions dans le même contexte Terminal.

### Fixtures de lecture — **partiellement conforme**

**Preuve.** L’autotest Terminal confirme le DOCX, le PDF scan et les deux seuils de taille. Les tailles vérifiées sont `4_9Mo.txt = 4 900 000` octets et `5_1Mo.txt = 5 100 000` octets ; [main.swift:200](~/fm-mini/Sources/FMMini/main.swift:200) emploie bien 5 000 000 et [498](~/fm-mini/Sources/FMMini/main.swift:498)–[501](~/fm-mini/Sources/FMMini/main.swift:501) divisent par 1 000 000, donc le message attendu est bien `5,1 Mo`.

Les parcours suivants sont établis par le code, sans plantage observé par l’autotest :

| Fixture | Résultat contrôlé |
|---|---|
| `vide.txt` | Lit une chaîne vide ; aucun rejet dédié n’est prévu. L’envoi UI n’a pas été joué. |
| `binaire.txt` | Rejet UTF-8 via [main.swift:221](~/fm-mini/Sources/FMMini/main.swift:221)–[223](~/fm-mini/Sources/FMMini/main.swift:223), message `Le fichier doit être du texte UTF-8 lisible.` |
| `corrompu.docx` | Toute erreur DOCX/RTF devient `damagedDocument` à [208](~/fm-mini/Sources/FMMini/main.swift:208)–[215](~/fm-mini/Sources/FMMini/main.swift:215), message `Ce fichier est illisible (document endommagé ?).` |
| `scan-sans-texte.pdf` | `PDFDocument(...).string` vide déclenche le message scan et n’attache pas le fichier ([216](~/fm-mini/Sources/FMMini/main.swift:216)–[220](~/fm-mini/Sources/FMMini/main.swift:220)); autotest OK. |
| `arabe.txt` / emoji | `String` et `Text` les conservent, mais le rendu RTL et visuel n’a pas été confirmé à l’écran. |

**Reproduction.** Joindre chaque fixture dans l’instance UI. Le pilote d’accessibilité a permis de lire la fenêtre d’installation mais son menu a ensuite capturé le focus de la copie isolée, empêchant de terminer de façon fiable les sélections `NSOpenPanel` ; aucun faux résultat UI n’est donc consigné.

### Flux, double clic, nouvelle conversation et collage 50 000 caractères — **partiellement conforme / non vérifiable en UI**

**Preuve.** `send()` devient non réentrant par `isSending`, et les boutons Joindre/Envoyer sont désactivés pendant un flux ([main.swift:725](~/fm-mini/Sources/FMMini/main.swift:725)–[730](~/fm-mini/Sources/FMMini/main.swift:730)). `newConversation()` annule bien `responseTask` avant la remise à zéro ([261](~/fm-mini/Sources/FMMini/main.swift:261)–[275](~/fm-mini/Sources/FMMini/main.swift:275)). Mais le bouton visible « Nouvelle conversation » est lui-même désactivé pendant un flux ([656](~/fm-mini/Sources/FMMini/main.swift:656)–[659](~/fm-mini/Sources/FMMini/main.swift:659)) : le scénario demandé ne peut pas être déclenché par l’utilisateur au moment où l’annulation serait utile.

`NSTextView` n’impose aucun plafond de caractères ; 50 000 caractères et le rendu d’un emoji nécessitent encore un essai visuel. Aucun gel ni crash n’a été observé dans les parcours réellement exécutés, mais ces trois gestes UI ne sont pas attestés.

**Reproduction.** Envoyer une requête longue, tenter immédiatement un second envoi puis « Nouvelle conversation » : les deux contrôles sont désactivés pendant le flux. Coller 50 000 caractères dans « Message » et vérifier manuellement la croissance jusqu’à six lignes et le défilement interne.

## 3. Correctifs mineurs 5–6

| Point | État | Preuve / reproduction |
|---|---|---|
| Noms longs sur deux lignes | Conforme statiquement | `.lineLimit(2)` pour la puce et le badge, [main.swift:703](~/fm-mini/Sources/FMMini/main.swift:703) et [714](~/fm-mini/Sources/FMMini/main.swift:714). Rendu avec un nom long non achevé par le pilote UI. |
| Saisie 3 → 6 lignes | Conforme statiquement | Hauteurs `minimum` 3 lignes et `maximum` 6, mesure de `usedRect`, [main.swift:1267](~/fm-mini/Sources/FMMini/main.swift:1267)–[1277](~/fm-mini/Sources/FMMini/main.swift:1277). |
| Vérifications d’installation limitées à 1 s | Conforme | Chaque `Process` est surveillé jusqu’à `Date()+1`, puis arrêté, [main.swift:1025](~/fm-mini/Sources/FMMini/main.swift:1025)–[1044](~/fm-mini/Sources/FMMini/main.swift:1044). |
| DOCX/RTF endommagé | Conforme statiquement | Message visible exact à [main.swift:506](~/fm-mini/Sources/FMMini/main.swift:506)–[508](~/fm-mini/Sources/FMMini/main.swift:508). |
| Libellé du champ | Conforme | `setAccessibilityLabel("Message")`, [main.swift:1232](~/fm-mini/Sources/FMMini/main.swift:1232)–[1235](~/fm-mini/Sources/FMMini/main.swift:1232). |
| Espaces insécables étroites visibles | Conforme pour les chaînes corrigées | Exemples : en-tête, accueil, jauge et erreurs utilisent U+202F ([main.swift:748](~/fm-mini/Sources/FMMini/main.swift:748), [757](~/fm-mini/Sources/FMMini/main.swift:757), [784](~/fm-mini/Sources/FMMini/main.swift:784), [788](~/fm-mini/Sources/FMMini/main.swift:788)). La ponctuation du wrapper transmis au modèle reste volontairement celle imposée par la consigne, et n’est pas un texte d’interface. |
| Sous-titre retiré | Conforme | Aucun `votre IA locale gratuite` dans le source ; l’en-tête ne contient que « FM Mini » et le bouton, [main.swift:649](~/fm-mini/Sources/FMMini/main.swift:649)–[665](~/fm-mini/Sources/FMMini/main.swift:665). |
| Accueil « une à quelques secondes » | Conforme | Formulation à [main.swift:788](~/fm-mini/Sources/FMMini/main.swift:788). |
| README : signature ad hoc et Terminal | Conforme | Gatekeeper/signature à [README.md:47](~/fm-mini/README.md:47), commande et précondition Terminal.app à [README.md:53](~/fm-mini/README.md:53). |

## 4. Bundle et documentation

**Remarque.** `make-app.sh` a reconstruit un bundle avec `CFBundleShortVersionString = 1.3.3`. `codesign --verify --deep --strict` réussit. `spctl -a -vv build/FM Mini.app` le rejette, comportement cohérent avec la signature ad hoc et correctement expliqué dans README.md.

## Exigences non vérifiables restantes

- La conformité exhaustive à `SPEC.md` 1.3.3 : le fichier présent est du HTML, pas la référence exploitable annoncée.
- Tous les parcours de `NSOpenPanel`, le rendu arabe RTL, emoji, collage de 50 000 caractères, double clic pendant flux, et redimensionnement visuel 400×560 / 460×760 : le pilote UI a bien relevé toutes les cartes d’installation, puis est resté capturé dans un menu système de la copie isolée ; aucun test partiel ne doit être présenté comme une preuve.
- Apple Intelligence désactivée ou devenue indisponible en cours de session : simulation nécessitant de modifier l’état système, hors audit non destructif.
- VoiceOver complet, contraste colorimétrique et Cmd-C sur sélection partielle : aucune sonde VoiceOver/colorimétrique fiable n’était disponible.
- Absence de tout trafic pendant cinq minutes et Wi-Fi coupé : hors du périmètre réduit de ce ré-audit et perturbateur pour le poste ; seul le code localhost de la fenêtre d’installation a été inspecté.
