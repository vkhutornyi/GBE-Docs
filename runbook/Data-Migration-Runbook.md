# Data Migration Runbook

End-to-end runbook for migrating a Business Central environment **off the legacy system** and onto the
**GlobalEgg Core (GBE)** field model.

> **This is the sanitized / public version of the runbook.** Environment-specific values (database name,
> server instance, company names, and app IDs) are shown as placeholders such as `<DATABASE>`, and the
> source system is referred to generically as the **legacy system** with a `LEGACY_` field prefix. Fill in
> the real values for your environment from the table below before running anything. The team keeps an
> internal copy with the concrete names and values filled in.

The process has **four stages** that must be performed **in order**:

1. **[Preparations](#stage-1-preparations)** – publish & install *GlobalEgg Core* and the *GlobalEgg Migration* app from the BC Administration Shell.
2. **[Execution](#stage-2-execution)** – run the Migration Wizard **per company**, then run the **Purchase Line Archive SQL script** **per database**.
3. **[Uninstalling](#stage-3-uninstalling-the-legacy-system)** – remove the legacy extensions (start from the legacy *System Helper* app).
4. **[Validation](#stage-4-validation)** – confirm every field migrated and nothing is broken.

> ⚠️ **This migration writes directly to production data and cannot be automatically undone.**
> Take a full SQL backup of the BC database **before Stage 2** and keep it until Stage 4 passes.

---

## Reference data — fill in for your environment

Substitute these placeholders throughout the runbook with your own values.

| Placeholder              | Meaning                                              | Where to find it                                  |
| ------------------------ | ---------------------------------------------------- | ------------------------------------------------- |
| `<BC_INSTANCE>`          | BC Server Instance name                              | `Get-NAVServerInstance`                           |
| `<DATABASE>`             | SQL database name                                    | BC Server Admin / SQL Server                      |
| `<NN Company Name>`      | A company's physical name prefix (`00 …`, `01 …`)    | SQL table-name lookup (Stage 2B)                  |
| `<GBE_CORE_APP_ID>`      | GlobalEgg Core app id                                | `GlobalEggCore/app.json`                          |
| `<GBE_MIGRATION_APP_ID>` | GlobalEgg Migration app id                           | Migration app `app.json`                          |
| `<LEGACY_APP_ID>`        | Legacy system app id (the source fields' publisher)  | Legacy app `app.json` / Extension Management      |
| `<EXT_TABLE_APP_ID>`     | App id that owns the Purchase Line Archive `$ext` table | SQL table-name lookup (Stage 2B)               |
| `LEGACY_`                | The legacy system's source-field prefix              | Column names in the database companion tables     |

App/version facts that are the same in every deployment:

| Item                    | Value                                              |
| ----------------------- | -------------------------------------------------- |
| GlobalEgg Core          | publisher **GlobalEgg**, v `1.0.0.0`               |
| GlobalEgg Migration     | publisher **GlobalEgg**, v `1.0.0.0`               |
| Platform / Application  | `26.0`                                             |

> The **GlobalEgg Migration** app depends on **both** *GlobalEgg Core* **and** the *legacy system*.
> The legacy system must still be installed during Stages 1–2; it is removed only in Stage 3.

---

## Prerequisites

- Member of **db_owner** on the BC SQL database (needed for the SQL script in Stage 2).
- Local admin on the BC server (to run the **Business Central Administration Shell** elevated).
- **SUPER** permission set in each BC company you will migrate.
- The two compiled `.app` packages copied to the server, e.g.:
  - `GlobalEgg_GlobalEgg Core_1.0.0.0.app`
  - `GlobalEgg_GlobalEgg Migration_1.0.0.0.app`
- A verified **full database backup**.

---

## Stage 1 — Preparations

Goal: get *GlobalEgg Core* and the *GlobalEgg Migration* app **Published → Synced → Installed** in every
company, using the BC Administration Shell.

### 1.1 Take a full database backup

Before publishing anything, take a **full SQL backup of the `<DATABASE>` database** and verify it
restores. Stage 2 writes directly to data and cannot be automatically undone — this backup is the
rollback point (see [Rollback](#rollback)). Keep it until Stage 4 passes.

### 1.2 Open the Business Central Administration Shell

On the BC server: **Start → Business Central Administration Shell** → right-click → **Run as administrator**.

Confirm the instance name:

```powershell
Get-NAVServerInstance | Select-Object ServerInstance, State, Version
```

Set a variable so the rest of the commands are copy-paste safe:

```powershell
$Instance = '<BC_INSTANCE>'
$AppPath  = 'C:\Install\GlobalEgg'   # folder where you copied the two .app files
```

### 1.3 Publish the apps (server gets the package)

Publish **Core first** (the Migration app depends on it). Use `-SkipVerification` if the packages are
not signed with a trusted certificate (typical for in-house apps).

```powershell
Publish-NAVApp -ServerInstance $Instance -Path "$AppPath\GlobalEgg_GlobalEgg Core_1.0.0.0.app" -SkipVerification
Publish-NAVApp -ServerInstance $Instance -Path "$AppPath\GlobalEgg_GlobalEgg Migration_1.0.0.0.app" -SkipVerification
```

Verify they are published:

```powershell
Get-NAVAppInfo -ServerInstance $Instance | Where-Object Publisher -eq 'GlobalEgg' |
    Select-Object Name, Version, IsInstalled, SyncState
```

### 1.4 Sync the schema (per company)

`Sync-NAVApp` creates the new GBE companion tables/fields in the database. Run **Core first**, then Migration.

```powershell
Sync-NAVApp -ServerInstance $Instance -Name 'GlobalEgg Core'      -Version 1.0.0.0
Sync-NAVApp -ServerInstance $Instance -Name 'GlobalEgg Migration' -Version 1.0.0.0
```

### 1.5 Install the apps

```powershell
Install-NAVApp -ServerInstance $Instance -Name 'GlobalEgg Core'      -Version 1.0.0.0
Install-NAVApp -ServerInstance $Instance -Name 'GlobalEgg Migration' -Version 1.0.0.0
```

### 1.6 Confirm Stage 1 is complete

```powershell
Get-NAVAppInfo -ServerInstance $Instance | Where-Object Publisher -eq 'GlobalEgg' |
    Select-Object Name, Version, IsInstalled
```

Both rows must show **`IsInstalled = True`**. ✅ Stage 1 done.

---

## Stage 2 — Execution

The migration has **two parts**:

- **2A — Migration Wizard** → run **once per company**. Migrates Items, Locations, Purchase Lines,
  Machine Centers, Egg Weight Classes, and Posted Purchase Invoice/Cr.Memo lines.
- **2B — Purchase Line Archive SQL script** → run **once per database**. A single run covers **all
  companies** in that database (one `UPDATE` block per company table). Migrates the Purchase Line Archive
  fields (`GBE_Type`, `GBE_PriceUnitOfMeasureCode`, `GBE_QuantityPerPriceUnit`, `GBE_PricePerPriceUnit`,
  `GBE_PriceUnitOfMeasure`). The wizard does **not** touch Purchase Line Archive.

> 🔁 **Run 2A for every company**, then **run 2B once per database** to cover all those companies in one pass.

### 2A — Run the Migration Wizard (per company)

1. Sign in to the **Business Central Web Client**.
2. **Switch to the company** you want to migrate (Settings ⚙ → **My Settings → Company**).
3. Open the wizard via **either** route:
   - **Tell Me** (Alt+Q) → search **“GlobalEgg Data Migration”** → open it, **or**
   - **Assisted Setup** page → group **Extensions** → **GlobalEgg Data Migration**.
4. The wizard has three steps:
   - **Step 1 – Welcome:** read the summary → **Next >**.
   - **Step 2 – Confirm:** confirms the action is irreversible and that a backup exists → **Start >**.
     A progress dialog shows the current **Table** and **Records** counter while it runs.
   - **Step 3 – Done:** shows **“Migration Complete”**, **or** an error panel with the message and call
     stack if something failed.
5. If you see the **Migration Error** panel:
   - Copy the error message + call stack.
   - The migration commits **per table**, so tables processed before the failure are already migrated.
     Re-running the wizard is **idempotent** for value conversions and safe to repeat after fixing the cause.
6. On **Migration Complete**, click **Finish**. The wizard marks the assisted setup as completed.
7. **Repeat for the next company.**

### 2B — Purchase Line Archive SQL script (once per database)

Run the Purchase Line Archive SQL script against the BC database **once**. It performs a direct `UPDATE`
per company table — so a single run migrates every company in that database — copying the legacy archive
fields into the GBE archive fields. Each per-company block looks like this:

```sql
UPDATE [<DATABASE>].[dbo].[<NN Company Name>$Purchase Line Archive$<EXT_TABLE_APP_ID>$ext]
SET [GBE_Type$<GBE_CORE_APP_ID>]                   = [LEGACY_ItemType$<LEGACY_APP_ID>],
    [GBE_PriceUnitOfMeasureCode$<GBE_CORE_APP_ID>] = [LEGACY_PriceUnitOfMeasureCode$<LEGACY_APP_ID>],
    [GBE_QuantityPerPriceUnit$<GBE_CORE_APP_ID>]   = [LEGACY_QuantityPerPriceUnit$<LEGACY_APP_ID>],
    [GBE_PricePerPriceUnit$<GBE_CORE_APP_ID>]      = [LEGACY_PricePerPriceUnit$<LEGACY_APP_ID>],
    [GBE_PriceUnitOfMeasure$<GBE_CORE_APP_ID>]     = [LEGACY_PriceUnitOfMeasure$<LEGACY_APP_ID>];
```

Before running, list the physical table names so you know the exact company prefixes and the
`<EXT_TABLE_APP_ID>` suffix for this database:

```sql
SELECT name
FROM   [<DATABASE>].sys.tables
WHERE  name LIKE '%Purchase Line Archive%$ext'
ORDER BY name;
```

Add one `UPDATE` block per company returned by that query.

**Execution steps:**

1. Open **SQL Server Management Studio (SSMS)** and connect to the BC SQL instance.
2. Open the script, run the table-name check above to confirm it covers every company, then **execute the script**.
3. **Run once per database** — the script already covers all companies in the database. Only repeat if
   companies live in **separate** databases.

> ℹ️ **Why direct SQL here?** The Purchase Line Archive table is huge — in some companies it holds
> **more than 13 million records**. Migrating it row-by-row through the wizard (AL `Modify` per record)
> would take far too long and risk timeouts. A single set-based SQL `UPDATE` migrates all those rows in one
> pass, which is why PLA is handled by the script instead of the wizard.
> ✅ Stage 2 done when 2A and 2B have completed.

---

## Stage 3 — Uninstalling the legacy system

Once data is migrated and validated for **all** companies, remove the legacy extensions from the
**Extension Management** page in the BC Web Client (no admin shell needed). The legacy system ships
**many** extensions, and most of them **depend on its *System Helper* app**, so that app is the right
place to start — BC will offer to uninstall its dependents in the same action.

> 🚫 **Do not uninstall the `GlobalEgg Migration` app yet if you might still need to re-run any
> company.** It depends on the legacy system, so uninstalling the legacy apps will force it out too.
> Finish & validate all companies first (Stages 2 & 4), **then** uninstall.

### 3.1 Open Extension Management and review the legacy apps

1. Sign in to the **Business Central Web Client** as an administrator.
2. **Tell Me** (Alt+Q) → search **“Extension Management”** → open it.
3. The page lists every installed extension. Locate the **legacy apps** (their publisher), including the
   legacy **System Helper**, and note how many there are so you can confirm them all gone at the end.

### 3.2 Uninstall the GlobalEgg Migration app first

It depends on the legacy system, so remove it before the legacy apps:

1. In **Extension Management**, select **GlobalEgg Data Migration** (Published by **GlobalEgg**).
2. Choose **Uninstall** in the action bar and confirm.

### 3.3 Uninstall the legacy apps starting from the System Helper

1. In **Extension Management**, select the legacy **System Helper** app.
2. Choose **Uninstall**.
3. BC detects the dependent legacy extensions and shows a confirmation listing them. **Enable the option to
   uninstall the dependent extensions** (e.g. *“Uninstall related/dependent extensions”*) and confirm.
   BC then uninstalls the dependents first and the System Helper last, in one action.
4. If any legacy app is left because it wasn’t covered by the cascade, select it directly and **Uninstall**
   it the same way. Repeat until none remain.

> 💡 The **Uninstall** action only removes the extension; it leaves the legacy data tables in place. That is
> intentional here — keep the `LEGACY_*` data until Stage 4 has passed (the validation queries read it).

### 3.4 Confirm the legacy apps are gone

Back in **Extension Management**, filter/scan the list and confirm there are **no remaining legacy
extensions** showing as installed.

✅ Stage 3 done when no legacy extension remains installed.

---

## Stage 4 — Validation

Confirm the migration produced correct data and the environment is healthy.

> ℹ️ **The legacy system is uninstalled by now, but its data is still here.** Uninstalling an extension
> (Stage 3) removes the app and its UI fields **but retains the data tables**. So the `LEGACY_*` columns
> still exist in the database and can be read **with SQL** — that is why the source-vs-destination checks
> below use SQL queries rather than the BC client (the legacy fields are no longer shown on any page). The
> `GBE_*` fields remain fully visible in the UI because **GlobalEgg Core** is still installed.

### 4.1 Extensions health

```powershell
$Instance = '<BC_INSTANCE>'
Get-NAVAppInfo -ServerInstance $Instance | Where-Object Publisher -eq 'GlobalEgg' |
    Select-Object Name, Version, IsInstalled
Get-NAVServerInstance $Instance | Select-Object ServerInstance, State    # State = Running
```

Expected final footprint:

- **GlobalEgg Core** → `IsInstalled = True` (it stays — it owns the GBE fields the data now lives in).
- **GlobalEgg Migration** → `IsInstalled = False` (it is a one-time tool that **depends on the legacy
  system**, so it is uninstalled together with the legacy apps in Stage 3 — this is expected, not a problem).

Check that the **assisted setup** completed without errors in each company (BC Web Client → *Assisted Setup*).

### 4.2 Spot-check migrated values in the BC client (per company)

For a sample of records, open the GBE fields in the UI and confirm they are **populated and sensible**.
(The legacy source fields are no longer on these pages after Stage 3 — to compare against the `LEGACY_`
source, use the SQL queries in 4.3.)

| Area             | Open page                        | Check                                                                                  |
| ---------------- | -------------------------------- | -------------------------------------------------------------------------------------- |
| Items            | **Item Card**                    | `GBE Type`, `GBE Housing Type Code`, `GBE Egg Color Code`, `GBE Egg Weight Class Code` populated |
| Locations        | **Location Card**                | `GBE Type` set (expect *Farm* / *FeedMill*)                                             |
| Egg Weight Class | **GBE Egg Weight Class** list    | Codes present (`XL`, `LG`, …) with descriptions populated                              |
| Purchase docs    | **Purchase Order/Invoice lines** | `GBE Type` + price-unit fields populated                                                |
| Machine Center   | **Machine Center Card**          | `GBE Machine Type` set (expect *FeedMill* etc.)                                         |

To verify a GBE value actually **matches its source**, compare them in SQL — this works because the legacy
data is retained (see the note at the top of Stage 4). The proven query pattern is the Purchase Line
Archive check in **4.3**; apply the same idea to other tables by reading the `LEGACY_` and `GBE_` columns
from the retained companion tables. Use the lookup query from Stage 2B
(`… WHERE name LIKE '%<table>%$ext'`) to find the exact physical table/column names for each table before
writing the comparison.

### 4.3 Validate the Purchase Line Archive SQL result

These run directly against SQL and stay valid **after** the legacy system is uninstalled, because the
`LEGACY_*` archive data is retained in the database. Confirm **no** archive row that has a legacy value was
left without the matching GBE value. Run per company table (same DB/company/IDs as in Stage 2B). The result
should be **0 rows**:

```sql
SELECT COUNT(*) AS MissedRows
FROM   [<DATABASE>].[dbo].[<NN Company Name>$Purchase Line Archive$<EXT_TABLE_APP_ID>$ext]
WHERE  [LEGACY_PriceUnitOfMeasureCode$<LEGACY_APP_ID>] <> ''
  AND  [GBE_PriceUnitOfMeasureCode$<GBE_CORE_APP_ID>] = '';
```

Optionally compare aggregate totals (legacy vs GBE) for a numeric field as a sanity check:

```sql
SELECT SUM([LEGACY_PricePerPriceUnit$<LEGACY_APP_ID>]) AS SrcSum,
       SUM([GBE_PricePerPriceUnit$<GBE_CORE_APP_ID>])  AS GbeSum
FROM   [<DATABASE>].[dbo].[<NN Company Name>$Purchase Line Archive$<EXT_TABLE_APP_ID>$ext];
```

`SrcSum` and `GbeSum` must be equal.

### 4.4 Functional smoke test with new data

The checks above prove the **historical** data migrated. This step proves the system works **going forward**
on **GlobalEgg Core alone** (the legacy system is gone) — i.e. that new transactions use the GBE fields correctly:

- **Create a brand-new purchase document** (Purchase Order/Invoice) on a migrated Item → confirm the
  **GBE price-unit fields** (`GBE_PriceUnitOfMeasureCode`, `GBE_QuantityPerPriceUnit`, `GBE_PricePerPriceUnit`,
  `GBE_PriceUnitOfMeasure`) populate/calculate as expected, then **post it** and confirm it posts cleanly.
- After posting, open the resulting **Posted Purchase Invoice/Cr. Memo** and, when the order is archived,
  the **Purchase Line Archive** entry → confirm the GBE fields carried through on the **new** records.
- Exercise other migrated areas with new data where relevant (e.g. set `GBE Type` on a **new Item/Location**,
  use a migrated **Egg Weight Class** code) → confirm no errors now that the legacy system is uninstalled.
- Review the **server event log / telemetry** for errors during these actions.

> Do this in a **non-production company or a restored copy** if you don’t want test documents in production.

### 4.5 Sign-off checklist

- [ ] **GlobalEgg Core** installed and healthy in every company.
- [ ] **GlobalEgg Migration** uninstalled (expected — it depends on the legacy system and is removed with it in Stage 3).
- [ ] Wizard reported **Migration Complete** (no error panel) for every company.
- [ ] Stage-2B SQL run once per database; review counts looked correct.
- [ ] Spot-checks (4.2) pass for Items, Locations, Egg Weight Class, Purchase docs, Machine Centers.
- [ ] Archive validation query (4.3) returns **0 MissedRows**; aggregate sums match.
- [ ] Functional smoke test **with new data** (4.4) passes — new purchase doc posts and GBE fields calculate without the legacy system.
- [ ] Legacy extensions uninstalled (Stage 3).
- [ ] Backup retained until business sign-off.

✅ When every box is checked, the migration is complete.

---

## Rollback

If Stage 2 or 4 fails badly:

1. **Stop** further company migrations.
2. Restore the **pre-Stage-2 database backup** (cleanest rollback — undoes wizard + SQL writes).
3. If a backup restore isn’t acceptable, note that:
   - Wizard value conversions are **idempotent** and safe to re-run after a fix.
   - The Stage-2B SQL is a plain field copy and can be re-run; wrap it in `BEGIN TRAN … ROLLBACK` to test first.
4. Re-validate (Stage 4) before resuming.

---

## Appendix — Field mapping reference

The wizard is driven by `FieldMapping.csv` and its value conversions (legacy source → GBE destination):

| Table (ID)                                          | Legacy source → GBE destination                                                                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Egg Weight Class Def Line (11050137)                | `Code` → `GBE_EggWeightClass.Code` / `.Description` (`EXLG→XL`, `LGE→LG`)                                                                  |
| Location (14)                                       | `LEGACY_Type` → `GBE_Type`                                                                                                                 |
| Item (27)                                           | `LEGACY_Type`, `LEGACY_HousingTypeCode`, `LEGACY_EggColorCode`, `LEGACY_EggWeightClassCode`, `LEGACY_QuantityEggs`, `LEGACY_PriceUnitCode` → GBE equivalents |
| Purchase Line (39)                                  | `LEGACY_ItemType` / `LEGACY_*PriceUnit*` → `GBE_Type` / GBE price-unit fields                                                              |
| Purch. Inv. Line (123) / Purch. Cr. Memo Line (125) | Legacy price-unit fields → GBE price-unit fields                                                                                           |
| **Purchase Line Archive (5110)**                    | All GBE fields via **Stage-2B SQL only** (not in the wizard mapping)                                                                       |
| Warehouse Receipt Header (7316)                     | `LEGACY_ShippingAgentCode` → `GBE_ShippingAgentCode`                                                                                       |
| Item Unit of Measure (5404)                         | `LEGACY_QtyEggsPerUnitOfMeasure` → `GBE_QtyEggsPerUnitOfMeasure`                                                                           |
| Machine Center (99000758)                           | `LEGACY_MachineType`, `LEGACY_GraderType` → GBE equivalents                                                                                |
