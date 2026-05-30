# GlobalEgg Business Central Extensions

Documentation for the GlobalEgg Business Central AL extensions used for the BC 26 implementation and the
data migration workstream.

## Apps

| App | Purpose |
| --- | --- |
| **GlobalEgg Core** | Core GlobalEgg app: the `GBE_*` fields the migrated data lives in, role center, setup, install/upgrade, permissions. |
| **GlobalEgg Migration** | One-time migration extension that copies legacy field data into the GlobalEgg Core (GBE) fields. |

## Guides

- **[Data Migration Runbook](data-migration.md)** — the four-stage runbook (Preparations → Execution →
  Uninstalling → Validation) for moving an environment off the legacy system onto GlobalEgg Core.

> The runbook published here is the **sanitized** version: environment-specific values (database name,
> server instance, company names, app IDs) appear as placeholders, and the source system is referred to
> generically as the **legacy system**. Substitute your own values from the reference table at the top of
> the runbook.

## Target environment

Microsoft Dynamics 365 Business Central **26**. The Core and Migration apps share the GlobalEgg `GBE`
object prefix/affix.
