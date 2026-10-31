{{flutter_js}}
{{flutter_build_config}}

// Le jeu s'affiche dans <div id="app"> (cadre téléphone sur ordinateur).
// Pas de service worker : celui de Flutter est obsolète et pouvait servir une ancienne version.
const host = document.getElementById("app");
_flutter.loader.load({
  config: { hostElement: host },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine({ hostElement: host });
    await appRunner.runApp();
    document.getElementById("loading")?.remove();
  },
});
