---
description: Mettre à jour depuis un nouveau tag remote, rebuilder et générer le .deb (Raspbian ARM64)
---

# Mise à jour depuis un tag remote, rebuild et génération du .deb

Ce workflow s'applique au build **Raspbian ARM64** (Raspberry Pi 5, noyau 16k pages).  
Le répertoire source est supposé être `/home/patrick/git/desktop-kDrive`.  
La branche locale `raspbian-aarch64-16k` n'existe pas upstream : elle contient les patches spécifiques au RPI5 et est maintenue en mergant les tags de release officiels.

---

## 1. Se placer sur la branche locale

```bash
git -C /home/patrick/git/desktop-kDrive checkout raspbian-aarch64-16k
```

---

## 2. Récupérer les nouveaux tags depuis upstream

Les tags de release sont créés sur `upstream` (https://github.com/Infomaniak/desktop-kDrive.git).

```bash
git -C /home/patrick/git/desktop-kDrive fetch --tags upstream
```

Vérifier les tags disponibles (les plus récents en premier) :

```bash
git -C /home/patrick/git/desktop-kDrive tag --sort=-creatordate | head -10
```

---

## 3. Merger le tag dans la branche

Remplacer `<TAG>` par le tag voulu (ex. `v3.8.4`).

```bash
git -C /home/patrick/git/desktop-kDrive merge tags/<TAG>
```

> En cas de conflit, les résoudre, puis `git merge --continue`.

---

## 4. Mettre à jour les submodules

```bash
git -C /home/patrick/git/desktop-kDrive submodule update --init --recursive
```

---

## 5. Vérifier / mettre à jour `version.json`

Le fichier `version.json` à la racine du projet contrôle la version intégrée dans les binaires et le package `.deb`.  
Si le tag correspond à une nouvelle version, mettre à jour manuellement :

```json
{
  "Version": {
    "major": X,
    "minor": Y,
    "patch": Z,
    "build": N,
    "year": YYYY
  }
}
```

---

## 6. Rebuilder (build incrémental)

Le script `build-raspbian.sh` utilise **Ninja** : seuls les fichiers modifiés sont recompilés.  
Si `sentry-native` et `log4cplus` sont déjà installés (cas habituel après un premier build), utiliser `--skip-sentry` pour gagner du temps.

```bash
/home/patrick/git/desktop-kDrive/infomaniak-build-tools/linux/build-raspbian.sh \
    -d /home/patrick/git/desktop-kDrive \
    --skip-sentry
```

> **Premier build ou mise à jour de sentry :** omettre `--skip-sentry`.  
> **Build type alternatif :** ajouter `-t Debug` ou `-t Release` (défaut : `RelWithDebInfo`).  
> **Nombre de jobs :** ajouter `-j <N>` (défaut : `nproc`).

Les binaires produits sont dans `build-raspbian/bin/`.

---

## 7. Générer le paquet `.deb`

```bash
/home/patrick/git/desktop-kDrive/infomaniak-build-tools/linux/build-deb.sh \
    -d /home/patrick/git/desktop-kDrive/build-raspbian
```

Le fichier `.deb` est généré dans `build-raspbian/`.

```bash
ls -lh /home/patrick/git/desktop-kDrive/build-raspbian/*.deb
```

---

## Récapitulatif des commandes (copier-coller)

```bash
REPO=~/git/desktop-kDrive
TAG=<TAG>   # ex: v3.8.3

git -C "$REPO" checkout raspbian-aarch64-16k
git -C "$REPO" fetch --tags upstream
git -C "$REPO" merge "$TAG"
git -C "$REPO" submodule update --init --recursive

# Vérifier version.json si nécessaire, puis :

"$REPO/infomaniak-build-tools/linux/build-raspbian.sh" \
    -d "$REPO" --skip-sentry

"$REPO/infomaniak-build-tools/linux/build-deb.sh" \
    -d "$REPO/build-raspbian"

ls -lh "$REPO/build-raspbian/"*.deb
```

---

## Notes

- **Rebuild complet :** supprimer le répertoire `build-raspbian/` avant l'étape 5 (`rm -rf build-raspbian`). Nécessaire si des fichiers CMake ont changé de façon incompatible.
- **CPack :** le script `build-deb.sh` exige que `build-raspbian/CPackConfig.cmake` existe (généré automatiquement par CMake lors de la configuration).
- **Submodules :** `src/3rdparty/keychain`, `src/3rdparty/qt-piwik-tracker`, `src/3rdparty/utf8proc`.
