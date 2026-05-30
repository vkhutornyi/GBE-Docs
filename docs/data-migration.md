# Data Migration Runbook

Migrating a Business Central environment **off the legacy system** onto the **GlobalEgg Core (GBE)** field
model. This page is a short overview — the full step-by-step runbook is in the download below.

[Download the full runbook (.zip)](downloads/data-migration-runbook.zip){ .md-button .md-button--primary }

The zip contains the complete sanitized runbook plus a Purchase Line Archive **SQL template**. Values that
differ per environment (database, server instance, company names, app IDs) appear as placeholders, and the
source system is referred to generically as the **legacy system**.

> ⚠️ The migration writes directly to production data and **cannot be automatically undone**. Take a full
> SQL backup before you start and keep it until validation passes.

## The four stages

Perform these **in order**:

1. **Preparations** — Take a full database backup, then publish, sync, and install *GlobalEgg Core* and the
   *GlobalEgg Migration* app in every company from the BC Administration Shell.
2. **Execution** — Run the **Migration Wizard once per company** (Items, Locations, Purchase Lines, Machine
   Centers, Egg Weight Classes, posted purchase lines), then run the **Purchase Line Archive SQL script once
   per database** (that table is migrated by set-based SQL because it can hold 13M+ rows per company).
3. **Uninstalling the legacy system** — From **Extension Management**, uninstall the *GlobalEgg Migration*
   app first, then the legacy extensions starting from the legacy *System Helper* (its dependents cascade).
   Uninstalling keeps the legacy data tables in place so validation can still read them.
4. **Validation** — Confirm only *GlobalEgg Core* remains installed, spot-check migrated GBE fields,
   verify the archive migration with SQL, and run a smoke test by posting a **new** purchase document.

For the detailed commands, SQL, screenshots of each wizard step, validation queries, and the rollback
procedure, use the download above.
