/* =====================================================================
   Purchase Line Archive — data migration (run ONCE per database)
   =====================================================================
   Copies the legacy source fields into the GlobalEgg Core (GBE) fields on
   the Purchase Line Archive companion table. The wizard does NOT migrate
   this table because it can hold 13M+ rows per company; a single set-based
   UPDATE is used instead.

   BEFORE RUNNING — substitute the placeholders for your environment:
     <DATABASE>          SQL database name
     <NN Company Name>   physical company prefix (00 ..., 01 ...)
     <EXT_TABLE_APP_ID>  app id that owns the Purchase Line Archive $ext table
     <GBE_CORE_APP_ID>   GlobalEgg Core app id
     <LEGACY_APP_ID>     legacy system app id (the source fields' publisher)
     LEGACY_             the legacy system's source-field prefix

   List the physical table names (one per company) to confirm coverage:

     SELECT name
     FROM   [<DATABASE>].sys.tables
     WHERE  name LIKE '%Purchase Line Archive%$ext'
     ORDER BY name;

   Add one UPDATE block per company returned by that query.
   Take a full database backup first — this writes data and is not auto-undoable.
   ===================================================================== */

UPDATE [<DATABASE>].[dbo].[<NN Company Name>$Purchase Line Archive$<EXT_TABLE_APP_ID>$ext]
SET [GBE_Type$<GBE_CORE_APP_ID>]                   = [LEGACY_ItemType$<LEGACY_APP_ID>],
    [GBE_PriceUnitOfMeasureCode$<GBE_CORE_APP_ID>] = [LEGACY_PriceUnitOfMeasureCode$<LEGACY_APP_ID>],
    [GBE_QuantityPerPriceUnit$<GBE_CORE_APP_ID>]   = [LEGACY_QuantityPerPriceUnit$<LEGACY_APP_ID>],
    [GBE_PricePerPriceUnit$<GBE_CORE_APP_ID>]      = [LEGACY_PricePerPriceUnit$<LEGACY_APP_ID>],
    [GBE_PriceUnitOfMeasure$<GBE_CORE_APP_ID>]     = [LEGACY_PriceUnitOfMeasure$<LEGACY_APP_ID>];

-- Repeat the UPDATE block above for every company in this database.
