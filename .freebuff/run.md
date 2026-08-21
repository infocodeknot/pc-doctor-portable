# Run Doc — PC Doctor Portable Preview

## Project Type
Pure PowerShell/WPF desktop application. No web server, no package.json, no npm.

## Artifacts to Reproduce
None — this is a static HTML project explorer, not a dev-server preview.

## How to View
Open `.freebuff/project-view.html` in a browser. The Freebuff preview registers
it directly via `htmlPath` (no server process needed).

### To re-register manually:
```
register_preview(htmlPath=".freebuff/project-view.html")
```

### If you need a full local server instead:
Use any static file server, e.g.:
```
npx serve .
```
Then open the URL it prints and navigate to `.freebuff/project-view.html`.
