# Helium Fix DRM

**Installer et maintenir Widevine dans Helium sous Windows, depuis PowerShell.**

Interface console courte, téléchargement avec barre de progression, validation des fichiers Google et sauvegarde avant remplacement.

> Widevine peut permettre la lecture sur certains services. Ce script ne corrige pas le refus Netflix observé dans Helium et ne garantit pas sa compatibilité.

## Installer ou mettre à jour

Ferme Helium, ouvre PowerShell, puis colle :

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 | iex
```

Le script détecte Helium et cherche Widevine dans Chrome. Il compare les versions et installe seulement si le module est absent, invalide ou plus ancien. Il ne rétrograde pas une version valide sans `-Force`.

Si Chrome ne fournit aucun module valide, il télécharge l'installateur officiel Google et en extrait Widevine avec **7-Zip**, sans exécuter cet installateur. La barre indique le pourcentage, les Mio reçus et le débit ; sans taille annoncée par le serveur, elle affiche uniquement le volume et le débit.

**Prérequis :** Windows, PowerShell 5.1 ou 7, Helium et Chrome installé, ou 7-Zip avec Internet pour l'extraction automatique x64. Pour ARM64/x86, utilise une source locale de même architecture. Une installation Helium dans Program Files peut nécessiter des droits administrateur.

## Activer les mises à jour automatiques

Garde Chrome installé et à jour, puis exécute une fois :

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -EnableAutoUpdate
```

Une tâche Windows vérifie le Widevine de Chrome **à l'ouverture de session et chaque jour à midi**, lorsque ta session est ouverte. Elle copie une version plus récente dans Helium et détecte ses nouveaux dossiers de version. Si Helium est ouvert, elle reporte l'opération au prochain passage ; elle ne ferme jamais le navigateur.

- Chrome récupère ses mises à jour officielles ; la tâche synchronise les fichiers disponibles localement. Elle ne vérifie pas indépendamment la dernière version mondiale de Widevine.
- Sans Chrome valide, aucune installation automatique n'a lieu. Relance la commande manuelle pour utiliser le téléchargement Google.
- La tâche fonctionne avec les droits de ton compte, sans élévation. Elle convient à Helium installé dans ton profil utilisateur.
- La copie locale du script est enregistrée dans `%LOCALAPPDATA%\HeliumFixDRM`. La tâche n'exécute pas de nouveau code téléchargé à chaque passage. Relance la commande d'activation pour mettre cette copie à jour.
- Le résultat du dernier passage est dans `%LOCALAPPDATA%\HeliumFixDRM\update.log`. Le Planificateur de tâches affiche aussi son état sous `HeliumWidevine-<SID utilisateur>`.

Pour désactiver la tâche, sans retirer Widevine :

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -DisableAutoUpdate
```

## Options utiles

Télécharge le script pour utiliser les options localement :

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 -OutFile HeliumFixDRM.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\HeliumFixDRM.ps1 -Diagnose
```

`-ExecutionPolicy Bypass` ne concerne que ce processus. Les commandes distantes exécutent le code publié sur `main` ; remplace `main` par un identifiant de commit pour fixer une version.

| Option | Effet |
| --- | --- |
| `-Diagnose` | Vérifier les fichiers installés sans les modifier. |
| `-SourcePath 'D:\WidevineCdm'` | Installer une source précise si plus récente ; sans téléchargement. |
| `-Force` | Réinstaller, y compris une version plus ancienne pour revenir en arrière. |
| `-HeliumPath 'D:\Helium\Application'` | Choisir une installation personnalisée ; fonctionne aussi avec l'activation automatique. |
| `-LocalOnly` | Chercher uniquement dans Chrome, sans téléchargement. |
| `-WhatIf` | Simuler l'action, sans installer ni créer de tâche. |
| `-Verbose` | Afficher le chemin source et son SHA256. |
| `-KeepTemp` | Garder l'installateur téléchargé et son extraction pour diagnostic. |
| `-Netflix` | Ouvrir Netflix dans une fenêtre Edge ou Chrome distincte. |

Les options d'activation/désactivation automatique sont des actions séparées. `-Unattended` est destiné à la tâche : il journalise le dernier passage et reporte l'installation si Helium est ouvert.

## Vérification et sauvegarde

Le script contrôle l'architecture PE, le manifeste et la signature Authenticode Google du CDM. Il vérifie également la signature de l'installateur téléchargé. Les nouveaux fichiers sont copiés et validés avant remplacement. L'ancienne version reste dans `WidevineCdm.backup-…` et est restaurée si le déplacement final échoue.

Les sauvegardes ne sont pas supprimées automatiquement. Pour revenir en arrière, ferme Helium et utilise `-SourcePath` avec le dossier de sauvegarde et `-Force`.

Après installation, redémarre Helium et teste une vidéo chiffrée, par exemple la [démo DRM Bitmovin](https://bitmovin.com/demos/drm). La présence du CDM dans `chrome://media-internals` ne prouve pas qu'un service acceptera sa demande de licence.

## Netflix

Lors des essais de septembre 2026, Chrome a lu Netflix avec Widevine 4.10.3112.0, mais Helium a continué à recevoir des refus de licence avec cette même version. Ce dépôt fournit un installateur de CDM, pas une correction démontrée de ce refus. Il ne modifie pas les contrôles du service.

L'option `-Netflix` ouvre réellement Edge, ou Chrome si Edge est absent, sans changer le navigateur par défaut.

Références : [demande DRM Helium](https://github.com/imputnet/helium/issues/116), [navigateurs pris en charge par Netflix](https://help.netflix.com/en/node/30081).

## Développement

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-HeliumFixDRM.ps1
pwsh -NoProfile -File .\tests\Test-HeliumFixDRM.ps1
```

Les tests vérifient la sélection de version, l'absence de rétrogradation automatique, les sauvegardes, la restauration, les téléchargements, la simulation et l'exécution via `iex`. Ils utilisent des fichiers synthétiques et ne prouvent pas la lecture Netflix.

## Licence

[MIT](LICENSE). Aucun binaire Widevine n'est redistribué dans le dépôt.
