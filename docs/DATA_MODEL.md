# Gestionnaire de Variantes — Model de dades

Actualització: 2026-11-05. Acords fins a D404 de [DECISIONS.md](DECISIONS.md). D404 permet substitució completa amb discrepància de línia coneguda, retirades/rebutjos individuals expressos i D392 intacte. §6.45 consolida25signatures sense categoria i formes revisades, inclosos vuit procediments SKU–valor sense canvi de signatura. Diccionari/ER **13 taules/90 camps**, mateixos76noms/funció;29signatures adaptades respecte D379 (quatre D398+25ara), altres formes E02 pendents. D395–D403 preservats. Etapa0 oberta (§7), documentació només, sense SQL/DDL/app/dades/font/configuració o avanç d'etapa.

## 1. Estat i lectura del document

Aquest document acompanya el [funcional Parkod](Parkod.md) i el [registre de decisions](DECISIONS.md). Recull el diagrama, els camps, les relacions i els arguments tractats amb l'usuari.

**No és DDL executable ni una estructura desplegada.** El document distingeix camps/claus de disseny aprovats, regles confirmades i controls SQL/proves pendents. L'etapa 0 continua oberta.

- **Ubicació:** VARIANTS_PARKOD.dbo, SQL Server 2017 Express/Windows Server 2019. Tretze taules/90 camps després de D380–D394; original parkod només amb lectures controlades (§1.1/§5).
- **Grup i pertinença — D380:** PK `(BrandCode, ProductGroupId)`, INT positiu numerat des d'1 per marca amb comptador/coordinació SQL. Cada SKU té un únic grup de la mateixa marca, però categories i línies poden diferir entre membres. CategoryCode i LineCode es retiren de ProductGroup; es conserven al SKU. No pertinences alternatives per client o agrupació automàtica per coincidència d'atributs.
- **Marca i unicitat confirmades:** VariantType incorpora BrandCode nullable per a qualsevol Type, estructurat o `open_type`. NULL significa global; una marca informada limita l'ús als seus grups. Type + Characteristics és únic globalment, sense incloure BrandCode. El canvi ordinari de BrandCode es bloqueja si hi ha assignacions, incloses les dels SKU retirats.
- **Representació confirmada (D156–D159/D170):** els tipus estructurats poden ser numèrics o textuals. VariantType.ValueKind NVARCHAR(7) NOT NULL declara `numeric` o `text`, homogeni per VariantTypeId; `open_type` exigeix `text`. Cada VariantTypeValue informa exactament un dels camps NumericValue/TextValue. No es replica ValueKind al valor ni s'afegeix a la unicitat. El canvi ordinari queda bloquejat amb qualsevol valor de catàleg o associació aprovada, també de fase 2 sense codi.
- **Principal confirmat:** ProductGroup incorpora PrimaryVariantTypeId, comú per a qualsevol ús. Només compten les associacions ProductGroupVariantType amb IsValidated=1 i ParkodVariantCode no nul: 0 → NULL, 1 → aquell tipus, més d'1 → selecció tècnica. No es compten SKU ni valors.
- **Associacions/rèpliques — D380:** PK ProductGroupVariantType `(ProductGroupId, BrandCode, VariantTypeId)`; ProductVariantValue conserva PK `(ProductVariantId, VariantTypeId)` i rèpliques BrandCode/ProductGroupId, però retira CategoryCode. VariantTypeValue.Type i els altres controls compartits es conserven. FK i cascades adaptades a §4.
- **Textos confirmats:** normalització automàtica dels blancs de TextValue, Characteristics, ProductGroupName i Type abans de validar i desar: qualsevol seqüència de blancs, incloent tabulacions, salts de línia i espais especials, es converteix en un únic espai ordinari U+0020, amb trim als extrems. S'admeten i es conserven accents i majúscules; la comparació és CI_AI. TextValue no nul és únic dins del seu VariantTypeId, però pot repetir-se entre tipus diferents. La collation s'ha de declarar als camps nous afectats, sense alterar la configuració general de parkod ni les columnes legacy.
- **Textos/codis:** NVARCHAR i sufix Code conservats. El grup hereta només marca del creador; categoria/línia del creador encara poden contribuir al nom descriptiu segons fórmula existent, sense convertir-se en atributs comuns. CCATEG/CategoryCode de SKU són dos dígits ASCII, amb zeros i tipus textual preservats (D388); cap alteració legacy.
- **Confirmat posteriorment:** IDs de catàleg INT IDENTITY(1,1), comptador local ProductGroupCounter, longituds de text i collation concretades, funció de blancs i CHECK binari/longitud, `SourceIsPresent`, nom inicial i escriptura protegida amb `sp_getapplock`. Les FK compostes i claus candidates indicades a la secció 4 han rebut confirmació de disseny; el DDL i les proves encara no existeixen.
- **Codi — D381–D383/D387:** ParkodVariantCode NVARCHAR(5) NULL, ASCII 0–9/A–N/P–Z, immutable i únic per marca incloent l'històric. DE000…ZZZZZ, sense retorn a 00000, màxim ordenat del registre i assignació SQL atòmica. Blocs retirats. Codi al final de fase 3, principal coherent; fase 2 admet 1/NULL. Identificador extern BrandCode(3)+codi(5), no substitució del SKU.
- **Taules tècniques:** ProductGroupCounter per marca, ParkodVariantCodeRegistry, EvaluationAuditEvent, AppAccount, AppSession amb reserva marca–grup i SynchronizationStatus cinc camps. Sense taules de versions/tasques o substitut de blocs.
- **Operativa:** conciliació completa/per marques, càrrega externa sempre completa D379, generador independent amb SNAPSHOT local. D389 retira només el rebuig CPROD d'antics blocs i el correu urgent corresponent; la resta de controls/logs intactes.
- **JSON i revisió confirmats (D143–D155/D159–D169):** contractes de fonts, propostes, resultats, claus i snapshots a §3.11; autoritat dels originals i context esperat per operació a §6.8. SQL compara l'estat revisat, no les correccions del formulari. La creació conjunta de grup/associacions/trasllats conserva valors i exigeix decisions explícites (§6.9).
- **Catàlegs i substitució confirmats (D171–D193):** claus d'auditoria sense context anterior a §3.11.3; reutilització/altes automàtiques i manuals a §6.10; substitució expressa A → B, retirades individuals auditades, JSON transitoris, dos procediments, SNAPSHOT de context, resposta post-COMMIT i resultat incert a §6.11. No noves taules ni columnes.
- **Desplegament/autenticació confirmats (D194–D200):** RDS/RemoteApp amb compte Windows propi i instància d'app per usuari, compte funcional propi, connexió directa i model intern de confiança; Argon2id en Python, token de 32 bytes i dos procediments de login a §6.13. No servei central ni autenticació Windows automàtica. SQL conserva els controls compartits; dependències comentades en anglès i inventariades a §6.12.
- **Catàleg manual i editorial confirmat (D201–D217):** finestra permanent de conjunt, preparació independent de tipus globals/valors, altes i auditories atòmiques, confirmació humana editorial, contextos SNAPSHOT reduïts, bloqueig per tipus, signatures/respostes i reversió editorial a §6.14. No noves columnes ni extensió de l'alta independent a tipus exclusius.
- **Fonts i entorn confirmats (D223–D232):** `parkod` local poblada i `VARIANTS_PARKOD` existent sense taules a `.\SQLEXPRESS`, SQL Server 2019 Express de proves. Producció continua en 2017 Express; l'usuari confirma l'estructura font com a referència i French_CI_AS a totes les columnes textuals de producció. Inventari/equivalències a §5, diagnòstics previs de lectura a §5.5. DESIGN1/DESIGN2 passen a NVARCHAR(18), code1 a NVARCHAR(13) NOT NULL; només s'ajusten aquests detalls físics, sense taules ni camps nous.
- **Precisió recent dels contractes (D233–D240):** tasques Windows en seqüència recàrrega → conciliació nocturna, ja acordades (§6.7); signatures completes A → B validades (§6.11.2); recuperació manual de resultats incerts només per administradors (§6.11.6), no comprovació automàtica. Entrada existent/nova de valor SKU i resposta de candidata en dos conjunts aprovades (§6.10.1–6.10.2), amb gramàtica D236 de ValuesJson reutilitzada expressament a NewValueJson. No canvia code1 ni originals històrics.
- **Candidates existents (D241–D248):** sis signatures i contractes de candidates a §6.15, preservats; quatre blocs grup–tipus D246 i set propietats SKU–valor D248 íntegrament confirmats. D243 només confirmava Parkod, no s'amplia retroactivament. Els altres circuits es concreten expressament a §6.16–6.24, no per extrapolació.
- **Contractes addicionals (D249–D284):** vint signatures de disseny per consulta administrativa, finalització, trasllats, creació/rebutjos, alta manual de tipus, principal i valors SKU. Absència/candidata/validada tenen circuits diferenciats; nous valors de catàleg només en confirmar, amb atomicitat/auditoria. Cap nova entitat/camp/PK/FK ni SQL desplegat; etapa 0 oberta.
- **Rebutjos conjunts i correccions de fase 2 (D285–D294):** quatre signatures addicionals a §6.25–6.26 i el lector GetGroupVariantTypeProposalCorrectionContext ara confirmat expressament per D294. D293 n'aprovava només el context, no s'amplia retroactivament. Cap assignació SKU s'elimina per fer admissible una candidata.
- **Substitució d'associació ja aprovada de fase 2 (D295–D296):** confirmador i lector de §6.27 per A 1/codi NULL i B candidata 0/codi NULL, totes dues sense assignacions al grup. Retirada expressa d'A/aprovació de B atòmiques, sense fase 3. Contractes preservats, amb l'adaptació d'activitat de grup D326–D330.
- **Sessions, comptes i abast de catàlegs (D297–D320):** cicle de sessió/reserva i tancament administratiu auditat, comptes/bootstrap/recuperació, BrandCode/ValueKind, signatura de NormalizeWhitespace i edició descriptiva del nom a §6.28–6.32. AppAccount.IsActive i ProductGroup.IsActive són independents. Cap servei central, compte de reserva o recuperació nova del tancament forçat.
- **Activitat:** IsActive/default1, controls d'inactius i zero SKU/cap reserva per desactivar intactes. D386 retira marca–categoria dels selectors administratius de buits/inactius: marca o totalitat. Grup actual de set camps; història de grups antics de nou camps intacta (§6.42).
- **Validació sense trasllat (D331–D337):** dos lectors i dos confirmadors per validar grup existent o pertinença actual, decisions independents; grup actiu buit, grup provisional i SKU retirat segons cada contracte (§6.36–6.37). Risc conservat, no-op només després de tots els controls.
- **Correcció de línia — D395:** reutilitzar lector/confirmador amb destí existent també per al grup actual; set blocs, SourceGroup/DestinationGroup complets amb mateix contingut si coincideixen. Signatures actuals sense categoria, tres conjunts post-COMMIT, auditoria només de files canviades (§6.38). Mateix grup: pertinença1/risc conservat/assignacions intactes D384–D385; trasllat risc nouNULL. No còpia escrita/relectura original/codi nou. E03 concretat en disseny, no SQL provat.
- **Càrrega externa versus conciliació (D361–D367, actualitzat D379):** només el procés extern carrega `parkod.dbo.PARKOD` → `VARIANTS_PARKOD.dbo.Parkod`, ara **sempre completament**, conserva històric i manté SourceIsPresent. Selecció de marques només per conciliar ProductVariant/grups, no per carregar la còpia o recuperar-ne una fallada. Nou camps de només lectura per a l'app; CLIGNE carregada versus LineCode classificat. GUI possible durant càrrega, conciliació sense sessions/entrada estable; contracte extern a §6.35 i Parkod.md §23.
- **Cicle batch i balanç (D348–D359, actualitzat D371–D373):** abast complet/multimarques i manual/scheduled, Begin/Complete/Fail i SESSION_CONTEXT petit, sense HASH d'abast o RunId. Cada SKU de còpia dins de l'abast té variant o incidència d'admissió individual d'aquella execució. SQL contrasta exactament els SKU sense variant amb UnincorporatedSkuIncidentsJson obligatori de CompleteReconciliation (§6.39.4/§6.39.6–6.39.7). COMMIT per operació, sense escriure còpia ni rollback global; dades/causes/completesa no demostrades només per sumes o pel text Reason.
- **Visibilitat i correcció de valors (D368–D370/D374–D378):** llista a cada login, incidències i quatre àmbits independents. Inclou assignacions candidates, valors no assignats i associacions aprovades sense codi com a finalització diferenciada. Retirats: validacions existents admissibles sí, assignacions absents no. Consulta a còpia durant càrrega o després de fallada: avís de llista no disponible fins a publicació correcta, no llista buida/completa fictícia o veto global de GUI. D369/no camp de pendent intactes (§6.41); consulta/resposta/GUI/SQL encara per materialitzar.
- **Matriu de línia — D390–D394/D398–D401/D404:** casos anteriors conservats; D404 afegeix substitució completa de §6.11 amb retirades/rebutjos expressos d'A, sense resoldre incidència o modificar pertinença. D390 abans de pertinença ordinària i D392 abans de codi NOU dels requerits intactes. No permissió universal de retirades/no-op (§6.42.3/§6.45.1).
- **Disponibilitat — D396/D402:** dependència real de còpia i indicador0 impedeixen context revisable/confirmació/rebuig formal; error SQL identificable pel backend sense comparar missatges, no signatures/respostes d'èxit noves. Sense dependència real no nou veto, buit només amb context complet verificable. GUI francesa/logs anglesos, D238 independent; numeració/transport detallat/proves pendents (§6.44.2).
- **Coordinació de còpia — D403:** carregador obligat a sp_getapplock exclusiu sobre el recurs existent, abans de marcar inici/modificar i fins a publicar resultat; revisions dependents compartit només durant lectura o confirmació/rebuig SQL curt. No TABLOCK, inspecció de taula bloquejada o locks de formulari. Indicador necessari després de fallada, cooperació externa imprescindible; noms/esperes/permisos/seqüència executable/proves pendents (§6.44.3, funcional §23.6).
- **Interfície:** mateixos76noms/funció separada. D380/D386:29signatures sense categoria, quatre de destí D398+altres25ara; altres arguments/tipus/ordre/defaults intactes. Vuit SKU–valor sense canvi de signatura, set blocs adaptats/grup3/associació5, no files completes substitutives. E02 restant sobre altres formes, no totes revisades (§6.45/§7).
- **Pendent:** completar evidència de metadades/permisos i impacte, controls executables JSON, detalls SQL de procediments/bloquejos, índexs/CHECK/FK, integracions i proves de les regles confirmades. Els casos no concretats es distingeixen a §7; no es consideren tots els procediments ni tots els formats possibles tancats. La FK SKU/còpia de quatre camps continua retirada. No avançar a l'etapa 1 abans de validar l'etapa 0.

Els vuit camps copiats conserven noms, tipus i nul·litat font acceptats (D230–D231), amb French_CI_AS al destí segons la producció confirmada (D232); no hereten SQL_Latin1 de la còpia de proves. `docs/parkod.sql` és una referència antiga discrepant, no el contracte de còpia. Fonts a `parkod.dbo`, objectes del projecte a `VARIANTS_PARKOD.dbo`; totes dues bases locals ja identificades a la mateixa instància de proves. L'equivalència estructural de la còpia amb producció és confirmació de l'usuari, no verificació directa de producció. En aquest document, `dbo.<objecte del projecte>` és abreviatura dins de **VARIANTS_PARKOD**, mai autorització per crear-lo a parkod. Cap script SQL de referència modificat ni objecte del model desplegat.

### 1.1 Frontera permanent: cap intervenció a `parkod`

**D218–D222 substitueixen l'antiga ubicació de D01/D65; D361–D367 precisen el límit de càrrega.** El projecte no executa a `parkod` cap escriptura, DDL, manteniment, objecte, permís o canvi de configuració. Tampoc implementa la càrrega de la còpia local. Per a aquell flux l'únic origen és `parkod.dbo.PARKOD`, consumit pel procés extern; no hi ha CSV, base intermèdia o recàrrega prèvia de l'original obligatoris afegits pel projecte. Les lectures auxiliars controlades ja autoritzades de §5 es conserven, sense ampliar-ne fonts ni permisos. Diagnòstics previs només de lectura, no autorització per executar scripts. Qualsevol necessitat d'alterar l'original exigeix redisseny.

Totes les escriptures, FK, procediments, comptes, sessions, bloquejos lògics, auditoria i SynchronizationStatus són a **VARIANTS_PARKOD.dbo**. Les FK inclouen la còpia local de PARKOD i no travessen bases. Fer servir dbo no implica concedir db_owner al compte de l'app. Els programes legacy continuen operant l'original fora del projecte; aquesta regla no posa la base sencera en READ_ONLY.

| Element | `parkod` original, observat i no modificable pel projecte | `VARIANTS_PARKOD`, configuració aprovada pendent d'aplicar/provar |
|---|---|---|
| Motor/instància | SQL Server 2017 Express 14.x, mateixa instància de destí | SQL Server 2017 Express, sense migració prevista |
| Compatibilitat | 100 | 140; permet OPENJSON, que exigeix almenys 130 |
| Collation general | French_CI_AS | French_CI_AS |
| ALLOW_SNAPSHOT_ISOLATION | OFF | ON, per transaccions explicitament SNAPSHOT |
| READ_COMMITTED_SNAPSHOT | No contrastat; cap canvi autoritzat | OFF |

L'usuari ha aportat resultats de consultes de metadades: versió 14.0.2110.2 i, a parkod, 80,25 MiB de dades assignats/41,44 MiB ocupats. Són una observació puntual, no una previsió de creixement ni una prova de rendiment. Express 2017 limita les dades a 10 GB per base; les dues bases comparteixen recursos del servidor. No es promet impacte nul de les lectures: controls d'abast, bloquejos ordinaris i càrrega s'han de provar sense NOLOCK ni bloqueig deliberat de taules senceres.

La collation Latin1_General_100_CI_AI_SC es manté als quatre textos nous acordats i la rèplica Type; LoginName conserva la seva unicitat CI_AI ja aprovada (§3.12). L'usuari confirma ara French_CI_AS general i a totes les columnes textuals de producció. Els vuit camps de còpia i els codis relacionats a VARIANTS_PARKOD es defineixen amb French_CI_AS (D232). La coincidència s'ha de garantir a cada costat de les FK textuals, encara amb codis ASCII. Les comparacions amb la font local SQL_Latin1 poden requerir COLLATE explícit, sense modificar-la; copiar NVARCHAR no normalitza ni canvia la grafia.

**Separació de proves i producció (D229):** la taula anterior és el destí aprovat i l'observació històrica de producció, no la configuració local actual. A `.\SQLEXPRESS`/2019 les dues bases s'han observat a compatibilitat 150, SQL_Latin1_General_CP1_CI_AS, SNAPSHOT OFF i RCSI OFF; VARIANTS_PARKOD existeix sense taules (§5.5). Cap canvi d'opcions executat. El disseny i el futur T-SQL continuen limitats a SQL Server 2017; proves en 2019 no acrediten per si soles compatibilitat/rendiment en 2017.

**Integracions encara pendents:** SNAPSHOT només a VARIANTS_PARKOD. La conciliació i les correccions de línia consumeixen la còpia local; les relectures originals de CLIGNE de l'antic disseny queden substituïdes per revalidació local. Noms/EAN/fonts auxiliars i generador conserven els seus protocols de lectura autoritzada pendents, sense SNAPSHOT a l'original ni coherència conjunta presumpta. La integració amb el carregador extern s'acota al contracte de disponibilitat/coordinació de §6.35/§6.7; no implica implementar-lo, copiar mestres o afegir permisos entre bases.

**Correspondència de codis (sense reanomenar la còpia):** `CMARQ → BrandCode`, `CCATEG → CategoryCode`, `CPROD → ProductCode`; CLIGNE inicialitza LineCode en alta/correcció confirmada, però la càrrega externa no el sobreescriu a ProductVariant. CLIGNE/LineCode poden diferir fins a revisió. A la còpia de proves, noms de marca/línia a `PARKOD.NOM_MARQUE`/`NOM_LIGNE`, categoria a `CATEGORY.CategoryName` i família a `FAMILY.FamilyName` segons §5.3; aquestes consultes auxiliars no són etapes de càrrega ni noves columnes/FK.

## 2. Diagrama entitat–relació

Totes les entitats del diagrama són a **VARIANTS_PARKOD.dbo**, inclosa Parkod, que és la còpia, no la font original. `PK` identifica una clau primària i `FK` una clau forana; diverses columnes marcades poden formar una sola clau composta. Es representen acords de disseny, no DDL validat ni desplegat.

**Abast vigent:** 13 taules/90 camps. Derivació de D380/D383: retirar cinc camps indicats, CategoryCode del comptador i ReservedCategoryCode de sessió, i la taula de blocs amb dos camps (14/99 → 13/90). Cap camp afegit; D381 amplia dues columnes de codi a5. Les dues retirades de camps tècnics són adaptació directa de la identitat marca–grup, no nous conceptes o decisions duplicades. Model de disseny, no DDL. Comparar amb inventari de camps i dependències a §6.42.1.

```mermaid
erDiagram
    Parkod ||--o| ProductVariant : "identifica el SKU"
    ProductGroup ||--o{ ProductVariant : "mateixa marca; categories i linies lliures"
    ProductGroup ||--o{ ProductGroupVariantType : "utilitza"
    ProductGroupVariantType |o--o| ProductGroup : "es principal del mateix grup"
    VariantType ||--o{ ProductGroupVariantType : "pot compartir-se"
    VariantType ||--o{ VariantTypeValue : "defineix valors"
    ProductVariant ||--o{ ProductVariantValue : "te assignacions"
    VariantTypeValue ||--o{ ProductVariantValue : "es assignat"
    ProductGroupVariantType ||--o{ ProductVariantValue : "associacio revisada per preparar valors"
    ProductGroupCounter ||--o{ ProductGroup : "numera per marca via procediment"
    ProductGroup ||--o{ ParkodVariantCodeRegistry : "conserva reserves del grup"
    VariantType ||--o{ ParkodVariantCodeRegistry : "conserva reserves del tipus"
    ParkodVariantCodeRegistry |o--o| ProductGroupVariantType : "reserva el codi final"
    AppAccount ||--o| AppSession : "una sessio activa"
    AppAccount |o--o{ EvaluationAuditEvent : "autor huma opcional"
    ProductGroup |o--o| AppSession : "reserva opcional exclusiva"

    Parkod {
        nvarchar CMARQ PK "3 caracters"
        nvarchar CCATEG PK "2 digits ASCII; zeros preservats"
        nvarchar CPROD PK "3 caracters"
        nvarchar CLIGNE "2 caracters; NOT NULL"
        nvarchar DESIGN1 "18 caracters; NOT NULL"
        nvarchar DESIGN2 "18 caracters; NULL"
        nvarchar code1 "13 caracters; NOT NULL; quantitat original"
        nvarchar code2 "1 caracter; NULL; unitat original"
        bit SourceIsPresent "NOT NULL; DEFAULT 1"
    }

    ProductGroup {
        int ProductGroupId PK, FK "positiu; des d 1 per marca"
        nvarchar ProductGroupName "150; nullable; blancs normalitzats; CI_AI"
        nvarchar BrandCode PK, FK "CMARQ; 3 caracters; NOT NULL"
        int PrimaryVariantTypeId FK "NULL amb 0 habilitacions finals"
        decimal EstimatedRiskPercent "DECIMAL(5,2); NULL si no estimable"
        bit IsValidated "NOT NULL; DEFAULT 0"
        bit IsActive "NOT NULL; DEFAULT 1; inactiu nomes sense SKU ni reserva vigent"
    }

    ProductVariant {
        bigint ProductVariantId PK "IDENTITY(1,1)"
        int ProductGroupId FK "NOT NULL; grup de la mateixa marca"
        nvarchar BrandCode FK "CMARQ; 3 caracters; NOT NULL"
        nvarchar CategoryCode FK "CCATEG; 2 digits ASCII; NOT NULL"
        nvarchar ProductCode FK "CPROD; 3 caracters; NOT NULL"
        nvarchar LineCode "classificacio del SKU; 2; NOT NULL; CLIGNE en alta/correccio"
        decimal EstimatedRiskPercent "DECIMAL(5,2); risc de pertinenca; nullable"
        bit IsValidated "NOT NULL; DEFAULT 0; pertinenca"
    }

    VariantType {
        int VariantTypeId PK "IDENTITY(1,1); U2 amb Type"
        nvarchar Type "20; NOT NULL; CI_AI; U1 amb Characteristics; U2 amb VariantTypeId"
        nvarchar Characteristics "80; NOT NULL; CI_AI; U1 amb Type"
        nvarchar BrandCode "nullable; NULL global"
        nvarchar ValueKind "7; NOT NULL; numeric o text; no replicat"
    }

    VariantTypeValue {
        int VariantTypeValueId PK "IDENTITY(1,1)"
        int VariantTypeId FK
        nvarchar Type FK "20; NOT NULL; CI_AI; replica conservada"
        decimal NumericValue "DECIMAL(18,3); nullable"
        nvarchar TextValue "80; CI_AI; nullable; unic per tipus si no NULL"
    }

    ProductGroupVariantType {
        int ProductGroupId PK, FK
        nvarchar BrandCode PK, FK "3 caracters; NOT NULL; marca del grup"
        int VariantTypeId PK, FK
        nvarchar ParkodVariantCode FK "5; nullable; assignat al final de fase 3"
        decimal EstimatedRiskPercent "DECIMAL(5,2); nullable"
        bit IsValidated "NOT NULL; DEFAULT 0; aprovacio de fase 2"
        nvarchar OriginalSourcesJson "MAX; nullable"
        nvarchar OriginalProposalJson "MAX; nullable"
    }

    ProductVariantValue {
        bigint ProductVariantId PK, FK
        int VariantTypeId PK, FK
        int ProductGroupId FK "NOT NULL; replica conservada; FK proposada"
        nvarchar BrandCode FK "3 caracters; NOT NULL; replica del grup real"
        int VariantTypeValueId FK
        decimal EstimatedRiskPercent "DECIMAL(5,2); nullable"
        bit IsValidated "NOT NULL; DEFAULT 0"
        nvarchar OriginalSourcesJson "MAX; nullable"
        nvarchar OriginalProposalJson "MAX; nullable"
    }

    ProductGroupCounter {
        nvarchar BrandCode PK "3 caracters; NOT NULL"
        int LastAllocatedId "NOT NULL; inicial 0"
    }

    ParkodVariantCodeRegistry {
        nvarchar BrandCode PK, FK "3; NOT NULL"
        nvarchar ParkodVariantCode PK "5; NOT NULL; permanent; DE000 a ZZZZZ"
        int ProductGroupId FK "NOT NULL"
        int VariantTypeId FK "NOT NULL"
    }

    EvaluationAuditEvent {
        bigint EvaluationAuditEventId PK "IDENTITY(1,1)"
        uniqueidentifier OperationId "NOT NULL"
        datetime2 OccurredAtUtc "3; NOT NULL; SYSUTCDATETIME"
        nvarchar EventKind "32; NOT NULL"
        nvarchar ActionName "64; NOT NULL; controlat"
        nvarchar DecisionOutcome "16; nullable"
        nvarchar ActorKind "16; NOT NULL"
        int ActorAppAccountId FK "nullable"
        nvarchar ActorProcessName "128; nullable"
        nvarchar TargetScope "32; NOT NULL"
        nvarchar TargetKeyJson "MAX; NOT NULL"
        decimal OriginalEstimatedRiskPercent "DECIMAL(5,2); nullable"
        nvarchar OriginalSourcesJson "MAX; nullable"
        nvarchar OriginalProposalJson "MAX; nullable"
        nvarchar DecisionResultJson "MAX; nullable"
        nvarchar BeforeStateJson "MAX; nullable"
        nvarchar AfterStateJson "MAX; nullable"
    }

    AppAccount {
        int AppAccountId PK "IDENTITY(1,1)"
        nvarchar LoginName "80; NOT NULL; unic CI_AI"
        nvarchar PasswordHash "255; NOT NULL; Argon2id"
        bit IsActive "NOT NULL; DEFAULT 0"
        bit IsAdmin "NOT NULL; DEFAULT 0"
    }

    AppSession {
        uniqueidentifier AppSessionId PK
        int AppAccountId FK "NOT NULL; UNIQUE"
        varbinary SessionTokenHash "32; NOT NULL; UNIQUE; SHA-256"
        datetime2 LastActivityAtUtc "3; NOT NULL; SYSUTCDATETIME"
        nvarchar ReservedBrandCode FK "3; nullable"
        int ReservedProductGroupId FK "nullable"
    }

    SynchronizationStatus {
        tinyint SynchronizationStatusId PK "unica fila; valor 1"
        datetime2 ParkodLastCompletedAtUtc "3; nullable"
        bit ParkodRefreshSucceeded "NOT NULL; DEFAULT 0"
        datetime2 VariantsLastCompletedAtUtc "3; nullable; nomes batch complet"
        bit VariantsReconciliationSucceeded "NOT NULL; DEFAULT 0; nomes batch complet"
    }
```

La correspondència Parkod–variant és 1:1 per als SKU vàlids incorporats. El `0..1` és també un estat normal d'entrada: la càrrega externa pot haver creat una còpia encara sense ProductVariant. L'alta de l'app crea variant, grup propi i auditories atòmicament, però no la còpia. D371–D373: cobertura final amb justificació individual des dels SKU sense variant i JSON d'incidències de Complete (§6.39.6–6.39.7), no igualtat inicial/final incondicional dels totals. Comptador: ús transaccional, no FK; cap relació física afegida.

**Claus de VariantType en el diagrama:** `PK (VariantTypeId)`; `U1 = UNIQUE (Type, Characteristics)` és la unicitat funcional global sobre text normalitzat amb `Latin1_General_100_CI_AI_SC`, sense BrandCode ni ValueKind; `U2 = UNIQUE (VariantTypeId, Type)` és una clau candidata tècnica per a la FK de `VariantTypeValue(VariantTypeId, Type)`. U1/U2 identifiquen **parelles** de columnes, no la unicitat individual de Type o Characteristics. Són acords de disseny, encara sense DDL desplegat.

PK vigents: ProductGroup `(BrandCode, ProductGroupId)`; ProductGroupVariantType `(ProductGroupId, BrandCode, VariantTypeId)`. ProductGroupId sol no identifica el grup. CategoryCode i LineCode són del SKU, no components de la referència al grup; no clau candidata de grup amb línia. Ordre físic d'índexs encara pendent.

La relació de principal és un subconjunt de les associacions habilitades: cada grup selecciona `0..1` associació i cada associació només pot ser principal del seu propi grup. El `0..1` del diagrama no implica opcionalitat general: amb un o més tipus habilitats, el principal és obligatori. La mateixa VariantType pot ser principal de molts grups a través d'associacions diferents; PrimaryVariantTypeId no és únic entre grups.

### Fonts de la còpia de proves, sense persistència local excepte vuit camps de PARKOD

```mermaid
flowchart LR
    P["parkod.dbo.PARKOD"] -->|"Copia controlada de vuit camps; lectura"| C["VARIANTS_PARKOD.dbo.Parkod"]
    P -->|"NOM_MARQUE NOM_LIGNE i preus; consulta sense copia"| Q["Consultes i classificacio"]
    K["parkod.dbo.CATEGORY"] -->|"IDCategory IDFamily i CategoryName; lectura puntual"| Q
    F["parkod.dbo.FAMILY"] -->|"IDFamily i FamilyName; lots en lectura puntual"| Q
    E["parkod.dbo.EAN"] -->|"IDParkod i EANNum; lectura puntual"| Q
    C --> Q
```

Aquests accessos són només de lectura, sense FK, vista ni cap altre objecte nou a l'origen. BRAND/LINE es conserven a la còpia de proves, però no són dependències necessàries per als noms de marca/línia. L'inventari canònic i la separació respecte de producció són a §5; cal verificar els permisos de lectura ja disponibles i l'impacte, sense concedir permisos ni configurar parkod des del projecte.

## 3. Diccionari de taules i camps

### 3.1 `dbo.Parkod`

**Finalitat:** còpia de treball a `VARIANTS_PARKOD.dbo.Parkod` de `parkod.dbo.PARKOD`, amb clau única, que permet ancorar les FK internes sense afectar les aplicacions antigues.

| Camp | Tipus de referència | Nul·litat | Funció i argument |
|---|---|---|---|
| `CMARQ` | NVARCHAR(3) | No | Marca i primer component de la PK. Tres caràcters exactes. |
| `CCATEG` | NVARCHAR(2) | No | Categoria i segon component de la PK. Dos dígits ASCII 0–9 exactes (D388); zeros preservats, sense conversió numèrica. |
| `CPROD` | NVARCHAR(3) | No | Producte i tercer component de la PK. Tres caràcters exactes. |
| `CLIGNE` | NVARCHAR(2) | No | Últim codi de línia carregat externament; pot diferir de ProductVariant.LineCode pendent de revisió. |
| `DESIGN1` | NVARCHAR(18) | No | Denominació original del SKU; metadades acceptades D231. |
| `DESIGN2` | NVARCHAR(18) | Sí | Denominació complementària original; metadades acceptades D231. |
| `code1` | NVARCHAR(13) | No | Quantitat original com a text; mai truncar ni convertir en copiar. NOT NULL no implica quantitat vàlida. |
| `code2` | NVARCHAR(1) | Sí | Unitat original com a text; els NULL es rebutgen en processar. |
| `SourceIsPresent` | BIT NOT NULL DEFAULT(1), confirmat | No | Mantingut només pel procés extern: 1 present segons la càrrega, 0 absència contrastada globalment amb càrrega completa fiable (D379). No expressa antiguitat, qualitat o validació; l'app no el modifica. |

PK/FK SKU `(CMARQ, CCATEG, CPROD)` conservades; ni CLIGNE ni LineCode hi entren. Classificació preservada fins a revisió D363; alta/correcció amb CLIGNE local revisada. FK de grup només marca–grup D380. SKU textual 3+2+3, CMARQ/CPROD A–Z/0–9 i CCATEG dos dígits; tipus/dades originals intactes, sense control específic d'O nou sobre la font.

Còpia acumulativa de totes les referències admeses, antigues i actuals: no DELETE, buidatge/recreació o pèrdua de l'última fila per desaparició del flux. D379 exigeix lectura completa/fiable global del procés extern: no càrrega per marques ni absència inferida d'un incremental o fallada. La comprovació periòdica d'integritat de producció i la seva càrrega són externes; l'app no executa el control de duplicats originals ni modifica cap dels nou camps de còpia. `PRIX_ACHAT`, `PRIX_VENTE`, `DECCONT`, `LIBELLE_COURT`, `NUM_UPD`, `CSSCATEG`, noms i mestres no s'hi afegeixen. Fonts de noms auxiliars i metadades D231/D232 preservades. Canvis futurs de contracte es revisen amb avís d'impacte, sense truncament/adaptació silenciosa.

### 3.2 `dbo.ProductGroup`

**Finalitat:** identificar i anomenar el producte comercial que agrupa els SKU.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `ProductGroupId` | INT NOT NULL, positiu; part de la PK composta, confirmat | Identificador des d'1 dins de BrandCode; comptador/coordinació per marca, DDL pendent. |
| `ProductGroupName` | NVARCHAR(150) NULL COLLATE Latin1_General_100_CI_AI_SC | Nom comercial visible, no únic. Informat inicialment amb noms/codis i editable; blancs normalitzats, cap buit informat. |
| `BrandCode` | NVARCHAR(3) NOT NULL; part de la PK composta, confirmat | Identificador CMARQ de la marca, heretat del primer SKU; tots els membres comparteixen la marca. |
| `PrimaryVariantTypeId` | INT NULL | VariantType principal per a qualsevol ús, no un SKU ni un valor. Ha de correspondre a una associació del mateix grup a ProductGroupVariantType; FK composta confirmada conceptualment. |
| `EstimatedRiskPercent` | DECIMAL(5,2) NULL | Risc inicial/vigent de creació/configuració, 0–100; NULL si no estimable. |
| `IsValidated` | BIT NOT NULL DEFAULT(0) | Validació tècnica del grup, independent de les pertinences dels SKU. |
| `IsActive` | BIT NOT NULL DEFAULT(1), confirmat D321 | Activitat operativa del grup, independent de IsValidated/risc. Només administració pot passar 1 → 0 amb zero SKU assignats i cap reserva vigent; consulta històrica conservada. |

El nom visible de marca es consulta a `PARKOD.NOM_MARQUE` de la còpia de proves, no en una columna nova de marca ni en una còpia de BRAND. CMARQ continua sent el codi funcional de marca; `BRAND.IDBrand` n'és l'equivalent documental. La disponibilitat i coherència de les denominacions s'han de contrastar sense seleccionar noms arbitraris si hi ha anomalies (§5).

Els camps de risc/validació estan confirmats per D107. Un grup propi provisional comença IsValidated=0 i risc sustentat o NULL; la PK i el nom no autoritzen ús als clients. DDL/proves pendents.

PK D380: `(BrandCode, ProductGroupId)`. ProductGroupId positiu/INT, no global ni equivalent a CPROD. Set camps de grup: ProductGroupId, ProductGroupName, BrandCode, PrimaryVariantTypeId, EstimatedRiskPercent, IsValidated, IsActive. Categoria/línia retirades del grup; no substituïdes per una categoria/línia principal o del creador.

SKU sense grup comercial conegut: grup propi provisional de la mateixa marca, no grup genèric. ProductVariant conserva categoria i línia pròpies. Mateixa marca és la compatibilitat de classificació requerida, no prova d'equivalència comercial ni dispensa de permisos, activitat, habilitacions, valors o principal. Noms repetits i grups buits conservats. El nom inicial encara segueix la fórmula existent del SKU creador (§5.1), només descriptiva.

Els noms poden repetir-se, fins i tot dins d'una marca i categoria; la PK completa distingeix les identitats. La importació repetida no crea nous grups per al mateix SKU. Els grups buits es conserven per auditoria i reversibilitat.

Activitat D321–D330 conservada: nous grups actius, buit = zero ProductVariant de la identitat marca–grup, retirats/pendents inclosos. Desactivar no modifica risc/validació, exigeix zero SKU i cap reserva vigent, també pròpia, sense moure/esborrar SKU o expulsar sessions. D386: selectors administratius només marca/totalitat. No DELETE o reactivació aprovada; caducades no són reserves vigents.

Un grup inactiu no es mostra ni s'utilitza en cerques, selectors, propostes, destinacions, reserves o modificacions ordinàries, també si l'actor és administrador o aporta una clau coneguda. SQL ho comprova transaccionalment, inclosos els no-op. L'operativa filtra **IsActive=1**, no IsValidated=1 ni «té SKU»: un grup actiu buit segueix operatiu fins a desactivació expressa. Cap reactivació automàtica per conciliació ni contracte de reactivació aprovat. Administració consulta els inactius per les vies explícites de §6.33–6.34.

Es conserven principal, associacions, codis, identificadors i auditoria. Les associacions històriques continuen comptant per compatibilitat de marca i bloqueig de ValueKind; no s'ignoren FK ni es reciclen comptadors/codis. Desactivar redueix el soroll operatiu, no l'emmagatzematge; persisteixen fila/índexs/dependències dins del límit d'Express. No es manté una transacció o bloqueig SQL obert pel fet que un grup sigui buit/inactiu. Contractes de nom/desactivació a §6.32–6.33 i matriu d'impacte a §6.34.6.

Numeració des d'1 per BrandCode; no per categoria/línia ni IDENTITY global. Comptador existent adaptat a marca, sp_getapplock/coordinació transaccional amb creació, sense MAX+1 de grups. No reiniciar/reciclar en desactivar. DDL/proves pendents.

#### Compatibilitat i línia pròpia del SKU

Un únic grup actual de la mateixa marca. Categoria i línia diferents entre membres són admeses; NULL de LineCode a ProductVariant continua prohibit, no s'inventa línia. No FK de grup amb categoria/línia. FK de tres camps a còpia intacta. CLIGNE local diferent de LineCode propi implica incidència tècnica, no incompatibilitat estructural del grup; matriu de decisions D390–D394 a §6.42.3. No relectura original o còpia escrita.

#### Tipus principal del grup

El principal és una propietat comuna del grup, independent d'eCommerce, connectors o destinacions. Pot ser estructurat o `open_type`, global o exclusiu d'una marca, sempre que estigui habilitat al mateix grup i respecti BrandCode.

| Nombre de VariantType habilitats a ProductGroupVariantType | PrimaryVariantTypeId requerit |
|---|---|
| 0 | NULL; no hi ha cap tipus a seleccionar. |
| 1 | Obligatori i igual a l'únic VariantTypeId habilitat. No hi ha una tria alternativa. |
| Més d'1 | Obligatori; el personal tècnic selecciona un dels tipus habilitats. |

Només compten les associacions amb **IsValidated=1 i ParkodVariantCode IS NOT NULL**. Les candidates i les aprovades a fase 2 encara sense codi no alteren el principal. El recompte no és un recompte de SKU ni valors; la completesa dels valors es comprova abans de donar el codi final. Grups d'un sol SKU i grups buits conservats segueixen la mateixa regla segons les habilitacions que mantinguin.

El recompte és per VariantTypeId: Size/letter i Size/cms compten com dos tipus si tots dos estan finalment habilitats, encara que comparteixin el text Type=Size.

Si el principal obligatori falta o no és vàlid, es bloqueja l'exportació del grup i es rebutgen els canvis ordinaris que deixin un estat final invàlid. Es permeten les operacions correctives necessàries per definir-lo, amb revalidació atòmica en una transacció curta. Afegir o retirar tipus, canviar el principal o traslladar SKU requereix revalidar la regla. Amb més d'un tipus no s'escull arbitràriament el primer ni se substitueix silenciosament una decisió tècnica vàlida.

El principal no elimina altres tipus, valors o SKU, ni els fusiona. Un grup amb diversos SKU però sense tipus definits continua pendent de classificació: un principal NULL coherent amb zero tipus no autoritza l'exportació. Un principal vàlid tampoc garanteix, per si sol, que tots els SKU tinguin valor o que els valors diferenciïn tots els SKU en una destinació limitada a una sola característica; els controls específics d'exportació s'hauran de concretar al connector, sense alterar la classificació interna.

La columna admet NULL físicament per al cas de zero habilitacions finals, però és obligatòria quan n'hi ha una o més. Les associacions candidates o aprovades sense codi no imposen un principal. Un NOT NULL incondicional no serveix i la FK composta confirmada només comprova la pertinença al grup, no la validesa final, el recompte ni l'elecció tècnica. La materialització SQL i el control transaccional continuen pendents; no s'afegeixen camps d'estat o marques IsPrimary.

### 3.3 `dbo.ProductVariant`

**Finalitat:** donar a cada SKU una identitat independent del seu Parkod i relacionar-lo amb el grup actual.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `ProductVariantId` | BIGINT IDENTITY(1,1), PK confirmada | Codi propi de variant. La PK impedeix duplicats i SQL Server el genera per a múltiples usuaris. |
| `ProductGroupId` | INT NOT NULL; FK composta de disseny | Grup actual dins de BrandCode; no determina la identitat de la variant. |
| `BrandCode` | NVARCHAR(3) NOT NULL; FK composta proposada | Component CMARQ del SKU i de la referència al grup; ha de coincidir amb la marca del grup. |
| `CategoryCode` | NVARCHAR(2) NOT NULL; FK composta a còpia | Component CCATEG del SKU, dos dígits ASCII; no component de la referència al grup. |
| `ProductCode` | NVARCHAR(3) NOT NULL; FK composta proposada | Component CPROD del SKU, independent de ProductGroupId. |
| `LineCode` | NVARCHAR(2) NOT NULL, confirmat | Línia classificada pròpia del SKU, inicialitzada de CLIGNE local; preservada fins a correcció humana, independent del grup. |
| `EstimatedRiskPercent` | DECIMAL(5,2) NULL | Risc de la pertinença SKU→grup actual, rang 0–100. |
| `IsValidated` | BIT NOT NULL DEFAULT(0) | Decisió tècnica individual de pertinença. |

La combinació `(BrandCode, CategoryCode, ProductCode)` és única i referencia la PK de `VARIANTS_PARKOD.dbo.Parkod`. D363 conserva aquesta FK de tres camps, no afegeix `ParkodVariantLink` ni UNIQUE amb CLIGNE. La coherència variant–grup és permanent; la igualtat amb CLIGNE local correspon a l'alta/correcció expressa. Els controls ordinaris afectats per un desajust d'entrada requereixen el contrast transversal de §6.40.

Cada pertinença té els camps físics de D107, independents dels de ProductVariantValue. Una aprovació conjunta conserva una decisió per SKU. Una proposta automàtica de trasllat no canvia ProductGroupId abans de validar; el SKU nou manté grup propi provisional i el rebuig no el deixa orfe.

Referència al grup `(BrandCode, ProductGroupId)`, no ProductGroupId sol. Categoria és part de la identitat SKU; línia és classificació revisable pròpia. No cal fer-les coincidir amb el grup. Canvi de CLIGNE conserva SKU; canvi de CCATEG continua essent recodificació/nou SKU, no corrector de categoria.

La identitat es conserva en trasllats de grup o canvi només de CLIGNE. Una recodificació que canvia CPROD o CCATEG crea un ProductVariant nou i grup propi provisional, sense herència automàtica; l'antic es conserva i no es retira si encara és a l'origen. EAN/descripció no són ordres de recodificació. BIGINT supera les `36^8` combinacions teòriques de l'alfabet general; comença per 1, amb salts acceptats, sense reciclatge ni MAX+1.

### 3.4 `dbo.VariantType`

**Finalitat:** definir què varia i amb quina unitat o denominació comercial.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `VariantTypeId` | INT IDENTITY(1,1) NOT NULL, PK | Identificador de l'única definició d'una parella Type + Characteristics. |
| `Type` | NVARCHAR(20) NOT NULL COLLATE Latin1_General_100_CI_AI_SC | Naturalesa de la característica: `volume`, `weight`, `Size`, `%alcool` o `open_type`. Ja no determina tot sol la representació numèrica/textual. Parella única amb Characteristics. |
| `Characteristics` | NVARCHAR(80) NOT NULL COLLATE Latin1_General_100_CI_AI_SC | Unitat, escala o denominació comercial; `unitless` només per a magnituds adimensionals confirmades. |
| `BrandCode` | NVARCHAR(3) NULL, compatible amb CMARQ; camp i nul·litat confirmats | NULL: tipus global. CMARQ informat: exclusiu d'aquella marca. Independent de Type; no forma part de la unicitat i no té FK a cap mestre font. |
| `ValueKind` | NVARCHAR(7) NOT NULL, confirmat | `numeric` o `text`; representació única per a tots els valors del mateix VariantTypeId. `open_type` exigeix `text`. No forma part de cap nova clau ni es replica a VariantTypeValue. |

Exemples: `volume/ml` amb ValueKind=`numeric`, `weight/gr`, `weight/oz`, `Size/letter` amb ValueKind=`text`, `Size/cms` amb ValueKind=`numeric`, `open_type/color SpringViews` amb ValueKind=`text`. Els noms i unitats es conserven, sense conversió.

- `(Type, Characteristics)` és una clau única global per a tots els tipus, estructurats i `open_type`, després de normalitzar els blancs i amb comparació CI_AI. La restricció acordada és `UNIQUE (Type, Characteristics)`; BrandCode no s'hi inclou i VariantTypeId continua sent la PK.
- Una parella existeix en una sola fila de VariantType. No es permet una segona definició amb un altre ID, sigui amb el mateix BrandCode, amb una altra marca o amb NULL.
- BrandCode és opcional per a qualsevol Type. Type determina la naturalesa de la característica; ValueKind, la representació dels valors; BrandCode, l'abast d'ús.
- Amb BrandCode NULL, el tipus és global i es pot associar a grups de qualsevol marca. L'ús actual per una sola marca no el converteix en exclusiu.
- Amb BrandCode informat, el tipus només es pot associar a grups d'aquella marca. Això també és possible per als tipus estructurats.
- La mateixa definició es reutilitza mitjançant ProductGroupVariantType: `VariantType.BrandCode IS NULL` o `VariantType.BrandCode = ProductGroup.BrandCode`.
- TextValue té una unicitat pròpia a VariantTypeValue: no es pot repetir dins del mateix VariantTypeId després de normalitzar els blancs i segons CI_AI, però sí entre VariantTypeId diferents. Reutilitzar un valor en diversos SKU no crea files noves al catàleg.
- Les unitats no es converteixen; unitats diferents identifiquen tipus diferents. No s'ha de confondre ounce de pes amb fluid ounce de volum.
- Canviar una definició compartida pot afectar diversos grups: requereix control i auditoria, no una modificació silenciosa del significat.

La fila única de VariantType conté el seu abast de marca; no cal un registre addicional de propietat de configuracions. El camp BrandCode està aprovat, però la materialització SQL de la compatibilitat amb els grups i del bloqueig de canvis continua pendent.

#### Representació homogènia i canvis de ValueKind

L'homogeneïtat és per **VariantTypeId**, no pel text de Type sol ni per ProductGroup. Un grup pot associar-se a `Size/letter` (M, L, XL, XXL textuals) i `Size/cms` (33, 34, 35 numèrics) mitjançant dos VariantType diferents. Cada SKU pot tenir un valor de cadascun; no se'n dedueixen equivalències, ordre comercial ni conversions. Una etiqueta numèrica textual no es converteix automàticament a NumericValue.

La parella Type + Characteristics continua sent única globalment: ValueKind no permet duplicar la mateixa parella amb una altra representació, marca o ID. `open_type` continua exclusivament textual, però ja no és l'únic Type que pot utilitzar TextValue. No s'ha aprovat cap valor per defecte ni extensió de la collation CI_AI a ValueKind.

**Bloqueig ordinari confirmat (D158/D170):** rebutjar un canvi de ValueKind si existeix **qualsevol VariantTypeValue del tipus, encara no assignat a cap SKU, o qualsevol ProductGroupVariantType del tipus amb IsValidated=1**. N'hi ha prou amb una de les dues condicions. El control abasta tots els grups que comparteixen el tipus, inclosos els aprovats a fase 2 amb codi NULL i encara sense valors. No es desvaliden associacions ni s'eliminen dades per permetre el canvi. Sense aquests usos continuen exigits la resta de controls, l'auditoria i `open_type → text`; no es reescriuen els originals de candidates.

Comprovació i canvi han de ser atòmics respecte de la creació de valors i l'aprovació de fase 2, amb la coordinació per tipus prevista a §6.2. La materialització, les curses i els permisos s'han de provar. La via administrativa excepcional de BrandCode (D142) **no s'estén a ValueKind**.

#### Casos de marca i reutilització

| Cas | Permès? | Motiu |
|---|---|---|
| `volume/ml` estructurat amb BrandCode NULL utilitzat per grups ABC i XYZ. | Sí | La definició és global. |
| `weight/gr` estructurat amb BrandCode ABC associat a un grup XYZ. | No | L'abast exclusiu també s'aplica als estructurats. |
| `open_type/color SpringViews`, ID 101, amb BrandCode NULL, utilitzat per ABC i XYZ. | Sí | Un `open_type` també pot ser global. |
| `open_type/color SummerViews`, ID 205, amb BrandCode ABC, utilitzat per dos grups ABC. | Sí | Reutilització d'una mateixa definició dins del seu abast. |
| El tipus 205 associat a un grup XYZ. | No | El grup és incompatible amb BrandCode ABC. |
| Crear un altre ID amb `open_type/color SpringViews`, amb ABC, XYZ o NULL, existint el 101. | No | La definició global no es duplica ni es privatitza amb una altra fila. |
| Crear un altre ID amb `open_type/color SummerViews`, amb ABC, XYZ o NULL, existint el 205. | No | La parella tampoc es repeteix dins d'una mateixa marca. |
| Repetir l'associació del mateix tipus al mateix grup. | No | Ho impedeix la PK de ProductGroupVariantType. |

#### Canvis de BrandCode

Un canvi de BrandCode és un canvi major d'abast, independent del Type. La unicitat global evita duplicar la definició, però no bloqueja per si sola l'edició d'aquest camp.

| Situació | Canvi ordinari de BrandCode | Condició |
|---|---|---|
| Sense assignacions ni associacions a grups. | Permès | No hi ha usos que es puguin tornar incompatibles. |
| Sense assignacions, amb associacions a grups compatibles amb el nou abast. | Permès | Revalidar totes les associacions ProductGroupVariantType. |
| Sense assignacions, amb alguna associació incompatible. | Bloquejat | No eliminar ni alterar associacions silenciosament. |
| Amb alguna assignació a ProductVariantValue. | Bloquejat | El tipus ja s'utilitza en un SKU. |
| Amb assignacions només a SKU retirats conservats. | Bloquejat | Els usos preservats també compten. |

Per exemple, NULL → ABC sense assignacions es rebutja si el tipus està associat a un grup XYZ. La comprovació i el canvi són atòmics, en transacció curta, segurs davant assignacions/associacions concurrents.

**Via excepcional confirmada (D142):** un canvi de VariantType.BrandCode amb assignacions existents s'executa fora de la GUI mitjançant un procediment protegit accessible només a una identitat SQL d'administració autoritzada, mai al compte ordinari de variants. Requereix anàlisi d'impacte i autorització prèvies. Comprova que totes les associacions grup–tipus continuen compatibles; qualsevol incompatibilitat rebutja el canvi. No elimina associacions o valors ni modifica codis per forçar la compatibilitat. El canvi i l'auditoria abans/després es confirmen en una mateixa transacció curta. El bloqueig ordinari, inclosos usos retirats, continua vigent. La via està acordada; procediment SQL, permisos efectius i proves encara pendents.

### 3.5 `dbo.VariantTypeValue`

**Finalitat:** contenir els valors disponibles de cada tipus.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `VariantTypeValueId` | INT IDENTITY(1,1) NOT NULL, PK | Identificador del valor. |
| `VariantTypeId` | INT NOT NULL, FK | Definició a la qual pertany el valor. |
| `Type` | NVARCHAR(20) NOT NULL COLLATE Latin1_General_100_CI_AI_SC | Rèplica controlada del pare; no declara independentment la representació ni substitueix ValueKind. |
| `NumericValue` | DECIMAL(18,3), nullable | Valor exacte si ValueKind=`numeric`; únic dins del tipus quan no és NULL. |
| `TextValue` | NVARCHAR(80) NULL COLLATE Latin1_General_100_CI_AI_SC | Valor si ValueKind=`text`, estructurat o `open_type`; únic dins del tipus quan no és NULL. |

Regles:

- Es conserva Type i la FK composta proposada `(VariantTypeId, Type)`. No és una naturalesa independent editable. L'antiga deducció `Type <> open_type → numèric` queda substituïda: la rèplica no basta per garantir l'homogeneïtat respecte de ValueKind.
- Cada fila informa **exactament un** dels camps NumericValue/TextValue: rebutjar tots dos informats o tots dos NULL. Un CHECK local controla aquesta exclusió i la regla `open_type → text`; els procediments protegits comproven la correspondència amb VariantType.ValueKind sota coordinació per tipus. No s'aprova una rèplica ValueKind, FK nova ni trigger per aquest canvi.
- ValueKind=`numeric`: NumericValue obligatori i TextValue NULL. ValueKind=`text`: TextValue obligatori, normalitzat i no buit, i NumericValue NULL. La mateixa regla s'aplica a tots els valors del VariantTypeId.
- Unicitat de `(VariantTypeId, TextValue)` només quan `TextValue IS NOT NULL`, després de normalitzar els blancs i segons CI_AI. No poden existir dues files del mateix tipus amb textos equivalents en aquesta comparació. Els NULL dels valors numèrics queden fora d'aquesta unicitat.
- Unicitat de `(VariantTypeId, NumericValue)` per als valors numèrics presents.
- Rebuig, sense arrodoniment silenciós, de valors que requereixin més de tres decimals o surtin del rang. Els zeros decimals finals no requereixen més precisió: `50.0000` es pot representar exactament, però `50.0001` no. DECIMAL(18,3) admet quinze dígits enters i tres decimals.
- `50`, `50.0` i `50.000` representen el mateix número dins del mateix tipus. No cal conservar el format original d'aquest número.
- `weight/gr/50` i `weight/oz/50` són entrades independents: no hi ha conversió.
- A la pantalla es poden eliminar zeros decimals finals.
- Diversos SKU poden reutilitzar el mateix VariantTypeValueId a ProductVariantValue; això no duplica TextValue a VariantTypeValue ni modifica la identitat de les variants.

La unicitat global afecta VariantType `(Type, Characteristics)`; la de TextValue es limita al seu VariantTypeId. VariantTypeValue és el catàleg de valors, no una taula de variants SKU. Un valor només s'assigna a través del seu tipus, a grups compatibles amb el seu abast: qualsevol marca si BrandCode és NULL, o només la marca informada. El mateix text pot existir en tipus diferents, però no en dues files del mateix tipus.

Les edicions sobre la mateixa fila de `VariantType.Type`, `VariantType.Characteristics` i `VariantTypeValue.TextValue` només poden ser **editorials sense canvi de significat**. Normalitzar/comprovar unicitat, preservar validacions i avaluar usos compartits amb auditoria. Canvi semàntic del tipus: nova VariantType/associació/codi i revalidació dels valors SKU; canvi semàntic només del valor: nou VariantTypeValue del mateix tipus i reassignació/revalidació, mai reescriure sentit d'una fila compartida. Confirmació humana, contextos i procediments editorials/reversió ja acordats a §6.14; seqüència SQL i cascada editorial D101 encara per implementar/provar, inclosa propagació exacta amb CI_AI.

El número no evita duplicats per naturalesa: ho fa la restricció d'unicitat. S'utilitza DECIMAL, no FLOAT, perquè cal igualtat numèrica exacta.

### 3.6 `dbo.ProductGroupVariantType`

**Finalitat:** reutilitzar una mateixa definició en grups compatibles amb el seu abast, tant per als tipus estructurats com per als `open_type`.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `ProductGroupId` | INT NOT NULL; FK, part de la PK composta | Identificador local del grup que utilitza el tipus. |
| `BrandCode` | NVARCHAR(3) NOT NULL; FK, part de la PK composta | Marca del grup, no una definició independent de l'abast del tipus. |
| `VariantTypeId` | INT NOT NULL, FK, part de la PK composta | Definició utilitzada. |
| `ParkodVariantCode` | NVARCHAR(5) NULL | Codi immutable final de fase 3, únic per marca incloent històric; DE000…ZZZZZ sense retorn. No és PK. |
| `EstimatedRiskPercent` | DECIMAL(5,2) NULL | Risc de l'associació, 0–100; NULL si no estimable. |
| `IsValidated` | BIT NOT NULL DEFAULT(0) | Aprovació tècnica de fase 2; no és habilitació final sense codi. |
| `OriginalSourcesJson` | NVARCHAR(MAX) NULL | Evidències/fonts originals de la candidata i del risc; JSON vàlid si informat. |
| `OriginalProposalJson` | NVARCHAR(MAX) NULL | Proposta automàtica original abans de la correcció humana; JSON vàlid si informat. |

PK D380, amb l'ordre anterior conservat després de retirar categoria: `(ProductGroupId, BrandCode, VariantTypeId)`.

La unicitat global de `(Type, Characteristics)` a VariantType, juntament amb aquesta PK, ja impedeix repetir la mateixa configuració dins d'un grup. No cal una unicitat local filtrada per `open_type` per aconseguir-ho.

BrandCode/ProductGroupId identifiquen el grup; no l'abast del tipus. CategoryCode retirada, Type/Characteristics no replicats. No particionar la mateixa associació per les categories dels seus SKU.

FK `(BrandCode, ProductGroupId)` a ProductGroup. Compatibilitat VariantType.BrandCode NULL o igual a marca del grup conservada; comprovació condicional/protecció SQL pendents. D393 permet aprovar fase2 amb incidència de línia coneguda, sense valors/codi/principal o pertinences aprovats implícitament.

PrimaryVariantTypeId selecciona una d'aquestes associacions, no una definició aliena al grup. Retirar l'associació seleccionada requereix deixar un principal coherent amb les associacions resultants dins de la mateixa operació atòmica; no s'esborren assignacions silenciosament ni s'aplica una cascada per evitar el conflicte. La substitució completa de §6.11 permet retirar relacions SKU–valor només amb decisió explícita i auditoria individual, preservant catàlegs i historial.

L'associació grup–tipus de §3.6 pot passar pels estats següents:

| Estat | IsValidated | ParkodVariantCode | Compta per al principal i la lectura Parkod? |
|---|---|---|---|
| Candidata de fase 2 | 0 | NULL | No |
| Aprovada a fase 2, valors en preparació | 1 | NULL | No |
| Completa al final de fase 3 | 1 | Assignat | Sí, sense substituir els altres controls per SKU |

Les candidates automàtiques són files persistents visibles amb risc i evidències. En rebutjar una candidata no validada, sense codi ni ProductVariantValue, s'elimina només aquesta fila i s'audita en la mateixa transacció; grup i VariantType es conserven. Les dues columnes JSON preserven originals fins a decidir i es copien a auditoria, també en rebutjos. No són esborranys manuals. La retirada d'una associació habilitada segueix els controls de referències/principal i conserva la reserva permanent del codi.

Crear/reutilitzar el tipus abans de persistir la candidata segueix §6.10. Corregir VariantTypeId implica una associació diferent: els casos d'A/B candidata, aprovada o amb assignacions i les seves auditories estan concretats a §6.11, no són una edició silenciosa de la PK. Dos tipus complementaris poden conservar-se i aprovar-se tots dos.

### 3.7 `dbo.ProductVariantValue`

**Finalitat:** assignar un valor de tipus a un SKU sense afegir columnes per cada atribut.

| Camp | Tipus/estat | Funció i argument |
|---|---|---|
| `ProductVariantId` | FK, part de la PK composta | Variant que rep el valor. |
| `VariantTypeId` | Conservació confirmada; FK composta, part de la PK | Tot i ser derivable del valor, es manté per limitar una assignació per tipus i SKU; ha de coincidir amb el VariantTypeId del valor referenciat. |
| `ProductGroupId` | INT NOT NULL; rèplica tècnica conservada | Grup actual real de la variant, identificat amb BrandCode. |
| `BrandCode` | NVARCHAR(3) NOT NULL; rèplica confirmada | Marca del SKU i del grup real; component de les FK compostes de coherència i habilitació. |
| `VariantTypeValueId` | FK composta | Valor concret, que ha de pertànyer al tipus indicat. |
| `EstimatedRiskPercent` | DECIMAL(5,2) NULL | Risc propi de la proposta d'assignació per SKU, rang 0–100. |
| `IsValidated` | BIT NOT NULL DEFAULT(0) | Validació humana d'aquesta assignació individual. |
| `OriginalSourcesJson` | NVARCHAR(MAX) NULL | Fonts/evidències originals del valor i del risc, JSON vàlid si informat. |
| `OriginalProposalJson` | NVARCHAR(MAX) NULL | Assignació automàtica original abans de correcció humana, JSON vàlid si informat. |

PK: `(ProductVariantId, VariantTypeId)`.

Els quatre camps addicionals estan aprovats per D107/D137. La seva informació pertany a l'assignació SKU–tipus, no al catàleg compartit ni a l'associació grup–tipus. Els controls de forma, coherència i unicitat continuen obligatoris.

Les FK comproven grup real, associació existent i valor del mateix tipus. El procediment exigeix aprovació de fase 2 abans de crear candidates de valor, però permet codi encara NULL per preparar la fase 3. Exigir codi final abans de preparar valors crearia una dependència impossible; la lectura Parkod sí exigeix habilitació final. Una variant pot tenir valors de dues unitats perquè són VariantType diferents.

VariantTypeId/ProductGroupId/BrandCode conservats; CategoryCode retirada D380. PK `(ProductVariantId, VariantTypeId)` intacta, com a màxim un valor per tipus/SKU. Categoria del SKU es consulta a ProductVariant, no s'elimina de la seva identitat o de les evidències font.

FK adaptades `(ProductVariantId, ProductGroupId, BrandCode)` al grup real del SKU i `(ProductGroupId, BrandCode, VariantTypeId)` a l'associació. No segona pertinença independent; trasllat atòmic manté grup/marca reals i totes les assignacions. Mateix número de grup pot repetir-se entre marques, no dins d'una marca.

Rèpliques proporcionades coherentment i verificades a SQL. Dues cascades limitades conservades: ProductVariant → ProductVariantValue per grup/marca en trasllats, i VariantType(VariantTypeId, Type) → VariantTypeValue per Type editorial. No DELETE CASCADE o canvi semàntic; DDL/proves pendents. D394 permet confirmar candidata/primera alta manual amb incidència de línia coneguda, no corregir línia o validar pertinença per herència.

En rebutjar un valor pendent IsValidated=0, només s'elimina la fila ProductVariantValue d'aquell SKU/tipus. Primer es preserven proposta, fonts, risc i decisió a EvaluationAuditEvent, en la mateixa transacció que l'eliminació; si alguna operació falla, rollback complet. ProductVariant i VariantTypeValue es conserven. Un valor obligatori absent impedeix completar una associació nova i donar-li codi. Les correccions reassignen a un valor correcte existent o nou, sense canviar el significat d'una fila compartida; una assignació ja validada no es reemplaça abans de confirmació explícita.

La retirada funcional explícita dins d'una substitució completa de tipus (§6.11) també pot afectar una assignació validada o d'un SKU retirat, amb auditoria individual i catàleg conservat. No s'assimila automàticament a rejected ni autoritza esborrats per SourceIsPresent=0. El moment d'alta d'un valor nou automàtic/manual es defineix a §6.10.

### 3.8 Textos nous: normalització dels blancs, comparació i unicitat

- **Camps afectats:** VariantType.Type, VariantType.Characteristics, ProductGroup.ProductGroupName i VariantTypeValue.TextValue. La mateixa regla s'aplica a VariantTypeValue.Type, rèplica conservada del Type del pare.
- **Normalització automàtica confirmada:** abans de validar i enregistrar, es converteix qualsevol seqüència d'un o més caràcters blancs en un únic espai ordinari U+0020. Inclou espais ordinaris, tabulacions, salts de línia i espais especials Unicode, com els espais no separables. Un blanc especial aïllat també es converteix, no només les seqüències repetides.
- Després de la conversió es fa trim dels extrems. El text desat no conté blancs inicials/finals, dos blancs consecutius, tabulacions, salts de línia ni espais especials: qualsevol separació interior queda representada per un únic U+0020. Es conserva la separació entre paraules, no es concatenen en eliminar els blancs.
- L'ordre és normalitzar blancs i fer trim, validar el resultat —inclosa la unicitat segons CI_AI— i desar aquell mateix text normalitzat. S'aplica a les insercions i edicions, tant interactives com batch, sense rebutjar una entrada només perquè contenia blancs que es poden normalitzar. Si el resultat provoca un duplicat prohibit, es rebutja l'operació; no es fusionen files ni es canvien IDs automàticament.
- Els quatre camps admeten accents i majúscules, que no es modifiquen amb la normalització dels blancs. La collation CI_AI és insensible a majúscules/minúscules i accents en la comparació, no en l'emmagatzematge: `Écru` i `ECRU` es comparen com a iguals, però es conserva la grafia de les lletres desada.
- La collation explícita acordada és `Latin1_General_100_CI_AI_SC` en els cinc camps (comptant la rèplica Type); no s'estén a codis ni camps originals. VariantType.Type i VariantTypeValue.Type comparteixen collation.
- No es modifica la collation general de la base existent parkod, les columnes originals ni els camps legacy de la còpia PARKOD amb aquest acord. Les regles del SKU `A–Z` i `0–9` continuen exigint validació exacta; CI_AI no autoritza codis amb accents.
- ProductGroupName no adquireix cap restricció d'unicitat. La parella `(Type, Characteristics)` sí que és una clau única global i `(VariantTypeId, TextValue)` és única només per als textos no nuls.
- Aquestes garanties s'han de materialitzar també a SQL. S'ha autoritzat `dbo.NormalizeWhitespace` a VARIANTS_PARKOD (NULL roman NULL) per als camins oficials interactiu/batch abans de validar longitud, buit i unicitat; sense truncament previ. CHECKs SQL compararan bytes exactes **i longitud** amb el resultat normalitzat, no igualtat CI_AI. Unicitats filtrades `(VariantTypeId, TextValue) WHERE TextValue IS NOT NULL` i `(VariantTypeId, NumericValue) WHERE NumericValue IS NOT NULL`: materialització i proves pendents. Excloure els NULL numèrics evita impedir múltiples valors textuals; una collation no compacta blancs.

En els exemples següents, `\t` indica una tabulació, `\r\n` un salt de línia, `\u00A0` un espai no separable i `\u202F` un espai no separable estret; representen els caràcters reals, no les barres i lletres literals.

| Entrada en qualsevol dels camps afectats | Text normalitzat abans de validar i desar |
|---|---|
| `"  Eau  de   parfum  "` | `"Eau de parfum"` |
| `"ÉCRU\t \r\nclair"` | `"ÉCRU clair"` |
| `"Écru\u00A0\u202Fclair"` | `"Écru clair"` |
| `"Écru\u00A0clair"` | `"Écru clair"`; un únic blanc especial també es converteix. |

| Cas, després de normalitzar els blancs i segons CI_AI | Resultat requerit |
|---|---|
| Crear una segona VariantType amb la mateixa parella Type + Characteristics, encara que variïn majúscules, accents o BrandCode. | Rebutjar; reutilitzar la definició existent quan sigui compatible. |
| Crear una segona parella Type + Characteristics que només difereixi en blancs interiors, tabulacions o salts de línia. | Rebutjar si la normalització produeix la parella existent. |
| Crear `Écru` i `ECRU` com dues files de VariantTypeValue del mateix VariantTypeId. | Rebutjar la segona fila; els textos són equivalents per a la unicitat. |
| Crear `"Écru  clair"` i `"Écru clair"` com dues files de VariantTypeValue del mateix VariantTypeId. | Rebutjar la segona fila; totes dues produeixen el mateix text normalitzat. |
| Crear `Écru` en dos VariantTypeId diferents. | Permès; cada valor pertany al seu propi tipus. |
| Assignar el mateix VariantTypeValueId a diversos SKU. | Permès; és reutilització del valor, no duplicació del catàleg. |
| Diversos valors numèrics amb TextValue NULL. | Permès per la unicitat textual; NumericValue continua sent únic per tipus. |
| Diversos valors textuals estructurats amb NumericValue NULL. | Permès per la unicitat numèrica filtrada; TextValue continua sent únic per tipus. |
| Dos grups amb el mateix ProductGroupName. | Permès; el nom no identifica el grup. |

S'entén per blancs exactament Unicode `White_Space` (no U+200B ni U+FEFF). Es rebutja el resultat buit dels camps obligatoris Type i Characteristics i de qualsevol TextValue informat, estructurat o `open_type`; ProductGroupName pot ser NULL, però si és informat no pot normalitzar-se a buit. No convertir automàticament buit a NULL. La grafia es conserva; Type estructurat continua obert a noms de característica, sense enum tancat. Els CHECKs de text normalitzat han de comparar bytes i longitud, no CI_AI. Aquest acord no amplia la normalització a ValueKind.

### 3.9 Indicadors de risc i validació confirmats

| Àmbit de la decisió | Risc previ i validació binària | Unitat de revisió |
|---|---|---|
| ProductGroup | Propis de la creació/configuració del grup. | Grup complet, diferent de la pertinença dels seus SKU. |
| ProductVariant → ProductGroup | Propis de cada SKU i la seva pertinença comercial. | Una decisió per SKU, fins i tot si es confirma un lot. |
| ProductGroupVariantType | Propis de cada associació grup–tipus. | Una proposta per parella; no s'hereta la validació d'altres grups que usen el mateix VariantType. |
| ProductVariantValue | Propis de cada assignació tipus/valor a un SKU. | No són atributs del VariantTypeValue de catàleg compartit. |

Als quatre àmbits hi ha **EstimatedRiskPercent DECIMAL(5,2) NULL**, rang 0–100, i **IsValidated BIT NOT NULL DEFAULT(0)**. El risc i la validació no són un únic camp: 0% no valida; NULL és no estimable. A ProductVariant corresponen a la pertinença al grup actual. Per a l'associació grup–tipus la validesa final també exigeix codi no nul (§3.6).

L'alta batch d'un SKU vàlid ja carregat a la còpia crea **variant, grup propi i auditories atòmicament**, sense escriure la còpia externa. Grup actiu, grup/pertinença IsValidated=0, risc sustentat o NULL; no aprovació comercial implícita ni recreació d'un SKU ja incorporat, també històric. Recalcular no sobreescriu decisions vigents. No fórmules predictives o camps de fase/publicació nous; validacions manuals sense trasllat a §6.36–6.37.

### 3.10 Codi final i registre permanent — D381–D383/D387–D389

ParkodVariantCode NVARCHAR(5) NULL identifica una habilitació grup–tipus. Cinc caràcters ASCII `0–9`, `A–N`, `P–Z`, sense O, accents, minúscules, blancs o conversió numèrica. NULL en preparació; codi només al final de fase 3 amb valors/principal vàlids i línies requerides resoltes D392. Immutable, permanent, sense reciclatge; actuals i retirats compten. Un tipus pot tenir codis diferents en grups diferents.

Per cada marca: primera assignació **DE000**, després següent en l'ordre de l'alfabet fins a **ZZZZZ**. Sense retorn a00000 ni blocs prohibits. En esgotament, error sense registre/associació/principal/auditoria parcials. Màxim alfabètic del registre complet de marca + increment determinista, amb coordinació SQL exclusiva per marca, restricció única i mateixa transacció de finalització. No MAX+1 desprotegit; el comptador d'IDs de grup continua separat. Ordre SQL coherent, successor, límits, concurrència i resposta incerta encara per materialitzar/provar; no camp de comptador de codis afegit.

Identificador extern **BrandCode(3)+ParkodVariantCode(5)=8**, exemple fictici ABCDE000. No substitueix SKU original3+2+3. D388 confirma CCATEG dos dígits: després de marca, SKU comença per dígit i codi nou per lletra D…Z, separació mantinguda perquè no hi ha retorn a00000. No nou control de col·lisió amb SKU originals o modificació de font. D389 retira rebuig CPROD d'antics blocs/correu específic; resta d'admissió intacta. La regla externa sense O continua sense nou validador específic sobre els camps originals.

#### `dbo.ParkodVariantCodeRegistry`

| Camp | Tipus confirmat | Funció |
|---|---|---|
| BrandCode | NVARCHAR(3) NOT NULL | Marca de reserva; part de PK i FK al grup. |
| ParkodVariantCode | NVARCHAR(5) NOT NULL | Codi permanent únic dins de la marca; part de PK. |
| ProductGroupId | INT NOT NULL | Grup local, conservat després de retirada. |
| VariantTypeId | INT NOT NULL | Tipus, conservat després de retirada. |

PK `(BrandCode, ParkodVariantCode)`, candidata `(BrandCode, ParkodVariantCode, ProductGroupId, VariantTypeId)` per a la FK de l'associació. FK al grup `(BrandCode, ProductGroupId)` i al tipus, sense DELETE CASCADE. App sense DML directe; procediment protegit i coordinació per marca. Taula de blocs retirada sense substitut. DDL/índexs/proves pendents.

### 3.11 `dbo.EvaluationAuditEvent`

Taula única append-only. Camps i contractes JSON següents confirmats; controls SQL, procediments executables i proves pendents:

| Camp | Tipus confirmat | Significat |
|---|---|---|
| EvaluationAuditEventId | BIGINT IDENTITY(1,1), PK | Identitat estable de l'esdeveniment. |
| OperationId | UNIQUEIDENTIFIER NOT NULL | Generat pel procediment SQL per operació atòmica; agrupa les seves entrades, no tot un batch de transaccions independents. |
| OccurredAtUtc | DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME() | Moment segons SQL Server. |
| EventKind | NVARCHAR(32) NOT NULL | proposal_decision o confirmed_change. |
| ActionName | NVARCHAR(64) NOT NULL | proposal_review, create, update, retire, password_reset; assignat pel procediment. |
| DecisionOutcome | NVARCHAR(16) NULL | accepted, rejected, corrected per propostes; NULL per canvis sense proposta. |
| ActorKind | NVARCHAR(16) NOT NULL | user o process; decisions de proposta exigeixen user. |
| ActorAppAccountId | INT NULL, FK a AppAccount | Informat només per autor user. |
| ActorProcessName | NVARCHAR(128) NULL | Informat només per autor process, nom tècnic controlat. |
| TargetScope | NVARCHAR(32) NOT NULL | Àmbit acordat segons taula inferior. |
| TargetKeyJson | NVARCHAR(MAX) NOT NULL | Clau estable o SKU/context si una proposta rebutjada no ha creat fila. |
| OriginalEstimatedRiskPercent | DECIMAL(5,2) NULL | Risc presentat, rang 0–100; NULL si no estimable o sense proposta. |
| OriginalSourcesJson | NVARCHAR(MAX) NULL | Fonts/evidències originals; array segons §3.11.1. SQL NULL significa no registrat/no aplicable; [] significa absència expressa de fonts. |
| OriginalProposalJson | NVARCHAR(MAX) NULL | Proposta original, també en rebutjos/correccions. |
| DecisionResultJson | NVARCHAR(MAX) NULL | Resultat acceptat/corregit; NULL en rebuig. |
| BeforeStateJson | NVARCHAR(MAX) NULL | Snapshot complet anterior, amb exclusions de secrets. |
| AfterStateJson | NVARCHAR(MAX) NULL | Snapshot complet posterior, amb exclusions de secrets. |

| TargetScope | Identitat/context de referència |
|---|---|
| product_group | BrandCode, ProductGroupId; context especial si el grup rebutjat no s'ha creat. |
| group_membership | ProductVariantId i grup complet anterior a la decisió; ProductGroupId JSON null només sense pertinença anterior. |
| group_variant_type | ProductGroupId, BrandCode, VariantTypeId. |
| variant_value | ProductVariantId, VariantTypeId, VariantTypeValueId anterior com a context; JSON null només sense assignació anterior, no nova PK. |
| variant_type | VariantTypeId. |
| variant_type_value | VariantTypeValueId. |
| parkod_copy | CMARQ, CCATEG, CPROD. |
| app_account | AppAccountId. |
| app_session | AppSessionId de la sessió destinatària; exclusivament tancament administratiu forçat D302. |

Sense fila/ID creat, una proposta rebutjada identifica el context aprovat a §3.11.3, sense inventar IDs ni utilitzar noms com a claus. SQL exigeix JSON vàlid i el procediment comprova contingut, autor, àmbit, acció i resultat. No hi ha FK des de TargetKeyJson que impedeixi traçar candidates eliminades. Aquestes propietats JSON no canvien PK, FK ni nul·litat de columnes.

Una entrada per objecte afectat i decisió individual, OperationId compartit per confirmació conjunta. Cada altra confirmació rep un ID nou; un batch amb transaccions independents no comparteix un únic OperationId global. Snapshots de tota la fila variants amb noms del model: alta només posterior, eliminació només anterior; rebuig sense canvi, cap snapshot. Rebutjar i eliminar una candidata produeix una sola entrada `proposal_decision / proposal_review / rejected` amb BeforeStateJson complet i AfterStateJson/DecisionResultJson SQL NULL, abans del DELETE i en la mateixa transacció; no una entrada addicional d'eliminació. Dades i auditoria sempre atòmiques. No contrasenyes, PasswordHash, tokens, altres secrets ni dades EAN gestionades fora de l'app. Excepció exclusiva: confirmed_change/password_reset permet ambdós snapshots NULL, mantenint compte, actor, moment i acció. No lectures, inicis/finals batch, errors sense canvi, SKU intactes sense nova decisió expressa de proposta o edicions descartades. D280 concreta una decisió de proposta amb fila intacta a §6.23.3, no una lectura rutinària. Sense purga automàtica; reversió com a nova operació revalidada/auditada.

#### 3.11.1 Fonts originals

OriginalSourcesJson és una llista amb la forma següent. Exemple fictici d'una lectura de la còpia:

```json
[
  {
    "source": "VARIANTS_PARKOD.dbo.Parkod",
    "records": [
      {
        "source_identifier": {"CMARQ": "ABC", "CCATEG": "01", "CPROD": "001"},
        "raw_value": {"CLIGNE": "01", "code1": "50", "code2": "L"}
      }
    ]
  }
]
```

- `source` identifica la taula realment consultada: `parkod.dbo.PARKOD` si s'ha llegit l'original, `VARIANTS_PARKOD.dbo.Parkod` si s'ha llegit la còpia. No atribuir una lectura de la còpia a l'original, encara que totes dues siguin dbo.
- `records` conserva els registres utilitzats; `source_identifier` els identifica segons la font i `raw_value` conserva les dades observades amb els seus noms originals. Les claus de dades depenen de la font; no són columnes noves del model.
- `[]` expressa que no s'han utilitzat fonts. SQL NULL significa informació no registrada o no aplicable; no són equivalents.
- No s'afegeixen automàticament propietats de recursos externs encara no definits, ni es reconstrueixen les evidències consultant la versió actual de la font en confirmar.

#### 3.11.2 Propostes originals i resultats

Els textos de catàleg són evidència històrica, no rèpliques físiques. Originals enregistrats mai reescrits. **Plantilles del tall D379:** les llistes i l'exemple següents amb categoria/línia de grup es conserven com a base històrica, no payloads actuals. D380 retira propietats comunes de grup, no categoria/línia pròpies dels SKU o raw_value. **Grup–tipus nou ja adaptat a §6.45.4**; altres plantilles/formes exactes encara §7-E02, no substituir propietats inventant-ne. Autoritat dels originals/accepted-corrected/JSON null/decisions individuals/no-generació anticipada intactes.

| Cas | Propietats de OriginalProposalJson | Condicions confirmades |
|---|---|---|
| Grup–tipus | BrandCode, CategoryCode, ProductGroupId, LineCode, VariantTypeId, Type, Characteristics, ValueKind, ProductVariants | LineCode superior és el destí proposat; ProductVariants conté objectes amb ProductVariantId i LineCode original de cada SKU. ID de grup real si existeix; JSON null només dins de la creació conjunta d'un grup nou. |
| SKU–valor | ProductVariantId, BrandCode, CategoryCode, ProductGroupId, VariantTypeId, VariantTypeValueId, Type, Characteristics, ValueKind, NumericValue, TextValue | NumericValue/TextValue respecten ValueKind; un és JSON null. Aquest format no autoritza inventar IDs de tipus/valors encara no creats. |
| Pertinença a grup existent | ProductVariantId, BrandCode, CategoryCode, ProductGroupId, LineCode | Identifica el destí proposat, no el grup anterior. |
| Pertinença a grup nou | ProductVariantId, BrandCode, CategoryCode, ProductGroupId, LineCode; ProductGroupName si proposat | ProductGroupId és JSON null; el nom només és descriptiu i no identifica el grup. No es crea ni es trasllada abans de validar. |
| Creació de grup | BrandCode, CategoryCode, ProductGroupId, LineCode, ProductGroupName, ProductVariantIds | ProductGroupId és JSON null; ProductVariantIds conté almenys un ID de SKU real, sense repeticions. |

**Les dues línies de context de la proposta grup–tipus (D166):** LineCode superior és la línia del grup proposat. Cada `ProductVariants[].LineCode` és el `ProductVariant.LineCode` que tenia el SKU en preparar l'original, **no** un possible CLIGNE nou de parkod.dbo.PARKOD. La llista contextual no substitueix les decisions individuals de pertinença. En una correcció tècnica de línia, actual i destí poden diferir durant la proposta, mai a l'estat final confirmat. No s'amplien per aquest acord els JSON de pertinença o creació amb noves propietats ProductVariants.

Exemple fictici de grup–tipus dins d'una creació amb correcció tècnica de línia; no és autorització per barrejar línies:

```json
{
  "BrandCode": "ABC",
  "CategoryCode": "01",
  "ProductGroupId": null,
  "LineCode": "02",
  "VariantTypeId": 101,
  "Type": "Size",
  "Characteristics": "letter",
  "ValueKind": "text",
  "ProductVariants": [
    {"ProductVariantId": 1001, "LineCode": "01"},
    {"ProductVariantId": 1002, "LineCode": "01"}
  ]
}
```

DecisionResultJson reutilitza l'estructura corresponent amb el contingut final aprovat; SQL NULL en rebuig. En crear el grup inclou l'ID real i els membres aprovats. En grup–tipus inclou també el LineCode de destí final i ProductVariants amb els membres aprovats i les seves línies finals. Els originals conserven els valors previs.

ProductVariantIds representa un conjunt: rebutjar repeticions, no deduplicar; l'ordre és irrellevant i reordenar-lo no és una correcció. Una proposta/confirmació de creació exigeix almenys un membre; si no se n'aprova cap, no es crea grup i la creació és rebutjada, no corregida amb zero membres. Això no impedeix conservar grups existents buits.

Assignar l'ID real no és una correcció del grup ni de les associacions confirmades amb ell. Modificar l'agrupació proposada sí que ho és. Executar un canvi de línia que ja estava proposat i s'aprova tal qual és una acceptació, encara que la línia final difereixi del context original per SKU. Per això no es classifica accepted/corrected comparant mecànicament tots els bytes de proposta i resultat. Tampoc es compara amb l'estat SQL anterior: una proposta nova de valor 302 sobre una assignació vigent 301 és accepted si s'aprova 302 sense corregir la proposta.

#### 3.11.3 Claus d'auditoria

| TargetScope / cas | Propietats exactes de TargetKeyJson |
|---|---|
| product_group existent o creat | BrandCode, ProductGroupId |
| product_group rebutjat abans de crear | BrandCode, ProductGroupId: null, ProductVariantIds originals |
| group_membership amb pertinença anterior | ProductVariantId, BrandCode, ProductGroupId del grup **anterior** |
| group_membership en alta inicial, sense pertinença anterior (D172) | ProductVariantId real, BrandCode, ProductGroupId: null |
| group_variant_type amb grup existent o creat | ProductGroupId, BrandCode, VariantTypeId |
| group_variant_type rebutjat abans de crear el grup | ProductGroupId: null, BrandCode, ProductVariantIds originals, VariantTypeId |
| variant_value amb assignació anterior | ProductVariantId, VariantTypeId, VariantTypeValueId **anterior** a la decisió |
| variant_value sense assignació anterior (D171) | ProductVariantId real, VariantTypeId real, VariantTypeValueId: null |
| variant_type | VariantTypeId |
| variant_type_value | VariantTypeValueId |
| parkod_copy | CMARQ, CCATEG, CPROD |
| app_account | AppAccountId |
| app_session — tancament administratiu forçat | AppSessionId |

Claus anteriors adaptades per eliminació dels components comuns de grup D380, només per esdeveniments nous; claus/snapshots històrics no reescrits. VariantTypeValueId segueix sent context de variant_value, no part de la PK SQL. Grup anterior real en clau de pertinença; destí en proposta/resultat. Absència inicial conserva grup JSON null/ID real del SKU. Detall per operació i comparadors pendents §7-E02, sense nou TargetScope.

**Absència de context anterior (D171–D172):** una candidata SKU–valor existent, encara no validada, aporta el seu VariantTypeValueId anterior real; no s'utilitza null perquè sigui pendent. En l'alta inicial d'una ProductVariant, SQL obté ProductVariantId real abans de generar l'auditoria de pertinença: ProductGroupId null a la clau significa que no hi havia pertinença anterior, mentre que AfterStateJson conté la fila completa amb el grup propi real. En ambdues altes BeforeStateJson és SQL NULL i AfterStateJson complet. Cap d'aquests null autoritza IDs/FK SQL nuls ni una variant sense grup. No s'extrapolen a catàlegs sense ID creat.

Les excepcions de grup no creat només identifiquen un context, no una nova clau física ni un grup pel nom. Un rebuig explícit d'una associació sense grup creat té ambdós snapshots i resultat SQL NULL, perquè no existia fila. Rebutjar el grup no genera rebutjos automàtics dels tipus no decidits individualment. Un error tècnic no es registra com a rebuig humà.

#### 3.11.4 Coherència d'esdeveniments i snapshots

| Cas | EventKind / ActionName / DecisionOutcome | Originals i resultat | Snapshots |
|---|---|---|---|
| Acceptar o corregir proposta | proposal_decision / proposal_review / accepted o corrected | OriginalProposalJson i DecisionResultJson obligatoris; risc/fonts originals poden ser NULL segons el cas. | Del canvi real produït. |
| Rebutjar sense modificar dades | proposal_decision / proposal_review / rejected | Original obligatori; resultat SQL NULL. | Tots dos SQL NULL; estat validat vigent preservat. |
| Rebutjar i eliminar candidata admissible | proposal_decision / proposal_review / rejected, una sola entrada | Original obligatori, fonts/risc preservats; resultat SQL NULL. | Before complet; After SQL NULL. Auditoria abans del DELETE, mateixa transacció. |
| Corregir A candidata admissible cap a una altra associació B (§6.11) | proposal_decision / proposal_review / corrected per A | Originals d'A preservats; resultat amb B aprovada. | Before d'A complet; After SQL NULL perquè s'elimina A. Auditories de B segons si és nova, candidata o ja aprovada. |
| Retirada funcional expressa d'associació/assignació (§6.11) | confirmed_change / retire / DecisionOutcome NULL | Camps de proposta de l'esdeveniment SQL NULL; risc/originals de la fila preservats dins de Before. | Before complet; After SQL NULL, abans del DELETE i mateixa transacció. No rebuig de predicció implícit. |
| Canvi confirmat sense proposta prèvia | confirmed_change / acció controlada / DecisionOutcome NULL | Risc/fonts originals, proposta i resultat SQL NULL. | Documenten el canvi; només password_reset admet tots dos SQL NULL. |

Eliminar per rebuig només és admissible per a una candidata grup–tipus IsValidated=0, codi NULL i sense ProductVariantValue, o una assignació SKU–valor IsValidated=0. Una associació aprovada a fase 2, encara sense codi, ja no entra en aquest circuit de candidata rebutjable. Catàlegs, SKU i grups no s'eliminen. Una proposta nova sobre estat validat rebutjada conserva l'estat vigent.

**Precisió expressament confirmada D280:** si es revisa una proposta nova sobre assignació validada però el valor final és l'actual, registrar la decisió accepted/corrected amb originals/risc nous i resultat a l'esdeveniment, sense UPDATE de la fila ni dels seus originals/risc; ambdós snapshots SQL NULL perquè cap fila canviada. No és confirmed_change sense canvi ni una ampliació de password_reset. Un no-op manual sense proposta, en canvi, no genera auditoria i retorna OperationId SQL NULL només als circuits que ho autoritzen explícitament (§6.22–6.23).

Els snapshots contenen tots els camps auditables reals de la fila, amb els noms del model i camps NULL explícits, excloent secrets. Per exemple, VariantType inclou ara ValueKind. Quan es documenten altes/eliminacions, SQL NULL per al snapshot corresponent significa absència de fila; un camp JSON null significa que la fila existeix i té aquell camp nul. Això no converteix els dos snapshots NULL d'un rebuig sense canvi en una afirmació que la fila no existeixi: en aquell cas no es registra cap snapshot. Les columnes JSON s'inclouen com a objectes/arrays imbricats, no com a strings escapats. Es preserva el contingut, no necessàriament indentació o espais de formatació.

#### 3.11.5 Validació i autoritat de generació

- Cap objecte JSON, ni interior, admet propietats duplicades, encara que els valors siguin idèntics. No escollir primer/últim ni reparar silenciosament.
- TargetKeyJson, OriginalProposalJson i DecisionResultJson només admeten propietats previstes per al cas, amb noms exactes sensibles a majúscules; desconegudes o mal escrites es rebutgen. Això no converteix els camps originals de raw_value en un esquema global fix.
- Els procediments SQL generen TargetKeyJson, snapshots i DecisionResultJson a partir de files/context verificats i del resultat real. La GUI no imposa aquests JSON com a text lliure. SQL genera també OperationId per operació atòmica.
- Per a candidates persistents pendents, els originals/risc autoritatius es rellegeixen de la fila SQL sota bloqueig i es contrasta que sigui el context revisat. Per a propostes no persistents, els conserva el backend separadament de les correccions manuals.
- En una proposta nova sobre una fila ja validada, els JSON guardats poden correspondre a una decisió antiga: no s'utilitzen com a originals de la proposta nova ni se sobreescriu l'estat vigent abans de confirmar. El backend conserva separadament els originals nous fins a decidir.
- SQL valida estructura, referències i coherència, però no pot demostrar tot sol què es va mostrar al tècnic ni quina resposta externa va observar el backend. Si es perd el context temporal, cal nova revisió; no es reconstrueix silenciosament per confirmar. No s'afegeixen taules de propostes, versions o snapshots persistents per aquest acord.

Els contractes d'aquests casos estan confirmats. Les validacions executables, les signatures exactes i els casos addicionals encara no detallats resten a §7; ISJSON sol no garanteix aquests controls. Els dos noms/responsabilitats de procediment de substitució sí que estan confirmats a §6.11.2.

D302/D329 adaptats D380: ForceCloseAppSession conserva àmbit/acció/clau i una auditoria. Snapshot segur actual de cinc camps: AppSessionId, AppAccountId, LastActivityAtUtc, ReservedBrandCode, ReservedProductGroupId. After SQL NULL, secrets exclosos, sense auditoria extra per reset/rutina. Antics snapshots de sis camps intactes; lector/context/confirmador contrastats a §6.28/§6.45.4, SQL/proves pendents.

D321/D329 adaptats D380/D386: desactivació audita product_group amb clau marca–grup i Before/After actuals de set camps, IsActive1→0. After objecte existent, altres camps intactes, UUID només per canvi real; cap UUID global o auditoria de skips. Snapshots antics de nou camps/originals conservats literalment, no migrats o completats artificialment.

### 3.12 `dbo.AppAccount`

| Camp | Tipus confirmat | Significat |
|---|---|---|
| AppAccountId | INT IDENTITY(1,1), PK | Identitat pròpia de l'app. |
| LoginName | NVARCHAR(80) NOT NULL, UNIQUE | Blancs Unicode normalitzats i comparació CI_AI, també entre desactivats. |
| PasswordHash | NVARCHAR(255) NOT NULL | Hash autodescriptiu Argon2id, no contrasenya reversible. |
| IsActive | BIT NOT NULL DEFAULT(0) | Permet login; desactivar no expulsa sessió oberta. |
| IsAdmin | BIT NOT NULL DEFAULT(0) | Permisos administratius vigents; també té permisos de tècnic. |

Retirar IsAdmin elimina permisos administratius immediatament, amb sessió conservada com a tècnic; IsAdminAtLogin descartat. Rebutjar atòmicament desactivar/retirar IsAdmin a l'últim administrador actiu. Només administrador restableix contrasenyes, sense canvi propi per tècnic. Qualsevol restabliment revoca sessió/reserva i descarta edicions no validades, sense tocar decisions confirmades; auditoria password_reset sense secrets.

Bootstrap fora GUI només amb AppAccount buit i identitat SQL d'administració autoritzada, mai compte ordinari variants: crea primer compte actiu/administrador sense contrasenya predeterminada, hash Argon2id, alta i auditoria process/bootstrap atòmiques. Recuperació excepcional fora GUI amb identitat SQL d'administració autoritzada: restableix administrador existent, revoca sessió/reserva, no modifica IsActive/IsAdmin ni crea comptes; auditoria process/admin_recovery/password_reset. Cap compte/contrasenya permanent de reserva. Permisos concrets, procediments i proves pendents.

### 3.13 `dbo.AppSession`

| Camp | Tipus confirmat | Significat |
|---|---|---|
| AppSessionId | UNIQUEIDENTIFIER, PK | Identitat de sessió. |
| AppAccountId | INT NOT NULL, FK/UNIQUE | Una sola sessió per compte. |
| SessionTokenHash | VARBINARY(32) NOT NULL, UNIQUE | SHA-256 d'un token aleatori; no token en clar. |
| LastActivityAtUtc | DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME() | Última interacció real de l'usuari. |
| ReservedBrandCode | NVARCHAR(3) NULL | Marca del grup reservat. |
| ReservedProductGroupId | INT NULL | Grup local reservat. |

Reserva D380: els dos camps ReservedBrandCode/ReservedProductGroupId NULL o tots dos informats, FK a marca–grup, índex únic filtrat per impedir dues reserves del mateix grup. ReservedCategoryCode retirada com a derivació de la nova identitat, no reserva d'un subconjunt de categories. Una pantalla/grup per usuari; caducitat30min configurable, renovació només per interacció real, neteja per demanda/login/batch, sense heartbeat o transacció de formulari. Regles de logout/reset/reserves vigents conservades.

### 3.14 `dbo.SynchronizationStatus`

| Camp | Tipus confirmat | Significat |
|---|---|---|
| SynchronizationStatusId | TINYINT, PK restringida a 1 | Una sola fila global. |
| ParkodLastCompletedAtUtc | DATETIME2(3) NULL | Final de l'última càrrega externa **completa** correcta de la còpia (D379); no data de recàrrega de producció. Conservada en fallada. |
| ParkodRefreshSucceeded | BIT NOT NULL DEFAULT(0) | Disponibilitat global de la còpia: procés extern posa 0 abans de carregar, 1 només després de verificar/publicar la càrrega completa correctament; 0 si falla (D379). |
| VariantsLastCompletedAtUtc | DATETIME2(3) NULL | Final de l'última conciliació completa acabada; no parcials. |
| VariantsReconciliationSucceeded | BIT NOT NULL DEFAULT(0) | 0 abans de modificacions del batch complet; 1 en acabar lectura/processament complets. |

Només cinc camps, sense versions/estats per marca. **D379 substitueix el vessant parcial de D364:** procés extern manté els dos camps Parkod només per a càrregues completes; una parcial reeixida no pot certificar recuperació global després d'una completa fallida i deixa de ser una modalitat admesa. La data continua sent de publicació de **còpia**, no de recàrrega original. L'app manté només els dos variants en conciliació completa; conciliacions per marques i omissions no alteren estat global variants ni senyals Parkod. No carregador desenvolupat, nou estat per marca o camp afegit. Completa amb incidències individuals controlades pot acabar 1; infraestructura/lectura incompleta no. SMTP fallit no rebaixa èxit de dades confirmat. Integració/autoritzacions pendents (§6.7/§6.39, Parkod.md §23).

Omissió programada per font ja conciliada només si ambdós indicadors són 1 i VariantsLastCompletedAtUtc és posterior a ParkodLastCompletedAtUtc. Manual explícit pot repetir; parcials no declaren tota la base al dia. Estat fiable per conciliar no equival a elegibilitat comercial: cap indicador 0 és veto global del generador Parkod, que anota el fet al seu log i aplica controls per SKU.

## 4. Relacions i materialització proposada

| Relació | Cardinalitat funcional | Argument |
|---|---|---|
| Parkod → ProductVariant | 1:1 per als SKU incorporats; 0..1 durant el processament | Un SKU no es duplica; la identitat de variant és independent. |
| ProductGroup → ProductVariant | 1:N, permetent grups buits | Cada variant té un únic grup de la mateixa marca; categories i línies dels membres poden diferir. |
| ProductGroup ↔ VariantType | N:M | Una mateixa definició s'utilitza en qualsevol marca si BrandCode és NULL, o només en la marca informada; el criteri és independent de Type. |
| ProductGroupVariantType ↔ ProductGroup, com a principal | 0..1:0..1, només dins del mateix grup | El grup selecciona una associació pròpia; la selecció és obligatòria amb un o més tipus habilitats. No depèn del nombre de SKU. |
| VariantType → VariantTypeValue | 1:N, permetent un catàleg inicialment buit | Cada valor pertany a una definició i respecta el seu ValueKind homogeni. |
| ProductVariant → ProductVariantValue | 1:N, permetent SKU sense assignacions | Com a màxim un valor per tipus i SKU. |
| VariantTypeValue → ProductVariantValue | 1:N | Reutilització dels valors del catàleg. |
| ProductGroupVariantType → ProductVariantValue | 1:N | Preparació possible amb associació de fase 2 aprovada sense codi; ús Parkod només amb habilitació final. |

La següent disposició de FK i claus candidates ha rebut **confirmació conceptual**, no és DDL executable. Continua incompleta respecte dels controls condicionals de marca, ValueKind, selecció humana i recompte del principal:

| Taula filla | Camps FK | Taula pare / camps referenciats |
|---|---|---|
| ProductGroup | ProductGroupId, BrandCode, PrimaryVariantTypeId | ProductGroupVariantType / ProductGroupId, BrandCode, VariantTypeId |
| ProductVariant | BrandCode, CategoryCode, ProductCode | Parkod / CMARQ, CCATEG, CPROD (PK de la còpia; línia d'entrada revalidada en alta/correcció, no FK CLIGNE) |
| ProductVariant | BrandCode, ProductGroupId | ProductGroup / BrandCode, ProductGroupId |
| VariantTypeValue | VariantTypeId, Type | VariantType / VariantTypeId, Type (`ON UPDATE CASCADE` només per correccions editorials de Type; cap cascada DELETE) |
| ProductGroupVariantType | BrandCode, ProductGroupId | ProductGroup / BrandCode, ProductGroupId |
| ProductGroupVariantType | VariantTypeId | VariantType / VariantTypeId |
| ProductVariantValue | ProductVariantId, ProductGroupId, BrandCode | ProductVariant / ProductVariantId, ProductGroupId, BrandCode (`ON UPDATE CASCADE` limitat a aquesta FK; sense cascada DELETE) |
| ProductVariantValue | ProductGroupId, BrandCode, VariantTypeId | ProductGroupVariantType / ProductGroupId, BrandCode, VariantTypeId |
| ProductVariantValue | VariantTypeValueId, VariantTypeId | VariantTypeValue / VariantTypeValueId, VariantTypeId |
| ProductGroupVariantType | BrandCode, ParkodVariantCode, ProductGroupId, VariantTypeId | ParkodVariantCodeRegistry / clau candidata dels quatre camps (codi nullable durant preparació) |
| ParkodVariantCodeRegistry | BrandCode, ProductGroupId | ProductGroup / PK completa |
| ParkodVariantCodeRegistry | VariantTypeId | VariantType / PK |
| AppSession | AppAccountId | AppAccount / PK |
| AppSession | ReservedBrandCode, ReservedProductGroupId | ProductGroup / PK completa; reserva opcional tota NULL o informada |
| EvaluationAuditEvent | ActorAppAccountId | AppAccount / PK; autor user, NULL per process |

Clau candidata de grup amb línia retirada D380. UNIQUE tècnica ProductVariant `(ProductVariantId, ProductGroupId, BrandCode)`; les de VariantType `(VariantTypeId, Type)` i VariantTypeValue `(VariantTypeValueId, VariantTypeId)` intactes. Ni categoria/línia al grup o a PVV, ni FK de quatre camps a còpia. Tipus/collations coincidents a cada costat de FK, DDL i proves pendents.

FK de grup: mateixa marca i existència. Dues cascades limitades de grup/marca i Type editorial conservades; cap DELETE CASCADE o pèrdua de valors/IDs. CLIGNE local i context actual revalidats en corrector, sense font escrita. Matriu §6.42.3 per validacions/codi nou; SQL2017/permisos/proves pendents.

D321/D326 no afegeixen IsActive a cap PK/FK ni a les seves rèpliques. La regla «grup inactiu sense SKU ni reserva vigent» i la prohibició de noves incorporacions/reserves es comproven a les vies SQL protegides sota coordinació compartida; aquestes FK, que continuen iguals, no imposen per si soles l'activitat. Registre permanent, associacions i reserves caducades poden referenciar la fila conservada inactiva. No DELETE CASCADE, nou índex o mecanisme de bloqueig concret aprovat implícitament per afegir el camp.

Per al principal s'utilitzaria la PK completa de ProductGroupVariantType; una FK només a VariantType o només amb ProductGroupId no garantiria el tipus habilitat al grup correcte. L'enllaç de retorn amb ProductGroup introdueix una dependència circular d'inserció/manteniment que s'ha de validar: per exemple, crear el grup sense tipus ni principal, habilitar els tipus i fixar el principal en una operació curta amb comprovació de l'estat final. No s'han de mantenir transaccions obertes mentre el tècnic edita un formulari.

Les regles a materialitzar inclouen els acords següents; el disseny físic concret continua sent una proposta:

- Unicitat del Parkod dins de ProductVariant.
- PK grup `(BrandCode, ProductGroupId)`, numeració INT positiva des d'1 per marca, segura en concurrència.
- Mateixa marca per membres; categories/línies diferents permeses, sense aquests camps al grup.
- ProductVariant.LineCode propi inicialitzat de CLIGNE local, preservat fins a revisió; còpia només lectura/FK SKU de tres camps, CCATEG dos dígits textuals. Corrector pot conservar grup.
- Unicitat global de `(Type, Characteristics)` per a tots els VariantType, després de normalitzar els blancs i segons CI_AI, sense incloure BrandCode.
- Normalització automàtica dels blancs, trim i persistència dels quatre camps textuals acordats, inclosa la rèplica Type, amb collation CI_AI explícita als camps nous afectats i sense canviar el model legacy.
- PK `(ProductGroupId, BrandCode, VariantTypeId)` de ProductGroupVariantType, sense duplicar associacions o tipus.
- ParkodVariantCode únic per marca incloent retirats, NVARCHAR(5)/ASCII sense O/DE000…ZZZZZ/sense retorn, registre permanent, sense blocs o rebuig CPROD reservat. Reserva/codi/principal/auditoria atòmics al final de fase3, línies requerides resoltes. Només1/codi informat és final.
- Principal pertanyent a una associació del mateix grup identificat per la seva PK completa, compatible amb la marca; el recompte també utilitza aquella identitat completa.
- Zero tipus: principal NULL; un tipus: aquell mateix ID; més d'un: selecció tècnica obligatòria. No es compten SKU ni assignacions de valors.
- Bloqueig d'exportació i de canvis que deixin un estat final invàlid si falta el principal obligatori; correccions i revalidació atòmiques, segures davant canvis concurrents d'associacions.
- Compatibilitat de marca: BrandCode del tipus nul o igual al del grup, tant per als estructurats com per als `open_type`; procediments protegits i bloquejos per tipus aprovats, implementació pendent.
- Bloqueig ordinari del canvi de BrandCode si hi ha assignacions, incloses les dels SKU retirats; sense assignacions, revalidació atòmica de totes les associacions sota bloqueig exclusiu per tipus. Proves pendents.
- Unicitat de `(VariantTypeId, NumericValue)` només per als números no nuls, sense impedir múltiples textos d'un tipus.
- Unicitat de `(VariantTypeId, TextValue)` per als textos no nuls, després de normalitzar els blancs i segons CI_AI; reutilització del mateix valor per diversos SKU permesa.
- Exactament un camp NumericValue/TextValue informat; correspondència amb ValueKind del pare i homogeneïtat per VariantTypeId mitjançant procediments protegits. `open_type → text`; Type no basta per deduir la representació dels estructurats.
- Bloqueig ordinari de ValueKind amb qualsevol valor de catàleg o associació IsValidated=1 de qualsevol grup, encara sense codi; comprovació/canvi atòmics respecte d'altes de valors i aprovacions de fase 2, sense invalidacions automàtiques.
- PK composta que limita una assignació per tipus i SKU.

No es creen FK a taules originals ni esborrats en cascada. Els trasllats de grup han de revalidar marca, categoria i línia del SKU i del destí, preparar/revalidar les associacions, el principal i l'abast de marca de tots els tipus, i mantenir les rèpliques i totes les FK amb una operació transaccional, sense fusionar conflictes automàticament ni canviar IDs. No es canvia BrandCode, CategoryCode, LineCode ni Characteristics silenciosament per permetre una associació incorrecta. El detall de les operacions, controls de línia, marca i principal, bloqueig de canvis i accions FK queda pendent del DDL i de la segona iteració d'anàlisi d'impacte.

## 5. Fonts consultables i equivalències de la còpia de proves

**Inventari tancat D221, actualitzat per D223–D232.** La base `parkod` local és una **còpia de producció per a proves**, no la base de treball original. PARKOD, CATEGORY, FAMILY, EAN, BRAND i LINE són els noms font adoptats; CATEGOR, FAMILLE, GENCOD, MARQUE i LIGNE es conserven com a correspondències històriques, no com a dependències addicionals. L'usuari confirma l'estructura de la còpia com a referència de producció, excepte la collation local aclarida separadament: producció French_CI_AS, proves SQL_Latin1_General_CP1_CI_AS. Font poblada i VARIANTS_PARKOD sense taules són a la mateixa instància local .\SQLEXPRESS/2019; destí de producció 2017 preservat. Diagnòstics previs a §5.5, no verificació directa de producció ni desplegament del model.

A totes les files s'aplica la frontera de §1.1: producció intocable, fonts només en lectura controlada/autoritzada i cap execució dels scripts de càrrega en aquesta tasca. Abast, permisos i impacte resten per provar; qualsevol altra font funcional requereix validació prèvia. Les consultes de metadades no amplien les fonts comercials.

| Font de la còpia de proves | Camps rellevants | Modalitat permesa | Finalitat i límit |
|---|---|---|---|
| `parkod.dbo.PARKOD` | CMARQ, CCATEG, CPROD, CLIGNE, DESIGN1, DESIGN2, code1, code2; NOM_MARQUE, NOM_LIGNE; preus consultables | Única font de la càrrega **externa** dels vuit camps; app només consultes auxiliars autoritzades | Còpia i SourceIsPresent mantinguts fora del projecte. L'app concilia des de la còpia, sense lector original de conciliació/CLIGNE. Noms/preus consultables, no copiats. |
| `parkod.dbo.CATEGORY` | IDCategory, IDFamily, CategoryName | Consulta puntual, sense còpia | `PARKOD.CCATEG = CATEGORY.IDCategory`; nom de categoria i navegació per família. PK i unions sense mancances observades en proves (§5.5), no garantia de càrregues futures. |
| `parkod.dbo.FAMILY` | IDFamily, FamilyName | Consulta puntual, sense còpia | `CATEGORY.IDFamily = FAMILY.IDFamily`; només navegació i lots marca–família, no identitat comercial del grup. |
| `parkod.dbo.EAN` | IDParkod, EANNum | Consulta puntual, sense còpia | `EAN.IDParkod = PARKOD.CMARQ + PARKOD.CCATEG + PARKOD.CPROD`; EAN d'ajuda, sense gestió de vigència/històric ni unicitat suposada d'EANNum. |
| `parkod.dbo.BRAND` | IDBrand, BrandName | Mestre conservat; correspondència de referència | Equivalent de MARQUE; no necessari per obtenir la denominació, disponible a PARKOD.NOM_MARQUE. Cap nova dependència automàtica ni còpia. |
| `parkod.dbo.LINE` | IDLine, IDBrand, LineCode, LineName | Mestre conservat; correspondència de referència | Equivalent de LIGNE; no necessari per obtenir el nom, disponible a PARKOD.NOM_LIGNE. IDLine és compost, no el codi local LineCode. |

Les dependències funcionals de lectura necessàries són **PARKOD, CATEGORY, FAMILY i EAN**. BRAND/LINE es conserven a la font de proves, però no es consulten automàticament com a alternativa als noms directes de PARKOD. Cap mestre ni EAN es copia, ni rep FK des del model nou. DEPARTEM i la resta de fonts no aprovades continuen excloses. `docs/EAN.sql` és la referència legacy de GENCOD; `data/EAN.sql` descriu EAN de proves. Cap d'aquests scripts prova el desplegament físic ni s'executa o modifica aquí.

**País exclòs (D228):** IDCountry no es filtra, agrupa, copia ni utilitza per identificar/classificar productes; el producte és independent del país. No s'introdueix tampoc un filtre de país equivalent amb CODE_PAYS. Aquesta exclusió no demostra que IDCategory, IDFamily o altres codis siguin claus globals úniques: cal contrastar les files i relacions sense país. Una correspondència ambigua exigeix incidència/revisió, mai triar la primera fila, fusionar dades ni inventar una regla de desambiguació. No es declaren PK, tipus, nul·litats o collations de font a partir dels XML/CSV o dels scripts preparatoris.

Els JOIN documentals no creen FK a l'origen. Nom absent permet codi/fallback acordat, no inventar denominacions; error d'accés/ambigüitat no són nom absent. Clau SKU `(CMARQ, CCATEG, CPROD)`, sense país. D360: integritat/duplicats originals són responsabilitat externa; no convertir observacions diagnòstiques en escàner periòdic del projecte. PK de còpia i unicitat de variant intactes.

### 5.1 Nom inicial del grup

En crear un grup propi per a un SKU, `ProductGroupName` s'informa una sola vegada amb `PARKOD.NOM_MARQUE + '_' + PARKOD.NOM_LIGNE + '_' + CATEGORY.CategoryName + '_' + ProductGroupId` (guions baixos literals). Marca i línia es prenen del SKU creador; categoria es consulta per `CATEGORY.IDCategory = PARKOD.CCATEG`. Això substitueix només l'origen dels noms de D77 per a la còpia de proves, no l'ordre ni les regles de generació. Si falta la fila o el nom és NULL, buit o només blancs, s'utilitza respectivament CMARQ, CLIGNE o CCATEG; no es busca un nom a BRAND/LINE ni es tria un altre SKU arbitràriament. Si el resultat normalitzat supera NVARCHAR(150), s'usa `CMARQ_CLIGNE_CCATEG_ProductGroupId`. No s'aplica truncament ni es rebutja un SKU només per nom absent; la sincronització no sobreescriu el nom editable. Una indisponibilitat de font o correspondència ambigua no és un nom absent. Cap columna de denominació s'afegeix a la còpia; només el nom de grup resultant ja aprovat es desa.

### 5.2 Quantitats i unitats originals

`code1` (quantitat) i `code2` (unitat) es copien com a text original sense corregir; la interpretació estructurada és una operació separada. `code1` només admet dígits ASCII, amb punt decimal opcional i dígits als dos costats (`50`, `0.04`, `50.0000`); no s'accepten signes, comes, blancs, notació científica, valor absent, precisió o rang no representables exactament a DECIMAL(18,3). Zeros decimals sobrants no alteren el valor; `50.0001` es rebutja. No utilitzar FLOAT, truncament ni arrodoniment. Quantitat > 0 per als codis admesos i enter per U; això no imposa positivitat global a tots els valors del catàleg.

`code2` és exactament `L → volume/ml`, `G → weight/gr`, `U → count/unit` (L indica mil·lilitres, G grams i U peces comercials); `unitless` només per a mesures adimensionals confirmades. Es rebutgen NULL, buit i codis no aprovats, inclosa `l` minúscula, sense substituir-los per U/1. La regla funcional de defecte U/1 no repara dades històriques incorrectes. Un inventari anterior incloïa 77.777 files, 122 unitats NULL i 11 codis informats prohibits, amb 115 quantitats zero observades; són comptes històrics, no el perfil de la nova exportació de 78.220 files (§5.4), ni totals sumables sense mesurar-ne el solapament. Cal auditar comptes U fraccionaris i impacte per SKU. L'app registra l'error de tractament i preserva classificacions anteriors, però no repara/restaura la còpia externa ni dedueix absències.

### 5.3 Taula documental d'equivalències origen → VARIANTS_PARKOD

**És documentació, no una nova taula SQL, vista, sinònim o migració de noms.** Només recull els camps font utilitzats i les correspondències dels mestres conservats ja acordades. Totes les destinacions internes s'entenen dins de `VARIANTS_PARKOD.dbo`; «sense columna» significa consulta/derivació, no persistència addicional.

| Origen de proves | Referència anterior | Destinació o ús intern | Modalitat | Regla |
|---|---|---|---|---|
| `PARKOD.CMARQ` | Mateix camp | `Parkod.CMARQ → ProductVariant.BrandCode`; BrandCode del grup heretat del primer SKU | Còpia literal + correspondència | Codi textual de marca de 3 caràcters; no BrandId. |
| `PARKOD.CCATEG` | Mateix camp | `Parkod.CCATEG → ProductVariant.CategoryCode`; CategoryCode del grup heretat del primer SKU | Còpia literal + correspondència | Codi textual de categoria de 2 caràcters; no CategoryId. |
| `PARKOD.CPROD` | Mateix camp | `Parkod.CPROD → ProductVariant.ProductCode` | Còpia literal + correspondència | Component SKU de 3 caràcters, no ProductGroupId. |
| `PARKOD.CLIGNE` | Mateix camp | `Parkod.CLIGNE` d'entrada; inicialitza/corregeix LineCode després de decisió, no sincronització automàtica | Càrrega externa literal + classificació | Codi de 2 caràcters; desajust posterior còpia–variant admès D363; no IDLine compost. |
| `PARKOD.DESIGN1` | Mateix camp | `Parkod.DESIGN1` | Còpia literal | Text original, sense normalització ni truncament de còpia. |
| `PARKOD.DESIGN2` | Mateix camp | `Parkod.DESIGN2` | Còpia literal | Text original i NULL preservats. |
| `PARKOD.code1` | Mateix camp | `Parkod.code1` | Còpia literal | Quantitat textual; interpretació separada segons §5.2. |
| `PARKOD.code2` | Mateix camp | `Parkod.code2` | Còpia literal | Unitat textual; cap reparació automàtica. |
| `PARKOD.NOM_MARQUE` | Nom abans consultat a MARQUE.NOMMARQ | Sense columna pròpia; marca visible i component del nom inicial | Consulta; derivació del nom de grup | Dada del SKU, sense còpia de denominació ni dependència de BRAND. |
| `PARKOD.NOM_LIGNE` | Nom abans consultat a LIGNE.LIBLIGNE | Sense columna pròpia; línia visible i component del nom inicial | Consulta; derivació del nom de grup | Dada del SKU; fallback CLIGNE segons §5.1, sense dependència de LINE. |
| `PARKOD.PRIX_ACHAT`, `PARKOD.PRIX_VENTE` | Mateixos camps | Sense columna | Consulta sense persistència | Preus només consultables; no ampliar la còpia. |
| `CATEGORY.IDCategory` | `CATEGOR.CCATEG` | Correspondència amb `Parkod.CCATEG` / CategoryCode | Consulta sense persistència | Unió per CCATEG, sense país; PK observada a §5.5, no inferida de l'XML. |
| `CATEGORY.IDFamily` | `CATEGOR.CFAM` | Sense columna; enllaç amb FAMILY.IDFamily | Consulta sense persistència | Només navegació/lots, cap FamilyCode nou. |
| `CATEGORY.CategoryName` | `CATEGOR.LIBCATEG` | Sense columna pròpia; categoria visible i component del nom inicial | Consulta; derivació del nom de grup | No es copia el mestre; fallback CCATEG segons §5.1. |
| `FAMILY.IDFamily` | `FAMILLE.CFAM` | Sense columna; família de navegació | Consulta sense persistència | Unió amb CATEGORY.IDFamily, no amb un grup comercial. |
| `FAMILY.FamilyName` | `FAMILLE.LIBFAM` | Sense columna; denominació de família | Consulta sense persistència | Només navegació/lots marca–família. |
| `EAN.IDParkod` | `GENCOD.PARKOD` | Sense columna; SKU derivat de BrandCode + CategoryCode + ProductCode | Correspondència + derivació | Vuit caràcters 3+2+3; mai ProductVariantId. |
| `EAN.EANNum` | `GENCOD.GENCOD` | Sense columna; ajuda a identificar variants | Consulta sense persistència | Ni EAN únic suposat, ni nova gestió de vigència/històric. |
| `BRAND.IDBrand` | `MARQUE.CMARQ` | Correspondència de referència amb CMARQ / BrandCode | Correspondència de mestre conservat | Cap nou identificador intern ni dependència necessària. |
| `BRAND.BrandName` | `MARQUE.NOMMARQ` | Sense columna; denominació de referència | Correspondència de mestre conservat | El nom utilitzat prové de PARKOD.NOM_MARQUE, no d'un fallback automàtic. |
| `LINE.IDBrand` | `LIGNE.CMARQ` | Correspondència de referència amb CMARQ / BrandCode | Correspondència de mestre conservat | Component de marca d'IDLine. |
| `LINE.LineCode` | `LIGNE.CLIGNE` | Correspondència de referència amb CLIGNE / LineCode | Correspondència de mestre conservat | Codi local de 2 caràcters quan informat; no IDLine complet. |
| `LINE.LineName` | `LIGNE.LIBLIGNE` | Sense columna; denominació de referència | Correspondència de mestre conservat | El nom utilitzat prové de PARKOD.NOM_LIGNE. |
| `LINE.IDLine` | Parella `LIGNE.(CMARQ, CLIGNE)` | Sense columna; identitat marca–línia derivada | Correspondència + derivació | IDBrand + LineCode = BrandCode + LineCode; 3+2 quan la línia està informada. |

**Fórmules confirmades (D227):** `IDParkod = BrandCode + CategoryCode + ProductCode = PARKOD.CMARQ + PARKOD.CCATEG + PARKOD.CPROD`; `IDLine = IDBrand + LineCode = BrandCode + LineCode = PARKOD.CMARQ + PARKOD.CLIGNE`. Són concatenacions **textuals**, sense separadors ni conversió numèrica, preservant zeros inicials. Un SKU vàlid té exactament 8 caràcters (3+2+3); la identitat marca–línia informada en té 5 (3+2). Ni IDParkod ni IDLine s'afegeixen com a columnes noves. IDLine no substitueix LineCode ni la identitat completa del grup; IDParkod no substitueix el BIGINT ProductVariantId.

**Propis de l'app, sense equivalent font:** SourceIsPresent, ProductVariantId, ProductGroupId i la resta de configuració/validació del grup; catàlegs VariantType/VariantTypeValue, associacions/assignacions, comptadors, registre/blocs de codis, auditoria, comptes/sessions i SynchronizationStatus. Els codis heretats o rèpliques controlades no són noves fonts independents. La taula anterior no constitueix una ordre d'importació de catàlegs ni d'assignació automàtica de BrandCode als tipus; el model intern conserva els noms i les claus, amb 14 taules i 99 camps després d'afegir ProductGroup.IsActive local (D321).

D363 precisa les equivalències de línia anteriors: a la font/còpia l'identificador marca–línia es deriva de CMARQ+CLIGNE; en la classificació de BrandCode+LineCode. La mateixa fórmula 3+2 no fa iguals dos valors de context diferent quan hi ha discrepància pendent. No columna nova, conversió numèrica o ús d'IDLine com a LineCode.

### 5.4 Evidència disponible i límits de validació

- `data/parkod.CSV`: 28 camps i 78.220 files/SKU únics en el perfil revisat; cap SKU duplicat o mal format ni fila amb nombre de camps incorrecte. NOM_MARQUE sempre informat i NOM_LIGNE buit en 12 files, sense noms múltiples observats per marca/parella marca–línia en aquesta exportació. Són observacions del fitxer, no garanties de totes les càrregues ni nul·litats SQL. Els altres camps exportats no s'incorporen automàticament al model.
- Les longituds màximes observades i els tipus suggerits a `data/Parkod_bulk_load.png` no acrediten tipus, longituds, nul·litats, collations, PK o índexs desplegats. XML de CATEGORY/FAMILY contenen IDCountry absent dels scripts de creació; no inferir-ne les claus globals sense verificar-les en lectura.
- A `data/Line.XML`, els 22.403 registres revisats compleixen IDLine = IDBrand + LineCode, però hi ha línies buides i identificadors més curts. No canvia el contracte NOT NULL de ProductVariant.LineCode/ProductGroup.LineCode ni autoritza inventar/completar codis invàlids; cal contrastar els enllaços efectivament utilitzats.
- Els scripts `data/*.sql` contenen càrregues i escriptures sobre parkod: són referència llegida, no executada ni modificada. D229–D232 i §5.5 resolen ubicació local, existència del destí buit i contracte font acceptat; això no desplega el model ni acredita permisos del futur compte d'app, integracions o proves de domini. Les observacions SQL prèvies es distingeixen dels perfils de fitxer.

### 5.5 Diagnòstics previs de només lectura i confirmacions d'entorn

**Evidència de la conversa consolidada el 2026-10-23; no consultes executades en aquesta actualització documental.** Connexió Windows a `.\SQLEXPRESS` amb accés observat a totes dues bases. Motor retornat: 15.0.2200.2, Express Edition (64-bit), RTM. parkod ONLINE amb 9 taules visibles; VARIANTS_PARKOD ONLINE amb 0 taules visibles, d'acord amb la confirmació expressa de l'usuari que no hi ha taules. Totes dues: compatibilitat 150, collation SQL_Latin1_General_CP1_CI_AS, SNAPSHOT OFF, READ_COMMITTED_SNAPSHOT OFF. La identitat de diagnòstic disposava de VIEW DEFINITION a parkod i SELECT a les sis fonts inventariades; no prova permisos del futur compte tècnic limitat ni autoritza concessions.

Els vuit camps de PARKOD s'han contrastat amb les definicions de §3.1 i acceptat per l'usuari, inclosos els tres ajustos D231. A la font de proves, les columnes textuals consultades tenen SQL_Latin1_General_CP1_CI_AS. Metadades rellevants dels altres enllaços llegits, **només de font, no nous camps interns**:

| Font i camp | Tipus SQL observat | Nul·litat |
|---|---|---|
| CATEGORY.IDCategory | VARCHAR(2) | NOT NULL |
| CATEGORY.IDFamily | VARCHAR(2) | NULL |
| CATEGORY.CategoryName | NVARCHAR(20) | NULL |
| FAMILY.IDFamily | VARCHAR(2) | NOT NULL |
| FAMILY.FamilyName | NVARCHAR(20) | NULL |
| EAN.IDParkod | VARCHAR(8) | NULL |
| EAN.EANNum | VARCHAR(13) | NULL |

CATEGORY, FAMILY, BRAND i LINE tenen PK declarades observades; PARKOD i EAN sense índexs declarats en la consulta de catàleg. La clau única de la còpia Parkod és una restricció pròpia aprovada, no una PK que el projecte afegeixi a la font. El detall complet dels camps consultables no transcrit aquí, i en especial la configuració dels futurs accessos de l'app, continua pendent de verificació executable abans del DDL.

| Comprovació sobre les dades locals | Resultat observat |
|---|---|
| Files PARKOD / claus SKU diferents | 78.220 / 78.220 |
| Claus SKU duplicades / files amb forma SKU invàlida | 0 / 0 |
| CLIGNE sense longitud exacta de dos caràcters | 0 |
| Files PARKOD sense CATEGORY corresponent | 0 |
| Categories sense família informada/corresponent | 0 sobre 106 categories; FAMILY amb 11 files al recompte de metadades |
| Files EAN | 588.261 |
| EAN.IDParkod NULL / amb format SKU incorrecte | 0 / 14 |
| EANNum NULL o buit després de trim ordinari | 1 |
| Files EAN sense correspondència amb PARKOD actual | 502.035 |

Unions sense país. La consulta de correspondència EAN ha utilitzat la igualtat textual ordinària de la font local, no una prova separada d'identitat binària. Els comptes són puntuals i poden superposar-se; no se sumen com a anomalies independents. No s'infereix vigència, historial, correcció d'EAN o retirada de SKU. Les lectures no formaven un SNAPSHOT comú ni acrediten el futur protocol de recàrrega/completesa; format vàlid no és classificació humanament validada. Cap font o configuració modificada.

**Producció:** 2017 Express i French_CI_AS general/a totes les columnes textuals confirmats per l'usuari, que accepta l'estructura de la còpia com a contracte font. No s'han rellegit metadades de producció. Es manté French_CI_AS al destí, sense convertir parkod local, i no s'utilitzen característiques exclusives de 2019. Resta configurar/provar el destí i contrastar rendiment/compatibilitat 2017 amb les autoritzacions corresponents.

## 6. Càrrega externa, conciliació i preservació

**Lectura vigent D404:** model13/90 a §2–§4, matriu/mapa §6.42–§6.45 i pendents §7. Les29retirades de categoria a signatures completes/inventari, formes de les famílies revisades i vuit SKU–valor estan adaptats a §6.45. Altres formes històriques amb categoria/línia de grup, reserva amb categoria, codi3 o G9/R5 encara no contrastades són **base a adaptar, no contracte executable**. D404 resol línia en substitució completa, no E02/E04 globals; D396/D402–D403 i D395 conservats.

Frontera D361–D379 conservada: càrrega sempre completa externa, app només llegeix la còpia, conciliació completa/per marques cap a dades pròpies; cap absència original inferida o escriptura de font/còpia. §6.35/Parkod.md §23.

- Una conciliació simultània; completa i parcial exigeixen absència de sessions vigents, mateixos controls SQL i transaccions curtes. No bloqueig deliberat de taules senceres o transacció oberta durant formularis/tot el batch.
- Càrrega externa compatible amb usuaris, però no amb conciliació. Contextos afectats per canvis d'entrada exigeixen revisió; confirmació estable durant càrrega pendent de contrast (§6.40).
- Idempotència: SKU ja incorporat conserva ProductVariantId i classificació. Referència nova admissible a la còpia genera variant, grup propi actiu/provisional i auditories atòmicament, sense crear/modificar la còpia o fusionar comercialment SKU.
- Errors individuals coneguts: rollback només de l'operació, log anglès i continuar quan sigui segur. Infraestructura/lectura incompleta: aturada, sense èxit fictici ni rollback dels COMMIT previs. Resposta perduda manté incertesa, sense reenviament automàtic.
- Duplicats originals/comprovació periòdica de producció i absències són responsabilitat externa. Còpia amb PK de tres camps; no lector original amb SourceSkuOccurrenceCount ni càrrega de fitxers implementats per l'app.
- SourceIsPresent només llegit; càrrega global fiable D379/història/reaparició/protecció d'origen buit són externes, no retirades per conciliació de marques.
- D389: cap rebuig d'admissió o correu específic perquè CPROD sigui dins d'antics blocs reservats. Resta d'admissió/cobertura D371–D373 intacta, sense esborrar còpia per quadrar recomptes.
- Preservar grups buits, variants retirades, valors, decisions i historial. Absència o recodificació no autoritzen DELETE, reciclatge o fusió per EAN/descripció.

Nous/actualitzats/intactes/rebutjats-pendents són resultats de l'app. Retirades/restabliment de presència són dades rebudes, no actuacions del batch. Unitats i fórmules antigues/vigents diferenciades a §6.39.6; no exigir igualtat inicial entre còpia carregada i variants.

D321/D330: cada nou grup propi és IsActive=1/IsValidated=0; no es reutilitza un grup inactiu pel nom/codis ni es reactiva en reapareixences o recàlculs. La conciliació manté l'exclusió global de sessions i no executa el lot administratiu de desactivació. La nova regla només afecta dades del projecte, sense tocar la còpia dels vuit camps ni la font original.

No es creen triggers DML a l'origen ni vistes indexades en aquesta primera versió. Una vista indexada requereix opcions SET compatibles, SCHEMABINDING i manteniment sincrònic que pot afectar les aplicacions antigues, i no pot ser destí de FK.

### 6.1 Comptador i numeració concurrent

ProductGroupCounter adaptat D380: **BrandCode NVARCHAR(3) NOT NULL PK** i **LastAllocatedId INT NOT NULL inicial0**. Dos camps, CategoryCode retirada. ProductGroupId des d'1 per marca; no IDENTITY global, MAX+1 o reinici per línia/categoria. Coordinació exclusiva per marca, increment/nom/grup atòmics en transacció curta, rollback conegut del conjunt. Ordre amb tipus/SKU/grup, overflowINT i concurrència encara per provar. Aquest comptador no genera ParkodVariantCode: el codi segueix el registre i la seqüència D382.

### 6.2 Contracte de bloquejos i vies d'escriptura

Backend interactiu i batch comparteixen una identitat SQL tècnica nova i limitada, separada del carregador i del lector Parkod. El compte de l'app rep EXECUTE autoritzat, no DML directe ni escriptura a l'origen. Procediments d'usuari comproven token, sessió, caducitat i reserva; deriven l'actor d'AppSession, no d'un ID del client, i consulten IsAdmin vigent per a administració. Bootstrap, recuperació i canvi excepcional de marca requereixen permisos SQL administratius fora del compte ordinari. Restriccions SQL són defensa addicional. Bloquejos per mutació són Transaction en transaccions curtes; els de coordinació d'execució es mantenen per connexió dedicada (§6.7), sense transacció oberta de tota la durada del batch. Noms, esperes, propietat SQL efectiva i deadlocks resten per materialitzar/provar.

| Recurs lògic | Mode | Operació protegida | Abast |
|---|---|---|---|
| `VariantTypeId` | Compartit | Associar/aprovar un tipus, crear valors de catàleg, assignar-ne valor o seleccionar-lo com a principal; coordinar BrandCode i ValueKind amb els usos que es validen. | Tots els grups que comparteixen el tipus. |
| `VariantTypeId` | Exclusiu | Canvi ordinari de BrandCode amb els seus controls; canvi de ValueKind només sense valors de catàleg ni associacions aprovades; correccions editorials de tipus/valor i comparació del context (§6.14). | Totes les vies que alteren usos, associacions o dades del context respecten aquesta coordinació; no bloqueig durant el formulari ni reserva de tots els grups. |
| `(CMARQ, CCATEG, CPROD)` | Exclusiu | Incorporació/revisió, correcció de línia classificada i trasllat; revalidació local, sense escriptura de còpia. | Un SKU complet; no coordina per si sol el carregador extern. |
| `(BrandCode, ProductGroupId)` | Exclusiu | Mutacions d'associacions/principal/composició i estat final. | Grup complet, no subconjunt de categories. |
| `BrandCode` | Exclusiu | Comptador d'IDs de grup i coordinació d'assignació de codis D382; no recursos executables nous fixats aquí. | Marca; ordre/recursos concrets a provar. |

Ordre de base: tipus → SKU → coordinació/comptadors de marques → grups marca–ID, cadascun ordenat. Assignació de codi per marca a integrar/provar amb la resta, sense reintents automàtics o garantia d'absència d'interbloquejos. Cap MAX alfabètic fora de coordinació D382. Principal només amb 1/codi informat, selecció expressa si múltiples; no assignacions esborrades o tria tècnica substituïda.

**Límit abans del DDL:** ordre i garanties pendents de tests de concurrència/timeout/deadlock. D363 substitueix les relectures originals: la correcció contrasta i protegeix la fila **local** de Parkod dins de l'operació; si canvia el context, error/nova revisió. L'app no hi escriu. Cal provar confirmació estable davant d'un carregador extern compatible amb GUI; no suposar que respecta els applocks de SKU. Coordinació càrrega/conciliació a §6.7; lectures auxiliars originals separades i autoritzades. No coherència instantània, locks de formulari o canvis a l'original.

### 6.3 CLIGNE carregada i línia de classificació

D363 substitueix la conservació de còpia antiga de D64/D71: el procés extern publica la darrera CLIGNE a la còpia local, mentre ProductVariant.LineCode i el seu grup es conserven fins a revisió tècnica. Diferència intencional, sense estat físic nou. L'app la registra al log anglès, no corregeix la còpia ni rellegeix CLIGNE original. Consumeix SourceIsPresent tal com publicat, també 0; no dedueix absències.

D368–D370 afegeixen visibilitat per al tècnic: comparar Parkod.CLIGNE amb ProductVariant.LineCode del mateix SKU, identificat pels tres codis, i mostrar la discrepància a la llista de pendents de cada inici de sessió, dins d'incidències tècniques (§6.41). No dependre només del log ni crear un camp físic de pendent. D369 permet corregir un valor sense resoldre primer la línia: la correcció de valor no canvia LineCode, grup o còpia i no tanca aquesta incidència.

Tres resultats: mantenir grup/risc, traslladar a existent o crear grup propi d'un SKU amb risc nouNULL D384–D385. D395 reutilitza la via existent per als dos primers, sense tercera parella de procediments; contracte §6.38.2–§6.38.3. Valors/metadata preservats, habilitacions/principal coherents, tipus necessaris al destí preparats. Nou grup amb aprovacions expresses, codis/principalNULL segons regles conservades. Cap igualtat de línies entre membres o còpia escrita.

FK de grup només marca–ID. Corrector revalida/protegeix CLIGNE local i context en transacció curta; rollback conegut només de l'intent, canvi posterior nova incidència. No auto-desvalidació o trasllat en càrrega. D390 exigeix línia resolta abans de validació ordinària, corrector resol i confirma conjuntament. D391/D393/D394 i D369 només autoritzen els àmbits de §6.42.3; exportació prèvia/codis antics intactes.

### 6.4 Lots de revisió i risc orientatiu

Tota proposta de classificació requereix **revisió humana abans de ser definitiva**; cap percentatge, inclòs 0% estimat, autoritza aprovació automàtica. La conciliació crea variant/grup propi inicial a partir de còpia **ja carregada externament**, sense aprovar classificació. Pertinença decidida **per SKU**, també en confirmació conjunta; grup/SKU amb risc/validació independents. Files ja validades intactes no requereixen nova revisió diària. Pantalla mostra tots els SKU i permet corregir/excloure'ls individualment. Menys de 40 variants és dada empírica d'ergonomia, **no** límit funcional.

La creació segueix tres fases amb validació humana per grup: **(1)** grup/configuració i cada pertinença SKU; **(2)** associacions grup–tipus amb candidates persistents i aprovació IsValidated; **(3)** valors per SKU només per associacions aprovades, seguida d'assignació final atòmica del codi i principal coherent. Un grup pot avançar sense esperar totes les marques. La IA pot proposar, mai confirmar; desenvolupament amb fonts externes/IA en etapes posteriors, després d'etapa 0. Cada assignació té risc/validació propis, sense herència. La pantalla mostra tots els SKU/valors pertinents i permet correccions individuals. Associacions amb codi NULL, incloses IsValidated=1, no són habilitacions Parkod.

Per calibrar estimacions es registra **tota proposta amb decisió definitiva**: acceptada, rebutjada o corregida, amb risc original i totes les fonts utilitzades; la correcció conserva la proposta inicial i el resultat aprovat. Quan intervenen diverses fonts, es calcula per combinació sense atribuir arbitràriament l'error a una de sola. Es pot observar `rebutjades o corregides / total de propostes decidides`, per àmbit i combinació, amb denominador i nombre de casos visibles. Aquest quocient posterior no és el risc previ ni substitueix la revisió. Sense dades suficients: «risc no estimable»; **0% calculat és admissible, però no prova correcció ni valida**. Camps i contractes JSON dels casos de §3.11 aprovats; fórmula predictiva, fonts externes concretes, calibratge, controls executables i implementació pendents.

El botó «Validar» confirma decisions individuals quan pertoqui. Tancar sense validar descarta edicions manuals, no recuperables. Això no elimina candidates automàtiques persistents grup–tipus/SKU–valor amb risc i JSON originals. Propostes no persistents, inclosa pertinença a grup candidat, poden recalcular-se en reobrir; el SKU manté grup provisional fins a validar. L'auditoria conserva decisions i canvis confirmats, no esborranys de pantalla.

Els tècnics poden preparar lots per marca–categoria o **marca–família**, a partir de `PARKOD.CCATEG = CATEGORY.IDCategory` i `CATEGORY.IDFamily = FAMILY.IDFamily`, per començar i acabar feina en sessions acotades; diverses persones poden treballar en marques diferents. Família és un filtre de navegació, no PK de grup, àmbit de numeració o atribut nou de ProductGroup; IDCountry no intervé. Cap transacció de SQL no roman oberta mentre es revisa un lot; es revalida abans de desar. La futura pantalla del grup, identificat per `(BrandCode, CategoryCode, ProductGroupId)`, mostra **tots** els SKU calculats d'aquell grup, amb els seus codis i DESIGN1/DESIGN2, el nom del grup, la marca (CMARQ + PARKOD.NOM_MARQUE), la categoria (CCATEG + CATEGORY.CategoryName), la família (CATEGORY.IDFamily + FAMILY.FamilyName) i la línia (CLIGNE + PARKOD.NOM_LIGNE). Els noms directes es consulten pels SKU corresponents; el nom inicial segueix el SKU creador (§5.1), sense seleccionar arbitràriament un nom comú davant discrepàncies. Si falta una denominació es mostra el codi i la incidència, sense rebutjar un SKU només per això. BRAND/LINE no són necessàries per obtenir aquests noms. La GUI i missatges externs seran en francès, els logs tècnics en anglès.

### 6.5 Lectura externa de l'estat validat

La **primera** exportació d'un ProductGroup exigeix: creació/configuració validada, almenys un SKU present i aprovat, principal informat i vàlid, totes les associacions ProductGroupVariantType habilitades validades i un VariantTypeValue **assignat i validat per cadascun dels tipus habilitats** a cada SKU incorporat que s'exporti. Validar el tipus és independent d'acabar-ne els valors; només el principal no basta. Si el grup és buit o tots els seus SKU són retirats, es conserva però no s'exporta. `SourceIsPresent=0` exclou el SKU de la sortida i del control de valors; no exigeix valors per a SKU que ja no existeixen.

D330 explicita també ProductGroup.IsActive=1 en la lectura de variants del generador existent. No és un veto global nou de SynchronizationStatus, ni autoritza implementar un exportador/vista nous o modificar ara SQL legacy/font. Integració i proves pendents; grup actiu no significa grup validat o exportable.

Un SKU **desconegut** o candidat encara no incorporat no fa incomplet un grup anteriorment exportable: es continuen exportant els membres presents i ja validats, sense el candidat, mentre no n'estiguin aprovades la pertinença i les assignacions necessàries. Un SKU classificat que continua present però té un canvi de CLIGNE a l'origen pendent de revisió **continua exportant-se amb la darrera classificació validada de la còpia**. La consulta no fa servir directament les novetats de l'origen ni edicions manuals encara no confirmades. Una modificació no validada després de la primera aprovació no reemplaça l'estat anterior exportable.

El generador manual existent de Parkod treballa principalment amb l'original i llegirà `VARIANTS_PARKOD.dbo` per ParkodVariantCode, Type, Characteristics i NumericValue/TextValue. No replica assignacions a `parkod.dbo.PARKOD` ni és un procés nou de l'app. Lectura inicial coherent de les dades **de VARIANTS_PARKOD** en SNAPSHOT curt, tancat abans de generar/enviar fitxers; ALLOW_SNAPSHOT_ISOLATION ON només a la nova base. Les lectures originals queden fora d'aquest SNAPSHOT: protocol concret pendent, sense canviar parkod ni prometre coherència conjunta entre bases. No NOLOCK ni taula de snapshots. Només habilitacions IsValidated=1 amb codi i SKU elegibles. Pot coincidir amb recàrrega, conciliació o validació; cap indicador global 0 és veto, però el generador ho registra al seu log. Estat coherent de variants no vol dir font completament conciliada; controls originals i adaptació del lector extern pendents de validar.

Amb ValueKind, el lector ha de respectar la representació i el camp informat; no deduir forma numèrica només de Type diferent d'open_type. Aquesta adaptació encara no s'ha desenvolupat/provat i no redefineix el format legacy ni afegeix un exportador.

### 6.6 Identitat, sessions, reserva i exclusió batch

La identitat funcional dels tècnics prové de **comptes propis de l'app**, gestionats per un administrador de l'app (creació, desactivació i permisos), no de comptes Windows; Linux és una possibilitat futura, no l'entorn obligatori actual. **Un sol inici de sessió actiu per compte**: un segon intent es rebutja, sense expulsar el primer. La sessió caduca als **30 minuts d'inactivitat per defecte**, valor parametritzable. Cada usuari pot editar una sola pantalla i un únic grup a la vegada; la sessió pot portar una **reserva opcional** d'aquell ProductGroup. Un altre tècnic pot consultar-lo, però no editar-lo; exportació permesa. Caducar o tancar la sessió allibera la reserva i descarta els canvis manuals no validats. No es manté cap transacció SQL oberta durant la pantalla.

AppAccount/AppSession i els camps/claus de §3.12–3.13 estan aprovats. Cal materialitzar i provar login/reserva/caducitat, permisos administratius vigents i cursa amb batch; la reserva de pantalla no substitueix controls transaccionals. Argon2id autentica contrasenya; SHA-256 protegeix token. Només interacció real renova activitat; neteja per demanda, sense heartbeat ni planificador propi.

**Desplegament RDS i tokens (D194):** una instal·lació al servidor, compte Windows propi per persona i una instància d'app a cada sessió RDS/RemoteApp. Després de Windows, el tècnic s'identifica amb AppAccount; no s'ha acordat autenticació automàtica Windows. La instància conserva el token només en memòria mentre la sessió de l'app és vigent; SQL només en conserva el hash. Token i hash s'exclouen de contextos, snapshots, auditoria i logs. AppSessionId sol és identificador, no prova d'autenticació.

**Model intern de confiança confirmat (D196–D200):** connexió directa als procediments, sense servei central. Python verifica Argon2id i SQL confia en aquesta verificació per emetre sessió; després verifica token i deriva l'actor de la sessió, mai d'un autor lliure del formulari. Finalitat principal: atribuir/auditar treball ordinari. S'accepta explícitament que no resisteix manipulació intencionada del programa o de la credencial SQL comuna; ni token ni hash esperat de contrasenya proven per si sols una autenticació honesta. No es presenta com una frontera de seguretat demostrada. Credencials/connexió s'han de protegir segons desplegament, sense reobrir com a pendent la decisió de confiança. Login/signatures exactes a §6.13; permisos efectius i proves encara pendents.

Desconnectar Remote Desktop no equival a logout de l'app ni prova rollback d'una operació en curs. Windows obert no renova activitat; batch consulta sessions de l'app, no tots els usuaris Windows. Token criptogràfic de **32 bytes exactes**, @AppSessionId UNIQUEIDENTIFIER i @SessionToken VARBINARY(MAX) confirmats; SQL comprova longitud abans de qualsevol conversió, desa només SHA-256. Token només en memòria de la instància i cap secret a traces, contextos o auditoria.

La conciliació global (normalment tasca del **Planificador de tasques de Windows**, o llançament manual) **no comença si existeix cap sessió d'usuari activa**, no només una sessió editant; durant el batch no s'obren sessions noves. Si s'omet per aquest motiu, finalitza amb codi **0** i un log tècnic en anglès que diu inequívocament que **no s'ha executat** i per què, diferent d'èxit després de processar i de fallada real. L'app no inclou planificador ni reintents propis. Les consultes/exportacions als clients no es bloquegen per aquesta exclusió; l'aïllament coherent d'exportació es concreta a §6.5.

### 6.7 Càrrega externa, dos batch seqüencials i coordinació

**Frontera D361–D367, precisada D379:** primer `.bat` extern carrega **completament** `parkod.dbo.PARKOD` → `VARIANTS_PARKOD.dbo.Parkod`; segon `.bat` concilia còpia → ProductVariant/grups, completament o per marques. Planificador Windows en seqüència després de final correcte, sense planificador/reintents interns. Cap CSV, intermediari o recàrrega d'original exigits. Càrrega i manteniment de producció externs, no desenvolupats ni executats aquí. Incorporació inicial **de variants per conciliacions de marques**, amb conciliació completa programada desactivada fins acabar-la; això no permet carregar parcialment la còpia. Conciliació no és validació comercial. Capítol extern consolidat a Parkod.md §23.

**Pauta operativa D233, terminologia corregida per D367:** completa nocturna diària després de càrrega externa correcta; no buidar/recrear taules ni perdre classificacions. Incidència extraordinària nocturna: intervenció manual, suspenent/aturant els procediments el temps necessari. No demanar estabilitat tècnica universal de tots els escriptors de producció ni afegir un vigilant nocturn. Tasca interrompuda incompleta, COMMIT anteriors conservats, no èxit fictici. L'horari no substitueix disponibilitat/coordinació reals de la còpia ni el control atòmic de sessions de conciliació.

**Acord ja pres, recordat en conversa:** tasques planificades **en seqüència, primer recàrrega i després conciliació**. No és una nova decisió pendent ni cal escollir un altre mecanisme d'orquestració. Detallar/provar senyals, permisos i coordinació per materialitzar aquest circuit no reobre D233 ni autoritza modificar el carregador/font legacy des del projecte.

El procés extern manté SourceIsPresent i només els dos camps Parkod de SynchronizationStatus: indicador 0 abans de modificar la còpia, 1/data nova només després de verificar i publicar correctament la càrrega **completa**; fallada 0/data anterior. Cap recuperació parcial per marques que torni a posar l'indicador global a 1 (D379). La comprovació interna de càrrega/producció és externa; no traslladar a l'app els antics controls CSV/font. Senyals de disponibilitat, no prova automàtica de tots els escriptors originals. Contracte i permisos a integrar/provar, sense tocar producció.

Tres recursos lògics conservats a VARIANTS_PARKOD: **batch exclusiu**, **global batch/login** i **càrrega de còpia/batch**. D403 concreta exclusiu del carregador/compartit de revisions dependents sobre aquest últim recurs, sense quart recurs; noms i detalls executables pendents. Sessions caducades netejades; sessió vigent o altre batch ometen conciliació amb0/log NOT RUN. Durant conciliació no nous logins o expulsió/alliberament forçat. Connexió dedicada conserva coordinació sense transacció global; perdre-la atura execució, no desfà COMMIT previs.

D365: publicador extern i conciliació s'exclouen amb la mateixa coordinació, abans de modificar/llegir i durant cada execució, sense locks de taula/transacció global. Senyals publicats abans d'alliberar, participació externa efectiva necessària. D367: GUI possible durant càrrega/no veto global login; D403 concreta Shared curt/Exclusive carregador, detalls SQL/proves pendents, mai locks de formulari. Conciliació zero sessions vigents/còpia coherent-disponible-estable; no Single_User, control Windows/RDS o canvi original. Generador independent.

**Precisió D403:** publicador obligat a obtenir sp_getapplock exclusiu abans de marcar inici/tocar còpia, mantenir-lo per connexió durant tota la càrrega i publicar resultat abans d'alliberar. Lectors/confirmadors/rebutjos realment dependents obtenen compartit durant operació curta, no formulari; esquema §6.44.3 i obligació externa §6.35.5/Parkod.md §23.6. SQL coneix el resultat de la petició lògica, no dedueix TABLOCK/càrrega en curs. D365/D367/exclusió de conciliació intactes, materialització/proves pendents.

Cada invocació té log anglès amb hora UTC, invocació/inici efectiu, abast/marques, completed/not_run/failed, durada, motius i balanç. Omissió no és èxit de processament; parcials no canvien estat global variants. Canvis reals de l'app auditats; errors sense canvi/intactes/inici/final només al log. Còpia no disponible/coherent, lectura incompleta o infraestructura fallida no són èxit. Incidències individuals controlades poden permetre completar amb avisos; no atribuir al batch retirades externes. Fórmules afectades pel canvi de frontera a §6.39.6.

D389 retira l'antic motiu CPROD reservat i el seu correu urgent; cap substitut de notificació aprovat. Altres controls d'admissió/logs i no-intervenció a font intactes. El control de duplicats originals ja era extern D360, no es recupera com a nou correu periòdic. Notes SMTP històriques no creen un circuit nou ni autoritzen FailReconciliation després de Complete.

### 6.8 Context revisat i confirmació concurrent

**Base contractual D379 a adaptar, no formulari nou ja validat:** els blocs de grup amb CategoryCode/LineCode i formes G9/R5 següents es llegeixen amb D380/§6.42.4. Fonts/propietats del SKU i invariants de comparació es conserven. Contracte exacte futur E02, sense reconstruir originals històrics.

**Traçabilitat D326–D330:** G9/R5 eren les formes anteriors a D380. Ara grup complet7/reduït SKU–valor3 i associació reduïda5 segons §6.15.3/§6.45, sense IsActive afegit als reduïts. Activitat SQL abans de no-op/secret-història intactes/excepcions d'admin-catàleg-alliberaments conservades. §6.34 és matriu històrica de referència, no totes les seves formes actuals contrastades; cap filtre global de referències.

#### 6.8.1 Tres estats diferents

El backend conserva separadament **l'estat SQL revisat**, **els originals de la proposta** (§3.11.5) i **les correccions del formulari**. En confirmar, SQL rellegeix les dades rellevants sota bloqueig i les compara amb l'estat revisat, no amb el resultat desitjat. Una assignació revisada M es pot corregir a XL si encara és M; si SQL troba L, cal rollback i nova revisió, no sobreescriure L silenciosament. No es reescriu un valor compartit de catàleg per canviar la talla: es modifica l'assignació.

Després de comprovar el context, SQL valida les correccions i l'estat final i confirma dades/auditoria en una transacció curta. No es manté una transacció durant el formulari, ni s'afegeixen rowversion, versions, taules de snapshots o de propostes. Si es perd el context del backend, cal tornar a revisar. Un conflicte no es registra com una decisió humana confirmada; els errors sense canvi corresponen al log tècnic.

**Comparació confirmada (D160):** identitats, codis, números, indicadors i NULL han de coincidir; els textos revisats es comparen exactament, distingint accents i majúscules, no amb la igualtat CI_AI d'unicitat. Una correcció editorial pot conservar aprovacions ja existents i, alhora, invalidar el context d'una revisió que encara estava oberta. JSON segons contingut i contracte, no indentació; membres segons conjunts, no ordre visual. Altes/baixes de files o relacions rellevants també es detecten. No es compara tota la base ni es reconstrueixen les fonts originals.

Els abasts següents són els contextos de disseny confirmats, no defineixen per si sols signatures ni representacions JSON exactes. D241–D247 concreten els procediments de candidates de §6.8.2–6.8.3 a §6.15; la resta continua segons l'estat de cada contracte. La materialització haurà d'explicitar lectures, absències, comparacions i bloquejos sense ampliar-los silenciosament.

#### 6.8.2 Candidata SKU–valor (D161)

| Dades | Context esperat |
|---|---|
| ProductVariantValue | Fila completa, inclosos valor, grup, risc, validació i originals JSON. |
| SKU | Identitat, grup actual complet, LineCode i validació de pertinença. |
| ProductGroup | Identitat completa, LineCode i IsValidated. |
| VariantType | Identitat, Type, Characteristics, BrandCode i ValueKind. |
| VariantTypeValue implicats | Identitat, tipus i contingut del valor revisat i del valor final seleccionat, si ja existeix. |
| ProductGroupVariantType | Existència, IsValidated i ParkodVariantCode. |
| VARIANTS_PARKOD.dbo.Parkod | CLIGNE i SourceIsPresent del SKU. |

No bloquejar la decisió individual per un canvi d'un altre SKU que no afecti aquestes dependències. Aquest cas no inclou encara finalització de fase 3 ni una correcció de línia. Una operació només variants no exigeix consultar parkod.dbo.PARKOD; es mantenen les regles de font fiable quan sí que en depèn.

Entrada de selecció/alta i resposta concretades per D239–D240 a §6.10.1–6.10.2. Noms/signatures de confirmació/lectura/rebuig i propietat Parkod confirmats per D241–D244; representació completa confirmada posteriorment per D248 a §6.15.3, sense ampliar aquest abast. Reutilitzacions expressament confirmades per a assignació validada/absent a §6.23–6.24.

#### 6.8.3 Candidata grup–tipus de fase 2 (D162)

| Dades | Context esperat |
|---|---|
| ProductGroupVariantType | Fila completa, inclosos risc, validació, codi i originals JSON. |
| ProductGroup | Fila completa. |
| VariantType | Identitat, Type, Characteristics, BrandCode i ValueKind. |
| Membres del grup | Conjunt de SKU, identitat, grup, línia, validació de pertinença, SourceIsPresent i CLIGNE de la còpia. |

Incorporar o traslladar un membre durant la revisió és un canvi de context; reordenar visualment no. No s'exigeix crear candidates de valor abans d'aprovar fase 2. El rebuig amb eliminació comprova també les condicions de §3.11.4. Canvis en altres grups del mateix tipus no invaliden la revisió si no afecten la definició compartida o aquest context.

D245–D247 concreten aprovació, lectura i rebuig a §6.15.5–6.15.7. D246 confirma expressament el JSON de quatre blocs i l'estructura reduïda de membres, sense confondre'l amb els quatre blocs editorials o el context de substitució.

#### 6.8.4 Trasllat a grup existent (D163)

| Dades | Context esperat |
|---|---|
| SKU traslladat i còpia | ProductVariant complet; CLIGNE i SourceIsPresent de VARIANTS_PARKOD.dbo.Parkod. |
| Grups actual i de destí | Files completes dels dos grups. |
| Membres dels dos grups | Conjunts de SKU, identitat, pertinença, línia, presència i validació. |
| Associacions dels dos grups | Conjunts complets, inclosos validació i codis, per a habilitacions i principals. |
| Assignacions del SKU traslladat | Totes les files ProductVariantValue, sense perdre'n cap. |
| Catàlegs implicats | Definicions dels tipus i valors referenciats, inclòs ValueKind. |

La decisió comercial es pren sobre aquella composició; un canvi en els membres exigeix revisió, no la seva reordenació. Després de comparar, revalidar marca–categoria–línia, associacions, assignacions i principals; trasllat i rèpliques atòmics. La proposta no persisteix el trasllat abans de validar. Crear un grup o corregir un canvi de línia de dbo requereix el context addicional corresponent.

Signatures, forma exacta i resposta del trasllat ordinari concretades per D257–D260 a §6.18; rebuig no persistent sense trasllat a §6.20.4. No són el circuit de correcció de CLIGNE.

#### 6.8.5 Creació de grup amb SKU ja incorporats (D168)

| Dades existents | Context esperat |
|---|---|
| SKU implicats i còpia | ProductVariant complets; CLIGNE i SourceIsPresent de la còpia. |
| Grups actuals dels SKU abans del trasllat | Files completes i composició, amb línia, presència i validació dels membres. |
| Associacions d'aquests grups actuals | Conjunts complets, inclosos validació i codis. |
| Assignacions dels SKU implicats | Totes les files ProductVariantValue que s'han de preservar. |
| Catàlegs implicats | Tipus i valors referenciats, inclòs ValueKind, de les assignacions conservades i les associacions proposades. |

Els «grups actuals dels SKU abans del trasllat» poden ser grups propis provisionals o comercials validats. Només es traslladen els SKU aprovats, no tots els membres d'aquests grups; la resta roman i els grups que quedin buits es conserven. Això és diferent de l'alta inicial batch d'un SKU nou, que encara no té grup anterior.

No existeix encara una fila de grup de destí per comparar: el backend conserva proposta/configuració i SQL les valida. **L'avanç del comptador ProductGroupCounter no és un conflicte de revisió:** l'ID no s'ha reservat durant la pantalla; SQL assigna el següent disponible sota coordinació i en la mateixa transacció. No és una proposta corregida per aquest sol fet. Un canvi d'altre context rellevant exigeix nova revisió abans de crear/traslladar. Correcció de línia pel circuit específic §6.38: només entrada local revisada, sense relectura original ni ampliació implícita d'aquest contracte ordinari.

D261–D268 concreten la creació ordinària amb creador explícit, context de cinc propietats i decisions individuals a §6.19. SourceGroups són els grups actuals, potencialment diferents, no grups declarats equivalents ni destinacions noves ja persistides.

#### 6.8.6 Finalització de fase 3 de classificació (D169)

| Dades | Context esperat |
|---|---|
| ProductGroup | Fila completa, inclòs PrimaryVariantTypeId. |
| Membres | Conjunt complet de SKU, pertinences, línies, presència i validacions. |
| Associacions grup–tipus | Conjunt complet, amb validació, codis i originals. |
| Assignacions SKU–valor | Les necessàries per completar els tipus que es finalitzen, inclosa qualsevol absència. |
| Catàlegs implicats | Definicions dels tipus i valors, inclòs ValueKind. |

Canvis del conjunt de SKU presents o d'altres dades rellevants exigeixen revisar abans de confirmar. Els retirats segueixen exclosos de l'exigència de valors. **No es congela el pròxim ParkodVariantCode durant la revisió:** registre/blocs es consulten i el codi disponible es reserva atòmicament en confirmar; que una altra operació hagi consumit un codi no és un conflicte de revisió.

Després de comparar el context, comprovar valors requerits i principal segons les habilitacions finals. Reserva, assignació de codi i ajust necessari del principal formen la mateixa transacció curta, sense substituir una selecció tècnica vàlida ni triar arbitràriament entre diversos tipus. Qualsevol error desfà aquesta finalització. No és l'etapa 3 de desenvolupament amb IA, sinó la fase 3 del circuit de classificació.

D253–D256 concreten el circuit individual de §6.17. D255 exigeix almenys un SKU present amb pertinença validada per donar **un codi nou**; no revoca habilitacions/codis conservats si després el grup queda buit o només amb retirats.

#### 6.8.7 Reversions pels circuits ordinaris: acord ja existent

Una reversió no editorial es fa com una **nova operació del circuit ordinari**, amb context actual, revisió, validació i auditoria noves. Recuperar el valor anterior d'un SKU és una nova correcció d'assignació; tornar un SKU al grup anterior és un nou trasllat subjecte a la compatibilitat i als controls vigents. Historial i canvis posteriors d'altres usuaris no es sobreescriuen. No hi ha ordre genèrica «Desfer OperationId» ni restauració automàtica de snapshots; l'auditoria és referència de revisió, no una instrucció executable.

L'usuari ha recordat que aquest criteri ja estava acordat: no es numera com a decisió funcional nova ni es torna a sotmetre a validació. La reversió editorial té els procediments específics de §6.14.9. Resten la materialització i proves dels circuits, no l'aprovació d'un «Desfer» nou. La restricció d'administrador de §6.11.6 és per investigar resultats incerts i no es trasllada automàticament a les correccions ordinàries.

### 6.9 Creació conjunta de grup, associacions i trasllats

**Circuit confirmat (D164):** un grup nou pot necessitar SKU que ja tenen ProductVariantValue. No es traslladen a un destí sense les associacions compatibles necessàries ni s'eliminen valors per fer-ho possible.

1. Durant la revisió, preparar el grup nou, els membres i les associacions necessàries per conservar les assignacions.
2. Aprovar explícitament les associacions del destí; no hereten la validació dels grups actuals dels SKU.
3. En confirmar, comparar els contextos esperats i crear el grup, incorporar les associacions aprovades i traslladar els SKU amb els valors en **una mateixa transacció curta**, amb auditoria individual i OperationId comú.
4. Revalidar línies, marca/categoria, assignacions, associacions i principals finals; si no es pot deixar un estat coherent, rollback complet, sense crear el grup ni traslladar cap SKU.

No es persisteix un grup preparatori buit ni es trasllada abans de validar. Això no impedeix passos intermedis dins la transacció ni conservar després grups existents buits. Les fases lògiques requereixen revisió explícita, no aprovació automàtica ni herència de decisions. No es traslladen ni reciclen codis Parkod dels grups anteriors; qualsevol codi nou continua subjecte a la finalització de fase 3. JSON de grup/associacions abans i després, membres i contextos de rebuig es defineixen a §3.11. Les seqüències SQL amb FK immediates, cascades, reserves de sessió i permisos encara s'han de materialitzar i provar.

### 6.10 Reutilització i moment d'alta dels catàlegs

**Acords D173–D176:** VariantType i VariantTypeValue són catàlegs compartits. Reutilitzar una definició compatible de Type + Characteristics i el valor existent del mateix tipus; no crear tipus/valors per cada SKU ni duplicar-los en reprocessar. Si la parella existent és incompatible amb BrandCode o ValueKind necessaris, revisar el conflicte, no duplicar-la ni canviar-ne silenciosament el significat. Crear catàleg no valida associacions ni assignacions; els catàlegs no tenen IsValidated/ParkodVariantCode.

| Situació | Moment d'alta si falta el catàleg | Persistència i atomicitat |
|---|---|---|
| Proposta automàtica de tipus sobre grup existent | Fase 2: crear VariantType i obtenir ID real abans de crear ProductGroupVariantType candidata. | Mateixa transacció curta; candidata encara IsValidated=0/codi NULL. |
| Proposta automàtica de valor | Fase 3, només després d'aprovar l'associació: crear VariantTypeValue i candidata ProductVariantValue. | Mateixa transacció curta; valor real referenciat, sense validació humana implícita. |
| Proposta automàtica per grup encara no creat | Reutilitzar o crear VariantType compatible prèviament, amb auditoria, en una transacció curta. | Proposta de grup/associacions al backend, amb tipus real i ProductGroupId JSON null; no grup, associació persistent ni trasllat anticipats. Confirmació conjunta segons §6.9. |
| Correcció manual que requereix valor nou del mateix tipus | Durant edició només al backend; crear en validar juntament amb la correcció de l'assignació. | Auditoria d'alta de catàleg i de proposta corregida, OperationId comú, una transacció curta. |
| Correcció manual que requereix tipus nou | Seleccionar explícitament l'existent compatible o preparar Type, Characteristics, BrandCode i ValueKind al backend; crear tipus/associació en validar. | Alta i auditoria atòmiques amb la decisió; substitució de candidata original segons §6.11. No correcció editorial del tipus anterior. |
| Preparació manual independent d'un tipus global amb els seus valors | Preparació en memòria, creació conjunta només en confirmar, BrandCode fixat a NULL. Admet tipus sense valors. | D202–D205, §6.14: totes les altes/auditories atòmiques, sense grup, assignació, validació ni codi implícits. |
| Valors nous en un tipus encara global | Confirmació d'un lot no buit contra context actual de catàleg revisat. | D207, §6.14: només files noves, totes o cap, sense substituir la llista sencera ni auditar intactes. |

Les altes tenen IDs reals, camps obligatoris normalitzats i no buits, abast/representació coherents i les unicitats del diccionari; VariantTypeValue.Type replica el pare i exactament un dels dos camps de valor està informat. No es replica ValueKind al fill. SQL comprova les regles i coordina les altes amb els canvis de representació/abast.

Si es rebutja una candidata automàtica, es conserva el catàleg. En grup nou, rebuig o rollback posterior de creació/trasllats no desfà una alta de catàleg prèvia ja confirmada ni genera rebutjos de tipus no decidits. Tampoc autoritza assignacions noves abans de fase 2.

Cancel·lar una edició manual no crea catàleg ni modifica l'assignació/associació; la candidata automàtica persistent es conserva. En validar una alta manual, si ha aparegut un duplicat o hi ha conflicte concurrent, rebutjar la confirmació i exigir nova revisió: no substituir silenciosament el nou valor/tipus per un altre ID. Els originals conserven la proposta anterior; el resultat i AfterStateJson incorporen els IDs reals aprovats. El valor/tipus anterior i els seus usos compartits es preserven.

La preparació manual independent de tipus **globals** i valors ja està aprovada (§6.14); no continua pendent com a concepte ni necessita una proposta automàtica prèvia. No s'extrapola a altes independents de tipus exclusius ni a propostes rebutjades amb ID de catàleg absent/inventat: aquests casos no detallats continuen a §7.

#### 6.10.1 Entrada transitòria de selecció o alta d'un valor SKU

**D239:** per indicar el valor desitjat en confirmar una correcció SKU–valor s'aproven aquests arguments, sense canviar el tipus al qual pertany l'assignació:

| Via | @SelectedVariantTypeValueId INT | @NewValueJson NVARCHAR(MAX) |
|---|---|---|
| Valor de catàleg existent del mateix tipus | ID real informat | SQL NULL |
| Valor nou del mateix tipus | SQL NULL | Objecte JSON informat |

Exactament una via: rebutjar totes dues informades o totes dues SQL NULL. NewValueJson és **un objecte**, no l'array ValuesJson: exactament `NumericValue` i `TextValue`, totes dues propietats obligatòries, una informada segons VariantType.ValueKind i l'altra JSON null. Sense IDs inventats ni rèpliques Type/ValueKind; noms exactes i duplicats/propietats desconegudes rebutjats segons controls JSON ja acordats. Exemple fictici d'un valor textual nou:

```json
{"NumericValue": null, "TextValue": "XL"}
```

S'aplica **expressament** la gramàtica decimal D236 de §6.14.2 a NumericValue de NewValueJson: número JSON sense cometes/+/coma/exponents, representació exacta DECIMAL(18,3), decimals posteriors a la tercera només zeros; zero/negatius no rebutjats per si sols. TextValue conserva normalització, límits, XOR segons el pare i unicitat de §3.5; no és correcció editorial d'un valor compartit existent.

Els dos arguments són transitoris: la nul·litat dels paràmetres no amplia cap columna, PK/FK, OriginalProposalJson o clau d'auditoria. El context SQL revisat continua separat del valor desitjat (§6.8.2), i els originals no es reescriuen. En la via nova, SQL genera l'ID real i crea el valor en confirmar; l'alta de catàleg, la confirmació de l'assignació i les auditories són atòmiques amb OperationId comú, segons el circuit ja acordat. No es duplica una assignació existent. Col·lisió concurrent exigeix revisió, no reutilització silenciosa. D241 confirma posteriorment nom/signatura/defaults de confirmació (§6.15.1); no aprova nous casos de proposta sense ID.

#### 6.10.2 Resposta de confirmació d'una candidata SKU–valor

**D240:** quan una candidata SKU–valor s'accepta o es corregeix, la confirmació retorna **dos conjunts**, exclusivament després del COMMIT:

| Ordre | Files | Contingut exacte |
|---|---|---|
| 1 | Una | OperationId UNIQUEIDENTIFIER i ProductVariantValue complet resultant de nou camps: ProductVariantId, VariantTypeId, ProductGroupId, BrandCode, VariantTypeValueId, EstimatedRiskPercent, IsValidated, OriginalSourcesJson, OriginalProposalJson. |
| 2 | Una | VariantTypeValue final complet, existent o nou: VariantTypeValueId, VariantTypeId, Type, NumericValue, TextValue. |

Tipus, nul·litat, grafia i camps segons §3.7/§3.5; no columnes de base noves. El segon conjunt retorna l'ID real i el contingut definitiu del valor, inclosa la normalització efectuada per SQL. Capturar tots dos resultats **dins de l'operació**, no rellegir-los després del COMMIT quan una altra sessió podria haver-los canviat. L'emissió d'èxit és sempre posterior al COMMIT; una resposta incompleta aplica el circuit manual de resultat incert de §6.11.6.

Aquesta resposta correspon a l'aprovació/correcció de candidata individual de §6.8.2: **no finalitza automàticament fase 3 ni assigna ParkodVariantCode**. No substitueix la resposta A → B de §6.11.6, no modifica els procediments editorials/globals i no s'extrapola al rebuig, als no-op o a altres circuits. Nom/signatura complets confirmats per D241 a §6.15.1; implementació/proves encara pendents.

### 6.11 Substitució expressa d'una associació grup–tipus A per B

**Contracte adaptat D380/D381, línia coneguda D404:** signatures marca–grup, grup7/associacions8/assignacions9 i resposta codi5. Set blocs i decisions individuals D184–D190 conservats. D404 permet el circuit complet amb discrepància de línia coneguda, incloses les retirades/rebutjos expressos d'assignacions d'A i retirada d'A, sense modificar LineCode/grup/validació de pertinença o resoldre la incidència. Cada retire/reject conserva les seves condicions; valors requerits de B, principal, permisos/context/auditoria atòmica i D396/D402–D403 intactes. D392 continua exigint línies resoltes dels requerits abans de codi NOU; B amb codi propi el conserva. No permissió universal de retirada ni circuit reduït de §6.27 (§6.45.1).

**Acords D177–D193:** A i B són associacions de tipus diferents del mateix grup existent. La substitució requereix decisió humana expressa; no es dedueix de coexistència, noms semblants o selecció del principal. Si les dues propostes són bones i complementàries, conservar/aprovar totes dues amb les seves decisions, valors i codis propis; quan hi ha diverses habilitacions finals, selecció tècnica del principal.

#### 6.11.1 Casos i auditories de substitució

| Estat revisat | Tractament confirmat | Auditoria |
|---|---|---|
| A candidata IsValidated=0, codi NULL i sense assignacions; B encara no associada | Eliminar A i crear B aprovada a fase 2, codi NULL. B conserva risc i JSON originals d'A sense reescriure'ls amb el nou tipus. | A: proposal_decision/proposal_review/corrected, clau d'A, Before complet, After SQL NULL, resultat amb B. B: confirmed_change/create, Before SQL NULL i After complet, sense segona decisió de la mateixa proposta. Alta del tipus B si cal, auditada amb OperationId comú. |
| A candidata admissible; B del mateix grup ja aprovada i revisada explícitament | Eliminar A; conservar B intacta, amb risc/originals/codi existents. | Només decisió corrected d'A, Before complet, After SQL NULL, resultat B. No entrada per B intacta ni còpia d'originals sobre B. Si no tenia codi, continua sense codi. |
| A i B candidates IsValidated=0, codi NULL i sense assignacions | Revisar explícitament ambdós originals; eliminar A i aprovar B a fase 2 si s'accepta tal com estava proposada. | A corrected, Before complet/After SQL NULL/resultat B; B accepted, Before/After complets, originals propis. Dues decisions, OperationId comú. Sense aprovació explícita de B no hi ha substitució. |
| A aprovada a fase 2, codi NULL i sense assignacions; B candidata | Retirada expressa d'A i aprovació explícita de B; no rebuig de candidata A ni eliminació per la sola aprovació de B. | A confirmed_change/retire, Before complet/After SQL NULL; historial d'aprovació preservat. B proposal_decision/proposal_review/accepted si no corregida, originals propis; OperationId comú. B encara sense codi. |
| A amb qualsevol assignació | Preparar i aprovar B a fase 2, revisar-ne els valors propis; conservar A i assignacions fins a transició final. | No retirada anticipada ni còpia/conversió/validació automàtica d'A com a B. Transició final i auditories individuals segons apartats següents. |

L'auditoria precedeix cada eliminació i comparteix transacció amb els canvis. Catàlegs A/B i totes les auditories prèvies es conserven. En B nova, els IDs dels JSON originals d'A són evidència històrica: no s'exigeix que es reescriguin per coincidir amb la fila final B. Les claus i resultats generats per SQL identifiquen els objectes reals corresponents. En B existent no es fusionen ni sobreescriuen originals/riscos. Qualsevol canvi rellevant de B després de revisar-la exigeix nova revisió.

**Retirada d'assignacions d'A (D182):** decisió individual explícita per cada ProductVariantValue, encara que es confirmi un lot. Inclou pendents, validades i les de SKU SourceIsPresent=0; no s'eliminen pel sol fet d'estar retirats. Es retira la relació, no el VariantTypeValue compartit. Si alguna s'ha de conservar com a fila, bloquejar la retirada completa d'A. Sense DELETE CASCADE ni excepcions de FK.

- Retirada funcional: confirmed_change/retire, DecisionOutcome i camps de proposta de l'esdeveniment SQL NULL; Before complet amb risc/JSON originals de la fila, After SQL NULL.
- Rebuig exprés de proposta pendent: proposal_decision/proposal_review/rejected, original disponible, una sola entrada segons §3.11.4.
- No convertir automàticament retirada en rejected: una substitució funcional no prova que la proposta original fos errònia, ni reescriu una aprovació històrica.

**Transició final (D183):** revalidar context revisat, sessió/reserva, decisions sobre totes les assignacions d'A, aprovació de B i valors requerits validats. En una mateixa transacció curta coordinar finalització de B, codi, principal, retirades i auditoria individual amb OperationId comú:

1. B conserva el codi propi si ja en té, o en reserva/rep un de nou només amb les condicions de fase 3. Mai transferir/reciclar el d'A; la reserva d'A continua al registre permanent.
2. Calcular les habilitacions finals: un sol tipus → aquell ID; múltiples → conservar tria tècnica encara vàlida o exigir tria explícita entre els restants si A era principal. La seqüència SQL ha de deixar de referenciar A abans d'eliminar-la quan la FK l'apunti.
3. Retirar les assignacions d'A decidides individualment i l'associació A, amb auditories abans dels DELETE i comprovacions finals de coherència.
4. Qualsevol error amb rollback, inclòs esgotament de codis, desfà tota la transició: A es conserva; les preparacions de B ja confirmades abans no desapareixen. Les lectures SNAPSHOT observen estat coherent anterior o posterior, no substitució parcial.

És una seqüència funcional, no un script SQL provat ni una excepció a l'ordre de bloquejos de §6.2. La regla de rollback no permet afirmar que una operació s'hagi desfet si se n'ha perdut la resposta final (§6.11.6).

#### 6.11.2 Procediments i contingut d'entrada

| Nom confirmat | Responsabilitat |
|---|---|
| dbo.GetGroupVariantTypeReplacementContext | A VARIANTS_PARKOD, verificar sessió/reserva/àmbit, llegir context coherent amb SNAPSHOT curt i retornar-lo; tancar transacció abans de revisar. |
| dbo.ConfirmGroupVariantTypeReplacement | A VARIANTS_PARKOD, verificar sessió, rellegir/comparar context actual sota bloqueig, validar decisions i confirmar transició/auditoria atòmiques; resposta d'èxit només després del COMMIT. |

Només cobreixen substitució completa en un grup existent. La lectura no crea catàlegs/grups/candidates ni reserva codis. Cap dels dos executa trasllats de SKU, correccions de línia, canvis globals de catàlegs o exportacions. Preparació de B per circuits ja acordats; no substitueixen els contractes reduïts d'altres operacions.

El contracte de transició final rep A/B amb IDs reals i B preparada prèviament. Això no força una alta manual anticipada per obtenir-los: les altes/correccions conjuntes de §6.10 i els casos parcials de §6.11.1 mantenen els seus circuits atòmics. D291–D294 concreten la correcció de candidata a §6.26 i D295–D296 el cas A ja aprovada sense codi/assignacions amb B candidata a §6.27; els altres procediments encara no coberts continuen pendents.

Contingut confirmat d'entrada (D184), precisat per D234–D235. **Validat:** A = `@VariantTypeIdToReplace INT`, B = `@ReplacementVariantTypeId INT` als dos procediments; lectura per substitució concreta amb A/B ja seleccionats, sense retirar A ni aprovar B. A no ha de ser el principal. Es descarta el nom provisional `@RetiredVariantTypeId`.

| Contingut | Representació acordada |
|---|---|
| Sessió autenticada | @AppSessionId UNIQUEIDENTIFIER i @SessionToken VARBINARY(MAX), token de 32 bytes exactes, segons §6.13; l'ID sol no basta. |
| Grup complet, IDs reals d'A/B i eventual selecció nova del principal | Paràmetres SQL tipats segons camps existents. |
| Context SQL revisat | NVARCHAR(MAX), objecte JSON de §6.11.4. Separat d'originals i resultat desitjat. |
| Decisions individuals de totes les assignacions revisades d'A | NVARCHAR(MAX), array JSON de §6.11.3. |

Els JSON són peticions transitòries, no OriginalProposalJson/DecisionResultJson ni columnes, taules o versions noves. SQL valida estructura, propietats exactes/duplicades, tipus, identitats i referències. La llista d'A ha de coincidir exactament amb la revisada; alta/baixa/canvi rellevant exigeix rollback i nova revisió, no ampliació automàtica de la retirada. SQL genera codi quan pertoqui, OperationId, claus, snapshots i resultats des de les files reals verificades.

**Paràmetre del principal validat (D235):** `@SelectedPrimaryVariantTypeId INT = NULL`. NULL vol dir «sense selecció nova», mai esborrar el principal. Aplicació segons les habilitacions finals IsValidated=1/codi no nul:

| Estat final / entrada | Resultat |
|---|---|
| Un únic tipus habilitat, sense selecció nova o amb aquell ID | Aquell ID és principal obligatori. |
| Diversos tipus, NULL i principal actual encara vàlid | Conservar el principal actual. |
| Diversos tipus, NULL i principal actual absent o invàlid | Rebutjar i exigir selecció explícita; cap tria arbitrària. |
| ID informat i habilitat en l'estat final | Aplicar la selecció humana explícita. |
| ID informat no habilitat en l'estat final | Rebutjar tota la transició, sense canvis parcials. |

B no és principal automàticament pel fet de substituir A. En la substitució completa B queda habilitada, per tant el principal final no pot ser NULL encara que el paràmetre ho sigui.

**Signatures D237 adaptades directament per D380:** retirar únicament @CategoryCode als dos procediments; marca NVARCHAR(MAX), grup INT, A/B/context/decisions/principal i defaults conserven tipus/ordre. D237 continua sent l'acord històric, no una signatura nova per semblança. No DDL implementat o desplegament autoritzat:

```text
dbo.GetGroupVariantTypeReplacementContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT
)

dbo.ConfirmGroupVariantTypeReplacement(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @AssignmentDecisionsJson NVARCHAR(MAX),
    @SelectedPrimaryVariantTypeId INT = NULL
)
```

**Resposta de lectura:** una fila `ContextJson NVARCHAR(MAX)` amb els set blocs de §6.11.4. BrandCode exigeix longitud exacta3 abans de convertir a NVARCHAR(3), sense retallar/normalitzar o ampliar columna; ProductGroupId positiu. Cada SKU conserva CategoryCode i LineCode propis. Resposta post-COMMIT de §6.11.6 conservada amb codiNVARCHAR(5) D381; materialització/proves pendents, no nova decisió sobre noms o resultsets.

OPENJSON s'executarà a VARIANTS_PARKOD amb compatibilitat 140 aprovada; la base local existeix però està a 150 sense model. Cal autorització separada per aplicar/verificar la configuració i provar el parser compatible amb SQL Server 2017 Express. `parkod` original conserva configuració; la còpia de proves observada a 150 tampoc rep canvis. Controls executables JSON pendents.

#### 6.11.3 JSON de decisions sobre assignacions d'A

Exemple fictici:

```json
[
  {"ProductVariantId": 1001, "Decision": "retire"},
  {"ProductVariantId": 1002, "Decision": "reject"}
]
```

- Només aquestes dues propietats, obligatòries, amb noms exactes; Decision és exclusivament retire/reject.
- Una entrada per cada assignació d'A revisada, incloses les de SKU retirats. Cap ProductVariantId repetit, encara amb decisió idèntica; ordre irrellevant.
- VariantTypeId no es repeteix: A ja està identificada al paràmetre tipat. El valor anterior es contrasta amb el context i la fila SQL, no s'imposa amb aquest array.
- retire és retirada funcional expressa, pendent o validada. reject exigeix IsValidated=0 i proposta original disponible; si no és admissible, rebutjar la petició, no transformar-la en retire.
- [] només si A no té assignacions. No deduir decisions d'IsValidated o SourceIsPresent.

#### 6.11.4 JSON de context revisat de substitució

Aquest context complet s'utilitza per confirmar la substitució A → B, no per cada SKU del batch, una exportació, una alta simple de catàleg o una validació individual amb context més petit. Té exactament aquests set blocs obligatoris (D186–D189):

| Propietat | Forma i abast |
|---|---|
| ProductGroup | Objecte amb fila completa del grup, inclòs PrimaryVariantTypeId. |
| ProductVariants | Array de tots els membres reals, també retirats o amb pertinença pendent; estructura concreta inferior. |
| ProductGroupVariantTypes | Array de totes les associacions del grup, files completes amb codi, validació, risc i originals. |
| VariantTypes | Array amb files completes d'A, B i dels altres tipus que quedaran finalment habilitats, necessaris per comprovar el principal. |
| VariantTypeValues | Array amb files completes dels valors referenciats per les assignacions d'A i les requerides de B incloses en aquest context; cada ID una sola vegada. |
| RetiredTypeAssignments | Array amb totes les files completes ProductVariantValue d'A, incloses pendents, validades i de SKU retirats. |
| ReplacementTypeAssignments | Array amb una entrada per SKU que requereix valor de B: ProductVariantId i ProductVariantValue complet, o null si falta. |

**Membres — ProductVariants:** exactament les propietats de l'exemple fictici següent, totes obligatòries:

```json
{
  "ProductVariantId": 1001,
  "BrandCode": "ABC",
  "CategoryCode": "01",
  "ProductCode": "001",
  "ProductGroupId": 7,
  "LineCode": "01",
  "IsValidated": true,
  "Parkod": {
    "CLIGNE": "01",
    "SourceIsPresent": true
  }
}
```

Els camps exteriors provenen de ProductVariant; els dos interiors de VARIANTS_PARKOD.dbo.Parkod, identificada pels tres codis del SKU. No propietats addicionals ni membres duplicats. EstimatedRiskPercent de pertinença queda expressament fora: la substitució no la modifica ni reavalua, i el risc es conserva intacte a SQL. Una alta, baixa o canvi dels camps inclosos exigeix revisió; ordre irrellevant.

D363/D380 distingeixen ProductVariant.LineCode, classificació pròpia del SKU, de Parkod.CLIGNE, entrada local més recent; ProductGroup no té LineCode. Conservar ambdós camps del membre, sense sobreescriure'ls o forçar igualtat. D404 permet discrepància coneguda en aquesta substitució, però no la corregeix ni valida la pertinença; D392 continua exigint resolució dels requerits abans de codi nou. No lectura original o còpia escrita.

**Assignació B absent — ReplacementTypeAssignments:** exemple fictici d'una entrada sense fila revisada:

```json
{
  "ProductVariantId": 1001,
  "ProductVariantValue": null
}
```

Si la fila existeix, incloure-la completa encara IsValidated=0; pendent no és absent. ProductVariantValue null és obligatori quan falta: ometre la propietat o enviar {} és invàlid. Una fila inclosa ha de correspondre al mateix SKU exterior i al tipus B identificat pel paràmetre. Cap SKU repetit; ordre irrellevant. Retirats exclosos de l'exigència de valors de B; l'abast dels requerits segueix les regles de fase 3/exportació, no s'amplia a SKU desconeguts o candidats no incorporats.

Registrar una absència no autoritza a finalitzar: qualsevol valor requerit absent o encara no validat rebutja la transició, sense completar-lo automàticament. El null indica absència de tota la fila, no permet IDs/FK nuls dins d'una assignació existent.

**Regles comunes de context:**

- Files completes amb tots els camps reals del diccionari; null explícit quan correspongui. No inventar rèpliques/propietats. Les columnes JSON s'inclouen com a objectes/arrays imbricats, no strings escapats; es distingeix SQL NULL de [].
- ValueKind és camp físic només de VariantType, encara que també consti dins de JSON originals històrics. No carregar altres grups ni tot el catàleg.
- Referències/identitats coherents i conjunts sense duplicats; comparar altes/baixes i contingut amb §6.8.1, sense dependre de l'ordre. No congelar pròxim codi disponible.
- Aquest és l'estat esperat del backend, no snapshots d'auditoria imposats per GUI. SQL genera l'auditoria des de les files actuals verificades. Cap propietat transitòria es converteix en camp SQL.

#### 6.11.5 Lectura inicial coherent i confirmació

**SNAPSHOT curt confirmat (D190):** verificar sessió i controls de reserva, obtenir tots els blocs d'un mateix estat de variants en una transacció SNAPSHOT curta i tancar-la abans de mostrar la revisió. El backend conserva aquest context separat de les edicions. No auditoria de lectura, transacció de formulari ni taules de versions/snapshots persistents.

En confirmar, nova transacció curta sobre estat actual sota els bloquejos acordats: comparar el context, validar decisions/estat final i confirmar. No reutilitzar l'antic SNAPSHOT per validar les escriptures. Configuració ALLOW_SNAPSHOT_ISOLATION, permisos i impacte s'han de provar; aquesta ampliació al context no modifica l'acord independent del generador Parkod.

#### 6.11.6 Resultat, errors i resposta d'èxit

| Situació | Tractament confirmat |
|---|---|
| Error abans del COMMIT amb rollback executat | Transició no confirmada; cap fila d'èxit. |
| COMMIT i resposta completa rebuda | Èxit confirmat. |
| Timeout, pèrdua de connexió o resposta incompleta sense resultat final fiable | Resultat potencialment desconegut; SQL podria haver confirmat abans de perdre la resposta. |

En resultat incert (D191), no repetir automàticament, afirmar rollback ni registrar rebuig humà. Informar de la incidència tècnica i impedir confirmar de nou amb context antic. És estat transitori de petició, no columna/estat persistent nou. La resposta perduda podria no haver lliurat OperationId; no es promet identificació unívoca garantida ni idempotència de reenviament.

**Recuperació manual confirmada (D238):** substitueix la proposta intermèdia de comprovació automàtica, que no és un circuit vigent:

1. L'usuari rep avís de resultat desconegut; l'app no reenvia l'operació ni intenta reconstruir-ne automàticament el resultat.
2. Només un **administrador de l'aplicació amb IsAdmin=1 vigent**, amb els controls de sessió existents, consulta l'auditoria per investigar-lo. Pot revisar operacions d'altres usuaris, no només les seves. No és la identitat SQL administrativa de bootstrap/recuperació de compte ni s'afegeix un model de permisos nou.
3. Consulta per OperationId si es coneix; en la substitució sense aquest ID, pel grup complet i A/B afectats. Contrasta les operacions registrades amb l'estat actual. Trobar simplement l'estat desitjat no basta per atribuir-lo inequívocament a aquella petició; si no s'aclareix, la incidència continua pendent de revisió tècnica.
4. **Absència de registre no prova rollback:** la petició original encara podria estar executant-se. La consulta no modifica classificacions, no desfà dades ni registra una decisió humana fictícia.

Circuit deliberadament simple: sense taules/camps/identificadors nous de petició, reconstrucció automàtica o garanties addicionals d'identificació. No aplicar la restricció admin a les correccions ordinàries ni a les reversions pels circuits normals (§6.8.7). Nom/signatura i dos conjunts de consulta confirmats posteriorment per D249–D252 a §6.16.2–6.16.3; execució, permisos i proves encara pendents.

**Resposta mínima d'èxit (D192):** una única fila, exclusivament després del COMMIT:

| Camp de resultat | Tipus | Contingut |
|---|---|---|
| OperationId | UNIQUEIDENTIFIER | Generat per SQL, comú a les auditories de la transició. |
| ParkodVariantCode | NVARCHAR(5) | Codi final de B, nou o existent conservat; D381. |
| PrimaryVariantTypeId | INT | Principal final del grup; pot ser un altre tipus habilitat si la tria és vàlida. |

Tots tres han d'estar informats en aquesta substitució completa: B queda finalment habilitada i hi ha principal obligatori. No secrets ni tots els snapshots a la resposta. No columnes noves ni exportació Parkod. Una resposta incompleta segueix el circuit de resultat incert, no es considera èxit per haver rebut una part.

### 6.12 SQL estàndard i dependències de SQL Server

**Criteri D195:** SQL tan estàndard com sigui possible, sense prometre portabilitat ANSI/ISO completa ni substituir mecanismes aprovats. Python conserva GUI, flux de revisió i preparació de propostes/contextos; SQL conserva integritat, controls compartits de sessió/permisos/reserva, coordinació concurrent i confirmació atòmica de dades/auditoria. No traslladar garanties crítiques a Python només per fer aparentment portable el SQL.

Prioritzar operacions relacionals i restriccions declaratives, procediments acotats, transaccions curtes i responsabilitat clara de COMMIT/ROLLBACK i errors. Evitar SQL dinàmic, complexitat innecessària i duplicació dispersa de regles.

**Comentaris al punt d'ús, en anglès:** identificar cada instrucció/bloc o dependència de comportament específica de SQL Server, el motiu i la garantia que caldria preservar en substituir-la. No només paraules clau: també collations, tipus/sintaxi concrets, índexs i semàntica d'aïllament. Exemple orientatiu abans de l'ús acordat de sp_getapplock, no codi executable:

```sql
-- SQL Server-specific (T-SQL): application-level locking.
-- Purpose: serialize ProductGroupId allocation within one brand.
-- Portability: any replacement must preserve atomic allocation.
```

Inventari inicial de dependències de disseny, a contrastar amb els punts d'ús del futur DDL/procediments:

| Característica específica | Ús previst | Justificació i estat |
|---|---|---|
| sys.sp_getapplock i propietat de bloquejos d'aplicació SQL Server | Comptador, tipus/SKU/grup/codis/execucions; D403 carregador exclusiu per connexió durant càrrega i revisions dependents compartides curtes (§6.7/§6.35.5/§6.44.3). | Mateix recurs a VARIANTS_PARKOD/cooperació externa obligatòria, no lock físic deliberat de taula o garantia sobre escriptors no cooperatius. Protecció abans de fixar estat llegit/comprovar indicador, no formulari; recurs/àmbit/esperes/ordre/propietat i alliberament executables/proves pendents. Comentaris anglesos al futur punt d'ús. |
| SNAPSHOT de SQL Server / ALLOW_SNAPSHOT_ISOLATION | Dades de VARIANTS_PARKOD per generador (§6.5), substitució (§6.11.5), catàleg/editorials (§6.14), candidates (§6.15), lectors §6.16–6.27 i lectures administratives/contextos §6.28–6.34; dues columnes editorials D328 del mateix estat. | ON aprovat només a la nova base; READ_COMMITTED_SNAPSHOT OFF. Lectures curtes/tancades abans de revisar, confirmació en transacció actual nova (§8), cap transacció global del lot D322. No incloure original SNAPSHOT OFF ni noms font presumptament coherents; permisos/impacte/proves pendents. |
| Latin1_General_100_CI_AI_SC i controls SQL exactes de bytes/longitud | Textos normalitzats i rèplica Type (§3.8). | Unicitat CI_AI sense perdre grafia; controls no equivalents a igualtat CI_AI. No canviar collation general ni legacy. |
| Collations French_CI_AS / SQL_Latin1_General_CP1_CI_AS i COLLATE | French_CI_AS general/còpia/codis interns; comparacions amb font local diferent (§1.1/§5.5). | D232 manté producció; columnes textuals referenciades per FK han de coincidir en collation encara amb ASCII. Comparació entre bases pot requerir COLLATE explícit; no alterar font, no confondre collation amb normalització ni perdre grafia NVARCHAR. Implementació/impacte pendents. |
| Ordre NVARCHAR amb French_CI_AS en MAX/índexs | D382/D397: màxim del registre permanent per marca, després successor; no MAX d'IDs de grup. | Mantenir French_CI_AS ja aprovada amb codis5 ASCII majúsculs validats, sense afegir Latin1_General_100_BIN2 a l'expressió. Verificar ordre coherent amb alfabet0–9/A–N/P–Z i pla d'accés en SQL2017; ni ordre ni rendiment provats. MAX no exigeix necessàriament sort complet ni protegeix concurrència. Comentari anglès al futur punt d'ús; cap collation física/font/configuració modificades (§6.43.3). |
| Índexs únics filtrats de SQL Server | Unicitats de valors no NULL i reserva opcional completa d'AppSession. | Excloure els NULL segons regles acordades; DDL i proves pendents. |
| Sintaxi IDENTITY(1,1), tipus SQL Server UNIQUEIDENTIFIER/DATETIME2/BIT/NVARCHAR(MAX) i SYSUTCDATETIME() | Identitats, OperationId/sessions/temps UTC, indicadors inclòs ProductGroup.IsActive DEFAULT(1) i signatura Unicode de NormalizeWhitespace. | Conservar generació, precisió, nul·litat, defaults i text acordats; tipus ja utilitzats, no dependència de 2019 ni justificació per alterar camps. Documentar al futur punt d'ús la sintaxi/comportament i garantia equivalent, sense declarar-los portables. |
| ISJSON i OPENJSON | Contractes JSON persistents/transitoris i validació SQL a VARIANTS_PARKOD, inclòs UnincorporatedSkuIncidentsJson de CompleteReconciliation (§6.39.7, D373). | ISJSON sol no valida array/forma exacta/duplicats ni cobertura individual de claus. OPENJSON disponible amb nivell 140 aprovat (mínim 130), cap opció exclusiva de 2019 o canvi a parkod/100. Parser/controls executables pendents; el JSON es rep com a paràmetre, no com a estat persistent o valor SESSION_CONTEXT MAX. |
| Sintaxi de procediments, gestió d'errors i transaccions T-SQL | Procediments protegits/§8.5/resposta post-COMMIT; D402 error SQL d'indisponibilitat identificable sense dependre del text (§6.44.2). | Dades/auditoria atòmiques, captura interna/després del COMMIT efectiu; COMMIT intern no tanca transacció real encara oberta. Sense resultset de disponibilitat o signatures noves, numeració/transport/sintaxi exacta d'error pendents. No wrappers de formulari o transaccions ambientals aprovats, D238 conservat; patrons/proves pendents. |
| Noms de tres parts i permisos/lectures entre bases SQL Server | Fonts parkod.dbo en lectura; tots els objectes nous a VARIANTS_PARKOD.dbo. | Cap FK entre bases ni canvi de permisos/configuració a parkod. Accés existent i protocol d'aïllament s'han de provar; no aprovació implícita de TRUSTWORTHY, DB_CHAINING o altres mecanismes. |
| VARBINARY(MAX), DATALENGTH i SHA-256 SQL Server | @SessionToken de 32 bytes, longitud verificada abans de convertir; SessionTokenHash de 32 bytes. | No confondre token/hash; disseny confirmat, implementació/proves pendents. Cap secret a logs/contextos/auditoria. |
| SESSION_CONTEXT i sp_set_session_context de SQL Server (disponibles al destí 2017) | Cicle Begin/Complete/FailReconciliation: tipus de llançament, completa/parcial i recomptes inicials petits de la connexió dedicada (§6.39). | Dependència aprovada D356, sense taula/camp/RunId o HASH d'abast. Valors <=8 KB; no desar directament un JSON MAX llarg, cap secret. Neteja només en tancament segur; connexió perduda no implica rollback dels COMMIT anteriors. Controls de propietat de bloquejos independents, claus/tipus/neteja executables pendents. Comentar en anglès al punt d'ús; substitució ha de preservar vinculació al mateix inici admès sense transacció llarga. |
| Cascada FK ON UPDATE i comparació CI_AI versus bytes exactes | Rèpliques Type i grup (§4/§6.14). | Comprovar propagació exacta de majúscules/accents i auditoria de cada fila realment modificada; no confiar sense prova en una cascada sobre clau CI_AI. Rollback si no es garanteix. |

Aquest inventari no aprova noves dependències ni garanteix que qualsevol SQL sense marca sigui portable. Es mantindrà amb el codi; els arguments són a DECISIONS.md i la convenció permanent a AGENTS.md. Els scripts SQL legacy es preserven: no s'hi afegeixen comentaris ni canvis en aquesta consolidació.

### 6.13 Contractes de sessió i login confirmats

**D196–D200; ubicació de tots els procediments: VARIANTS_PARKOD.dbo.** Són contractes de disseny, no SQL implementat ni provat. No camps nous d'AppAccount/AppSession.

#### 6.13.1 Paràmetres comuns i límit de confiança

Els procediments autenticats reben `@AppSessionId UNIQUEIDENTIFIER` i `@SessionToken VARBINARY(MAX)`. Token criptogràfic de **32 bytes exactes**, conservat només en memòria de la instància; SQL comprova la longitud exacta abans de convertir i només desa SHA-256 a SessionTokenHash. Rebutjar longituds incorrectes, mai truncar/omplir silenciosament. SQL verifica sessió/token/caducitat, permisos vigents i reserva quan l'operació la requereix; actor derivat de la sessió, no paràmetre lliure d'autor. PasswordHash, hash esperat, token i hash de token no es registren en logs, auditoria, snapshots o contextos de revisió.

El login no té encara sessió: dos passos SQL amb verificació **Argon2id en Python entremig**, sense transacció oberta durant el càlcul. SQL confia en la verificació de l'app segons el model intern acceptat (§6.6). La coincidència del hash esperat detecta un restabliment concurrent; no és prova autònoma que el client hagi verificat una contrasenya. No servei central ni autenticació Windows automàtica. No prometre resistència a manipulació intencionada de l'app/credencial comuna.

#### 6.13.2 GetAppAccountAuthenticationData

`dbo.GetAppAccountAuthenticationData(@LoginName NVARCHAR(MAX))`

- Lectura inicial limitada d'AppAccount actiu, amb les regles de LoginName del diccionari; zero o una fila amb exactament `AppAccountId INT` i `PasswordHash NVARCHAR(255)`.
- Només EXECUTE autoritzat a l'app, no SELECT directe general a AppAccount. El hash és dada transitòria d'autenticació en memòria, no un context funcional ni una dada que es mostri a la GUI.
- L'app verifica Argon2id; si falla o no hi ha compte actiu, no sol·licita alta de sessió. La lectura inicial no reserva sessió ni exclou batch durant el càlcul.

#### 6.13.3 CreateAppSession

`dbo.CreateAppSession(@AppAccountId INT, @ExpectedPasswordHash NVARCHAR(MAX), @SessionToken VARBINARY(MAX))`

- SQL revalida atòmicament compte actiu i hash exacte encara vigent, neteja caducades, comprova sessió única i exclusió global amb batch. Revalidar hash/longitud sense truncament, no comparar secrets amb igualtat CI_AI.
- Token de 32 bytes verificat abans de convertir; persistir només SHA-256. SQL genera AppSessionId UNIQUEIDENTIFIER i desa l'activitat segons el diccionari. Segon login rebutjat sense expulsar la sessió vigent.
- Resposta d'èxit: una fila amb `AppSessionId UNIQUEIDENTIFIER`, només després del COMMIT. Cap ID d'èxit abans de confirmar ni hash/token retornat. Errors/resultat incert segueixen §6.11.6; no reenviament automàtic.

### 6.14 Catàleg permanent, preparació global i correccions editorials

**D380:** els contractes independents de grup es conserven; Usages i claus de grups referenciats s'han de contrastar amb marca–grup. CategoryCode del SKU o evidència font no s'elimina. E02/E09 cobreixen aquesta adaptació, no un catàleg nou.

**D201–D217; tots els procediments a VARIANTS_PARKOD.dbo.** Paràmetres de sessió de §6.13.1 obligatoris a totes les signatures següents. Les signatures no són DDL ni aprovació de desplegament; no taules/columnes noves.

#### 6.14.1 Finestra permanent i regles comunes

Consulta/edició del catàleg sempre disponible per tipus globals o exclusius, usats en un o múltiples grups, i valors encara no assignats. Mostrar definició, **tots** els valors, consulta d'usos i motius dels bloquejos ordinaris BrandCode/ValueKind. No bloquejar tota la finestra perquè hi hagi usos ni substituir la llista sencera en desar; cada operació té abast propi. No límit artificial de 40 valors.

Preparació independent anticipada aprovada **només per tipus globals i els seus valors**: BrandCode=NULL, sense associacions, assignacions, validacions o reserves de codis implícites. Durant preparació inicial tot és en memòria. Confirmar crea tipus/valors i una auditoria `confirmed_change/create` per fila, snapshots complets, OperationId comú, en una sola transacció curta; cancel·lació/error no deixa altes parcials. Els catàlegs no tenen IsValidated ni hereten aprovacions. No confondre aquest circuit amb les correccions/altes conjuntes de §6.10.

Entrades de text NVARCHAR(MAX): normalitzar abans de validar longitud/buit/unicitat i desar en les longituds del diccionari; cap truncament. L'entrada ampla no amplia les columnes. Rebutjar col·lisions normalitzades sense fusió, deduplicació ni reutilització silenciosa d'un altre ID. Auditoria SQL sobre files verificades i resposta capturada per l'operació, no relectura posterior vulnerable a canvis d'una altra sessió.

#### 6.14.2 ValuesJson per a valors nous

`@ValuesJson NVARCHAR(MAX)` és un array d'objectes amb **exactament** `NumericValue` i `TextValue`, totes dues propietats obligatòries, una sola informada segons ValueKind; l'altra JSON null. No IDs, Type, ValueKind ni altres rèpliques dins de cada entrada. Rebutjar propietats duplicades també als interiors, absències o tipus JSON incorrectes.

NumericValue és un número representable exactament en DECIMAL(18,3), sense FLOAT ni arrodoniment; TextValue és text normalitzat no buit. Unicitat dins del lot i respecte del catàleg segons §3.5; formats numèrics equivalents no creen files diferents. No s'aplica automàticament a tots els valors la positivitat específica de les quantitats font. Regles funcionals i gramàtica d'entrada confirmades; validació executable i proves de límits encara pendents.

**Gramàtica d'entrada confirmada (D236):** quan està informat, NumericValue és un número JSON, no una cadena; part entera obligatòria, punt decimal opcional amb dígits després i signe negatiu opcional, segons sintaxi numèrica JSON. Sense signe `+`, coma decimal ni notació científica. Valor exactament representable en DECIMAL(18,3): com a màxim 15 dígits enters i escala 3; si s'informen més de tres posicions decimals, totes les posteriors a la tercera han de ser zero. La comprovació ha d'evitar que una conversió arrodoneixi abans de detectar l'error. Zero i negatius no es rebutgen pel signe/zero per si sols; NumericValue JSON null continua sent obligatori per a ValueKind=text segons XOR.

| Token proposat per a NumericValue | Tractament confirmat |
|---|---|
| `50`, `50.125`, `50.0000` | Admesos si la resta del contracte és coherent; 50 i 50.0000 són el mateix valor. |
| `50.0001` | Rebutjat: no representable exactament a escala 3. |
| `"50"` | Rebutjat com a NumericValue: cadena, no número JSON. |
| `5e1` | Rebutjat: notació científica encara que sigui equivalent a 50. |
| `0`, `-2.5` | No rebutjats per positivitat global inexistent al catàleg. |

Abast inicial: ValuesJson de nous valors de catàleg de §6.14.3/§6.14.5. **D239 aprova expressament reutilitzar aquesta gramàtica per NumericValue de NewValueJson (§6.10.1)**; és un objecte individual, no un array. No reescriu originals/JSON històrics ni amplia automàticament altres contractes. `code1` segueix §5.2, sense signe i amb quantitats positives/unitats vàlides; TextValue pot ser `"50"` quan ValueKind=text. Gramàtica decidida, parser i proves executables encara pendents; ni canvis de precisió ni camps nous.

#### 6.14.3 CreateGlobalVariantTypeWithValues

`dbo.CreateGlobalVariantTypeWithValues(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @Type NVARCHAR(MAX), @Characteristics NVARCHAR(MAX), @ValueKind NVARCHAR(MAX), @ValuesJson NVARCHAR(MAX))`

Fixa BrandCode=NULL; rebutja parella Type + Characteristics ja existent, global **o exclusiva**, encara que ValueKind coincideixi. Comprova representació, `open_type → text`, normalització/unicitat i tots els valors; `[]` admès per crear un tipus buit. Tipus, tots els valors i auditories es creen atòmicament, amb OperationId comú.

Èxit només post-COMMIT, **dos conjunts**:

1. Una fila amb `OperationId UNIQUEIDENTIFIER` i VariantType complet: VariantTypeId, Type, Characteristics, BrandCode, ValueKind.
2. Totes les files VariantTypeValue creades: VariantTypeValueId, VariantTypeId, Type, NumericValue, TextValue; conjunt buit si entrada `[]`.

Resultats capturats dins de l'operació, no una consulta independent posterior. Qualsevol error desfà tot el lot.

#### 6.14.4 GetVariantTypeCatalog

`dbo.GetVariantTypeCatalog(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT)`

Tipus global o exclusiu; error si inexistent. Lectura SNAPSHOT curta **només a VARIANTS_PARKOD**, tancada abans de revisar, sense reserva de grup ni auditoria de lectura. Una fila `CatalogJson NVARCHAR(MAX)` amb exactament:

- `VariantType`: fila completa del pare.
- `VariantTypeValues`: array de totes les files completes del catàleg, també no utilitzades; `[]` si buit.

No Usages en aquest contracte de dos blocs. No text SQL JSON escapant JSON imbricats, ni propietats duplicades/desconegudes; null explícit segons diccionari. La consulta d'usos i la revisió editorial tenen contextos específics següents.

#### 6.14.5 AddGlobalVariantTypeValues

`dbo.AddGlobalVariantTypeValues(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedCatalogJson NVARCHAR(MAX), @ValuesJson NVARCHAR(MAX))`

Tipus encara global (BrandCode NULL). ExpectedCatalogJson conté exactament VariantType complet i VariantTypeValues complets segons §6.14.4. Nova transacció curta amb coordinació per tipus, rellegir/contrastar estat actual abans d'afegir; context alterat exigeix nova revisió. Només valors nous, `[]` rebutjat. Validar lot/col·lisions i crear tots o cap; auditar només files noves, OperationId comú. Cap canvi a valors existents, associacions o assignacions.

Resposta de dos conjunts només post-COMMIT: primer OperationId i tipus complet verificat, segon **només valors nous**, amb els mateixos camps de §6.14.3. Resultat capturat, no relectura posterior.

#### 6.14.6 Revisió editorial: confirmació i contextos

Només redacció **sense canvi de significat**, amb decisió humana expressa:

> Je confirme que cette correction ne change pas la signification.

`@ConfirmsUnchangedMeaning BIT` ha de ser 1; NULL/0 rebutjats. No converteix una modificació semàntica/quantitativa en editorial ni autoritza canviar NumericValue. SQL comprova context, regles i unicitat, però no pot demostrar tot sol equivalència semàntica. IDs, assignacions, validacions, codis i JSON històrics es preserven.

| Procediment i signatura completa | Resposta; propietats exactes del ContextJson |
|---|---|
| `dbo.GetVariantTypeValueEditorialContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeValueId INT)` | VariantType complet, VariantTypeValue complet, Usages del valor concret. |
| `dbo.GetVariantTypeEditorialContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT)` | D328: una fila amb ContextJson NVARCHAR(MAX) i InactiveProductGroupsJson NVARCHAR(MAX). ContextJson conserva exactament VariantType complet, VariantTypeValues complets (també no assignats), ProductGroupVariantTypes complets (candidates/aprovades, també de grups inactius), Usages de tot el tipus. |

Error si objecte inexistent. Tots els blocs d'un mateix estat SNAPSHOT curt, tancat abans del formulari; cap reserva de tots els grups ni auditoria de lectura. Arrays `[]` si absents. Dades de la còpia local, sense consulta dbo original obligatòria. Són contextos de **tres/quatre blocs**, diferents del catàleg de dos blocs i de substitució de set blocs.

**D328, resposta editorial de tipus ampliada expressament:** només GetVariantTypeEditorialContext passa a **dues columnes d'una mateixa fila**, no dos conjunts. InactiveProductGroupsJson és array amb exactament BrandCode, CategoryCode i ProductGroupId per cada grup IsActive=0 referenciat per les associacions d'aquell ContextJson; identitats completes úniques, [] si cap, mai SQL NULL/propietat omesa o detall de nom/permisos. Les dues columnes provenen del mateix SNAPSHOT. És metadata de presentació, no columna física, cinquè bloc del context o rèplica a ProductGroupVariantType.

La GUI ordinària no mostra aquests grups com a usos operatius/enllaços/destinacions. Pot explicar un bloqueig per ús històric conservat sense llistar-los. SQL conserva **totes** les associacions al context i als controls BrandCode/ValueKind. Tipus i valors compartits no desapareixen per tenir referències inactives. CorrectVariantTypeText i els confirmadors ordinaris §6.30 continuen rebent només el ContextJson de quatre blocs; la metadata no s'envia com a estat desitjat ni els autoritza a operar sobre grups inactius. GetVariantTypeBrandScopeChangeContext protegit (§6.30.1) manté una sola columna ContextJson amb la mateixa forma de quatre blocs. GetVariantTypeValueEditorialContext conserva una sola columna i tres blocs; no s'hi afegeix metadata, perquè un grup inactiu és necessàriament sense SKU. Resposta editorial incompleta: no inventar [], grup actiu o camps absents (§6.34.5).

**Usages compartit (D211):** array de tots els usos pendents/validats, també SKU retirats. Cada entrada té exactament:

- `ProductVariantValue`: fila completa del diccionari, amb originals JSON imbricats i null explícits.
- `ProductVariant`: objecte amb exactament `ProductVariantId`, `BrandCode`, `CategoryCode`, `ProductCode`, `ProductGroupId`, `Parkod`; aquest últim objecte conté **només SourceIsPresent**, de VARIANTS_PARKOD.dbo.Parkod.

ProductVariantValue i ProductVariant han de correspondre al mateix SKU/tipus/grup complet coherent. Filtre pel valor concret o per tot el tipus segons procediment; sense entrades null/incompletes ni duplicats de `(ProductVariantId, VariantTypeId)`, ordre irrellevant, `[]` si cap ús. Risc/validació de pertinença, LineCode, CLIGNE i noms de grup **no** s'afegeixen a aquest ProductVariant reduït; no confondre'l amb membres de substitució de §6.11.4.

#### 6.14.7 Coordinació, comparació i correcció de TextValue

Confirmació en **nova transacció curta sobre estat actual** sota bloqueig exclusiu per VariantTypeId, mai amb l'antic SNAPSHOT. Totes les vies que alteren usos/dades del context, inclosos trasllats, retirades, associacions, altes de valors i presència, han de respectar la coordinació compatible amb §6.2; ordre global de bloquejos preservat. Sense bloqueig durant el formulari ni reserva de tots els grups. Comparar propietats/conjunts/absències i textos exactes (§6.8.1), no només CI_AI; qualsevol canvi rellevant exigeix nova revisió.

`dbo.CorrectVariantTypeValueText(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeValueId INT, @ExpectedContextJson NVARCHAR(MAX), @TextValue NVARCHAR(MAX), @ConfirmsUnchangedMeaning BIT)`

ExpectedContextJson és el context del valor de §6.14.6. Exigeix tipus textual, confirmació=1 i context coincident; normalitza/comprova longitud/no buit/unicitat. Modifica **només TextValue**, mai NumericValue, IDs ni tipus pare. Una entrada confirmed_change/update amb Before/After complets i OperationId SQL, atòmica amb el canvi; no auditar SKU intactes.

Resposta: una fila només post-COMMIT amb `OperationId UNIQUEIDENTIFIER` i valor complet resultant (VariantTypeValueId, VariantTypeId, Type, NumericValue, TextValue). Si després de comprovar context i normalitzar no hi ha canvi exacte: cap UPDATE ni auditoria, `OperationId=NULL` a la resposta, valor complet verificat. Aquesta nul·litat és del resultat, no d'EvaluationAuditEvent.OperationId.

#### 6.14.8 Correcció del tipus i propagació exacta

`dbo.CorrectVariantTypeText(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @Type NVARCHAR(MAX), @Characteristics NVARCHAR(MAX), @ConfirmsUnchangedMeaning BIT)`

ExpectedContextJson és el context de quatre blocs del tipus. Dos textos finals obligatoris: NULL **no** vol dir conservar. Confirmació=1, context actual coincident, normalització/longitud/no buit/unicitat. Modifica només Type/Characteristics i les rèpliques VariantTypeValue.Type que realment canviïn; cap canvi BrandCode/ValueKind/valors ni associacions/assignacions intactes.

Audita una entrada confirmed_change/update per **cada fila realment modificada**, inclosa cada rèplica Type, amb snapshots complets i OperationId comú. Propagar exactament majúscules/accents malgrat CI_AI; no suposar que la FK/cascada farà un canvi que la seva comparació considera equivalent. Garantia pendent de prova SQL Server 2017: si no es pot preservar propagació exacta i auditoria atòmica, rollback íntegre, no èxit parcial ni nova dependència implícita.

Resposta de **dos conjunts** només post-COMMIT:

1. Una fila OperationId UNIQUEIDENTIFIER i VariantType complet resultant.
2. Només VariantTypeValue realment modificats, complets; no tot el catàleg.

Sense canvi efectiu exacte després de normalitzar i contrastar context: cap UPDATE/auditoria, OperationId=NULL al primer conjunt i segon buit. Una correcció només de Characteristics no produeix auditories de rèpliques Type intactes. Resultats capturats dins de l'operació, no relectura posterior.

#### 6.14.9 Reversió editorial i resultat incert

Reutilitzar CorrectVariantTypeText o CorrectVariantTypeValueText, amb **context actual nou**, textos anteriors proposats, nova comprovació d'impacte/unicitat i nova confirmació humana. Si hi ha canvi, nova operació/auditoria/OperationId; historial antic intacte. No restaurar snapshots sencers, eliminar catàlegs, recuperar assignacions retirades o desfer classificacions amb aquest circuit editorial. Les reversions no editorials segueixen els circuits ordinaris de §6.8.7, criteri funcional ja acordat; no «Desfer OperationId» nou. Materialització/proves pendents.

Timeout/connexió perduda/resposta incompleta segueixen §6.11.6 també en aquests circuits: no reenviar automàticament, afirmar rollback ni registrar rebuig humà; invalidar context antic i recuperació manual d'estat/auditoria només per administrador segons D238, sense prometre idempotència no definida. Cancel·lar preparació manual abans de confirmar no crea files ni auditoria d'una decisió inexistent.

### 6.15 Contractes de revisió de candidates existents

**Adaptació directa D380:** tres signatures grup–tipus sense categoria; context de quatre blocs amb grup7/associació8, set blocs SKU–valor amb reduïts grup3/associació5 (§6.45.2–§6.45.4). Signatures SKU–valor intactes. D393/D394/D369/D400, originals, XOR, auditories i disponibilitat D396/D402–D403 conservats; cap E02 global tancat.

**D241–D247; tots els procediments a VARIANTS_PARKOD.dbo.** Signatures de disseny, no DDL executable ni objectes desplegats. Paràmetres comuns de sessió/token i controls existents de §6.13.1; integritat, permisos/reserva quan correspongui, ordre de bloquejos i auditoria continuen en SQL. Confirmacions/rebutjos rellegeixen i contrasten context en una transacció curta sobre estat actual; no reutilitzen el SNAPSHOT de lectura. Errors/resultats incerts segueixen §6.11.6/D238, sense reenviament automàtic ni rebuig humà fictici. Cap secret dins dels JSON de context.

#### 6.15.1 ConfirmVariantValueProposal

**D241, signatura confirmada:**

```text
dbo.ConfirmVariantValueProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @SelectedVariantTypeValueId INT = NULL,
    @NewValueJson NVARCHAR(MAX) = NULL
)
```

Acceptar o corregir **una candidata pendent persistent** identificada per `(ProductVariantId, VariantTypeId)`, no rebutjar-la ni decidir una proposta nova sobre assignació ja validada. SQL obté el grup de l'assignació real i el contrasta amb el context revisat de §6.8.2 i els controls de sessió/reserva. Originals/risc autoritatius de la fila SQL segons §3.11.5; el context esperat no és el resultat desitjat.

Defaults NULL confirmats, però no són acceptació implícita: exactament una via D239 (§6.10.1), tots dos NULL invàlids. Alta de valor si cal, confirmació d'assignació i auditories atòmiques; no canvi de significat d'un valor de catàleg compartit. Resposta D240 de §6.10.2 intacta: dos conjunts d'una fila només post-COMMIT, capturats dins de l'operació. No fase 3/codi automàtics. Forma exacta completa del context aprovada posteriorment per D248 a §6.15.3, no per extrapolació d'aquesta signatura.

#### 6.15.2 GetVariantValueProposalContext

**D242, signatura i lectura confirmades:**

```text
dbo.GetVariantValueProposalContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @SelectedVariantTypeValueId INT = NULL
)
```

Una fila `ContextJson NVARCHAR(MAX)` amb l'abast de §6.8.2 i la representació de §6.15.3 confirmada posteriorment per D248. Incloure sempre candidata pendent i valor original; si el seleccionat existent està informat, incloure'l també i exigir que sigui del mateix tipus. **NULL significa que no s'ha indicat un valor final existent addicional**, no elimina l'original ni crea un valor nou. El contingut desitjat d'un valor nou es conserva separat al backend per NewValueJson; no s'injecta a l'estat SQL revisat.

Error si candidata absent/ja validada o seleccionat incompatible. Sessió verificada, tots els blocs d'un **SNAPSHOT curt només de VARIANTS_PARKOD**, transacció tancada abans de revisar. No modifica assignacions, crea catàlegs, reserva codis ni audita lectura. No consulta parkod original. D242 n'aprovava nom/signatura/resposta/abast; D248 n'aprova després la representació íntegra, sense modificar-los.

#### 6.15.3 Context SKU–valor de set propietats confirmat

**D243/D248 adaptats D380:** Parkod manté exactament CLIGNE/SourceIsPresent locals. CLIGNE més recent pot diferir de LineCode classificat; no FK amb CLIGNE. Grup reduït3 i associació reduïda5 següents, no antigues R5 o files completes7/8 substitutives. D369/D394/D400 permeten els circuits de valor contrastats amb desajust conegut, sense corregir línia; context canviat exigeix nova revisió. No permissió universal o signatures noves.

SourceIsPresent conserva la situació local de presència revisada, relacionada amb exportació i exigència de valors en finalitzar habilitacions; no forma part del valor del catàleg. **Un 0 no elimina l'assignació ni introdueix una prohibició nova de corregir SKU retirats.** Inclusió conservadora de dependències ja previstes a §6.8.2, no camps nous ni requisit per determinar la validesa del número/text. L'exclusió batch–sessions es manté; aquesta propietat no autoritza conciliació durant sessions actives.

**Representació completa confirmada D248:** aprovació expressa posterior a D243, no ampliació retroactiva de la resposta sobre Parkod. Totes les propietats són obligatòries, objectes excepte l'array VariantTypeValues, sense propietats addicionals o duplicats ni context parcial si falta una dada requerida:

| Propietat | Contingut confirmat |
|---|---|
| ProductVariantValue | Fila completa segons §3.7. |
| ProductVariant | ProductVariantId, BrandCode, CategoryCode, ProductCode, ProductGroupId, LineCode, IsValidated. |
| ProductGroup | Exactament BrandCode, ProductGroupId, IsValidated; activitat comprovada a SQL, no IsActive afegit al JSON. |
| VariantType | Fila completa segons §3.4. |
| VariantTypeValues | Array de files completes segons §3.5: original i seleccionat existent si informat; mateix ID només una vegada, només original sense seleccionat. |
| ProductGroupVariantType | Exactament ProductGroupId, BrandCode, VariantTypeId, IsValidated, ParkodVariantCode; codi NVARCHAR(5) nullable, no risc/originals afegits al reduït. |
| Parkod | CLIGNE i SourceIsPresent de la còpia local; aquesta propietat sí està confirmada per D243. |

JSON null explícit en camps nullable i originals JSON imbricats, no cadenes escapades; cap altre SKU del grup ni valor nou desitjat dins del context. És el context de candidata, no el JSON de substitució A → B malgrat tenir també set propietats. Reutilització expressament confirmada amb fila validada a §6.23 i fila absent a §6.24; les diferències d'estat/absència s'hi declaren, no són un context universal implícit.

#### 6.15.4 RejectVariantValueProposal

**D400:** discrepància de línia coneguda no bloqueja aquest rebuig; només candidata pendent eliminada segons D244, catàleg/SKU conservats. Incidència pendent, D396/D402–D403 i altres controls intactes (§6.44).

**D244, signatura i resposta confirmades:**

```text
dbo.RejectVariantValueProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Context de lectura de candidata **sense valor final existent addicional**. Només IsValidated=0 amb proposta original disponible; context, sessió, permisos/reserva quan correspongui comprovats. Una única auditoria `proposal_decision / proposal_review / rejected`, originals/risc i Before complets preservats, After/DecisionResult SQL NULL; abans d'eliminar només la candidata, mateixa transacció (§3.11.4). SKU, catàleg de valor, tipus, grup i historial preservats.

Conflicte de context no elimina ni registra rebuig confirmat; nova revisió. Èxit: **una fila amb exactament OperationId UNIQUEIDENTIFIER, només després del COMMIT**. No assignació resultant perquè s'ha eliminat, ni dos conjunts D240. Aquesta via no retira una assignació validada ni rebutja una proposta nova no persistent sobre estat validat.

#### 6.15.5 ApproveGroupVariantTypeProposal

**D245, signatura i resposta confirmades:**

```text
dbo.ApproveGroupVariantTypeProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Acceptar **la candidata existent tal com està proposada, sense canviar-ne el tipus**. Marca exactament3 abans de convertir, ID de grup positiu/marca–ID, sense categoria de grup. Contrastar §6.8.3/§6.15.6 i controls de sessió/reserva/activitat; IsValidated=1/codiNULL, risc/originals conservats i auditoria d'acceptació atòmica. D393 permet línia coneguda, no context canviat o dades indisponibles.

No crea valors SKU, assigna codis ni modifica el principal. Canviar VariantTypeId segueix el circuit de substitució que correspongui, no aquest procediment; no és una correcció editorial del catàleg. Èxit: **una fila OperationId UNIQUEIDENTIFIER + ProductGroupVariantType complet resultant** segons §3.6, capturada dins de l'operació i retornada només post-COMMIT. No extrapolar a no-op o associació ja aprovada.

#### 6.15.6 GetGroupVariantTypeProposalContext

**D246, signatura, lectura i estructura JSON confirmades:**

```text
dbo.GetGroupVariantTypeProposalContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeId INT
)
```

Validar longitud dels codis abans de convertir, sense truncament. Sessió comprovada, una fila `ContextJson NVARCHAR(MAX)` amb **exactament quatre propietats obligatòries**, dades del mateix SNAPSHOT curt només a VARIANTS_PARKOD, tancat abans de revisar:

| Propietat | Forma i contingut confirmats |
|---|---|
| ProductGroupVariantType | Objecte amb fila completa de la candidata, §3.6. |
| ProductGroup | Objecte amb fila completa del grup, §3.2. |
| VariantType | Objecte amb fila completa del tipus, §3.4. |
| ProductVariants | Array de tots els membres reals, amb la forma reduïda inferior. |

Cada membre té exactament ProductVariantId, BrandCode, CategoryCode, ProductCode, ProductGroupId, LineCode, IsValidated i un objecte Parkod amb exactament CLIGNE/SourceIsPresent de la còpia local. No risc de pertinença afegit ni lectura obligatòria de parkod original. Incloure retirats i pertinences pendents, sense duplicats; `[]` si grup buit. Camps nullable amb JSON null explícit, originals JSON imbricats; la proposta de pertinença no incorporada encara no és un membre real.

Error si candidata absent o ja aprovada. No modifica dades, crea valors ni reserva codis; lectura no auditada segons la regla general. El contracte és el de fase 2 de §6.8.3, no l'editorial de quatre blocs, la proposta completa SKU–valor de §6.15.3 ni la substitució de set blocs. La forma JSON d'aquest apartat sí està explícitament confirmada.

#### 6.15.7 RejectGroupVariantTypeProposal

**D400:** discrepàncies de línia conegudes dels membres no bloquegen per si soles el rebuig admissible D247. Associació0/codiNULL/sense assignacions/original exigits, no retirada d'una aprovada. Incidència pendent, D396/D402–D403/context actual/altres controls intactes (§6.44).

**D247, signatura i resposta confirmades:**

```text
dbo.RejectGroupVariantTypeProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Context de quatre blocs de §6.15.6, marca exacta abans de convertir i controls existents de sessió/permisos/reserva/activitat. Només candidata0/codiNULL/original disponible i cap ProductVariantValue que referenciï l'associació **marca–grup–tipus**, també pendent/validada/de retirat. Condicions/context verificats atòmicament, no filtre per categoria dels membres.

Una única auditoria de rebuig segons §3.11.4, seguida de l'eliminació només de l'associació en la mateixa transacció; originals/risc/Before complets preservats, After/resultat SQL NULL. Conservar grup, SKU, catàlegs i historial. Una associació ja aprovada a fase 2 no es pot rebutjar per aquesta via, encara que no tingui codi. Conflicte o condició invàlida no elimina ni registra rebuig confirmat.

Èxit: **una fila amb exactament OperationId UNIQUEIDENTIFIER, només després del COMMIT**. No fila d'associació resultant ni resposta d'aprovació D245 per extrapolació; no és retirada funcional de validats ni substitució A → B.

**D247 revisat inclòs el 2026-10-28:** signatura/condicions/resposta preservades. «Conflicte sense rebuig confirmat» significa conflicte detectat amb rollback d'aquest intent i log tècnic, no un error de connexió després d'un possible COMMIT; §6.16.1 i D238 mantenen el tractament incert. L'auditoria d'altres operacions confirmades no es desfà.

### 6.16 Convencions addicionals i consulta administrativa de resultat incert

#### 6.16.1 Abast i verificació retrospectiva

**D248–D284; vint signatures noves de disseny, no implementació.** Tots els objectes són a VARIANTS_PARKOD.dbo i utilitzen els arguments comuns de §6.13.1; token de longitud exacta abans de convertir, actor derivat de sessió, cap secret a contextos/logs/auditoria. Es mantenen integritat, permisos, reserva quan correspongui, coordinació de tipus/SKU/grup i atomicitat en SQL. Els vuit lectors addicionals fan SNAPSHOT curt només sobre aquesta base, tancat abans d'analitzar o editar. Les escriptures/auditories contrasten el context en una transacció actual nova, curta; mai durant un formulari ni reutilitzant el SNAPSHOT per escriure.

Totes les respostes d'escriptura s'emeten només després del COMMIT, capturades dins de l'operació; no relectura posterior. Un conflicte detectat i amb rollback no insereix una decisió humana definitiva d'aquell intent ni elimina dades per rebuig. Exemple: es revisa M, es vol rebutjar XL i una altra persona ha confirmat L; cal nova revisió, conservar L i la seva auditoria, log tècnic anglès, no una rejected fictícia basada en context caducat. Timeout/connexió perduda/resposta incompleta **no proven rollback** i segueixen D238: avís, context antic invalidat, cap reenviament automàtic i investigació manual admin.

Els noms de propietats/columnes de resposta són transitoris: no afegeixen camps físics. Full row significa tots els camps del diccionari auditable corresponent, amb null explícit i JSON imbricats dins de JSON; mai PasswordHash/token/secrets. Mateixes regles d'exactitud, conjunts, noms exactes i rebuig de propietats/IDs duplicats, sense truncament, deduplicació o reutilització silenciosa.

**Control D240–D248 adaptat D380:** dos conjunts de confirmació assignació9/valor5/captura interna/post-COMMIT/sense fase3. Sis noms de §6.15, tres signatures grup–tipus retiren categoria i tres SKU intactes; resta d'arguments/ordre/tipus/defaults conservats. D245: IsValidated1/codiNULL; D246: quatre blocs/grup7/associació8; D247: candidata0/codiNULL/sense assignacions/original/audit+DELETE/resposta OperationId. Set blocs SKU de D248 amb grup reduït3/associació5, no IsActive afegit. Reutilitzacions per circuit expressament aprovades, D328 editorial amb dues columnes no extrapolat. Altres formes E02 pendents.

#### 6.16.2 GetUncertainOperationContext

**D249–D252:**

```text
dbo.GetUncertainOperationContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @OperationId UNIQUEIDENTIFIER = NULL,
    @BrandCode NVARCHAR(MAX) = NULL,
    @ProductGroupId INT = NULL,
    @VariantTypeIdToReplace INT = NULL,
    @ReplacementVariantTypeId INT = NULL
)
```

Exactament una via: OperationId informat i els **quatre** arguments BrandCode/ProductGroupId/VariantTypeIdToReplace/ReplacementVariantTypeId SQL NULL; o OperationId SQL NULL i tots quatre informats, només per substitució sense ID. Marca exactament3 abans de convertir, grup marca–ID. Sessió i **IsAdmin vigent**, també operacions d'altres usuaris, no identitat SQL de bootstrap. Mateix SNAPSHOT curt per auditoria/estat actual, absències explícites, A pot haver estat retirada correctament. Sense reserva, modificació, reenvio o auditoria de lectura; estat observat no prova autoria, si ambigu incidència pendent. D238/D305 i fallback acotat intactes. Dependències exactes de consulta administrativa encara E05, no veto de confirmació/rebuig extrapolat.

#### 6.16.3 Dos conjunts administratius

Primer conjunt: files completes EvaluationAuditEvent (§3.11). Per ID conegut, totes les seves entrades; per grup/A/B, trobar OperationId amb una entrada TargetScope=group_variant_type de la identitat completa del grup i VariantTypeId igual a **A o B**, després recuperar totes les entrades de cada operació trobada, també d'altres àmbits. No exigir A i B tots dos auditats: B pot quedar intacta. Sense duplicats, ordre OccurredAtUtc/EvaluationAuditEventId per presentació; no tria automàtica de l'última operació. Buit no prova rollback/petició acabada.

Segon conjunt, exactament aquestes columnes:

| Columna | Tipus/contingut |
|---|---|
| TargetScope | NVARCHAR(32), àmbit existent de l'objecte. |
| ObjectKeyJson | NVARCHAR(MAX), clau primària real de l'objecte identificable, no el TargetKeyJson històric. |
| CurrentStateJson | NVARCHAR(MAX) NULL, fila actual auditable completa o SQL NULL si absent. |

Objectes identificables de les auditories retornades, una vegada per àmbit/clau real. En cerca grup/A/B, afegir també grup, definicions A/B i dues associacions, encara que no s'hagi trobat auditoria. Identificació per PK ja definida, no pel contingut desitjat ni restauració de snapshots:

| Àmbit | Clau real de consulta |
|---|---|
| product_group | BrandCode, ProductGroupId. |
| group_membership | ProductVariantId; es consulta la pertinença actual encara que hagi canviat de grup. |
| group_variant_type | ProductGroupId, BrandCode, VariantTypeId. |
| variant_value | ProductVariantId, VariantTypeId; no incloure el valor anterior com a condició de cerca. |
| variant_type | VariantTypeId. |
| variant_type_value | VariantTypeValueId. |
| parkod_copy | CMARQ, CCATEG, CPROD de la còpia local. |
| app_account | AppAccountId, només camps auditables, sense PasswordHash. |

D329/D380: CurrentStateJson de product_group té set camps també amb IsActive=0, no SQL NULL per inactivitat. Claus reals actuals marca–grup/associació de tres camps; cap IsActive afegit a claus. Primer conjunt amb claus/originals/snapshots històrics literals, sense reescriure'ls per simular la PK nova. D305: ForceCloseAppSession continua fora de recuperació GUI, sense ampliar consulta/fallback.

Un grup rebutjat abans de crear-se, sense ID real, no genera un objecte inventat: evidència només al primer conjunt. No modificar TargetKeyJson antic ni atribuir automàticament èxit/rollback a l'estat actual. Aquesta resposta no reconstrueix el formulari o el resultat perdut.

### 6.17 Finalització individual de fase 3

**Contracte adaptat D380/D381:** dues signatures marca–grup, sis blocs amb grup7/associacions8/assignacions9, resposta codi5. D382/D392: DE000…ZZZZZ per marca/sense retorn-blocs, línies resoltes dels requerits abans de codi NOU, cap revocació de codis antics. D253–D256/resultsets/principal/D396/D402–D403 conservats; E06/materialització/proves pendents.

#### 6.17.1 Signatures de finalització i lectura

**D253–D254:**

```text
dbo.FinalizeGroupVariantType(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @SelectedPrimaryVariantTypeId INT = NULL
)

dbo.GetGroupVariantTypeFinalizationContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeId INT
)
```

Associació existent1/codiNULL, altrament error; marca exactament3 abans de convertir/grup positiu, actiu i controls de sessió/reserva. Lector: una fila ContextJson/SNAPSHOT curt local, sense alta de valors/reserva anticipada de codi; principal desitjat separat. Finalitzador: nova transacció actual/context-valors-compatibilitat-principal comprovats, registre+codi+associació+principal+auditories atòmics. SelectedPrimary NULL significa sense nova tria, no esborrar: únic final aquell ID, múltiples conservar principal vàlid o exigir tria; ID invàlid rebutja tot. Sense aprovar valors pendents o rebre codi del formulari.

#### 6.17.2 Context exacte i mínim per a codi nou

**D255–D256:** exactament sis propietats obligatòries:

| Propietat | Contingut |
|---|---|
| ProductGroup | Fila completa, inclòs principal actual. |
| ProductVariants | Tots els membres reals, també retirats/pertinences pendents, amb forma reduïda inferior. |
| ProductGroupVariantTypes | Totes les associacions actuals del grup, files completes. |
| VariantTypes | Tipus objectiu i altres actualment habilitats definitivament (1/codi informat), files completes sense IDs repetits. |
| RequiredTypeAssignments | Una entrada per membre SourceIsPresent=1 i pertinença IsValidated=1, per al tipus objectiu. |
| VariantTypeValues | Files completes dels valors referenciats per aquestes assignacions, una vegada per ID. |

Cada membre té exactament ProductVariantId, BrandCode, CategoryCode, ProductCode, ProductGroupId, LineCode, IsValidated i Parkod amb exactament CLIGNE/SourceIsPresent locals. Aquesta és també la forma reduïda expressament acordada per als membres dels contextos §6.18–6.21, no un afegit al diccionari.

Cada RequiredTypeAssignments té exactament ProductVariantId i ProductVariantValue: fila completa del mateix SKU/tipus o JSON null explícit si falta. Una pendent és fila existent, no absència; pendent/absent requerida impedeix finalitzar. Arrays sense duplicats/[] quan pertoqui, nullable explícits/originals imbricats, sense principal desitjat ni pròxim codi disponible.

Un lector pot retornar zero requerits per mostrar la situació, però **una nova assignació de codi exigeix almenys un SKU present amb pertinença validada**. Altrament, cap consum/reserva ni canvi de principal: associació continua 1/NULL. No revocar ni alterar codis/habilitacions assignats anteriorment si el grup després queda buit o només amb retirats. La regla no converteix aquests grups en exportables.

#### 6.17.3 Resposta de finalització

Una fila amb exactament OperationId UNIQUEIDENTIFIER, ParkodVariantCode **NVARCHAR(5)**, PrimaryVariantTypeId INT, tots informats. Principal final del grup, no necessàriament el tipus acabat de finalitzar. Captura interna/post-COMMIT, resposta incompleta D238; esgotament/invalidesa sense codi-principal parcial o reciclatge. Valors requerits validats, almenys un requerit i D392 abans de codi nou; proves d'ordre/seqüència French_CI_AS encara E06.

### 6.18 Trasllat ordinari a grup existent

**Adaptació directa D380/D390:** signatures següents sense DestinationCategoryCode; destí de la mateixa marca, no categoria/línia comunes. Resoldre línia del SKU que s'aprova abans de validar ordinàriament la pertinença; no inserir corrector implícit o veto nou per incidències d'altres membres. Set blocs i dos conjunts de resposta conservats, grup complet7/associació8/assignació9 segons diccionari. D396 s'aplica perquè el context necessita Parkod (§6.43.1); resta d'E02/E04 no tancada globalment.

#### 6.18.1 GetGroupMembershipMoveContext

**D257:**

```text
dbo.GetGroupMembershipMoveContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @DestinationBrandCode NVARCHAR(MAX),
    @DestinationProductGroupId INT
)
```

Grup origen derivat del SKU, no imposat pel formulari. Marca de destí de tres caràcters validada abans de convertir; arguments obligatoris sense defaults, IDs positius, controls sessió/reserva. Una fila ContextJson NVARCHAR(MAX) de SNAPSHOT curt local. Categoria del SKU conservada, no argument de destí. No trasllada/valida, crea associacions/reserves/codis o corregeix CLIGNE; destí existent compatible per marca.

#### 6.18.2 Set propietats exactes del trasllat

**D258:**

| Propietat | Contingut |
|---|---|
| ProductVariant | Fila completa del SKU que es vol traslladar. |
| Parkod | Exactament CLIGNE/SourceIsPresent del mateix SKU, còpia local. |
| SourceGroup | Bloc del grup actual de tres propietats, definit inferiorment. |
| DestinationGroup | Mateixa forma per al grup de destí. |
| ProductVariantValues | Totes les assignacions del SKU, files completes pendents/validades. |
| VariantTypes | Files completes dels tipus referenciats per associacions dels dos grups o assignacions del SKU, IDs únics. |
| VariantTypeValues | Files completes dels valors referenciats per assignacions del SKU, IDs únics. |

SourceGroup/DestinationGroup contenen exactament ProductGroup (set camps de §3.2, inclosos principal/activitat), ProductVariants (tots els membres reals reduïts de §6.15.6, amb categoria/línia pròpies i Parkod local) i ProductGroupVariantTypes (vuit camps de §3.6). Arrays sense duplicats/[] reals, null explícit/originals imbricats; no valors d'altres SKU o context parcial. Estat revisat, no configuració desitjada o moviment anticipat; no habilita associacions que faltin.

#### 6.18.3 ConfirmGroupMembershipMove

**D259:**

```text
dbo.ConfirmGroupMembershipMove(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @DestinationBrandCode NVARCHAR(MAX),
    @DestinationProductGroupId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX) = NULL,
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Manual directe: tres originals SQL NULL, confirmed_change/update i risc de nova pertinença NULL. Amb proposta no persistent: original nou del backend, fonts/risc nullable, accepted/corrected SQL i risc presentat conservat; no reescriure originals pel destí corregit. Pertinença final1, Before complet. Revalidar marca comuna, context/línia pròpia resolta D390, associacions/principals i rèpliques marca–grup; categoria del SKU no canvia ni s'exigeix al destí. Grups buits/assignacions/catàlegs conservats, cap grup/associació/codi nou o transferit. Controls §6.16.1 i disponibilitat D396 intactes.

#### 6.18.4 Resposta del trasllat

**D260:** dos conjunts post-COMMIT, capturats dins de l'operació:

| Ordre | Files | Camps |
|---|---|---|
| 1 | Una | OperationId UNIQUEIDENTIFIER + ProductVariant complet: ProductVariantId, ProductGroupId, BrandCode, CategoryCode, ProductCode, LineCode, EstimatedRiskPercent, IsValidated. |
| 2 | Zero o més | ProductVariantValue completes del SKU amb rèpliques de grup actualitzades; segon buit si cap, no omès. |

Tipus/nul·litats segons diccionari; valors, risc, validacions i originals d'assignacions preservats. Cap resposta d'èxit amb rollback; incert segons D238. Rebuig separat a §6.20.4.

### 6.19 Creació ordinària conjunta de grup i decisions individuals

**D380:** grup nou només de la marca del creador, membres de categories/línies diferents admesos. Creador/decisions expresses/preservació de valors i fórmula de nom intactes. No heretar categoria/línia com a camps del grup. Les formes/signatures següents són base D379, E02/E04 inclouen D390 per les pertinences aprovades.

#### 6.19.1 Creador i GetProductGroupCreationContext

**D261–D262:** @CreatorProductVariantId BIGINT és explícit, membre seleccionat i finalment aprovat. No primer element d'array o ID mínim arbitrari; herència/fórmula/fonts del nom prèvies intactes. Paràmetre transitori, no nova columna ni propietat afegida als originals establerts.

```text
dbo.GetProductGroupCreationContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @CreatorProductVariantId BIGINT,
    @ProductVariantIdsJson NVARCHAR(MAX),
    @VariantTypeIdsJson NVARCHAR(MAX)
)
```

ProductVariantIdsJson: array no buit d'IDs BIGINT reals; VariantTypeIdsJson: IDs INT existents ([] admès, cap herència implícita). Sense duplicats/ordre significatiu; creador inclòs i marca comuna, categories/línies dels SKU poden diferir. Sessió/reserva, SNAPSHOT curt local, una fila ContextJson NVARCHAR(MAX), amb disponibilitat D396. No grup/associació/trasllat/ID reservat/comptador consumit; nom/configuració/originals desitjats separats al backend. No resol tipus sense ID o correccions de CLIGNE.

#### 6.19.2 Cinc propietats del context de creació

**D263:**

| Propietat | Contingut |
|---|---|
| ProductVariants | Seleccionats; cada entrada té exactament ProductVariant (fila completa) i Parkod (CLIGNE/SourceIsPresent locals). |
| SourceGroups | Grups actuals dels seleccionats, una entrada per identitat marca–grup, amb tres propietats inferiors. |
| ProductVariantValues | Totes les assignacions dels seleccionats, files completes incloses pendents i de retirats. |
| VariantTypes | Definicions completes referenciades per associacions dels grups actuals, assignacions seleccionades o VariantTypeIdsJson, IDs únics. |
| VariantTypeValues | Valors complets referenciats per assignacions seleccionades, IDs únics. |

SourceGroups: exactament ProductGroup complet7, ProductVariants amb tots els membres reals reduïts de §6.15.6 (categoria/línia pròpies preservades), ProductGroupVariantTypes completes8. Tots els seleccionats/creador representats, sense context parcial/duplicats/valors de no seleccionats. Assignacions completes9 segons §3.7. Arrays [] reals, null explícit/originals imbricats. No fila de destí, ID futur o comptador congelat.

Els seleccionats poden provenir d'un o diversos grups provisionals o comercials: una incorporació inicial dona grup propi a cada SKU, abans d'identificar el grup comercial. No declara equivalents els grups d'origen sencers ni els fusiona; membres no aprovats romanen al lloc actual i grups buits es conserven. Un seleccionat apareix també dins la composició del seu grup actual: solapament deliberat de representació completa/reduïda, no duplicació SQL. Si ja hi ha un grup comercial correcte, no cal crear-ne un altre; el trasllat a existent té el seu circuit.

#### 6.19.3 Nom inicial i associacions aprovades

**D264:** @ProductGroupName NVARCHAR(MAX)=NULL demana generació inicial després d'assignar l'ID, amb creador explícit i fórmula/fallback §5.1. No desa nom NULL en aquesta alta, sense canviar nul·litat física ni edició posterior. Text informat: normalitzar abans de validar, rebutjar buit/>150, sense truncament o número afegit. Fallback compacte només per a generació automàtica. El protocol de lectura autoritzada dels noms font segueix pendent, no s'amplia SNAPSHOT a l'original.

**D265:** GroupVariantTypeDecisionsJson és array amb exactament quatre propietats obligatòries per entrada:

| Propietat | Forma |
|---|---|
| VariantTypeId | ID real de tipus existent. |
| OriginalProposalJson | Objecte original o JSON null per alta manual sense proposta. |
| OriginalSourcesJson | Array de fonts originals o JSON null segons contracte. |
| OriginalEstimatedRiskPercent | Número exactament representable DECIMAL(5,2), 0–100, o JSON null. |

Cada entrada aprova explícitament una associació nova 1/codi NULL, no hereta aprovació/codi/risc. Sense proposta, fonts/risc també null i risc de fila NULL; amb proposta, preservar originals/risc, inclòs ProductGroupId JSON null, no substituir-lo per ID generat. Tots els tipus per conservar assignacions dels SKU aprovats inclosos; si falta algun, rebutjar confirmació, no completar automàticament. [] només sense associacions necessàries. Omissió no és rebuig; sense IDs/propietats duplicats o addicionals ni JSON escapats. No catàleg nou ni substitució de tipus per aquesta entrada.

#### 6.19.4 Decisions de pertinença

**D266:** MembershipDecisionsJson és array amb exactament cinc propietats obligatòries per entrada:

| Propietat | Forma |
|---|---|
| ProductVariantId | ID real del SKU revisat. |
| Decision | Exclusivament approve o reject. |
| OriginalProposalJson | Objecte original de pertinença o JSON null per decisió manual sense proposta. |
| OriginalSourcesJson | Array de fonts originals o JSON null. |
| OriginalEstimatedRiskPercent | Número DECIMAL(5,2) exacte, 0–100, o JSON null. |

Una entrada per SKU del context revisat, sense IDs repetits. Approve incorpora al grup nou amb IsValidated=1: amb proposta, SQL determina accepted/corrected i conserva risc presentat; manual directe exigeix tres originals null, risc nou NULL i confirmed_change/update. Reject exigeix original i audita rebuig conservant íntegrament grup, pertinença, risc/validació i assignacions actuals. Rebuig no persistent sense canvi: ambdós snapshots i resultat SQL NULL, clau de pertinença del grup anterior real.

Una exclusió d'esborrany manual sense proposta no és reject: retirar de selecció i renovar context, no auditoria fictícia. Per confirmar alta, almenys un approve i creador aprovat; només aquests SKU es traslladen i determinen les associacions necessàries. Zero aprovats no crea grup ni una creació «corregida buida»; el circuit de rebuig corresponent és separat, concretat després a §6.25, sense rebutjos implícits. Originals mai reescrits amb ID de grup final.

**Contrast directe D390/D261–D268:** cada approve és una validació ordinària de pertinença i exigeix línia resolta d'aquell SKU. No cal que les seves línies siguin iguals entre elles; un SKU revisat amb discrepància no pot entrar com a approve. Si és el creador explícit, no es confirma l'alta mentre no sigui admissible/aprovat; no escollir-ne un altre silenciosament. Rebuig exprés amb original o canvi de selecció manual segueixen les regles anteriors. No veto nou pels altres membres dels grups d'origen que no s'aproven/traslladen.

#### 6.19.5 ConfirmProductGroupCreation

**D267:**

```text
dbo.ConfirmProductGroupCreation(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @CreatorProductVariantId BIGINT,
    @ExpectedContextJson NVARCHAR(MAX),
    @MembershipDecisionsJson NVARCHAR(MAX),
    @GroupVariantTypeDecisionsJson NVARCHAR(MAX),
    @ProductGroupName NVARCHAR(MAX) = NULL,
    @OriginalProposalJson NVARCHAR(MAX) = NULL,
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Els tres arguments Original finals són **només del grup**; evidències/riscos de membres/associacions als arrays propis. Manual: tres SQL NULL/risc nouNULL/confirmed_change-create; amb proposta: original del grup obligatori, fonts/risc nullable i accepted/corrected SQL. IDs derivats dels arrays, sense arguments redundants. Crear grup validat/actiu de la marca del creador, ID per comptador de marca; sense categoria/línia al grup. Associacions aprovades sense codi, trasllats/rèpliques preservant assignacions i rebutjos individuals explícits; transacció curta amb auditories/UUID comú. Error conegut desfà només l'intent, incertesa D238 intacta. Cap catàleg/fase3 nova, principalNULL amb zero finals, grups origen/codis conservats.

#### 6.19.6 Quatre conjunts de resposta

**D268:** capturats dins de l'operació, retornats només post-COMMIT:

| Ordre | Files | Contingut |
|---|---|---|
| 1 | Una | OperationId UNIQUEIDENTIFIER + ProductGroup complet7: ProductGroupId, ProductGroupName, BrandCode, PrimaryVariantTypeId, EstimatedRiskPercent, IsValidated, IsActive=1. |
| 2 | Una o més | ProductVariant complets dels SKU aprovats i traslladats. |
| 3 | Zero o més | ProductGroupVariantType completes creades i aprovades. |
| 4 | Zero o més | ProductVariantValue completes dels traslladats amb rèpliques actualitzades. |

Una mateixa alta de grup pot associar un o més tipus existents, N tipus produeixen N files al tercer conjunt, no N grups ni operacions separades. Zero tipus només si no hi ha valors conservats que els exigeixin. Buits retornats, no omesos. Rebutjats no als conjunts 2/4 però amb decisió auditada al mateix OperationId; catàlegs no retornats perquè no canviats. Cap èxit amb rollback; resultat incert segons D238.

### 6.20 Rebutjos no persistents de grup i pertinença

**D400:** els quatre rebutjos següents admeten discrepàncies de línia conegudes. D269–D272 conserven abasts/originals/claus/auditoria/resposta, sense crear/eliminar classificacions vigents o aprovar pertinences. No rebutjos implícits/cancel·lació manual auditada/excepció D390 per aprovar. Incidència pendent, D396/D402–D403 i altres controls intactes (§6.44).

#### 6.20.1 RejectProductGroupProposal

**D269:**

```text
dbo.RejectProductGroupProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX),
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Només decisió del grup proposat encara no creat. Original obligatori amb ProductGroupId JSON null; context revisat dels SKU originals, no donar per suficient una selecció corregida que n'hagi exclòs algun. Controls de sessió/permisos/reserva i context actual; única proposal_decision/proposal_review/rejected, originals/risc preservats, resultat i ambdós snapshots SQL NULL. Clau product_group no creat de §3.11.3, sense inventar ID. No grups creats/eliminats, SKU traslladats, valors canviats, comptadors/codis consumits. No rebutjos individuals implícits de membres o tipus; contracte conjunt separat definit posteriorment a §6.25. Cancel·lar preparació manual sense proposta no invoca aquest procediment. Èxit: una fila exactament OperationId UNIQUEIDENTIFIER post-COMMIT; conflicte/rollback sense decisió confirmada.

#### 6.20.2 RejectNewGroupVariantTypeProposal

**D270:**

```text
dbo.RejectNewGroupVariantTypeProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX),
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Rebutjar només proposta d'associació amb grup nou, no tipus de catàleg. Original obligatori amb ProductGroupId JSON null i tipus real coincident; context de creació amb membres originals proposats i tipus implicat, controls actuals contrastats. Única rejected amb clau group_variant_type no creat de §3.11.3, originals/risc conservats i snapshots/resultat SQL NULL. No cap alta/eliminació/trasllat/consum de codis o comptadors; no rebuig del grup/altres propostes. Si el tipus continua necessari per preservar assignacions, creació posterior bloquejada fins resolució, no eliminació de valors. Una fila exactament OperationId UNIQUEIDENTIFIER post-COMMIT. No és RejectGroupVariantTypeProposal de candidata persistent ni cobreix catàlegs sense ID.

#### 6.20.3 RejectNewGroupMembershipProposal

**D271:**

```text
dbo.RejectNewGroupMembershipProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX),
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Proposta no persistent, original obligatori amb mateix SKU/destí ProductGroupId JSON null; context de creació de cinc propietats amb SKU inclòs. Controls actuals abans d'una única rejected; originals/risc conservats i snapshots/resultat SQL NULL. SKU conserva grup/risc/validació/assignacions, mai esborra variant ni la deixa òrfena. Clau d'auditoria de pertinença identifica grup anterior real; null només destí a original, no PK/FK. No rebuig implícit de grup/tipus ni auditoria de descart manual. Una fila exactament OperationId UNIQUEIDENTIFIER post-COMMIT.

#### 6.20.4 RejectGroupMembershipMoveProposal

**D272:**

```text
dbo.RejectGroupMembershipMoveProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX),
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Proposta no persistent amb mateix SKU i destí existent complet. Context de set propietats de GetGroupMembershipMoveContext per al destí **original**, no un altre introduït com a correcció manual. Controls actuals i una única rejected amb originals/risc i snapshots/resultat SQL NULL; clau de grup anterior real i original preservant destí rebutjat. Sense trasllat, eliminació, desvalidació o canvi del risc/assignacions vigents. Una fila exactament OperationId UNIQUEIDENTIFIER post-COMMIT; conflicte/rollback sense rebuig confirmat, incert segons §6.16.1. Èxit significa rebuig registrat: no associar tipus ni desfer trasllat confirmat. Cancel·lació manual sense proposta no és aquest circuit.

### 6.21 Alta manual múltiple de tipus a un grup existent

**D401 i adaptació D380:** AddGroupVariantTypes admet línia coneguda sense resoldre-la. Dues signatures marca–grup, quatre blocs grup7/associacions8/membres/tipus seleccionats i resposta dues parts. Només tipus existents compatibles/grup existent, lot no buit/tot o res/cap associació existent ignorada. D273–D275, originals/riscs/D396/D402–D403 intactes; no SKU/valors/línies/principal/codis nous (§6.44/§6.45.4).

#### 6.21.1 AddGroupVariantTypes

**D273:**

```text
dbo.AddGroupVariantTypes(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdsJson NVARCHAR(MAX),
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Manual directe sense proposta: grup existent actiu, array no buit de tipus existents globals/marca compatibles/sense duplicats; marca exactament3 abans de convertir/grup positiu. Qualsevol associació existent, també candidata, invalida tot el lot i exigeix revisió, no ignorar/aprovar silenciosament; candidates pel seu circuit. Cada nova associació1/codi-risc-originalsNULL, una confirmed_change/create per fila/OperationId comú/totes o cap. Sense catàleg/valors SKU/codis/principal nous; fase2 no compta pel principal, zero finals mantéNULL/amb finals conserva tria vàlida. No exportables només per aquesta aprovació.

#### 6.21.2 GetGroupVariantTypeAdditionsContext

**D274:**

```text
dbo.GetGroupVariantTypeAdditionsContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdsJson NVARCHAR(MAX)
)
```

Mateixes condicions de grup/tipus existents compatibles, llista no buida/sense duplicats/associacions absents i validació de codis; error si incomplertes. Sessió/reserva, SNAPSHOT curt local i una fila ContextJson NVARCHAR(MAX) amb exactament quatre propietats:

| Propietat | Contingut |
|---|---|
| ProductGroup | Fila completa del grup existent. |
| ProductVariants | Tots els membres reals reduïts §6.17.2, inclosos retirats/pertinences pendents; [] si buit. |
| ProductGroupVariantTypes | Totes les associacions actuals completes; [] si cap. |
| VariantTypes | Definicions seleccionades completes sense repetir IDs. |

Nullable explícits/originals imbricats, sense assignacions SKU o catàleg de valors; no escriptura/codi/auditoria de lectura. No és el lector de candidata singular D246 malgrat tenir també quatre blocs.

#### 6.21.3 Resposta de l'alta múltiple

**D275 adaptat D380:** dos conjunts post-COMMIT capturats internament: una fila exactament OperationId UNIQUEIDENTIFIER; després1+ associacions completes creades, una per tipus. Vuit camps exactes: ProductGroupId, BrandCode, VariantTypeId, ParkodVariantCode, EstimatedRiskPercent, IsValidated, OriginalSourcesJson, OriginalProposalJson. Codi/risc/originalsNULL/indicador1. No èxit parcial/zero altes o grup-SKU-catàleg intactes retornats. Resposta incompleta D238; codi final només pel circuit FinalizeGroupVariantType.

### 6.22 Selecció o correcció del principal existent

#### 6.22.1 GetProductGroupPrimaryVariantTypeContext

**D276:**

```text
dbo.GetProductGroupPrimaryVariantTypeContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT
)
```

Grup existent actiu, marca exactament3 abans de convertir/grup positiu, sessió/reserva i SNAPSHOT curt local. Una fila ContextJson NVARCHAR(MAX), exactament tres propietats; ProductGroup7/ProductGroupVariantTypes8 per D380, sense membres/valors o dependència nova de Parkod:

| Propietat | Contingut |
|---|---|
| ProductGroup | Fila completa, inclòs principal actual. |
| ProductGroupVariantTypes | Totes les associacions actuals completes. |
| VariantTypes | Definicions completes referenciades per les associacions, sense IDs duplicats. |

[] si cap associació, null explícit/originals imbricats. Sense SKU/valors, principal depèn d'habilitacions, també amb grup buit. Lectura permesa encara que principal falti o sigui invàlid per preparar correcció; no canvi/codi/auditoria de lectura. Selecció desitjada separada.

#### 6.22.2 SetProductGroupPrimaryVariantType

**D277:**

```text
dbo.SetProductGroupPrimaryVariantType(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @PrimaryVariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

PrimaryVariantTypeId és argument obligatori **sense default**: SQL NULL només admissible amb zero habilitacions finals; amb una, aquell ID; amb diverses, un final compatible. Aquí NULL no significa conservar com el SelectedPrimary opcional de substitució/finalització. Verificar controls/codis/context i revalidar habilitacions/principal atòmicament; únic camp de negoci modificat ProductGroup.PrimaryVariantTypeId, risc/IsValidated intactes. Si canvi, una confirmed_change/update del grup, Before/After complets; sense associacions/codis/SKU/valors alterats.

Una fila OperationId + ProductGroup complet resultant, capturada dins de l'operació/post-COMMIT. Si després de **totes** les comprovacions és el mateix principal vàlid: cap UPDATE/auditoria, OperationId de resposta SQL NULL i grup intacte. Canvi real: UUID informat. Això no canvia EvaluationAuditEvent.OperationId NOT NULL: no existeix fila d'auditoria en no-op. Un context caducat o principal invàlid no es converteix en no-op correcte.

### 6.23 Correcció de valor d'una assignació ja validada

**Contrast E02 D380/D248/D278–D282:** signatures/ordre/tipus/defaults intactes. Set blocs de §6.15.3 amb assignació9/grup reduït3/associació reduïda5, no files completes7/8 en lloc dels reduïts. Mateixes respostes de dues parts i no-op/proposta sense canvi ja decidits; tots els procediments SKU–valor continuen depenent de Parkod (§6.45.3).

#### 6.23.1 GetVariantValueCorrectionContext

**D278:**

```text
dbo.GetVariantValueCorrectionContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @SelectedVariantTypeValueId INT = NULL
)
```

Exigir assignació existent IsValidated=1; error absent/pendent, aquestes tenen altres circuits. Valor **actual** sempre inclòs, seleccionat addicional si informat i mateix tipus, sense repetir ID. NULL només sense seleccionat addicional; valor nou desitjat separat. Una fila ContextJson NVARCHAR(MAX), reutilització expressa i exacta de les set propietats/camps de §6.15.3 però fila validada. JSON històrics de fila no esdevenen originals nous. Sessió/reserva/SNAPSHOT curt local, cap escriptura/auditoria de lectura ni exigència de codi final o prohibició nova de retirats. Correcció d'assignació, no reescriptura de significat del catàleg compartit; reversions ordinàries ja acordades, no un nou Desfer.

#### 6.23.2 Risc i originals en canvi efectiu

**D279:** només quan realment canvia el valor assignat: amb proposta nova acceptada/corregida, EstimatedRiskPercent/OriginalSourcesJson/OriginalProposalJson de la fila passen a risc/originals nous del backend; manual directe sense proposta, tots tres SQL NULL, no antic risc ni 0 inventat. IsValidated=1 després de confirmació/comprovacions. BeforeStateJson complet preserva tots els antics, After complet reflecteix la nova fila; auditoria anterior append-only intacta. No reescriure originals nous amb correccions/IDs generats, ni modificar camps físics. No aplicar aquesta substitució de metadades automàticament al cas sense canvi.

#### 6.23.3 Mateix valor final que l'actual

**D280:** després de contrastar context i validar l'operació, si l'ID existent seleccionat és el mateix actual:

| Cas | Fila vigent | Auditoria i OperationId de resposta |
|---|---|---|
| Manual sense proposta | Intacta, inclosos risc i originals antics. | Cap UPDATE/auditoria; OperationId SQL NULL. |
| Proposta nova expressament revisada | També intacta, sense sobreescriure risc/originals de fila. | Una proposal_decision/proposal_review accepted o corrected segons correspongui, originals/risc nous i DecisionResultJson real; snapshots ambdós SQL NULL; UUID informat. |

En el segon cas hi ha una nova decisió humana real, no lectura/intacte rutinari auditat. SQL NULL dels snapshots significa cap fila modificada, no absència d'assignació; no és confirmed_change sense canvi ni amplia l'excepció password_reset. Els nous originals només a l'esdeveniment, no sobre la fila intacta. NewValueJson duplicant valor existent continua conflicte/revisió, no reutilització silenciosa ni no-op per contingut.

#### 6.23.4 ConfirmVariantValueCorrection i dos conjunts

**D281:**

```text
dbo.ConfirmVariantValueCorrection(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @SelectedVariantTypeValueId INT = NULL,
    @NewValueJson NVARCHAR(MAX) = NULL,
    @OriginalProposalJson NVARCHAR(MAX) = NULL,
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Fila existent IsValidated=1 i grup real derivat, context/estat final verificats abans de canvis/no-op. **Exactament una via** ID existent del mateix tipus o NewValueJson: defaults no són acceptació implícita, tots dos NULL o informats invàlids. S'aplica expressament tot §6.10.1/D239/D236: objecte NumericValue/TextValue obligatoris, XOR segons ValueKind, normalització/unicitats/gramàtica decimal exacta, sense arrodonir, exponents o conversions d'unitats ni IDs inventats. No extrapolar a code1/TextValue legítim/història.

**D369 — línia pendent:** una discrepància present al context revisat entre Parkod.CLIGNE i ProductVariant.LineCode no és, per si sola, motiu per bloquejar aquesta correcció de valor o exigir abans el corrector de línia. La classificació variant–grup continua coherent i no canvia; es mantenen sessió/permisos/reserva/grup actiu, habilitació i compatibilitat de tipus/valor, context actual i atomicitat/auditoria habituals. Si el context rellevant ha canviat després de llegir-lo, cal nova revisió: no confondre un desajust conegut amb un canvi concurrent. Corregir el valor no resol ni aprova la discrepància, que continua visible mentre existeixi (§6.41). Sense nous paràmetres, conjunts de resposta o metadades de pendent.

OriginalProposalJson SQL NULL significa manual directe, fonts/risc originals també NULL; amb proposta nova els originals del backend són obligatoris segons §3.11.2, no els antics de la fila. Canvi efectiu segons §6.23.2: manual confirmed_change/update o proposta accepted/corrected; valor nou de catàleg si cal amb ID real i auditoria create, correcció/auditories atòmiques amb OperationId comú. Mentre s'edita, nou valor només al backend; cancel·lar no crea cap fila. Col·lisió exigeix revisió i selecció de l'ID existent, mai reutilització silenciosa. Valor anterior compartit preservat; no tipus/grup/codi/principal canviats ni fase 3 implícita.

Dos conjunts d'una fila, capturats dins de l'operació/post-COMMIT: primer OperationId + ProductVariantValue complet resultant; segon VariantTypeValue final complet existent/nou. Mateixos camps/tipus de §6.10.2 expressament reutilitzats, però OperationId de resposta pot ser SQL NULL **només** en no-op manual. Amb decisió de proposta sense canvi és UUID i fila de negoci intacta amb metadades antigues; amb canvi, UUID i metadades segons nova decisió. Resposta incompleta segons D238.

#### 6.23.5 RejectVariantValueCorrectionProposal

**D400:** discrepància de línia coneguda no bloqueja aquest rebuig sobre validada. D282 conserva íntegres assignació/risc/originals/catàlegs; no DELETE de candidata pendent. Incidència pendent, originals nous obligatoris, D396/D402–D403 i altres controls intactes (§6.44).

**D282:**

```text
dbo.RejectVariantValueCorrectionProposal(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @OriginalProposalJson NVARCHAR(MAX),
    @OriginalSourcesJson NVARCHAR(MAX) = NULL,
    @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL
)
```

Fila existent IsValidated=1; error absent/pendent. Original nou obligatori del backend amb format/IDs reals ja acordats, no històrics guardats. Context de GetVariantValueCorrectionContext sense seleccionat addicional, actual sempre inclòs; controls/context actuals abans d'auditar. Única proposal_decision/proposal_review/rejected amb nous originals/risc preservats, resultat i ambdós snapshots SQL NULL. Assignació/risc/validació/originals vigents intactes, cap catàleg creat/eliminat. Clau usa VariantTypeValueId actual real de la fila, no proposat/null; no DELETE com a candidata pendent de §6.15.4. Cancel·lació manual no és aquesta decisió. Una fila exactament OperationId UNIQUEIDENTIFIER post-COMMIT; conflicte versus incert segons §6.16.1.

### 6.24 Primera assignació manual de valor SKU

**Contrast E02 D380/D283–D284:** signatures intactes; set blocs adaptats de §6.15.3, ProductVariantValue JSON null obligatori i valors seleccionat o [] segons contracte. Context no admet reemplaçar grup3/associació5 per files completes. Dos conjunts OperationId+assignació9/valor5, sempre alta real; cap upsert/no-op nou (§6.45.3).

#### 6.24.1 GetNewVariantValueAssignmentContext

**D283:**

```text
dbo.GetNewVariantValueAssignmentContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @SelectedVariantTypeValueId INT = NULL
)
```

SKU/tipus existents, associació del grup real aprovada i compatible (pot tenir codi NULL). Exigir absència de ProductVariantValue per parella SKU–tipus; error si pendent o validada existent. Seleccionat existent opcional del mateix tipus. Sessió/reserva i SNAPSHOT curt local, sense escriptures/auditoria de lectura; una fila ContextJson NVARCHAR(MAX). Mateixos set noms/camps §6.15.3 expressament reutilitzats, amb dues diferències exactes: ProductVariantValue és JSON null obligatori (no omès/{}), VariantTypeValues només seleccionat existent o [] si no indicat. Resta de blocs intacta; valor nou desitjat separat al backend, no al context.

És una absència revisada, no IDs/FK nuls dins de fila SQL ni autorització d'upsert. Si una altra operació crea la fila abans de confirmar, nova revisió sense sobreescriure-la. El lector no crea el valor de catàleg; [] no impedeix preparar un valor nou per confirmar.

#### 6.24.2 ConfirmNewVariantValueAssignment i resposta

**D284:**

```text
dbo.ConfirmNewVariantValueAssignment(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @SelectedVariantTypeValueId INT = NULL,
    @NewValueJson NVARCHAR(MAX) = NULL
)
```

Primera alta manual directa sense proposta: fila encara absent, associació aprovada/compatible, context actual contrastat. Exactament ID existent del mateix tipus **o** NewValueJson, tots dos NULL o informats invàlids; reutilització expressa completa de §6.10.1/D239/D236, inclosa gramàtica decimal exacta, normalització i duplicats. Pot crear el VariantTypeValue nou en aquesta mateixa actuació, no cal alta a priori; Type sí existent. Cancel·lar formulari no crea res, alta concurrent de valor o assignació exigeix revisió/selecció explícita, sense reutilització/sobreescriptura silenciosa.

Crear ProductVariantValue amb IsValidated=1, risc/originals SQL NULL, grup real i valor amb ID real. Una confirmed_change/create per alta real, valor de catàleg si cal + assignació + auditories atòmics amb OperationId comú. Before SQL NULL/After complet de l'assignació, clau amb VariantTypeValueId JSON null només per absència anterior (§3.11.3), After/filera real amb FK no nul·la; no extrapolar null a ID de catàleg nou, que té identificador real. No modifica pertinença/associació/codi/principal ni finalitza fase 3.

Dos conjunts d'una fila, capturats internament/post-COMMIT: OperationId UNIQUEIDENTIFIER informat + ProductVariantValue complet creat; després VariantTypeValue final complet existent/nou (mateixos camps de §6.10.2, reutilització expressa). Sempre alta real i UUID, mai no-op. Fila pendent pels procediments de candidates; fila validada per correcció; no dues assignacions del mateix tipus/SKU ni correcció automàtica si l'absència ja no és vigent. Que el valor de catàleg sigui existent o nou és independent d'aquests tres estats de l'assignació.

### 6.25 Rebuig conjunt de propostes d'un grup encara no creat

**D400:** també permès amb discrepàncies de línia conegudes. Només decisions expresses D285–D289/una auditoria per decisió/UUID comú/tot o res, sense DML de negoci o aprovació de pertinences. Incidència pendent, originals/context complet i D396/D402–D403 conservats. Formes afectades encara E02, cap rebuig automàtic de fills/esborrany manual (§6.44).

#### 6.25.1 Abast, signatura i resposta de rebuig

**D285–D286 confirmats.** Una mateixa revisió pot confirmar conjuntament només els rebutjos marcats expressament: grup nou, pertinences i/o associacions grup–tipus proposades. Cada decisió conserva originals/risc propis, una auditoria per decisió i un OperationId comú. Tot o res, sense crear grups o associacions ni modificar classificacions vigents. No rebuig implícit del grup o dels fills, ni auditoria de descart d'esborrany manual. Aquest circuit cobreix el cas sense membres aprovats sense convertir-lo en una creació buida; no aprova membres ni tipus.

```text
dbo.RejectProductGroupCreationProposals(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ExpectedContextJson NVARCHAR(MAX),
    @MembershipRejectionsJson NVARCHAR(MAX),
    @GroupVariantTypeRejectionsJson NVARCHAR(MAX),
    @GroupRejectionJson NVARCHAR(MAX) = NULL
)
```

Els dos arrays són obligatoris, [] admès per l'àmbit sense rebutjos; GroupRejectionJson SQL NULL vol dir que no es rebutja el grup. **Almenys una decisió entre les tres entrades**, sense èxit buit o no-op. Controls de sessió/permisos/reserves aplicables i context actual contrastat en una transacció nova curta, segons §6.16.1. Originals no persistents autoritatius del backend, separats del context SQL; mai reconstruïts a partir de les fonts actuals.

Per cada decisió expressa, una proposal_decision/proposal_review/rejected amb originals/risc propis, DecisionResultJson/BeforeStateJson/AfterStateJson SQL NULL. Claus canòniques §3.11.3: grup/associació nous amb context original i ProductGroupId JSON null; pertinença amb ProductVariantId i grup anterior real. Ometre una proposta no és rebutjar-la. No consum de comptador/codi, trasllats, eliminació de candidates persistents o de catàlegs. Auditories atòmiques amb UUID comú; conflicte detectat desfà tot el lot, sense decisions parcials ni rejected humana fictícia.

Èxit: **una única fila amb exactament OperationId UNIQUEIDENTIFIER informat**, capturada dins de l'operació i emesa només post-COMMIT. Timeout/connexió perduda segueixen D238, no rollback presumptiu ni reenviament automàtic. Els quatre rebutjos individuals de §6.20 es conserven; no comparteixen un OperationId entre crides independents per aquest sol fet.

#### 6.25.2 Tres entrades JSON de rebuig

**D287 confirmat:** propietats exactes i obligatòries en cada objecte:

| Entrada | Forma | Propietats exactes |
|---|---|---|
| GroupRejectionJson | SQL NULL si no es rebutja el grup; altrament objecte JSON. | OriginalProposalJson, OriginalSourcesJson, OriginalEstimatedRiskPercent. |
| MembershipRejectionsJson | Array, [] si cap rebuig exprés de pertinença. | ProductVariantId, OriginalProposalJson, OriginalSourcesJson, OriginalEstimatedRiskPercent. |
| GroupVariantTypeRejectionsJson | Array, [] si cap rebuig exprés d'associació. | VariantTypeId, OriginalProposalJson, OriginalSourcesJson, OriginalEstimatedRiskPercent. |

- OriginalProposalJson és **objecte obligatori no nul** segons §3.11.2, no una cadena JSON escapada ni un esborrany manual.
- OriginalSourcesJson és array de §3.11.1 o JSON null; [] i null conserven significats diferents.
- OriginalEstimatedRiskPercent és número JSON exactament representable en DECIMAL(5,2), entre 0 i 100, o JSON null, sense arrodoniment.
- ProductVariantId/VariantTypeId són IDs reals coincidents amb els originals; ProductGroupId del destí no creat continua JSON null dins de l'original. No inventar IDs de catàleg ni ampliar aquesta excepció.
- Sense propietats addicionals/repetides, IDs repetits dins de cada array o propietat Decision: totes les entrades són rebutjos expressos. La reiteració contextual d'un SKU entre originals independents no és una segona decisió de pertinença.
- Metadades individuals, no heretades de les del grup, ni originals reescrits amb una selecció corregida. Cap taula/columna o nul·litat física nova.

#### 6.25.3 Context conjunt de cinc propietats

**D288 confirmat:** mateixa forma de cinc propietats que §6.19.2, amb abast específic de rebuig, no les precondicions d'aprovació d'una creació:

| Propietat | Contingut |
|---|---|
| ProductVariants | SKU implicats; cada entrada té exactament ProductVariant complet i Parkod amb CLIGNE/SourceIsPresent locals. |
| SourceGroups | Grups actuals d'aquests SKU: ProductGroup complet, ProductVariants amb tots els membres reduïts §6.17.2 i ProductGroupVariantTypes completes. |
| ProductVariantValues | Totes les assignacions dels SKU implicats, pendents/validades i de retirats incloses. |
| VariantTypes | Definicions completes dels tipus rebutjats i dels referenciats per associacions dels grups actuals o assignacions incloses. |
| VariantTypeValues | Files completes referenciades per les assignacions incloses. |

SKU implicats = unió dels ProductVariantIds originals del grup si es rebutja, dels ProductVariantId amb rebuig de pertinença i dels ProductVariants originals de les propostes grup–tipus rebutjades. No limitar-se a una selecció manual corregida que exclogui membres originals. Una referència compartida entre originals apareix una vegada al conjunt corresponent; això no autoritza deduplicar entrades de decisió invàlides. SourceGroups una vegada per identitat completa, tipus/valors una vegada per ID; [] on poden ser buits, nullable explícits/originals imbricats, sense valors de SKU no implicats ni context parcial.

Tot l'estat actual en un SNAPSHOT curt només de VARIANTS_PARKOD, sense fonts originals/ID futur/comptador congelat. **No exigir creador aprovat ni que l'agrupació proposada sigui acceptable per crear-se:** s'està rebutjant, no aprovant. Els originals de rebuig d'entrada no s'injecten al context SQL; originals històrics de les files completes sí s'hi conserven com a estat actual.

#### 6.25.4 GetProductGroupCreationRejectionContext

**D289, signatura/resposta confirmades:**

```text
dbo.GetProductGroupCreationRejectionContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @MembershipRejectionsJson NVARCHAR(MAX),
    @GroupVariantTypeRejectionsJson NVARCHAR(MAX),
    @GroupRejectionJson NVARCHAR(MAX) = NULL
)
```

Validar D287/almenys una decisió, derivar SKU/tipus dels originals sense arrays redundants o argument creador. Controls de sessió/permisos/reserves aplicables; una fila **ContextJson NVARCHAR(MAX)** amb exactament §6.25.3, tots els blocs del mateix SNAPSHOT curt local i transacció tancada abans de revisar. Fila requerida absent o format invàlid: error, mai context parcial. No canvi de negoci, associacions/catàlegs creats, identificadors/codis consumits o auditoria de lectura. La confirmació posterior contrasta estat actual nou, no escriu sobre aquest SNAPSHOT.

### 6.26 Correcció d'una candidata de fase 2 canviant el tipus

**D399, formes adaptades D380:** dos correctors i lector existent sense categoria, grup7/associacions8. B nou reutilitza quatre blocs D246, B existent cinc blocs D293; NewVariantTypeJson quatre propietats intactes. A0/codiNULL/original/sense assignacions al grup també pendents/validades/de retirats. Estats/metadades/auditories de B D177–D179 conservats; B ja aprovada intacta, sense copiar-hi les condicions diferents de §6.27. Incidència pendent, no SKU/valors/línies/pertinences/principal canviats o codi nou. D396/D402–D403 intactes; no A aprovada/amb assignacions (§6.44/§6.45.4).

#### 6.26.1 Abast i NewVariantTypeJson

**D290 confirmat, concretant D176–D177:** primer circuit limitat a candidata grup–tipus A d'un grup existent, substituïda expressament per un tipus B nou. NewVariantTypeJson NVARCHAR(MAX) és objecte amb exactament quatre propietats obligatòries:

| Propietat | Contingut |
|---|---|
| Type | Text, normalitzat/no buit, límit 20 i comparació d'unicitat acordats. |
| Characteristics | Text, normalitzat/no buit, límit 80 acordat. |
| ValueKind | Text numeric o text, sense default; open_type exigeix text. |
| BrandCode | JSON null per global o marca del grup per exclusiu compatible. |

Sense ID, risc, validació, codi o valors inicials de catàleg dins d'aquest objecte; sense propietats addicionals/repetides. La parella normalitzada Type + Characteristics continua única globalment, sense BrandCode/ValueKind a la clau. Definició només en memòria mentre s'edita; SQL crea ID real en confirmar. Col·lisió concurrent exigeix revisió, no reutilització silenciosa d'un altre tipus. No amplia altres circuits automàtics/manuals, l'alta independent exclusiva o originals sense ID no definits.

**A admissible en els dos correctors:** associació existent del grup complet, IsValidated=0/ParkodVariantCode NULL, cap ProductVariantValue que la referenciï i original disponible. Compartir Type o codis no implica substitució; selecció expressa A → B. A aprovada o amb assignacions requereix el circuit corresponent de §6.11, no aquest de candidata. Les assignacions d'A en altres grups no s'eliminen ni impedeixen per si soles corregir aquesta associació admissible.

#### 6.26.2 CorrectGroupVariantTypeProposalWithNewType

**D291, signatura/context/resposta confirmats:**

```text
dbo.CorrectGroupVariantTypeProposalWithNewType(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @NewVariantTypeJson NVARCHAR(MAX)
)
```

Marca MAX validada a longitud3 abans de convertir/grup marca–ID positiu i actiu, sessió/permisos/reserva/context actual contrastats. **Quatre blocs de GetGroupVariantTypeProposalContext de §6.15.6 per A**, no cinc del cas B existent. B nova desitjada separada al backend, sense ID futur al context.

Una transacció curta crea VariantType B amb ID real, elimina només l'associació candidata A i crea associació B IsValidated=1/codi NULL, conservant risc i JSON originals d'A sense reescriure'ls. D177: auditoria d'alta del tipus B confirmed_change/create; una decisió corrected d'A amb Before complet/After SQL NULL/resultat B; alta d'associació B confirmed_change/create amb After complet, no una segona decisió sobre la mateixa proposta. OperationId comú per als tres esdeveniments. Catàleg A/usos/historial preservats. Cap valor SKU, codi nou o principal canviat; coherència final revalidada sense reparar-la silenciosament.

Dos conjunts d'una fila, capturats internament/post-COMMIT: **OperationId informat + ProductGroupVariantType B complet**, després **VariantType B complet amb ID real nou**. Sempre canvi real/UUID; no no-op. Col·lisió/context caducat: rollback/nova revisió, sense reutilització silenciosa. Qualsevol alta parcial d'aquest intent es desfà; un COMMIT aliè/anterior no.

#### 6.26.3 CorrectGroupVariantTypeProposalWithExistingType

**D292, signatura i resposta confirmades:**

```text
dbo.CorrectGroupVariantTypeProposalWithExistingType(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

A admissible de §6.26.1; B de catàleg existent, diferent/compatible. A=B no és no-op o aprovació implícita. Mateixos controls/marca exactament3/grup positiu/context actual; cinc blocs exactes de §6.26.4. Efectes D177–D179:

| Estat de l'associació B al grup | Canvi i auditoria |
|---|---|
| Absent | Crear B aprovada a fase 2/codi NULL amb risc/originals d'A; A corrected/eliminada i B confirmed_change/create. |
| Candidata pendent admissible | Revisar expressament ambdós originals; A corrected/eliminada i B aprovada segons D179, accepted si s'accepta tal com estava proposada. Originals/risc de B propis, no barrejats amb A. |
| Ja aprovada | B completament intacta, també codi/risc/originals; només A corrected/eliminada auditada, sense entrada per B intacta. |

No catàleg creat/modificat, assignació SKU, codi nou o canvi de principal. Conservar catàleg A/usos/historial; validar coherència final. En una única transacció actual curta, una decisió corrected d'A i, només quan correspon, auditoria de canvi real de B, OperationId comú. Resposta en **dos conjunts d'una fila**: OperationId informat + ProductGroupVariantType B complet resultant, després VariantType B complet existent; incloure B intacta a resposta no n'autoritza auditoria fictícia. Captura interna/post-COMMIT, no relectura posterior; sempre correcció efectiva d'A, no no-op.

#### 6.26.4 Context A/B de cinc propietats i preservació dels SKU

**D293 confirmat després de l'aclariment sobre assignacions:**

| Propietat | Contingut |
|---|---|
| ProductGroup | Fila completa del grup existent, inclòs principal actual. |
| ProductVariants | Tots els membres reals reduïts §6.17.2, amb Parkod CLIGNE/SourceIsPresent locals. |
| VariantTypes | Definicions completes d'A i B, una vegada per ID. |
| GroupVariantTypeToReplace | Fila completa de l'associació candidata A. |
| ReplacementGroupVariantType | Fila completa de l'associació B o JSON null explícit si encara no està associada al grup. |

A/B han d'existir al catàleg i ser diferents; l'absència admesa és només associació B, mai el tipus B. B pendent és fila completa amb els seus originals, no null/{} o propietat omesa. Membres retirats/pertinences pendents inclosos, [] si grup buit. Null explícit als camps nullable/JSON originals imbricats, sense duplicats o propietats addicionals. Sense assignacions SKU, valors de catàleg o associacions d'altres tipus: no es modifiquen en aquest circuit; SQL comprova igualment que A no tingui assignacions i revalida principal final sense canviar-lo. Mateix SNAPSHOT curt només nova base, després confirmació en transacció actual nova. No és la substitució completa de set blocs §6.11, ni el context conjunt de rebuig malgrat tenir també cinc propietats.

**Aclariment confirmat en conversa:** si qualsevol SKU del grup revisat té assignació a A, pendent/validada o d'un SKU retirat, la correcció de candidata no és admissible. No eliminar ni traslladar assignacions per fer-la possible. Rebuig tècnic amb rollback conegut conserva per aquest intent **totes les assignacions a A, també les del ProductGroup revisat**, l'associació A, B preexistent, catàlegs i historial; cap canvi parcial ni rejected humana fictícia. Altres operacions confirmades conserven els seus canvis. Resultat de connexió incert segueix D238, no aquesta garantia de rollback conegut. Si es vol substituir A amb assignacions, preparar B preservant A i utilitzar §6.11 amb decisions individuals de retirada; no canvi automàtic de tipus/valors dels SKU.

#### 6.26.5 GetGroupVariantTypeProposalCorrectionContext

**D294, nom/signatura/resposta confirmats expressament després del tall D293.** D293 aprovava les cinc propietats; la petició anterior de documentació no n'era una confirmació implícita. La proposta conservada esdevé ara contracte de disseny confirmat, no procediment desplegat:

```text
dbo.GetGroupVariantTypeProposalCorrectionContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT
)
```

Sessió/permisos/reserves/activitat, marca exactament3 abans de convertir/grup positiu, A candidata sense assignacions al grup i B existent/diferent/compatible. **Una fila ContextJson NVARCHAR(MAX)** amb cinc blocs de §6.26.4 del mateix SNAPSHOT curt local, tancat abans de revisar. Associació B absent JSON null; error sense context parcial si falta dada requerida/condició invàlida. Sense canvis/altes/reserva de codis/auditoria de lectura. Només B existent; B nova manté lector D246. D294 confirmat, adaptació D380 no l'estén a A aprovada (§6.27.3); implementació/permisos/proves pendents.

### 6.27 Substitució expressa d'A aprovada a fase 2 per B candidata

**D398, adaptació D380:** dues signatures sense categoria, cinc blocs amb grup7/associacions8, dos conjunts associació8/tipus5. Línia coneguda no bloqueja aquest cas reduït, retirada conjunta d'A inclosa. Condicions D295–D296 intactes: cap assignació d'A/B al grup, cap canvi de SKU/valors/línies/principal/codis, incidència pendent/no pertinença validada. D396/D402–D403 conservats. D404 cobreix després §6.11, no converteix aquest circuit en una substitució universal.

#### 6.27.1 Abast i ConfirmGroupVariantTypePhase2Replacement

**D295 confirmat, concretant el principi D180 ja acordat.** Grup existent i tipus A/B reals, diferents i compatibles: A és associació IsValidated=1/ParkodVariantCode NULL; B és candidata IsValidated=0/ParkodVariantCode NULL amb original disponible. Totes dues del mateix grup complet i **cap de les dues amb ProductVariantValue al grup**, encara pendent/validada o d'un SKU retirat. No s'exigeix que els catàlegs siguin buits: valors no assignats i usos en altres grups es conserven. No és la correcció d'A candidata de §6.26 ni la substitució completa amb retirades/valors/codi de §6.11.

```text
dbo.ConfirmGroupVariantTypePhase2Replacement(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Marca MAX exactament3 abans de convertir/grup positiu-actiu, sessió/token/permisos/reserva verificats. Context §6.27.2 en **nova transacció actual curta**, coordinació existent/no escriptures sobre SNAPSHOT de revisió. Admissibilitat/compatibilitat/principal final revalidats sense modificar-lo: associacions sense codi no alteren recompte final. Cap SelectedPrimary, NewVariantTypeJson o decisions de retirada SKU afegits.

Operació humana expressa, tota o cap:

| Objecte | Canvi | Auditoria segons D180/§3.11 |
|---|---|---|
| Associació A ja aprovada | Retirar només ProductGroupVariantType A; catàleg A/usos/historial conservats. | confirmed_change/retire, Before complet amb antics risc/originals, After SQL NULL. DecisionOutcome i camps de proposta/resultat de l'esdeveniment SQL NULL; no rejected de candidata ni reescriptura de l'aprovació antiga. |
| Associació candidata B | Aprovar explícitament B segons revisió dels seus originals, IsValidated=1/codi NULL; conservar risc/originals propis, no copiar els d'A ni posar risc a zero. | proposal_decision/proposal_review, accepted si s'accepta tal com proposada, originals/risc de B i resultat generat per SQL, Before/After complets. |

Auditories i canvis atòmics amb un mateix OperationId generat per SQL. **No es modifiquen assignacions SKU, catàlegs, pertinences, codis o principal**, ni es creen associacions noves: B candidata ja existeix. Si apareixen assignacions d'A o B al grup, canvia el context o falla qualsevol control, error/rollback conegut sense retirada/aprovació parcials, sense rejected humana fictícia i sense tocar les assignacions. COMMIT anteriors/aliens preservats; resposta perduda segueix resultat incert D238, no rollback assumit. No eliminar valors per fer passar el procediment ni convertir-lo automàticament en el circuit complet.

**Resposta D295:** dos conjunts d'una fila, capturats dins de l'operació i emesos només post-COMMIT efectiu:

| Ordre | Camps |
|---|---|
| 1 | OperationId UNIQUEIDENTIFIER informat + ProductGroupVariantType B complet resultant segons §3.6. |
| 2 | VariantType B complet existent segons §3.4. |

Cap no-op autoritzat: la retirada expressa d'A i aprovació de B són canvis reals, UUID informat. El segon conjunt retorna el catàleg verificat, no una alta/modificació del tipus B ni una auditoria fictícia. Respostes incompletes segons §8.6.

#### 6.27.2 Context de cinc propietats per A aprovada/B candidata

**D296 confirmat:** reutilització expressa de la forma D293, però amb admissibilitat diferent. Mateixos cinc noms exactes, no un context universal d'A/B:

| Propietat | Contingut |
|---|---|
| ProductGroup | Fila completa del grup existent, inclòs principal actual. |
| ProductVariants | Tots els membres reals reduïts §6.17.2, amb Parkod CLIGNE/SourceIsPresent locals. |
| VariantTypes | Definicions completes d'A i B, diferents i compatibles, una vegada per ID. |
| GroupVariantTypeToReplace | Associació A completa, IsValidated=1/codi NULL. |
| ReplacementGroupVariantType | Associació B completa, IsValidated=0/codi NULL, amb original disponible. |

**B associació obligatòria: no pot ser JSON null, absent o ja aprovada en aquest circuit.** A/B han d'estar al mateix grup; les dues sense assignacions SKU al grup. El context no inclou assignacions/valors de catàleg, però SQL comprova igualment aquella absència, també en confirmar. Membres retirats/pertinences pendents inclosos, [] si grup buit; null explícit als camps nullable i originals imbricats, sense duplicats/propietats addicionals. No afegir valors d'altres SKU ni llegir la font original. Cinc blocs del mateix SNAPSHOT curt només de VARIANTS_PARKOD, tancat abans de revisar. La lectura no retira A ni aprova B.

#### 6.27.3 GetGroupVariantTypePhase2ReplacementContext

**D296, signatura/context/resposta confirmats:**

```text
dbo.GetGroupVariantTypePhase2ReplacementContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @VariantTypeIdToReplace INT,
    @ReplacementVariantTypeId INT
)
```

Sessió/permisos/reserves/activitat i marca exactament3 abans de convertir/grup positiu; estats A/B i absència d'assignacions §6.27.1–§6.27.2. **Una fila ContextJson NVARCHAR(MAX)** amb cinc propietats de §6.27.2, mateix SNAPSHOT curt local/tancat abans de revisar. Condició invàlida/dada requerida absent: error/no context parcial. Sense canvi/reserva de codis/auditoria de lectura. No ampliar lector D294 d'A candidata; aquí A aprovada. D295 confirma en nova transacció actual/context contrastat. Disseny, no SQL desplegat o etapa0 tancada.

### 6.28 Cicle de sessió, reserva i tancament administratiu

**Adaptació D380 contrastada:** reserva marca–grup de dos camps, dues signatures sense categoria, resposta reserva/alliberament4, sessió segura5 i llista administrativa8. Autenticació/caducitat/privilegis/no heartbeat/tancament forçat D297–D306 conservats. No dependència nova de Parkod, secrets, auditoria rutinària o OperationId afegits (§6.45.4).

#### 6.28.1 Regles comunes de D297–D306

Tots els objectes són a VARIANTS_PARKOD.dbo, contractes de disseny pendents de SQL/permisos/proves. Sessió/token obligatoris de §6.13.1: 32 bytes exactes abans de convertir, només SHA-256 a SQL, secrets exclosos de contextos/logs/auditoria. Cap identitat lliure d'autor aportada pel client. IsAdmin, quan s'exigeix, és el vigent; un AppAccount desactivat pot conservar sessió i permisos vigents segons D112. No confondre AppAccount.IsActive amb ProductGroup.IsActive.

Operacions de sessió en transaccions curtes, coordinades amb ús de sessió/reserves i inici batch. Respostes capturades dins de l'operació i emeses només després del COMMIT efectiu; cap transacció durant formularis. Cap contrasenya/hash/token a les respostes següents. Sessions/reserves rutinàries no generen EvaluationAuditEvent ni retornen OperationId; el tancament administratiu forçat és l'excepció D302. Errors de sessió/longitud/token: cap èxit fictici. Timeout o resposta incompleta: no assumir rollback ni reenviar automàticament.

Els dos procediments de reserva/alliberament reutilitzen exactament una fila amb aquests quatre camps:

| Camp de resposta | Tipus |
|---|---|
| AppSessionId | UNIQUEIDENTIFIER informat |
| ReservedBrandCode | NVARCHAR(3) NULL |
| ReservedProductGroupId | INT NULL |
| LastActivityAtUtc | DATETIME2(3) informat |

Reserva: els dos Reserved* informats. Alliberament: tots dos SQL NULL. Acció expressa renova activitat, no crides automàtiques/clics tècnics convertits en heartbeat. Reserva lògica/no congela dades/consulta-exportació intactes. Reservar exigeix grup actiu; alliberar/revocar/netejar no. No AppAccountId afegit a aquesta resposta.

#### 6.28.2 CloseAppSession — D297

```text
dbo.CloseAppSession(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX)
)
```

Arguments obligatoris sense defaults. Sessió existent/vigent i token verificats; no exigeix administrador ni compte encara actiu. Elimina només aquella AppSession, alliberant-ne la reserva atòmicament. No busca una sessió nova pel compte, no tanca altres sessions ni desfà operacions ja confirmades. Coordinar amb operacions en curs/inici batch sense KILL o rollback remot. L'app descarta edicions manuals no validades i deixa d'utilitzar el token; candidates automàtiques persistents, dades confirmades i historial intactes. Desconnexió RDS no equival a aquesta crida.

Resposta: una fila AppSessionId UNIQUEIDENTIFIER de la sessió eliminada, capturada dins de l'operació/post-COMMIT. Sense auditoria/OperationId. Sessió absent/caducada o token incorrecte: error genèric de sessió no vàlida, no presentar-ho com a tancament confirmat per aquesta crida; neteja per demanda independent ja acordada. Resposta perduda: tancament no confirmat, no reenviament o rollback presumptiu.

#### 6.28.3 RenewAppSession — D298

```text
dbo.RenewAppSession(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX)
)
```

Arguments obligatoris sense defaults. Només per interacció real, mai temporitzador/heartbeat/activitat automàtica. SQL comprova sessió no caducada/token i actualitza únicament LastActivityAtUtc amb hora UTC SQL; client no aporta data/durada. Conserva reserva i compte/permisos. No ressuscita sessions caducades, revocades o afectades per restabliment concurrent; no exigeix IsAdmin o IsActive=1 del compte si la sessió segueix vigent.

Resposta: una fila amb exactament AppSessionId UNIQUEIDENTIFIER i LastActivityAtUtc DATETIME2(3), informats, captura interna/post-COMMIT. Sense OperationId/auditoria. Absent/caducada/token incorrecte: error genèric; resultat incert sense reenviament automàtic.

#### 6.28.4 ReserveProductGroup — D299

```text
dbo.ReserveProductGroup(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT
)
```

Arguments obligatoris sense defaults. Sessió/token vigents, marca exactament3 abans de convertir i ID positiu/marca–grup. Grup existent **actiu**, també IsValidated0/reservar no aprova. Neteja per demanda de caducades; comprovació/reserva coordinades amb desactivació/altres reserves:

| Estat | Resultat |
|---|---|
| Sessió sense reserva i grup disponible | Reservar grup. |
| Mateixa sessió ja reserva aquest grup | Conservar reserva. |
| Sessió reserva un altre grup | Error, cal alliberament explícit; no canvi silenciós. |
| Altra sessió vigent reserva el grup | Error, no prendre/expulsar reserva aliena. |

Renova LastActivityAtUtc per acció real i retorna els quatre camps de §6.28.1, tots informats. No IsAdmin requerit, aprovació de negoci/codis/auditoria de clics o OperationId. No locks de formulari, resultat incert sense reenviament.

#### 6.28.5 ReleaseProductGroup — D300

```text
dbo.ReleaseProductGroup(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT
)
```

Arguments obligatoris sense defaults. Sessió/token vigents, marca exactament3 abans de convertir/ID positiu/grup existent marca–ID. **No exigir ProductGroup.IsActive=1 per alliberar**. Grup explícit evita alliberar reserva actual d'un grup diferent per petició antiga, no versió/idempotència.

| Reserva actual | Resultat |
|---|---|
| Coincideix amb el grup | Posar els dos camps de reserva a SQL NULL. |
| Cap reserva | Conservar absència sense error. |
| Un altre grup | Error; conservar reserva actual. |

En els dos casos d'èxit, renovar LastActivityAtUtc per acció expressa i retornar §6.28.1 amb els dos Reserved* SQL NULL. Sense OperationId/auditoria. No logout: sessió/token vigents encara impedeixen conciliació. No confirma edicions; sortir sense validar descarta manuals/no candidates persistents-decisions-historial. Estat capturat d'aquesta operació/no immutabilitat posterior. Errors sense alliberament parcial, incertesa segons regles comunes.

#### 6.28.6 GetAppSessionForcedClosureContext — D301–D303

```text
dbo.GetAppSessionForcedClosureContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @TargetAppSessionId UNIQUEIDENTIFIER
)
```

Arguments obligatoris sense defaults. Els dos primers són de l'administrador; mai es demana el token de l'afectat. Sessió/token/IsAdmin vigent; destinatària existent, no caducada i diferent de la pròpia (sortida pròpia per CloseAppSession). Compte destinatari pot estar desactivat. Una fila ContextJson NVARCHAR(MAX) amb exactament:

| Propietat | Camps exactes, tots obligatoris |
|---|---|
| AppAccount | AppAccountId, LoginName, IsActive, IsAdmin del destinatari. |
| AppSession | Exactament cinc camps segurs del destinatari: AppSessionId, AppAccountId, LastActivityAtUtc, ReservedBrandCode, ReservedProductGroupId. |

Reserva absent amb JSON null explícit; compte/sessió corresponents i sense PasswordHash/SessionTokenHash/token. Un mateix SNAPSHOT curt local tancat abans de revisió. No tancament, reserva, renovació de l'activitat observada o auditoria de lectura. Fila absent/caducada: error sense context parcial ni sessió substituta del mateix compte. Canvi detectat d'activitat/reserva/context exigeix revisió nova al confirmador.

#### 6.28.7 ForceCloseAppSession — D304

```text
dbo.ForceCloseAppSession(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @TargetAppSessionId UNIQUEIDENTIFIER,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Arguments obligatoris sense defaults. Nova transacció curta actual: revalidar sessió/token/IsAdmin de l'administrador, destinatària existent/vigent/diferent de la pròpia i context exacte D303, amb identitats coincidents. Compte destinatari desactivat o sense reserva admès. Canvis detectats d'activitat, reserva o compte exigeixen revisió. Una auditoria D302 (§3.11) i eliminació exclusivament de la sessió destinatària/alliberament de la seva reserva, tot atòmic. No modificar contrasenyes, permisos, classificacions, candidates persistents, decisions confirmades o reserva d'un altre usuari; no transferir-la a l'administrador.

Coordinació amb usos de sessió en curs, sense cancel·lar transaccions alienes. Una operació pot completar-se abans del tancament; després SQL rebutja l'ús de la sessió revocada. La finestra remota pot seguir visible: no es tanca Windows/RDS ni s'esborra remotament la memòria; a la següent crida l'app detecta revocació i descarta les edicions manuals pendents. No desfà COMMIT anteriors.

Resposta: una fila amb exactament OperationId UNIQUEIDENTIFIER informat i AppSessionId UNIQUEIDENTIFIER informat **de la sessió eliminada**, captura interna/post-COMMIT. Absent/caducada/context canviat/permís insuficient: error sense auditoria fictícia o cerca d'una sessió nova del compte. Error amb rollback conegut desfà només eliminació/auditoria d'aquest intent. Resposta incerta segons §6.28.9.

#### 6.28.8 GetAppSessionsForForcedClosure — D306

```text
dbo.GetAppSessionsForForcedClosure(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX)
)
```

Arguments obligatoris sense defaults. Sessió/token/IsAdmin vigent. **Altres** sessions no caducades, amb reserva o sense/també comptes desactivats/pròpia exclosa. Exactament vuit camps: AppSessionId UNIQUEIDENTIFIER, AppAccountId INT, LoginName NVARCHAR(80), IsActive BIT, IsAdmin BIT (del compte), LastActivityAtUtc DATETIME2(3), ReservedBrandCode NVARCHAR(3) NULL, ReservedProductGroupId INT NULL. Reserva dos camps informats o tots dosNULL; zero files si cap altra sessió vigent. Signatura intacta.

SNAPSHOT curt local, sense modificació/renovació dels observats/auditoria/OperationId ni secrets. Seleccionar fila no autoritza tancament: després llegir D303 i confirmar D304. Llistat de preparació ordinària administrativa, no recuperació de peticions incertes.

#### 6.28.9 Incidències de tancament forçat — D305

Es descarta l'ampliació proposada de GetUncertainOperationContext a app_session i qualsevol lector específic GUI de recuperació de ForceCloseAppSession. Investigació d'aquest cas fora de l'app, amb accés SQL administratiu autoritzat/auditoria. App avisa de resultat incert, sense reenviament o rollback presumptiu. **GetUncertainOperationContext continua vigent per als usos prèviament aprovats**, no es retira ni se n'amplia el fallback. D302 continua auditant el tancament forçat. La idea de tancar totes les sessions/verificar inconsistències com a manteniment no aprova un procediment massiu, reparació automàtica o execució SQL nous; requeriria definir i autoritzar aquell manteniment separadament, només al destí del projecte.

### 6.29 Administració ordinària de comptes i vies SQL excepcionals

#### 6.29.1 GetAppAccounts — D307

```text
dbo.GetAppAccounts(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX)
)
```

Arguments obligatoris sense defaults. Sessió/token/IsAdmin vigent; tots els comptes actius/desactivats, també propi, sense canvis de compte/permisos/contrasenya/sessió/reserva. Un conjunt ordenat per LoginName, una fila per compte amb exactament AppAccountId INT, LoginName NVARCHAR(80), IsActive BIT i IsAdmin BIT, tots informats. SNAPSHOT curt local; cap PasswordHash/token/dada de sessió, reserva, auditoria o OperationId. Selecció no substitueix controls actuals de confirmació. Aquests **quatre camps auditables** es reutilitzen expressament a continuació; ProductGroup.IsActive no els amplia.

#### 6.29.2 CreateAppAccount — D308

```text
dbo.CreateAppAccount(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @LoginName NVARCHAR(MAX),
    @PasswordHash NVARCHAR(MAX),
    @IsActive BIT,
    @IsAdmin BIT
)
```

Tots obligatoris, sense defaults/SQL NULL. Alta ordinària per sessió/token/IsAdmin vigent, no bootstrap. LoginName: blancs normalitzats, no buit, <=80, únic CI_AI també entre desactivats; no upsert/reutilització/correcció silenciosa d'un altre compte. AppAccountId generat per IDENTITY existent. Dos indicadors explícits, sense alterar defaults físics 0.

Hash autodescriptiu Argon2id generat en Python abans de cridar, sense transacció durant càlcul. SQL valida representació/longitud admeses <=255 abans de convertir, sense truncar/normalitzar/canviar grafia del hash. No contrasenya en clar a SQL ni secrets a logs/contextos/auditoria. Detalls executables de comprovació de format pendents, no verificació de contrasenya per SQL ni dependència nova aprovada.

Alta i una auditoria confirmed_change/create de app_account atòmiques: clau AppAccountId real, actor usuari derivat de sessió, Before SQL NULL/After quatre camps auditables sense PasswordHash; DecisionOutcome/risc/fonts/proposta/resultat SQL NULL, OperationId SQL informat. No segon password_reset per la contrasenya inicial. No crea AppSession ni login automàtic.

Resposta: una fila OperationId UNIQUEIDENTIFIER + AppAccountId INT, LoginName NVARCHAR(80), IsActive BIT, IsAdmin BIT, tots informats, captura interna/post-COMMIT. Duplicat/error amb rollback no deixa alta/auditoria parcials; resultat incert sense reenviament automàtic.

#### 6.29.3 SetAppAccountAccess — D309

```text
dbo.SetAppAccountAccess(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @TargetAppAccountId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @IsActive BIT,
    @IsAdmin BIT
)
```

Obligatoris sense defaults/SQL NULL. ExpectedContextJson té exactament AppAccount amb els quatre camps de la fila seleccionada de GetAppAccounts, conservats tal com revisats i separats dels indicadors desitjats. ID ha de coincidir amb TargetAppAccountId real positiu; propietats obligatòries/exactes, cap addicional/duplicada, comparació de text exacta de §6.8.1, no només CI_AI. No nou lector redundant ni hash al context.

Sessió/token/IsAdmin vigent, compte existent i context contrastat en transacció curta actual. Modifica només IsActive/IsAdmin. Protecció atòmica de l'últim administrador actiu respecte de canvis concurrents, no recompte antic de pantalla. Es permet modificar el propi compte amb aquesta protecció. Desactivar impedeix nous logins però no revoca sessió/reserva; retirar IsAdmin elimina permisos administratius immediatament, no expulsa sessió. No canvis LoginName/contrasenya.

Canvi efectiu: una confirmed_change/update de app_account, Before/After quatre camps complets auditables, actor de sessió, clau real/OperationId SQL; camps de proposta/risc/resultat/DecisionOutcome SQL NULL. Resposta amb exactament els cinc camps/tipus de §6.29.2. Mateixos indicadors després de controls/context: cap UPDATE/auditoria, compte intacte, OperationId de resposta SQL NULL. Context canviat no és no-op; aquesta nul·litat no altera EvaluationAuditEvent.OperationId NOT NULL.

#### 6.29.4 ResetAppAccountPassword — D310–D311

```text
dbo.ResetAppAccountPassword(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @TargetAppAccountId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @NewPasswordHash NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL. Sessió/token/IsAdmin vigent; compte existent, també desactivat. Reutilitza expressament l'AppAccount de quatre camps de §6.29.3, ID coincident i context exacte. Hash nou segons §6.29.2, generat abans de la crida, sense contrasenya en clar ni hash al context. No exigeix hash/contrasenya anteriors.

Una transacció curta contrasta context, estableix hash nou, elimina la sessió existent del compte si n'hi ha/allibera reserva i audita. No modifica LoginName/IsActive/IsAdmin ni dades de negoci/candidates. **Administrador pot restablir la pròpia contrasenya**: actor verificat/capturat abans de revocar-ne també sessió/reserva; ha de tornar a entrar si el compte és actiu. No és canvi propi per tècnic ordinari. Revocar no tanca Windows/RDS ni desfà COMMIT; la següent crida del destinatari detecta sessió invàlida i descarta edicions manuals, sense reutilitzar context antic.

D310: el context no inclou hash i no promet detectar un altre restabliment que només l'hagi canviat. Si dos restabliments expressos superen els controls, SQL els serialitza, cadascun auditat i **l'últim hash confirmat és el vigent**. No és reenviament/idempotència. Cada restabliment acceptat revoca la sessió existent encara que el hash aportat coincideixi amb l'actual; no no-op que ometi aquella revocació.

Una sola confirmed_change/password_reset de app_account, clau real, actor administrador de sessió, Before/After SQL NULL segons l'excepció aprovada; DecisionOutcome i camps de risc/fonts/proposta/resultat SQL NULL, cap secret. Sense auditoria app_session addicional. Hash/revocació/auditoria atòmics. Resposta: una fila exactament OperationId UNIQUEIDENTIFIER i AppAccountId INT, informats, captura interna/post-COMMIT. Errors/incertesa segons regles vigents, sense nou fallback ni reenviament.

#### 6.29.5 BootstrapAppAccount — D312

```text
dbo.BootstrapAppAccount(
    @LoginName NVARCHAR(MAX),
    @PasswordHash NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL. **Fora GUI, només identitat SQL administrativa autoritzada**, mai compte tècnic ordinari; no rep AppSession/token perquè encara no existeix compte. Només AppAccount completament buida, inclosos desactivats: comprovar buit/inserir atòmicament perquè dues crides concurrents no creïn dos inicials. Mateixes validacions de nom/hash de §6.29.2, hash generat fora SQL sense scripts/logs de secrets. Genera AppAccountId i fixa IsActive=1/IsAdmin=1, sense contrasenya predeterminada/compte de reserva. No recupera un compte existent ni crea sessió; després login normal.

Una confirmed_change/create de app_account amb ActorKind=process/ActorProcessName=bootstrap/ActorAppAccountId SQL NULL, clau real, Before NULL/After quatre camps sense PasswordHash; camps de proposta/risc/resultat/DecisionOutcome NULL, OperationId SQL. No password_reset addicional inicial. Resposta exactament els cinc camps/tipus de §6.29.2, indicadors 1, captura interna/post-COMMIT. Alta/auditoria totes o cap; resultat incert sense reenviament o rollback presumptiu, investigació autoritzada sense procediment de recuperació nou implícit.

#### 6.29.6 RecoverAppAdministratorPassword — D313

```text
dbo.RecoverAppAdministratorPassword(
    @TargetAppAccountId INT,
    @NewPasswordHash NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL, ID positiu. Fora GUI i només identitat SQL administrativa autoritzada, no compte ordinari ni sessió de l'app. Destinatari existent amb IsAdmin=1 actual; no recupera un tècnic promovent-lo ni crea comptes. Hash segons §6.29.2, sense contrasenya anterior/compte de reserva ni login automàtic. No canvia LoginName/IsActive/IsAdmin: administrador desactivat continua sense poder iniciar sessió.

Transacció curta estableix hash, revoca sessió existent/reserva si n'hi ha i audita, respectant coordinació amb login/altres restabliments. D310 reutilitzat expressament: operacions admissibles serialitzades, cadascuna auditada, últim hash confirmat vigent. Una confirmed_change/password_reset de app_account, ActorKind=process/ActorProcessName=admin_recovery/ActorAppAccountId SQL NULL, clau real, Before/After SQL NULL, camps de proposta/risc/resultat/DecisionOutcome NULL i cap secret/app_session addicional. Resposta exactament OperationId UNIQUEIDENTIFIER + AppAccountId INT informats, captura interna/post-COMMIT. Atomicitat/error/incertesa segons §6.29.4, sense reenviament automàtic o nou fallback GUI.

### 6.30 Canvi d'abast de marca i de representació del tipus

#### 6.30.1 GetVariantTypeBrandScopeChangeContext — D314

```text
dbo.GetVariantTypeBrandScopeChangeContext(
    @VariantTypeId INT
)
```

ID positiu obligatori, sense default. Només identitat SQL administrativa autoritzada fora GUI, mai compte ordinari; sense AppSession/token. Tipus existent. Una fila amb **únicament ContextJson NVARCHAR(MAX)** que reutilitza expressament els quatre blocs de §6.14.6: VariantType complet, VariantTypeValues complets també no assignats, ProductGroupVariantTypes completes candidates/aprovades i Usages exactes D211, pendents/validats/retirats inclosos. D328 no hi afegeix la columna de presentació del lector ordinari. Arrays []/null explícit/originals imbricats, sense context parcial. SNAPSHOT curt només nova base, tancat abans de revisar; no canvi, reserva, auditoria o lectura original.

Aquest lector prepara impacte de D142, no autoritza el canvi. L'acord D142 situa el **canvi excepcional** fora GUI pel risc sobre abast compartit i pel nivell SQL d'autorització; no prohibeix que el catàleg GUI ordinari mostri definició/usos actius. La lectura protegida conserva també les associacions de grups inactius necessàries per als controls.

#### 6.30.2 ChangeVariantTypeBrandScope — D315

```text
dbo.ChangeVariantTypeBrandScope(
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @NewBrandCode NVARCHAR(MAX)
)
```

Arguments obligatoris sense defaults; SQL NULL admès **només NewBrandCode**, amb significat global. Via D142 per tipus amb assignacions existents, també pendents/de SKU retirats; sense assignacions correspon circuit ordinari. Només identitat SQL administrativa autoritzada, fora GUI, amb impacte/autorització previs; ser IsAdmin de l'app o haver llegit el context no és suficient. ExpectedContextJson és exactament D314. Marca informada: CMARQ vàlid de tres caràcters abans de convertir, sense truncar/corregir silenciosament.

Nova transacció curta actual sota coordinació exclusiva per tipus/ordre global: rellegir/contrastar context i totes les associacions. NULL global és compatible amb marques diverses; marca informada exigeix tots els grups d'aquella marca, **també els inactius**. Incompatibilitat rebutja, no eliminar associacions/valors o canviar codis per encaixar. Només VariantType.BrandCode canvia, no Type/Characteristics/ValueKind, IDs, pertinences, assignacions, validacions, principal, codis o originals històrics. No reserva de tots els grups o transacció durant impacte.

Canvi: una confirmed_change/update de variant_type, clau VariantTypeId, Before/After complets dels cinc camps, ActorKind=process/ActorProcessName=variant_type_brand_scope_change/ActorAppAccountId SQL NULL. Camps de proposta/risc/resultat/DecisionOutcome NULL, OperationId SQL informat. Resposta una fila OperationId UNIQUEIDENTIFIER + VariantType complet, captura interna/post-COMMIT. Mateixa marca després de **tots** els controls: cap UPDATE/auditoria, tipus intacte, OperationId resposta NULL. Context canviat no és no-op. Error/rollback conegut sense parcial ni desfer COMMIT anteriors; incert sense reenviament/rollback presumptiu.

#### 6.30.3 SetUnassignedVariantTypeBrandScope — D316

```text
dbo.SetUnassignedVariantTypeBrandScope(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @NewBrandCode NVARCHAR(MAX)
)
```

Obligatoris sense defaults; SQL NULL només NewBrandCode/global. Tècnic ordinari amb sessió/token vigents, sense IsAdmin requerit. Tipus existent; ExpectedContextJson reutilitza exactament els quatre blocs de GetVariantTypeEditorialContext, **no** InactiveProductGroupsJson de presentació. Cap ProductVariantValue del tipus enlloc, encara pendent o de retirat. Valors de catàleg encara no assignats no bloquegen BrandCode: no confondre amb ValueKind. Marca CMARQ vàlida de tres caràcters abans de convertir.

Transacció curta/coordinació exclusiva per tipus: contrastar context i totes les associacions, actives o històriques inactives, segons compatibilitat de §6.30.2. Modifica només BrandCode. Si apareixen assignacions després de revisar, error/nova revisió; no salt automàtic a la via excepcional. Sense desvalidació/eliminació/codis/principal/originals canviats.

Canvi: una confirmed_change/update de variant_type amb actor usuari de sessió, Before/After complets, clau/OperationId SQL, camps de proposta/risc/resultat/DecisionOutcome NULL. Resposta una fila OperationId + VariantType complet, captura interna/post-COMMIT. Mateixa marca després de tots els controls de context/elegibilitat: cap UPDATE/auditoria, OperationId resposta NULL. Incert/error segons regles comunes.

#### 6.30.4 SetVariantTypeValueKind — D317

```text
dbo.SetVariantTypeValueKind(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @VariantTypeId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @NewValueKind NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL; sessió/token de tècnic ordinari, sense IsAdmin requerit. Tipus existent, context exacte de quatre blocs del lector editorial ordinari, sense la columna de presentació. numeric/text validats abans de convertir a NVARCHAR(7); open_type exigeix text. Cap default, normalització de blancs o collation específica de ValueKind aprovat.

Després de contrastar context i validar valor admès, **si ja coincideix**: no-op sense UPDATE/auditoria, OperationId resposta NULL i tipus intacte, encara que hi hagi usos. No canvi de representació ni excepció al bloqueig. Context caducat/valor invàlid no són no-op.

Si hi ha canvi efectiu, rebutjar amb qualsevol VariantTypeValue (encara no assignat) **o** qualsevol ProductGroupVariantType.IsValidated=1, en qualsevol grup també inactiu, fase 2 sense codi/valors inclosa. Comprovació/canvi atòmics respecte d'altes de catàleg/aprovacions, amb coordinació exclusiva per tipus. Només ValueKind canvia; no conversions, eliminació de catàleg, desvalidació/retirada d'associacions o reescriptura d'originals de candidates. D142 no és aplicable.

Canvi: una confirmed_change/update de variant_type, actor usuari verificat, Before/After cinc camps, clau/OperationId SQL informat i camps de proposta/risc/resultat/DecisionOutcome NULL. Resposta una fila OperationId UNIQUEIDENTIFIER + VariantType complet, captura interna/post-COMMIT. Errors/incertesa segons regles comunes, cap reenviament automàtic.

### 6.31 NormalizeWhitespace: signatura interna — D318

```text
dbo.NormalizeWhitespace(
    @Value NVARCHAR(MAX)
) RETURNS NVARCHAR(MAX)
```

Argument sense default, SQL NULL admès/retorna SQL NULL. Funció interna de controls SQL d'etapa 0, no procediment App–SQL, algoritme d'agrupació, sessió, auditoria o OperationId. Comportament D48 preservat: exactament Unicode White_Space, cada seqüència a U+0020 i trim dels extrems; un blanc especial aïllat també es converteix. U+200B/U+FEFF no són blancs i es conserven. Resta de grafia exacta, accents/majúscules/puntuació/unitats intactes, sense truncar/conversió d'unitats; idempotent. Només blancs retorna cadena buida, no NULL.

La funció no decideix obligatorietat, límits o unicitat: controls corresponents després de normalitzar i abans de desar, amb comparació per bytes exactes/longitud. Camps aprovats de §3.8, rèplica Type i LoginName de §3.12; no ampliar a ValueKind/codis/còpia Parkod/legacy. NVARCHAR(MAX) no amplia les longituds dels camps de destí. Signatura/comportament confirmats, DDL/implementació/proves compatibles 2017 pendents.

### 6.32 Edició descriptiva del nom del grup — D319–D320

**Adaptació D380 contrastada:** signatura marca–grup sense categoria, context i resposta grup7. Nom descriptiu/normalització/NULL/no-op/risc i validació D319–D320 conservats. Sense fonts consultades en editar o lector nou; D276 només aporta el bloc ProductGroup (§6.45.4).

```text
dbo.SetProductGroupName(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @ExpectedContextJson NVARCHAR(MAX),
    @ProductGroupName NVARCHAR(MAX)
)
```

Obligatoris sense defaults; SQL NULL només ProductGroupName significa **nom sense informar**, no regeneració; NULL en creació conserva significat d'automàtic. Reutilitzar només bloc ProductGroup complet de GetProductGroupPrimaryVariantTypeContext D276, tal com revisat/separat del nom desitjat. ExpectedContextJson exactament ProductGroup de **set camps** de §3.2, claus coincidents/nullables explícits; no altres dos blocs, propietats addicionals/duplicades o desitjat injectat.

Sessió/token de tècnic ordinari; marca exactament3 abans de convertir/ID positiu/grup existent **actiu**. Reserva aliena vigent bloqueja/altre grup reservat exigeix alliberament explícit, reserva opcional/sense canvi silenciós. Nova transacció curta/context contrastat/integritat vigent: no reparar o canviar principal ni deixar estat final invàlid.

Nom informat normalitzat amb §6.31/no buit/<=150, sense truncament/unicitat/número afegit/fonts/generació automàtica. Només ProductGroupName canvia: identitat/composició/tipus/valors/codis/principal/risc/validació intactes; línies pròpies dels SKU intactes, cap línia del grup inventada. Provisional continua provisional/validat continua validat, no aprovació comercial o reagrupació.

Canvi: una product_group/confirmed_change/update, clau BrandCode/ProductGroupId i actor verificat, Before/After **set camps**, proposta/risc de decisió/resultat/DecisionOutcomeNULL/UUID informat. Resposta una fila OperationId UNIQUEIDENTIFIER + grup complet7 capturada dins/post-COMMIT. Mateix nom exacte normalitzat després de tots els controls: cap UPDATE/audit/UUID de resposta; case/accents diferents són canvi real malgrat CI_AI. Context canviat/inactiu no són no-op, error/incertesa segons regles vigents.

### 6.33 Desactivació administrativa de grups buits

**Adaptació D380/D386 contrastada:** selectors només marca/totalitat, tres signatures sense categoria, grup7/marca–ID. Candidats set camps+HasActiveReservation calculat, resposta de desactivació quatre camps, consulta d'inactius set camps; ordre marca–ID. Controls/cinc ResultCode/ordre D330/història conservats (§6.45.4).

#### 6.33.1 Camp, abast i límits — D321–D322

ProductGroup.IsActive BIT NOT NULL DEFAULT(1), independent de risc/validació/sense rèpliques o estat per marca. **No s'elimina físicament cap grup.** Només admin de l'app amb sessió/token/IsAdmin vigent, per marca o totalitat D386. Buit = zero ProductVariant de la PK marca–grup, retirats/pendents inclosos, no zero presents. No moure/esborrar SKU per forçar elegibilitat.

Sense reserva de sessió vigent, també pròpia; no alliberar-la/expulsar ningú en silenci. No buscar un altre grup o reactivar automàticament. Referències, associacions, principal, codis, risc, validació i historial conservats; controls de marca/ValueKind històrics intactes. Desactivat fora de l'operativa ordinària, consultable només pel circuit administratiu/històric; cap contracte de reactivació aprovat. No estalvi de dades ni garantia de rendiment nul: fila/índexs/dependències persisteixen.

Una transacció curta per grup amb actualització/auditoria atòmiques, sense transacció global del lot o bloqueig deliberat de taules. Grups no elegibles queden intactes amb motiu, no una rejected humana. COMMIT anteriors/aliens mai desfets per error posterior. L'app conserva el conjunt revisat de candidats per executar-lo, sense nova taula/versionat/ID de petició o UUID global del lot.

#### 6.33.2 GetEmptyProductGroupDeactivationCandidates — D323

```text
dbo.GetEmptyProductGroupDeactivationCandidates(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX) = NULL
)
```

Sessió/token obligatoris/IsAdmin vigent; únic filtre opcional BrandCode NVARCHAR(MAX)=NULL, exactament aquests abasts:

| BrandCode | Abast |
|---|---|
| SQL NULL | Totalitat de ProductGroup del projecte. |
| Informat | Marca. |

Marca informada exactament3 abans de convertir, buit no significa totalitat; cap filtre per categoria pròpia/deduïda d'un grup buit. IsActive1/cap ProductVariant/retirats-pendents inclosos. Incloure també reservats per mostrar motiu, sense alliberar-los.

Un conjunt ordenat **BrandCode/ProductGroupId**, exactament **set camps complets de ProductGroup + HasActiveReservation BIT calculat informat** de sessió no caducada. Sense camp físic/propietat de ProductGroup nova o identitat de compte/token/hash retornats. Zero files si cap candidat; SNAPSHOT curt local/tancat abans de revisar/sense canvi-reserva-auditoria-OperationId.

No congela estat o amplia lot amb candidats posteriors. Cada fila revisada proporciona ProductGroup de set camps per D324, **sense HasActiveReservation dins del bloc**; indicador de presentació, reserva actual comprovada a SQL en executar.

#### 6.33.3 DeactivateEmptyProductGroup — D324/D330

```text
dbo.DeactivateEmptyProductGroup(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL. ExpectedContextJson exactament ProductGroup de set camps de D323, claus coincidents/nullable explícits/no propietats addicionals o duplicades. HasActiveReservation fora del bloc, no versió del context. Sessió/token/IsAdmin a cada crida, marca exactament3 abans de convertir i ID positiu/marca–grup.

**Ordre D330, no resultat nou afegit:**

| Pas | Comprovació/resultat |
|---|---|
| 1 | Autenticació, permisos, arguments i estructura del context; error si fallen. |
| 2 | Grup existent; error si falta. |
| 3 | Si ja IsActive=0: already_inactive. |
| 4 | Si context canviat: context_changed. |
| 5 | Si qualsevol ProductVariant assignada: not_empty. |
| 6 | Si reserva de sessió vigent, també pròpia: reserved. |
| 7 | Altrament, canviar només IsActive 1 → 0 i auditar: deactivated. |

Nova transacció curta/coordinació amb incorporacions, trasllats i reserves perquè no hi hagi interval desprotegit entre comprovació i canvi. Els altres camps, associacions, codis i historial intactes; no desvalidació, eliminació, alliberament o transferència. Tots els resultats controlats es capturen dins de l'operació i s'emeten després del COMMIT efectiu.

**Resposta exacta d'una fila:**

| Camp | Tipus |
|---|---|
| OperationId | UNIQUEIDENTIFIER NULL, informat només per deactivated. |
| BrandCode | NVARCHAR(3) informat |
| ProductGroupId | INT informat |
| ResultCode | NVARCHAR(32) informat |

ResultCode només deactivated, not_empty, reserved, already_inactive o context_changed. Els quatre sense canvi no fan UPDATE ni auditoria i retornen OperationId SQL NULL; already_inactive no atribueix aquella desactivació a aquesta crida ni és èxit de mutació amb context antic. Grup/context invàlids, manca de permís o error tècnic no són un codi controlat fictici.

Només deactivated: una product_group/confirmed_change/update d'admin verificat, TargetKeyJson **BrandCode/ProductGroupId**, Before/After **set camps** (IsActive1/0), OperationId SQL nou per grup. Proposta/risc de decisió/resultat/DecisionOutcomeNULL, no auditar associacions/SKU intactes o canviar nul·litat de l'UUID d'auditoria. Originals/snapshots històrics intactes.

Error amb rollback conegut no deixa canvi/auditoria parcials d'aquest intent. Timeout o resposta perduda/incompleta: resultat incert d'aquell grup i aturada del lot, cap reenviament/rollback presumptiu ni decisió humana fictícia. Conservar COMMIT anteriors, sense convertir incertesa en not_empty/reserved o altra omissió coneguda.

#### 6.33.4 GetInactiveProductGroups — D325

```text
dbo.GetInactiveProductGroups(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX) = NULL
)
```

Sessió/token/IsAdmin vigent, mateixos **dos** abasts i validació de marca D323. Un conjunt amb exactament **set camps** de ProductGroup IsActive0/sense filtre IsValidated, ordre **BrandCode/ProductGroupId**, zero files si cap. SNAPSHOT curt local/tancat abans de mostrar/sense modificació-reserva-auditoria-OperationId.

Consulta administrativa/històrica, no opció perquè un tècnic inclogui inactius als selectors normals. No reactiva ni autoritza ús ordinari. Estat actual no atribueix la desactivació a una petició concreta ni substitueix auditoria/criteris de resultat incert. Sense lector de recuperació addicional o garantia d'idempotència.

#### 6.33.5 Orquestració i informe del lot

L'app consulta D323, conserva/revisa el conjunt i executa crides individuals D324, sense afegir-hi grups nous després. Resultats controlats permeten continuar, errors no controlats de permisos/sessió/arguments/infraestructura aturen; timeout/resposta perduda també aturen amb resultat incert. Resum dels desactivats/no desactivats i motius, distingint no processats o resultat incert d'un resultat SQL conegut. OperationId de cada canvi només, cap UUID global nou. No transacció durant revisió ni COMMIT global que desfaci els anteriors. Activitat de sessió no renovada artificialment per les crides automàtiques del lot.

És un lot administratiu interactiu, **no** conciliació batch ni nou planificador/reintent intern. No requereix expulsar tots els tècnics; altres grups poden seguir en ús, amb coordinació curta pels afectats. Sessió admin activa continua excloent la conciliació batch com qualsevol sessió. Si es retira IsAdmin o caduca sessió, la següent crida falla i el lot s'atura amb els COMMIT anteriors conservats. Logs tècnics anglesos i missatges GUI francesos; materialització/rendiment/permisos i proves pendents.

### 6.34 Adaptació transversal de ProductGroup.IsActive — D326–D330

**Tall de formats D379, no diccionari vigent:** G9/R5, reserva amb categoria i claus triples següents substituïts estructuralment per D380 (§6.42.4). IsActive/risc/validació i garanties d'activitat/història conservats, snapshots antics intactes. Matriu65 com a traçabilitat, contrast actual E02/E04.

#### 6.34.1 Formats confirmats — D326

| Element | Canvi confirmat |
|---|---|
| Grup actual complet | Nou camps de §3.2; afegir IsActive també a SourceGroup.ProductGroup, DestinationGroup.ProductGroup i SourceGroups de creació/rebuig. No canviar nombre/noms dels blocs. |
| Grup reduït SKU–valor | Conservar exactament els cinc camps §6.15.3: BrandCode, CategoryCode, ProductGroupId, LineCode, IsValidated. Activitat comprovada a SQL, sense ampliar aquest JSON. |
| Altres taules/claus | No rèplica d'IsActive a ProductVariant/ProductGroupVariantType/ProductVariantValue ni canvi de PK/FK/TargetKeyJson/ObjectKeyJson. AppAccount.IsActive independent i intacte. |
| Originals/històric | No injectar IsActive als formats originals aprovats, snapshots antics o JSON de fonts. Snapshots nous de grup complet sí tenen nou camps. |
| Context actual antic de vuit camps | Error/lectura nova, no completar assumint IsActive=1. No confondre'l amb un snapshot històric immutable. |
| Signatures ordinàries | Sense paràmetre nou IsActive; les creacions el fixen a 1 i la desactivació només per circuit administratiu. |

#### 6.34.2 Operativa ordinària — D327

Cerques/lectures/selectors ordinaris exigeixen IsActive=1 al **grup objecte de l'acció**, també per clau coneguda o administrador que utilitzi el procediment ordinari. No exigir IsValidated=1 o tenir membres; actiu buit continua operatiu. Aprovacions/correccions/trasllats/incorporacions/associacions/finalitzacions/principal/nom i reserva revaliden activitat dins de transacció/coordinació juntament amb controls existents, també abans de no-op.

Si el grup s'ha desactivat mentre un formulari/proposta era obert, error de grup inactiu sense canvi/auditoria d'aquell intent. No reactivar, redirigir a un altre grup, reutilitzar revisió antiga o generar rejected humana automàtica. Tornar a consultar opcions actives. Propostes no persistents amb aquell destí perden revisió sense reescriure originals. Candidates persistents del grup es conserven i no s'aproven/corregeixen/rebutgen per vies ordinàries mentre inactiu. No grup existent/IsActive inventats en propostes de grup nou encara sense fila; els grups actuals revisats conserven el seu context corresponent.

No aplicar aquest filtre indiscriminadament a referències històriques de catàleg, auditoria o alliberament de sessió: són casos diferents, no grups de destinació utilitzables.

#### 6.34.3 Catàlegs compartits — D328

Aplicació exacta a §6.14.6 i §6.30: context editorial de tipus segueix quatre blocs amb totes les associacions, i el lector ordinari retorna a més InactiveProductGroupsJson de presentació en la mateixa fila/SNAPSHOT. No nova taula/camp físic/cinquè bloc o paràmetre als confirmadors. Aquests només reben ContextJson. Lector SQL protegit conserva només ContextJson; context de valor continua tres blocs.

La GUI no mostra grups inactius com a usos operatius, destinacions o enllaços; pot explicar bloqueig per ús històric sense llistar-los. No amagar tipus/valors compartits ni ignorar associacions inactives per compatibilitat BrandCode o bloqueig de ValueKind. Els controls SQL consulten estat actual i tots els usos pertinents; la metadata no és autorització ni reserva.

#### 6.34.4 Administració, alliberaments i auditoria — D329

GetInactiveProductGroups consulta nou camps sense activar/operar. GetUncertainOperationContext manté paràmetres/permisos/vies, grup actual amb IsActive=0 com objecte de nou camps, no SQL NULL; claus reals inalterades. Històric original retornat intacte i D305 preservat, cap fallback nou.

CloseAppSession, ReleaseProductGroup, ForceCloseAppSession, ResetAppAccountPassword i RecoverAppAdministratorPassword **no exigeixen grup actiu per alliberar/revocar**, conservant tots els altres controls. Tampoc filtrar per grup actiu la neteja de sessions caducades, inclosos login/inici de conciliació. Una reserva caducada pot seguir físicament fins a la neteja per demanda i no equival a reserva vigent. Això no permet reservar, reutilitzar o reactivar un grup inactiu.

Auditoria de desactivació D324: un confirmed_change/update per grup, Before/After nou camps 1/0, altres camps intactes, no After SQL NULL ni UUID global. Resultats sense desactivació sense auditoria/OperationId. Errors sense canvi al log tècnic, no decisions humanes fictícies. No reescriure snapshots/originals anteriors ni introduir restauració/reactivació automàtiques. Cap contracte de reactivació aprovat.

#### 6.34.5 Concurrència, integracions i respostes — D330

Exigir conjuntament «IsActive=0 implica zero ProductVariant» i «cap nova reserva vigent sobre inactiu». Desactivació, trasllats, incorporacions i reserves comparteixen coordinació per fer comprovació/canvi atòmics, respectant ordre global tipus → SKU → comptador → grup, esperes finites/transaccions curtes. No locks de formulari ni taules senceres deliberadament. Recursos/modes executables, índexs/permisos/deadlocks i proves continuen pendents: no garantia de concurrència ja demostrada.

Ordre de resultats D324 exactament §6.33.3; resultats controlats continuen, error no controlat/incertesa aturen §6.33.5. Cap ampliació automàtica del conjunt, reenviament, sessió mantinguda per heartbeat, rollback global o expulsió de tots els tècnics. Aquest lot no canvia l'exclusió global batch/sessions.

| Integració | Adaptació confirmada, no autorització d'execució |
|---|---|
| Conciliació inicial/completa/parcial | Grup nou actiu/no reutilització-reactivació d'inactius. D361–D363: només entrada local, sense escriure vuit camps o presència; càrrega/absències externes. |
| Correcció tècnica de línia | Destí existent actiu o nou actiu; D363 revalida només la CLIGNE de còpia, sense escriptura de còpia o relectura original. Altres garanties de classificació conservades, detall §6.38/§6.40. |
| Descoberta/selectors | Només grups actius com candidats; IsValidated i presència no substitueixen IsActive. |
| Generador Parkod existent | Exclusió explícita d'inactius a la lectura de variants, sense exportador nou/intervenció original o veto global de SynchronizationStatus. |
| ProductGroupCounter/registre de codis | No reduir/reiniciar/reciclar després de desactivar; referències internes conservades. |
| SynchronizationStatus | Cinc camps/tipus i cap estat de desactivació; D364 redefineix els dos Parkod com publicació externa de còpia, data també parcial. No atribuir-li una invariància antiga de significat d'origen. |

Client exigeix respostes completes: no inventar IsActive=1/camps o [] per metadata absent. Lector editorial D328 exigeix dues columnes coherents del mateix SNAPSHOT. Mutació amb resposta perduda/incompleta segueix resultat incert, no èxit per haver rebut només una part. Contextos, signatures i matriu són disseny; DDL, permisos, integracions, dades humanament validades i proves continuen pendents.

#### 6.34.6 Matriu consolidada de contractes afectats

Revisió de **65 procediments: 44 del tall D296 + 21 de D297–D325**, més NormalizeWhitespace interna separada. No canvis de nom/ordre/tipus/defaults als paràmetres ja confirmats per causa d'IsActive. G9 = grup complet nou; R5 = grup reduït SKU–valor de cinc camps. Control operatiu d'activitat al grup objecte de l'acció, no exclusió de referències històriques.

| Contracte(s) operatius amb grup complet — 27 | Context/lectura i resposta adaptats |
|---|---|
| GetGroupVariantTypeProposalContext | G9 dins dels quatre blocs. |
| ApproveGroupVariantTypeProposal, RejectGroupVariantTypeProposal | Consumir G9; respostes d'associació/OperationId intactes. |
| GetGroupVariantTypeReplacementContext, ConfirmGroupVariantTypeReplacement | G9 dins dels set blocs; resposta final de tres camps intacta. |
| GetGroupVariantTypeFinalizationContext, FinalizeGroupVariantType | G9 dins dels sis blocs; resposta final de tres camps intacta. |
| GetGroupMembershipMoveContext, ConfirmGroupMembershipMove | Origen/destí G9, comprovació activa de grups operatius; respostes SKU/assignacions intactes. |
| GetProductGroupCreationContext, ConfirmProductGroupCreation | SourceGroups G9; grup creat/primer conjunt G9 amb IsActive=1. Resta de conjunts intactes. |
| RejectProductGroupProposal, RejectNewGroupVariantTypeProposal, RejectNewGroupMembershipProposal | Estat actual dels grups existents del context actualitzat; no inventar fila de destí nou ni reescriure originals. Respostes intactes. |
| RejectGroupMembershipMoveProposal | Context de destí original G9; desactivació caduca revisió, no rejected automàtica. |
| GetGroupVariantTypeAdditionsContext, AddGroupVariantTypes | G9 dins del context de quatre blocs; respostes d'alta intactes. |
| GetProductGroupPrimaryVariantTypeContext, SetProductGroupPrimaryVariantType | G9 en context i resposta del setter. Lector segueix permetent revisar principal invàlid d'un grup actiu. |
| GetProductGroupCreationRejectionContext, RejectProductGroupCreationProposals | SourceGroups G9, originals/rebutjos/respostes intactes. |
| CorrectGroupVariantTypeProposalWithNewType | Context de candidata amb G9, dos conjunts associació/tipus intactes. |
| CorrectGroupVariantTypeProposalWithExistingType, GetGroupVariantTypeProposalCorrectionContext | G9 dins dels cinc blocs A/B; respostes intactes. |
| GetGroupVariantTypePhase2ReplacementContext, ConfirmGroupVariantTypePhase2Replacement | G9 dins dels cinc blocs; respostes d'associació/tipus intactes. |
| SetProductGroupName | Consumeix i retorna G9, reutilitzant el bloc D276. |

| Altres grups de contractes | Adaptació exacta |
|---|---|
| GetUncertainOperationContext — 1 | CurrentStateJson G9 també inactiu, mai NULL per inactivitat; historial/permisos/signatura/fallback intactes. |
| GetVariantValueProposalContext, ConfirmVariantValueProposal, RejectVariantValueProposal, GetVariantValueCorrectionContext, ConfirmVariantValueCorrection, RejectVariantValueCorrectionProposal, GetNewVariantValueAssignmentContext, ConfirmNewVariantValueAssignment — 8 | R5/respostes intactes; activitat del grup real comprovada a SQL. Retirat no implica grup buit. |
| ReserveProductGroup — 1 | Nou control actiu/coordinat; cap canvi de resposta o signatura. |
| GetVariantTypeEditorialContext — 1 | Única resposta prèvia ampliada: dues columnes ContextJson/InactiveProductGroupsJson, context intern de quatre blocs intacte. |
| CorrectVariantTypeText, GetVariantTypeBrandScopeChangeContext, ChangeVariantTypeBrandScope, SetUnassignedVariantTypeBrandScope, SetVariantTypeValueKind — 5 | No paràmetres/metadata nous als confirmadors o lector protegit; conservar referències/compatibilitat i bloquejos històrics. |
| GetEmptyProductGroupDeactivationCandidates, DeactivateEmptyProductGroup, GetInactiveProductGroups — 3 | Ja definits amb G9/IsActive; elegibilitat, metadata de reserva, codis de resultat i ordre segons §6.33. |
| CloseAppSession, ReleaseProductGroup, ForceCloseAppSession, ResetAppAccountPassword, RecoverAppAdministratorPassword — 5 | No bloquejar alliberament/revocació per grup inactiu, cap camp de grup nou als seus contextos/respostes. Neteja comuna també sense aquest filtre. |

| Sense canvi directe de contracte per IsActive — 14 | Noms |
|---|---|
| Autenticació | GetAppAccountAuthenticationData, CreateAppSession; verificar neteja de caducades sense filtre de grup. |
| Comptes | GetAppAccounts, CreateAppAccount, SetAppAccountAccess, BootstrapAppAccount. AppAccount.IsActive no canvia. |
| Sessions | RenewAppSession, GetAppSessionForcedClosureContext, GetAppSessionsForForcedClosure. |
| Catàleg independent/editorial de valor | CreateGlobalVariantTypeWithValues, GetVariantTypeCatalog, AddGlobalVariantTypeValues, GetVariantTypeValueEditorialContext, CorrectVariantTypeValueText. |

NormalizeWhitespace no canvia per activitat. Altres circuits funcionals encara sense signatures completes —conciliació, descoberta, correcció CLIGNE, lectura externa— s'adapten només com a §6.34.5, sense inventar noms/paràmetres. Reactivació fora d'abast. La nova especificació exigeix contrast complet de les etapes: aquí només etapa 0 documental; etapes 1–4 no implementades/validades, no s'afirma cap prova de programari superada.

### 6.35 Glossari vigent i contracte de la còpia externa

#### 6.35.1 Dos processos, dues responsabilitats

**Actualització D379:** càrrega sempre completa, selecció de marques només en conciliació. El contracte documental del procés extern es reuneix a [Parkod.md](Parkod.md) §23, «Procés de carrega de VARIANTS_PARKOD.parkod». No és un carregador de l'app ni autorització d'implementació SQL.

| Terme vigent | Entrada → sortida | Responsabilitat |
|---|---|---|
| Càrrega/recàrrega externa de la còpia | parkod.dbo.PARKOD → VARIANTS_PARKOD.dbo.Parkod | Procés extern, **sempre complet**, fora del desenvolupament/manteniment de l'app. Vuit camps originals + SourceIsPresent. |
| Conciliació | VARIANTS_PARKOD.dbo.Parkod → ProductVariant, grups i altres dades pròpies autoritzades | App batch, complet o per marques, sense escriure els nou camps de còpia ni consultar l'original per aquest flux. |
| Correcció tècnica de línia | CLIGNE local revisada → LineCode/classificació del SKU | Decisió humana protegida; no recàrrega o reparació de la còpia (§6.38). |

Per carregar la còpia només hi ha la taula de producció PARKOD a parkod com a origen. No afegir CSV, transferències, bases intermèdies o una recàrrega obligatòria de producció. Els CSV/XML/SQL de §5.4–5.5 són evidències històriques de proves, no passos exigits en execució. Aquesta frontera **no elimina** consultes auxiliars ja autoritzades de noms/CATEGORY/FAMILY/EAN ni integra el generador extern dins l'app. Cap actuació a producció, nou planificador o servei central.

#### 6.35.2 Històric, presència i controls externs

Còpia acumulativa amb PK `(CMARQ, CCATEG, CPROD)`: referències antigues i actuals preservades, igual que ProductVariant, classificacions i auditoria. No DELETE o recreació de taules per igualar recomptes. L'absència d'una fila al flux recent no és absència de l'original. Un SKU antic encara present a la font continua present, independentment d'antiguitat o validació.

SourceIsPresent pertany exclusivament al procés extern. D379: presència/absència determinades per lectura completa i fiable **global**; ja no s'admet càrrega de marques seleccionades, i incremental/incomplet no prova absència. Registre observat però rebutjat no es considera desaparegut. Proteccions històriques d'inidentificables/duplicats no es transformen en algoritmes del projecte: control d'integritat de producció extern. L'app conserva PK de còpia i FK/unicitats pròpies, no implementa SourceSkuOccurrenceCount o comprovació periòdica d'originals.

D351 va confirmar reaparició amb canvi de CLIGNE: no ID o classificació nous automàtics, presència restablerta només amb lectura fiable. D362–D363 actualitzen qui ho fa i què es conserva: l'extern publica SourceIsPresent=1 i la CLIGNE carregada; l'app conserva **ProductVariant i decisions**, no congela l'antiga CLIGNE a la còpia. SourceIsPresent=0 no impedeix per si sol les correccions manuals aprovades, però exclou el SKU del generador.

D352: origen global buit amb referències encara presents no ha de causar retirada massiva automàtica ni èxit fictici. Amb la nova frontera, és condició del contracte extern; l'app no reconsulta producció per implementar-la. Una marca completament absent amb lectura fiable de la seva marca segueix el tractament d'absències acordat. No llindars arbitraris o mecanisme automàtic d'override aprovats.

#### 6.35.3 CLIGNE versus LineCode

CLIGNE = últim valor carregat externament. ProductVariant.LineCode = línia de classificació vigent, inicialment procedent de la còpia i conservada fins a correcció expressa. ProductGroup.LineCode = línia del creador del grup; en el nou grup tècnic és la línia final revisada del mateix SKU. Sempre ProductVariant.LineCode = línia del seu grup, mai diversos grups actuals per SKU.

Un canvi de CLIGNE no trasllada, desvalida o modifica risc/valors silenciosament. L'última classificació validada continua llegible per Parkod si compleix elegibilitat/presència/principal/valors/activitat. No afegir camp de desajust/Phase, altra PK/FK o font per resoldre'l. D368–D370: discrepància calculada visible a l'inici de sessió, correcció de valor no bloquejada per aquest sol fet (§6.41). La resta de mutacions i l'adaptació completa de controls continuen al contrast §6.40; no permissió o bloqueig universals extrapolats.

#### 6.35.4 Disponibilitat, usuaris i seqüència

Camp ParkodRefreshSucceeded i data ParkodLastCompletedAtUtc només del publicador extern: 0 durant càrrega/fallada, 1/data nova només després de **càrrega completa verificada i publicació correcta**. Data de darrera càrrega completa correcta de la còpia, no recàrrega de producció; fallada conserva data anterior. D379 substitueix expressament la publicació parcial de D364 per evitar un fals èxit global després de completa fallida. Selecció de marques només a §6.39, no via de recuperació de càrrega. Tipus/defaults/cinc camps globals intactes; cap versió, hash o estat per marca.

D377–D378: si obtenir la llista de pendents requereix consultar Parkod durant càrrega o després d'una fallada, mostrar avís de llista no disponible fins a nova publicació correcta (§6.41.5). No llista buida/resultat parcial complet fictici o veto general de l'app. L'indicador 0 no distingeix càrrega vigent de fallada; no inventar aquell diagnòstic o un camp d'estat nou.

Dos `.bat` seqüencials al Planificador de tasques de Windows, primer càrrega externa i després conciliació amb final correcte anterior verificat. No únic coordinador/planificador nou dins de l'app. No reobrir aquesta orquestració. De nit habitualment; excepcions gestionades manualment aturant/suspenent tasques, sense presumpció de rollback o garantia universal sobre escriptors legacy.

**Criteri final, posterior al tall intermedi D366:** càrrega externa compatible amb activitat GUI a VARIANTS_PARKOD, sense exclusió global de sessions/logins de tota la cadena. Controls de context, integritat i disponibilitat quan pertoqui; implementació de confirmació estable amb còpia canviant pendent, no autorització d'ometre'ls. Conciliació sí exigeix zero AppSession vigents, globals també en parcial, i entrada coherent/disponible; no activitat GUI durant conciliació. Sessió caducada als 30 minuts configurables és lògicament invàlida i no bloqueja el batch, encara que la finestra RDS/fila SQL continuï fins a neteja per demanda. Sense heartbeat o expulsió automàtica.

#### 6.35.5 Cooperació de càrrega i conciliació

Ambdós processos s'exclouen amb coordinació lògica §6.7 a la nova base, mantinguda per connexió dedicada durant cada procés, no transacció llarga. Conciliació: obtenir, comprovar disponibilitat després i mantenir fins al tancament; exclusió global de sessions intacta.

**Obligació expressa del carregador extern — D403:** obtenir bloqueig lògic **Exclusive mitjançant sp_getapplock** sobre el mateix recurs de coordinació de còpia dins de VARIANTS_PARKOD que utilitzen els procediments dependents de l'app. Abans de marcar inici i modificar còpia, mantenir-lo per connexió durant tota la càrrega completa i publicar resultat abans d'alliberar-lo. Si no l'obté, no modificar descoordinadament. Sense cooperació efectiva no hi ha exclusió garantida. No TABLOCK, objecte/permís a parkod o transacció global de càrrega.

Lectors dependents Shared durant lectura curta; confirmacions/rebutjos dependents Shared fins COMMIT/ROLLBACK (§6.44.3). Recurs/àmbit SQL efectiu coincidents entre participants; noms/permisos/esperes/propietat executable/proves pendents. Ni resultat d'adquisició ni indicador0 acrediten per si sols taula físicament bloquejada/càrrega en curs. Fallada pot alliberar coordinació deixant0/data anterior, només completa correcta recupera. Connexió perduda no autoritza continuar descoordinat/assumir rollback. Contracte també a Parkod.md §23.6, carregador extern no implementat aquí.

### 6.36 Validació manual d'un grup existent

**D380/D391, contrast E02 consolidat:** dues signatures marca–grup/quatre blocs amb grup7/associacions8. Configuració validable amb línia discrepant coneguda sense aprovar membres, risc/no-op/context actual conservats; buit actiu admès D333. D396/D402–D403 segons dependència real (§6.45.4).

#### 6.36.1 GetProductGroupValidationContext — D331–D333

```text
dbo.GetProductGroupValidationContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT
)
```

Tots obligatoris sense defaults/SQL NULL; sessió/token vigents/32bytes exactes abans de convertir, marca exactament3 abans de convertir/ID positiu. Tècnic ordinari/grup existent actiu/IsValidated0 o1/reserves verificades. Una fila ContextJson NVARCHAR(MAX), mateix SNAPSHOT curt local/tancat abans de revisar, sense auditoria/OperationId/reserva nova o lectura original.

| Propietat exacta | Contingut |
|---|---|
| ProductGroup | Grup complet de set camps de §3.2, incloent risc/validació/activitat/principal, sense categoria/línia de grup. |
| ProductVariants | Tots els membres reals, pendents i retirats, amb la forma reduïda inferior; [] si buit. |
| ProductGroupVariantTypes | Totes les associacions actuals completes. |
| VariantTypes | Definicions completes referenciades per les associacions, IDs únics. |

Membre exactament ProductVariantId, BrandCode, CategoryCode, ProductCode, ProductGroupId, LineCode, IsValidated i Parkod amb exactament CLIGNE/SourceIsPresent locals; reutilització expressa D246, no risc de pertinença afegit. Arrays sense duplicats, [] si absents, nullable explícits/originals JSON imbricats. Sense assignacions/valors ni configuració desitjada al context. Tipus/associacions permeten revisar principal, sense exigir fases 2–3 completes.

#### 6.36.2 ConfirmProductGroupValidation — D334

```text
dbo.ConfirmProductGroupValidation(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @BrandCode NVARCHAR(MAX),
    @ProductGroupId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Arguments obligatoris sense defaults/SQL NULL; mateixos controls del lector i context exacte de quatre blocs. D363 s'aplica sense canviar paràmetres. Transacció curta actual: verificar activitat/reserva/context/composició, integritat i principal sense reparar-lo, i canviar només ProductGroup.IsValidated 0→1. **Grup actiu buit admès**, sense mínim de SKU, membres validats, tipus finalitzats o valors complets. Risc/nom/relacions intactes; cap pertinença/tipus/valor validat automàticament, cap codi/exportabilitat.

Una product_group/confirmed_change/update, actor de sessió/clau BrandCode-ProductGroupId/Before-After **set camps**; camps de proposta/risc de decisió/resultat/DecisionOutcomeNULL, risc de fila conservat als snapshots. Resposta una fila **OperationId UNIQUEIDENTIFIER NULL + ProductGroup complet7**, capturada dins/post-COMMIT. Revisat ja1/després de tots els controls: no UPDATE-audit/UUIDNULL. Canvi concurrent0→1 és context canviat, no no-op antic. Errors/incertesa segons regles comunes/sense reenvio o rejected fictícia.

### 6.37 Validació de pertinença actual sense trasllat

**D390 resol el pendent del tall següent:** validació ordinària bloquejada fins a resolució de línia; corrector resol/valida conjuntament. D380 només exigeix marca comuna. Signatures/JSON antigues són base E02, no categoria/línia comunes.

#### 6.37.1 GetGroupMembershipValidationContext — D335–D336

```text
dbo.GetGroupMembershipValidationContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT
)
```

Obligatoris sense defaults/SQL NULL, ID positiu, tècnic amb sessió/token/reserves verificats. Grup actual derivat del SKU, existent actiu, no aportat pel client. Fila pendent o validada admesa; grup IsValidated=0 admès i SourceIsPresent=0 no és veto de retirada. SNAPSHOT curt local, una fila ContextJson NVARCHAR(MAX), sense canvi/reserva/auditoria/OperationId.

| Propietat exacta | Contingut |
|---|---|
| ProductVariant | Fila completa de vuit camps del SKU objecte, risc inclòs. |
| ProductGroup | Grup actual complet G9. |
| ProductVariants | Tots els membres reduïts de §6.36.1, inclòs exactament un cop l'objecte, retirats/pendents. |
| ProductGroupVariantTypes | Totes les associacions actuals completes. |
| VariantTypes | Definicions completes referenciades, IDs únics. |

Reutilització expressa dels quatre blocs del lector de grup afegint ProductVariant complet. Còpia local dins de cada membre, sense Parkod superior addicional, assignacions o valors de catàleg. Mateixes regles []/null/imbricació. Objecte/grup absent o inactiu: error sense grup alternatiu.

#### 6.37.2 ConfirmGroupMembershipValidation — D337

```text
dbo.ConfirmGroupMembershipValidation(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL. Via manual sense originals de proposta. Nova transacció curta, mateixos controls, context cinc contrastat i compatibilitat de marca/categoria/línia classificada amb grup/principal. Només ProductVariant.IsValidated 0→1, **risc anterior conservat**, no trasllat o correcció de LineCode. Grup provisional i retirat admissibles, sense exigir valors complets o fases 2–3; altres validacions intactes. El desajust CLIGNE/LineCode de D363 no s'arregla aquí; política ordinària d'aquest cas pendent de §6.40.

Una group_membership/confirmed_change/update, actor verificat, clau exactament ProductVariantId/BrandCode/CategoryCode/ProductGroupId actuals reals, Before/After vuit camps. Camps de proposta/risc de decisió/resultat i DecisionOutcome SQL NULL; risc de fila dins snapshots. Cap auditoria de grup/assignacions intactes. Resposta una fila **OperationId UNIQUEIDENTIFIER NULL + ProductVariant complet**, captura interna/post-COMMIT. Revisat ja 1 i controls superats: no UPDATE/auditoria, UUID NULL; canvi després de lectura és conflicte. Mai nova fila/ID/grup/codi. Errors/incertesa com §6.36.2.

### 6.38 Correcció tècnica de línia: mateix grup, altre existent o grup propi nou

**D395 concretat:** es reutilitza la via amb destí existent també quan és el grup actual; no tercera parella de procediments o paràmetre de mode nou. Set blocs amb SourceGroup/DestinationGroup complets encara que coincideixin. D384–D385: mateixa pertinença1/risc conservat; trasllat a altre existent o propi nou amb risc nouNULL. Marca comuna D380, sense categoria/línia comunes de grup. D396 segons dependència de còpia; disseny concretat, SQL/concurrència/proves encara pendents.

#### 6.38.1 Abast vigent i acords substituïts

D338–D347 són el tall històric de quatre noms de procediment; D361–D363 retiren relectura original i escriptura de còpia, D380 retira categoria/línia de grup, D395 concreta el resultat sense trasllat. CLIGNE només de la còpia local revisada, no @NewLineCode lliure. Correcció humana efectiva de ProductVariant.LineCode, no trasllat ordinari §6.18 o agrupació automàtica. Si CLIGNE ja coincideix amb LineCode, aquest circuit no és un no-op admès o un trasllat dissimulat; canvi concurrent de context sempre exigeix nova revisió.

ProductVariantId/BrandCode/CategoryCode/ProductCode conservats; únic grup actual de la mateixa marca. Actualitzar LineCode amb CLIGNE local revisada i posar pertinença IsValidated=1. Si identitat marca–grup no canvia, EstimatedRiskPercent de pertinença es conserva exactament, també NULL; si canvia, risc nou SQL NULL. Altres validacions/riscs/originals intactes, grup origen conservat encara buit. No línia del grup a modificar. SourceIsPresent0 no és veto nou ni exportabilitat; disponibilitat D396 diferent de presència, amb protecció concurrent pendent de prova.

**Traçabilitat de formats:** els set/sis blocs locals ja aprovats deriven de D343/D346/D363, no es reobre aquella confirmació. Ara files completes segons diccionari13/90 i PK marca–grup: ProductGroup7, ProductGroupVariantType8, ProductVariantValue9. Membres SKU conserven categoria/línia pròpies. D395 precisa SourceGroup/DestinationGroup coincidents; signatures actuals a continuació, sense procediments nous. Originals/snapshots antics literals intactes, no reconstruïts; etapa0 oberta.

#### 6.38.2 Lector amb destí existent, també actual — D343/D395

```text
dbo.GetVariantLineCorrectionToExistingGroupContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @DestinationBrandCode NVARCHAR(MAX),
    @DestinationProductGroupId INT
)
```

Arguments obligatoris sense defaults/SQL NULL, també per mantenir grup: el client indica marca–ID actual com a destí, no NULL o flag nou. Marca de tres caràcters validada abans de convertir, IDs positius, tècnic ordinari/sessió/token/reserves vigents. Origen derivat del SKU; origen/destí existents actius de la mateixa marca, poden ser el mateix grup. Pertinença comercial expressa, sense categoria/línia de destí comunes. Una fila ContextJson NVARCHAR(MAX), SNAPSHOT curt local tancat abans de revisar, sense creacions/reserves/codis/auditoria/OperationId de lectura. Si necessita còpia indisponible no emet context revisable D396.

| Bloc de lectura | Contracte vigent / adaptació de forma |
|---|---|
| ProductVariant | Fila completa SKU. |
| Parkod | Exactament CLIGNE i SourceIsPresent locals revisats, no dades de classificació desitjades. |
| SourceGroup | Exactament tres propietats: ProductGroup complet7, ProductVariants amb tots els membres reduïts §6.15.6, ProductGroupVariantTypes completes8. |
| DestinationGroup | Les mateixes tres propietats del destí. Si coincideix amb origen, mateix contingut complet en els dos blocs, no null o omès. |
| ProductVariantValues | Totes les assignacions del SKU, pendents/validades completes. |
| VariantTypes | Tots els tipus referenciats per associacions dels dos grups o assignacions, complets/IDs únics. |
| VariantTypeValues | Valors referenciats per les assignacions del SKU, complets/IDs únics. |

Exactament set noms de propietat, tots del mateix SNAPSHOT curt local. D395 conserva els dos blocs de grup encara que representin la mateixa identitat: solapament deliberat de presentació, no dues files SQL o dues pertinences/reserves. Igual contingut/conjunts, sense imposar ordre significatiu als arrays. Membres retirats/pendents inclosos; categoria/línia del SKU i Parkod:{CLIGNE, SourceIsPresent} preservats. ProductVariantValues completes9; [] reals, null explícits, originals imbricats i cap ID/propietat duplicat dins de cada conjunt/objecte. SourceParkod original continua retirat D363. No ID futur, camp nou, destí null o context vell completat silenciosament.

#### 6.38.3 Confirmador amb destí existent, també actual — D344/D395

```text
dbo.ConfirmVariantLineCorrectionToExistingGroup(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @DestinationBrandCode NVARCHAR(MAX),
    @DestinationProductGroupId INT,
    @ExpectedContextJson NVARCHAR(MAX)
)
```

Obligatoris sense defaults/SQL NULL. Context exacte del lector, CLIGNE local autoritativa revisada, no línia lliure. Nova transacció curta/coordinació: disponibilitat, entrada/context, sessió/permisos/reserves/activitat, identitats, marca comuna i assignacions/habilitacions/principals revalidats. Si falta associació necessària al destí, error/nova preparació i revisió, no crear-la silenciosament. Mateix grup: canvien només LineCode i IsValidated si cal, risc i assignacions exactament intactes. Altre grup: també ProductGroupId/risc nouNULL i rèpliques necessàries, sense pèrdua de valors/metadades. Cap grup/catàleg/codi/principal nou o canviat. Conflicte conegut desfà només l'intent; no reenvio o rejected fictícia, incertesa D238 conservada.

**Auditoria D342/D395:** una group_membership/confirmed_change/update amb clau anterior real §3.11.3 i Before/After ProductVariant8. Mateix grup: només aquesta entrada, cap audit d'assignacions intactes. Trasllat: variant_value/confirmed_change/update per cada rèplica canviada, snapshots9, valors/risc/validació/originals conservats. Actor user verificat/UUID SQL comú, camps de proposta/DecisionOutcome SQL NULL. Cap audit de grup/catàleg intactes, lectures o còpia; parkod_copy retirat D363, històric intacte.

| Conjunt post-COMMIT | Files | Resposta confirmada, captura interna |
|---|---|---|
| 1 | Una | OperationId UNIQUEIDENTIFIER informat + ProductVariant complet resultant. |
| 2 | Zero o més | Totes les ProductVariantValue completes9 del SKU: rèpliques actualitzades si trasllat, files intactes si mateix grup; conjunt de zero files si cap, no omès. |
| 3 | Una | Parkod completa, vuit camps originals + SourceIsPresent; amb el nou abast és **estat d'entrada llegit**, no fila actualitzada per l'app. |

Resposta no implica exportabilitat, UUID sempre informat en canvi efectiu; no no-op. Pèrdua/incompletesa segons D238, no assumir rollback o reenviar.

#### 6.38.4 Grup propi nou: aprovacions i lector — D345–D346

Un únic SKU existent és creador explícit, no mínim d'array, fusió de línia o límit de la creació conjunta §6.19. Altres membres intactes. Grup nou amb número del comptador per marca, sense categoria/línia, IsActive1/IsValidated1/riscNULL; LineCode final és del SKU. Nom manual/automàtic segons §6.38.5. Només associacions dels tipus assignats al SKU, cadascuna expressament aprovada1/codi-risc-originalsNULL. Cap tipus/valor nou, codi transferit o herència d'aprovació; zero finals→principalNULL, fase3 posterior.

```text
dbo.GetVariantLineCorrectionToNewGroupContext(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT
)
```

Obligatoris sense defaults/SQL NULL; IDs/sessió/token/reserves comprovats, origen existent actiu, còpia local amb nova línia. Una fila ContextJson d'un SNAPSHOT curt local, sense creació/número reservat/auditoria. SourceIsPresent=0 admès, sense confondre presència amb disponibilitat de còpia. Abans del canvi de frontera, set blocs aprovats: ProductVariant, Parkod, SourceParkod original, SourceGroup, ProductVariantValues, VariantTypes, VariantTypeValues. SourceParkod original ara retirat.

**Context local de sis blocs:** exactament ProductVariant, Parkod, SourceGroup, ProductVariantValues, VariantTypes i VariantTypeValues, formes actuals de §6.38.2 sense DestinationGroup. Mateix SNAPSHOT curt local, disponibilitat D396, sense destí null/ID futur/còpia fictícia. D346/D363/D380 com a origen de les adaptacions, no una nova aprovació pendent. Tipus de totes les associacions d'origen per revisar principal, sense associar-los tots al nou grup. Nom/aprovacions desitjats separats del context. Cap CLIGNE original rellegida; protocol auxiliar de noms encara pendent.

#### 6.38.5 Confirmador amb grup propi nou — D347

```text
dbo.ConfirmVariantLineCorrectionToNewGroup(
    @AppSessionId UNIQUEIDENTIFIER,
    @SessionToken VARBINARY(MAX),
    @ProductVariantId BIGINT,
    @ExpectedContextJson NVARCHAR(MAX),
    @ApprovedVariantTypeIdsJson NVARCHAR(MAX),
    @ProductGroupName NVARCHAR(MAX) = NULL
)
```

Obligatoris sense defaults/SQL NULL excepte el nom. ApprovedVariantTypeIdsJson és array d'IDs INT reals existents, sense duplicats/ordre significatiu; **exactament** els tipus de ProductVariantValue del SKU, [] obligatori si cap. Omissió/tipus extra/duplicat: error sense completar/ignorar. Cada entrada representa aprovació humana, no còpia automàtica de l'origen.

Nom NULL demana generació inicial segons fórmula/fallback aprovats amb nou ID/creador/línia final; text informat normalitzat, no buit/<=150, sense unicitat, truncament o número afegit. No alta amb nom NULL en aquesta creació. Protocol de noms auxiliars i coherència amb la línia local revisada pendents: error d'accés/ambigüitat no són fallback de nom absent; no ampliar fonts o copiar denominacions.

Transacció curta: controls de lector/context/revalidació local, tipus → SKU → comptador → grups. Crear grup/aprovacions necessàries, traslladar el mateix SKU amb LineCode final/IsValidated=1/risc NULL, cascada limitada de rèpliques. No escriure còpia/SourceIsPresent; altres validacions i dades conservades. Principals i FK revalidats, cap codi o finalització fase 3/no-op. Cap grup buit preparatori persistent. Si canvia entrada/context o falla un control, només rollback d'aquest intent; COMMIT anteriors conservats, incertesa sense reenviament.

Auditoria: product_group/create (Before NULL/After7), group_variant_type/create per associació (Before NULL/After8), group_membership/update (Before/After8, clau anterior real) i variant_value/update per rèplica canviada (Before/After9). Confirmed_change/actor user verificat/UUID SQL comú, DecisionOutcome/camps de proposta d'esdeveniment NULL. Cap parkod_copy D363, audit d'altres membres/grups/catàlegs intactes o reescriptura de snapshots antics.

| Conjunt post-COMMIT | Files | Resposta confirmada, captura interna |
|---|---|---|
| 1 | Una | OperationId UNIQUEIDENTIFIER informat + grup nou complet7. |
| 2 | Una | ProductVariant complet resultant. |
| 3 | Zero o més | Associacions completes creades. |
| 4 | Zero o més | Assignacions completes amb rèpliques actualitzades. |
| 5 | Una | Parkod completa de nou camps, llegida i no modificada per l'app. |

Conjunts buits retornats, no omesos. Els nou camps de Parkod són CMARQ, CCATEG, CPROD, CLIGNE, DESIGN1, DESIGN2, code1, code2, SourceIsPresent; no nova columna. Captura de resposta coherent amb l'entrada protegida a provar. Ni codi/principal nou no nul o exportabilitat per si sola.

### 6.39 Abast, balanç i cicle SQL de conciliació

#### 6.39.1 Entrada de l'abast i tipus de llançament — D353–D354

BrandCodesJson NVARCHAR(MAX)=NULL: **SQL NULL** significa completa. En parcial, array no buit de codis textuals de tres caràcters A–Z/0–9, zeros preservats, sense duplicats i ordre irrellevant. []/cadena buida/JSON null/objecte/estructura incorrecta són error, mai ampliació a completa. Marca històrica local sense files actuals admissible; cap filtre nou per categoria/línia/país o consulta obligatòria al mestre BRAND. No ampliar marques després d'iniciar. Abast transitori, no columna/estat per marca.

InvocationKind NVARCHAR(MAX) obligatori, sense default/SQL NULL, només manual o scheduled. Es declara expressament, no es dedueix de Windows/RDS o d'un clic al Planificador. Manual permet repetir sense omissió per dates; no salta controls de sessions, disponibilitat, coordinació, integritat o abast. Scheduled només omet una **completa** per dates si els dos indicadors són 1 i VariantsLastCompletedAtUtc és posterior a ParkodLastCompletedAtUtc. Dates globals no justifiquen ometre parcials. No @Force per saltar garanties.

#### 6.39.2 BeginReconciliation — D355–D356

```text
dbo.BeginReconciliation(
    @InvocationKind NVARCHAR(MAX),
    @BrandCodesJson NVARCHAR(MAX) = NULL
)
```

Identitat SQL tècnica limitada ja acordada per batch/interactiu, EXECUTE autoritzat, no sessió/token d'app o compte SQL nou implícits. Validar arguments, coordinar altre batch i login, netejar caducades; qualsevol sessió d'app vigent també administrativa impedeix iniciar, sense expulsió/alliberament forçat. Obtenir coordinació de càrrega de còpia/batch i comprovar ParkodRefreshSucceeded després d'obtenir-la. Còpia no disponible, arguments/permisos/infraestructura incorrectes són errors, no omissions fictícies. Ocupació confirmada per altre batch diferenciada d'un error/timeout tècnic.

Una fila amb exactament ResultCode NVARCHAR(32):

| Valor | Significat |
|---|---|
| started | Inici admès, no execució acabada. |
| not_run_active_session | Sessió vigent, no executat. |
| not_run_other_batch | Altra conciliació en curs, no executat. |
| not_run_up_to_date | Completa scheduled ja conciliada segons dates/indicadors. |

Els tres not_run_*: sortida batch 0/log NOT RUN, sense canviar SynchronizationStatus i alliberant els bloquejos adquirits per la crida. Neteja ordinària de caducades no es converteix en auditoria de negoci. started: completa posa VariantsReconciliationSucceeded=0/data anterior conservada, parcial no toca camps globals variants. Resposta només després de COMMIT efectiu de l'inici. Sense auditoria/OperationId, nova taula/RunId o transacció oberta de tot el batch.

**SESSION_CONTEXT aprovat:** petites metadades de la mateixa connexió dedicada: tipus de llançament, indicador completa/parcial i recomptes inicials de còpia/ProductVariant dins de l'abast, incloent històric. Preparades només per started, netejades en tancament segur. No substitueixen comprovar identitat SQL/bloquejos posseïts; connexió perduda no recrea estat ni prova rollback. No guardar un JSON MAX llarg en un valor limitat a 8 KB; claus i patró executable pendents, ús inventariat a §6.12.

#### 6.39.3 Sense HASH d'abast — D357

Proposta de fingerprint SHA-256 **retirada i descartada expressament**. No forma part de l'implementació requerida ni crea identificador/versionat/idempotència. El backend conserva el conjunt inicial fixat i l'envia a les operacions que el necessitin. SQL valida l'array rebut i que el SKU sigui dins d'aquest abast; completa/parcial es contrasta amb l'inici a la connexió. **No afirmar que SQL compara dos conjunts inicial/posterior de marques**, perquè no guarda aquella llista completa. Aquesta coherència correspon al backend sota el model intern de confiança aprovat, no prova contra manipulació intencionada. Hash/token de sessió D199 intacte; no eliminar-lo per aquest descart.

#### 6.39.4 CompleteReconciliation — D358, ampliat D371–D373

```text
dbo.CompleteReconciliation(
    @ReadCount BIGINT,
    @InsertedCount BIGINT,
    @UpdatedCount BIGINT,
    @UnchangedCount BIGINT,
    @RejectedOrPendingCount BIGINT,
    @UnincorporatedSkuIncidentsJson NVARCHAR(MAX),
    @BrandCodesJson NVARCHAR(MAX) = NULL
)
```

Recomptes obligatoris, no NULL/no negatius; InsertedCount només altes amb COMMIT. **D373 afegeix únicament @UnincorporatedSkuIncidentsJson NVARCHAR(MAX), obligatori sense default, abans de l'abast opcional.** Set paràmetres en total; els cinc recomptes i el tipus/default de BrandCodesJson es conserven. JSON exacte a §6.39.7, [] explícit si no queda cap SKU sense variant. No nombre 77 de procediment ni camp físic nou.

Mateixa connexió started/metadades i bloquejos vigents, abast vàlid/coherent amb completa/parcial. D371–D372: SQL comprova, en el tancament actual coordinat, la correspondència exacta entre claus de còpia de l'abast sense ProductVariant i claus del JSON, sense omissions, sobrants o duplicats. El backend aporta incidències identificades d'aquella execució i manté les causes al log; no n'hi ha prou amb RejectedOrPendingCount. Lectura/processament complets continuen sent precondició: sumes, coincidència de conjunts i text Reason no en són una prova suficient ni certifiquen per si sols la veracitat de la causa declarada. Incidències individuals controlades poden permetre completar amb avisos, no infraestructura incompleta o proteccions ignorades. Absències originals sota responsabilitat externa.

La signatura anterior D358 de sis paràmetres queda substituïda per aquesta ampliació expressament confirmada D372–D373; **les cinc columnes de resposta es mantenen**. Contracte encara de disseny: parser/comparació SQL/protecció concurrent/proves pendents. En tancament correcte, completa posa VariantsReconciliationSucceeded=1 i VariantsLastCompletedAtUtc SQL nova; parcial conserva camps globals. Cap camp Parkod canviat. Resposta d'una fila capturada dins de l'operació/post-COMMIT:

| Camp | Tipus |
|---|---|
| ResultCode | NVARCHAR(32), completed |
| ParkodCountBefore | BIGINT |
| ParkodCountAfter | BIGINT |
| ProductVariantCountBefore | BIGINT |
| ProductVariantCountAfter | BIGINT |

Després de COMMIT efectiu, netejar metadades i alliberar coordinació. Sense auditoria de finalització/OperationId. Error de comprovació no és èxit ni alliberament com a completed; tancament per fallada coneguda separat. Resposta perduda/incompleta: resultat incert, no reenviar ni cridar Fail automàticament.

#### 6.39.5 FailReconciliation — D359

```text
dbo.FailReconciliation()
```

Sense arguments: no necessita llista perquè no processa/compta/retira SKU; pren completa/parcial de l'inici SQL. Abast exacte/causa/recomptes confirmats i incerts al log del backend. Mateixa connexió dedicada amb started, metadades/bloquejos vàlids i execució conegudament incompleta, sense operació en curs/transacció de treball pendent. No rollback indiscriminat o tancament des d'una connexió nova reconstruïda. No usar-lo com a prova de si Complete va confirmar.

Tancament curt: completa assegura VariantsReconciliationSucceeded=0/data anterior conservada; parcial no toca globals. Cap camp Parkod canviat ni cap reversió de còpies/variants/grups/assignacions/auditories confirmades. Després de COMMIT, netejar metadades i alliberar bloquejos propis. Una fila exactament **ResultCode NVARCHAR(32)=failed**, sense auditoria o OperationId. És «execució fallida tancada», no error SQL del tancament; backend retorna no zero.

Connexió incorrecta, inici absent, bloquejos no posseïts o execució ja tancada: error, no failed fictici/no-op. COMMIT previs intactes; rollback conegut afecta només operació que falla. Últim SKU amb resultat incert continua incert, tancar no resol aquella petició. Complete incert o SMTP fallit després d'èxit no criden Fail automàticament; SMTP no rebaixa èxit de dades. Connexió perduda: aturar, no reconnectar per simular aquest tancament. Els paràmetres d'autor no són lliures i no es creen sessions/IDs de batch.

#### 6.39.6 Balanç mínim i cobertura individual — D349–D350/D371–D372

D349–D350 van confirmar resum/log, no taules/camps nous. Categories exclusives per fila llegida: nous incorporats, actualitzats, intactes, rebutjats/pendents. Pendent és dins de l'última categoria, no doble recompte. Reaparició amb canvi de línia es comptava una vegada pendent; no decisió humana rejected inventada. Nous només amb COMMIT. Acord de suma conservat:

```text
ReadCount = InsertedCount + UpdatedCount + UnchangedCount + RejectedOrPendingCount
```

Amb la nova frontera, ReadCount es refereix a les files de còpia dins de l'abast, no a una importació original/CSV. InsertedCount és alta de ProductVariant, no de còpia. No excloure retirats/pendents per fer quadrar totals d'històric. Categories exactes d'actualització sense escriptura de còpia a contrastar amb els escriptors batch encara pendents, no generar canvis automàtics de classificació per justificar un recompte.

| Regla | Estat vigent després de D371–D373 |
|---|---|
| ParkodCountAfter = ParkodCountBefore + InsertedCount | **Substituïda:** pressuposava que l'app carregava la còpia; ara és fals. |
| ParkodCountAfter = ParkodCountBefore | Conseqüència de còpia de només lectura i exclusió efectiva de càrrega durant conciliació. No assumir estabilitat sense integrar/provar el coordinador extern. |
| ProductVariantCountAfter = ProductVariantCountBefore + InsertedCount | Mantinguda, sense DELETE ni duplicació d'IDs. |
| Igualtat inicial còpia–variant | **No exigible:** noves còpies encara sense variant són estat normal abans de conciliar. |
| Cobertura final còpia–variant | **D371 confirmat:** cada SKU de còpia de l'abast té ProductVariant o incidència d'admissió identificada per aquell SKU durant l'execució. Cap SKU sense variant i sense explicació; SQL contrasta el conjunt exacte amb el JSON de §6.39.7. No igualtat incondicional de totals, DELETE o creació de variants invàlides per quadrar-los. |
| Retirades 1→0 i presència restablerta 0→1 | Actuacions externes, no comptadors de mutacions d'app. L'app pot comptar presència actual, però no inferir transicions d'una càrrega sense evidència externa ni inventar històric nou. |

Les tres igualtats aprovades sota la frontera antiga es conserven només per traçabilitat: C_after=C_before+Inserted, V_after=V_before+Inserted, C_after=V_after. Només la regla de creixement de variants es manté; còpia estable i cobertura individual les substitueixen als altres punts. D372–D373 aproven expressament un paràmetre JSON nou de Complete, no un ResultCode, recompte de resposta o taula nous. No es desfan COMMIT previs per quadrar dades.

**Cobertura, mateix abast i estat final:** per a cada clau de còpia s'ha de complir una de les dues vies: variant existent o incidència d'admissió del SKU sense variant en l'execució. SQL obté els SKU sense variant de les dades locals actuals i els compara amb els identificats al JSON; totes dues direccions han de coincidir. Un SKU amb variant però línia pendent no és un SKU no incorporat i no entra en aquest JSON. Tampoc s'hi admet un motiu genèric sense clau individual o una clau aliena a l'abast. Incloure històric/retirats/presència 0 i pendents en els recomptes segons l'abast acordat; cap filtre nou per validació o antiguitat.

**RejectedOrPendingCount no és la diferència còpia–variant:** també inclou incidències amb variant existent. Exemple fictici: 100 còpies, 98 variants i 5 rebutjats/pendents, dels quals 2 SKU no incorporats i 3 discrepàncies de línia amb variant. El JSON té 2 entrades, no 5. Amb correspondència exacta i FK/unicitat internes, C_after=V_after+nombre d'entrades del JSON és una conseqüència de cobertura, no una prova substitutiva de la comparació de claus ni una columna física/de resposta nova.

Una omissió, clau sobrant/duplicada o absència sense incidència impedeix declarar completed. Una incidència d'admissió individual controlada pot permetre completar amb avisos; una lectura incompleta, infraestructura fallida o operació incerta no es converteix en èxit afegint un Reason. D238/D359 i els COMMIT previs intactes, sense reenviament automàtic o rebuig humà fictici. Balanç/comparació no demostren per si sols la lectura completa ni el motiu real: backend continua responsable de processament/logs. Resum de transicions de presència no inferit de l'estat actual, perquè les manté el carregador extern.

#### 6.39.7 UnincorporatedSkuIncidentsJson — forma exacta D373

Paràmetre NVARCHAR(MAX) obligatori sense default, **no SQL NULL**, exclusiu del tancament CompleteReconciliation. JSON transitori, no fila de taula, cua de tasques, auditoria, nou RunId o dades a la còpia. Array d'objectes, una entrada per SKU sense variant amb incidència d'admissió d'aquella execució; ordre irrellevant. [] explícit si el conjunt final de SKU sense variant és buit, encara que hi hagi altres incidències amb variant existent. No estendre el significat de [] a BrandCodesJson, on continua sent error.

| Propietat exacta | Tipus JSON i validació confirmada |
|---|---|
| BrandCode | String de 3 caràcters exactes ASCII A–Z/0–9, zeros preservats. |
| CategoryCode | String de 2 dígits exactes ASCII 0–9, zeros preservats (D388). |
| ProductCode | String de 3 caràcters exactes ASCII A–Z/0–9, zeros preservats. |
| Reason | String tècnica obligatòria amb contingut, emesa pel backend en anglès, sense secrets; text descriptiu, no nou catàleg de codis d'error. |

Totes quatre propietats obligatòries i no JSON null, noms exactes sensibles a majúscules; cap propietat desconeguda/duplicada, encara idèntica, ni objecte/array imbricat en lloc d'un string. No ProductVariantId inventat: la variant no existeix. Unicitat de la clau completa BrandCode/CategoryCode/ProductCode dins de l'array, no ProductCode global. Rebutjar SQL NULL, JSON null, cadena buida, document malformat o no array, elements no objecte i estructura/codis invàlids; no retallar/convertir/omplir o passar a majúscules els codis abans d'acceptar-los. Validar longitud/ASCII abans de convertir a tipus acotats, sense confiar només en comparació de collation que admeti espais finals o equivalències.

Reason no pot ser buit ni contenir només blancs; sense truncament silenciós o normalització automàtica dels camps fora de l'abast D318. El backend garanteix redacció tècnica anglesa i absència de secrets; SQL valida l'estructura/contenidor/claus i contingut exigit, no certifica idioma, causa real o completesa del procés amb el text. No nova longitud màxima, default, collation CI_AI o vocabulari d'incidències aprovats per aquesta propietat. Es manté el motiu al log tècnic de l'execució, sense nova entrada EvaluationAuditEvent de lectura/tancament.

Exemple fictici confirmat de forma, no dada de producció ni diagnòstic executat:

```json
[
  {
    "BrandCode": "ABC",
    "CategoryCode": "01",
    "ProductCode": "V70",
    "Reason": "Product quantity is invalid."
  }
]
```

SQL comprova existència de cada clau a la còpia local, pertinença a l'abast, absència actual de ProductVariant i coincidència exacta amb tots els SKU sense variant en aquell abast. Mateixa connexió/metadades/bloquejos del cicle, comprovació de tancament en transacció curta actual. No comparar en una connexió reconstruïda o suposar que el JSON prova l'abast inicial guardat: D357 encara deixa el conjunt fix al backend, sense hash/llista inicial completa SQL. No guardar aquest JSON MAX en SESSION_CONTEXT, ni modificar fonts/còpia/validacions per fer-lo coincidir. Parser/comparador/SQL/permisos i proves humanament validades pendents, sense implementació executable.

### 6.40 Contrast transversal i límits de la consolidació

**Referència històrica D379: 76 noms i NormalizeWhitespace separada.** Taula següent d'aquell tall, no interfícies totes adaptades. D395§6.38/D396–D398§6.43/D399–D403§6.44/D404§6.45,29signatures amb categoria ja adaptades a contractes/inventari. Altres formes E02 pendents; marques antigues de línia/disponibilitat per decidir i G9/R5 no vigents. CompleteD373 setparàmetres/resposta intactes, Category/exemple actualitzatsD388–D389.

| Família | Canvi actual i pendent a contrastar |
|---|---|
| 4 validacions grup/pertinença §6.36–6.37 | Signatures/contextos 4/5/respostes confirmats. Coherència variant–grup mantinguda, no absorbir correcció de línia. Política exacta de confirmació ordinària amb CLIGNE d'entrada discrepant pendent. |
| 4 correccions de línia §6.38 | Signatures/entrades/3 o 5 conjunts confirmats; còpia de només lectura, SourceIsPresent extern, cap lectura original o auditoria parkod_copy. Contextos locals 7/6 derivats de D343/D346 amb D363, sense nova decisió pendent; controls executables/proves encara pendents. |
| 3 procediments batch §6.39 | D371–D373 tanquen el criteri individual de cobertura i JSON exacte de Complete: set paràmetres/resposta intacta, SQL compara claus sense variant amb incidències de l'execució. Begin/Fail/metadades intactes, sense hash/RunId. Parser/comparador/balanç executables, disponibilitat/coordinació i proves encara pendents; no antiga igualtat de totals o prova fictícia de completesa. |
| Lectors/mutadors SKU–valor, grup–tipus, substitucions, finalització, trasllat i creació conjunta previs | Mateixos arguments i formes G9/R5 actuals. CLIGNE d'entrada recent versus LineCode classificat, sense igualtat universal/correcció implícita. D369 resol la correcció de valor: desajust conegut no la bloqueja, context actual/altres controls intactes (§6.41.3). Resta de circuits i protecció concurrent a contrastar sense extrapolació. |
| Catàlegs/editorials, comptes, sessions, noms/principal i desactivació | No bloqueig global de GUI només per càrrega. Operacions sense dependència d'entrada no obtenen un veto nou fictici. Contextos que sí la inclouen i lectura/protecció de còpia durant càrrega a contrastar, sense canviar formats a cegues. |
| Integració de còpia | D379: càrrega externa sempre completa, marques només en conciliació; D364 parcial substituït. App sense DML a Parkod, història/presència/indicadors externs. Contracte a Parkod.md §23, no carregador desenvolupat. Configuració SQL 2017/140/French_CI_AS/SNAPSHOT només nova base encara pendent, original intocable. |
| Generador existent | Mateixa elegibilitat/última classificació validada si present, IsActive=1, indicadors informatius. Cap exportador nou o control de font original afegit. |
| Visibilitat de pendents §6.41 | D374–D376: candidates/valors absents diferenciats, fase 2 aprovada sense codi com a finalització, retirats amb validacions existents admissibles sí/assignacions absents no. D377–D378: avís de llista no disponible durant càrrega/fallada si consulta còpia. Detalls restants de consulta/resposta/GUI pendents, sense signatura/entitat nova o etapa 4 implementada. |

**No adoptat:** HASH d'abast, SourceSkuOccurrenceCount, escàner periòdic de producció, excepcions de caixes als codis compatibles, nova taula/composició de kits, batch de trasllats a destí existent, planificador intern, còpia d'intermediaris/denominacions o manteniment original. El cas d'agrupar diversos SKU compatibles en **grup nou** ja és §6.19, amb creador/decisions individuals; no el limita l'únic SKU del corrector tècnic. Agrupació massiva cap a grup existent no queda aprovada per extrapolació.

D366 va reflectir un tall intermedi de finestra global sense GUI per càrrega i conciliació. **D367 el substitueix:** GUI permesa durant càrrega; conciliació sense sessions vigents/còpia coherent; dos `.bat` en seqüència, no bloqueig de login de tota la cadena. No tornar a presentar l'orquestració o caducitat 30 minuts ja acordades com a noves decisions.

Consolidació documental de 2026-11-03, no dates inventades de confirmació. Model físic 14/99/PK/FK/tipus sense canvis, amb redefinició funcional de propietat de còpia/presència/LineCode/indicadors; obliga contrast complet de totes les etapes. Només disseny documental d'etapa 0 existeix, i continua obert; DDL, comparadors, escriptors batch, noms automàtics coherents, disponibilitat/permisos/concurrència/integracions i proves humanament validades pendents. No SQL executat, dada/font/configuració canviades o programari desplegat.

### 6.41 Visibilitat de pendents i correcció de valors amb línia discrepant

#### 6.41.1 Detecció local i visibilitat — D368

Discrepància = Parkod.CLIGNE versus ProductVariant.LineCode del mateix SKU. Revisió tècnica si difereixen, sense línia comuna al grup D380. No font original, segon grup actual, flag o còpia escrita. CCATEG continua identificant SKU: canviar-la és recodificació, no incidència d'una categoria classificada nova.

La visibilitat per al tècnic no es limita al log anglès de §6.3: el cas s'inclou a la llista inicial d'incidències, amb identificació del SKU i les dues línies. La presentació externa serà en francès. El pendent és derivat de l'estat local actual; corregir un valor no el fa desaparèixer. Quan ja no hi ha desajust, aquella discrepància no és un pendent actual; això per si sol no prova autoria o execució d'un corrector. Les correccions efectives conserven l'auditoria ordinària, no s'inventa un tancament auditat només per una lectura o avís.

#### 6.41.2 Llista en cada inici de sessió i categories — D368/D370

Després d'un inici de sessió d'app correcte, mostrar **cada vegada** una llista de tasques o problemes pendents, agrupada en les dues categories confirmades:

| Categoria funcional | Contingut confirmat |
|---|---|
| Incidències tècniques | Inicialment, discrepàncies de línia de §6.41.1. Altres incidències requereixen definició prèvia de detecció/tractament; no incorporar tots els logs, SMTP o casos de resultat incert automàticament per extrapolació. |
| Treballs pendents de validació | Els quatre àmbits existents diferenciats: ProductGroup; pertinença ProductVariant → ProductGroup; associació ProductGroupVariantType; assignació ProductVariantValue. No validació comercial del catàleg compartit per herència. |

La llista és presentació del treball existent, no un cinquè àmbit de validació, aprovació conjunta implícita o nova fase. No crea reserves, decisions o canvis de negoci només per mostrar-se; les accions continuen pels circuits normals amb context actual i els controls d'activitat/sessió/permisos/reserva corresponents. D327/D328 no es relaxen: inactius no esdevenen destinacions/tasques operables per aparèixer en una consulta, i catàlegs/usos històrics conserven les seves regles.

No es pressuposa un gestor nou d'assignació personal de tasques, historial d'estats de tasca, noves taules/camps o escriptures de còpia. Les categories no autoritzen nous diagnòstics de producció, notificacions periòdiques, recuperació automàtica de resultats incerts o auditoria de lectures. Tampoc canvien el login de dos passos: llegir/mostrar la llista no és un nou resultat de CreateAppSession ni una transacció d'autenticació mantinguda oberta.

D374–D376 tanquen els criteris d'assignacions absents/finalització/retirats a §6.41.4; D377–D378 tanquen l'avís durant càrrega/fallada a §6.41.5. La forma exacta de consulta/resposta/agrupació i els altres criteris no definits encara s'han de concretar. No assimilar absència a candidata o associació aprovada sense codi a candidata rebutjable. No noms/signatures nous, persistència de tasques o desenvolupament GUI aprovats per aquests acords.

#### 6.41.3 Correcció de valor permessa amb línia pendent — D369

El desajust **present al context revisat** de §6.41.1 no bloqueja per si sol una correcció de valor d'un ProductVariant ni exigeix resoldre primer la línia. No s'exigeix una aprovació separada de la línia per poder corregir el valor: «revisat» es refereix al context habitual de correcció. S'aplica al circuit existent (§6.23), manual o amb proposta segons el seu contracte. No equival a autoritzar tots els altres tipus de validació, trasllats, altes o finalitzacions davant de qualsevol discrepància; els seus controls s'han de contrastar separadament (§6.40).

Es conserven permisos/sessió/token/caducitat, reserva, grup actiu i classificació variant–grup coherent, habilitació de tipus/compatibilitat de marca, representació/unicitat del valor, comparació de context i transacció/auditories. Una modificació rellevant després de la lectura exigeix nova revisió; no es pot ignorar perquè la discrepància sigui admissible. No relectura original o escriptura de còpia, ni nou camp/paràmetre per permetre-ho.

Canvia només el que ja autoritza la correcció de valor: LineCode/pertinença/còpia no canvien, el pendent de línia continua mentre les dues línies difereixin. Risc/originals/no-op/UUID i dos conjunts capturats post-COMMIT segons §6.23; ni un bloqueig fictici per línia ni una auditoria fictícia de correcció de línia. SourceIsPresent segueix extern i les regles de retirats/exportació anteriors intactes.

#### 6.41.4 Assignacions absents, finalització i SKU retirats — D374–D376

La llista inclou treball pendent més enllà de files IsValidated=0, sense crear nous àmbits de validació o estats físics:

| Situació | Presentació i circuit confirmats |
|---|---|
| ProductVariantValue existent amb IsValidated=0 | Assignació pendent de validar; candidata existent, circuit de §6.15. No absència o alta manual silenciosa. |
| ProductVariantValue absent per parella SKU–tipus d'un tipus aprovat al grup | Valor pendent d'assignar (D374); no ID/fila candidats inventats. Si es decideix l'alta manual, circuit de §6.24 amb context actual. Excepció per retirats a continuació. |
| ProductGroupVariantType existent amb IsValidated=1 i ParkodVariantCode SQL NULL | Pendent de finalització (D375), separat de candidata pendent d'aprovar; finalització §6.17, no rebuig/aprovació de fase 2 o codi automàtic. |

**D376 — SKU retirats, SourceIsPresent=0:** tot treball de validació existent que els circuits vigents permeten es mostra com a tasca i es resol mitjançant decisió humana ordinària. Inclou pertinença SKU–grup pendent admissible i assignació SKU–valor candidata existent, encara que el SKU no s'exporti. En canvi, una assignació absent continua absent i **no** es mostra com a tasca pendent d'assignar per aquell SKU. No ocultar candidates existents pel simple fet de ser retirat ni crear les mancants per omplir la llista. És un criteri de visibilitat, no DELETE, canvi de SourceIsPresent o prohibició nova d'actuacions manuals ja permeses.

Mostrar no valida/reserva/audita o obliga a resoldre tota la llista. **Pendent antic resolt D390:** validació ordinària bloquejada per línia pendent; corrector resol i confirma conjuntament. Configuració de grup, fase2 i valors segons permisos explícits D391/D393/D394, no extrapolació de D369. Matriu §6.42.3.

Una associació pendent de finalització no significa finalitzable immediatament. D253–D256 intactes: valors requerits presents/validats, principal coherent i almenys un SKU present amb pertinença validada per a codi nou; grup amb només retirats no n'obté un. No nous filtres implícits de finalització, camps, cues, signatures o recompte de resposta. Detalls exactes d'elegibilitat/consulta restants s'han de concretar abans d'implementar.

#### 6.41.5 Llista temporalment no disponible — D377–D378, actualitzat D379

**Durant càrrega:** si obtenir la llista requereix consultar VARIANTS_PARKOD.dbo.Parkod, mostrar avís explícit de llista temporalment no disponible, no una llista buida interpretada com a absència de feina o dades parcials presentades com a completes. D377 es va confirmar per càrregues totals o parcials; D379 substitueix després la modalitat parcial: totes les càrregues externes admeses són ara completes. No extrapolar la selecció de marques de conciliació a disponibilitat parcial de la còpia.

**Després d'una càrrega fallida:** D378 confirma mantenir no disponible la llista que depèn de Parkod fins que l'extern torni a publicar correctament la còpia. Amb D379, recuperació només amb nova càrrega completa verificada/publicada, no èxit d'una càrrega per marques. ParkodRefreshSucceeded resta 0 i data anterior conservada; ni aquella data ni COMMIT previs demostren que la còpia hagi retornat íntegrament a l'estat anterior. Cap reparació/restitució automàtica de l'app.

Avís extern en francès. Formulació orientativa durant càrrega efectivament coneguda: «La liste des tâches est temporairement indisponible : mise à jour des données Parkod en cours.» Si hi ha fallada o només indicador 0 sense causa establerta, avís neutre: «La liste des tâches est temporairement indisponible : les données Parkod ne sont pas disponibles.» No atribuir càrrega en curs només per ParkodRefreshSucceeded=0: el mateix valor també cobreix fallada. Detecció/coordinació SQL i forma de resposta encara pendents, sense nou camp o signatura inventats.

L'avís D377–D378 només tracta la llista: sense login bloquejat, expulsió, auditoria de lectura o veto general. **D396 resol després** la resta de revisions segons dependència real de còpia (§6.43.1), no per extrapolació de l'avís: sense context revisable/confirmació/rebuig formal amb0 si necessita Parkod, operacions independents conservades. Consulta separada de CreateAppSession; cap transacció de formulari, cache/snapshot persistent, reintents o auto-refresc nous.

### 6.42 Nous requeriments: acords vigents i mapa de represa — D380–D394

**Actualització D398:** el model següent continua vigent; D395 concreta el corrector a §6.38, D396 resol el criteri de disponibilitat a §6.43.1, D397 concreta la comparació del màxim i D398 el cas reduït de §6.27. Les referències antigues a E03/E05 per decidir no són pendents funcionals actuals.

**Precisió D403:** matriu ampliada amb els casos D399–D401; error identificable D402 i esquema lògic D403 a §6.44. Model13/90/signatures/respostes d'èxit intactes, detalls executables/proves no resolts pel sol acord.

#### 6.42.1 Model consolidat i derivacions

Els requisits i les eliminacions indicats per l'usuari governen §2–§4. Identitats: grup `(BrandCode, ProductGroupId)`, associació `(ProductGroupId, BrandCode, VariantTypeId)`, assignació SKU–valor PK intacta, registre `(BrandCode, ParkodVariantCode)`. Cap nom de taula/columna nou o categoria/línia principal substitutiva.

| Entitat | Camps vigents | Canvi respecte del tall D379 |
|---|---|---|
| Parkod | 9 | Tipus/nul·litat/font intactes; domini CCATEG precisat a dos dígits. |
| ProductGroup | 7 | Retirar CategoryCode/LineCode; ID per marca. |
| ProductVariant | 8 | Camps conservats; categoria/línia pròpies, FK grup marca–ID. |
| VariantType | 5 | Sense canvi. |
| VariantTypeValue | 5 | Sense canvi. |
| ProductGroupVariantType | 8 | Retirar CategoryCode; codiNVARCHAR(5). |
| ProductVariantValue | 9 | Retirar CategoryCode, PK intacta. |
| ProductGroupCounter | 2 | Retirar CategoryCode, coordinació per marca. |
| ParkodVariantCodeRegistry | 4 | Retirar CategoryCode, codiNVARCHAR(5)/unicitat per marca. |
| EvaluationAuditEvent | 17 | Columnes intactes; claus/contextos de files noves adaptats. |
| AppAccount | 5 | Sense canvi. |
| AppSession | 6 | Retirar ReservedCategoryCode; reserva marca–grup. |
| SynchronizationStatus | 5 | Sense canvi D379. |
| **Total** | **90** | **13 taules**; ParkodVariantCodeBlock retirada, cap camp afegit. |

Comptador i reserva marca–grup són derivacions directes D380, no acords nous per repetir. CategoryCode del SKU conserva NVARCHAR(2)/zeros, no INT. Marca comuna no dispensa controls compartits o decisió humana. No pertinences alternatives per client. Nom del creador descriptiu segons fórmula existent, no classificació comuna de grup.

#### 6.42.2 Seqüència i compatibilitat de codis

Règim final DE000…ZZZZZ, sense retorn/blocs previs/reciclatge. Vxxxx/V0000 i ZZZZZ→00000 substituïts, no alternatives. Unicitat per marca, registre permanent, màxim+successor sota coordinació SQL i restricció única, finalització atòmica. Moment fase3/principal/mínim d'un requerit/valors exigits intactes, més D392. No codi per SKU/valor o ID nou del grup.

D397 manté French_CI_AS per cercar el màxim ordenat; BIN2 proposada no adoptada. Màxim = codi més avançat ja registrat per aquella marca, inclosos retirats, no quantitat de SKU o MAX(ProductGroupId). Ordre/accés/SQL2017 encara per provar (§6.43.3), sense canvis a collations físiques o dades.

BrandCode3+codi5 = identificador extern8. CCATEG dos dígits i absència de retorn fan disjunts els dos espais després de marca, sense escaneig o filtre nou. D389 només retira CPROD d'antics blocs/correu específic, altres causes d'admissió intactes. Càrrega externa completa/appreadonly conservats; retirada del model no autoritza DROP/neteja d'una taula real.

#### 6.42.3 Matriu confirmada de discrepància de línia

Desajust **conegut al context revisat** entre CLIGNE local i LineCode del SKU, no canvi concurrent ignorat o còpia indisponible. D363 preserva files/IDs/valors/decisions fins revisió, sense flags a0 automàticament. SKU al seu únic grup mentre espera, sense cinquena validació o flag nou.

| Operació | Criteri vigent | Origen |
|---|---|---|
| Validar ordinàriament pertinença SKU–grup | Bloquejada fins a resolució de línia; controls de no-op no esquiven la regla. | D390 |
| Corregir línia i confirmar continuïtat al mateix grup | Permès: CLIGNE local revisada→LineCode, pertinença1, risc anterior conservat, assignacions intactes. | D384–D385 |
| Corregir línia amb trasllat a existent o grup propi nou | Permès segons controls conservats, marca comuna, nova pertinença1/riscNULL. | D380/D384–D385 i regles no substituïdes |
| Validar configuració del ProductGroup | Permès, no valida membres/valors o línia. | D391 |
| Aprovar associació grup–tipus en fase2 | Permès, IsValidated1/codeNULL, cap aprovació de pertinences/valors/línia o principal nou. | D393 |
| Substituir A aprovada sense codi per B candidata, totes dues sense assignacions al grup | Permès amb discrepància coneguda, retirada/aprovació atòmiques; incidència de línia, SKU/valors/principal/codis intactes. Cas estricte §6.27, no qualsevol substitució. | D398/D295–D296 |
| Substitució completa amb retirades/rebutjos expressos d'assignacions d'A i retirada d'A | Permès amb discrepància coneguda segons §6.11 i admissibilitat pròpia de cada decisió; incidència pendent/LineCode-grup-pertinença intactes. D392 abans de codi nou de B, codi existent propi conservat, altres controls/atomicitat intactes. | D404/D182–D185 |
| Corregir candidata grup–tipus amb B nou o existent | Permès segons §6.26/A sense assignacions; incidència pendent, cap pertinença/línia/codi nou implícits. | D399 |
| Rebutjar candidata grup–tipus o SKU–valor, o proposta nova sobre valor validat | Permès pels tres circuits específics: només candidata admissible eliminada o validada intacta segons cas. Incidència pendent. | D400/D247/D244/D282 |
| Rebutjar propostes no persistents, individuals o conjuntes | Permès §6.20/§6.25, només auditories expresses/sense DML de negoci; no aprovació de pertinences. | D400 |
| Alta manual de tipus existents al grup existent | Permès §6.21/lot atòmic/associacions absents/1-codiNULL, sense valors/pertinences/línies/principal/codi final nous. | D401 |
| Corregir assignació de valor ja validada | Permès, risc/originals/no-op del circuit conservats. | D369 |
| Confirmar candidata SKU–valor | Permès, circuit propi, no valida pertinença/corregeix línia/finalitza codi. | D394 |
| Primera assignació manual de valor | Permès, absència revisada/tipus aprovat/controls existents; no upsert. | D394 |
| Assignar codi NOU a l'habilitació | Bloquejat si algun SKU requerit té discrepància pendent; sense consum o estat parcial. | D392 |

Requerits = SourceIsPresent1 i pertinença IsValidated1 D255–D256. Un validat amb canvi CLIGNE pendent conserva el flag però exigeix línia resolta abans de codi nou. No veto addicional pels altres membres, codi antic immutable, grup buit/només retirats no consumeix codi nou. Elegibilitat/exportació prèvia D80 intactes.

Corrector sense aprovació ordinària prèvia circular. D395 concreta §6.38: mateixos procediments d'existent, dos blocs complets encara coincidents i auditoria només de files canviades. CCATEG canviada continua essent nou SKU D04/D106, no categoria classificada mutable. La disponibilitat D396 es contrasta separadament de cada permissió de línia coneguda.

#### 6.42.4 Mapa de contractes a revisar sense inventar aprovacions

| Família | Adaptació exigida / límit |
|---|---|
| §6.8–§6.11/§6.15–§6.27 |25signatures amb categoria adaptades al lot §6.45, formes de les famílies revisades actualitzades. Vuit SKU–valor conserven signatures/grup reduït3/associació5. Altres contextos/plantilles/comparadors encara E02, membres/raw_value intactes. D404 cobreix línia en substitució completa. |
| §6.14/§6.30 | Usages, claus d'inactius i bloquejos de tipus sobre usos complets; no esborrar categoria del SKU o aprovar altes exclusives/via excepcional ValueKind. |
| §6.28/§6.29 | Sessions adaptades: reserva2/resposta4/sessió segura5/llista8, tancament/admin/auditoria/rutina intactes. Autenticació/comptes/signatures no afectades conservats. |
| §6.32–§6.34 | Nom/desactivació contrastats: grup7/resposta de desactivació4/candidat7+indicador separat/inactius7/marca-all/ordre marca–ID. §6.34 conserva matriu històrica G9/R5 com a referència, no tots els seus contextos revisats. |
| §6.36–§6.38 | D390–D391 conservats; D395 concreta via existent/sense trasllat a §6.38, set blocs i tres conjunts. Quatre signatures de destí de §6.18/§6.38 sense categoria; formes restants encara E02, no API nova. |
| §6.39 | Complete7paràmetres/resposta5columnes intactes; CCATEG dígits, motiu d'exemple actualitzat car CPROD reservat ja no és rebuig. Lectors/escriptors SKU encara per definir. |
| §8.8 |76noms,29retirades de categoria ja reflectides igual que als contractes,47altres signatures intactes. Inventari actual d'arguments, no76contextos/retorns tots contrastats o SQL executable. |

Originals/snapshots històrics immutables, context antic no acceptat afegint defaults/ignorant camps/ometent controls. No Undo genèric, versió, registre de tasques o font nova. SourceIsPresent0, discrepància de línia i ParkodRefreshSucceeded0 són diferents; D396 resol ara el criteri funcional de disponibilitat, no la protecció concurrent executable.

### 6.43 Lot consolidat del xat — D395–D398

#### 6.43.1 Disponibilitat segons dependència real de Parkod — D396

**Regla transversal confirmada per a les revisions de l'app:** si construir o verificar el context requereix dades de VARIANTS_PARKOD.dbo.Parkod, ParkodRefreshSucceeded=0 impedeix retornar un nou context revisable o executar confirmació/rebuig formal. El mateix0 cobreix càrrega en curs i fallada; no atribuir-ne causa només pel valor. Avís extern en francès, no context parcial, arrays buits o null ficticis per representar dades indisponibles. No s'han aprovat un camp/estat nou, signatura, columna de resposta o catàleg d'errors per aquest acord.

No modificar dades, crear catàleg/assignació anticipats, eliminar candidates o auditar una accepted/corrected/rejected/confirmed_change que no s'ha executat. Indisponibilitat és incidència tècnica, no decisió humana o prova de rollback d'una petició anterior incerta. Cancel·lar edició manual/tancar pantalla continua permès pels circuits existents; la indisponibilitat no expulsa sessions, allibera reserves o esborra edicions manuals per si sola. Resta de controls de sessió/permisos/activitat/reserva/integritat/auditoria intactes.

Després d'una fallada, només publicació externa **completa verificada i correcta** D379 acredita recuperació; data anterior/COMMIT previs o un èxit per marca no basten. Per reprendre la decisió cal nova lectura i revisió de context, no reenvio automàtic/antic context/fusió silenciosa. No cache, refresc automàtic, versió/HASH o transacció de formulari nous.

**Sense dependència de còpia:** no afegir veto només per l'indicador0 si tot el context es pot obtenir i verificar amb dades pròpies. Un grup realment buit pot ser un cas, però no una exempció automàtica: l'operació ha de continuar admissible segons el seu contracte i tots els altres controls. [] significa absència real de membres/usos, no informació que no s'ha pogut llegir. Revalidar composició/context en confirmar; alta/baixa concurrent exigeix nova revisió, no ús de l'exempció d'un grup que ja no és el revisat.

| Família contrastada | Aplicació del criteri, no excepció nova de permisos |
|---|---|
| ConfirmVariantValueCorrection, ConfirmVariantValueProposal, ConfirmNewVariantValueAssignment | Els tres contextos necessiten el Parkod del SKU; amb0 no confirmar. Fila validada/candidata/absència continuen sent circuits diferents, cap upsert. |
| GetVariantValueCorrectionContext, GetVariantValueProposalContext, GetNewVariantValueAssignmentContext | Amb0 no retornar context revisable o dades font parcials; cap buidatge de candidata, catàleg o edició per la lectura. |
| RejectVariantValueProposal, RejectVariantValueCorrectionProposal | Amb0 no executar el rebuig formal ni auditoria. La candidata es conserva; assignació validada/catàlegs intactes. Cancel·lació manual no és rebuig. |
| GetGroupVariantTypeProposalContext, ApproveGroupVariantTypeProposal, RejectGroupVariantTypeProposal | Amb membres reals, Parkod dels membres és necessari: també retirats i pertinences pendents. Amb0 no context/aprovació/rebuig; grup realment buit sense dependència conserva admissibilitat ordinària. |
| Validacions de grup/pertinença, correctors, trasllats, creacions, substitucions i finalització | Contrastar context complet per circuit; la regla transversal s'aplica a les dades Parkod realment necessàries, no només a la fila que es modifica. Corrector/trasllat d'un SKU no esdevé independent perquè el destí sigui buit. Finalitzar un codi nou continua exigint almenys un requerit; buit no permet saltar el contracte. |
| Catàleg i editorials | GetVariantTypeCatalog de dos blocs és independent. Usages editorials amb assignacions inclouen SourceIsPresent de còpia (§6.14.6): quan existeixen, cal Parkod. Sense usos reals, no inventar-ne o imposar aquest veto per mera existència d'associacions, mantenint tots els controls històrics. |
| Principal, nom descriptiu, comptes i sessions | Els contractes que no necessiten Parkod no reben veto nou; principal segueix habilitacions del grup, no SKU/valors. Autenticació, alliberament/neteja/revocació de sessió conserven les regles pròpies. |

És el criteri final que engloba les confirmacions successives del xat, no vuit decisions noves pels vuit procediments SKU–valor. D369/D394/D398 davant d'una discrepància **coneguda i disponible** es mantenen; SourceIsPresent0 no es converteix en còpia indisponible o nou veto a retirats. D377–D378 continuen aplicant-se a la llista depenent de còpia, sense llista parcial presentada com a completa.

**Límits:** generador Parkod existent independent D129, indicadors0 informatius al log, cap exportador/vista nova. El cicle batch conserva coordinació i tancament propis: D396 no és un veto que impedeixi netejar/tancar tècnicament una execució fallida o una sessió. Les consultes administratives d'incertesa no s'assimilen a una confirmació/rebuig humà per analogia; conservar D238/D249–D252/D305 i contrastar les dependències exactes que pertoquin. No excepció nova d'autenticació, atribució o recuperació automàtica.

**Precisió D402–D403:** error SQL identificable i esquema Shared/Exclusive ara confirmats (§6.44.2–§6.44.3). No signatura/resposta d'èxit nova o lock físic de taula. E05 encara ha de completar matriu exacta, numeració/transport detallat, recurs/esperes/permisos/seqüència executable/integració/proves. Comprovar1 aïllat no garanteix estabilitat, disseny no prova cooperació externa. Sense veto global GUI/login, locks de formulari o canvi original.

#### 6.43.2 Adaptacions directes d'E02 i contrast parcial d'E04

**Tall històric D398:**29signatures afectades per categoria al tall D379, quatre de destí adaptades aleshores i25pendents. **Estat actual després del contrast §6.45:** les25CategoryCode restants també retirades,29en total i inventari §8.8 alineat; altres arguments/tipus/ordre/defaults conservats. Altres47noms sense aquesta retirada no equivalen a contextos intactes: vuit SKU–valor revisats en aquest lot, altres formes E02 pendents. No76interfícies íntegrament contrastades.

| Forma actual segons D380, no camp nou | Camps/adaptació directa |
|---|---|
| ProductGroup complet | Set: ProductGroupId, ProductGroupName, BrandCode, PrimaryVariantTypeId, EstimatedRiskPercent, IsValidated, IsActive. |
| ProductGroup reduït SKU–valor | Tres: BrandCode, ProductGroupId, IsValidated; activitat comprovada a SQL, no IsActive afegit al reduït. |
| Associació/assignació completes | ProductGroupVariantType8 i ProductVariantValue9 segons diccionari; CategoryCode retirada només d'aquestes files, no del SKU. Codi d'associacióNVARCHAR(5). |
| Sessió i respostes segures | AppSession6/snapshot segur5 sense hash, reserva-alliberament4 (AppSessionId, ReservedBrandCode, ReservedProductGroupId, LastActivityAtUtc), no AppAccountId afegit. Llista administrativa8. Formes detallades contrastades a §6.28/§6.45.4, no rutina auditada o control nou. |

**Trasllat ordinari i creació conjunta:** mateixa marca, categories/línies diferents admeses; D390 exigeix línia resolta de cada pertinença que s'aprova. No implica exigir-ho a tots els membres d'origen/destí o seleccions rebutjades que no es traslladen. Creador seleccionat/aprovat D261, almenys un approve, totes les assignacions preservades i decisions individuals D266. Manual sense proposta exclòs: canviar selecció i renovar context, no rejected fictícia. Cinc blocs/quatre conjunts de creació i set blocs/dos conjunts de trasllat conservats; només files/claus segons model.

**Substitució completa D183/D392:** si B ja té codi final propi, es conserva i D392 no introdueix un veto nou de línia per codi NOU inexistent en aquella crida. Si B necessita codi nou, tots els requerits presents/pertinença validada amb línia resolta; no veto addicional pels altres membres. Resta de controls/context/valors/principal/retirades expresses/auditoria atòmics intactes. Codi d'A mai transferit/reciclat, preparacions confirmades prèvies de B no desfetes per rollback conegut de la transició.

**D404 posterior, no extrapolació de D398:** discrepància coneguda no bloqueja per si sola les retirades/rebutjos individuals expressos d'assignacions d'A i retirada de l'associació A en el circuit complet; condicions pròpies de cada decisió/D392/altres controls intactes. Incidència de línia pendent, sense LineCode/grup/validació de pertinença canviats (§6.45.1).

Aquest contrast no aprova tots els mutadors/altes/substitucions per semblança. D398 cobreix §6.27, D399–D401 els enumerats §6.44.1 i D404 el circuit complet §6.11; altres casos E04 oberts, no permissió universal.

#### 6.43.3 Màxim ordenat dels codis i French_CI_AS — D397

Màxim = codi més avançat del registre permanent **d'una marca**, actuals/retirats inclosos, no nombre de variants ni ProductGroupId. Sense cap codi: primera assignacióDE000. Amb codis: successor en alfabet0–9/A–N/P–Z; ZZZZZ implica esgotament sense retorn o estat parcial. Exemple fictici: DE000, DE001 i DE00N → màximDE00N → següentDE00P, saltant O. No omplir forats o reciclar retirats.

Mantenir comparació French_CI_AS ja aprovada; amb longitud5 i alfabet ASCII majúscul validats és esperable l'ordre requerit, **no és una prova feta**. La proposta Latin1_General_100_BIN2 només a l'expressió es va retirar: no afegir dependència sense necessitat demostrada. Verificar ordre i pla d'accés en2017; no prometre que COLLATE acceleri el càlcul ni que MAX impliqui ordenar tota la taula. Un índex adequat pot ser aprofitable, disseny físic/proves pendents, no índex nou aprovat aquí.

Coordinació SQL exclusiva per marca, restricció única i registre/codi/associació/principal/auditoria en la mateixa transacció D382 intactes. Màxim/successor no són protecció concurrent. Comptador d'IDs de grup separat, cap MAX+1 de grups o comptador de codis nou. Collations/font/configuració/dades intactes; alternativa només amb justificació/revisió prèvies, no canvi silenciós.

### 6.44 Lot consolidat: línia coneguda, error i coordinació — D399–D403

#### 6.44.1 Casos de línia expressament permesos, no excepció d'integritat

Desajust CLIGNE/LineCode **conegut al context revisat**, dades necessàries disponibles. Incidència pendent, cap correcció automàtica de línia/presència/pertinença o codi nou per aquests acords. Permisos/sessió/reserves/grup actiu/integritat/context/atomicitat/auditoria i estats propis intactes. Context canviat exigeix nova revisió; D396/D402–D403 separats, no []/null ficticis per manca de dades.

**D399 — dues correccions de candidata:** CorrectGroupVariantTypeProposalWithNewType i CorrectGroupVariantTypeProposalWithExistingType (§6.26). A0/codiNULL/original/sense assignacions al grup, també pendents/validades/de retirats; no eliminar assignacions per fer-la admissible. B nou amb definició4propietats/ID real en confirmar, o B existent segons D177–D179: associació absent creada amb metadades d'A, candidata amb originals/riscs propis revisats, aprovada intacta sense auditoria fictícia. Altres grups/catàlegs/usos preservats, dos conjunts/UUID i auditories originals de cada cas intactes; no convertir en substitució d'A aprovada/amb assignacions.

**D400 — vuit rebutjos enumerats:**

| Procediment | Efecte i condicions anteriors conservats |
|---|---|
| RejectGroupVariantTypeProposal | D247: candidata0/codiNULL/sense assignacions/original; una rejected amb Before complet i eliminació només d'associació atòmiques. Grup/SKU/catàlegs/historial preservats, no rebutjar fase2 aprovada per aquesta via. |
| RejectVariantValueProposal | D244: assignació candidata0/original, una rejected/Before complet/After-resultatNULL i DELETE només de candidata; SKU/catàleg/tipus/grup conservats. |
| RejectVariantValueCorrectionProposal | D282: proposta nova expressa del backend sobre fila1, una rejected/snapshots-resultatNULL; assignació/risc/originals/validació/catàlegs íntegres, clau amb valor actual real. |
| RejectProductGroupProposal | D269: només proposta de grup no creat, auditar sense crear grup o rebutjar fills implícitament. |
| RejectNewGroupVariantTypeProposal | D270: només proposta d'associació per grup nou, auditar sense eliminar catàleg o rebutjar grup/altres propostes. |
| RejectNewGroupMembershipProposal | D271: només proposta de pertinença a grup nou, auditar amb grup anterior real/estat vigent intacte. |
| RejectGroupMembershipMoveProposal | D272: només proposta no persistent de trasllat a existent, auditar amb destí original revisat/grup anterior real, cap trasllat/retirada/desfer implícits. |
| RejectProductGroupCreationProposals | D285–D289: almenys un rebuig exprés, grup/pertinences/tipus amb originals/fonts/riscs individuals, una auditoria per decisió/UUID comú/tot o res, cap DML de negoci/comptador/codi. |

Els cinc últims circuits només auditen: no creen ni eliminen classificacions vigents, snapshots/resultat SQL NULL segons contracte. Originals/fonts/riscs/identitats/contexts no s'ometen perquè hi hagi discrepància. Lector conjunt GetProductGroupCreationRejectionContext D289 conservat, no API nova. Cada resposta de rebuig continua només OperationId post-COMMIT; crides individuals no comparteixen UUID automàticament. Cancel·lació manual no és rejected, error tècnic no inventa decisió humana, incertesa D238 intacta.

**D401 — alta manual d'associacions:** AddGroupVariantTypes/GetGroupVariantTypeAdditionsContext (§6.21). Tipus de catàleg existents compatibles, grup existent, array no buit/sense duplicats; qualsevol associació existent, també candidata, invalida el lot i exigeix revisió. Associacions1/codi-risc-originalsNULL, una confirmed_change/create per fila/UUID comú i dos conjunts D275, sense catàleg/valors SKU/codis/principal nous. No aprovació de pertinences o resolució d'incidència.

Matriu §6.42.3 ampliada només en aquests casos. D390 continua bloquejant aprovació ordinària de pertinença amb línia pendent; D392 exigeix línies resoltes dels requerits abans de codi NOU. D369/D394/D398 intactes. Altres retirades/no-op/mutadors no coberts continuen E04, no tornar a consultar els casos confirmats.

#### 6.44.2 Error SQL d'indisponibilitat identificable — D402

Quan la indisponibilitat D396 impedeix una operació dependent, SQL la comunica amb **error específic identificable pel backend sense dependre del text del missatge**. No context revisable parcial/buit fictici, resposta d'èxit o OperationId que aparenti decisió executada. Signatures/conjunts/columnes d'èxit existents conservats, no camp/taula/resultset d'estat nou.

Backend diferencia aquest error explícit d'un rebuig humà, conflicte de context o resultat perdut. GUI francesa, detalls tècnics/logs anglesos/sense secrets. D396 conserva dades/candidates/edicions, altres controls i nova lectura/revisió després de publicació completa correcta; no cancel·lació/reenvio/expulsió automàtics. No auditar una decisió no executada.

**D238 intacte:** timeout/connexió perduda/resposta incompleta no es tradueixen per comoditat en aquesta indisponibilitat controlada ni proven rollback. Rebre error SQL explícit i perdre resultat són situacions diferents. No recuperació automàtica, identificador de petició/idempotència o fallback administratiu ampliat.

**Pendent E05:** número/identificador exacte, metadades de transport/mapping backend/missatge final, seqüència d'error/ROLLBACK i proves. No s'escullen THROW/RAISERROR, driver, framework o catàleg general d'errors, ni s'implementa SQL. Dependència T-SQL inventariada §6.12, comentari anglès al futur punt d'ús.

#### 6.44.3 Coordinació lògica de còpia, no bloqueig físic de taula — D403

Reutilitzar recurs lògic de coordinació de còpia §6.7 dins VARIANTS_PARKOD mitjançant **sp_getapplock**. Mateix recurs/àmbit SQL efectiu entre participants, no quart recurs/taula/flag/versió nou o objecte a parkod. Exclusió càrrega–conciliació D365 i sessions–conciliació D367 conservades; no modes executables addicionals de batch/login concretats per aquest acord.

| Participant dependent | Accés lògic i durada confirmats |
|---|---|
| Carregador extern complet | Exclusive obligatori abans de marcar inici/modificar còpia; mantingut per connexió durant tota la càrrega fins a publicar resultat, després alliberar. Sense transacció global oberta. |
| Lector de context que necessita Parkod | Shared només durant lectura SQL curta, abans de fixar estat llegit/SNAPSHOT i comprovar indicador; alliberat en acabar lectura. |
| Confirmació o rebuig que necessita Parkod | Shared durant operació curta, indicador/context actual comprovats sota protecció, manteniment fins COMMIT/ROLLBACK. No escriure sobre SNAPSHOT antic de revisió. |

**Per què compartit:** revisions poden coexistir, subjectes als altres controls/bloquejos. Carregador exclusiu no pot coincidir amb aquelles operacions curtes. No es bloqueja el formulari: entre lectura i confirmació no es manté aquesta protecció; en confirmar es torna a obtenir i revalidar tot el context rellevant. SNAPSHOT coherent no impedeix iniciar càrrega ni substitueix protecció de confirmació. Seqüència executable haurà d'evitar fixar SNAPSHOT antic abans d'obtenir protecció.

**Com ho coneix SQL:** procediment demana recurs lògic i comprova resultat d'adquisició; no necessita inferir taula físicament bloquejada. Si no obté accés per incompatibilitat, no pot garantir accés coordinat, però això no prova càrrega en curs, identitat d'un propietari concret o TABLOCK. Errors de permisos/adquisició/deadlock i connexió perduda no es disfressen de càrrega coneguda o indisponibilitat controlada. Mapping de resultats/esperes pendent, D238 conservat.

**Indicador igualment necessari:** després d'adquirir protecció es comprova ParkodRefreshSucceeded. Amb0 no context revisable/confirmació/rebuig dependent encara sense carregador actiu; fallada pot alliberar recurs deixant0/data anterior. Només completa verificada/publicada correcta D379 acredita recuperació. No dependre d'indicador1 observat abans de bloqueig ni applock sense comprovació d'estat.

**Cooperació obligatòria del carregador:** obtenir Exclusive sobre el mateix recurs abans de marcar inici/tocar còpia, mantenir connexió/coordinació tot el procés, publicar estat final abans d'alliberar. Sense obtenir-lo no modificar descoordinadament. Connexió perduda exigeix aturar segons protocol existent: no continuar sense protecció, assumir rollback de COMMIT previs o marcar preparada. Obligació també §6.35.5/Parkod.md §23.6; carregador extern, no implementat aquí.

**Límits:** no TABLOCK/bloqueig deliberat de taula sencera, NOLOCK, transacció de formulari o canvi original. Applock no obliga escriptors no participants, no elimina bloquejos normals del motor ni garanteix impacte nul. Operacions realment independents no reben aquest requisit per analogia; buit no exonera context/elegibilitat. Generador D129 independent, no adopció obligatòria d'aquest recurs per ell o veto global GUI/login. No SNAPSHOT a parkod, taula de locks/signatura/resposta d'èxit nova.

**Pendent E05/E09:** nom/àmbit/identitat SQL efectiva del recurs, permisos, propietat d'adquisició/alliberament i connexions, esperes finites/mapping de resultats, ordre amb tipus→SKU→marca→grup, matriu exacta per procediment, integració/proves de carreres/fallada/desconnexió. Shared/Exclusive/durades decidits, no prova SQL/integració feta. Cap fail-fast concret, reintents o planificador nous aprovats.

### 6.45 Revisió E02 consolidada i substitució completa amb línia coneguda — D404

#### 6.45.1 Única decisió nova del lot: substitució completa — D404

Confirmació expressa després de comprovar D182–D185/D392, no derivació del cas reduït D398 ni dels vuit rebutjos D400. En ConfirmGroupVariantTypeReplacement (§6.11), discrepància CLIGNE/LineCode **coneguda al context revisat** no impedeix per si sola les retirades/rebutjos individuals expressos d'assignacions d'A ni la retirada de l'associació A.

Cada decisió conserva admissibilitat pròpia: retire funcional amb auditoria de retirada; reject només candidata pendent amb original disponible, no conversió automàtica d'una via en l'altra. Una decisió per totes i cadascuna de les assignacions revisades d'A, incloses validades/de retirats, cap conservada com a fila si es retira completament A. Catàlegs/historial preservats, sense DELETE CASCADE o eliminacions per SourceIsPresent0.

Incidència pendent, sense modificar LineCode, grup actual del SKU, validació/risc de pertinença o còpia; cap aprovació per herència. «No canviar grup» es refereix a ProductVariant.ProductGroupId, no impedeix l'ajust atòmic de ProductGroup.PrimaryVariantTypeId ja previst per D183/D235. Valors requerits de B/principal/context/sessió/permisos/reserva/grup actiu/integritat i dades–auditoria atòmics conservats. Preparacions ja confirmades de B no es desfan per rollback conegut de la transició. D238 continua distingint resultat incert, sense reenvio/rollback presumptiu/rejected fictícia.

**D392 no canvia:** si B necessita codi NOU, línies dels requerits presents/pertinença validada resoltes abans de consumir-lo; sense veto nou als altres membres. Si B ja té codi final propi, conservar-lo. El d'A queda permanentment reservat, mai transferit/reciclat. Principal final coherent segons habilitacions, no B escollida arbitràriament. D396/D402–D403 sobre dades necessàries disponibles/coordinació intactes. No retirada universal, nou no-op o ampliació automàtica del circuit reduït.

#### 6.45.2 Adaptacions de signatures, no25decisions noves

Derivació directa D380/D386; els assentiments del xat no creen una decisió nova per cada argument retirat.25signatures que encara contenien CategoryCode ara el retiren als contractes i inventari §8.8, **sense cap altre canvi de tipus/ordre/defaults**. Juntament amb quatre DestinationCategoryCode retirades D398,29signatures adaptades respecte D379. Mateixos76noms/NormalizeWhitespace separada, no lector/mode/API nou; els altres47noms conserven signatures, no necessàriament totes les formes.

| Família | Noms afectats en aquest lot | Nombre | Contracte |
|---|---|---|---|
| Sessions | ReserveProductGroup, ReleaseProductGroup |2| §6.28 |
| Principal | GetProductGroupPrimaryVariantTypeContext, SetProductGroupPrimaryVariantType |2| §6.22 |
| Nom | SetProductGroupName |1| §6.32 |
| Desactivació/inactius | GetEmptyProductGroupDeactivationCandidates, DeactivateEmptyProductGroup, GetInactiveProductGroups |3| §6.33 |
| Candidates grup–tipus | GetGroupVariantTypeProposalContext, ApproveGroupVariantTypeProposal, RejectGroupVariantTypeProposal |3| §6.15.5–§6.15.7 |
| Correctors de candidata | CorrectGroupVariantTypeProposalWithNewType, CorrectGroupVariantTypeProposalWithExistingType, GetGroupVariantTypeProposalCorrectionContext |3| §6.26 |
| Substitució reduïda | ConfirmGroupVariantTypePhase2Replacement, GetGroupVariantTypePhase2ReplacementContext |2| §6.27 |
| Alta manual | GetGroupVariantTypeAdditionsContext, AddGroupVariantTypes |2| §6.21 |
| Validació de grup | GetProductGroupValidationContext, ConfirmProductGroupValidation |2| §6.36 |
| Finalització | GetGroupVariantTypeFinalizationContext, FinalizeGroupVariantType |2| §6.17 |
| Substitució completa/incertesa | GetGroupVariantTypeReplacementContext, ConfirmGroupVariantTypeReplacement, GetUncertainOperationContext |3| §6.11/§6.16 |
| **Total** | CategoryCode retirat, no altres arguments | **25** | No tancament global d'E02 |

Marca exactament3 abans de convertir/ID positiu i clau marca–grup, sense categoria comuna deduïda. Selectors de buits/inactius: només marca opcional o totalitat. Consulta incerta: OperationId informat i quatre arguments marca–grup–A–BNULL, o OperationIdNULL i tots quatre informats, fallback només per substitució. Autenticació, comptes, token, funció de blancs i CompleteD373 intactes.

#### 6.45.3 Vuit procediments SKU–valor sense canvi de signatura

GetVariantValueProposalContext/ConfirmVariantValueProposal/RejectVariantValueProposal; GetVariantValueCorrectionContext/ConfirmVariantValueCorrection/RejectVariantValueCorrectionProposal; GetNewVariantValueAssignmentContext/ConfirmNewVariantValueAssignment. D248/D278/D283 reutilitzen expressament set blocs; adaptació D380 a §6.15.3, sense forma universal per a altres circuits.

| Bloc exacte | Forma vigent |
|---|---|
| ProductVariantValue | Fila completa9; JSON null obligatori només en alta absent. |
| ProductVariant | ProductVariantId, BrandCode, CategoryCode, ProductCode, ProductGroupId, LineCode, IsValidated: set camps reduïts, no risc afegit. |
| ProductGroup | BrandCode, ProductGroupId, IsValidated: tres camps reduïts. |
| VariantType | Cinc camps complets. |
| VariantTypeValues | Valors complets5 sense IDs repetits, segons estat/selecció. |
| ProductGroupVariantType | ProductGroupId, BrandCode, VariantTypeId, IsValidated, ParkodVariantCode: cinc camps reduïts/codiNVARCHAR(5)nullable. |
| Parkod | CLIGNE, SourceIsPresent de la còpia local. |

**No substituir grup3/associació5 per files completes7/8 ni afegir IsActive**; activitat comprovada a SQL. Conservar categoria/línia pròpies del SKU i evidències, sense còpia/source escrits. Candidata0, validada1 i absent són estats diferents/no upsert. Original/actual sempre inclòs amb fila existent; alta absent només seleccionat existent o [], valor nou desitjat separat. Rebutjos sense seleccionat addicional. Fila apareguda/context canviat exigeix revisió, no sobrescriure.

Tres confirmacions: dos conjunts d'una fila capturats internament/post-COMMIT, primer OperationId+assignació9, segon valor final5 existent/nou. Candidata/primera alta UUID informat, primera alta1/risc-originalsNULL/no no-op. Correcció manual mateix ID conserva fila/metadades i no audita/UUIDNULL; proposta nova sense canvi audita decisió amb nous originals/risc/resultat, snapshotsNULL/fila intacta. Canvi efectiu manual neteja tres metadadesNULL/amb proposta nova les reemplaça segons D279, Before antic complet. XOR/decimals/textos/duplicats/IDs reals D239/D236 intactes, codi final no requerit per preparar valors/no fase3 automàtica.

Dos rebutjos: una fila OperationId; candidata audit+DELETE només d'assignació admissible, proposta nova sobre validada només audit/fila-risc-originals intactes. Cancel·lació manual no és rejected. Tots vuit necessiten Parkod; línia coneguda permesa D369/D394/D400 sense resoldre-la, però còpia indisponible0 impedeix context/confirmació/rebuig formal D396. D402 error identificable i D403 Shared durant operació curta/mai formulari, detalls SQL/proves encara pendents.

#### 6.45.4 Formes de les famílies contrastades

| Família | Forma actual i límits conservats |
|---|---|
| Sessions/reserves | AppSession6/sessió segura5, resposta reserva-alliberament4 exactament AppSessionId/ReservedBrandCode/ReservedProductGroupId/LastActivityAtUtc, no AppAccountId afegit. Reserva dos camps informats o tots dosNULL. Context forçat AppAccount4/AppSession5, llista administrativa8. Reservar exigeix grup actiu/alliberar no, rutines sense auditoria ni UUID; tancament forçat una auditoria/snapshot segur5. |
| Principal/nom | Lector principal tres blocs grup7/associacions8/tipus5, sense membres/valors. Setter principal ID obligatori/NULL només zero finals; nom consumeix només bloc ProductGroup7 i nom desitjat separat. Resposta OperationId nullable+grup7, no-op després de tots els controls. NomNULL sense nom/no regeneració, normalitzat<=150/no buit/no unicitat/fonts no consultades. Sense nova dependència de Parkod. |
| Desactivació | Candidats grup7+HasActiveReservation calculat fora del bloc/context; esperat només ProductGroup7. Resposta quatre camps OperationId/BrandCode/ProductGroupId/ResultCode, inactius set camps. Marca/all/ordre marca–ID. Ordre auth-forma→existeix→already_inactive→context_changed→not_empty→reserved→deactivated. ZeroSKU també retirats-pendents/cap reserva vigent també pròpia, només canvi audita Before-After7/UUID, altres resultats sense canvi/audit. No dependència nova de Parkod. |
| Candidata grup–tipus | Quatre blocs amb grup7/associació8/tipus5/membres reduïts8propietats incloent Parkod2. Tots membres reals/retirats/pendents, no risc de pertinença afegit; [] només buit real. Aprovar1/codiNULL/risc-originals conservats, resposta OperationId+associació8; rebutjar només0/codiNULL/original/sense assignacions i una fila OperationId. |
| Correctors/fase2 | B nou quatre blocs D246+NewVariantTypeJson4 separat; B existent cinc blocs D293/grup7/associacions8, B absent JSONnull/pendent completa/aprovada intacta segons cas, no veto a B aprovada per copiar les condicions de §6.27. Cas reduït cinc blocs però B candidata obligatòria/no null/absent/aprovada, A1/codiNULL i cap assignació d'A-B. Tots dos conjunts OperationId+associacióB8/tipusB5. |
| Alta manual/validació de grup | Quatre blocs amb mateixos noms, no intercanviables: VariantTypes seleccionats per afegir en alta, referenciats per associacions actuals en validació. Lot manual no buit/atòmic/ni associació existent ignorada; resposta OperationId i associacions8 creades. Validació només flag/risc conservat/buit actiu admès, resposta OperationId nullable+grup7; canvi concurrent0→1 conflicte, no no-op antic. |
| Finalització | Sis blocs/grup7/associacions8/assignacions requerides9 o null explícit; membres amb categoria/línia pròpies/Parkod2. Mínim un requerit present-pertinença1, valors1 i línies resoltes D392 abans de codi nou. Resposta OperationId/codiNVARCHAR(5)/principalINT informats, principal opcionalNULL sense nova tria. No codi congelat durant pantalla, consum concurrent no conflicte, codis antics no revocats. |
| Substitució completa/incertesa | Set blocs i decisions exactament ProductVariantId/Decision retire-reject preservats, grup7/associació8/assignació9/codi5/D404. Consulta admin amb dos conjunts: auditoria històrica literal i estat actual per ObjectKeyJson/PK real, inactiu grup7 existent/absent SQLNULL, sense IsActive a claus o fallback nou. Dependències exactes del lector admin encara E05, no veto extrapolat. |

**Plantilla grup–tipus nova, derivació D380:** exactament BrandCode, ProductGroupId, VariantTypeId, Type, Characteristics, ValueKind, ProductVariants; retirar només CategoryCode/LineCode superiors de la base §3.11.2. ProductVariants conserva objectes ProductVariantId/LineCode originals, sense afegir categoria o altres propietats per semblança. DecisionResultJson segueix forma adaptada amb contingut final aprovat/IDs reals quan correspon, línies finals pròpies dels membres, mai línia comuna de grup. Casos d'IDsnull/grup no creat existents intactes. OriginalSourcesJson/raw_value i qualsevol original persistent/snapshot històric no es reescriuen, encara que B conservi originals d'A. Altres plantilles de §3.11.2 continuen E02, no totes convertides.

D393/D399–D401/D391, matriu de línia i resta de controls propis conservats. Contextos de membres reals necessiten Parkod; grup buit només sense dependència real/context complet verificable, no [] per informació indisponible. No signatura nova d'error, camp de tasques, cache/refresc, reactivació, nou càrrec d'auditoria o font addicional.

#### 6.45.5 Represa i pendents reals

**E02 no tancat:** les25retirades d'arguments i les formes anteriors estan revisades, no les76interfícies completes. Continuar per catàlegs/editorials/Usages i metadata d'inactius (§6.14/§6.30), altres contextos compostos/rebutjos/creacions i respostes no contrastades, plantilles restants de proposta/resultat, claus/snapshots/comparadors exactes. Referències històriques G9/R5/taules amb categoria no es completen ignorant propietats ni s'apliquen com a formes actuals. No eliminar categoria del SKU o esborrar evidència.

**E04 restant:** D404 resol només línia en substitució completa de §6.11, no totes les retirades/no-op/circuits possibles. D398/D399–D401/D390–D394 conservats, preguntar només per un cas realment no cobert. **E05:** criteri/error/esquema Shared-Exclusive decidits, però matriu exacta incloent consulta administrativa, número/transport, recurs/àmbit/permisos/propietat/alliberament/esperes/ordre SQL/integració/proves pendents. Cap nou número d'error o timeout inventats en aquest lot.

E03 definit/no SQL provat; E01/E06–E11 conservats a §7. Model13/90/76noms/funció, tres fases/quatrevalidacions, història/source/configuració intactes. Etapa0 oberta; cap SQL/DDL/app/dades/font/configuració, prova de domini-concurrència-integració, commit/push o etapa1–4 implementats.

## 7. Temes no tancats i proves pendents

**Punt de represa canònic, D404.** Model13/90/76noms/funció intactes;29signatures sense categoria (quatre D398+25ara) i formes revisades §6.45, vuit SKU–valor amb signatures intactes. D404 permet substitució completa amb línia coneguda, no tots els casos d'E04. D395–D403 conservats; E02/E04 restants, detalls SQL/integracions/proves pendents, etapa0 oberta. E01–E11 per traçabilitat, no tots decisions obertes.

| ID | Tipus | Treball pendent d'etapa 0 |
|---|---|---|
| E01 | Disseny físic/preparació de proves | Contrastar claus/índexs/CHECK/cascades/collations del model13/90, sense camps nous. Numeració per marca, reserva de dos camps, CCATEG dígits i codi5; DDL/execució només amb autorització específica. |
| E02 | Contractes exactes/adaptació restant |29retirades de categoria i formes revisades §6.45 ja concretades, no25arguments pendents. Continuar catàlegs/editorials/Usages/metadata d'inactius, altres contextos compostos/rebutjos/creacions/retorns, plantilles restants/claus/snapshots/comparadors no contrastats. Vuit SKU–valor grup3/associació5/signatures intactes, no totes76formes validades. Categoria/línia SKU/raw_value/història preservats. |
| E03 | Disseny concretat; materialització/proves pendents | D395 reutilitza el circuit existent, set blocs amb origen/destí complets encara coincidents, tres conjunts/auditoria de files canviades (§6.38). No tercera API per decidir. Després d'autorització, provar forma/protecció/atomicitat/carreres/no-op prohibit, risc conservat o nouNULL i respostes capturades post-COMMIT. |
| E04 | Contrast funcional restant per circuit | D398/D399–D401 conservats; D404 línia coneguda en substitució completa/retirades-rebutjos expressos d'A amb condicions pròpies/D392 intacte ja decidit. No reobrir aquests casos. Completar només altres circuits/retirades/no-op realment no coberts, sense permissió universal o signatures inventades. |
| E05 | Criteri i mecanismes decidits; detalls/SQL/proves pendents | D396 dependència real/buit verificable; D402 error SQL identificable sense parsejar text; D403 Shared curt/Exclusive carregador. Completar matriu exacta, número/transport/error-ROLLBACK, nom/àmbit/permisos/esperes/propietat/ordre executables i integració/proves. No TABLOCK/formulari/indicador aïllat o error d'adquisició convertit en càrrega acreditada/incertesa amagada. |
| E06 | SQL/concurrència/proves | D397 manté French_CI_AS, BIN2 no adoptada. Provar ordre/accés en2017, successor DE000…ZZZZZ sense O/retorn, unicitat permanent i finalització atòmica. Simultaneïtat/límits/esgotament/rollback/incertesa/ordre tipus→SKU→marques→grups. Només amb autorització; no comptador de codis nou o reenvio implícits. |
| E07 | Conciliació i altes | Alta de grup propi sense categoria/línia, noms del creador, lectors/escriptors SKU encara no definits i recomptes. Retirar rebuig/correuCPROD, altres controls intactes. Complete7args/5columnes: parser quatre propietats, CategoryCode dígits, claus exactes sense variant; sumes/claus/Reason no proven lectura completa o causa real. |
| E08 | Consulta de tasques/GUI futura | Consulta/resposta/agrupació/elegibilitat restant, D374–D378 i matriu nova. Retirats: validacions existents admissibles sí/assignacions absents no. Sense reserva/auditoria de lectura, taula/estat de tasques, API/cache/refresc nous aprovats. GUI només a etapa corresponent. |
| E09 | Integracions/metadades/permisos | Carregador obligat a sp_getapplock exclusiu D403 (§6.35.5/funcional §23.6), verificar cooperació/estat/recuperació i detalls del recurs, no implementar-lo o escriure font. Noms/generador/format3+5/CCATEG/permisos/impacte pendents, sense canvi a parkod/coherència interbases presumpta. Diagnòstic anterior no prova compte runtime. |
| E10 | Validació i proves autoritzades | PK/FK/cascades/textos/ValueKind/decimals/JSON/principal/matriu/codis/sessions/admin/reserves/incertesa/rendiment. Dades humanament validades/compatibilitat2017. Configuració140/French_CI_AS/SNAPSHOT ON/RCSI OFF només nova base amb autorització. Cap etapa1–4 o prova SQL de domini ja superades. |
| E11 | Altres contractes no coberts | Completar només operacions encara no detallades. No altes exclusives independents/reactivació/recuperació forçada GUI/excepció ValueKind o recursos nous per semblança. Login/reversió/catàleg/editorial/decimals/quatrevalidacions ja decidits no es reobren. |

**Ordre de represa:** E02 per catàlegs/editorials/Usages i altres formes §6.45.5, E04 només casos no coberts/no D404 a reaprovar. E05 matriu/numeració/transport/recurs sense reobrir D396/D402–D403, E03 definit. E01/E06–E09 en disseny sense SQL, E10 autorització/dades humanament validades, E11 sense ampliar abast. Dependències §6.12/comentaris anglesos al futur punt d'ús; materialització/proves separades de disseny confirmat.

**Proves anteriors preservades:** llistes històriques D330/D379. Referències a14/99, G9/R5, clau triple, blocs/correuCPROD, categoria administrativa o línia comuna **no vigents**. Reutilitzar casos no afectats, adaptar segons E01–E11 i no executar-los com a pla aprovat. Cap SQL/DDL fet en consolidar.

**Proves addicionals D297–D330, totes pendents:**

- §6.28–6.29: longitud/token/caducitat, no renaixement, reserva/release propi/altre/absent, canvi explícit de grup, tancament forçat només altra sessió vigent/IsAdmin actual/context fresc i auditoria sense secrets. D305 sense lector incert nou. Comptes nom normalitzat/duplicat inactiu, autoedició/últim admin/no-op/canvis concurrents, reset propi/aliè/repetit/serialitzat i revocació encara hash igual, bootstrap buit concurrent i recuperació només admin existent sense reactivar-lo. Permisos SQL privilegiats separats, respostes post-COMMIT i cap auditoria app_session extra per password_reset.
- §6.30–6.32: BrandCode NULL/CMARQ, assignacions pendents/retirades, ordinari versus protegit sense salt de via, totes les associacions inactives encara compatibles. ValueKind amb qualsevol valor o aprovació fase 2, no-op amb usos/open_type; sense default/collation/excepció nova. NormalizeWhitespace NULL/buit/idempotència/no truncament; nom NULL edició versus generació en alta, risc/IsValidated intactes, exactitud de majúscules/accents, reserves i integritat/principal no esquivats.
- §6.33: abasts NULL/NULL, marca, marca–categoria; categoria sola/buits/longituds invàlids; zero SKU també retirats/pendents; reserva vigent pròpia/aliena versus caducada. Carreres amb trasllat/incorporació/reserva, ordre dels cinc resultats, UPDATE/auditoria/UUID per canvi i cap auditoria per skips. Interrupció/permisos retirats/caducitat/error no controlat/incert sense reenviament, COMMIT previs conservats, no èxit global fictici o candidats nous afegits.
- §6.34: G9 versus R5, context vell rebutjat sense assumir 1, altes actives; dues columnes editorials del mateix SNAPSHOT/context quatre blocs intacte, metadata []/claus completes úniques, inactius ocults només a presentació i bloquejos històrics preservats. Operacions/no-op ordinaris rebutgen inactiu també per admin; alliberament/neteja no bloquejats. CurrentStateJson G9/IsActive=0 no NULL, snapshots antics intactes. No reactivació/DELETE/ID o codi reciclat/FK/rèplica/font/exportador nous. Revalidar totes les etapes per l'especificació nova, sense afirmar etapes 1–4 o proves de domini superades.

**Base de proves anterior D330, preservada per traçabilitat:** els casos de catàleg, claus, JSON i decisions segueixen útils; les frases següents de còpia escrita, retirades originals/CSV, lector de CLIGNE original o contractes llavors no definits descriuen aquell tall i **no són requisits vigents**. Les prioritats anteriors i §6.35–6.40 els substitueixen en aquests punts. No executar aquesta llista antiga com un pla d'implementació sense el contrast actual.

1. Materialitzar i provar FK de tres camps a la còpia, FK de quatre camps al grup, control protegit de CLIGNE sense FK de línia a la còpia i les dues cascades limitades D67/D101. Política de §6.3 aprovada; la seqüència SQL, els casos encara no classificats i l'impacte de canvis futurs en dimensions de font resten pendents.
2. Materialitzar ProductGroupCounter, funció de blancs, índexs, CHECKs, procediments, permisos i `sp_getapplock`; provar l'ordre tipus → SKU → comptador → grup, concurrència, rollback, timeout, interbloquejos, límit d'INT i transicions de principal. No hi ha DDL ni proves executades.
3. Provar la retirada fiable de §6.7 i completar l'evidència executable de metadades/accessos dels camps consultats no transcrits a §5.5, inclosos noms/preus quan pertoqui. Vuit camps acceptats D230–D231; metadades, PK i unions sense país parcialment contrastades en diagnòstics previs, no garantia de futures càrregues ni prova de domini. Ubicació local/estructura font de referència resoltes D229–D232; IDParkod/IDLine segons §5.3. No inferir PK dels scripts ni autorització de modificar fonts.
4. Verificar la gramàtica decimal de code1, les unitats i els casos límit en codificacions humanament validades; comprovar superposició d'anomalies i U fraccionàries sense reparar l'origen.
5. Materialitzar i provar els contractes JSON de §3.11 i els contextos de §6.8: duplicitats de propietats, noms exactes, NULL/[], imbricació de JSON als snapshots, autoritat dels originals, rebuig amb una sola entrada i eliminació atòmica, operacions conjuntes i reversions. Aquests casos ja estan confirmats; no presentar-ne tot el format com a pendent funcional. Preservar estat anterior validat; no esborranys manuals.
6. AppAccount/AppSession aprovats: materialitzar/provar autenticació, caducitat/reserva, IsAdmin vigent, últim administrador, restabliments i permisos bootstrap/recuperació fora GUI. Provar exclusió atòmica sessions/altre batch/recàrrega i pèrdua de connexió, omissions 0 i logs inequívocs. Tasques externes, sense reintents interns.
7. Via excepcional de canvi de BrandCode D142 i signatures D314–D315 confirmades a §6.30.1–6.30.2: resten implementació/permisos SQL específics, impacte/autorització i proves, no nova aprovació funcional o del nom/signatura.
8. Provar principal segons habilitació final, dependència circular/fase 3. Configurar/provar SNAPSHOT **només a VARIANTS_PARKOD** per generador, substitució, catàleg i editorials; confirmar en transacció actual nova. Protocol de lectura original separat encara pendent. Permisos de lectura/indicadors 0 no bloquejants, sense procés/vista d'exportació ni taules de snapshots a l'app.
9. Validar el DDL i les regles amb codificacions humanament validades abans de passar a l'etapa 1. Incloure unicitat amb BrandCode igual, diferent o NULL, compatibilitat per a tots els Type, bloqueig amb assignacions actives/retirades i concurrència entre assignació, associació i canvi de marca. Provar també el rebuig de rèpliques Type/VariantTypeId/ProductGroupId/BrandCode/CategoryCode discrepants, dos valors del mateix tipus per SKU i tipus no habilitats al grup real. Per al principal: 0/1/més d'1 tipus, grup d'un sol SKU amb tipus, absència de valors assignats, grups buits conservats, tipus aliè al grup, addició/retirada del principal i transicions entre recomptes, sense pèrdua d'assignacions ni seleccions tècniques arbitràries. El recompte i la selecció no han de barrejar grups amb el mateix ProductGroupId en marques/categories diferents.
10. Codis/registre/blocs aprovats: provar candidata de cinc camps, format ASCII, no-col·lisió CPROD, consum V70…VZZ/Z00…ZZZ, canvi de bloc només a xZZ, esgotament, immutabilitat, concurrència i reactivació amb codi nou. Finalització només al final de fase 3 i sense reciclatge; retirada sense violar assignacions/principal. Provar integració externa carregador/SynchronizationStatus, logs/SMTP i generador, sense secrets ni canvis a fonts.
11. Materialitzar ValueKind NVARCHAR(7) NOT NULL, valors admesos, `open_type → text`, XOR local i correspondència al pare sense rèplica nova; unicitats filtrades numèrica/textual. Provar tipus estructurats textuals, prohibició de barreja per VariantTypeId, valors sense assignacions i bloqueig amb associació aprovada sense codi/valors, incloses curses entre canvi de representació, alta de catàleg i aprovació. No s'han aprovat default, collation específica ni via excepcional de ValueKind.
12. Implementar/provar signatures A → B §6.11.2, candidates §6.15 i contractes confirmats §6.16–6.34; formats/lectors ja resolts, 65 procediments inventariats. Completar només altres operacions no cobertes, comparador accepted/corrected executable, protocols de conciliació/correcció CLIGNE i propostes sense ID encara no detallades. Cap alta, validació de grup existent/pertinença sense trasllat o reactivació nova per extrapolació. Reversions/login/global/editorials/gramàtica/cicle de sessió/comptes/abast ja resolts: materialitzar/provar, no reobrir-los; no IDs null extrapolats ni excepció ValueKind.
13. Materialitzar/provar altes/candidates conjuntes §6.10 i preparació global §6.14: cancel·lació, lot buit inicial admès/addició buida rebutjada, col·lisions dins/fora lot, cap ID substituït silenciosament, auditoria de nous/resultats capturats. D239–D240: exactament una via existent/nova, NewValueJson objecte amb propietats exactes/XOR/gramàtica D236, ID real i dos conjunts d'una fila només post-COMMIT; segon també amb valor existent, cap finalització de fase 3 implícita. Altes independents exclusives i altres propostes sense ID no aprovades per extrapolació.
14. Materialitzar/provar §6.11: A/B nova/candidata/aprovada, retire versus reject, tipus complementaris conservats, decisions individuals incloses validades/de retirats, codis propis/principal/FK/auditoria atòmics. Provar canvis de context, absències B, duplicats, conjunts, risc exclòs, originals històrics preservats. Verificar OPENJSON al nivell 140 aprovat de VARIANTS_PARKOD, mai canviar parkod/100; representació executable SQL/JSON, límits i comparacions pendents.
15. Distingir conflicte detectat amb rollback de timeout/connexió perduda després d'un possible COMMIT; provar resposta completa post-COMMIT i invalidació de context antic. Implementar/provar consulta administrativa ja confirmada §6.16: IsAdmin vigent/operacions alienes, XOR d'entrades, auditoria completa per operació/grup A O B, estat per PK real/absències/secrets exclosos i mateix SNAPSHOT. Sense auditoria no provar rollback, petició pot seguir en curs; mantenir incidència si ambigu. No consulta automàtica/reenviament/taules/identificadors nous/idempotència garantida ni extrapolació del fallback a altres circuits.
16. Implementar/provar login §6.13 dins del model intern de confiança acceptat: token 32 bytes, longitud abans de convertir, actiu/hash exacte, restabliment concurrent, sessió única/caducades/exclusió batch i resposta només post-COMMIT. Provar EXECUTE limitat, cap SELECT general d'AppAccount ni secrets a traces. No prometre protecció contra manipulació intencionada ni exigir servei central.
17. Aplicar comentaris D195 en anglès al futur SQL i mantenir inventari §6.12 concordant amb els punts d'ús. Justificar extensions de sintaxi i comportament, preservant garanties SQL, sense canviar scripts legacy ni introduir dependències per documentar-les.
18. Completar l'entorn local identificat a §5.5: VARIANTS_PARKOD ja existeix sense taules però a 150/SQL_Latin1/SNAPSHOT OFF/RCSI OFF. Només amb validació/autorització específica, aplicar/provar 140/French_CI_AS/SNAPSHOT ON/RCSI OFF i desplegar el model; cap canvi a parkod. Proves compatibles amb el destí 2017, no dependències exclusives de 2019. Permisos, materialització/proves d'integracions carregador/lector, relectures CLIGNE i impacte/rendiment/creixement d'auditoria pendents. Seqüència de tasques Windows recàrrega → conciliació i pauta extraordinària D233 ja acordades, no escollir un altre mecanisme ni exigir estabilitat tècnica universal. Qualsevol necessitat d'alterar original exigeix redisseny.
19. Provar §6.14: contextos 2/3/4 blocs exactes, Usages complet sense duplicats/retirats omesos, confirmació humana=1, no-op normalitzat amb context coincident, majúscules/accents versus CI_AI, auditoria de rèpliques Type realment modificades i rollback íntegre si propagació exacta impossible. Provar cursa amb alta/assignació/rebuig/retirada/trasllat/presència/canvi de catàleg respectant bloqueig per tipus, i reversió editorial amb context nou, sense restaurar snapshots sencers.
20. Provar §6.15: diferència de NULL entre lectura/confirmació SKU, valor original sempre inclòs, seleccionat compatible, candidata absent/ja validada, SNAPSHOT dels dos lectors, exclusió d'estat desitjat. Rebuig SKU sense seleccionat addicional i grup només 0/NULL/sense assignacions; una auditoria+DELETE atòmics, conflictes sense decisió fictícia i OperationId post-COMMIT. Aprovació grup sense canvi de tipus/codi/principal i resposta completa; quatre blocs grup i set SKU confirmats exactes, membres/retirats/pendents/[]/sense duplicats. D247 revisat inclòs sense modificar-ne la regla ni ampliar-lo a validades/grups no creats.
21. Provar §6.17–6.19: mínim d'un present amb pertinença validada només per codi nou, retirats exclosos de requerits però presents al context, absències/pendents explícites, no consum concurrent com a conflicte, principal coherent i resposta de tres camps. Trasllats amb set blocs/dos grups, totes les assignacions/rèpliques preservades i dos conjunts. Creació amb cinc blocs, creador explícit seleccionat/aprovat, arrays d'IDs sense duplicats, grups actuals diferents no fusionats, nom NULL automàtic/manual normalitzat i quatre conjunts; fonts dels noms/fiabilitat entre bases encara a integrar. Decisions per SKU i associació independents, rebutjats intactes i zero aprovats sense alta.
22. Provar §6.20–6.22: rebuig de grup/pertinença/tipus no persistents amb originals del backend i auditoria sense snapshots, sense DELETE de dades vigents/rebutjos implícits; destí original versus corregit i claus anteriors reals. Alta manual 1+ tipus existents, cap ignorat si ja associat, lot atòmic/risc NULL/codi NULL, dos conjunts. Principal només habilitacions finals, NULL obligatori explícit diferent de SelectedPrimary opcional, lectura per corregir invàlid, context nou/no-op després de validar, fila intacta sense auditoria/OperationId resposta NULL.
23. Provar §6.23–6.24: absència/candidata/validada diferents, nou valor catàleg i assignació/correcció atòmics sense alta anticipada ni reutilització silenciosa; duplicats concurrents, XOR/defaults/gramàtica exacta i real ID final. Canvi efectiu amb nova proposta substitueix metadades, manual les posa a NULL preservant Before; no-op manual conserva fila/sense auditoria, proposta sense canvi conserva fila però audita decisió amb snapshots NULL. Claus de valor anterior real/NULL només absent, mai ID catàleg inventat. Primera alta sempre UUID i dos conjunts, absència canviada no és upsert; correcció pot retornar OperationId NULL només no-op manual. No tipus/grup/codi/principal ni ban nou de retirats per aquests circuits.
24. Provar §6.25: almenys una decisió, tres formats exactes amb originals no nuls/fonts/risc individuals, duplicitats dins dels arrays rebutjades/unió de referències compartides al context. Cinc blocs complets inclosos originals de membres exclosos manualment, sense exigir creador aprovat o agrupació acceptable per crear; lectura curta i rebuig atòmic només d'expressos. Una auditoria per decisió/UUID comú/snapshots-resultat NULL, claus anteriors reals, zero canvis de negoci/comptadors/codis i resposta única post-COMMIT. Rebuig del grup no inventa rebutjos de fills; crides individuals no comparteixen UUID automàticament.
25. Provar §6.26/§8: NewVariantTypeJson de quatre propietats, ID nou real/col·lisions/cancel·lació, A candidata sense assignacions/original disponible. B nou: context D246 i tres auditories; B existent: context cinc amb associació absent null/pendent completa/aprovada intacta i sense auditoria fictícia. A amb assignacions dins del grup, encara pendents o retirades, impedeix el corrector i conserva totes les assignacions amb rollback conegut; altres grups/catàlegs/SKU/principal/codis preservats. Dos conjunts capturats internament i emesos post-COMMIT, COMMIT efectiu/no transacció de formulari, pèrdua de resposta incerta/fallback no extrapolat. Lector §6.26.5 confirmat D294: mateixa signatura/context, no tornar-lo a sotmetre a aprovació ni ampliar-lo a A ja aprovada.
26. Provar D295–D296 §6.27: A 1/codi NULL i B 0/codi NULL amb original, IDs diferents/compatibles, mateix grup i les dues sense assignacions. Qualsevol assignació també pendent/retirada bloqueja sense eliminar-la, sense afectar usos en altres grups; B absent/null/aprovada és error, no conversió a un altre circuit. Context cinc de forma D293 però estats diferents, grups buits i membres retirats/pendents, originals imbricats, SNAPSHOT curt. A retire amb Before complet i camps de proposta de l'esdeveniment NULL; B revisió dels seus originals, sense copiar els d'A o posar risc a zero; dues auditories/UUID comú i dos conjunts complets només post-COMMIT. No catàlegs/SKU/codis/principal nous. Explicació §8.4.1 coherent amb quatre àmbits independents, reutilització del mateix valor per diversos SKU del mateix grup i principal només per tipus finals; no límit artificial o fase física nova.

Per a la identitat del grup i la línia: provar creació a partir de CLIGNE informat, herència Parkod → ProductVariant → ProductGroup amb FK SKU de tres camps, FK al grup amb línia i validació SQL protegida, rebuig de CLIGNE NULL, línies o marca/categoria diferents. Provar canvi a l'origen de L1 a L2 sobre SKU classificat: preservar còpia/classificació, registrar error, continuar, mantenir SourceIsPresent=1 i no inferir retirada; revisió tècnica amb relectura de l'origen abans de COMMIT, grup existent confirmat o nou grup propi, associacions/principal compatibles i cascada d'actualització de les rèpliques d'assignació, o rollback complet. Verificar que compartir codis no força fusió comercial; IDs locals repetits en àmbits diferents, concurrència i idempotència no poden creuar associacions ni perdre valors.

Per als textos: provar conversió Unicode White_Space (inclòs CRLF), exclusió de U+200B/U+FEFF, límits 20/80/150, blanc aïllat, preservació d'accents, idempotència, comprovació per bytes i longitud, NULL de la forma numèrica/textual i rebuig de qualsevol TextValue informat buit o de nom informat buit. Provar unicitat CI_AI i comparació exacta diferenciades, noms repetits, reutilització de valors i SKUs sense accents; cap fusió o truncament silenciós.

Per a validació/exportació: provar risc previ 0% **sense** aprovació, risc no estimable, aprovació per SKU dins d'un lot i aprovació independent de grup, tipus–grup i valor–SKU; associació de tipus aprovada abans de completar valors que no permet exportar. Provar primera aprovació, grup buit, només retirats, retirats barrejats amb actius sense valors, nou candidat pendent sense aturar l'exportació prèvia i SKU present amb CLIGNE discrepant que continua amb l'últim estat validat. Provar sortida sense validar (canvis descartats) i propostes recalculades, canvis confirmats entre l'inici i el final d'una exportació, traça de propostes acceptades/rebutjades/corregides i reversió com a nova operació. La dada empírica de 40 no ha de fer rebutjar cap grup superior.

Per a comptes/sessions/batch: provar segon login rebutjat sense expulsió, reserva opcional amb dues persones editant grups diferents o intentant editar-ne un de sol, consulta/exportació no bloquejades, caducitat per inactivitat i alliberament de reserva, paràmetre 30 minuts configurable, batch omès amb sessió activa i exit 0 + log «no executat», login rebutjat durant batch, absència de curses entre inici de batch i alta de sessió i fallada real distingida d'omissió. No retenir transaccions durant formularis ni introduir planificador intern.

Per a textos compartits i codis externs: provar matisació editorial de Type amb `ON UPDATE CASCADE` a la rèplica Type i aprovacions conservades, correcció de Characteristics/TextValue sense canvi semàntic, col·lisió CI_AI i auditoria; canvi semàntic de tipus amb nova definició, associació i codi, canvi semàntic només de valor amb nou VariantTypeValue del mateix tipus i revalidació de SKU. Provar que els programes lectors no emeten codis d'associacions aprovades sense valors complets ni canvis no validats, i que l'anterior estat validat continua disponible fins a la confirmació nova.

**Revisió documental de coherència — 2026-10-22:** acords fins a D228 contrastats amb funcional i instruccions; 14 taules/98 camps, claus i formats preservats. Fonts de la còpia de proves i equivalències documentals actualitzades, noms directes de PARKOD i país exclòs; això no demostra les metadades SQL ni equivalència física amb producció. Ubicació vigent VARIANTS_PARKOD.dbo, fonts només en lectura controlada; configuració nova aprovada, cap canvi original. Login/confiança/token, catàleg global, contextos/correccions/reversió editorial ja confirmats, no DDL/proves. Historial dels acords substituïts a DECISIONS.md, no regles operatives alternatives.

**Consolidació — 2026-10-23, D229–D236:** s'actualitza aquell estat amb els diagnòstics previs de §5.5 i les confirmacions de l'usuari: base local existent sense taules, separació 2019 de proves/2017 de producció, estructura font acceptada amb tres ajustos físics, French_CI_AS mantinguda, pauta nocturna/extraordinària i precisions A/B/principal/ValuesJson. Es conserven 14 taules/98 camps i totes les claus/regles comercials; només canvien les descripcions de longitud/nul·litat indicades al diagrama/diccionari. Resta de signatures aleshores proposada i separada dels acords, confirmada posteriorment per D237. No SQL executat en aquella tasca, model no desplegat, etapa 0 oberta.

**Consolidació — 2026-10-25, D237–D240:** signatures A → B ara aprovades íntegrament; recuperació de resultat incert manual només admin, substituint la comprovació automàtica intermèdia; entrada existent/nova SKU–valor i resposta de candidata en dos conjunts aprovades. Reversions ordinàries i seqüència de tasques Windows eren acords previs, no funcional pendent. Diagrama, 25 taules del diccionari, 14 entitats/98 camps i claus/tipus físics sense canvis respecte de D236. Contractes parcials SKU–valor no aproven noms/signatures/contextos exactes encara no definits; DDL, permisos, consultes/procediments i proves continuen pendents. Actualització només documental, sense SQL ni pas a etapa 1.

**Consolidació — 2026-10-27, D241–D247:** sis noms/signatures de candidates, lectors SNAPSHOT, respostes i condicions aprovats en conversa incorporats a §6.15; es resolen els pendents de noms/signatures d'aquests sis procediments que constaven a la consolidació anterior. JSON grup–tipus de quatre blocs confirmat; proposta SKU de set propietats separada dels acords, amb Parkod confirmat. Sense canvis a diagrama/diccionari/relacions, 14 taules/98 camps preservats. No DDL, SQL, dades/font/configuració o scripts modificats; etapa 0 oberta.

**Revisió de cobertura de la conversa — 2026-10-27:** els acords tècnics, arquitectònics i funcionals confirmats de la conversa disponible s'han contrastat amb el funcional i el registre; tots localitzats fins a D247, sense decisions noves a numerar. Matriu de traçabilitat a DECISIONS.md, apartat «Revisió de cobertura de la conversa». D223 conserva el fet històric de còpia de proves, però els seus pendents d'entorn/estructura es remeten a D229–D230 com a resolts. Es mantenen la recuperació manual D238, les sis signatures i els estats de validació dels contextos de §6.15; cap proposta pendent es promou a acord. Revisió només documental, sense canviar aquest model ni executar SQL.

**Consolidació — 2026-10-28, D248–D284:** estat posterior a aquella revisió històrica. Context SKU complet confirmat i vint signatures/contexts/entrades/respostes expressament aprovats en conversa incorporats a §6.16–6.24. D247 inclòs en revisió amb aclariment de conflicte detectat versus resultat incert; D240–D246 preservats, resposta D240 i sis signatures contrastades amb diccionari/conversa. No reaprovar principis de reversió, seqüència Windows, no-intervenció o principal ja resolts. Diagrama/diccionari/claus/14 taules/98 camps i contractes previs preservats; pendents resolts retirats de l'estat actual, altres límits i proves mantinguts. Només documentació, cap SQL ni algoritme.

**Consolidació posterior — 2026-10-28, D285–D293:** rebuig conjunt exprés i dues correccions de candidata a §6.25–6.26, quatre signatures confirmades; context A/B confirmat separat de la signatura/resposta del lector encara proposades. Aclariment SKU: correcció inadmissible amb assignacions al grup, sense pèrdua de cap assignació amb rollback conegut ni rejected fictícia; incert D238 intacte. Capítol 8 explicatiu sol·licitat, amb tokens/sessió/OperationId/COMMIT i 42 signatures inventariades amb estat (41 confirmades, 1 proposta). No noves definicions físiques ni dependències; s'han preservat els canvis documentals previs.

**Revisió de conversa i consolidació — 2026-10-29, D294–D296:** lector A/B de candidata ara confirmat expressament, més confirmador/lector de substitució de fase 2 amb A ja aprovada sense codi/assignacions i B candidata. Es manté el tall històric D293 anterior, però els seus pendents d'aprovació del lector ja no són vigents. Explicació de tres fases afegida a §8.4.1 segons petició de l'usuari; compartir VariantTypeValue entre SKU del mateix grup ja constava a §3.5 i no genera decisió nova. Inventari de 44 signatures confirmades amb arguments/defaults preservats, sense noms nous per a altres circuits pendents. No decisions arquitectòniques/físiques addicionals ni aprovació de DDL/proves.

**Consolidació posterior — 2026-10-31, D297–D330:** data d'incorporació documental, no data atribuïda a cada confirmació. S'incorporen 21 signatures noves, una funció interna amb signatura concretada, àmbit d'auditoria app_session i l'únic camp nou ProductGroup.IsActive BIT NOT NULL DEFAULT(1). Model 14/99, mateixos PK/FK/fonts/altres camps; matriu de 65 procediments a §6.34.6, inventari exacte a §8.8. Els quatre blocs editorials es conserven però lector ordinari retorna dues columnes D328; G9/R5 distingits, història immutable, desactivació per grup sense estat/UUID global nou. No es confirmen propostes descartades de DELETE, simple filtre de buits o recuperació GUI del tancament forçat. Altres circuits/signatures no coberts i tota materialització/prova resten pendents. No codi, SQL executable, dada, font, configuració, commit o push modificats/executats en aquesta tasca.

**Tall documental — 2026-11-03, D331–D367:** 11 signatures noves, 76 en total. Càrrega externa de còpia i SourceIsPresent, només lectura per l'app, correcció local de classificació, nous significats d'indicadors i GUI possible durant càrrega; conciliació sense sessions vigents/còpia coherent. Regles intermèdies substituïdes conservades en decisions, no executables. Aquell tall marcava contextos 7/6 i cobertura de Complete pendents; l'aclariment següent corregeix la primera marca, no valida la segona. Cap camp físic/PK/FK/tipus nou, cap SQL/dades/configuració/font, commit o push.

**Tall documental — 2026-11-03, D368–D370:** visibilitat de discrepància, llista a cada login/incidències i quatre àmbits de validació, correcció de valor permesa amb línia pendent (§6.41). Contextos 7/6 derivats, no decisió nova. Aquell tall deixava cobertura de Complete i altres controls oberts; D371–D373 resolen només el criteri/JSON de cobertura, no les proves o la resta de controls. 76 signatures/model 14/99 sense canvis físics o pas d'etapa.

**Actualització — 2026-11-03, D371–D373:** cada SKU de còpia dins de l'abast ha de tenir variant o incidència d'admissió individual de l'execució. CompleteReconciliation rep UnincorporatedSkuIncidentsJson NVARCHAR(MAX) obligatori sense default abans de BrandCodesJson, array exacte BrandCode/CategoryCode/ProductCode/Reason, [] si cap, no NULL. SQL comprova conjunt exacte de claus sense variant, resposta original de cinc columnes intacta. 75 altres signatures/funció/model 14/99/claus intactes. Parser/comparador/permisos/concurrència i altres contractes/proves encara pendents, no completesa demostrada només per JSON/sumes o Reason. Documentació només, sense SQL/dades/font/configuració, commit o push; etapa 0 oberta.

**Actualització — 2026-11-04, D374–D379:** criteris de tasques/retirats/finalització i avís de llista no disponible confirmats (§6.41.4–6.41.5); càrrega externa sempre completa, marques només en conciliació, substitució expressa del sentit parcial de D364 (§6.35). Capítol documental del procés extern a Parkod.md §23, sense implementar-lo. Diagrama/model14/99/tipus/PK/FK, 76 signatures/respostes/funció i contextos existents intactes; només arguments funcionals dels senyals/presència ajustats al nou abast de càrrega. Proposta de bloqueig de validació SKU–grup no confirmada, resta de contractes/SQL/DDL/integracions/permisos/proves pendents. Etapa0 oberta, contrast complet de la nova especificació, sense SQL/dades/font/configuració, commit o push.

ProcessingRun, AssignmentProposal, ValidationDecision i ChangeAudit continuen històrics no adoptats. Contractes a §3.11/§6.8/§6.10–6.40, inventari al capítol 8. Contrast documental no és prova de domini/permisos/concurrència o desplegament. Etapa 0 oberta; etapes 1–4 no implementades/validades.

Proves addicionals dels acords recents: fase 2 IsValidated=1/codi NULL sense alterar principal ni fitxers; creació de valors només després de fase 2; rebuig de candidates amb originals auditats abans d'eliminar i catàlegs preservats; finalització de fase 3 amb codi/principal atòmics. Comparar completa/parcial multimarques, absències dins/fora d'abast, duplicats idèntics/conflictius, SKU/marca inidentificables i retirades suspeses. Provar èxit de dades amb errors individuals, SMTP fallit amb sortida no zero i generació independent amb indicadors 0. No reprendre batch descoordinat després de perdre connexió.

No s'ha executat cap prova SQL de domini ni implementat cap algoritme, importador, API o GUI. Els diagnòstics previs de lectura de la conversa i les confirmacions de l'usuari descriuen l'entorn, no un desplegament del model. Cap base creada/modificada ni SQL executat en aquesta consolidació documental; dades/scripts font intactes.

## 8. Interficie  App - motor SQL

### 8.1 Objectiu, vocabulari i límit del capítol

Explicació App–SQL/tres fases/principis conservats. **D404:** model13/90/matriu §6.42/corrector §6.38/disponibilitat-coordinació §6.43–§6.44, formes revisades §6.45. Mateixos76noms/funció,29signatures sense categoria/vuit SKU–valor amb signatures intactes, inventari §8.8 alineat; no totes les formes d'E02 confirmades. Complete7args-resposta/auth intactes, E04 restant i E05 detalls-proves pendents; cap servei/carregador/exportador/SQL o avanç d'etapa.

**Signatura** vol dir nom del procediment i llista ordenada de paràmetres amb tipus/defaults, no signatura digital. **Resposta** és el conjunt o conjunts de files que el contracte retorna, no només «cap excepció». **Context revisat** és l'estat SQL que l'usuari ha vist; no és la configuració desitjada ni un snapshot d'auditoria a restaurar. **Operació atòmica** és la unitat curta de canvis i auditories que es confirma conjuntament; no tota una sessió, pantalla o execució batch.

El patró lectura → revisió → confirmació s'aplica als circuits que el defineixen. No lector nou obligatori per altes sense estat anterior o ContextJson universal: catàleg retorna CatalogJson, autenticació té lectura pròpia i batch metadades de connexió sense AppSession. Contractes canònics §6.11–6.40, amb adaptacions pendents explícites. IsActive no afegeix paràmetres ordinaris, metadata editorial és segona columna/no cinquè bloc. La càrrega de còpia és externa; cap escriptura de còpia o lectura original de CLIGNE presumpta dins d'aquest flux.

### 8.2 AppSessionId, SessionToken i OperationId: tres funcions diferents

| Element | Qui el proporciona i ús | Persistència i límits |
|---|---|---|
| AppSessionId UNIQUEIDENTIFIER | SQL el genera en CreateAppSession; l'app l'envia a les crides autenticades per identificar la sessió funcional. | PK d'AppSession, no ID de compte/connexió SQL/sessió RDS/transacció. Sol no autentica ni autoritza. Una mateixa sessió pot fer moltes operacions amb COMMIT independents. |
| SessionToken, argument VARBINARY(MAX) | L'app genera un secret criptogràfic de 32 bytes exactes, el conserva només en memòria i el presenta amb AppSessionId. | SQL valida longitud abans de convertir i comprova el token contra el hash de la sessió. No truncar/omplir ni conservar el token en clar a SQL, fitxers, logs, auditoria o contextos. |
| SessionTokenHash VARBINARY(32) | SQL conserva SHA-256 del token, no el secret original. | Camp intern d'AppSession, no una dada de resposta ni un token que el client pugui substituir per l'original. També exclòs de traces/contextos/snapshots. |
| OperationId UNIQUEIDENTIFIER | SQL el genera per l'operació atòmica que registra canvis o decisions; vincula els seus esdeveniments EvaluationAuditEvent. | NOT NULL a cada esdeveniment persistent. No és AppSessionId, reserva, ID de petició aportat pel client ni clau d'idempotència. No identifica tot un batch amb transaccions independents. |

El nom del paràmetre és **@SessionToken** en singular; no existeix una taula/columna SessionsTokens afegida per aquest capítol. El token de 32 bytes i el seu SHA-256 de 32 bytes són dades diferents encara que tinguin igual longitud.

Cada procediment autenticat comprova sessió/token/caducitat i permisos vigents; deriva l'actor d'AppSession, no d'un identificador d'autor lliure. IsAdmin és l'actual, no el del login. Reserva de grup opcional amb identitat completa, comprovada quan el circuit la requereix; no equival a una transacció SQL mantinguda oberta. Una sessió per compte, 30 minuts d'inactivitat per defecte configurables fora GUI; només interacció real renova, no heartbeat. Expiració/logout/restabliment alliberen reserva i invaliden edicions pendents segons §3.13/§6.6. Desactivar compte no expulsa per si sol; restablir contrasenya sí revoca sessió/reserva.

OperationId de resposta pot ser SQL NULL només en no-op expressos: editorials/principal/valor manual/accés de compte/abast i ValueKind/nom/validació manual de grup o pertinença, i resultats controlats sense desactivació D324. Sense fila d'auditoria amb UUID NULL. Proposta expressa sense canvi pot auditar D280. Lectures/sessió rutinària/cicle Begin-Complete-Fail no auditen ni retornen UUID; login retorna AppSessionId, ForceClose audita D302, reset només password_reset. Desactivació un UUID per grup canviat, no global; correccions efectives de línia sempre UUID informat.

### 8.3 Login abans de disposar de sessió

1. L'app crida GetAppAccountAuthenticationData amb LoginName. SQL retorna zero/una fila del compte actiu amb AppAccountId/PasswordHash, sense SELECT general a AppAccount.
2. Python comprova Argon2id en memòria. **Cap transacció SQL oberta durant aquest càlcul.** Si falla, no demana crear sessió. Hashes/tokens no es mostren a la GUI; contrasenya i altres secrets mai a logs/auditoria/contextos.
3. Si correcte, l'app genera el token criptogràfic i crida CreateAppSession amb AppAccountId, hash esperat i token. Aquesta crida encara no pot presentar AppSessionId.
4. SQL revalida atòmicament compte actiu/hash exacte, sessió única/caducades i exclusió batch, desa només hash del token i confirma l'alta. Hash esperat detecta restabliment concurrent; no demostra per si sol verificació honesta de contrasenya.
5. **Només post-COMMIT** retorna una fila AppSessionId; no token/hash retornat. L'app conserva AppSessionId + token en memòria per a les crides autenticades.

Model intern ja acceptat: connexió directa, sense servei central ni autenticació Windows automàtica; atribució/auditoria per ús ordinari, no garantia contra manipulació intencionada de l'app o credencial SQL comuna. Windows/RDS/connexió SQL no substitueixen AppAccount/AppSession. Un error de connexió al login tampoc prova rollback; no reenviar automàticament (§6.13).

### 8.4 Flux general d'una operació amb revisió humana

```text
App: seleccionar l'objecte i preparar la petició de lectura
  -> SQL: verificar sessió/àmbit i llegir un context coherent curt
  -> SQL: tancar la lectura i retornar els conjunts exactes
  -> App: conservar el context rebut separat del resultat desitjat
  -> Usuari: revisar, corregir si correspon i confirmar expressament
  -> App: enviar arguments finals + ExpectedContextJson revisat
  -> SQL: nova transacció actual, coordinació i contrast del context
  -> SQL: validar, aplicar dades + auditoria i capturar la resposta
  -> SQL: COMMIT efectiu de tota l'operació
  -> App: rebre i comprovar la resposta completa post-COMMIT
```

| Fase | App/backend | Motor SQL i resposta |
|---|---|---|
| 1. Preparació | Identifica grup/SKU/tipus reals i via concreta; no upsert entre absència/candidata/validada. | Signatura fixa què es pot demanar; codis MAX per validar 3/2 abans de convertir, JSON amb propietats exactes, sense IDs ficticis. |
| 2. Lectura | Envia sessió/token i arguments del lector concret. | Verifica controls aplicables, genera tots els blocs d'un mateix SNAPSHOT curt només a VARIANTS_PARKOD per als lectors que el tenen acordat; error sense context parcial. |
| 3. Retorn de lectura | Rep ContextJson/CatalogJson o els conjunts definits. | Transacció de lectura tancada abans de revisar. Ni reserva de codis/IDs futurs, ni auditoria ordinària de lectura. No incloure parkod original SNAPSHOT OFF. |
| 4. Revisió | Conserva l'estat SQL rebut, originals autoritatius i edicions desitjades separats. GUI en francès; cancel·lar descarta esborrany manual, no candidata automàtica persistent. | Cap transacció ni bloqueig de dades mantinguts mentre l'usuari pensa. Els controls de sessió/activitat/reserva ja acordats continuen aplicables; això no autoritza heartbeat. |
| 5. Confirmació | Envia sessió/token, IDs reals/arguments finals i context revisat del circuit. Si canvia un objecte seleccionat fora de l'abast llegit, obtenir el context corresponent. | No confiar en Before/After, autor, claus, codis o OperationId imposats pel client; SQL els deriva de l'estat verificat. Originals persistents de la candidata SQL bloquejada; no persistents del backend segons el contracte. |
| 6. Contrast actual | No sobreescriu el context antic amb una relectura oculta ni reenvia automàticament. | Nova transacció curta actual, ordre tipus → SKU → comptador si cal → grup; coordinació compartida aprovada. Comparar camps/conjunts/absències/textos exactes rellevants, no només CI_AI ni format/ordre JSON. |
| 7. Aplicació | Espera la resposta final, sense donar per bo un primer resultat parcial. | Revalidar compatibilitats, estats/assignacions/principal; normalitzar abans de validar/desar. Canvis i auditories atòmics, una entrada per fila/decisió real segons el circuit, UUID comú. |
| 8. Captura i COMMIT | No fa una consulta independent per reconstruir la resposta de confirmació. | Capturar files/conjunts dins de l'operació, confirmar tota la transacció real i només després emetre'ls. Preservar conjunts buits previstos i tipus/nulls exactes. |
| 9. Resultat | Èxit només amb resposta completa conforme; mostrar resultat capturat. Conflicte conegut exigeix revisió nova; incert segueix §8.6. | No retornar èxit d'una operació amb rollback, ni assumir que la pèrdua de resposta implica rollback després d'un possible COMMIT. |

Les lectures de revisió no congelen l'estat fins a confirmar. Un altre usuari pot haver fet canvis vàlids; la confirmació no els desfà. No hi ha taules de versions/contextos persistents o garantia de reconnexió/idempotència creada per aquest flux. Una reserva lògica ajuda a coordinar l'edició però no substitueix contrast, integritat ni atomicitat SQL.

#### 8.4.1 Les tres fases de classificació d'un ProductGroup

**Explicació dels acords existents**, demanada per l'usuari per entendre la construcció de les variants d'un grup. No són les etapes 0–4 de desenvolupament del projecte: l'etapa 0 continua oberta mentre definim aquests circuits. Les tres fases classifiquen SKU reals, no generen tres classes de ProductVariant ni una nova columna Phase.

**Punt de partida:** còpia carregada **abans i externament**, després conciliació de l'app que crea variant/grup propi/auditories a partir d'una entrada admissible, no la còpia en la mateixa transacció. Una còpia nova sense variant és entrada pendent normal. ProductVariant representa un SKU de vuit caràcters amb ID estable i un únic grup, inicialment provisional, no un grup genèric o una aprovació comercial. Crear un valor no crea un altre SKU; les decisions posteriors determinen amb qui s'agrupa, què varia i quin valor correspon a cadascun. Fases comercials diferents dels processos de càrrega/conciliació.

Amb N SKU vàlids nous acceptats en un destí inicialment buit, es creen N ProductVariant i N grups propis provisionals actius, no N classificacions comercials aprovades. No grup per fila rebutjada/duplicada ni recreació d'un SKU ja incorporat. Després es poden reagrupar; els grups buits es conserven físicament i només administració pot desactivar-los segons §6.33. IsValidated no és ocupació o activitat. IsActive=1 segueix obligatori per operativa ordinària/lectura Parkod, sense substituir les quatre validacions següents.

```text
SKU incorporats i classificació provisional
  -> FASE 1: grup comercial + pertinença individual de cada SKU
  -> FASE 2: tipus aplicables al grup, associacions aprovades sense codi
  -> FASE 3: valors per SKU, després codi grup-tipus i principal coherent
  -> Lectura Parkod només dels SKU i habilitacions elegibles
```

**Fase 1 — Construir i validar el grup comercial.** La descoberta proposa quins SKU formen un producte comercial; marca/categoria/línia compatibles són necessàries però no suficients per agrupar-los. El tècnic valida independentment configuració de ProductGroup i cada pertinença ProductVariant → ProductGroup, encara que la pantalla confirmi un lot. Les propostes no persistents no traslladen SKU abans de confirmar; una pertinença rebutjada conserva l'estat vigent. Un SKU sense agrupació convincent manté grup propi, i els grups buits es conserven.

En crear un grup nou s'aplica el creador explícit/seleccionat/aprovat, la identitat completa i la numeració per marca–categoria de §6.19. En incorporar a grup existent s'utilitza el circuit de trasllat de §6.18; no cal crear un grup nou si el correcte ja existeix. No moure tots els membres dels grups d'origen per haver-ne seleccionat alguns. **Resultat de fase 1:** grup i pertinences aprovats, encara sense garantir exportabilitat, valors o codis.

**Fase 2 — Determinar què varia dins del grup.** Seleccionar/reutilitzar VariantType compartits compatibles, globals o exclusius de la marca, i revisar cada associació ProductGroupVariantType. Una candidata persistent té risc/originals propis, IsValidated=0/codi NULL; aprovar-la posa IsValidated=1 però conserva el codi NULL. Aquesta validació és de l'associació amb aquell grup, no una aprovació global del tipus ni de tots els seus valors o usos.

| Estat de l'associació grup–tipus | IsValidated | ParkodVariantCode | Efecte |
|---|---|---|---|
| Candidata de fase 2 | 0 | NULL | Proposta persistent revisable; no habilitació final. |
| Aprovada a fase 2 | 1 | NULL | Permet preparar assignacions SKU; no compta per al principal ni la lectura Parkod. |
| Finalitzada a fase 3 | 1 | Informat | Compta com a habilitació final, sense substituir els controls per SKU. |

Aprovar fase 2 no assigna valors SKU, no reserva/dona codi i no modifica el principal. Crear/reutilitzar catàlegs segueix §6.10: els valors de catàleg poden existir prèviament, però les candidates/assignacions SKU–valor només es creen després d'aprovar l'associació. Els catàlegs no tenen IsValidated ni codi d'habilitació. Si cal substituir un tipus, és una decisió expressa, no perquè coexistir amb un tipus complementari sigui un error.

**Fase 3 — Assignar els valors dels SKU i finalitzar l'habilitació.** Per cada associació aprovada, preparar/revisar el valor concret de cada SKU mitjançant ProductVariantValue, seleccionant un VariantTypeValue existent o creant-lo en el moment autoritzat. Cada assignació té risc/originals/validació propis. Absència, candidata pendent i assignació validada tenen circuits diferents (§6.15/§6.23/§6.24), no upsert silenciós. La confirmació d'un valor individual no finalitza automàticament l'associació.

Quan els valors requerits són presents i validats, la finalització expressa de §6.17 revalida el context i, atòmicament, reserva/assigna ParkodVariantCode, manté un principal coherent i audita. Per codi **nou**, almenys un membre SourceIsPresent=1 amb pertinença IsValidated=1; tots aquests membres requerits han de tenir assignació validada del tipus. Una assignació absent/pendent requerida bloqueja; un membre de pertinença pendent no es converteix en aprovat per aquest fet. SourceIsPresent=0 exclou els retirats dels valors exigits i de l'exportació, però no n'elimina dades. Codis anteriors es conserven si el grup després queda buit o només amb retirats.

El codi identifica **l'habilitació del tipus en aquell grup**, no un SKU, valor o número de grup. És immutable/no reciclat. Principal és un VariantType final del mateix grup: zero finals exigeix NULL, un exigeix aquell ID, diversos conserven una tria vàlida o requereixen selecció expressa; no comptar SKU/valors ni triar arbitràriament. NULL amb zero finals no fa exportable el grup.

**Tres fases, quatre àmbits de validació independents:**

| Àmbit | Fila on es valida | Fase de la decisió |
|---|---|---|
| Configuració del grup | ProductGroup.IsValidated | 1 |
| Pertinença de cada SKU | ProductVariant.IsValidated | 1, decisió individual per SKU |
| Aplicabilitat del tipus al grup | ProductGroupVariantType.IsValidated | 2; només final amb codi després de 3 |
| Valor concret d'un SKU per tipus | ProductVariantValue.IsValidated | 3, decisió individual per assignació |

EstimatedRiskPercent és independent en els quatre àmbits; NULL és no estimable i 0 no valida. Aprovar una fila no valida les altres, no posa risc a zero i no transfereix aprovació del catàleg, d'un altre grup o d'un altre SKU.

**Dos SKU del mateix grup poden compartir valor.** És la reutilització ja acordada a §3.5, no una nova excepció: una única fila VariantTypeValue per aquell tipus/valor, referenciada per dues ProductVariantValue diferents. Per exemple, dos SKU del mateix grup poden tenir color «Noir» amb el mateix VariantTypeValueId; cap ID fictici o valor duplicat de catàleg per representar-los. Cadascun continua sent un ProductVariant diferent, amb risc/validació de la seva assignació independents. La PK ProductVariantId + VariantTypeId limita a un valor d'aquell tipus per SKU, **no exigeix valors diferents entre membres del grup**. Validar l'assignació d'un no valida automàticament la de l'altre.

**COMMIT, correccions i continuïtat:** les fases poden durar diverses revisions; no hi ha una transacció oberta des de l'inici de fase 1 fins al final de fase 3. Cada operació protegida té context/controls/COMMIT propis i auditories atòmiques. Els circuits conjunts autoritzats, com crear grup/associacions aprovades/trasllats preservant valors, poden combinar decisions de diverses fases en una transacció curta, però totes són explícites i no perden dades. Un rollback posterior no desfà operacions ja confirmades; resposta perduda segueix D238.

El circuit D295–D296 de §6.27 és **només fase 2**: A ja aprovada sense codi/assignacions i B candidata sense codi/assignacions, retirada expressa d'A i aprovació de B sense valors/codis/principal nous. El lector només informa; el confirmador aplica els canvis. Si A té assignacions, aquest circuit és inadmissible i s'utilitza el de substitució completa §6.11, preparant B mentre A i els seus valors continuen intactes fins a la transició explícita. No retirar aprovacions ni canviar tipus dels SKU silenciosament.

**Resultat llegible per Parkod:** primera exportació només de grup aprovat amb almenys un SKU present i pertinença aprovada, principal vàlid i valors validats de cada tipus finalment habilitat per cada SKU exportat (§6.5). No exportar grup buit/només retirats. Un SKU nou pendent no bloqueja els membres ja validats ni s'exporta abans d'estar preparat; un tipus B aprovat sense codi no substitueix una habilitació A anterior. Lectura dels programes Parkod existents, no exportador/vista nous ni escriptura a l'original. Classificació aprovada i conciliació acabada són garanties diferents.

### 8.5 Què confirma cada COMMIT

| Àmbit | Abast de la confirmació i del rollback |
|---|---|
| Una operació d'escriptura/decisió | Dades, reserves/codis/comptador quan pertoquin i totes les seves auditories, en la mateixa transacció curta. Error amb rollback conegut desfà només aquest intent. Rebuig no persistent pot confirmar només auditories, sense canvis de negoci. |
| Creació/correcció conjunta | Catàleg nou si està autoritzat en aquell circuit, associació/assignació/trasllat i auditories conjuntes. No donar per confirmada una peça abans que tota l'operació acabi. |
| Preparació confirmada prèviament | Un catàleg/B preparat en una operació anterior amb COMMIT continua existint si falla la transició posterior. No desfer COMMIT anteriors o aliens ni restaurar snapshots com a compensació automàtica. |
| Lectura de context | Final de la transacció de lectura significa acabar el punt coherent llegit, no aprovar una proposta ni reservar fins al formulari. No es reutilitza aquell SNAPSHOT per escriure. |
| Sessió/pantalla | AppSession pot sobreviure a moltes transaccions. Un COMMIT de negoci no fa logout; caducar/desconnectar RDS/tancar formulari no prova rollback d'una operació en curs. |
| Conciliació batch | Transaccions curtes per unitat, amb coordinació d'execució per connexió dedicada. Fallada posterior no desfà COMMIT previs: execució incompleta, no rollback global presumptiu. OperationId no és un únic ID de tot el batch. |
| Resposta i fitxers externs | COMMIT confirma l'operació SQL, no el lliurament de la resposta, la generació d'un fitxer o un correu SMTP. Un error extern posterior no desfà dades ja confirmades. |

La responsabilitat de confirmar/desfer l'operació és del circuit SQL protegit, no d'un botó GUI amb una transacció oberta durant tota la pantalla. **Cal COMMIT efectiu de tota la transacció d'operació**, no considerar suficient un COMMIT intern si un embolcall encara manté la transacció real oberta. Això delimita la garantia a preservar; no aprova un nou model de transaccions imbricades o ambientals. Detalls de gestió d'errors/connexió/COMMIT/ROLLBACK pendents d'implementació i prova SQL Server 2017.

En no-op expressament admès, SQL comprova igualment context i estat final; no UPDATE ni auditoria fictícia, OperationId de resposta NULL segons contracte. En una decisió nova de proposta sense canvi de fila, pot haver-hi auditoria i UUID reals D280. No confondre «cap canvi a la fila», «cap auditoria» i «cap decisió».

### 8.6 Èxit, cancel·lació, conflicte i resultat incert

| Resultat | Tractament |
|---|---|
| Èxit complet | Conjunts/columnes/files requerits rebuts post-COMMIT, inclosos conjunts buits previstos; utilitzar la captura retornada, no una relectura posterior com si fos la mateixa resposta. |
| Cancel·lació manual abans de confirmar | Descartar esborrany; no crear catàleg, eliminar candidata persistent o auditar rejected sense proposta/decisió. |
| Conflicte/condició invàlida detectats amb rollback conegut | Error tècnic, log anglès, cap canvi parcial d'aquest intent ni rejected humana fictícia. Conservar COMMIT d'altres operacions i exigir context/revisió nous. |
| Rebuig humà confirmat | Operació explícita de proposta amb original i auditoria rejected, no error tècnic. Només candidats persistents admissibles poden eliminar-se pels seus circuits; estat validat i catàlegs preservats. |
| Timeout, connexió perduda o resposta incompleta | Resultat incert encara que SQL sigui atòmic. Informar l'usuari, invalidar context antic, cap reenviament automàtic/rollback presumptiu. Recuperació manual només admin vigent segons D238/§6.16. |

OperationId conegut permet la ruta administrativa que el rep. Sense ID, el fallback grup/A/B de GetUncertainOperationContext està aprovat per la substitució definida a §6.11; **no extrapolar-lo automàticament a qualsevol operació de correcció de fase 2**. Absència d'auditoria no prova rollback ni fi de petició; estat desitjat observat no demostra autoria. Si no es pot aclarir, incidència pendent. Consulta d'investigació no modifica/desfà dades ni restringeix correccions ordinàries als administradors.

### 8.7 Exemple complet: candidata A corregida seleccionant B existent

**D292–D294 confirmats:** context D293 i nom/signatura/resposta del lector aprovats després per D294. L'exemple explica el circuit de disseny, no una implementació/prova ni el cas A ja aprovada de §6.27.

1. L'app selecciona grup complet/A/B i demana GetGroupVariantTypeProposalCorrectionContext amb sessió/token i aquests IDs.
2. El lector comprova A admissible/B existent compatible i retorna ContextJson amb els cinc blocs exactes §6.26.4, inclosa associació B null si absent. SNAPSHOT local tancat abans de revisar.
3. Backend conserva context sense edicions sobreposades; usuari revisa A/B/originals i confirma substitució expressa. Si B canvia, llegir el context del B nou, no reutilitzar el d'un altre ID.
4. Crida confirmada CorrectGroupVariantTypeProposalWithExistingType amb els mateixos identificadors i ExpectedContextJson revisat.
5. SQL en nova transacció actual revalida sessió/àmbit/context/condicions. Si qualsevol SKU del grup té assignació a A, **no és admissible**: amb rollback conegut no es modifica cap assignació d'A, dins o fora del grup, ni s'elimina A per fer passar la correcció. Log tècnic, no rejected humana.
6. Si admissible, eliminar només associació candidata A; crear B 1/codi NULL si absent, aprovar B candidata segons D179 o conservar B aprovada intacta. Catàleg A i tots els seus altres usos preservats; cap assignació SKU, codi nou o principal canviat.
7. Auditar A corrected i només el canvi real de B quan pertoqui, amb OperationId comú. B ja aprovada no rep auditoria fictícia. Originals/risc d'A a B només si es crea l'associació; B existent conserva els seus.
8. Capturar dins de l'operació dos conjunts d'una fila: OperationId informat + associació B completa; després VariantType B complet existent. Fer COMMIT efectiu i retornar-los.
9. App rep tots dos conjunts i mostra el resultat; resposta incompleta/timeout segons §8.6, sense garantir rollback ni reenviament. Amb assignacions que cal substituir, usar el circuit complet §6.11, mai aquest corrector reduït.

### 8.8 Inventari complet de signatures definides i estat de validació

**Inventari actual d'arguments, mateixos76noms del tall D379**, NormalizeWhitespace separada.29signatures sense categoria per D380/D386: quatre de destí adaptades D398+25CategoryCode en §6.45, coincidents amb els contractes. Altres47signatures intactes, però **no totes les formes de context/retorn estan revisades**. Vuit SKU–valor sí contrastats/grup3-associació5/assignació9; sessions/reserves/grups/codi5 de les famílies revisades actualitzats. E02 restant §6.45.5, no llista d'arguments pendent. D395 sense tercer corrector/D396 sense API-estat nou, autenticació/funció/Complete7args-resposta5 intactes. Signatures de disseny, no SQL executable.

**Límit de «complet»:** inclou les 11 signatures de validació sense trasllat/correcció/cicle batch confirmades en xat. No inclou lector/escriptors SKU de conciliació encara no definits, altes/propostes sense ID no cobertes o reactivació de grup. Càrrega de còpia i integritat de producció fora del projecte, no inventar-ne API d'importació. Integració/controls i formats afectats per nova frontera pendents §6.40; generador extern no esdevé exportador nou. Funció interna i totes les signatures requereixen materialització/proves.

#### 8.8.1 Autenticació i alta de sessió — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetAppAccountAuthenticationData(@LoginName NVARCHAR(MAX))` | Consulta limitada del compte actiu abans d'Argon2id; retorna AppAccountId/PasswordHash només per ús en memòria (§6.13.2). |
| `dbo.CreateAppSession(@AppAccountId INT, @ExpectedPasswordHash NVARCHAR(MAX), @SessionToken VARBINARY(MAX))` | Revalida autenticació/compte/sessió única/exclusió batch, desa hash del token i retorna AppSessionId post-COMMIT (§6.13.3). |

#### 8.8.2 Catàleg global i correccions editorials — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.CreateGlobalVariantTypeWithValues(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @Type NVARCHAR(MAX), @Characteristics NVARCHAR(MAX), @ValueKind NVARCHAR(MAX), @ValuesJson NVARCHAR(MAX))` | Crea tipus global i valors inicials, també tipus buit, amb auditories atòmiques; sense associacions/SKU/codis (§6.14.3). |
| `dbo.GetVariantTypeCatalog(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT)` | Llegeix tipus i tots els valors en CatalogJson de dos blocs, sense Usages (§6.14.4). |
| `dbo.AddGlobalVariantTypeValues(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedCatalogJson NVARCHAR(MAX), @ValuesJson NVARCHAR(MAX))` | Afegeix lot no buit de valors nous a tipus encara global contra catàleg revisat; no reemplaça els existents (§6.14.5). |
| `dbo.GetVariantTypeValueEditorialContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeValueId INT)` | Context de tres blocs del valor textual i els seus usos per preparar correcció editorial (§6.14.6). |
| `dbo.GetVariantTypeEditorialContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT)` | D328: una fila amb ContextJson de quatre blocs complets i InactiveProductGroupsJson de presentació, mateix SNAPSHOT; no retallar controls històrics (§6.14.6). |
| `dbo.CorrectVariantTypeValueText(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeValueId INT, @ExpectedContextJson NVARCHAR(MAX), @TextValue NVARCHAR(MAX), @ConfirmsUnchangedMeaning BIT)` | Corregeix només TextValue amb confirmació expressa de significat inalterat, auditoria o no-op exacte (§6.14.7). |
| `dbo.CorrectVariantTypeText(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @Type NVARCHAR(MAX), @Characteristics NVARCHAR(MAX), @ConfirmsUnchangedMeaning BIT)` | Corregeix Type/Characteristics sense canvi semàntic, incloses rèpliques Type realment modificades, amb auditoria atòmica (§6.14.8). |

#### 8.8.3 Candidates persistents SKU–valor i grup–tipus — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetVariantValueProposalContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @SelectedVariantTypeValueId INT = NULL)` | Llegeix candidata SKU–valor i valor original/seleccionat opcional; set propietats, no alta de valor durant lectura (§6.15.2–6.15.3). |
| `dbo.ConfirmVariantValueProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @SelectedVariantTypeValueId INT = NULL, @NewValueJson NVARCHAR(MAX) = NULL)` | Accepta/corregeix candidata amb via existent/nova XOR; possible alta de valor i dos conjunts post-COMMIT (§6.15.1). |
| `dbo.RejectVariantValueProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | Rebutja candidata pendent amb una auditoria i DELETE només de l'assignació admissible (§6.15.4). |
| `dbo.GetGroupVariantTypeProposalContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeId INT)` | Quatre blocs actuals, grup7/associació8/membres amb categoria i línia pròpies (§6.15.6). |
| `dbo.ApproveGroupVariantTypeProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | Aprova candidata tal com proposada, IsValidated=1/codi NULL; OperationId+associació8, sense fase3 (§6.15.5). |
| `dbo.RejectGroupVariantTypeProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | Només candidata0/codiNULL/sense assignacions/original, audit+DELETE atòmics; resposta OperationId (§6.15.7). |

#### 8.8.4 Substitució completa i investigació de resultat incert — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetGroupVariantTypeReplacementContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT)` | Set blocs de substitució completa, grup7/associacions8/assignacions9, IDs reals i B preparada (§6.11.2–6.11.4). |
| `dbo.ConfirmGroupVariantTypeReplacement(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @AssignmentDecisionsJson NVARCHAR(MAX), @SelectedPrimaryVariantTypeId INT = NULL)` | D404 línia coneguda permesa amb retirades/rebutjos expressos; D392 abans de codi nou, resposta codi5/principal/OperationId (§6.11). |
| `dbo.GetUncertainOperationContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @OperationId UNIQUEIDENTIFIER = NULL, @BrandCode NVARCHAR(MAX) = NULL, @ProductGroupId INT = NULL, @VariantTypeIdToReplace INT = NULL, @ReplacementVariantTypeId INT = NULL)` | Admin manual/XOR ID o quatre arguments marca–grup–A–B, dos conjunts/auditoria literal/estat actual per PK real (§6.16). |

#### 8.8.5 Finalització individual de fase 3 — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetGroupVariantTypeFinalizationContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeId INT)` | Sis blocs actuals d'associació1/codiNULL i assignacions requerides9 o null explícit (§6.17). |
| `dbo.FinalizeGroupVariantType(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @SelectedPrimaryVariantTypeId INT = NULL)` | Mínim un requerit present/pertinença1/valor1/línia resolta; codi5/principal/auditories atòmics (§6.17). |

#### 8.8.6 Trasllat ordinari a grup existent — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetGroupMembershipMoveContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @DestinationBrandCode NVARCHAR(MAX), @DestinationProductGroupId INT)` | D380 sense categoria de destí, mateixos set blocs actuals/grup7/assignació9; no correcció de línia (§6.18.1–6.18.2). |
| `dbo.ConfirmGroupMembershipMove(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @DestinationBrandCode NVARCHAR(MAX), @DestinationProductGroupId INT, @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX) = NULL, @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | D380/D390: marca comuna i línia resolta del SKU aprovat; assignacions preservades/dos conjunts/D396 disponibilitat (§6.18.3–6.18.4). |

#### 8.8.7 Creació conjunta de grup — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetProductGroupCreationContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @CreatorProductVariantId BIGINT, @ProductVariantIdsJson NVARCHAR(MAX), @VariantTypeIdsJson NVARCHAR(MAX))` | Llegeix cinc blocs de creació amb creador explícit, seleccionats i grups actuals, sense ID futur reservat (§6.19). |
| `dbo.ConfirmProductGroupCreation(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @CreatorProductVariantId BIGINT, @ExpectedContextJson NVARCHAR(MAX), @MembershipDecisionsJson NVARCHAR(MAX), @GroupVariantTypeDecisionsJson NVARCHAR(MAX), @ProductGroupName NVARCHAR(MAX) = NULL, @OriginalProposalJson NVARCHAR(MAX) = NULL, @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Crea grup/associacions aprovades i trasllada només SKU aprovats amb decisions individuals, creador aprovat i quatre conjunts post-COMMIT (§6.19). |

#### 8.8.8 Rebutjos individuals de propostes no persistents — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.RejectProductGroupProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX), @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Audita només el rebuig del grup no creat, sense rebutjos implícits de membres/tipus (§6.20.1). |
| `dbo.RejectNewGroupVariantTypeProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX), @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Rebutja associació proposada amb grup nou, no el tipus de catàleg (§6.20.2). |
| `dbo.RejectNewGroupMembershipProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX), @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Rebutja pertinença proposada a grup nou preservant la classificació vigent (§6.20.3). |
| `dbo.RejectGroupMembershipMoveProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX), @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Rebutja proposta de trasllat a destí existent original, sense moure SKU ni desfer operacions (§6.20.4). |

#### 8.8.9 Alta manual de tipus a grup existent — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetGroupVariantTypeAdditionsContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdsJson NVARCHAR(MAX))` | Quatre blocs grup7/membres/associacions8/tipus seleccionats, no buit/compatibles/encara no associats (§6.21.2). |
| `dbo.AddGroupVariantTypes(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdsJson NVARCHAR(MAX), @ExpectedContextJson NVARCHAR(MAX))` | Tot o res/1-codi-risc-originalsNULL; OperationId i associacions8 creades en dos conjunts (§6.21). |

#### 8.8.10 Principal del grup — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetProductGroupPrimaryVariantTypeContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT)` | Tres blocs grup7/associacions8/tipus, principal absent/invàlid revisable, sense SKU/valors (§6.22.1). |
| `dbo.SetProductGroupPrimaryVariantType(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @PrimaryVariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | Només principal, ID obligatori/NULL només zero finals; OperationId nullable+grup7 post-COMMIT (§6.22.2). |

#### 8.8.11 Assignació validada o primera assignació manual — confirmades

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetVariantValueCorrectionContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @SelectedVariantTypeValueId INT = NULL)` | Llegeix assignació validada i valor actual/seleccionat; error absent/pendent (§6.23.1). |
| `dbo.ConfirmVariantValueCorrection(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @SelectedVariantTypeValueId INT = NULL, @NewValueJson NVARCHAR(MAX) = NULL, @OriginalProposalJson NVARCHAR(MAX) = NULL, @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Corregeix validada amb valor existent/nou XOR, risc/originals segons decisió; distingeix no-op manual/proposta sense canvi (§6.23). |
| `dbo.RejectVariantValueCorrectionProposal(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @OriginalProposalJson NVARCHAR(MAX), @OriginalSourcesJson NVARCHAR(MAX) = NULL, @OriginalEstimatedRiskPercent DECIMAL(5,2) = NULL)` | Audita rebuig de proposta nova sobre validada deixant fila/risc/originals/catàleg intactes (§6.23.5). |
| `dbo.GetNewVariantValueAssignmentContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @SelectedVariantTypeValueId INT = NULL)` | Llegeix absència revisada d'assignació amb JSON null explícit i seleccionat opcional (§6.24.1). |
| `dbo.ConfirmNewVariantValueAssignment(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @SelectedVariantTypeValueId INT = NULL, @NewValueJson NVARCHAR(MAX) = NULL)` | Primera alta manual encara absent, valor existent/nou XOR, assignació validada/risc/originals NULL i dos conjunts; no upsert (§6.24.2). |

#### 8.8.12 Rebuig conjunt del grup nou i propostes seleccionades — confirmades D285–D289

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetProductGroupCreationRejectionContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @MembershipRejectionsJson NVARCHAR(MAX), @GroupVariantTypeRejectionsJson NVARCHAR(MAX), @GroupRejectionJson NVARCHAR(MAX) = NULL)` | Llegeix cinc blocs amb unió dels SKU originals dels rebutjos seleccionats, sense creador aprovat (§6.25). |
| `dbo.RejectProductGroupCreationProposals(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ExpectedContextJson NVARCHAR(MAX), @MembershipRejectionsJson NVARCHAR(MAX), @GroupVariantTypeRejectionsJson NVARCHAR(MAX), @GroupRejectionJson NVARCHAR(MAX) = NULL)` | Confirma només rebutjos expressos, almenys un, amb originals/risc individuals i auditories atòmiques/UUID comú; sense canvis de negoci (§6.25). |

#### 8.8.13 Correcció de candidata A amb tipus B nou/existent — confirmades D290–D293

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.CorrectGroupVariantTypeProposalWithNewType(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ExpectedContextJson NVARCHAR(MAX), @NewVariantTypeJson NVARCHAR(MAX))` | Quatre blocs D246 adaptats, B nou payload4; dos conjunts associació8/tipus5 (§6.26.2). |
| `dbo.CorrectGroupVariantTypeProposalWithExistingType(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | A candidata sense assignacions, B existent absent/candidata/aprovada segons D177–D179; cinc blocs actuals (§6.26.3–6.26.4). |

#### 8.8.14 Lector de correcció d'A candidata amb B existent — confirmat D294

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetGroupVariantTypeProposalCorrectionContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT)` | Cinc blocs A/B actuals, A candidata admissible/B associació absent null/pendent/aprovada; D294 confirmat (§6.26.5). |

#### 8.8.15 Substitució d'A aprovada de fase 2 per B candidata — confirmades D295–D296

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.ConfirmGroupVariantTypePhase2Replacement(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX))` | Cas estricte A1/NULL→B0/NULL/sense assignacions d'A-B/D398; dos conjunts associació8/tipus5 (§6.27). |
| `dbo.GetGroupVariantTypePhase2ReplacementContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @VariantTypeIdToReplace INT, @ReplacementVariantTypeId INT)` | Cinc blocs actuals/A aprovada/B candidata obligatòria amb originals, sense assignacions d'A-B (§6.27.2–6.27.3). |

#### 8.8.16 Sessions, reserves i tancament administratiu — D297–D306

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.CloseAppSession(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX))` | Tanca només sessió vigent autenticada/allibera reserva, una fila AppSessionId post-COMMIT, sense auditoria/OperationId (§6.28.2). |
| `dbo.RenewAppSession(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX))` | Interacció real, actualitza només activitat UTC; AppSessionId/LastActivityAtUtc post-COMMIT, cap renaixement/heartbeat (§6.28.3). |
| `dbo.ReserveProductGroup(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT)` | Grup existent actiu/marca–ID, reserva opcional exclusiva sense canvi silenciós; resposta segura4 (§6.28.4). |
| `dbo.ReleaseProductGroup(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT)` | Coincident allibera/absent admès/altra reserva error, activitat de grup no exigida; resposta4/reserva2NULL (§6.28.5). |
| `dbo.GetAppSessionForcedClosureContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @TargetAppSessionId UNIQUEIDENTIFIER)` | Admin vigent/revisió d'altra sessió vigent, ContextJson amb AppAccount/AppSession sense hashes, SNAPSHOT curt (§6.28.6). |
| `dbo.ForceCloseAppSession(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @TargetAppSessionId UNIQUEIDENTIFIER, @ExpectedContextJson NVARCHAR(MAX))` | Tancament administratiu/context actual/auditoria app_session atòmics; OperationId/AppSessionId afectada post-COMMIT, incidents D305 fora GUI (§6.28.7–6.28.9). |
| `dbo.GetAppSessionsForForcedClosure(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX))` | Llista altres sessions vigents en vuit camps sense secrets, no tanca ni renova observats (§6.28.8). |

#### 8.8.17 Comptes i vies SQL administratives — D307–D313

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetAppAccounts(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX))` | Admin, tots els comptes actius/inactius en quatre camps auditables; SNAPSHOT curt sense hash/sessió (§6.29.1). |
| `dbo.CreateAppAccount(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @LoginName NVARCHAR(MAX), @PasswordHash NVARCHAR(MAX), @IsActive BIT, @IsAdmin BIT)` | Alta ordinària/admin, indicadors explícits, Argon2id extern i auditoria create; OperationId+quatre camps post-COMMIT (§6.29.2). |
| `dbo.SetAppAccountAccess(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @TargetAppAccountId INT, @ExpectedContextJson NVARCHAR(MAX), @IsActive BIT, @IsAdmin BIT)` | Només activació/permisos, context de fila D307, protecció d'últim admin/autoedició; no-op OperationId NULL (§6.29.3). |
| `dbo.ResetAppAccountPassword(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @TargetAppAccountId INT, @ExpectedContextJson NVARCHAR(MAX), @NewPasswordHash NVARCHAR(MAX))` | Admin també propi, context quatre camps, hash+revocació+password_reset atòmics; dos camps resposta/últim reset admissible vigent (§6.29.4). |
| `dbo.BootstrapAppAccount(@LoginName NVARCHAR(MAX), @PasswordHash NVARCHAR(MAX))` | Només SQL admin fora GUI/AppAccount buit, primer compte 1/1, auditoria process/bootstrap, sense sessió automàtica (§6.29.5). |
| `dbo.RecoverAppAdministratorPassword(@TargetAppAccountId INT, @NewPasswordHash NVARCHAR(MAX))` | Només SQL admin fora GUI/admin existent, reset/revocació auditats process/admin_recovery, flags intactes (§6.29.6). |

#### 8.8.18 BrandCode i ValueKind — D314–D317

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetVariantTypeBrandScopeChangeContext(@VariantTypeId INT)` | Lector SQL administratiu de quatre blocs complets, només ContextJson, sense metadata GUI (§6.30.1). |
| `dbo.ChangeVariantTypeBrandScope(@VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @NewBrandCode NVARCHAR(MAX))` | Excepcional SQL admin amb assignacions, marca NULL global explícita, compatibilitat històrica/impacte/autorització/auditoria, no-op autoritzat (§6.30.2). |
| `dbo.SetUnassignedVariantTypeBrandScope(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @NewBrandCode NVARCHAR(MAX))` | Ordinari sense assignacions, context editorial quatre blocs, totes les associacions compatibles, no salt a excepcional (§6.30.3). |
| `dbo.SetVariantTypeValueKind(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @VariantTypeId INT, @ExpectedContextJson NVARCHAR(MAX), @NewValueKind NVARCHAR(MAX))` | Canvi només sense valors ni associació aprovada, també inactiva; coincidència vàlida no-op amb usos, sense excepció D142 (§6.30.4). |

#### 8.8.19 Nom descriptiu del grup — D319–D320

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.SetProductGroupName(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @ExpectedContextJson NVARCHAR(MAX), @ProductGroupName NVARCHAR(MAX))` | Grup actiu/context només ProductGroup7 de D276, NULL sense nom/no regeneració; OperationId nullable+grup7 (§6.32). |

#### 8.8.20 Desactivació de grups buits — D321–D325

| Signatura completa | Funció breu i contracte |
|---|---|
| `dbo.GetEmptyProductGroupDeactivationCandidates(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX) = NULL)` | Admin/marca o totalitat, grup7+HasActiveReservation calculat/ordre marca–ID; sense reserva (§6.33.2). |
| `dbo.DeactivateEmptyProductGroup(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @ExpectedContextJson NVARCHAR(MAX))` | Admin/grup7/zeroSKU/cap reserva vigent, resposta4/cinc ResultCode ordre D330/audit només canvi (§6.33.3). |
| `dbo.GetInactiveProductGroups(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX) = NULL)` | Admin/històric/grup7 IsActive0, marca o totalitat/ordre marca–ID, no reactivació (§6.33.4). |

#### 8.8.21 Validació de grup existent — D331–D334

| Signatura completa | Funció breu i estat |
|---|---|
| `dbo.GetProductGroupValidationContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT)` | Quatre blocs grup7/membres/associacions8/tipus referenciats, grup actiu també buit (§6.36.1). |
| `dbo.ConfirmProductGroupValidation(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @BrandCode NVARCHAR(MAX), @ProductGroupId INT, @ExpectedContextJson NVARCHAR(MAX))` | Només IsValidated/risc conservat/sense aprovació de fills; OperationId nullable+grup7 post-COMMIT (§6.36.2). |

#### 8.8.22 Validació de pertinença sense trasllat — D335–D337

| Signatura completa | Funció breu i estat |
|---|---|
| `dbo.GetGroupMembershipValidationContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT)` | Grup derivat actiu, context cinc blocs amb SKU complet i quatre blocs D332; grup provisional/retirat admès (§6.37.1). |
| `dbo.ConfirmGroupMembershipValidation(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @ExpectedContextJson NVARCHAR(MAX))` | Només flag de pertinença/risc conservat, UUID nullable+SKU complet, no correcció LineCode (§6.37.2). |

#### 8.8.23 Correcció de línia amb grup existent, també actual — D338–D344/D363/D395

| Signatura completa | Funció breu i estat |
|---|---|
| `dbo.GetVariantLineCorrectionToExistingGroupContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @DestinationBrandCode NVARCHAR(MAX), @DestinationProductGroupId INT)` | D380/D395: sense categoria de destí; set blocs amb origen/destí complets també coincidents, no SourceParkod original (§6.38.2). |
| `dbo.ConfirmVariantLineCorrectionToExistingGroup(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @DestinationBrandCode NVARCHAR(MAX), @DestinationProductGroupId INT, @ExpectedContextJson NVARCHAR(MAX))` | Mateix grup/risc conservat/assignacions intactes o trasllat/risc nouNULL; canvi efectiu de línia/no no-op, tres conjunts i audit només de files canviades. Còpia llegida, disponibilitat D396/proves pendents (§6.38.3). |

#### 8.8.24 Correcció de línia amb grup propi nou — D345–D347/D363

| Signatura completa | Funció breu i estat |
|---|---|
| `dbo.GetVariantLineCorrectionToNewGroupContext(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT)` | SKU explícit creador, sis blocs locals derivats de D346/D363, sense SourceParkod original o destí futur; no nova aprovació pendent (§6.38.4). |
| `dbo.ConfirmVariantLineCorrectionToNewGroup(@AppSessionId UNIQUEIDENTIFIER, @SessionToken VARBINARY(MAX), @ProductVariantId BIGINT, @ExpectedContextJson NVARCHAR(MAX), @ApprovedVariantTypeIdsJson NVARCHAR(MAX), @ProductGroupName NVARCHAR(MAX) = NULL)` | Únic SKU, grup nou 1/1/risc NULL, associacions necessàries aprovades sense codi/principal NULL; nom manual/auto, cinc conjunts confirmats; còpia només llegida (§6.38.5). |

#### 8.8.25 Cicle de conciliació — D353–D359, frontera D361–D367

| Signatura completa | Funció breu i estat |
|---|---|
| `dbo.BeginReconciliation(@InvocationKind NVARCHAR(MAX), @BrandCodesJson NVARCHAR(MAX) = NULL)` | Coordinació/sessions/disponibilitat de còpia, started o tres not_run, SESSION_CONTEXT petit, sense audit/RunId (§6.39.2). |
| `dbo.CompleteReconciliation(@ReadCount BIGINT, @InsertedCount BIGINT, @UpdatedCount BIGINT, @UnchangedCount BIGINT, @RejectedOrPendingCount BIGINT, @UnincorporatedSkuIncidentsJson NVARCHAR(MAX), @BrandCodesJson NVARCHAR(MAX) = NULL)` | D371–D373: set paràmetres, JSON d'incidències exacte per SKU de l'abast sense variant; SQL compara claus/estructura, no prova tota la lectura o la causa real. Resposta completed+quatre recomptes intacta, captura interna/post-COMMIT (§6.39.4/§6.39.6–6.39.7). |
| `dbo.FailReconciliation()` | Tancament d'execució incompleta de la mateixa connexió, failed d'una columna/no undo/audit/UUID; error SQL no és failed fictici (§6.39.5). |
