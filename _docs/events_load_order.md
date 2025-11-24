Voici la séquence générale des événements pour un chargement normal :

    Chargement des fichiers : Les fichiers XML et Lua de l'addon sont chargés séquentiellement comme listés dans le fichier .toc.

    ADDON_LOADED → addOnName

        Cet événement se déclenche une fois pour chaque addon lorsqu'il a fini de se charger, y compris toutes ses variables sauvegardées (SavedVariables).

        C'est le point le plus fiable pour initialiser les données spécifiques à l'addon et vérifier que ses variables sont prêtes. L'argument est le nom de l'addon qui vient d'être chargé.

    PLAYER_LOGIN

        Se déclenche pendant l'écran de chargement, avant le premier PLAYER_ENTERING_WORLD.

        À ce stade, la plupart des informations sur le monde et le personnage (profil, talents, etc.) sont disponibles pour l'interface utilisateur. C'est l'endroit idéal pour effectuer l'initialisation unique de l'interface et le placement des cadres (frames).

    PLAYER_ENTERING_WORLD → isInitialLogin, isReloadingUi

        Se déclenche pendant n'importe quel écran de chargement (connexion, rechargement de l'interface, entrée/sortie d'instance).

        C'est le premier événement de ce type après PLAYER_LOGIN. L'information sur les talents est également disponible lors d'un rechargement de l'interface (/reload). On l'utilise pour l'initialisation qui doit se faire chaque fois que le joueur entre dans une zone (par exemple, ajustements de l'interface en fonction de la zone).

---

## Recommended AddOn Load Sequence (improvements)

To avoid duplicate event handlers, race conditions, and missed updates, prefer the following order and event ownership:

1. ADDON_LOADED (Addon core)
    - Initialize database and saved variables (Addon.Database:Initialize())
    - Initialize configuration and locale (Addon.Config:Initialize())
    - Set the `Addon.db` reference - do NOT start module event registration here
2. PLAYER_LOGIN (Modules initialize themselves)
    - Initialize session and session event listeners (Addon.Session:Initialize() -> registers PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, TIME_PLAYED_MSG)
    - Initialize statistics/views (Addon.Stats:Initialize() -> registers PLAYER_XP_UPDATE, TIME_PLAYED_MSG)
    - Initialize XP controller (Addon.BarManager:Initialize() -> initializes selected style frame; controller and services should register XP events such as PLAYER_XP_UPDATE, PLAYER_LEVEL_UP, UPDATE_EXHAUSTION)
    - Initialize options (Addon.Options:Initialize())
    - This order ensures Session/Stats are ready before XPBar starts broadcasting player XP updates
3. PLAYER_ENTERING_WORLD
    - Modules perform per-world initialization (session snapshots, quest cache, UI adjustments)
    - XPBar sets `Addon._lastKnownXP/Level` snapshots for safe animation deltas

Notes:

- Modules should own registering and unregistering of their events (XPBar for XP events, Stats for stats-related events, Session for session/time events). This avoids duplicate handling and keeps the global event dispatcher focused on addon lifecycle only.

- Use `Addon.EventBus` with canonical constants from `core/EventNames.lua` (accessible as `Addon.EventNames`) for cross-module publishes/subscriptions instead of ad-hoc string literals or a legacy observer registry.

- For a safe migration, add a `Addon.db.legacyMode` flag during deprecation to keep behavior backward compatible for one release.
