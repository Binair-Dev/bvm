# BVM Mobile v0.5.0 — Release Notes

**APK:** `bvm-v0.5.0.apk` (36.8 MB)

---

## ✨ Nouveautés

### 📝 Éditeur de texte intégré
- Ouvrir et éditer n'importe quel fichier texte depuis le **VM Explorer**
- **Syntax highlighting** pour 25+ langages (Preview tab)
- Sauvegarde directe dans la VM via `writeRootfsFile`
- Détection des modifications non sauvegardées (`*` dans le titre)
- Double onglet : **Edit** (édition) et **Preview** (coloration syntaxique)
- Fonts monospace (DejaVu Sans Mono)

### 📁 File Sharing (depuis v0.4.0)
- Upload Android → VM (`/mnt/shared`)
- Download VM → Android (fichiers + dossiers ZIP)
- VM Explorer pour naviguer dans le filesystem

---

## 📍 Comment utiliser l'éditeur
1. Accueil → choisir une VM
2. Menu **⋮** → **Files**
3. Onglet **VM Explorer** → naviguer vers un fichier
4. **Long press** sur le fichier → **Edit**
5. Éditer dans l'onglet **Edit**
6. Vérifier le rendu dans l'onglet **Preview**
7. Appuyer sur 💾 pour sauvegarder

---

## 🖥️ Langages supportés
`dart`, `python`, `javascript`, `typescript`, `json`, `yaml`, `xml`, `html`, `css`, `scss`, `bash`, `c`, `cpp`, `java`, `kotlin`, `swift`, `go`, `rust`, `ruby`, `php`, `sql`, `markdown`, et plus.
