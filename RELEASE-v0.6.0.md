# BVM Mobile v0.6.0 — Release Notes

**APK:** `bvm-v0.6.0.apk` (36.9 MB)

---

## ✨ Nouveautés

### 🎛️ Contrôle Start/Stop des VMs
- Les VMs ne démarrent plus automatiquement à la création
- **Bouton Start** sur l'écran détail de la VM pour la lancer manuellement
- **Bouton Stop** pour arrêter proprement la VM
- État `Running` / `Stopped` persisté dans `state.json`

### 📱 Écran Détail VM (`VmDetailScreen`)
- Accès en tapant sur une VM depuis la liste
- Affichage du statut, taille, distro, date de création
- Actions contextuelles regroupées : Terminal, Files, Port Forwards
- Gestion Backup / Delete depuis l'AppBar

### ⚙️ Auto-start
- Checkbox **"Auto-start on app launch"** par VM
- Les VMs marquées auto-start se lancent automatiquement au démarrage de l'application

### 🏠 Liste des VMs améliorée
- Indicateur visuel 🟢/⚫ selon l'état Running/Stopped
- Icône play/stop dans l'avatar
- Navigation vers le détail de la VM au tap

---

## 🛠️ Corrections
- Le terminal n'est accessible que quand la VM est en cours d'exécution
- Les fichiers et port forwards sont masqués quand la VM est arrêtée

---

## 📍 Workflow utilisateur
1. Créer une VM → elle apparaît comme **Stopped**
2. Taper sur la VM → écran détail
3. Appuyer sur **START VM**
4. Une fois démarrée : accès à **Terminal**, **Files**, **Port Forwards**
5. Appuyer sur **STOP VM** pour l'arrêter
