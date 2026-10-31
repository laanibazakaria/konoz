{{flutter_js}}
{{flutter_build_config}}

// Numéro de version ajouté à chaque mise en ligne (remplacé par le workflow) :
// le navigateur télécharge le nouveau jeu au lieu de garder l'ancien en cache.
for (const b of _flutter.buildConfig.builds) {
  if (b.mainJsPath) b.mainJsPath += "?v=__BUILD__";
}

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
