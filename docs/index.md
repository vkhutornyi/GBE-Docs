# GlobalEgg Business Central Extensions

Documentation for the GlobalEgg Business Central AL extensions used for the BC 26 implementation and the
OVO-Vision migration workstream.

## Apps

| App | Purpose |
| --- | --- |
| **GlobalEgg Core** | Core GlobalEgg app: the `GBE_*` fields the migrated data lives in, role center, setup, install/upgrade, permissions. |
| **GlobalEgg OVO Migration** | One-time migration extension that copies OVO-Vision field data into the GlobalEgg Core (GBE) fields. |

## Guides

- **[OVO-Vision Data Migration Runbook](ovo-migration.md)** — the four-stage runbook (Preparations →
  Execution → Uninstalling → Validation) for moving an environment off OVO-Vision onto GlobalEgg Core.

> The runbook published here is the **sanitized** version: environment-specific values (database name,
> server instance, company names, app IDs) appear as placeholders. Substitute your own values from the
> reference table at the top of the runbook.

## Target environment

Microsoft Dynamics 365 Business Central **26**. The Core and OVO Migration apps share the GlobalEgg `GBE`
object prefix/affix.
