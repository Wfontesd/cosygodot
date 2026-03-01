# Floating Sanctuary — README

## Pitch
**Floating Sanctuary** est un jeu cosy de gestion d’un écosystème vivant sur une **île flottante dans les nuages**, en **2.5D isométrique sur Unity**, où le joueur **incarne un personnage** (déplacement libre) et élève des **créatures nées d’œufs magiques**.  
Les créatures vivent de manière autonome, travaillent et influencent un **équilibre élémentaire doux** (jamais punitif). Le joueur est un **gardien** : il aménage, assigne, observe et harmonise un monde qui continue de vivre sans micro-management.

---

## Piliers de design
- **Cozy fantasy** : ambiance calme, chaleureuse, vivante.
- **World-first** : l’état du monde se lit dans l’environnement et les comportements.
- **Proximité** : *agir = se déplacer* (pas d’actions à distance via clic).
- **Autonomie** : les créatures agissent seules ; le joueur orchestre.
- **Stratégie douce** : optimisation et synergies, sans punition brutale.

---

## Plateforme & Tech
- **Moteur :** Unity
- **Caméra :** 2.5D **isométrique (2D iso)**
- **Style :** Voxel **haute qualité** (formes arrondies, lisibles, non agressives)
  - Pipeline possible : sprites iso pré-rendus depuis voxels, meshes voxel lissés, ou hybride.

---

## Direction Artistique

### Ambiance
- **Île flottante** dans les nuages
- Atmosphère **calme mais vivante**
- Palette **pastel** + accents légèrement saturés
- **Lumière chaude et douce**
- Animations **subtiles** (vent, particules, micro-idles)

### Style visuel
- Voxel haute qualité, **silhouettes arrondies** (semi-chibi)
- Proportions mignonnes mais lisibles
- **Aucun voxel brut** / cubique agressif
- Forte lisibilité à distance caméra (silhouettes + VFX doux)

---

## Le Joueur (contrôle type Animal Crossing)
Le joueur se déplace librement sur l’île et interagit directement avec le monde.
- Déplacement walk/run en isométrique
- Interaction contextuelle **uniquement à portée**
- Rythme : promenade, observation, petites tâches, amélioration progressive

---

## Interactions & UX (100% par proximité)
### Règle centrale
- **Pas de clic pour interagir à distance**
- Pour agir, le joueur doit :
  1. **Se rendre** sur place  
  2. Entrer dans une **zone de proximité**  
  3. Déclencher l’action via une **touche/bouton d’interaction**

### Feedback d’interaction
Quand une interaction est possible :
- Surbrillance douce / outline léger
- Petite icône diegétique au-dessus de l’objet/créature
- Prompt minimal en bas (ex : “Interagir”, “Collecter”, “Assigner”)

### UI
- **Prompt contextuel bas** (minimal) uniquement quand à portée
- **Menu radial** déclenché près d’un élément pour les actions locales
- Gestion détaillée uniquement **au bâtiment** (panneau léger)

---

## Les Créatures (cœur du système)
Chaque créature :
- Naît d’un **œuf magique**
- Possède un **élément** : Plante, Feu, Eau, Roche, Magie
- A un comportement **autonome**
- Peut être **assignée** à un bâtiment (via interaction de proximité)
- Influence l’écosystème global

### Éléments
- **🌿 Plante** : replante, coupe du bois, stimule la croissance  
  *Silhouette organique avec feuilles*
- **🔥 Feu** : chauffe incubateurs, accélère certains processus  
  *Silhouette dynamique avec crête flamboyante stylisée*
- **💧 Eau** : améliore récupération, optimise repos  
  *Formes fluides et arrondies*
- **🪨 Roche** : mine, stabilise, augmente solidité  
  *Silhouette basse et robuste*
- **✨ Magie** : amplifie auras, effets spéciaux doux  
  *Formes flottantes avec cristaux*

---

## Boucle de gameplay principale
1. Obtenir un **œuf**
2. L’amener à un **incubateur** (déplacement + dépôt)
3. L’**incuber**
4. Observer la créature **vivre et travailler**
5. Construire des **bâtiments** adaptés
6. **Assigner** certaines créatures (par proximité)
7. **Équilibrer** les éléments
8. Débloquer **nouvelles zones / biomes**

> Le monde évolue même sans intervention constante.

---

## Bâtiments
Chaque bâtiment :
- A une **capacité** (ex : 3 créatures)
- Offre une **fonction claire**
- Génère des **bonus** selon synergies élémentaires
- Affiche les créatures assignées **physiquement** dans/près du bâtiment

### Exemples
- 🥚 **Incubateur**
- 🛏️ **Zone de repos**
- 🌿 **Cabane nature**
- 🔮 **Tour magique**
- 🪨 **Atelier minier**

### Interaction bâtiment (par proximité)
- Le joueur se place au point d’interaction (porte, panneau, établi)
- Ouvre un panneau léger : occupants, bonus, synergies, réglages

---

## Système d’Écosystème (équilibre doux)
Le monde repose sur un équilibre dynamique entre les 5 éléments.  
Un déséquilibre produit des effets **doux**, jamais punitifs.

### Exemples
- Trop de **Feu** → végétation ralentie
- Trop d’**Eau** → incubation plus lente
- Trop de **Roche** → moins de dynamisme
- Trop de **Magie** → instabilité douce (VFX + comportements fantasques)

---

## Progression
- **Expansion** de l’île
- Déblocage de **biomes spécialisés**
- Nouvelles **espèces/variantes**
- **Journal du parc**
- **Amélioration** des bâtiments

Objectif : créer un écosystème harmonieux, beau et prospère.

---

## Expérience recherchée
- Sérénité
- Attachement aux créatures
- Satisfaction stratégique douce
- Sentiment d’un monde vivant autonome  
Le joueur n’est pas un contrôleur strict, mais un **gardien** d’un petit monde magique.

---

## Résumé en une phrase
**Floating Sanctuary** est un jeu cosy de gestion en voxel, en **2.5D isométrique sur Unity**, où le joueur contrôle son personnage et interagit **uniquement par proximité** avec des créatures autonomes et des bâtiments pour développer une île flottante harmonieuse et vivante.
