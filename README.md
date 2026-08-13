# Helium Fix DRM

Script PowerShell qui restaure la lecture DRM (Widevine) dans [Helium](https://github.com/imputnet/helium) sur Windows.

Le script télécharge le dernier installateur Chrome offline, en extrait `WidevineCdm`, puis le copie dans le dossier d'application de Helium.

> ⚠️ Ce fix permet de charger le module Widevine dans Helium, mais certains services de streaming stricts (Netflix, Crunchyroll...) peuvent encore refuser la lecture même avec le CDM présent — ces plateformes vérifient l'intégrité du navigateur au-delà de la simple présence du fichier CDM. Fonctionne mieux sur des services moins stricts (YouTube, etc.).

## Prérequis

- Windows
- [Helium](https://github.com/imputnet/helium) installé sous `C:\Program Files\imput\Helium`
- [7-Zip](https://www.7-zip.org/)
- Accès Internet (pour récupérer l'installateur Chrome)
- Droits d'écriture dans `C:\Program Files` (PowerShell en administrateur)

## Installation rapide (curl-style)

Ouvre **PowerShell en tant qu'administrateur**, puis lance directement :

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 | iex
```

Cette commande télécharge et exécute le script en une seule ligne, sans avoir besoin de cloner le repo.

### Avec l'option `-Force` (réécrase une install existante)

`irm | iex` ne transmet pas d'arguments directement, donc pour utiliser `-Force` ou `-KeepTemp`, télécharge le script d'abord :

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 -OutFile HeliumFixDRM.ps1
Set-ExecutionPolicy -Scope Process Bypass
.\HeliumFixDRM.ps1 -Force
```

## Installation manuelle (clone du repo)

```powershell
git clone https://github.com/da0t-exe/Helium-Fix-DRM.git
cd Helium-Fix-DRM
Set-ExecutionPolicy -Scope Process Bypass
.\HeliumFixDRM.ps1
```

### Options disponibles

| Option | Effet |
|---|---|
| *(aucune)* | Installe le CDM seulement s'il n'existe pas déjà |
| `-Force` | Réécrase un CDM déjà présent |
| `-KeepTemp` | Conserve les fichiers temporaires extraits (debug) |

Exemple :
```powershell
.\HeliumFixDRM.ps1 -Force
```

## Après l'exécution

1. Ferme complètement Helium (vérifie qu'aucun processus ne tourne encore en arrière-plan)
2. Relance Helium, ou va sur `helium://restart/`
3. Vérifie que le module est chargé : `helium://components`
4. Teste la lecture sur un flux DRM, par exemple : `https://bitmovin.com/demos/drm`

## Dépannage

**`Access is denied` lors de la copie**
→ PowerShell n'est pas lancé en administrateur. Ferme la fenêtre, relance-la avec "Run as administrator".

**`Error: Helium not found`**
→ Ton install de Helium n'est pas dans `C:\Program Files\imput\Helium`. Vérifie le vrai chemin avec :
```powershell
Get-ChildItem "C:\Program Files\imput\Helium\Application" -ErrorAction SilentlyContinue
```
Si absent, adapte la variable `$HeliumBase` en haut du script vers le bon chemin (souvent `%LOCALAPPDATA%\imput\Helium\Application` selon le mode d'installation).

**`Error: 7-Zip not found`**
→ Installe 7-Zip depuis [7-zip.org](https://www.7-zip.org/) avec les options par défaut.

**Widevine reste sur `Status: New` ou `0.0.0.0` dans `helium://components`**
→ Comportement normal même après une installation réussie ; l'important est que `bitmovin.com/demos/drm` détecte bien "Widevine" et non "No DRM".

**Certains sites (Netflix, Crunchyroll) refusent toujours la lecture**
→ Limite connue. Ces plateformes appliquent une vérification d'intégrité du navigateur (Verified Media Path) que la simple présence du CDM ne satisfait pas sur un navigateur non certifié par Google. Pas de solution connue côté client à ce jour.

## Licence

À toi de préciser selon ce que tu veux (MIT, aucune, etc.)
