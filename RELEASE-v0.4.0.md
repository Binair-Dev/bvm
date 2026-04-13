# BVM Mobile v0.4.0 — Release Notes

**APK:** `bvm-v0.4.0.apk` (34 MB)

---

## ✨ Nouveautés

### 📁 File Sharing Android ↔ VM
- **Upload** de fichiers depuis Android vers la VM (`/mnt/shared`)
- **Download** de fichiers et dossiers (ZIP auto) depuis la VM vers Android
- **VM Explorer** intégré pour naviguer dans tout le filesystem de la VM
- Accès via le menu ⋮ d'une VM → **Files**

---

## 🛠️ Corrections
- Bind `--bind` manquant dans le terminal interactif empêchant l'accès à `/mnt/shared`
- Dossier `shared/<vm>` créé automatiquement au démarrage de chaque terminal
- File sharing fonctionne aussi bien en terminal qu'en commandes synchronisées

---

## 📍 Accès dans l'app
1. Accueil → appuyer sur une VM
2. Menu **⋮** (3 points) → **Files**
3. Onglet **Shared** pour uploader
4. Onglet **VM Explorer** pour naviguer et télécharger

---

## 🖥️ Chemin VM
```bash
ls /mnt/shared
```
