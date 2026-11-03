# FM Mini

![Demo: summarizing a 300-word attachment in a few seconds](docs/demo.gif)

FM Mini is a small Mac app: one white window, one language model, one attachment. It uses the model Apple ships with macOS 27 — free, no account, and your texts never leave your computer.

It deliberately does few things: summarize, proofread, translate, pull the essentials out of a document, in 15 languages. It knows nothing about current events and almost nothing by heart: you give it the text to work on.

Interface in French, English, Spanish, German, Italian and Portuguese: it follows your Mac's language and can be changed in View → Language (Présentation → Langue).

Who it is for: anyone with an Apple Silicon Mac running macOS 27 who wants to try Apple's model without installing anything other than the command line tools. No Xcode needed, no programming knowledge needed.

To modify it: open Sources/FMMini/Langues.swift (all the texts, in six languages) or Sources/FMMini/Personnalisation.swift (sizes, colors, credits, default language) in TextEdit, or ask your coding assistant (Claude Code, Codex…) — the app's "Go further" window contains ready-to-paste requests, and FOR-ASSISTANTS.md explains the repository's rules to it.

Credits: acromega + Claude, 2026. MIT license. The audits are in audits/.

![FM Mini welcome window](docs/accueil.png)

## Requirements

- an Apple Silicon Mac;
- macOS 27 or later;
- Apple Intelligence enabled (System Settings → Apple Intelligence & Siri). The first activation downloads the model: allow a few minutes, once. After that, FM Mini works without a connection;
- the Apple Command Line Tools (install them with `xcode-select --install` if needed). Xcode is not required.

## Installation and first launch

First download the folder, in one of the two following ways.

- Without git: **Code → Download ZIP** button on the GitHub page. The unzipped folder is called `fm-mini-main`: move it into your home folder and rename it `fm-mini` (no space).
- With git: `git clone https://github.com/acromega/fm-mini.git ~/fm-mini`.

Either way, you must end up with a `~/fm-mini` folder, that is `fm-mini` directly in your home folder. The commands below assume the folder is at that exact location.

Then open the Terminal app: it is in Applications → Utilities (or type Terminal in Spotlight). Then:

1. Type `cd ~/fm-mini` and press Enter.
2. Type `./make-app.sh` and press Enter. The script first checks that the Apple model is available, then builds the application in `build/`.
3. Type `open "build/FM Mini.app"` and press Enter.

If the model is not available, `make-app.sh` stops with a message and builds nothing. In that case, enable Apple Intelligence in System Settings, wait for the model download to finish, then run `./make-app.sh` again.

The window opens the first time in the center of the screen in portrait format (460 × 760), can be shrunk down to 400 × 560, and then remembers its size and position.

## One-line installation (if you have used the Terminal before)

```
git clone https://github.com/acromega/fm-mini.git ~/fm-mini && cd ~/fm-mini && ./make-app.sh && open "build/FM Mini.app"
```

On a new Mac, macOS will first offer to install the command line tools: accept, wait, paste the line again. To update later: `cd ~/fm-mini && git pull && ./make-app.sh && open "build/FM Mini.app"`

## Installation by an assistant (Claude Code, Codex…)

Launch your assistant from the Terminal app — otherwise the model is invisible to it (error 1008) — and paste this:

```
Install FM Mini, a small open-source Mac app (https://github.com/acromega/fm-mini) that opens a chat window on the language model built into macOS 27. Do exactly this, without modifying the project:
1. Check that the Mac is Apple Silicon (uname -m = arm64) and runs macOS 27 or later (sw_vers). Otherwise, say so and stop.
2. git clone https://github.com/acromega/fm-mini.git ~/fm-mini (if the folder already exists, run git pull inside it).
3. cd ~/fm-mini && ./make-app.sh. If the script asks for the Command Line Tools, run xcode-select --install, wait for the installation to finish, then run ./make-app.sh again. If the script says the model is not available, explain to me how to enable Apple Intelligence in System Settings and stop. If you get error 1008 "not available in this context", you were not launched from the Terminal app: tell me and stop.
4. Open the application with the open command printed by the script, and tell me in three lines what I can do with it (read README.md).
```

## Using FM Mini

You can add a `.txt`, `.md`, `.csv`, `.json`, `.log`, `.rtf`, `.docx` or `.pdf` attachment containing text, with the **Add an attachment…** button (Ajouter une PJ…) or the **File** menu (Fichier). Scanned PDFs without text cannot be read. On the welcome screen, the five chips open the file picker if no attachment is loaded; once accepted, they place their request in the field without sending it. Press Enter to send; Shift-Enter adds a line. The response time is shown under each model answer.

- "Summarize the attachment in about 200 words."
- "Correct the spelling and grammar of the attachment, keeping the meaning."
- "Create a five-question quiz from the attachment, with the answers."
- "Extract the names, dates and figures from the attachment."
- "Translate into…"

An attachment is only sent with the first question: the badge "Attachment: <name> (N tokens)" then confirms that it stays in the conversation. The gauge under the header shows how full the context is; FM Mini automatically compresses older exchanges as it approaches the limit, without removing the visible bubbles. Bubbles can be copied on hover or with a right click.

## Menus and keyboard

The **File** menu (Fichier) offers **New conversation** (⌘N), **Add an attachment…** (⌘O) and **Close** (⌘W). The **Edit** menu (Édition) also offers **Copy Last Answer** (⌘⇧C). These shortcuts work even while you are writing your message. The **View → Language** menu (Présentation → Langue) changes the interface language (Français, English, Español, Deutsch, Italiano, Português) without restarting: the current conversation is kept and the following answers arrive in the new language.

Tab follows the macOS setting System Settings → Keyboard → Keyboard navigation; every action has a shortcut: ⌘N, ⌘O, Enter, ⌘⇧C.

## What if my document is too long?

The model can only read a limited amount of text at a time: this is not a bug. FM Mini then automatically splits the attachment into parts, respecting headings, paragraphs and sentence endings as much as possible. Pick a part; it becomes the loaded attachment for the next question, and you can come back to another part at any time. If this split does not match your need, copy the useful section yourself into a small `.txt` file.

## Limits

A file cannot exceed 5 MB. The model also has a limited context window (depending on the Mac, usually 4,096 or 8,192 tokens): the application shows an estimate in words under the **Add an attachment…** button (about 2,600 or 5,300 words). The longer the conversation, the slower each answer; FM Mini compresses it automatically. When an attachment exceeds this window, FM Mini offers its parts; when the conversation gets long, it keeps the attachment and automatically summarizes the older exchanges. It has no real-time knowledge of the world and Apple's guardrails may refuse some requests.

## Languages

The 24 supported languages are: fr, fr-CA, en ×4, es ×3, pt ×2, zh ×3, de, it, ja, ko, nl, da, nb, sv, tr, vi. For a language outside this list, the model produces text but with no guarantee at all (observed: very decent Arabic, misleading Thai); only the quality of French has been measured.

## What it cannot do

FM Mini cannot count, compare, detect a contradiction or reliably say "the text does not say": it restates, it does not verify.

## Customizing FM Mini

All the interface texts, in the six languages, are in [Sources/FMMini/Langues.swift](Sources/FMMini/Langues.swift); the colors, credits, window size and default language are in [Sources/FMMini/Personnalisation.swift](Sources/FMMini/Personnalisation.swift). You can adapt them without touching the rest of the folder.

1. In the Finder, right-click `Sources/FMMini/Langues.swift` (or `Personnalisation.swift`), choose **Open With**, then **TextEdit**.
2. Change only the text between quotation marks (or the two numbers of `CGSize` for the window size), then save.
3. In Terminal, after `cd ~/fm-mini`, run `./make-app.sh` again.

For example, you can change a chip by replacing the text of `.puceResume` in the language you want, switch French to the informal "tu" by replacing "vouvoies" with "tutoies" in `.consigneModele` of the French block, fix a translation, or enlarge the window by increasing `width` and `height` of `tailleFenetreParDefaut`. Do not change the key names, the comments, or any other file in the folder.

## Go further

The **Help → Go further…** menu (Aide → Aller plus loin…), or the link at the bottom of the welcome screen, opens a window of six cards. It explains three capabilities already on the Mac (dictation, Shortcuts and Terminal), then three additions you can ask your coding assistant for: reading images and scans, web pages, or a folder of documents. The last three cards copy a ready-to-paste request; the window detects nothing, runs nothing and downloads nothing.

![FM Mini "Go further" window](docs/aller-plus-loin.png)

*The "Go further" window: three capabilities already on the Mac, three additions to ask an assistant for.*

The copied requests refer to [FOR-ASSISTANTS.md](FOR-ASSISTANTS.md) and [SPEC.md](SPEC.md), which describe the project's working rules.

## Troubleshooting

- If the application says the model is not available, open System Settings, enable Apple Intelligence and wait for the download to finish.
- This case only occurs if the app was copied from another Mac. An app built on your Mac by `make-app.sh` opens directly. FM Mini is ad hoc signed: it is signed locally, without an Apple distribution certificate. Gatekeeper may at first only show **Move to Trash** and **Done**. Click **Done**, then open **System Settings → Privacy & Security** and choose **Open Anyway** for FM Mini.
- If a selected part does not answer your question, pick another part in the attachment card or attach a shorter excerpt.
- A file of several MB may take a few tens of seconds to read and split; the **Analyzing the document…** indication stays visible during this work.
- During verification, an isolated Swift script could show an Apple `ModelManagerServices` error while the signed application worked. In that case, build and open the application with the three commands of the "Installation and first launch" section rather than trying the model from a shell script.
- If the old icon is still shown after a rebuild, it is usually the Finder or Dock cache: run `touch "build/FM Mini.app"`, then reopen the application. If that is not enough, relaunch the Finder or the Dock.

## Technical verification

Two commands run the self-test, both from Terminal.app after `cd ~/fm-mini`:

- `swift run -c release FMMini --autotest` compiles then runs the self-test without going through the built app;
- `build/FM Mini.app/Contents/MacOS/FMMini --autotest` runs the self-test of the app already built by `make-app.sh`.

Add `--langue en` (or es, de, it, pt, fr) to limit the language checks to a single language. The self-test checks, for each language, the welcome screen, the translation keys, the answer to "hello" in the right language, then switching a conversation from French to English; and, in French, the normal answer without attachment, "salut", a summary, the attachment chips (cancellation and insertion without sending), the context window, reading the DOCX and the text-less PDF from the fixtures, the 5 MB limit, splitting a 20,000-word attachment and compressing a conversation.
