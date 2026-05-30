# GBE-Docs

Public documentation site for the **GlobalEgg Business Central** extensions and the **OVO-Vision migration**.

This repository contains **documentation only** — no Business Central app source code. The published
runbook is a **sanitized** version: environment-specific values (database name, server instance, company
names, app IDs) appear as placeholders.

🔗 **Live site:** https://vkhutornyi.github.io/GBE-Docs/

## Structure

```text
GBE-Docs/
├── docs/
│   ├── index.md            # Landing page
│   └── ovo-migration.md    # OVO-Vision migration runbook (sanitized)
├── mkdocs.yml              # MkDocs Material configuration
├── requirements-docs.txt   # Pinned build dependencies
└── .github/workflows/deploy-docs.yaml   # Build + deploy to GitHub Pages
```

## Build locally

```bash
pip install -r requirements-docs.txt
mkdocs serve     # preview at http://127.0.0.1:8000
mkdocs build --strict
```

## Publishing

On push to `main`, the **Deploy Docs** workflow builds the site and deploys it to GitHub Pages.
Enable it once under **Settings → Pages → Build and deployment → Source = GitHub Actions**.
