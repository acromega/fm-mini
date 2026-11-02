# Pour les assistants de programmation

Lisez d’abord [SPEC.md](SPEC.md). Respectez ses exigences fonctionnelles, de confidentialité et d’accessibilité ; ne changez que le périmètre explicitement demandé. Vérifiez avec `./make-app.sh` puis lancez l’autotest depuis Terminal.app. Faites un commit par étape lorsque la demande le précise.

Si on vous donne le prompt « Installe FM Mini… » du README (section « Installation par un assistant »), voici ce qu'il attend de vous : vérifier Apple Silicon et macOS 27, cloner ou mettre à jour `~/fm-mini`, lancer `./make-app.sh` depuis Terminal.app, ouvrir l'app, puis résumer son usage en trois lignes d'après README.md.
Il n'attend aucune modification du projet : ne créez ni commit ni fichier, et en cas d'erreur (Command Line Tools absents, modèle indisponible, erreur 1008) expliquez la cause et arrêtez-vous.
