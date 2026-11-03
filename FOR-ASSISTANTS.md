🇫🇷 [Français](POUR-LES-ASSISTANTS.md) · 🇬🇧 [English](FOR-ASSISTANTS.md)

# For coding assistants

Read [SPEC.md](SPEC.md) first. Respect its functional, privacy and accessibility requirements; change only the scope explicitly requested. Verify with `./make-app.sh` then run the self-test from Terminal.app. Make one commit per step when the request says so. Every new visible string goes into Langues.swift, in the six languages (same keys everywhere); Personnalisation.swift contains only what is not text.

If you are given the "Install FM Mini…" prompt from the README ("Installation by an assistant" section), here is what it expects from you: check Apple Silicon and macOS 27, clone or update `~/fm-mini`, run `./make-app.sh` from Terminal.app, open the app, then summarize its use in three lines based on README.md.
It expects no modification of the project: create neither commit nor file, and in case of error (Command Line Tools missing, model unavailable, error 1008) explain the cause and stop.
