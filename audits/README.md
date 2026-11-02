# Audits de FM Mini

Trois rapports d'audit en lecture seule, produits le 2 novembre 2026, avant la publication.

- `AUDIT-RAPPORT.md` : Codex audite la version 1.3.1 (commit 62cf2e4). Verdict : non distribuable tel quel (fenêtre d'installation, prévol du script de construction, autotest).
- `AUDIT-RAPPORT-claude.md` : Claude Code audite la même version 1.3.1 en parallèle. Verdict : non distribuable tel quel, distribuable après les correctifs B1-B2 et M1-M6 listés en tête.
- `RE-AUDIT-RAPPORT.md` : Codex ré-audite la version 1.3.3. Verdict : les trois constats bloquants sont fermés ; un constat majeur demeure (découpage au milieu d'une phrase).

Les vérifications finales ont été faites sur 1.3.10 (personnalisation, menus, focus) puis sur 1.3.13 (repli Tab, autotest, fenêtre « Aller plus loin ») ; elles n'ont pas donné lieu à un rapport séparé.

Non vérifié par ces audits : le comportement avec Apple Intelligence désactivée, les erreurs `LanguageModelError` réelles (seuls les messages sont vérifiés statiquement), l'usage effectif avec VoiceOver, et l'installation sur un Mac neuf.

Les chemins personnels des rapports ont été remplacés par `~` avant publication.
