# Cal Sorbonne

Application Flutter permettant de consulter les emplois du temps des masters de l’UFR d’Informatique de Sorbonne Université.

## Démo en ligne

L'application est déployée et accessible à l'adresse suivante :  
👉 **[https://calsorbonne.pages.dev/](https://calsorbonne.pages.dev/)**

## Fonctionnalités

- Connexion au serveur CalDAV de l’UFR : `cal.ufr-info-p6.jussieu.fr`
- Sélection des masters et spécialités :
  - ANDROIDE, BIM, DAC, IMA, IQ, RES, SAR, SESI, SFPN, STL, etc.
  - Niveaux M1 et M2
- Filtrage des Unités d’Enseignement (UE) à afficher
- Affichage des cours, TD, TP, examens, soutenances, etc.
- Option « Afficher uniquement la salle » pour masquer le nom du cours
- Sauvegarde automatique des préférences (masters et UEs sélectionnés)

## Technologies utilisées

- Flutter
- SharedPreferences

## Installation (Développement)

1. Cloner le dépôt :
   ```bash
   git clone <url-du-depot>
   cd cal_sorbonne
   ```

2. Installer les dépendances :
   ```bash
   flutter pub get
   ```

3. Lancer l’application :
   ```bash
   flutter run
   ```

## Déploiement

L'application est déployée sur **Cloudflare Pages**.

## Auteur

**Bilal Chetouani**