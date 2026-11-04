# Parkod – Project Context

> Actualització funcional: 2026-11-04, acords fins a D379. Nou capítol §23 «Procés de carrega de VARIANTS_PARKOD.parkod»: càrrega externa sempre completa, recuperació global després de fallada, marques només en conciliació. §22.54 concreta tasques de valors absents/finalització, retirats i avís de llista no disponible. D373/cobertura, D369 i contextos 7/6 intactes. Mateixos 76 procediments/signatures/respostes, NormalizeWhitespace separada i model 14/99/tipus/PK/FK sense canvis. SQL Server 2017 Express/Windows Server 2019, etapa 0 oberta. [Decisions](DECISIONS.md), [model](DATA_MODEL.md) §6.35/§6.41; només documentació, cap SQL/codi/dada/font/configuració o prova de domini.

## 1. Objectiu del projecte

Parkod és un sistema d’identificació i classificació de productes orientat principalment als sectors de:

- perfumeria
- cosmètica
- parafarmàcia

L’objectiu del nou desenvolupament és evolucionar Parkod perquè pugui representar correctament els productes tal com són necessaris actualment en entorns eCommerce, ERP, PIM i POS.

La necessitat principal és passar d’un model centrat essencialment en una referència Parkod individual a un model capaç d’identificar:

**Producte / família de producte → Variant o declinació → EAN(s)**

El sistema ha de continuar sent compatible amb la base Parkod històrica.

Gestionnaire de Variantes afegeix classificació amb totes les escriptures pròpies a **VARIANTS_PARKOD.dbo**, base separada de producció. Un procés **extern** carrega els vuit camps acordats de `parkod.dbo.PARKOD` a la còpia local i manté SourceIsPresent; l'app no desenvolupa el carregador ni escriu aquella taula. No es pressuposen CSV, base intermèdia o recàrrega prèvia de producció. Consultes auxiliars de NOM_MARQUE/NOM_LIGNE, CATEGORY, FAMILY i EAN ja autoritzades preservades (§5 del model), sense copiar mestres/denominacions o afegir fallback BRAND/LINE. **Cap actuació a parkod**, fora de lectures controlades/autoritzades; original i gestió EAN intactes.

---

## 2. Codificació Parkod existent

Parkod disposa d’una codificació pròpia històrica.

El codi Parkod s’ha de conservar i no s’ha de redefinir com a conseqüència del nou model de declinacions.

La codificació actual està basada principalment en:

1. Marca
2. Categoria
3. Producte

La clau completa és `CMARQ + CCATEG + CPROD`, de 3 + 2 + 3 caràcters exactes, respectivament. El resultat té vuit caràcters de `A–Z` i `0–9`, conservant els zeros inicials. Identifica un SKU: un Parkod diferent implica una variant diferent, però no necessàriament un grup comercial diferent.

Les equivalències acordades per a les fonts de proves són `IDParkod = BrandCode + CategoryCode + ProductCode = CMARQ + CCATEG + CPROD` i `IDLine = IDBrand + LineCode = BrandCode + LineCode = CMARQ + CLIGNE`. Concatenació textual sense separadors ni conversió numèrica: SKU 3+2+3=8; marca–línia informada 3+2=5. IDParkod no és ProductVariantId; IDLine no és el codi local LineCode. Cap camp intern nou ni reanomenament.

La regla de l'entorn Parkod prohibeix també O en CMARQ, CCATEG, CPROD i CLIGNE. L'app no hi afegeix una comprovació específica d'O ni modifica els codis originals; manté el validador exacte general del SKU. El nou ParkodVariantCode sí es genera i valida amb l'alfabet ASCII sense O.

En diferents implementacions també existeix el concepte de línia de marca.

La codificació Parkod continua sent un identificador extern proporcionat pel servidor Parkod.

Els sistemes clients, com Odoo, han de recuperar aquesta informació mitjançant API i no generar arbitràriament codis Parkod incompatibles amb la base central.

---

## 3. Problema actual

Actualment els productes es poden agrupar principalment mitjançant:

- Marca
- Categoria
- Línia de marca

Aquesta informació no és suficient per determinar amb precisió quins registres són declinacions d’un mateix producte.

Exemple conceptual:

```text
Dior Sauvage
    Eau de Toilette 30 ml
    Eau de Toilette 60 ml
    Eau de Toilette 100 ml
```

Els tres registres poden tenir:

- Parkod diferent
- EAN diferent
- contingut diferent

però conceptualment pertanyen a un mateix producte comercial.

Aquest nivell d’agrupació és necessari per alimentar correctament sistemes eCommerce.

---

## 4. Nou model conceptual

El model separa el grup comercial, el SKU/variant i les seves característiques i valors. Els EAN són identificadors del sistema existent, consultables però no gestionats en taules noves per aquesta aplicació.

### PRODUCT_GROUP

Representa el producte comercial comú.

Exemples:

```text
Dior Sauvage Eau de Toilette
Lancôme L'Absolu Rouge
L'Oréal Revitalift Filler
```

No representa una unitat concreta venuda.

Es conserven els noms `ProductGroup` i `ProductGroupId`. Cada grup té un nom no necessàriament únic i la PK `(BrandCode, CategoryCode, ProductGroupId)`. ProductGroupId és INT positiu, NOT NULL, generat automàticament des d'1 per marca–categoria; es pot repetir fora d'aquesta parella, no es reinicia per línia. Totes les variants comparteixen marca, categoria i LineCode informat. A la còpia de proves, les denominacions de marca/línia es consulten directament a `PARKOD.NOM_MARQUE`/`PARKOD.NOM_LIGNE`, tant per a la visualització com per al **nom inicial del grup**, sense afegir-les a la còpia interna.

Quan un SKU no troba el grup comercial al qual pertany, crea un grup propi que hereta el seu BrandCode, CategoryCode i LineCode; no existeix un grup genèric compartit. Compartir aquests codis no és suficient per decidir una agrupació comercial. Es pot canviar posteriorment de grup sense canviar el codi de variant, respectant la compatibilitat i les assignacions. Els grups que quedin buits es conserven per traçabilitat.

ProductGroup incorpora **IsActive BIT NOT NULL DEFAULT(1)**, independent de la validació. Els nous grups, també els propis provisionals, neixen actius. Un administrador pot desactivar expressament grups amb **zero ProductVariant assignades**, incloses retirades/pendents, i cap reserva vigent, per marca/marca–categoria/totalitat. La fila no s'elimina: desapareix de l'operativa ordinària i conserva estat, associacions, codis i història. No es reactiva automàticament ni es reciclen IDs/codis (§22.43–22.44).

Cada grup incorpora `PrimaryVariantTypeId`, el tipus de variant principal comú per a qualsevol ús. La seva obligatorietat depèn dels VariantType habilitats al grup, no del nombre de SKU: cap tipus implica NULL; un tipus implica aquell mateix ID; amb més d'un el personal tècnic n'ha de seleccionar un. Les regles completes consten a la secció 22.7.

---

### VARIANT

Representa una declinació comercial concreta del producte.

Exemples:

```text
30 ml
60 ml
100 ml
Rouge 132
Rouge 274
Recharge 50 ml
```

Una variant ha de pertànyer a un únic PRODUCT_GROUP.

Cada SKU té una única `ProductVariant`, fins i tot si encara no té característiques assignades. La relació funcional Parkod–variant és bijectiva per als registres vàlids incorporats. No cal `ParkodVariantLink`.

ProductVariant incorpora `LineCode NVARCHAR(2) NOT NULL`: línia de classificació, inicialitzada de CLIGNE local i conservada davant de canvis d'entrada fins a correcció tècnica expressa. Sempre coherent amb la línia del grup, no necessàriament amb la CLIGNE actual de còpia. ProductCode és CPROD, no ProductGroupId; codis amb sufix Code, no Id.

El codi propi de variant és un `BIGINT IDENTITY(1,1)` amb clau primària, independent del Parkod. SQL Server el genera amb seguretat per a múltiples usuaris. Es permeten salts, però no reciclatge d'identificadors en l'operativa normal ni generació amb `MAX + 1`.

Les característiques s'expressen mitjançant `VariantType`, `VariantTypeValue`, `ProductGroupVariantType` i `ProductVariantValue`. Les regles detallades consten a la secció 22 i al [diccionari de dades](DATA_MODEL.md).

---

### EAN — sistema existent, només consulta

Cada variant pot tenir un o diversos codis EAN/GTIN.

Relació prevista:

La relació següent és conceptual: els EAN romanen a les taules originals, no en una taula nova `Gtin` o `VariantGtin`.

```text
PRODUCT_GROUP
    |
    +-- VARIANT
          |
          +-- EAN
          +-- EAN
          +-- EAN
```

És important no confondre:

```text
EAN diferent
```

amb:

```text
Variant diferent
```

Un canvi d’EAN pot ser conseqüència de:

- canvi d’embalatge
- canvi logístic
- nova generació de packaging
- substitució d’un EAN anterior
- canvi comercial sense modificació real del producte

Per tant, diversos EAN poden identificar la mateixa variant.

---

## 5. Duplicats EAN

Les regles d'aquesta secció descriuen el sistema Parkod i les seves integracions existents. Gestionnaire de Variantes només consulta EAN (`IDParkod`, `EANNum` a la còpia de proves; equivalència històrica GENCOD) per ajudar a identificar variants; no registra ni corregeix EAN, no copia aquesta font i no determina la vigència dels seus codis.

Parkod ha de controlar que un mateix EAN no quedi assignat incorrectament a diversos productes independents.

En les integracions via API existeix una regla específica:

Si el servidor Parkod retorna el mateix Parkod amb un EAN diferent, aquest EAN no s’ha de perdre.

S’ha de registrar en una estructura de codis alternatius o duplicats associada al producte.

Aquesta funcionalitat ha de quedar encapsulada dins del domini Parkod i no dispersa pels diferents connectors.

---

## 6. Informació útil per detectar declinacions

La identificació de PRODUCT_GROUP i VARIANT no s’hauria de basar en un únic camp.

Poden utilitzar-se conjuntament diferents senyals:

- marca
- categoria
- línia de marca
- denominació del producte
- DESIGN1
- DESIGN2
- contingut
- unitat
- volum
- pes
- color
- tonalitat
- format
- tipus de producte
- recharge/refill
- EAN
- informació externa

La denominació comercial és especialment important perquè conté informació semàntica.

---

## 7. Fonts externes d’enriquiment

Quan la base Parkod no disposi d’informació suficient, es podrà enriquir un EAN mitjançant fonts externes.

Fonts previstes:

### GS1 / CodeOnline

Font prioritària quan existeixi informació disponible.

Pot aportar:

- denominació
- marca
- GTIN
- dimensions
- dades logístiques
- classificacions
- informació proporcionada pel fabricant

La cobertura no és necessàriament completa per a totes les referències.

---

### Equadis

Pot ser una font especialment interessant per dades de producte i logística del sector.

Caldrà estudiar la disponibilitat d’API i les condicions d’accés.

---

### Fabricant / marca

Les webs oficials de les marques poden ser especialment valuoses per:

- identificar la família comercial
- detectar variants
- identificar formats
- colors o tonalitats
- contingut
- nomenclatura oficial

---

### eCommerce i marketplaces

Poden utilitzar-se com a font complementària per entity resolution.

No s’han de considerar automàticament fonts mestres.

---

## 8. Ús de la IA

La IA pot ajudar principalment en dues tasques diferents.

### Entity resolution

Determinar si dos registres corresponen:

- al mateix PRODUCT_GROUP
- a variants diferents del mateix producte
- al mateix SKU Parkod amb EAN diferents
- a productes independents

---

### Extracció d’atributs

Interpretar textos com:

```text
SAUVAGE EDT VAPO 100ML
SAUVAGE EAU TOILETTE SPRAY 60 ML
ABSOLU ROUGE CREAM 132
```

i convertir-los en informació estructurada:

```text
product_name
product_type
variant_type
volume
unit
color
shade
format
```

Aquestes dues operacions s’han de mantenir conceptualment separades.

L'extracció d'atributs ha de respectar les unitats comercials del fabricant. No convertirà unitats ni unificarà variants expressades en unitats diferents. Dos Parkod diferents no es fusionen en una mateixa variant; només poden agrupar-se sota un mateix producte comercial.

---

## 9. Risc orientatiu i validació

S'estima el risc abans de decidir en quatre àmbits: ProductGroup, pertinença SKU→grup a ProductVariant, associació grup→tipus i assignació SKU→valor. Cadascun té EstimatedRiskPercent DECIMAL(5,2) NULL (0–100) i IsValidated BIT NOT NULL DEFAULT(0). NULL és no estimable; 0% no valida. Catàlegs VariantType/VariantTypeValue no hereten aprovacions. El risc original queda a l'auditoria; no es posa a 0 perquè un tècnic valida. Per a grup–tipus la validesa final exigeix també ParkodVariantCode no nul, assignat al final de fase 3.

Per proposta cal conservar les fonts utilitzades; quan se'n combinen diverses, el resultat s'analitza per combinació i no s'atribueix arbitràriament a una sola font. Un registre d'avaluació conserva risc original i decisió final de propostes **acceptades, rebutjades i corregides**; en les corregides conserva també la proposta inicial i el resultat validat. Això permet calcular errors observats (`rebutjades o corregides / total amb decisió definitiva`), amb el denominador visible, per àmbit i combinació de fonts. És calibratge posterior, no un llindar d'acceptació. Camps i contractes JSON dels casos de §22.15 aprovats; fórmula predictiva, llindars, controls executables i implementació pendents, a contrastar amb codificacions validades humanament.

---

## 10. Traçabilitat

Les dades obtingudes externament han de conservar la seva procedència.

Sempre que sigui possible s’haurien de guardar:

```text
source
source_identifier
retrieval_date
confidence
raw_value
normalized_value
```

Això ha de permetre saber d’on prové cada dada i tornar a processar-la en el futur.

Aquesta llista és context orientatiu de traçabilitat, no una aprovació de columnes o propietats JSON addicionals. Els casos ja confirmats segueixen el contracte de §22.15 i DATA_MODEL.md §3.11; no s'hi afegeixen retrieval_date, confidence o normalized_value sense acord específic.

La normalització numèrica no converteix unitats; DECIMAL(18,3) no conserva formats equivalents com a valors diferents. Els tipus estructurats també poden tenir etiquetes textuals segons ValueKind, sense convertir-les automàticament a números. Camps originals preservats. EvaluationAuditEvent és el registre únic append-only de decisions i canvis confirmats, no lectures/esborranys/SKU intactes. ProductGroupVariantType i ProductVariantValue guarden OriginalSourcesJson/OriginalProposalJson de candidates automàtiques, copiats a auditoria en decidir. Contractes dels casos confirmats a §22.15 i DATA_MODEL.md §3.11; DDL i comprovacions executables pendents. Una reversió és nova operació revalidada/auditada, sense esborrar l'entrada antiga.

Les reversions no editorials segueixen els circuits normals amb context actual: nova correcció d'assignació per recuperar un valor anterior, o nou trasllat per tornar a un grup anterior, subjectes als controls vigents. No «Desfer OperationId» genèric ni restauració automàtica de snapshots; auditoria com a referència, sense sobreescriure canvis posteriors. És un acord ja existent, no una nova funcionalitat pendent d'aprovar; detall a DATA_MODEL.md §6.8.7.

---

## 11. Arquitectura d’integració

Parkod ha de funcionar com a sistema central independent dels ERP o plataformes eCommerce.

Arquitectura conceptual:

```text
                 PARKOD
                   |
             Parkod API
                   |
      +------------+-------------+
      |            |             |
     Odoo       Shopify      PrestaShop
      |                          |
    Magento                   altres
```

La lògica funcional de Parkod no s’ha d’implementar repetidament dins de cada connector.

Els connectors han de transformar el model Parkod al model específic de cada plataforma.

---

## 12. Compatibilitat eCommerce

El model s’ha de dissenyar tenint en compte com gestionen variants les principals plataformes:

- Shopify
- PrestaShop
- Magento / Adobe Commerce
- Odoo
- WooCommerce

La representació interna de Parkod no ha de copiar exactament el model de cap d’elles.

Ha de ser suficientment neutra per poder alimentar-les totes.

---

## 13. Integració Odoo existent

Existeix una primera implementació Parkod per Odoo 19.

El mòdul actual utilitza models com:

```text
ittar.brand
ittar.ligne
```

i extensions sobre:

```text
product.template
product.product
```

Existeix una jerarquia aproximada:

```text
Marca
  |
Línia
  |
Producte
```

Els codis utilitzats inclouen actualment:

```text
Marca: 3 caràcters
Línia: 2 caràcters
```

amb controls de coherència i unicitat.

Aquesta implementació és una primera versió i no ha de condicionar excessivament el nou model central Parkod.

---

## 14. EAN alternatius a Odoo

S’ha desenvolupat també un mecanisme per permetre diversos EAN per producte.

Model aproximat:

```text
ittar.product.barcode
```

amb:

```text
barcode
product_id
active
```

i control d’unicitat.

Aquest mecanisme resol parcialment els múltiples EAN, però no resol per si sol el problema de les declinacions.

Un EAN alternatiu i una variant són conceptes diferents.

---

## 15. Integració amb POS

En sistemes com Odoo POS és important poder cercar els productes mitjançant:

- EAN
- referència interna
- Parkod

La implementació concreta dependrà del connector.

El model central Parkod no s’ha d’adaptar artificialment a les limitacions del POS.

---

## 16. Integració PrestaShop existent

Existeixen desenvolupaments històrics que sincronitzen informació Winparf/Parkod amb PrestaShop.

PrestaShop diferencia entre:

```text
product
product_attribute
```

El segon correspon aproximadament al concepte de declinació.

Aquesta experiència confirma la necessitat que Parkod pugui distingir explícitament entre:

```text
PRODUCT_GROUP
```

i:

```text
VARIANT
```

---

## 17. Qualitat de dades

El nou sistema ha de prestar especial atenció a:

- EAN duplicats
- EAN reutilitzats
- EAN històrics
- productes desapareguts
- denominacions incoherents
- diferents unitats d’un mateix valor
- abreviacions
- errors tipogràfics
- informació contradictòria entre fonts

Les dades originals no s’han de destruir durant la normalització.

Les unitats diferents defineixen `VariantType` diferents. Aquesta aplicació no gestiona la qualitat ni la vigència dels EAN a l'origen: només els consulta. Les anomalies de les fonts s'informen sense modificar les taules originals.

---

## 18. Principi de compatibilitat

Una decisió important del projecte és:

**No modificar la codificació Parkod històrica per introduir les declinacions.**

El nou model s’ha de construir per sobre de les referències existents.

Per exemple:

```text
PRODUCT_GROUP
      |
      +-- PARKOD A
      +-- PARKOD B
      +-- PARKOD C
```

on cada Parkod identifica una variant concreta. Un SKU encara no agrupat té un grup propi inicial.

Això permet evolucionar Parkod sense invalidar els sistemes actuals que ja utilitzen aquests codis.

---

## 19. Principis de desenvolupament

El nou desenvolupament hauria de seguir aquests principis:

1. Separar model funcional i connectors.
2. No duplicar lògica entre integracions.
3. Preservar les dades originals.
4. Garantir traçabilitat.
5. Automatitzar només quan hi hagi confiança suficient.
6. Permetre validació humana.
7. Fer els algoritmes reproduïbles.
8. Desenvolupar tests des del principi.
9. Evitar dependències innecessàries de plataformes externes.
10. Mantenir compatibilitat amb Parkod existent.

---

## 20. Estat actual

El projecte està en l'etapa 0: documentació i validació de l'estructura nova per a **SQL Server 2017 Express/Windows Server 2019**. No migració de motor prevista ni dependències exclusives del motor 2019 local de proves. Les regles del nucli estan acordades; el DDL, la importació i els algoritmes no s'han implementat ni provat. Diagnòstics previs de només lectura sobre l'entorn local i confirmacions de l'usuari documentats a DATA_MODEL.md §5.5; no proves SQL de domini ni nova execució SQL en aquesta actualització.

El model documentat conté catorze taules i **99 camps**: set taules funcionals de base, ProductGroupCounter i les sis tècniques ParkodVariantCodeRegistry, ParkodVariantCodeBlock, EvaluationAuditEvent, AppAccount, AppSession i SynchronizationStatus. **Totes a VARIANTS_PARKOD.dbo**, amb FK internes, inclosa la còpia de PARKOD. D321 afegeix únicament ProductGroup.IsActive als 98 camps del tall D296, sense nova taula, PK/FK o canvi dels altres camps. D231 ajustava DESIGN1/DESIGN2 a 18 i code1 a 13 NOT NULL; la còpia/font no canvia aquí. Font local poblada i destí existent sense taules; estructura font acceptada i collation local diferent de producció. Els 78.220 SKU/formats observats no són classificació humana validada ni desplegament. Original parkod intacta.

Encara cal definir o validar:

- Les longituds 20/80/80/150, la collation `Latin1_General_100_CI_AI_SC`, els buits prohibits informats, el nom inicial, el comptador i l'ús de `sp_getapplock` estan confirmats; resten DDL i proves.
- IDs de catàleg INT IDENTITY(1,1); ProductVariantId segueix BIGINT IDENTITY(1,1). Numeració de ProductGroupId per marca–categoria, no per línia.
- Claus candidates/FK pendents de materialització/proves: SKU–grup inclou LineCode NOT NULL, SKU–còpia només tres codis. D363 permet desajust CLIGNE/LineCode pendent de revisió, no nova FK amb CLIGNE; coherència de línia classificada sempre. Dues cascades limitades (rèpliques de grup/Type), atomicitat/bloquejos pendents. SourceIsPresent mantingut només externament.
- Controls SQL de compatibilitat de marca i de bloqueig de canvis de `VariantType.BrandCode`. El camp nullable està aprovat i figura al diagrama; la parella `Type + Characteristics` és única globalment, sense incloure BrandCode.
- `VariantType.ValueKind NVARCHAR(7) NOT NULL` i homogeneïtat numèrica/textual confirmats, també per a estructurats. Provar correspondència amb el catàleg i bloqueig amb qualsevol valor o associació aprovada, encara de fase 2 sense codi; no default, rèplica a la filla ni via excepcional aprovats.
- Controls SQL i transaccionals de `ProductGroup.PrimaryVariantTypeId`: pertinença als tipus habilitats del mateix grup, obligatorietat segons el nombre de tipus i bloqueig d'exportació/canvis invàlids. El camp i les regles estan aprovats; la FK composta i el seu manteniment són propostes a validar.
- Materialitzar i provar la via excepcional de BrandCode ja acordada: fora GUI, procediment protegit i identitat SQL administrativa específica, amb impacte/autorització previs, compatibilitat total i auditoria atòmica.
- Contrastar les quantitats/unitats i casos límit amb dades validades: font actual `code1`/`code2`; no reparar codis o quantitats invàlids. Scripts antics discrepants amb la font real.
- Acords fins a D379: 76 procediments/signatures/respostes/funció/matrius intactes respecte de D373. Càrrega externa sempre completa (§23), conciliació completa o per marques; criteris i avís de llista resolts a §22.54, sense persistència o lector nou aprovat. Cobertura/JSON D373, D369 i contextos locals 7/6 intactes. Parser/comparador/balanç i altres controls/DDL/permisos/integracions/consultes/proves pendents; contrast complet de totes les etapes, cap avanç a etapa 1 o implementació GUI.
- RDS, confiança interna simplificada, Argon2id en Python, token de 32 bytes i paràmetres comuns confirmats (§22.20); el model no pretén resistir manipulació intencionada. Provar permisos/connexió/login sense exigir servei central. Aplicar comentaris/inventari de dependències SQL Server al futur SQL.
- Completar l'entorn local ja identificat a DATA_MODEL.md §5.5: VARIANTS_PARKOD existeix sense taules però encara amb configuració local diferent de l'aprovada. Aplicar/provar configuració/model només amb autorització específica, sense intervenir a parkod. Completar evidència dels camps/accessos no transcrits, permisos del futur compte i proves compatibles amb 2017. Pauta nocturna/extraordinària resolta D233; integració carregador, lectures del generador i impacte encara pendents, sense coherència conjunta presumpta ni SNAPSHOT a l'original. Valorar creixement d'auditoria i recursos d'Express.
- Validar DDL/controls sobre codificacions humanament validades abans de tancar etapa 0. Algoritmes de descoberta/calibratge, fonts externes/IA i GUI són etapes posteriors, no implementacions autoritzades aquí.

El detall es manté a [DATA_MODEL.md](DATA_MODEL.md) i [DECISIONS.md](DECISIONS.md). La gestió d'EAN actuals i històrics no és una tasca pendent de l'aplicació: queda fora del seu abast.

---

## 21. Instruccions per a Codex

Abans de modificar codi relacionat amb Parkod:

1. Llegir aquest document.
   Llegir també `docs/DATA_MODEL.md` i `docs/DECISIONS.md`, distingint acords confirmats de propostes pendents.
2. Respectar la compatibilitat amb la codificació Parkod existent.
3. No assumir que EAN diferent significa variant diferent.
4. No assumir que Parkod diferent significa producte comercial diferent.
5. Separar PRODUCT_GROUP, VARIANT i EAN.
6. Evitar introduir regles específiques d’Odoo, Shopify, PrestaShop o Magento dins del model central.
7. Afegir proves per a qualsevol regla funcional nova.
8. Documentar les decisions estructurals importants a `docs/DECISIONS.md`.

---

## 22. Resum funcional acordat de Gestionnaire de Variantes

### 22.1 Persistència i fonts

- Les dades, procediments i scripts nous treballen exclusivament a **VARIANTS_PARKOD.dbo**, a la mateixa instància SQL Server 2017 Express. Sense esquema personalitzat variants; aquesta ubicació substitueix la base única de D01/D65. Integritat referencial només entre taules noves, cap FK entre bases.
- Només el procés extern copia `parkod.dbo.PARKOD` a `VARIANTS_PARKOD.dbo.Parkod`, clau única/vuit camps de §22.5 i SourceIsPresent extern; app només lectura. No-intervenció absoluta sobre original: cap DML/DDL/manteniment/objecte/permís/configuració del projecte, només auxiliars controlades/autoritzades (§22.22).
- Les fonts de la còpia de proves són `PARKOD`, `CATEGORY`, `FAMILY`, `EAN`, `BRAND` i `LINE`; substitueixen els noms font antics segons DATA_MODEL.md §5.3, no reanomenen el model intern. Les dependències necessàries són les quatre primeres; BRAND/LINE es conserven sense dependència necessària per als noms. Cap mestre ni EAN es copia ni rep FK.
- Els noms de marca/línia provenen de `PARKOD.NOM_MARQUE`/`PARKOD.NOM_LIGNE`; categoria per `PARKOD.CCATEG = CATEGORY.IDCategory`, família per `CATEGORY.IDFamily = FAMILY.IDFamily`. Diagnòstics locals previs a DATA_MODEL.md §5.5; completar evidència i provar futurs accessos sense concessions ni objectes a l'original pel projecte.
- `EAN.IDParkod` correspon al SKU concatenat i `EAN.EANNum` aporta els EAN. L'aplicació no n'administra els codis, la vigència ni l'històric.
- `DEPARTEM` queda exclòs; FAMILY només serveix per navegar/preparar lots marca–família, sense canviar PK ni numeració del grup. IDCountry no filtra, agrupa, identifica ni classifica: el producte és independent del país. Això no prova unicitat global dels codis; qualsevol ambigüitat exigeix contrast/revisió, no selecció/fusió arbitrària.
- La taula d'equivalències és documental, no una taula SQL nova. Font poblada i destí sense taules identificats a .\SQLEXPRESS de proves; estructura font acceptada com a referència de producció per l'usuari, no verificada directament a producció. Exportacions/scripts preparatoris no acrediten el desplegament del model.

### 22.2 Taules, camps i funcions

| Taula | Funció | Camps funcionals principals |
|---|---|---|
| `Parkod` | Entrada acumulativa carregada externament, només lectura per a l'app, ancora FK sense afectar producció. | Vuit camps originals i SourceIsPresent extern; PK `CMARQ + CCATEG + CPROD`. |
| `ProductGroup` | Producte comercial amb marca, categoria i línia coherents, nom no únic, tipus principal i activitat operativa independent de validació. | PK `(BrandCode, CategoryCode, ProductGroupId)`; ProductGroupId INT positiu local, ProductGroupName NVARCHAR(150) NULL però informat inicialment, LineCode NOT NULL, PrimaryVariantTypeId INT NULL segons habilitacions i IsActive BIT NOT NULL DEFAULT(1). |
| `ProductVariant` | Identitat estable d'un SKU i pertinença actual única, històric conservat. | ProductVariantId BIGINT IDENTITY(1,1), ProductGroupId INT, clau SKU única i LineCode NOT NULL de classificació, inicialment CLIGNE local però conservat fins a correcció. |
| `VariantType` | Defineix la naturalesa, unitat/escala o característica comercial, representació homogènia i abast de marca. | Identificador, `Type`, `Characteristics`, `BrandCode` nullable i `ValueKind NVARCHAR(7) NOT NULL` numeric/text; parella Type + Characteristics única globalment, sense ValueKind. |
| `VariantTypeValue` | Catàleg de valors d'un tipus, no una variant SKU. | Identificador, VariantTypeId, Type replicat conservat; exactament un NumericValue/TextValue segons ValueKind del pare. No rèplica ValueKind; unicitats no NULL per tipus. |
| `ProductGroupVariantType` | Associació candidata, revisada o finalment habilitada en un grup compatible. | PK `(ProductGroupId, BrandCode, CategoryCode, VariantTypeId)`; ParkodVariantCode NVARCHAR(3) NULL fins a final de fase 3, risc/IsValidated i JSON originals. Type/Characteristics no replicats. |
| `ProductVariantValue` | Assigna/proposa un valor per tipus i SKU després d'aprovar fase 2. | PK `(ProductVariantId, VariantTypeId)`; rèpliques completes de grup, VariantTypeValueId, risc/IsValidated i JSON originals. |
| `ProductGroupCounter` | Numeració tècnica transaccional per marca–categoria. | PK `(BrandCode, CategoryCode)`; LastAllocatedId INT NOT NULL inicial 0. No és un IDENTITY de grup ni una nova classificació. |
| `ParkodVariantCodeRegistry` | Reserves permanents actuals/retirades, sense reciclatge. | PK `(BrandCode, CategoryCode, ParkodVariantCode)`; grup/tipus, candidata dels cinc camps i FK des de l'associació. |
| `ParkodVariantCodeBlock` | Configuració global append-only externa, lectura per l'app. | BlockOrder INT PK immutable, FirstCode NVARCHAR(3); V70, després Z00. |
| `EvaluationAuditEvent` | Decisions i canvis confirmats, append-only sense purga automàtica. | Identitat BIGINT, OperationId, moment/actor, acció/àmbit, JSON originals/resultat/snapshots. |
| `AppAccount` | Comptes propis administrats a l'app. | Identitat INT, LoginName únic normalitzat CI_AI, hash Argon2id, IsActive/IsAdmin. |
| `AppSession` | Una sessió per compte i reserva opcional exclusiva de grup. | UUID, compte, hash SHA-256 de token, activitat UTC i reserva marca–categoria–grup. |
| `SynchronizationStatus` | Última càrrega completa correcta de còpia (D379) i última conciliació completa; no historial. | Fila única 1, dues dates/dos indicadors; cinc camps, sense versions o estat per marca. |

Definicions aprovades de camps/claus al diccionari DATA_MODEL.md §3; resten controls SQL, procediments i proves. ProductGroup/ProductVariant també tenen risc/IsValidated. Textos nous NVARCHAR, sense canvis a camps/tipus/dades originals; cap taula addicional de versions o snapshots aprovada.

D321–D330: IsActive només a ProductGroup, no a les rèpliques de grup ni a les PK/FK/claus JSON. AppAccount.IsActive conserva el seu altre significat. Grup complet nou camps; grup reduït dels contextos SKU–valor cinc camps intactes amb comprovació d'activitat a SQL. No default al client per completar un context antic ni reescriptura d'originals/snapshots històrics.

#### Identitat del grup i compatibilitat dels SKU

- Es mantenen ProductGroup, ProductGroupId i ProductGroupVariantType; només es retiren les denominacions Product/ProductId proposades, no els canvis estructurals. ProductGroupId és independent de ProductVariant.ProductCode.
- ProductGroup té BrandCode NVARCHAR(3) NOT NULL, CategoryCode NVARCHAR(2) NOT NULL i LineCode NVARCHAR(2) NOT NULL. La seva identitat és la PK completa `(BrandCode, CategoryCode, ProductGroupId)`, no el número local sol; LineCode no forma part de la PK.
- ProductGroupId es genera automàticament des d'1 dins de cada parella BrandCode + CategoryCode, amb INT positiu NOT NULL. Pot repetir-se entre parelles: `(ABC, 01, 1)` i `(ABC, 02, 1)` són grups diferents. Comptador local i bloqueig exclusiu `sp_getapplock` per parella aprovats; DDL i proves pendents. Un IDENTITY global no expressa el requisit.
- ProductVariant.LineCode NVARCHAR(2) NOT NULL inicialitza la línia des de CLIGNE local i la conserva fins a revisió, encara que la còpia externa canviï. Grup amb marca/categoria/línia del creador; al corrector de grup propi és la línia **final** revisada del mateix SKU. No canviar la línia d'un grup existent per encaixar-lo.
- Els SKU membres han de tenir la mateixa marca, categoria i línia informada que el grup. La clau candidata `UNIQUE (BrandCode, CategoryCode, ProductGroupId, LineCode)` i FK composta de ProductVariant impedeixen barrejar línies; no cal LineCode a ProductGroupVariantType ni ProductVariantValue.
- Mateixa marca/categoria/línia classificada necessàries però no suficients per agrupar comercialment; noms repetits/grups buits conservats. La còpia publica CLIGNE actual i l'app conserva classificació/decisions, registra discrepància i respecta SourceIsPresent extern. Correcció expressa cap a grup actiu compatible o grup propi nou, tipus/valors/principal coherents sense pèrdues. No corregeix còpia ni original, no reclassifica silenciosament. Caixa/kit no introdueix excepcions als codis aprovats (model §6.3/§6.38).

#### Simplificació i rèpliques controlades

- ProductGroupVariantType manté PK de quatre camps NOT NULL, marca/categoria de grup i textos consultats a VariantType. Codi nullable, risc/IsValidated i JSON originals físics aprovats; habilitació final només amb indicador i codi.
- Es conserva VariantTypeValue.Type i la FK composta amb VariantTypeId per garantir la rèplica del pare. La deducció antiga «no-open_type = numèric» queda substituïda: CHECK local d'exclusió NumericValue/TextValue i open_type textual, més procediments protegits per correspondència amb ValueKind. No nova rèplica ni FK per a ValueKind.
- Es conserva ProductVariantValue.VariantTypeId com a part de la PK que limita una assignació per tipus i SKU. La FK composta proposada amb VariantTypeValueId haurà de garantir que el valor pertany al mateix tipus.
- Es conserva ProductVariantValue.ProductGroupId i s'hi afegeixen BrandCode i CategoryCode, tots tres NOT NULL, per comprovar el grup real complet del SKU i que el tipus hi està habilitat. Les FK proposades són `(ProductVariantId, ProductGroupId, BrandCode, CategoryCode)` cap a ProductVariant i `(ProductGroupId, BrandCode, CategoryCode, VariantTypeId)` cap a ProductGroupVariantType. La PK d'assignació `(ProductVariantId, VariantTypeId)` no canvia.
- El principal referencia una associació amb `(ProductGroupId, BrandCode, CategoryCode, PrimaryVariantTypeId)`. La referència al grup de ProductVariant afegeix LineCode cap a la clau candidata; ProductGroupVariantType utilitza la PK `(BrandCode, CategoryCode, ProductGroupId)`. ProductGroupId sol no és suficient.
- No són definicions independents editables. Les FK comproven la coherència, però no omplen automàticament les rèpliques, **excepte** dues cascades `ON UPDATE CASCADE` delimitades: ProductVariantValue → ProductVariant en trasllats de grup i VariantTypeValue(VariantTypeId, Type) → VariantType(VariantTypeId, Type) només per correcció editorial de Type. Cap cascada DELETE ni canvi silenciós d'IDs o valors; DDL/proves pendents.
- PK de còpia `(CMARQ, CCATEG, CPROD)` i FK de tres camps intactes. UNIQUE/FK de quatre camps amb CLIGNE retirades; D363 permet desajust temporal de còpia–variant. Correcció amb revalidació de la CLIGNE local, no invariant d'igualtat universal; FK variant–grup amb línia classificada sempre coherent. Cap escriptura de còpia per l'app.

### 22.3 Tipus i valors

`Type + Characteristics` defineix, per exemple, `volume/ml`, `weight/gr`, `weight/oz`, `Size/letter`, `Size/cms` o `open_type/color SpringViews`. **Estructurat no significa necessàriament numèric.** `open_type` es conserva exclusivament textual, però deixa de ser l'únic Type que pot tenir TextValue.

- La parella `Type + Characteristics` és una clau única global per a tots els VariantType, estructurats i `open_type`, després de normalitzar els blancs i segons CI_AI: existeix en una sola fila. La restricció és `UNIQUE (Type, Characteristics)`, sense incloure BrandCode; VariantTypeId continua sent la PK.
- No es pot duplicar una parella amb un altre identificador, ni dins de la mateixa marca ni amb una marca diferent ni amb NULL. Una definició global no pot coexistir amb còpies privades de la mateixa parella.
- `VariantType.BrandCode` és nullable per a qualsevol Type. `Type` determina la naturalesa de la característica; `ValueKind`, la representació numèrica/textual; `BrandCode`, l'abast d'ús.
- Si BrandCode és NULL, la definició és global i es pot reutilitzar en grups de qualsevol marca. Que només l'utilitzi actualment una marca no la converteix en exclusiva.
- Si BrandCode està informat, la definició és exclusiva d'aquella marca i només s'associa als seus grups.
- `ProductGroupVariantType` expressa la reutilització de la mateixa definició, sense duplicar-la. Cada associació ha de complir `VariantType.BrandCode IS NULL` o `VariantType.BrandCode = ProductGroup.BrandCode`.
- Els valors numèrics són exactes `DECIMAL(18,3)`, únics dins de cada tipus quan no són NULL; no es converteixen unitats ni s'utilitza `FLOAT`. Els valors que no es poden representar exactament amb tres decimals, o que surten del rang, es rebutgen sense arrodoniment silenciós. Els zeros decimals finals no requereixen més precisió.
- `ValueKind NVARCHAR(7) NOT NULL` admet `numeric` o `text`, únic per a tots els valors del VariantTypeId. Amb numeric: NumericValue obligatori i TextValue NULL; amb text: TextValue obligatori, normalitzat i no buit, i NumericValue NULL. Rebutjar tots dos informats o tots dos NULL. `open_type` exigeix ValueKind=text.
- Un mateix grup pot tenir `Size/letter` textual (M, L, XL, XXL) i `Size/cms` numèric (33, 34, 35): són dos VariantType, no una barreja dins del mateix tipus. Un SKU pot tenir un valor de cadascun. No se'n dedueixen equivalències, ordre comercial o conversions. Una etiqueta que sembli numèrica tampoc es converteix automàticament a número.
- ValueKind no entra a la unicitat Type + Characteristics, no es replica a VariantTypeValue i no afegeix taules/FK. La correspondència amb el pare es comprova als procediments protegits; Type tot sol ja no basta.
- El canvi ordinari de ValueKind es bloqueja amb qualsevol valor del catàleg, encara no assignat, **o** qualsevol associació del tipus IsValidated=1 en qualsevol grup, fins i tot de fase 2 sense codi ni valors. No es desvalida ni elimina res automàticament per permetre'l. Comprovació/canvi atòmics respecte de creació de valors i aprovació de fase 2; no s'estén la via excepcional de BrandCode.
- A VariantTypeValue, `(VariantTypeId, TextValue)` és únic només quan `TextValue IS NOT NULL`, després de normalitzar blancs i segons CI_AI. El mateix text es pot repetir entre tipus diferents, no dins del mateix. Els NULL dels valors numèrics queden fora; la unicitat numèrica també exclou NULL per permetre múltiples valors textuals.
- Diversos SKU poden reutilitzar el mateix VariantTypeValueId mitjançant ProductVariantValue, **també dins del mateix ProductGroup** per al mateix tipus. Una fila de catàleg compartida i una assignació per SKU, amb risc/validació independents; validar-ne una no valida les altres. La unicitat limita un valor per tipus i SKU, no obliga a valors diferents entre membres del grup. No duplicar catàleg ni fusionar identitats de variant; regla ja acordada, no canvi de model.
- Cada SKU té com a màxim un valor assignat per `VariantType` concret. Pot tenir valors de dues unitats diferents perquè són tipus diferents.
- Les edicions de `VariantType.Type`, `VariantType.Characteristics` i `VariantTypeValue.TextValue` sobre una mateixa fila són **només correccions de redacció sense canvi de significat**; conserven les aprovacions després dels controls de normalització/unicitat i auditant l'impacte en usos compartits. Canviar el significat de Type o Characteristics exigeix VariantType nou, nova associació i codi, i revalidar els valors afectats; si només canvia el significat d'un TextValue es crea un VariantTypeValue nou **del mateix tipus** i es reassignen i revaliden els SKU afectats. No es reescriu un valor compartit ni es perd la classificació validada anterior fins a validar el canvi. Com comprovar l'absència de canvi semàntic i autoritzar-ho resta pendent.
- La presentació numèrica pot eliminar zeros decimals finals. No cal conservar formats com `50` i `50.0` separadament dins del mateix tipus.

#### Normalització dels blancs i comparació dels textos nous

- S'aplica normalització automàtica a VariantType.Type, VariantType.Characteristics, ProductGroup.ProductGroupName i VariantTypeValue.TextValue, amb el mateix tractament per a la rèplica VariantTypeValue.Type. Qualsevol seqüència d'un o més blancs, incloent tabulacions, salts de línia i espais especials Unicode, es converteix en un únic espai ordinari U+0020; també es converteixen els blancs especials aïllats. Després es fa trim dels extrems, es valida el resultat i es desa aquell mateix text normalitzat.
- No s'enregistren blancs als extrems, dos blancs consecutius, tabulacions, salts de línia ni espais especials; qualsevol separació interior és un únic U+0020. Es preserva la separació entre paraules. Per exemple, `"  Eau  de   parfum  "` es desa com `"Eau de parfum"`; tabulacions o salts de línia entre aquestes paraules produeixen el mateix resultat.
- La normalització es fa abans de comprovar la unicitat, en insercions i edicions tant interactives com batch. No es rebutja l'entrada només pels blancs que es poden normalitzar; si el resultat entra en conflicte amb una unicitat acordada, es rebutja l'operació sense fusionar files ni canviar identificadors. No s'amplia el domini funcional de Type ni es modifica la nul·litat acordada dels camps.
- Aquests quatre camps admeten i conserven accents i majúscules de les lletres. La collation CI_AI compara sense distingir majúscules/minúscules ni accents, però no els elimina ni canvia la grafia de les lletres desades. Per exemple, `Écru` i `ECRU` no poden generar dos valors del mateix VariantTypeId.
- La collation explícita dels quatre textos i la rèplica Type és `Latin1_General_100_CI_AI_SC`. No es canvia la collation general de parkod, cap columna original ni els camps legacy de la còpia PARKOD. La validació exacta dels codis Parkod continua vigent.
- ProductGroupName continua sense unicitat, encara que es normalitzin els blancs i es compari amb CI_AI. No es converteixen unitats comercials ni es normalitzen els camps legacy de la còpia PARKOD.
- S'aplica exactament Unicode `White_Space`, excloent U+200B i U+FEFF. `VARIANTS_PARKOD.dbo.NormalizeWhitespace` retorna NULL si rep NULL; normalitza abans de validar longitud, buit i unicitat sense truncar. Type/Characteristics i qualsevol TextValue informat, estructurat o open_type, no poden quedar buits; ProductGroupName pot ser NULL però no informat buit, sense conversió automàtica a NULL. CHECKs SQL han de comparar bytes exactes i longitud, no només igualtat CI_AI. Longituds: Type i rèplica NVARCHAR(20), Characteristics i TextValue NVARCHAR(80), ProductGroupName NVARCHAR(150). No s'estén la normalització/collation a ValueKind. DDL i proves pendents.

### 22.4 Concurrència i integritat

Els identificadors i les restriccions els gestiona SQL Server. Les operacions es desen amb transaccions curtes; no es bloquegen taules senceres deliberadament ni es manté una transacció oberta durant l'edició d'un formulari.

Restriccions: identitat completa del grup/numeració local, marca/categoria/línia classificada iguals dels membres, tipus/valors, unicitats CI_AI i principal coherents, màxim un valor per tipus/SKU. FK variant–grup inclou LineCode; FK a còpia només tres codis, no CLIGNE. Inicialització/correcció amb entrada local revisada, però diferència posterior de còpia legítima D363. FK no imposa compatibilitat condicional o obligatorietat del principal; SQL protegit a provar. Cobertura còpia–variant amb entrades encara no admeses pendent de model §6.39.6.

Un trasllat de grup es fa atòmicament, conserva identificadors i revalida marca, categoria i línia del SKU i del destí, els tipus habilitats, el principal, l'abast de marca i les assignacions. Actualitza coherentment les rèpliques del grup complet, sense fusionar ni perdre assignacions silenciosament. Es conserven els grups buits i els registres retirats per permetre auditoria i reversibilitat; no s'esborren en cascada.

Una associació a un grup incompatible amb el BrandCode informat del tipus, la creació d'una parella Type + Characteristics ja existent o un segon TextValue equivalent dins del mateix VariantTypeId es rebutgen. Les comparacions textuals acordades es fan després de normalitzar els blancs i segons CI_AI. La normalització aprovada no autoritza alterar BrandCode, Characteristics o TextValue per esquivar un conflicte, ni fusionar files automàticament. Si el problema apareix durant el processament, s'enregistra i es conserva el tractament tolerant a errors de registre.

#### Canvis de BrandCode

- És un canvi major d'abast, tant per als tipus estructurats com per als `open_type`.
- Si existeix qualsevol assignació del tipus a `ProductVariantValue`, el canvi de BrandCode queda bloquejat en l'edició ordinària. També compten les assignacions dels SKU retirats que es conserven.
- Sense assignacions, el canvi es permet només si totes les associacions existents a `ProductGroupVariantType` continuen sent compatibles amb el nou abast. No s'eliminen associacions silenciosament.
- Per exemple, passar de NULL a ABC no és vàlid si el tipus està associat a un grup XYZ, encara que aquest no tingui valors assignats.
- La comprovació i el canvi s'han de fer atòmicament en una transacció curta, sense permetre que una assignació o associació concurrent invalidi la comprovació.
- Canvi excepcional assignat: fora GUI, procediment protegit només per identitat SQL d'administració autoritzada, mai compte ordinari variants. Requereix impacte/autorització previs i compatibilitat de totes les associacions; si alguna incompatible, rebuig. No elimina associacions/valors ni canvia codis per forçar compatibilitat. Canvi i auditoria abans/després atòmics en transacció curta. Via aprovada, SQL/permisos/proves pendents.

### 22.5 Càrrega externa i conciliació tolerant a errors

**Conciliació des de la còpia**, completa o parcial d'una/diverses CMARQ, manual o programada: idempotent, una execució i zero sessions vigents. Un SKU admissible encara sense variant rep ProductVariant/grup propi actiu provisional i auditories atòmiques; la còpia ja existeix i no s'escriu. Risc inicial sustentat o NULL, IsValidated=0; no aprovació comercial. Intactes/històrics no es recreen; decisions/IDs/valors preservats. Abast parcial no modifica marques alienes. SourceIsPresent i absències són externs, no actuacions del batch. Balanç de processament i diferències de cobertura a §22.48/model §6.39.6.

El batch el llança manualment el personal autoritzat o el Planificador de tasques de Windows; l'app no incorpora planificació ni reintents propis. Hi ha **exclusió global amb les sessions d'usuari**: si n'hi ha una d'activa, el batch no arrenca, finalitza amb codi de sortida **0** i deixa al log tècnic constància explícita de «no executat» i del motiu, sense presentar-ho com a conciliació completada. Mentre el batch corre no es permet obrir sessions d'usuari. Si s'ha omès, una execució manual o una futura tasca planificada el tornarà a intentar per mitjans externs. Això no impedeix les exportacions als clients; el control atòmic d'inici batch/inici sessió resta pendent de proves.

**Contracte de còpia D230–D232, frontera D361–D367 actualitzada D379:** mateixa PK `(CMARQ, CCATEG, CPROD)` i vuit noms/tipus: CMARQ/CCATEG/CPROD NVARCHAR(3/2/3) NOT NULL, CLIGNE NVARCHAR(2) NOT NULL, DESIGN1 NVARCHAR(18) NOT NULL, DESIGN2 NVARCHAR(18) NULL, code1 NVARCHAR(13) NOT NULL, code2 NVARCHAR(1) NULL; SourceIsPresent BIT NOT NULL DEFAULT(1) local i **externament mantingut**. Història acumulada, no DELETE. App només lectura; CLIGNE recent pot diferir de LineCode classificat. Text/French_CI_AS preservats, NOT NULL de code1 no prova quantitat vàlida. Noms/mestres/EAN/preus no s'afegeixen a la còpia; auxiliars autoritzades conservades. Canvis futurs de metadades exigeixen revisió/avís, no truncament. Absències fiables amb càrrega global completa i integritat de producció són responsabilitat externa, no escàner original de l'app. Procés reunit a §23.

Per crear el nom inicial modificable del grup, després de numerar-lo, s'utilitza `PARKOD.NOM_MARQUE + '_' + PARKOD.NOM_LIGNE + '_' + CATEGORY.CategoryName + '_' + ProductGroupId`. Marca/línia provenen del SKU creador i categoria de `CATEGORY.IDCategory = PARKOD.CCATEG`. Si falta una fila o denominació (NULL/buit/blancs), el component corresponent passa a CMARQ/CLIGNE/CCATEG; no s'afegeix fallback a BRAND/LINE ni es tria una altra fila/SKU arbitràriament. Un nom absent no rebutja per si sol el SKU. Si el resultat normalitzat supera NVARCHAR(150), s'utilitza `CMARQ_CLIGNE_CCATEG_ProductGroupId`. Només es genera en crear el grup i no se sobreescriu a la sincronització. Fallada d'accés o ambigüitat no equivalen a nom absent. Només es desa el nom de grup resultant, no les denominacions font com a camps addicionals.

`code1` només accepta dígits ASCII amb punt decimal opcional i dígits als dos costats, sense signes, comes, blancs ni exponents. Lectura exacta DECIMAL(18,3), sense arrodonir: 50.0000 equival a 50, 50.0001 rebutjat. code2 exactament L→volume/ml, G→weight/gr, U→count/unit; NULL/buit/l/altres rebutjats sense U/1. Quantitat >0/entera per U; això no imposa positivitat als valors generals de catàleg. Error de tractament: log anglès/rollback de l'operació/prèvia classificació conservada; l'app no repara ni restaura la còpia actual externa.

Les correccions de línia revaliden **només la còpia local** revisada dins de transacció curta, amb protecció a provar davant de càrrega externa compatible amb usuaris. No relectura CLIGNE original/escriptura de còpia o transacció durant formulari. Canvi de context exigeix revisió; canvi després del COMMIT no reescriu classificació. Contractes §22.47/model §6.38 i matriu d'adaptació §6.40, no mecanisme executable aprovat per aquesta nota.

1. Llegir còpia local disponible/coherent dins de l'abast, sense canviar els seus nou camps o rellegir l'original per conciliació.
2. Tractament de dades pròpies atòmic per operació en transacció curta, no tota l'execució.
3. Error individual conegut: rollback només de l'intent/log anglès/continuar quan segur, conservant decisions.
4. PK de còpia garanteix unicitat; integritat periòdica/duplicats originals i càrrega són externs, cap SourceSkuOccurrenceCount de l'app.
5. SourceIsPresent es consumeix tal com publicat; rebuig d'admissió o incidència no calcula una retirada ni elimina història.
6. Variant/grup/valors anteriors conservats; discrepància CLIGNE–LineCode pendent de revisió humana, no canvi silenciós.
7. Infraestructura incompleta: aturada/resultat fallit, cap èxit fictici o rollback de COMMIT previs. Última operació incerta continua incerta, no reenviament automàtic.
8. Resum de llegits/nous/actualitzats/intactes/rebutjats-pendents, sense doble recompte o transicions externes inventades. Cobertura final a precisar amb còpies encara sense variant.

No s'introdueix **cap objecte** a l'origen, inclosos triggers/vistes ordinàries/indexades/sinònims, ni ara ni com a solució implícita posterior. Una vista indexada tampoc és destí de FK. La còpia periòdica en lectura controlada és adequada perquè s'accepta latència elevada; només les taules noves reben FK.

### 22.6 Auditoria, confiança i validació

L'aplicació ha de permetre identificar autors i canvis, desfer operacions, conservar la procedència i distingir propostes automàtiques de decisions humanes. Els llindars de confiança s'establiran amb dades reals i les proves de domini es faran contra codificacions humanament validades. L'auditoria preserva les decisions definitives acceptades, rebutjades i corregides, i els canvis confirmats de persones i batch amb abans/després, moment i actor/procés; no consulta simple, edicions descartades o SKU intactes. Els logs tècnics d'errors i execucions batch en anglès són separats. Desfer una operació requereix una **nova operació** revalidada i registrada, sense esborrar-ne l'historial.

La revisió humana de propostes SKU → ProductGroup i VariantType → ProductGroup és obligatòria. Es poden preparar lots **marca–categoria o marca–família**, utilitzant CATEGORY.IDFamily i FAMILY.IDFamily/FamilyName només en lectura, sense país. Família agrupa categories però no forma part de la PK o numeració del grup. Tècnics diferents poden treballar en paral·lel amb marques diferents. La confirmació d'un lot requereix mostrar les variants incloses i permetre corregir/excloure cada SKU; una proposta ja validada i intacta no es torna a validar cada dia.

En un grup amb diversos SKU, **cada pertinença SKU → ProductGroup es valida per separat**, fins i tot si l'acció visible confirma el lot complet. La revisió d'un tipus es fa **per parella ProductGroup–VariantType** i mostra tots els SKU d'aquell grup amb el seu VariantTypeValue, el risc/validació de cada assignació i les propostes noves, amb correcció SKU per SKU. El tipus es pot validar al grup abans que tots els SKU tinguin valor; això no autoritza encara l'exportació. Un tècnic pot consultar els altres grups on s'usa el mateix VariantType i el grau de risc/validació de cada associació, sense heretar-ne l'aprovació. Normalment es preveuen menys de 40 ProductVariant per VariantType i grup per dissenyar la pantalla: **no** és un límit de registres.

Validació explícita; tancar descarta edicions manuals, sense esborrany recuperable. Això no elimina candidates automàtiques persistents grup–tipus/SKU–valor amb risc/evidències. Propostes no persistents poden recalcular-se en reobrir; no reescriure risc/validació de files aprovades abans de decidir. Rebuig d'una proposta sobre estat validat conserva aquell estat i només audita la decisió.

La futura pantalla identifica el grup complet i mostra tots els SKU, DESIGN1/DESIGN2 i codis/denominacions de marca, categoria, família i línia amb les fonts acordades. Nom absent mostra codi/incidència, sense inventar ni rebutjar SKU. Riscos, validacions i traça tenen camps físics aprovats al diccionari, sense DDL desplegat ni GUI implementada.

`ProcessingRun`, `AssignmentProposal`, `ValidationDecision` i `ChangeAudit` van ser noms històrics proposats, no adoptats. La taula única aprovada és EvaluationAuditEvent, amb camps al diccionari; cap d'aquestes estructures es considera implementada.

### 22.7 Tipus principal del ProductGroup

`PrimaryVariantTypeId` identifica un VariantType habilitat al mateix grup, no un ProductVariant/SKU ni un VariantTypeValue. És una propietat comuna per a qualsevol ús, independent dels sistemes d'eCommerce o connectors. Pot seleccionar un tipus estructurat o `open_type`, respectant el seu abast de marca.

Només són habilitades les associacions amb **IsValidated=1 i ParkodVariantCode IS NOT NULL**. Candidates i aprovades de fase 2 amb codi NULL no compten ni alteren el principal; recompte segons grup complet. En donar el codi final de fase 3 es revalida el principal atòmicament.

| Nombre de tipus habilitats a ProductGroupVariantType | Regla de PrimaryVariantTypeId |
|---|---|
| 0 | Ha de ser NULL. |
| 1 | És obligatori i ha de ser l'únic VariantTypeId habilitat. |
| Més d'1 | És obligatori i el personal tècnic selecciona un dels tipus habilitats. |

Aquestes regles depenen exclusivament del nombre de tipus habilitats, no del nombre de SKU, del catàleg de valors ni de les assignacions existents. Un grup d'un sol producte també ha de tenir principal quan té un o més tipus habilitats. Els grups buits conservats segueixen la mateixa regla segons les associacions que mantinguin.

El principal ha de correspondre a una associació de ProductGroupVariantType del mateix grup, compatible amb BrandCode. La pertinença i el recompte utilitzen la identitat completa `(BrandCode, CategoryCode, ProductGroupId)`: no es barregen grups d'àmbits diferents amb el mateix ProductGroupId. La FK proposada és `(ProductGroupId, BrandCode, CategoryCode, PrimaryVariantTypeId)` cap a la PK de l'associació. La mateixa VariantType pot ser principal de diversos grups; no és una definició privada ni es duplica per seleccionar-la.

El recompte és per VariantTypeId habilitat, no pel text Type: si Size/letter i Size/cms estan tots dos finalment habilitats, compten com dos tipus i cal selecció tècnica del principal, encara que tots dos s'anomenin Size.

Quan falta el principal obligatori o no és vàlid, es bloqueja l'exportació del grup i es rebutgen els canvis ordinaris que deixin un estat final invàlid. Es permeten les operacions correctives necessàries per definir-lo. Afegir o retirar tipus, canviar el principal o traslladar SKU requereix revalidació atòmica en una transacció curta, sense transaccions obertes durant l'edició del formulari.

No es pot retirar l'associació seleccionada sense deixar un principal coherent amb els tipus resultants en la mateixa operació. Amb més d'un tipus no s'escull arbitràriament el primer ni se substitueix silenciosament una selecció tècnica vàlida. El principal no elimina altres tipus, valors o SKU, ni els fusiona.

Un grup amb diversos SKU però sense tipus definits continua pendent de classificació: tenir el principal NULL no autoritza l'exportació. Disposar d'un principal vàlid tampoc garanteix, per si sol, que tots els SKU tinguin valor o siguin distingibles en una destinació amb una sola característica. Els controls específics del connector s'hauran de concretar sense alterar ni perdre la classificació interna.

La columna admet NULL per representar zero tipus, però és funcionalment obligatòria quan n'hi ha un o més. La FK composta ha estat acceptada com a disseny; el seu DDL i els controls SQL/transaccionals de recompte, selecció tècnica i bloqueig continuen pendents de validar a l'etapa 0. No s'ha implementat cap d'aquests mecanismes.

### 22.8 Primera validació i lectura pels programes Parkod

Per primera vegada un ProductGroup només és exportable quan se n'ha validat la creació/configuració, **té almenys un SKU present i aprovat**, el tipus principal està informat i és vàlid, tots els VariantType habilitats al grup estan validats i **tots els SKU incorporats que s'exportaran** tenen un VariantTypeValue assignat i validat per **cada** tipus habilitat. No n'hi ha prou amb el valor del principal. El tipus es pot aprovar abans d'acabar els valors dels SKU, però el grup no esdevé exportable només per això. Es conserven grups buits; aquests i els grups amb només SKU retirats no s'exporten.

D330 explicita també IsActive=1 a la lectura de variants pel generador existent. No nou veto global de SynchronizationStatus, exportador/vista o escriptura a parkod; integració/proves pendents. Activitat no substitueix cap validació ni garanteix exportabilitat.

«Complet» es refereix als SKU **coneguts, incorporats i presents** a l'origen, no a un inventari hipotètic de SKU encara desconeguts. Els SKU amb `SourceIsPresent=0` es conserven per traçabilitat, però s'exclouen tant de l'exportació com del control de valors que en determina l'exportabilitat. Un SKU nou detectat com a possible membre d'un grup existent no n'atura l'exportació: fins que s'aprova la pertinença i els valors, el grup continua exportant-ne els membres validats, sense incloure el candidat. La introducció pendent no invalida el grup que ja era exportable.

El generador manual existent treballa principalment amb l'original i llegirà VARIANTS_PARKOD.dbo per ParkodVariantCode, Type, Characteristics i NumericValue/TextValue. Cap rèplica d'assignacions a parkod.dbo.PARKOD ni exportador nou. SNAPSHOT inicial curt **només sobre VARIANTS_PARKOD**, tancat abans de generar fitxers; lectures originals separades amb protocol encara pendent, sense activar SNAPSHOT a parkod ni prometre coherència conjunta. Canvis posteriors surten a la següent execució; no NOLOCK ni taula de snapshots. Independent de recàrrega/batch/validació. Indicadors 0 de SynchronizationStatus informatius al log, no vetos; elegibilitat per SKU, retirats exclosos i CLIGNE discrepant pendent amb classificació anterior validada. Configuració nova, permisos i integració/proves encara pendents.

L'adaptació del lector ha de respectar ValueKind i el camp informat, no deduir «numèric» només perquè Type no sigui open_type. Això no autoritza canviar el format legacy ni afegir un exportador a l'app; integració i proves encara pendents.

### 22.9 Comptes, sessions i edició concurrent

Els tècnics s'identifiquen amb **comptes propis de l'aplicació**, no amb comptes Windows. Un administrador gestiona comptes/permisos; validacions per tècnic identificat. Linux només és possibilitat futura, no substitueix Windows Server 2019/SQL Server 2017 Express. **Una sessió activa per compte:** segon intent rebutjat sense expulsar l'anterior. Caducitat de **30 minuts d'inactivitat per defecte**, parametritzable fora GUI; allibera reserva i descarta edicions manuals no validades.

AppAccount/AppSession i camps/claus aprovats al diccionari. Una sola pantalla/grup per usuari amb reserva opcional exclusiva a la mateixa AppSession, sense transacció de formulari ni bloqueig de consulta/generació. Tokens aleatoris només com hash SHA-256, contrasenyes Argon2id. Només interacció real renova activitat, no heartbeat; neteja per demanda. IsActive=0 impedeix login però no expulsa sessió; retirar IsAdmin elimina permisos administratius immediatament. Qualsevol restabliment de contrasenya sí revoca sessió/reserva. Batch i sessions globalment exclosos, també per marques. Procediments/permisos/proves pendents.

RDS/RemoteApp amb compte Windows propi i instància d'app per sessió, AppAccount i token de 32 bytes segons §22.20. Windows no és AppSession ni substitueix token. Confiança interna i Argon2id en Python confirmats; permisos/connexió/proves pendents, no la decisió d'autenticació. Sense servei central.

### 22.10 `ParkodVariantCode`: codi extern de l'habilitació grup–tipus

`ProductGroupId INT` i la seva PK es mantenen. El nou camp acordat **`ProductGroupVariantType.ParkodVariantCode`** no és un ID de SKU, de ProductGroup ni del catàleg global VariantType: amb `(BrandCode, CategoryCode)` identifica **una habilitació concreta** de VariantType en un ProductGroup. És únic dins de la parella marca–categoria entre **totes** les habilitacions, no només dins d'un grup. El mateix tipus pot rebre codis diferents en grups diferents. El nom anteriorment plantejat `ProductVariantCode` a ProductGroup i l'ús de `CPROD` en grups d'un sol SKU **no s'adopten**.

**S'assigna al final de fase 3**, amb valors requerits validats, reserva i principal coherent en una mateixa transacció. La fase 2 pot tenir IsValidated=1/codi NULL; no és habilitació final. Validesa final exigeix indicador i codi. Un cop assignat, immutable i mai reciclat; registre permanent conserva reserva/habilitació després de retirada. Nova habilitació de la mateixa parella consumeix codi nou. Retirada bloquejada amb assignacions referenciades o principal invàlid. Sense codi disponible es rebutja finalització atòmicament, GUI francesa/log anglès. Substitueix l'assignació anticipada de D93.

La configuració global de blocs, **consultada però mai modificada per l'app**, conté l'ordre d'aplicació i només el **primer codi assignable** de cada bloc: inicialment `V70`, després `Z00`; no conté límit superior configurable. Externament s'hi poden **afegir** blocs al final, sense editar ni reordenar els ja configurats. Cada parella marca–categoria consumeix independentment codis incrementals del bloc en ús fins a `xZZ`; aleshores consulta el bloc següent. Sense bloc següent es rebutja la validació, sense consum parcial ni codi provisional. Generació i reserva han de ser atòmiques amb validacions concurrents; el registre històric impedeix el reciclatge.

El codi té tres caràcters ASCII `0–9`, `A–N`, `P–Z` (48–57, 65–78, 80–90), sense O. Regla externa Parkod també sense O per codis originals, sense nou control específic d'O a l'app ni alteració de fonts. Camps/claus de registre/blocs aprovats al diccionari, controls SQL/concurrència encara pendents. L'equip Parkod comprova CPROD abans d'afegir blocs. CPROD dins bloc reservat omet SKU nou i conserva còpia/decisions de l'existent, amb incidència urgent al correu agrupat.

### 22.11 Creació en tres fases i candidates persistents

Explicació detallada demanada en conversa a DATA_MODEL.md §8.4.1. ProductVariant ja és el SKU incorporat, inicialment amb grup propi provisional; les tres fases n'estableixen agrupació comercial, tipus i valors. No són les etapes 0–4 del projecte, no hi ha columna Phase ni una transacció única oberta entre fases. Validacions independents de grup i pertinences a fase 1, d'associació a fase 2 i de cada assignació a fase 3; les operacions conjuntes autoritzades no les aproven implícitament.

1. **Grups i SKU:** descoberta proposa grup comercial, tècnic valida configuració i cada pertinença individual. Un grup pot avançar sense esperar totes les marques. Proposta de pertinença candidata no es desa com a trasllat abans de validar; SKU manté grup propi provisional. Sense agrupació convincent no queda orfe ni va a grup genèric. Grups buits conservats.
2. **Tipus del grup:** candidates ProductGroupVariantType persistents amb risc, originals JSON, IsValidated=0 i codi NULL. Aprovació tècnica passa IsValidated a 1, però codi continua NULL i no habilita ús Parkod/principal.
3. **Valors per SKU:** només per associacions aprovades de fase 2. Candidates ProductVariantValue amb risc i validació propis; revisar/confirmar individualment. En completar els valors requerits dels SKU presents pertinents, assignar codi i revalidar principal atòmicament. SourceIsPresent=0 exclou retirats de l'exigència de valors. No nova taula ni procés de publicació separat: és la finalització de fase 3.

IA pot ajudar amb variables de SKU, dades Parkod/EAN i fonts GS1/marques/eCommerce, però només proposa. Recursos externs/IA es desenvoluparan en etapes 2/3 del projecte, sense saltar validació d'etapa 0; aquestes tres fases de treball no substitueixen les etapes del projecte. Conciliació de font acabada no implica classificació aprovada.

OriginalSourcesJson i OriginalProposalJson NVARCHAR(MAX) NULL, JSON vàlid si informat, a les dues taules candidates: fonts i proposta automàtica originals abans de correccions. No es guarden al catàleg compartit ni són esborranys manuals. En acceptar/corregir/rebutjar es preserven també a EvaluationAuditEvent.

Rebutjar candidata grup–tipus no validada sense codi ni valors elimina només aquella fila; grup/VariantType conservats. Rebutjar valor pendent IsValidated=0 elimina només ProductVariantValue d'aquell SKU/tipus; ProductVariant i VariantTypeValue conservats. Originals/risc/decisió es guarden a auditoria en mateixa transacció, abans d'eliminar; si falla qualsevol operació, rollback complet. Valor obligatori absent impedeix completar l'associació nova. Correccions reassignen a valor correcte existent o nou, sense canviar significat d'una fila compartida ni sobreescriure assignació validada abans de confirmar.

La preparació d'un tipus B en un grup ja habilitat amb A no altera el principal ni la lectura d'A mentre B no tingui codi. No s'aproven dues versions físiques de classificació per resoldre aquest procés de creació. Les correccions editorials i els canvis semàntics continuen sota les regles anteriors.

El moment de reutilització/alta del catàleg automàtic o manual està concretat a §22.18; crear catàleg no valida la candidata. La substitució expressa d'A per B es regula a §22.19, diferent d'aprovar tipus complementaris.

### 22.12 SynchronizationStatus i publicació de còpia disponible

Una única fila tècnica, cinc camps: SynchronizationStatusId TINYINT PK restringit a 1; ParkodLastCompletedAtUtc i VariantsLastCompletedAtUtc DATETIME2(3) NULL; ParkodRefreshSucceeded i VariantsReconciliationSucceeded BIT NOT NULL DEFAULT(0). No versions BIGINT ni estat SQL per marca. Historial d'execucions al log, canvis de dades a auditoria.

- **Senyals externs de còpia, D379:** només camps Parkod, 0 durant càrrega/fallada, 1/data nova únicament després de càrrega **completa verificada i publicada correctament**. Data de darrera càrrega completa correcta de còpia, no recàrrega de producció; data anterior en fallada. D364 parcial substituït, no recuperació per marques que acrediti tota la còpia. No CSV/transferència o implementació d'integritat original exigits al projecte. Disponibilitat requereix cooperació efectiva del publicador, no un indicador descoordinat (§23).
- **Batch complet:** abans de modificar dades posa indicador variants 0, conservant data anterior. Només amb lectura/processament acabats posa 1 i data nova; errors individuals o retirades suspeses registrats poden permetre èxit 1. Fallada d'infraestructura o lectura incompleta deixa 0. Una omissió no modifica camps variants.
- **Conciliació per marques:** consulta disponibilitat de còpia, mateix tractament d'admissió/revisió dins l'abast, no canvia SourceIsPresent o camps globals variants. Abast/resultat al log, mutacions pròpies auditades, cap taula per marca.
- **Omissió programada:** si ambdós indicadors són 1 i data variants posterior a data Parkod, font ja conciliada i batch complet s'omet. Manual explícit pot repetir. Dates suficients segons operativa acordada, sense comptadors de versió.
- **Lectura de fitxers:** els dos indicadors informen situació, no elegibilitat per SKU ni veto global; generador pot operar amb qualsevol indicador 0 i ho registra al seu log.

Carregador extern de còpia i manteniment de producció **fora del projecte**. Dos `.bat` en seqüència al Planificador de Windows: primer carrega parkod.dbo.PARKOD → VARIANTS_PARKOD.dbo.Parkod, després concilia còpia → ProductVariant/grups, després de final correcte anterior. Habitualment completa nocturna diària; no buidar/recrear o perdre decisions. Orquestració D233 ja decidida, no nou planificador intern. Senyals/coordinació només a nova base, integració/proves pendents; horari no prova completesa ni autoritza una càrrega simultània.

Parkod de producció canvia en horari d'oficina; no s'exigeix nova garantia tècnica d'estabilitat nocturna ni control dels usuaris legacy per l'app. Treball extraordinari de nit: coordinació operativa de l'equip, com suspendre les tasques. Si una tasca ja iniciada s'interromp, queda incompleta, sense rollback presumpte dels COMMIT anteriors ni declaració d'èxit. Sense coordinació efectiva d'escriptures externes, el calendari no garanteix coherència; no s'afegeix detecció automàtica ni objectes/bloquejos a l'original. Exclusió sessions d'app/batch intacta.

### 22.13 Coordinació d'execucions, logs i correu urgent

Backend interactiu/batch comparteixen compte SQL tècnic nou i limitat; carregador separat, generador lector separat. Tècnics no tenen logins SQL propis. Procediments d'usuari comproven token, sessió/caducitat/reserva, deriven actor d'AppSession i consulten IsAdmin vigent. Sense DML directe de l'app.

Dos bloquejos d'execució protegeixen **batch exclusiu** i **global batch/login**. Netejar caducades abans de decidir: sessió activa o altre batch ometen execució amb sortida 0 i motius diferenciats; durant batch no nous logins. Mateixa connexió dedicada manté coordinació i escriu en transaccions curtes; perdre-la atura l'execució incompleta.

Coordinació **càrrega externa de còpia/conciliació**, amb recursos de nova base: obtenir abans de tocar/llegir, mantenir per connexió durant cada procés, publicar senyals finals abans d'alliberar. El batch comprova disponibilitat després d'obtenir-la. Sense transacció global o garantia automàtica d'applock sobre un publicador no cooperatiu. Criteri final: **usuaris possibles durant càrrega**, però conciliació sense sessions vigents i amb còpia coherent/estable. No veto de tota la cadena, expulsió o controls a l'original. Confirmació SQL estable/context nou si canvia còpia durant GUI a concretar i provar. Generador independent.

Cada invocació registra al log tècnic anglès hora UTC d'invocació/inici efectiu, abast/marques, durada, completed/not_run/failed, motius i recomptes quan pertoqui. Intactes, errors sense canvi i inici/final no van a EvaluationAuditEvent. Marques amb retirades suspeses queden explícites; no es presenta omissió com èxit real.

Un sol correu urgent per execució, francès, per incidències CPROD en blocs reservats, amb deteccions disponibles també en interrupció. El control de duplicats originals/producció és extern D360, no escàner o correu periòdic nou implementat per l'app. Compte/connexió disponibles, adreces/secrets protegits, logs anglesos/sense reintents. SMTP fallit no desfà dades ni rebaixa èxit completat, però retorna no zero i log inequívoc; no crida FailReconciliation després de Complete.

Durant incorporació inicial, batch complet desactivat al Planificador extern; marques principalment manuals. Després activar completa. Operativa habitual nocturna recàrrega → conciliació; revisió humana l'endemà i generador Parkod manual posterior, sense convertir aquesta seqüència en bloqueig global de la generació independent.

### 22.14 Auditoria física i administració excepcional

EvaluationAuditEvent té camps i contractes dels casos aprovats al diccionari (§3.11): EventKind proposal_decision/confirmed_change, ActionName controlat proposal_review/create/update/retire/password_reset, autor user/process, àmbit/clau, originals, resultat i snapshots. Decisions de proposta exigeixen humà. Una entrada per objecte/decisió amb OperationId compartit; snapshots complets, sense secrets, alta només posterior i eliminació només anterior. Rebuig sense canvi no té snapshots. Rebuig amb eliminació de candidata és una sola entrada proposal_decision/proposal_review/rejected, amb Before complet, After/resultat NULL i auditoria abans del DELETE en la mateixa transacció. No purga, lectures, esborranys ni SKU intactes. Controls SQL, procediments i casos addicionals pendents.

Només administrador restableix contrasenyes, sense funció de canvi propi per tècnic. Qualsevol restabliment revoca sessió/reserva; única excepció de confirmed_change amb ambdós snapshots NULL, acció password_reset i cap secret a la traça. Impedir atòmicament desactivar/retirar IsAdmin de l'últim administrador actiu.

Bootstrap fora GUI només amb AppAccount buit i identitat SQL d'administració autoritzada, mai compte ordinari variants; primer compte actiu/administrador, Argon2id sense contrasenya predeterminada i auditoria process/bootstrap en mateixa transacció. Recuperació excepcional amb identitat SQL administrativa autoritzada, fora GUI: administrador existent, contrasenya nova i sessió/reserva revocades; no modifica IsActive/IsAdmin ni crea comptes; auditoria process/admin_recovery/password_reset. No compte/contrasenya permanent de reserva. Via excepcional BrandCode definida a §22.4 amb els mateixos límits de permisos, impacte i auditoria, no accessible des de GUI ordinària.

### 22.15 Originals, resultats i claus JSON confirmats

El contracte canònic dels casos confirmats és a DATA_MODEL.md §3.11.1–3.11.5 (D143–D155/D159/D165–D167, ampliat per D171–D172 i els casos de substitució). No són nous camps SQL ni estructures desplegades.

- **Fonts:** OriginalSourcesJson és una llista `{source, records:[{source_identifier, raw_value}]}`. source identifica la taula realment llegida: VARIANTS_PARKOD.dbo.Parkod per a la còpia, parkod.dbo.PARKOD per a l'original; raw_value conserva noms i dades observades. [] és absència expressa de fonts; SQL NULL és no registrat/no aplicable.
- **Propostes:** grup–tipus conserva grup/tipus, Type, Characteristics i ValueKind; SKU–valor conserva SKU/grup/tipus/valor, textos i ValueKind/NumericValue/TextValue. No convertir aquests textos històrics en noves columnes replicades. Pertinença identifica el destí; creació de grup, configuració i conjunt ProductVariantIds amb ID de grup JSON null, almenys un SKU real i sense duplicats.
- **Membres:** ProductVariantIds és un conjunt: ordre irrellevant, repeticions rebutjades, no deduplicades. Sense cap membre aprovat no es crea grup; creació rebutjada, no corregida amb zero membres. Un grup existent que després queda buit es conserva.
- **Les dues línies del JSON grup–tipus:** LineCode superior és el destí proposat; ProductVariants conté ProductVariantId i LineCode que tenia cada SKU en preparar l'original, no el possible CLIGNE nou de dbo. En correcció tècnica poden diferir durant la proposta. No és una proposta independent de pertinença ni autoritza línies finals incompatibles.
- **Resultats:** mateixa estructura amb contingut final acceptat/corregit; SQL NULL en rebuig. Grup nou amb ID real i membres aprovats; grup–tipus amb membres i línies finals. Originals no reescrits. Generar ID, reordenar un conjunt o executar un canvi de línia ja proposat no són correccions per si sols; canviar l'agrupació proposada sí. El resultat es compara amb la proposta, no amb l'assignació SQL anterior.
- **Claus d'auditoria:** grup i associació amb identitat completa; group_membership amb grup anterior; variant_value amb valor anterior contextual, sense canviar la seva PK. Si un grup es rebutja abans de crear-lo, context amb marca/categoria/línia, ID null i membres; si es rebutja explícitament un tipus d'aquell grup, afegir VariantTypeId. No inventar IDs ni identificar grup pel nom. Grup rebutjat no implica rebutjos automàtics de tipus no decidits.
- **Sense context anterior (D171–D172):** variant_value usa ProductVariantId/VariantTypeId reals i VariantTypeValueId JSON null només si no hi havia assignació; una candidata pendent existent usa valor anterior real. Alta inicial de group_membership usa ProductVariantId real, BrandCode/CategoryCode i ProductGroupId JSON null perquè no hi havia pertinença anterior. Before SQL NULL, After complet amb grup/valor reals; cap canvi de nul·litat, PK/FK SQL ni extrapolació a catàleg sense ID.
- **Obligatorietat:** proposal_decision exigeix original i resultat accepted/corrected, o resultat NULL per rejected; risc/fonts poden ser NULL segons el cas. confirmed_change sense proposta té DecisionOutcome, risc/fonts originals, proposta i resultat SQL NULL. Només password_reset permet també ambdós snapshots NULL en un canvi confirmat.
- **Snapshots:** tota la fila auditable, inclòs ValueKind, amb camps NULL explícits i sense secrets. En una alta/eliminació, SQL NULL és absència de fila al costat corresponent; un camp JSON null és nul·litat dins d'una fila existent. En rebuig sense canvi, ambdós snapshots NULL indiquen que no es registren snapshots, no que l'estat vigent hagi desaparegut. Columnes JSON imbricades com a arrays/objectes, no strings escapats; preservar contingut, no formatació.
- **Validació:** cap propietat duplicada ni als interiors; TargetKeyJson/proposta/resultat només amb noms exactes previstos, sensibles a majúscules, sense desconegudes. Els noms de raw_value depenen de la font. SQL genera clau, snapshots i resultat des del context verificat, no de JSON lliure de la GUI.
- **Autoritat:** originals/risc de candidata persistent pendent llegits de la fila SQL sota bloqueig; de proposta no persistent, conservats pel backend separats de correccions. Proposta nova sobre estat validat no utilitza els originals antics de la fila ni els sobreescriu abans de decidir. SQL no pot provar tot sol què va mostrar la pantalla o quina resposta externa va observar el backend. Sense context, cal nova revisió, no reconstrucció silenciosa.
- **OperationId:** generat pel procediment SQL per operació atòmica; entrades conjuntes comparteixen ID, altres confirmacions en tenen un de nou. No un sol ID global per batch amb transaccions independents.

### 22.16 Context de revisió i concurrència

**Abans d'aplicar les correccions, SQL comprova que les dades rellevants sobre les quals el tècnic ha pres la decisió no hagin canviat des que les va revisar.** Estat SQL revisat, originals i correccions són tres informacions separades. Si es revisa una assignació M i es vol XL, SQL comprova que encara sigui M i després valida/aplica XL; si ara és L, rollback i nova revisió. No s'edita el valor de catàleg M per convertir-lo en XL.

Identitats/codis/números/indicadors/NULL coincidents; text exacte distingint accents i majúscules, no igualtat CI_AI d'unicitat. JSON per contingut, no indentació; composicions per conjunt, no ordre visual. Altes/baixes rellevants també són canvis. Una correcció editorial preserva aprovacions existents però obliga a renovar una revisió oberta afectada. No transaccions de formulari ni rowversion/versions/taules noves.

| Operació | Abast confirmat, detallat a DATA_MODEL.md §6.8 |
|---|---|
| Candidata SKU–valor | Assignació completa; pertinença, identitat/línia/validació de grup, tipus i valors implicats, associació i CLIGNE/presència de còpia. No canvis d'altres SKU aliens a les dependències. |
| Candidata grup–tipus | Associació i grup complets, definició compartida i conjunt de membres amb línia/presència/validació. Sense exigir valors abans de fase 2. |
| Trasllat a grup existent | SKU/còpia, grups actual/destí i composicions, associacions, totes les assignacions del SKU i catàlegs implicats. |
| Creació amb SKU incorporats | SKU/còpia, grups actuals abans del trasllat amb membres/associacions, assignacions conservades i catàlegs. Sense fila de destí encara. |
| Finalització de fase 3 | Grup/principal, membres/presència/validacions, associacions amb originals, assignacions requerides incloses absències i catàlegs. Retirats exclosos de valors exigits. |
| Substitució completa A → B | Context específic de set blocs de DATA_MODEL.md §6.11.4, obtingut amb SNAPSHOT curt i comparat en nova transacció sota bloqueig. No context universal per tota operació. |

Els «grups actuals dels SKU abans del trasllat» són els provisionals o comercials als quals pertanyen ara. No es traslladen tots els seus membres automàticament i els grups buits es conserven. L'alta inicial batch crea el primer grup propi i no té un grup anterior.

**No es congelen comptadors ni pròxim codi durant la pantalla.** L'avanç de ProductGroupCounter o el consum de codis per altres operacions no són conflictes de revisió: SQL assigna/reserva el disponible atòmicament en confirmar, sense reciclar. L'ID no estava reservat. Canvis en altres dades rellevants exigeixen nova revisió. La reserva/assignació del codi i principal coherent són una mateixa finalització, no ajustos parcials.

Operacions de classificació i conciliació consumeixen la còpia local, no CLIGNE original; consultes auxiliars autoritzades amb protocol propi separat. Disponibilitat de còpia, context i integritat segons operació; GUI possible durant càrrega però cap permís de confirmar sobre context canviat. Un conflicte o error tècnic no és decisió humana confirmada.

### 22.17 Creació conjunta amb valors preexistents i coherència pendent

Quan es crea un grup amb SKU que ja tenen valors, el tècnic revisa prèviament grup/membres i les associacions compatibles necessàries. Les associacions del destí requereixen aprovació explícita, no herència dels grups anteriors. SQL compara contextos i crea grup/associacions aprovades/trasllats amb valors preservats en una transacció curta, decisions individuals i OperationId comú; qualsevol incoherència desfà tot. No grup preparatori buit persistent ni trasllat abans de validar.

Original de l'associació amb grup nou conserva ProductGroupId JSON null; resultat i clau de l'associació confirmada usen l'ID real. No es reescriu l'original ni canvia la nul·litat SQL. Codis anteriors no es traslladen ni es reciclen; codis nous subjectes a fase 3 i principal coherent. Les fases es revisen abans i s'executen conjuntament quan cal conservar valors, no s'aproven automàticament.

La revisió documental de 2026-10-18 contrasta aquest canvi conceptual amb el funcional/model: mateixa identitat de grup/SKU, 14 taules, dues cascades, unitats i codis preservats; ValueKind és l'única columna nova d'aquests darrers acords. Els controls abans atribuïts a Type s'han ajustat, i els JSON no es confonen amb rèpliques físiques.

**Etapa 0 oberta:** fins a D379/76 procediments de disseny, model 14/99 sense canvis físics o de signatures. Càrrega només completa externa (§23), criteris/avís de llista (§22.54), cobertura/JSON D373 i contextos locals 7/6 resolts en disseny. D369 intacte; proposta de bloqueig de validació SKU–grup per línia discrepant encara sense confirmació final. Resta de mutadors, detalls de consulta/GUI, DDL/permisos/integracions/concurrència/proves humanes pendents. No reactivar grups o extrapolar altes sense ID; ValueKind sense default/collation/excepció nous. Cap etapa 1–4 implementada/validada.

### 22.18 Catàlegs compartits i altes automàtiques/manuals

**D173–D176, detall a DATA_MODEL.md §6.10:** no es creen VariantType/VariantTypeValue per cada SKU. Reutilitzar definició i valor existents compatibles; una incompatibilitat de marca o representació no autoritza duplicar la mateixa parella Type + Characteristics.

- Sobre grup existent, crear el tipus que falti i la candidata grup–tipus en una mateixa transacció curta de fase 2. En fase 3, només després d'aprovar l'associació, crear el valor que falti i la candidata SKU–valor en una mateixa transacció curta. Les candidates referencien IDs reals, sense aprovació implícita pel fet de crear catàleg.
- Per proposta automàtica de grup encara no creat, preparar prèviament el tipus real, reutilitzat o creat amb auditoria; conservar proposta de grup/associacions al backend fins a confirmació conjunta. Rebuig/fallada posterior no desfà una alta de catàleg anterior ja confirmada. No grup preparatori buit, associació sense grup ni trasllat anticipat.
- Alta manual per corregir valor o tipus: durant edició només al backend; crear en validar amb l'assignació/associació, controls i auditories individuals, una transacció curta i OperationId comú. Originals preservats, resultat amb IDs reals. Si el tipus canvia de significat no s'edita el compartit anterior.
- Cancel·lar no crea catàleg ni altera la candidata automàtica persistent. Col·lisió concurrent exigeix nova revisió, sense reutilització silenciosa d'un ID aparegut després. Seleccionar un existent compatible és decisió explícita.
- Rebutjar candidata conserva catàlegs. Preparació independent de tipus globals/valors aprovada a §22.23; no extrapolar a tipus exclusius ni a propostes amb ID de catàleg inventat/null.

**Entrada SKU–valor confirmada (D239):** exactament una via: `@SelectedVariantTypeValueId INT` informat amb `@NewValueJson=NULL`, o ID NULL amb `@NewValueJson NVARCHAR(MAX)` informat. NewValueJson és un objecte amb exactament NumericValue i TextValue, tots dos obligatoris, un informat segons ValueKind del tipus i l'altre JSON null. Aplica expressament la gramàtica decimal D236 i les regles existents de text/unicitat. Paràmetres transitoris, no columnes noves ni IDs absents als originals; alta del valor nou i confirmació de l'assignació/auditoria atòmiques amb ID real, sense duplicar assignació existent. Detall a DATA_MODEL.md §6.10.1; D241 confirma posteriorment nom/signatura/defaults a §6.15.1.

**Resposta de candidata acceptada/corregida (D240):** dos conjunts només post-COMMIT: primer una fila OperationId UNIQUEIDENTIFIER + ProductVariantValue complet resultant; segon una fila VariantTypeValue final complet, existent o nou. Resultats capturats dins de l'operació, no relectura posterior; l'app rep l'ID real i el contingut definitiu normalitzat. No finalitza automàticament fase 3 ni assigna codi Parkod. Rebuig/altres circuits/no-op no s'hi extrapolen; camps exactes i límits d'abast a DATA_MODEL.md §6.10.2.

### 22.19 Substitució expressa A → B i transició final

**D177–D193, contracte canònic a DATA_MODEL.md §6.11:** A/B són tipus diferents del mateix grup existent. Si tots dos són bons i complementaris, s'aproven tots dos; no hi ha substitució ni eliminació implícita. Si el tècnic expressament substitueix A:

| Estat | Tractament |
|---|---|
| A candidata no validada, codi NULL i sense assignacions; B encara no associada | A corrected/eliminada; B creada aprovada a fase 2, codi NULL, amb risc/originals d'A preservats. Una decisió de proposta per A i auditoria d'alta de B, no segona acceptació de la mateixa proposta. |
| A candidata admissible; B ja aprovada i revisada | B intacta; només corregir/auditar/eliminar A amb resultat B. No sobreescriure originals/codi ni auditar B intacta. |
| A i B candidates admissibles | Revisar originals de totes dues: A corrected/eliminada i B accepted/aprovada si s'accepta tal com estava proposada. Dues decisions reals i OperationId comú; no barrejar originals/riscos. |
| A aprovada a fase 2, sense codi ni assignacions; B candidata | Retirada expressa d'A amb confirmed_change/retire i aprovació explícita de B amb els seus originals. Aprovar B no retira A automàticament. |
| A amb assignacions | Conservar A/assignacions mentre es prepara B i els seus valors propis. Cap conversió, còpia ni validació automàtica d'A com a B; transició final conjunta. |

La substitució completa permet retirar relacions SKU–valor només amb decisió individual explícita i auditoria, incloses validades i de SKU retirats. Es conserven catàlegs, IDs compartits i historial. Si cal conservar una assignació d'A com a fila, bloquejar retirada completa. Retirada funcional = confirmed_change/retire, Before complet amb originals i After SQL NULL; no rebuig automàtic de predicció. Un rebuig exprés d'una proposta pendent segueix proposal_decision/proposal_review/rejected amb una sola entrada.

La transició final revalida context/decisions i valors requerits de B, finalitza B amb codi propi nou o existent conservat, fixa principal segons habilitacions finals i retira assignacions d'A/A amb auditories individuals i OperationId comú, en una transacció curta. Codi d'A mai transferit/reciclat; registre permanent conservat. Amb un sol tipus final, aquell ID; amb múltiples, conservar tria tècnica vàlida o exigir-ne explícita si A era principal. Canviar principal abans d'eliminar A quan la FK l'apunti. Un error amb rollback desfà tota aquesta transició, no preparacions anteriors confirmades de B.

Procediments amb noms, responsabilitats i signatures completes confirmats per D234–D235/D237 a DATA_MODEL.md §6.11.2, sense implementació:

- `VARIANTS_PARKOD.dbo.GetGroupVariantTypeReplacementContext`: sessió/reserva i context coherent amb SNAPSHOT curt a la nova base, tancat abans de revisar. No altes, trasllats ni reserva de codis.
- `VARIANTS_PARKOD.dbo.ConfirmGroupVariantTypeReplacement`: nova transacció sobre estat actual bloquejat, comparació de context, decisions/estat final i auditoria atòmics. No modificacions globals de catàleg, correcció de línia ni exportació.

Entrada mixta: sessió verificada i paràmetres tipats de grup/A/B/eventual principal; dos JSON NVARCHAR(MAX) transitoris, un de context revisat i un de decisions. Decisions amb només ProductVariantId i Decision retire/reject, exactament una per assignació d'A revisada, inclosos retirats; [] només sense assignacions. No decisions deduïdes de validació/presència, duplicats ni ampliació automàtica davant noves assignacions.

**Validat:** A és `@VariantTypeIdToReplace INT`, B és `@ReplacementVariantTypeId INT`, als dos procediments. La lectura revisa una substitució concreta amb A/B seleccionats prèviament; no retira A ni aprova B, i A no ha de ser el principal. `@SelectedPrimaryVariantTypeId INT = NULL` significa «sense nova selecció», no esborrar: un tipus final → aquell ID; múltiples amb NULL → conservar principal actual vàlid, altrament exigir selecció explícita. ID informat ha d'estar finalment habilitat o es rebutja tota la transició. Només IsValidated=1/codi no nul; B no esdevé principal automàticament per substituir A. En substitució completa B queda habilitada i el principal final no és NULL.

**D237 completa el contracte:** @BrandCode NVARCHAR(MAX), @CategoryCode NVARCHAR(MAX) i @ProductGroupId INT als dos procediments; @ExpectedContextJson NVARCHAR(MAX) i @AssignmentDecisionsJson NVARCHAR(MAX) a la confirmació. Longitud exacta 3/2 abans de convertir, sense truncament ni ampliar columnes. La lectura retorna una única fila ContextJson NVARCHAR(MAX) amb els set blocs acordats. Ja no són detalls pendents de validar; resten SQL/proves.

El context de set blocs de substitució no és universal: grup/membres/associacions/tipus/valors/assignacions A-B segons model §6.11.4. Membres amb LineCode classificat i CLIGNE/SourceIsPresent locals; D363 permet diferència d'entrada pendent de revisió, sense risc de pertinença afegit/lectura original. Assignació B absent null explícit, no pendent/{}; absència o manca de validació requerida bloqueja finalitzar. JSON originals imbricats, sense duplicats o columnes noves. Controls ordinaris afectats per discrepància de línia a revisar a §6.40 del model.

Èxit: una única fila **després del COMMIT** amb OperationId UNIQUEIDENTIFIER, ParkodVariantCode NVARCHAR(3) final de B i PrimaryVariantTypeId INT final, tots informats. Principal pot ser altre tipus habilitat. SQL genera aquests resultats i l'auditoria.

Timeout/pèrdua de connexió o resposta incompleta poden deixar resultat incert: no repetir automàticament, afirmar rollback ni registrar rebuig humà; impedir nova confirmació amb context antic. **D238: recuperació manual exclusiva d'administradors de l'app amb IsAdmin vigent**, també per operacions d'altres usuaris, amb els controls de sessió existents. L'administrador consulta OperationId si conegut o grup/A/B afectats i contrasta auditoria/estat actual; si no s'aclareix, incidència pendent. Absència de registre no prova rollback: la petició podria seguir executant-se. Consulta de lectura, no modifica ni desfà dades; sense comprovació automàtica, taules noves, reconstrucció automàtica o idempotència garantida. Això substitueix la proposta intermèdia automàtica i no restringeix les correccions ordinàries als administradors. Consulta administrativa executable encara per concretar a DATA_MODEL.md §6.11.6.

### 22.20 Desplegament RDS, sessions i tokens

**D194/D196–D200:** instal·lació Windows, compte Windows propi i instància d'app per sessió RDS/RemoteApp. Login AppAccount independent; token criptogràfic de **32 bytes exactes** només en memòria, SQL només SHA-256. Paràmetres comuns @AppSessionId UNIQUEIDENTIFIER i @SessionToken VARBINARY(MAX), longitud exacta abans de convertir. AppSessionId sol no autentica; cap secret a contextos/logs/auditoria/snapshots.

**Confiança interna simplificada acceptada:** connexió directa als procediments limitats; Python verifica Argon2id, SQL confia en la verificació per emetre sessió i després comprova token/deriva actor. Finalitat d'atribució i auditoria ordinària; no garantia contra manipulació intencionada de programa/credencial SQL comuna. No servei central ni autenticació Windows automàtica. Mantenir protecció de connexió/credencials i permisos limitats, sense presentar aquest límit de confiança com encara indecidit.

Login en dos passos SQL: `dbo.GetAppAccountAuthenticationData(@LoginName NVARCHAR(MAX))` retorna zero/una fila activa AppAccountId INT/PasswordHash NVARCHAR(255), EXECUTE sense SELECT general a AppAccount; Python verifica Argon2id fora de transacció; `dbo.CreateAppSession(@AppAccountId INT, @ExpectedPasswordHash NVARCHAR(MAX), @SessionToken VARBINARY(MAX))` revalida actiu/hash exacte, caducades, sessió única i exclusió batch atòmicament. SQL genera/retorna AppSessionId només post-COMMIT. Hash esperat detecta restabliment concurrent, no prova autenticació autònoma. Signatures canòniques a DATA_MODEL.md §6.13, sempre a VARIANTS_PARKOD.dbo.

Desconnexió RDS no és logout ni prova rollback; Windows obert no renova activitat. Batch comprova AppSession. Longitud/token/signatures ja confirmats; implementació/permisos/proves pendents.

### 22.21 Responsabilitats SQL i documentació de T-SQL

**D195:** mantenir a SQL integritat, controls compartits de sessió/permisos/reserva, concurrència i confirmació atòmica de dades/auditoria. No traslladar-los a Python per aparent portabilitat; Python conserva GUI, flux de revisió i preparació de propostes/contextos.

Prioritzar SQL estàndard, operacions relacionals i restriccions declaratives; procediments acotats, transaccions curtes, control clar d'errors/COMMIT/ROLLBACK, sense SQL dinàmic o complexitat innecessaris. No s'exigeix portabilitat ANSI/ISO total ni substituir mecanismes SQL Server aprovats.

Cada dependència SQL Server, de sintaxi **o comportament**, s'identificarà en anglès al punt d'ús: característica, motiu i garantia a preservar. Inclou sp_getapplock, SNAPSHOT, collations, índexs, tipus/sintaxi i lectures entre bases. Inventari DATA_MODEL.md §6.12, arguments DECISIONS.md, regla AGENTS.md. Documentar no aprova dependències noves ni canvis legacy. OPENJSON previst només a VARIANTS_PARKOD/140; original parkod/100 intacta. Parser/controls executables pendents.

### 22.22 Base exclusiva i no-intervenció a parkod

**D218–D222:** VARIANTS_PARKOD, esquema dbo existent, a la mateixa instància SQL Server 2017 Express sobre Windows Server 2019. No esquema personalitzat variants ni migració de motor prevista; totes les escriptures/objectes nous aquí, no a parkod. dbo no concedeix db_owner a l'app.

| Opció | VARIANTS_PARKOD: disseny aprovat, pendent d'aplicar/provar | parkod original |
|---|---|---|
| Compatibilitat | 140 | 100, intacta |
| Collation general | French_CI_AS | French_CI_AS, intacta |
| ALLOW_SNAPSHOT_ISOLATION | ON | OFF, intacta |
| READ_COMMITTED_SNAPSHOT | OFF | No contrastat; cap canvi |

French_CI_AS de producció confirmada per l'usuari a totes les columnes textuals; es manté al destí general, als vuit camps copiats i als codis relacionats. Latin1_General_100_CI_AI_SC als quatre textos nous/rèplica Type, i LoginName amb CI_AI ja aprovada, sense canvis. Columnes textuals dels dos costats d'una FK han de tenir collation coincident, encara amb codis ASCII. La font local SQL_Latin1 pot requerir COLLATE en comparacions, sense modificar-la ni alterar grafia NVARCHAR.

**Entorn local observat, no disseny de producció:** .\SQLEXPRESS, SQL Server 2019 Express 15.0.2200.2; parkod poblada i VARIANTS_PARKOD existent sense taules. Totes dues a 150/SQL_Latin1_General_CP1_CI_AS/SNAPSHOT OFF/RCSI OFF. Configuració aprovada encara no aplicada; cap canvi automàtic ni dependència exclusiva de 2019. Diagnòstics previs a DATA_MODEL.md §5.5, autorització separada abans de configurar/desplegar.

**Prohibició permanent:** cap modificació de dades, taules/esquemes, índexs, triggers, vistes, sinònims, usuaris/permisos, manteniment o configuració a parkod. Només lectures controlades i autoritzades; si cal intervenir-hi per resoldre una integració, redissenyar. Els permisos han d'estar disponibles sense canvi del projecte a l'original. Aquesta regla no impedeix l'operativa legacy de l'equip ni posa tota la base en READ_ONLY.

| Font de la còpia de proves | Modalitat i finalitat permesa |
|---|---|
| parkod.dbo.PARKOD | Únic origen de la càrrega externa dels vuit camps a VARIANTS_PARKOD.dbo.Parkod, no càrrega de l'app; consultes auxiliars/noms/preus autoritzades sense persistència addicional. |
| parkod.dbo.CATEGORY | Consulta puntual IDCategory/CategoryName/IDFamily, categoria i família. |
| parkod.dbo.FAMILY | Consulta puntual IDFamily/FamilyName només per navegació/lots marca–família. |
| parkod.dbo.EAN | Consulta puntual IDParkod/EANNum, EAN d'ajuda a classificació, sense gestió de vigència/històric. |
| parkod.dbo.BRAND | Mestre conservat, IDBrand/BrandName com a correspondència documental; no necessari per als noms directes de PARKOD. |
| parkod.dbo.LINE | Mestre conservat, IDLine/IDBrand/LineCode/LineName com a correspondència documental; no necessari per als noms directes de PARKOD. |

Inventari canònic DATA_MODEL.md §5, actualitzat per D223–D232: noms de marca/línia consultats directament a PARKOD.NOM_MARQUE/NOM_LIGNE, no copiats. Dependències necessàries PARKOD/CATEGORY/FAMILY/EAN; cap mestre/EAN copiat o amb FK. DEPARTEM exclosa, qualsevol altra font funcional requereix validació. Estructura font acceptada com a referència de producció per l'usuari, no inspeccionada directament en aquesta tasca; noms font no són taules noves internes.

Només lectura no implica impacte nul: bases comparteixen CPU/memòria/disc, lectures poden bloquejar. Provar abast/impacte sense NOLOCK. Express 2017 limita dades a 10 GB per base; espai actual original no prova creixement d'auditoria ni rendiment multiusuari futurs. SNAPSHOT només nova base; protocols entre bases/carregador/generador encara pendents, sense coherència conjunta presumpta ni canvis de permisos/configuració a l'original.

### 22.23 Catàleg permanent, alta global i correcció/reversió editorial

**D201–D217; contractes exactes DATA_MODEL.md §6.14.** Finestra permanent amb definició, tots els valors —també no assignats—, consulta d'usos i motius de bloqueig. Disponible encara amb múltiples grups; no bloquejar tota la finestra ni substituir tot el catàleg en desar.

- Preparar independentment **tipus globals** i valors: en memòria fins a confirmar; tipus, valors i una auditoria confirmed_change/create per fila, OperationId comú, tots o cap. BrandCode fixat NULL, tipus buit admès; cancel·lació no crea files. Cap grup/assignació/validació/codi implícits. No alta independent de tipus exclusius per extrapolació.
- `dbo.CreateGlobalVariantTypeWithValues`: sessió + Type/Characteristics/ValueKind/ValuesJson NVARCHAR(MAX); rebutja parella existent global/exclusiva. ValuesJson exactament NumericValue/TextValue, un informat segons pare, sense IDs/rèpliques, normalització i DECIMAL(18,3) exacte. [] admès. Dos conjunts post-COMMIT: OperationId/tipus complet i tots els valors creats.
- `dbo.GetVariantTypeCatalog`: sessió + VariantTypeId INT; una fila CatalogJson amb VariantType i VariantTypeValues complets, [] si buit, error si inexistent; global/exclusiu, SNAPSHOT curt, sense reserva de grup/auditoria de lectura.
- `dbo.AddGlobalVariantTypeValues`: sessió + VariantTypeId INT/ExpectedCatalogJson/ValuesJson; tipus encara global i context de dos blocs coincident. Lot nou no buit, atòmic; auditar/retornar només nous, no intactes. Col·lisió o canvi de context exigeix nova revisió, no reutilització silenciosa.

**D236, NumericValue de ValuesJson:** quan informat, número JSON amb part entera, punt decimal opcional i signe negatiu opcional; sense cometes, signe +, coma decimal ni notació científica. Exactament representable en DECIMAL(18,3), sense FLOAT/arrodoniment; posicions decimals posteriors a la tercera només si zero. 50/50.125/50.0000 admesos, 50.0001/cadena "50"/5e1 rebutjats; zero i negatius no rebutjats per si sols. Només contracte de nous valors, parser/proves pendents. No modifica code1, positivitat/unitats de font, TextValue legítim "50" per tipus textual ni originals històrics.

Correcció editorial requereix confirmació humana **«Je confirme que cette correction ne change pas la signification.»**, BIT=1. Només redacció de Type/Characteristics/TextValue; canvi semàntic/quantitatiu segueix alta nova i revalidació, no aquesta via. Usos, IDs, validacions, codis i JSON històrics preservats.

- `dbo.GetVariantTypeValueEditorialContext`: tres blocs exactes VariantType/VariantTypeValue/Usages, filtre pel valor.
- `dbo.GetVariantTypeEditorialContext`: D328 conserva ContextJson amb quatre blocs VariantType/VariantTypeValues/ProductGroupVariantTypes/Usages i totes les associacions, també històriques. La mateixa fila retorna una segona columna InactiveProductGroupsJson amb les claus completes dels grups inactius referenciats, úniques/[] si cap, mateix SNAPSHOT; no cinquè bloc o nou camp físic. GUI oculta aquests grups operatius però SQL no n'ignora compatibilitat/bloquejos. Confirmadors reben només ContextJson; lector SQL protegit D314 segueix una columna/quatre blocs.
- Usages inclou tots els usos pendents/validats i de retirats: ProductVariantValue complet i ProductVariant reduït amb ID/codis SKU/grup i Parkod:{SourceIsPresent}. Sense risc de pertinença/noms/línia; [] si cap ús, no duplicats, null o files incompletes. Estructura canònica §6.14.6, no els membres de substitució.
- Contextos SNAPSHOT curts només nova base, tancats abans de revisar. Confirmació en nova transacció sobre estat actual sota bloqueig exclusiu per tipus, respectat per totes les vies que alteren context/usos; no bloqueig de formulari/reserva de tots els grups.
- `dbo.CorrectVariantTypeValueText`: sessió + ID/context/TextValue/confirmació; tipus textual, només TextValue, mai NumericValue. Una auditoria de canvi; una fila post-COMMIT OperationId i valor complet.
- `dbo.CorrectVariantTypeText`: sessió + ID/context/Type/Characteristics/confirmació; dos textos finals obligatoris, NULL no conserva. Auditar cada fila realment modificada, incloses rèpliques Type, snapshots complets/OperationId comú; no SKU/associacions intactes. Dos conjunts post-COMMIT: OperationId/tipus complet i només valors modificats.
- Propagació exacta de majúscules/accents malgrat CI_AI pendent de prova SQL; si no es garanteix, rollback íntegre. No-op exacte després de normalitzar/contrastar context: cap UPDATE/auditoria, OperationId de resposta NULL i segon conjunt buit si existeix.
- Reversió editorial pels mateixos procediments amb context actual nou, textos anteriors proposats, confirmació humana nova i nova auditoria/OperationId si hi ha canvi. No restaurar snapshots sencers, alterar historial, eliminar catàleg o recuperar assignacions retirades per aquesta via editorial. Altres reversions pels circuits normals ja acordats. Resultat incert: context antic invalidat, recuperació manual d'estat/auditoria només admin segons D238, cap reenviament automàtic ni rollback presumptiu.

### 22.24 Còpia de proves i taula documental d'equivalències

**D223–D228; detall canònic DATA_MODEL.md §5.3–5.4.** La nova parkod aportada és una còpia de producció per a proves. Les correspondències CATEGOR → CATEGORY, FAMILLE → FAMILY, GENCOD → EAN, MARQUE → BRAND i LIGNE → LINE no autoritzen modificar fonts, reanomenar camps interns ni ampliar la còpia de vuit camps. La taula origen/destinació/modalitat/regla és exclusivament documental, amb identificació separada dels objectes propis de l'app sense equivalent font.

IDParkod és el SKU textual BrandCode + CategoryCode + ProductCode (3+2+3), no l'ID numèric de variant. IDLine és IDBrand + LineCode = BrandCode + LineCode (3+2 amb línia informada), no LineCode sol. Zeros preservats, sense separadors ni conversió numèrica. IDCountry no s'utilitza: producte independent del país, sense afegir filtre equivalent ni assumir claus globals úniques; conflictes de correspondència a revisar sense fusió/selecció arbitrària.

L'exportació revisada té 28 camps i 78.220 SKU únics; no afegeix aquests 28 camps al model. NOM_LIGNE buit en 12 files activa el tractament de nom absent, no una nova nul·litat de LineCode. Les línies buides del mestre LINE no modifiquen el NOT NULL intern. Captures, CSV/XML i scripts no acrediten les metadades SQL desplegades; diagnòstics previs locals disponibles a DATA_MODEL.md §5.5, ubicació/estructura de referència acceptades D229–D232. Permisos del futur compte, integracions i model nou encara pendents. No s'executen scripts ni SQL en aquesta actualització.

**Consolidació documental — 2026-10-22:** acords fins a D228 contrastats amb funcional/model i instruccions, sense canviar les 14 taules, els 98 camps, claus, unitats, cascades o codis permanents. Fonts de proves, noms directes i equivalències actualitzats; traçabilitat dels acords substituïts a DECISIONS.md. No bases creades/modificades, dades i SQL legacy intactes; DDL, signatures restants, permisos, integracions i proves SQL encara pendents. Etapa 0 oberta, sense algoritmes.

### 22.25 Consolidació de l'etapa 0 — 2026-10-23

**D229–D236; estat posterior a la consolidació anterior.** Entorn de proves identificat i destí ja existent sense taules, motor de producció 2017 preservat. Estructura font acceptada, DESIGN1/DESIGN2(18) i code1(13) NOT NULL al diagrama/diccionari, French_CI_AS mantinguda amb excepcions CI_AI ja acordades. 14 taules/98 camps i claus/regles comercials intactes. Conciliació completa nocturna i gestió operativa extraordinària documentades, sense afirmar estabilitat garantida de tots els escriptors externs ni desplegament de senyals/bloquejos.

Diagnòstics previs: 78.220 SKU únics, cap duplicat/format SKU o longitud de línia incorrectes; sense mancances en unions categoria–família. EAN: 588.261 files, 14 referències amb format incorrecte, una fila sense número i 502.035 sense correspondència amb PARKOD actual. Comptes puntuals potencialment superposats, no vigència/historial ni autorització per corregir EAN o retirar SKU; lectures sense SNAPSHOT conjunt. Dades humanament validades i proves de domini encara pendents.

Estat d'aquella consolidació: noms A/B, interpretació de NULL del principal i gramàtica ValuesJson validats, resta de signatures aleshores proposada; posteriorment confirmada per D237. Recuperació manual definida després per D238. DDL, permisos/controls executables, materialització de recuperació/integracions i proves de concurrència/compatibilitat amb 2017 pendents abans de tancar etapa 0. Només documents locals actualitzats; cap SQL executat, base/configuració/dada/script font modificats ni algoritmes desenvolupats.

### 22.26 Consolidació de contractes de l'etapa 0 — 2026-10-25

**D237–D240:** signatures completes A → B aprovades, recuperació manual de resultat incert només per administradors, entrada de valor existent/nou i resposta de confirmació de candidata en dos conjunts. NewValueJson reutilitza expressament gramàtica D236; cap canvi a code1, als originals històrics o a les 14 taules/98 camps/claus/tipus físics. La proposta intermèdia de comprovació automàtica està substituïda, no vigent.

Reversions pels circuits ordinaris i tasques Windows en seqüència recàrrega → conciliació ja eren acords, no decisions a tornar a validar. Altres noms/signatures/contextos no coberts, consulta administrativa de recuperació, DDL, permisos, integracions i proves humanament validades continuen pendents; no s'aproven per extrapolació ni es dona l'etapa 0 per acabada. Cap SQL, font, dada/configuració o script legacy modificats en aquesta actualització documental.

### 22.27 Contractes de candidates existents — 2026-10-27

**D241–D247, signatures canòniques a DATA_MODEL.md §6.15.** Sis procediments de disseny a VARIANTS_PARKOD.dbo, no implementats ni desplegats:

| Procediment | Abast i resposta confirmats |
|---|---|
| dbo.ConfirmVariantValueProposal | Acceptar/corregir candidata SKU–valor pendent persistent; dos conjunts D240 post-COMMIT. No rebuig ni proposta nova sobre assignació validada. |
| dbo.GetVariantValueProposalContext | Lectura de candidata i valor original sempre inclosos, més seleccionat existent compatible si informat; una fila ContextJson. |
| dbo.RejectVariantValueProposal | Rebutjar candidata SKU–valor IsValidated=0 amb original disponible, auditar/eliminar només candidata atòmicament; una fila OperationId post-COMMIT. |
| dbo.ApproveGroupVariantTypeProposal | Acceptar candidata grup–tipus tal com proposada, sense canviar tipus: IsValidated=1/codi NULL, risc/originals conservats; una fila OperationId + associació completa post-COMMIT. |
| dbo.GetGroupVariantTypeProposalContext | Lectura del context grup–tipus de quatre blocs exactes; una fila ContextJson. |
| dbo.RejectGroupVariantTypeProposal | Només candidata 0/codi NULL/sense assignacions/original disponible; auditoria i eliminació només d'associació atòmiques; una fila OperationId post-COMMIT. |

Sessió, context revisat i controls existents de permisos/reserva verificats; canvis rellevants exigeixen nova revisió sense eliminació ni rebuig fictici. Originals/risc autoritatius de la fila SQL, no imposats per formulari. Els dos lectors utilitzen SNAPSHOT curt només a VARIANTS_PARKOD, tancat abans de revisar, sense modificar dades, crear catàlegs, reservar codis ni auditoria de lectura. Confirmacions/rebutjos treballen en nova transacció sobre estat actual; resultat incert segons D238, manual només admin i sense reenviament automàtic.

Defaults NULL de confirmació SKU validats: exactament una via existent/nova, tots dos NULL invàlids. En canvi, NULL al lector SKU significa «sense seleccionat existent addicional», mai excloure l'original; el valor nou desitjat continua separat al backend. No barrejar els dos significats ni interpretar NULL com una acceptació implícita.

**Context SKU–valor:** propietat Parkod amb exactament CLIGNE/SourceIsPresent de la còpia confirmada D243, per coherència de línia i situació de presència revisada. No nova font/camp, reclassificació silenciosa o prohibició nova de corregir retirats. En aquest tall D247, la resta encara era proposta: posteriorment confirmada íntegrament per D248 a DATA_MODEL.md §6.15.3, no retroactivament per l'acord sobre Parkod.

**Context grup–tipus íntegrament confirmat D246:** ProductGroupVariantType, ProductGroup i VariantType complets; ProductVariants array de tots els membres reals amb ID/codis SKU/grup/LineCode/IsValidated i Parkod:{CLIGNE, SourceIsPresent} de la còpia. Inclou retirats i pertinences pendents, sense duplicats, [] si grup buit; null explícit als camps nullable i originals JSON imbricats. No el context editorial de quatre blocs ni el de substitució.

Aprovar fase 2 no crea valors SKU, assigna codis o modifica el principal; substituir el tipus té el seu circuit. Associació ja aprovada, encara sense codi, no rebutjable com a candidata. Rebuig no elimina SKU, grup, tipus, valors de catàleg o historial. Les signatures no aproven altes conjuntes ni altres circuits per extrapolació: confirmacions posteriors expresses D248–D284 a continuació. 14 taules/98 camps/claus/tipus físics intactes; DDL, altres contractes no coberts, permisos, integracions i proves pendents. Etapa 0 oberta, sense SQL.

### 22.28 Consolidació dels acords posteriors a D247 — 2026-10-28

**D248–D284; tots els noms/signatures són contractes de disseny, no objectes implementats.** Context SKU de set propietats ara íntegrament confirmat D248; vint procediments addicionals (vuit lectors/dotze d'escriptura o auditoria), amb paràmetres comuns de sessió/token i controls SQL vigents. Referències canòniques:

| Circuit | Contractes tècnics | Acords |
|---|---|---|
| Investigació manual de resultat incert | DATA_MODEL.md §6.16 | D249–D252 |
| Finalització individual amb codi/principal | §6.17 | D253–D256 |
| Trasllat ordinari a grup existent | §6.18 | D257–D260 |
| Creació conjunta de grup/associacions/pertinences | §6.19 | D261–D268 |
| Rebutjos no persistents diferenciats | §6.20 | D269–D272 |
| Alta manual múltiple de tipus a grup existent | §6.21 | D273–D275 |
| Revisió/selecció del principal | §6.22 | D276–D277 |
| Correcció/rebuig sobre assignació validada | §6.23 | D278–D282 |
| Primera assignació manual, encara absent | §6.24 | D283–D284 |

Els lectors són SNAPSHOT curts només de VARIANTS_PARKOD, tancats abans de revisar; no lectures originals implícites ni transaccions de formulari. Confirmació/rebuig rellegeix en nova transacció actual amb context contrastat, permisos/reserva i coordinació existents. Respostes capturades dins de l'operació i emeses post-COMMIT; no relectures posteriors. SQL conserva integritat/atomicitat/auditoria, no es traslladen a Python ni es desplega res amb aquesta documentació.

### 22.29 Consulta administrativa manual de resultat incert

dbo.GetUncertainOperationContext només per admin de l'app amb IsAdmin vigent/sessió verificada, també operacions d'altres usuaris; no identitat SQL de bootstrap ni restricció a correccions ordinàries. Dues entrades excloents: OperationId conegut amb resta de filtres NULL, o grup complet/A/B tots informats per substitució sense ID. No camps nous de petició, reenviament o identificació garantida.

Dos conjunts del mateix SNAPSHOT curt: auditoria completa de cada operació trobada i estat actual dels objectes identificables per PK real. En grup/A/B, cercar A **o** B i retornar totes les auditories de les operacions, perquè B pot quedar intacta; no triar automàticament l'última. Segon conjunt TargetScope/ObjectKeyJson/CurrentStateJson amb null explícit si fila absent, més grup/definicions A–B/dues associacions encara sense auditoria. Grup no creat sense ID no s'inventa; claus històriques no es reescriuen, secrets exclosos. No reserva grup ni audita lectura. Absència d'auditoria no prova rollback o fi de petició; estat desitjat observat no prova autoria d'aquella petició.

### 22.30 Fase 2, codi final i principal: operacions diferents

dbo.AddGroupVariantTypes aprova manualment 1+ associacions noves a **un grup existent**, amb tipus de catàleg existents compatibles. Lot no buit/sense duplicats, totes o cap; associació ja existent, també candidata, exigeix revisió, no s'ignora ni s'aprova silenciosament. Cadascuna 1/codi NULL/risc/originals NULL, una auditoria create per fila amb OperationId comú. No nous tipus/valors, codis o principal. Resposta: OperationId, després totes les associacions completes, una per tipus. El lector té quatre propietats; no és el de candidata persistent singular.

dbo.FinalizeGroupVariantType finalitza **una** associació 1/codi NULL amb context de sis propietats i valors requerits validats. Donar un codi nou exigeix almenys un SKU present amb pertinença validada; zero requerits es pot mostrar però bloqueja finalització. No revoca codis anteriors si el grup després queda buit/retirat. Codi nou, principal i auditories atòmics, sense codi reservat durant pantalla ni consum concurrent com a conflicte. Resposta OperationId/codi/principal finals informats.

El principal compta només 1/codi informat, no SKU ni valors; fase 2 no l'altera. dbo.SetProductGroupPrimaryVariantType és selecció expressa independent amb lector de tres propietats: argument obligatori sense default, NULL només amb zero finals, un final obliga aquell ID, diversos exigeixen un final compatible. No confondre aquest NULL amb SelectedPrimary opcional de finalització/substitució, que significa sense nova tria. Només canvia principal, risc/IsValidated intactes. Resposta OperationId+grup complet; mateix principal vàlid després de totes les comprovacions, cap UPDATE/auditoria i OperationId resposta NULL. Lectura permesa per corregir principal invàlid, sense forçar cap selecció arbitrària.

### 22.31 Trasllats, creador i decisions de creació conjunta

Grup origen de trasllat derivat de pertinença real del SKU, destí complet existent; no nou grup o correcció de CLIGNE per aquest contracte. Context de set propietats amb SKU complet/còpia, dos grups amb composicions/associacions, totes les assignacions del SKU i catàlegs. No valors dels altres membres. Manual sense proposta: nous originals/risc d'entrada NULL i risc de pertinença nova NULL, no antic risc ni 0; amb proposta, originals del backend i risc presentat preservats, SQL determina accepted/corrected. Dades/rèpliques/auditories atòmiques i dos conjunts de resposta: OperationId+SKU complet, després assignacions completes; buit no omès.

Creació conjunta: @CreatorProductVariantId explícit, seleccionat i aprovat, sense triar el primer d'array o mínim ID. Herència de marca/categoria/línia i fonts del nom segons el creador, sense columna ni nova propietat d'original. @ProductGroupName=NULL demana nom automàtic després de donar número; text manual normalitzat no buit i <=150, sense afegir número. Fallback compacte només automàtic, nul·litat física/edició posterior intactes; integració fiable de lectures de noms font encara pendent, no SNAPSHOT original.

Context de cinc propietats amb seleccionats complets i grups actuals/composicions reduïdes/associacions, assignacions seleccionades i catàlegs. Els seleccionats poden venir de grups provisionals o comercials diferents: no equivalència ni fusió de grups sencers. Repetició del SKU complet i dins de composició reduïda és solapament JSON, no duplicació SQL. Només els aprovats es traslladen, resta roman i grups buits es conserven; si ja hi ha grup correcte, es pot fer trasllat a existent en lloc de crear-ne un altre.

Arrays separats d'aprovació d'associacions i decisions approve/reject per SKU, cadascun amb originals/risc propis. Manual sense proposta exigeix originals/fonts/risc null; approve confirma pertinença amb risc presentat o NULL, reject necessita original i conserva estat anterior. Almenys un aprovat i creador entre ells; no alta buida. Tipus necessaris per conservar assignacions aprovades explícitament inclosos, no herència o rebuig per omissió. No convertir un esborrany descartat en rebuig humà.

Grup nou validat, associacions aprovades sense codi, trasllats i rebutjos explícits en transacció curta/OperationId comú. Originals finals dels arguments només del grup, mai propagats a membres/tipus. Quatre conjunts: OperationId+grup, SKU traslladats, associacions creades, assignacions preservades. N tipus → N files del tercer conjunt; zero només si no es necessiten per valors conservats. Rebutjats auditats però no retornats com a SKU/assignacions modificats. No catàlegs nous ni finalització implícita: per si sol no fa exportable el grup.

### 22.32 Rebutjar una proposta no és eliminar una classificació vigent

Rebutjos diferenciats de grup no creat, tipus proposat per grup nou, pertinença a grup nou i proposta de trasllat a existent (§6.20). Originals nous del backend i context revisat, una auditoria rejected sense canvi de negoci/snapshots/resultat, resposta només OperationId post-COMMIT. Rebuig de tipus conserva catàleg; si encara necessari, alta posterior de grup bloquejada, no pèrdua de valors. Rebuig del grup no rebutja automàticament membres/tipus. Les claus de pertinença són del grup anterior real, encara que destí de proposta nova sigui JSON null; propostes de grup/tipus no creat tenen les claus especials ja aprovades.

Rebuig de proposta nova sobre assignació validada també conserva fila/risc/validació/originals/catàleg, i clau amb valor actual real. És diferent del rebuig de candidata pendent, que elimina només la candidata admissible amb audit+DELETE atòmics. No desfer operacions, retirar validats o auditar cancel·lacions manuals per aquests procediments.

Conflicte detectat amb rollback: conservar canvis confirmats d'altres persones, log tècnic anglès i nova revisió, no rejected definitiva d'un context no vist. Timeout/connexió perduda no prova rollback: resultat incert de D238, cap reenviament automàtic ni reconstrucció. Èxit d'un procediment de rebuig significa decisió registrada, no aprovació/trasllat/associació de tipus.

### 22.33 Tres estats SKU–valor i possible alta de catàleg

| Estat de ProductVariantValue per SKU–tipus | Circuit confirmat |
|---|---|
| Absent | Primera assignació manual GetNewVariantValueAssignmentContext/ConfirmNewVariantValueAssignment. |
| Candidata pendent IsValidated=0 | Lector/confirmació/rebuig de candidata §6.15. |
| Assignació validada IsValidated=1 | Lector/correcció/rebuig de proposta nova §6.23. |

No és un upsert: si s'esperava absència i apareix fila, nova revisió, no correcció silenciosa. Context de set propietats explícitament reutilitzat amb absència ProductVariantValue JSON null obligatori i VariantTypeValues només seleccionat o []; amb validada, valor actual sempre inclòs i seleccionat addicional compatible opcional. No modifica nul·litat/PK/FK SQL ni crea IDs ficticis, ni exigeix codi final per preparar valors. Sense nova prohibició de revisar retirats.

En primera assignació i correcció es pot seleccionar valor existent o aportar NewValueJson per crear-lo **en aquella mateixa confirmació**, no a priori. Type i associació aprovada han d'existir. Alta de catàleg amb ID real + alta/correcció d'assignació + auditories atòmiques; compartit anterior conservat, cancel·lació no crea files. Dues vies XOR obligatòries malgrat defaults NULL, gramàtica decimal D236/D239 expressament reutilitzada, sense exponents/arrodoniment/conversions o extrapolació a code1/TextValue/història. Duplicat concurrent exigeix revisar i seleccionar ID existent, no reutilització silenciosa.

Primera alta manual: assignació 1/risc/originals NULL, confirmed_change/create, Before SQL NULL/After complet; clau amb valor anterior JSON null només perquè no existia fila, fila creada amb FK real. Sempre alta/OperationId informat i dos conjunts d'una fila (OperationId+assignació; valor final existent/nou), capturats internament/post-COMMIT. Correcció sobre validada té els mateixos dos conjunts expressament aprovats, amb l'excepció de no-op manual descrita a continuació. Ni grups/tipus/codis/principal nous ni finalització automàtica de fase 3.

### 22.34 Risc, originals i decisions sense canvi de valor

Quan una correcció efectiva canvia el valor: amb proposta nova acceptada/corregida, la fila rep risc/originals nous del backend; manual sense proposta, aquests tres camps SQL NULL. IsValidated=1, estat anterior complet amb antics originals a Before, història intacta. No utilitzar JSON antics de la fila com a originals d'una proposta nova ni reescriure els nous amb correccions/IDs generats.

Mateix ID final actual després de totes les comprovacions: manual sense proposta deixa fila/risc/originals intactes, sense UPDATE/auditoria, OperationId de resposta NULL. Nova proposta expressament revisada també deixa fila intacta però registra accepted/corrected amb originals/risc nous i resultat real a auditoria, snapshots SQL NULL i OperationId informat. És una decisió nova, no lectura rutinària d'un SKU intacte; snapshots NULL no volen dir fila absent ni amplien l'excepció password_reset de confirmed_change. NewValueJson duplicant un valor no es transforma en no-op: conflicte/revisió.

### 22.35 Revisió D240–D247 i límits de la consolidació

D240 i sis signatures de candidates contrastats amb conversa/diccionari: dos conjunts de candidata, defaults/ordre/tipus, quatre blocs grup–tipus i rebuig D247 intactes. D247 revisat inclòs amb aclariment d'error tècnic versus resultat incert. El context SKU complet es confirma per D248, no per reescriure l'aprovació parcial de D243. Noves entrades/respostes aplicades expressament als circuits respectius, no generalització automàtica a tots els casos.

14 taules/98 camps, claus i definicions físiques preservats; SQL Server 2017/French_CI_AS i frontera de no-intervenció intactes. **En el tall D284**, tipus nous sense IDs, contracte conjunt de rebuig sense membres aprovats i altres operacions no cobertes continuaven pendents; D285–D293 concreten després només els casos de §22.36–22.37. Comparadors, recursos de bloqueig, permisos, lectures de noms/integracions, DDL i proves humanament validades segueixen pendents. No codi, SQL o fonts/configuracions canviats; etapa 0 oberta. Dates de consolidació, no de cada confirmació ni autorització de desplegament.

### 22.36 Rebuig conjunt de propostes d'un grup nou

**D285–D289; DATA_MODEL.md §6.25.** Una mateixa confirmació pot registrar només els rebutjos expressament marcats del grup nou, de pertinences i/o d'associacions proposades. Originals/fonts/risc independents per decisió, una auditoria rejected per decisió amb mateix OperationId, tot o res; cap canvi de classificacions vigents, catàlegs, comptadors o codis. Rebutjar grup no rebutja automàticament els fills, ometre no és rebutjar, i descartar esborrany manual no s'audita com a rejected.

RejectProductGroupCreationProposals rep context revisat, arrays de rebutjos de pertinença/tipus i objecte opcional de rebuig de grup. Arrays [] admesos, però almenys una decisió conjunta. Original objecte no nul obligatori, fonts array/null i risc exacte 0–100/null, IDs reals/ProductGroupId proposat null. No camp Decision perquè totes les entrades són rebutjos. Resposta només OperationId informat post-COMMIT, sense canvis parcials davant de conflicte detectat; incert segons D238.

GetProductGroupCreationRejectionContext deriva el context de cinc propietats de la unió dels membres originals implicats, no una selecció corregida més petita: SKU complets/còpia local, grups actuals amb membres/associacions, assignacions i catàlegs. Un sol SNAPSHOT curt només nova base, sense creador aprovat o acceptabilitat per crear: es rebutja. Fila requerida absent dona error, no context parcial. Els rebutjos individuals continuen existint; diverses crides independents no comparteixen OperationId automàticament.

### 22.37 Correcció de candidata A amb tipus B nou o existent

**D290–D293; DATA_MODEL.md §6.26.** Només A candidata existent 0/codi NULL/sense assignacions al grup/original disponible. Substitució expressa, no retirada d'un tipus aprovat ni inferència perquè coexisteixin tipus complementaris. Amb assignacions d'A, usar el circuit complet §22.19/§6.11 del model: preparar B conservant A i revisar retirades individuals, sense conversió/còpia d'aprovacions.

**Garantia aclarida amb l'usuari:** si qualsevol SKU del ProductGroup revisat té assignació a A, encara pendent o retirat, aquesta correcció no és admissible. No s'elimina ni trasllada cap assignació per fer-la possible. Error amb rollback conegut conserva totes les assignacions a A, incloses les del grup revisat, A/B/catàlegs/historial sense canvis d'aquest intent. No rejected humana fictícia ni rollback presumptiu davant d'una connexió perduda; COMMIT aliens/anteriors preservats. Assignacions d'A en altres grups no s'alteren per corregir una associació admissible.

- **B nou:** NewVariantTypeJson amb exactament Type/Characteristics/ValueKind/BrandCode, sense ID/risc/validació/codi/valors inicials. Preparació només en memòria; normalització/unicitat vigents, col·lisió exigeix revisió. CorrectGroupVariantTypeProposalWithNewType crea tipus/associació B 1/codi NULL, elimina només associació A i conserva risc/originals d'A a B, amb auditories D177 atòmiques. Reutilitza expressament els quatre blocs del lector D246, definició nova separada; no catàleg A/usos eliminats.
- **B existent:** CorrectGroupVariantTypeProposalWithExistingType crea associació B si absent, aprova candidata B després de revisió dels seus originals D179 o conserva B ja aprovada completament intacta/sense auditoria fictícia. Originals no barrejats. Context confirmat de cinc propietats: ProductGroup, ProductVariants, VariantTypes, GroupVariantTypeToReplace, ReplacementGroupVariantType. Associació B absent JSON null, B pendent fila completa, no absència del tipus B de catàleg.

Cap valor SKU, codi nou o principal modificat pels dos correctors. Tots dos retornen dos conjunts d'una fila capturats dins de l'operació/post-COMMIT: OperationId+associació B completa, després VariantType B complet nou/existent. Signatures confirmades de disseny, no SQL. **GetGroupVariantTypeProposalCorrectionContext confirmat després per D294:** D293 n'aprovava només el context; D294 confirma expressament nom/signatura/resposta sense canviar la proposta. Una fila ContextJson de cinc blocs, SNAPSHOT curt local, cap canvi de negoci o auditoria de lectura; A candidata, no A ja aprovada.

### 22.38 Interfície App–SQL i abast de les confirmacions

El capítol 8 de DATA_MODEL.md, «Interficie  App - motor SQL», preserva lectura/revisió/confirmació en transaccions curtes, captura interna i resposta post-COMMIT, tres fases/quatre validacions/valor compartit. Inventari de **76 procediments de disseny**, NormalizeWhitespace separada. Únic canvi d'arguments després de D370: JSON obligatori de Complete segons D373; 75 altres signatures i respostes intactes. Altres controls afectats per còpia externa pendents §6.40. Signatura no és implementació/signatura digital ni aprovació d'altres circuits. IsActive/G9/R5/història immutable, sense nous camps físics.

AppSessionId identifica sessió funcional, no transacció/connexió/RDS ni prova d'autenticació per si sol. SessionToken de 32 bytes només en memòria; SQL valida longitud abans de convertir i desa/comprova només SHA-256 a SessionTokenHash. OperationId generat per SQL agrupa auditories d'una operació atòmica, no tota la sessió/batch ni un identificador d'idempotència del client. No secrets als contextos/logs/auditoria; no-op amb OperationId de resposta NULL només on està expressament autoritzat, sense fila d'auditoria amb UUID NULL.

Cada COMMIT confirma la seva operació curta de dades/auditoria, no la pantalla ni el lliurament de la resposta. Cap transacció durant formularis/Argon2id; un COMMIT anterior/aliè no es desfà per error posterior, batch interromput no té rollback global presumptiu. Resposta capturada dins de l'operació i emesa post-COMMIT, pèrdua de connexió/resultat incomplet incert segons D238. Recuperació administrativa manual dins del seu abast, no fallback A/B extrapolat a tots els correctors ni restauració de snapshots. Etapa 0 oberta, cap codi/SQL executable/configuració/dada font modificada.

### 22.39 Substitució d'A aprovada sense codi per B candidata de fase 2

**D295–D296; DATA_MODEL.md §6.27.** Concreta D180, no una regla nova de retirada: mateix grup existent, tipus A/B reals diferents/compatibles, A associació 1/codi NULL i B candidata 0/codi NULL amb original. Totes dues sense assignacions SKU al grup, també pendents o de retirats. Els valors de catàleg no assignats i usos en altres grups poden existir i es conserven. B absent/null/ja aprovada no entra en aquest circuit; no s'amplia el corrector de candidata A ni s'aplica la transició final amb codi.

GetGroupVariantTypePhase2ReplacementContext retorna una fila ContextJson de cinc propietats amb forma D293 però estats obligatoris diferents: ProductGroup, ProductVariants, VariantTypes, GroupVariantTypeToReplace i ReplacementGroupVariantType. A aprovada/B candidata en files completes, B no null; membres retirats/pendents i còpia local inclosos. Sessió/permisos/reserva, codis 3/2 abans de convertir i SNAPSHOT curt només nova base, tancat abans de revisar. Llegir no retira A ni aprova B, ni audita lectura.

ConfirmGroupVariantTypePhase2Replacement contrasta context en nova transacció curta; retira només associació A amb confirmed_change/retire, Before complet/After NULL, conservant l'aprovació històrica. Aprova explícitament B amb la decisió dels seus originals, mantenint risc/originals propis i codi NULL, sense copiar els d'A. Dues auditories/OperationId comú, dades/auditories atòmiques. Si apareixen assignacions o canvia context rellevant, rollback conegut conserva A/B/SKU/historial d'aquest intent, no rejected fictícia; COMMIT anteriors/aliens intactes i connexió incerta segons D238.

Resposta en dos conjunts d'una fila capturats dins de l'operació i emesos post-COMMIT: OperationId+associació B completa, després VariantType B complet existent. Sense catàleg nou, assignacions/pertinences SKU, codis o principal modificats. No finalitza fase 3 ni fa el grup exportable per si sol; aprovació tècnica de B encara sense codi. Explicació i signatures confirmades, no implementació ni autorització de DDL.

### 22.40 Cicle de sessió i comptes — D297–D313

Contractes complets a DATA_MODEL.md §6.28–6.29, sense servei central o model de confiança nous. CloseAppSession tanca només sessió/token vigents i allibera reserva, no Windows/RDS o decisions confirmades. RenewAppSession només interacció real i hora SQL, no heartbeat o renaixement. ReserveProductGroup només grup existent actiu/disponible, mateixa reserva conserva, altre grup requereix release explícit i reserva aliena error. ReleaseProductGroup allibera coincidència o conserva absència, altre grup error; no logout, la sessió encara exclou conciliació. Reserva/alliberament són lògics, cap transacció durant pantalla.

Administrador de l'app pot llistar altres sessions vigents amb GetAppSessionsForForcedClosure, revisar-ne una amb GetAppSessionForcedClosureContext (AppAccount quatre camps/AppSession sis sense hashes) i confirmar ForceCloseAppSession. IsAdmin actual, destinatària vigent/diferent de pròpia, context actual contrastat; eliminació/reserva i una auditoria app_session confirmed_change/retire atòmiques, Before sessió sense hash/After NULL. Resposta OperationId/AppSessionId afectada post-COMMIT, sense contrasenyes canviades o reserva transferida. Finestra pot seguir visible; següent crida detecta revocació i descarta edicions manuals, no candidates persistents.

**D305:** incidències d'aquest tancament forçat s'investiguen fora de l'app amb SQL administratiu autoritzat. No ampliació de GetUncertainOperationContext o lector nou de recuperació; resta de recuperació ja aprovada intacta. Avís/no reenviament/rollback no presumit. Idea de tancar totes les sessions/verificar inconsistències no és un procediment nou de manteniment o reparació autoritzat.

GetAppAccounts retorna els quatre camps auditables de tots els comptes, sense hashes; CreateAppAccount crea amb nom normalitzat únic també entre inactius/hash Argon2id extern/flags explícits, auditoria create i cap sessió automàtica. SetAppAccountAccess reutilitza la fila revisada, només flags amb protecció atòmica d'últim admin i autoedició admesa; desactivar no expulsa, retirar IsAdmin és immediat. No-op exacte després de controls sense UPDATE/auditoria/UUID.

ResetAppAccountPassword només admin, també propi; context quatre camps, no hash al context. Hash nou/revocació de sessió-reserva/password_reset atòmics, fins i tot hash igual, flags/nom/negoci intactes. Propi admin ha de tornar a entrar. Dos restabliments admissibles serialitzats, cadascun auditat, últim hash confirmat vigent; no idempotència o reenviament. Única auditoria password_reset amb snapshots NULL i cap secret/app_session extra. BootstrapAppAccount només SQL admin autoritzat/AppAccount buit, crea primer compte 1/1 i audita process/bootstrap. RecoverAppAdministratorPassword només SQL admin/admin existent, no compte/sessió nous ni canvi IsActive/IsAdmin, process/admin_recovery; no reactiva admin desactivat. Sense contrasenya predeterminada o compte permanent de reserva.

### 22.41 Abast de marca i ValueKind — D314–D317

DATA_MODEL.md §6.30 concreta la via D142 sense reobrir-la. GetVariantTypeBrandScopeChangeContext i ChangeVariantTypeBrandScope són SQL administratius fora GUI, no permisos ordinaris d'IsAdmin. Lector de quatre blocs editorials complets, una columna ContextJson, no canvi/reserva/auditoria; canvi amb assignacions exigeix impacte/autorització i context actual. NewBrandCode NULL és global; informat, CMARQ de tres caràcters i totes les associacions compatibles, també dels grups inactius. Només BrandCode/audit update process/variant_type_brand_scope_change, no eliminacions/codis/validacions/originals forçats.

SetUnassignedVariantTypeBrandScope és ordinari de tècnic, cap assignació pendent/validada/retirada enlloc, valors de catàleg no assignats no bloquegen marca. Context editorial quatre blocs, compatibilitat total; assignació apareguda exigeix revisió, no salt a excepcional. SetVariantTypeValueKind ordinari reutilitza quatre blocs, numeric/text/open_type textual: canvi només sense valors de catàleg ni cap associació IsValidated=1, també inactiva/fase 2 sense codi. No conversió/eliminació/desvalidació/default/collation o excepció D142. No-op coincident validat de ValueKind admès encara amb usos; no UPDATE/auditoria/UUID. Canvis efectius auditats/UUID i tipus complet post-COMMIT, sense afectar grups o SKU intactes.

### 22.42 Normalització interna i nom descriptiu — D318–D320

NormalizeWhitespace és funció interna NVARCHAR(MAX) → NVARCHAR(MAX), NULL conserva NULL, comportament Unicode White_Space/D48 intacte. No procediment GUI, camps d'aplicació nous, truncament o buit→NULL; límits/buit/unicitat es validen després. Signatura a DATA_MODEL.md §6.31, implementació/proves pendents.

SetProductGroupName (§6.32) reutilitza exactament només el bloc ProductGroup complet de D276, ara nou camps. Tècnic/sessió/token, grup existent actiu i reserves respectades; només nom normalitzat <=150/no buit informat, repetible/sense número afegit. **NULL deixa sense nom**, diferent de NULL en creació que demana generació automàtica. No consulta fonts, reagrupa, aprova o modifica risc/IsValidated/principal/tipus/valors/codis. Un grup provisional continua provisional i un validat validat. Una update amb Before/After complets i UUID; resposta UUID+grup, captura interna/post-COMMIT. Mateix nom exacte normalitzat no-op sense UPDATE/auditoria/UUID; case/accents sí són canvi.

### 22.43 Grups buits i desactivació administrativa — D321–D325

**ProductGroup.IsActive BIT NOT NULL DEFAULT(1)** és únic camp físic nou. No és IsValidated ni ocupació: quedar buit no modifica validació/risc. En destí buit, N SKU vàlids nous acceptats originen N variants/N grups propis provisionals actius, no N grups comercials aprovats. No recreació per conciliacions repetides o alta per files rebutjades. Reagrupacions posteriors poden deixar grups buits, conservats físicament; cost de fila/índexs/dependències dins d'Express, sense bloqueig SQL permanent pel fet de ser buits. No consumeixen codi només per existir, però codis anteriors es conserven.

Administrador de l'app amb IsAdmin vigent pot desactivar grups actius **només sense cap ProductVariant assignada**, incloses retirades/pendents, i sense reserva de sessió vigent també pròpia. No alliberar/expulsar/moure/esborrar automàticament per aconseguir-ho. Abasts per marca, marca–categoria o totalitat; categoria sola/codis buits invàlids. L'operació és lògica, no DELETE, no recupera espai de dades o recicla IDs/codis. Conserva IsValidated/risc/principal/associacions/història i controls d'integritat. No reactivació automàtica ni contracte de reactivació aprovat.

GetEmptyProductGroupDeactivationCandidates retorna G9 d'actius buits més HasActiveReservation calculat (no camp físic), inclosos reservats per mostrar el motiu. Després de revisar, DeactivateEmptyProductGroup actua per grup amb context G9/estat actual, un UPDATE IsActive 1→0 i audit update atòmics. Cinc resultats: deactivated, not_empty, reserved, already_inactive, context_changed; només deactivated informa OperationId/audita. Prioritat D330 després de controls/estructura/existència: ja inactiu → context canviat → té SKU → reservat → desactivat. No atribuir canvi aliè o error tècnic a un resultat controlat fictici.

Lot amb transacció curta per grup, conjunt revisat no ampliat, controlats continuen i error no controlat/incertesa aturen sense reenviament. COMMIT previs conservats/no UUID global/rollback global/heartbeat o expulsió de tots els tècnics. Resum distingeix resultats coneguts, no processats i incerts; no és conciliació batch, segueix exclusió batch/sessions. Auditoria de cada grup: Before/After nou camps 1/0, After no NULL, altres camps intactes; no auditar skips o fills intactes.

GetInactiveProductGroups consulta administrativa/històrica IsActive=0, mateixos tres abasts/G9 sense filtre IsValidated, cap mutació/activació/auditoria/UUID. No un selector normal amb opció que activi el tècnic, ni prova d'autoria d'una petició incerta. Contractes exactes a DATA_MODEL.md §6.33.

### 22.44 Cinc blocs d'adaptació transversal — D326–D330

Matriu completa dels **65 procediments** a DATA_MODEL.md §6.34.6, inventari de signatures §8.8. No nous paràmetres ordinaris IsActive o canvis de PK/FK/rèpliques/altres camps. IsActive només al grup, independent d'AppAccount.IsActive. Context actual complet G9 també als grups imbricats; R5 SKU–valor intacte amb control SQL. Context vell de vuit camps exigeix lectura nova, no assumir 1. Originals/JSON de fonts/snapshots històrics no reescrits; nous snapshots complets G9.

Operativa ordinària només IsActive=1, també per clau coneguda/admin/no-op; no filtre automàtic per tenir SKU o IsValidated=1. Actiu buit operatiu fins a desactivació expressa. Comprovació SQL dins de transacció/coordinació; grup desactivat durant formulari causa error sense canvi/auditoria/activació/redirecció o rejected humana automàtica. Revisió antiga invalidada; candidates persistents conservades no operables i propostes no persistents sense originals reescrits. No traslladar/incorporar a inactiu.

Catàleg: lector editorial retorna ContextJson quatre blocs complets i InactiveProductGroupsJson de presentació, mateix SNAPSHOT. Només claus completes de grups inactius referenciats/úniques/[] real, no cinquè bloc o paràmetre. GUI no mostra usos/enllaços/destinacions inactius; SQL manté compatibilitat BrandCode/bloqueig ValueKind històrics. No amagar tipus/valors compartits. Lector SQL protegit una columna/quatre blocs i editorial de valor tres blocs intactes.

Administració: GetUncertainOperationContext manté vies/permisos, grup inactiu existent com objecte G9/IsActive=0, no NULL; claus inalterades i D305 intacte. Alliberaments/revocacions/password reset i neteja de caducades login/batch no exigeixen grup actiu. Reserva caducada pot seguir físicament fins a neteja, no és vigent. No restaura snapshots o afegeix reactivació.

Concurrència: inactiu sense SKU ni nova reserva vigent, comprovació/canvi coordinats amb incorporacions/trasllats/reserves; ordre global/esperes finites/transaccions curtes, sense locks de formulari/taules deliberats. Conciliació nova/CLIGNE/descoberta/generador usen grups actius sense reactivar, alterar font, exportador, comptador, registre permanent o SynchronizationStatus. Client no inventa IsActive=1/[]/camps per resposta incompleta; mutació incerta no és fals èxit.

**Consolidació documental 2026-10-31:** D297–D330 incorporats després de totes les confirmacions dels cinc blocs. Diagrama/diccionari 14/99, signatures/contextos/flux/funcional/instruccions alineats; la matriu final no afegeix D331. Les notes històriques 14/98 i 44 signatures anteriors són talls passats. Revisió només documental, sense codi/SQL/dades/configuració/font/commit/push; la nova especificació exigeix contrast complet de totes les etapes, però només hi ha disseny d'etapa 0. DDL, permisos, comparadors, integracions, altres contractes no coberts i proves humanament validades continuen pendents.

### 22.45 Validar un grup existent sense reagrupar — D331–D334

GetProductGroupValidationContext i ConfirmProductGroupValidation, signatures exactes al model §6.36. Tècnic ordinari/grup actiu/reserves/context; lector de quatre blocs ProductGroup complet, tots els membres reduïts amb Parkod local, totes les associacions i definicions dels tipus. SNAPSHOT local curt i sense valors/SKU assignats desitjats. El grup pot estar provisional, validat o buit.

Confirmar només IsValidated 0→1, risc/nom/principal/relacions conservats; no membres/tipus/valors aprovats per herència ni exigència de fases 2–3. Grup actiu buit admès amb mateixos controls d'integritat/principal. Una auditoria product_group/update Before/After G9/camps de proposta NULL, resposta OperationId nullable+grup complet post-COMMIT. Revisat ja 1 i tots els controls superats: no UPDATE/auditoria/UUID; canvi concurrent no és no-op amb context antic.

### 22.46 Validar una pertinença sense trasllat — D335–D337

GetGroupMembershipValidationContext/ConfirmGroupMembershipValidation, model §6.37. Una ProductVariant sempre té un únic grup actual: IsValidated=0 vol dir pertinença provisional, no absència de grup; 1 vol dir pertinença aprovada, no classificació/exportació completa. Passar per grups al llarg del temps es conserva a auditoria, no en pertinences actuals múltiples.

Grup derivat del SKU/actiu; grup encara provisional i SKU retirat admesos. Context cinc blocs: ProductVariant complet i els quatre del lector de grup, sense assignacions/valors, objecte un cop entre membres. Confirmació només flag/risc antic conservat, cap trasllat, línia o altre àmbit aprovats. Una group_membership/update amb grup actual real, snapshots vuit camps/actor verificat/camps de proposta NULL, resposta OperationId nullable+SKU complet post-COMMIT. No-op només amb revisió ja validada/control complet; context canviat exigeix revisió.

### 22.47 Dues vies de correcció tècnica de línia — D338–D347, actualitzades D363

La càrrega externa ha canviat CLIGNE de còpia; ProductVariant conserva línia/grup/decisions fins a revisió. L'app només revalida **la còpia local**, no CLIGNE original ni les dades d'un client com a línia arbitrària. Si canvia context, error sense canvi/auditoria d'aquell intent, no reenvio o rejected humana fictícia. No no-op: cal correcció efectiva, no trasllat ordinari dissimulat.

- **Destí existent:** GetVariantLineCorrectionToExistingGroupContext/ConfirmVariantLineCorrectionToExistingGroup, model §6.38.2–6.38.3. Mateixa marca/categoria, grup actiu de nova línia i pertinença comercial confirmada. Habilitacions necessàries ja preparades/compatibles; si falten, bloqueig sense crear-les o perdre assignacions. Nova pertinença IsValidated=1/risc NULL; grups/principals/codis intactes. Tres conjunts: OperationId+SKU, totes les assignacions, còpia completa només llegida.
- **Grup propi nou:** GetVariantLineCorrectionToNewGroupContext/ConfirmVariantLineCorrectionToNewGroup, model §6.38.4–6.38.5. Únic SKU explícit també creador; grup nou actiu/validat/risc NULL/línia final i principal NULL. Array d'aprovacions exactament tipus de les assignacions del SKU, [] si cap, cap extra/duplicat. Associacions aprovades expressament 1/codi/risc/originals NULL, no herència de l'origen. Nom NULL genera inicial/manual normalitzat no buit<=150/sense unicitat/sufix. Cinc conjunts: grup+UUID, SKU, associacions creades, assignacions, còpia llegida.

En ambdues vies SourceIsPresent intacte també 0, altres validacions/riscs/originals/IDs/valors conservats i rèpliques de grup actualitzades atòmicament. Audit group_membership/update i cada assignació modificada, més create de grup/associacions al nou. **Sense audit parkod_copy dins del corrector**, perquè l'app no l'escriu; no es reescriu auditoria antiga. No codi nou, fase 3 o exportabilitat implícits. Captura interna/post-COMMIT, incertesa D238.

Les signatures/payloads/conjunts estaven confirmats; els contextos originals de vuit/set blocs incloïen SourceParkod original. D363 el retira: **set/sis blocs locals vigents**, adaptació directa de D343/D346/D363, sense SourceParkod fictici, destí null o ID futur. No cal nova aprovació; la marca anterior de pendent era excessiva i es corregeix amb traçabilitat, no una decisió nova numerada. Mateix SNAPSHOT curt local/formes aprovades, originals històrics intactes. D369 resol la correcció de valor amb desajust (§22.52); resta de mutadors, concurrència i noms automàtics a contrastar.

Crear grup comercial amb molts SKU compatibles segueix disponible a §22.31/model §6.19, amb creador/aprovació per SKU i un OperationId conjunt. Mateixa línia no prova equivalència comercial; aquest corrector d'un únic SKU no limita aquella agrupació conjunta. Trasllat massiu atòmic a grup existent requeriria contracte nou, no aprovat aquí. No excepció de caixes/kit a les restriccions actuals.

### 22.48 Balanç mínim i història — D348–D352

Història preservada a còpia i variants. No comparar tot l'històric amb només flux recent ni eliminar per quadrar totals. Llegits=Nous+Actualitzats+Intactes+Rebutjats/pendents, categories exclusives, altes només amb COMMIT; la suma no prova lectura completa. SourceIsPresent=0 és absència contrastada externament, no antiguitat; antic SKU encara a font és present. Absències globals fiables amb càrrega completa i reaparició són contracte extern (D379), mai incremental com a prova de retirada. La conciliació per marques no determina presència.

Reaparició amb canvi de línia: l'extern publica presència i CLIGNE actual, app manté classificació anterior i deixa pendent tècnic sense nou ID/grup automàtic; última classificació validada pot seguir elegible si resta de controls superats. L'antiga conservació de CLIGNE a còpia i audit del canvi de presència per l'app queden substituïts. Origen global buit amb SKU encara presents no causa retirades massives automàtiques; protecció és externa, sense llindars nous/override automàtic.

**Balanç vigent D371–D373:** còpia estable durant conciliació, sense créixer per altes de variant; Variants_final=variants_inicial+Nous es manté. Desigualtat inicial normal per noves còpies. Al final, cada SKU de còpia de l'abast té variant o incidència d'admissió individual d'aquella execució; SQL contrasta totes les claus sense variant amb el JSON de tancament (§22.53/model §6.39.6–6.39.7). No igualtat incondicional de totals, DELETE o variants invàlides per quadrar-los. Rebutjats/pendents també inclouen SKU amb variant: no equivalen a la diferència. Transicions de presència no inferides de l'estat actual; continuen externes. Resum/log i dades JSON transitòries, no taules/camps/versions nous o SQL executable.

### 22.49 Entrada i cicle de conciliació — D353–D359

Model §6.39, signatures completes/inventari §8.8.25. BrandCodesJson SQL NULL=completa, array no buit de marques textuals 3 A–Z/0–9=parcial, zeros preservats/sense duplicats/ordre conjunt; []/buit/JSON null/objecte incorrecte error, mai completa implícita. Marca històrica sense files actuals admesa, cap filtre de país/categoria/línia nou. InvocationKind obligatori manual o scheduled, no deducció Windows; manual repeteix sense omissió per dates, no evita garanties. Scheduled només omet completa segons els dos indicadors/dates acordats; parcial no al dia per dates globals.

- **BeginReconciliation:** sessió SQL tècnica dedicada, no AppSession/token d'usuari. Arguments, sessions caducades/netejades, zero sessions vigents, coordinació exclusiva/disponibilitat de còpia; started o not_run_active_session/not_run_other_batch/not_run_up_to_date. Omissions 0/log NOT RUN/globals intactes; inici complet variants0/data anterior, parcial intacta. No auditoria/OperationId.
- **CompleteReconciliation:** mateixa connexió/metadades/bloquejos, recompte/lectura/processament complets. D373 afegeix UnincorporatedSkuIncidentsJson obligatori abans de BrandCodesJson opcional; SQL comprova conjunt exacte de claus de l'abast sense variant (§22.53). Completa1/data nova SQL, parcial no globals. Resposta completed+quatre recomptes còpia/variant before/after intacta, captura interna/post-COMMIT i després neteja/allibera. Criteri/JSON aprovats, parser/protecció/proves pendents; no antigues fórmules de còpia escrita.
- **FailReconciliation():** sense arguments, mateix inici/connexió/bloquejos, execució incompleta coneguda i cap treball/transacció en curs. Completa0/data anterior, parcial intacta; cap Undo de COMMIT previs. Una fila ResultCode=failed significa tancament correcte d'execució fallida, backend no zero. Context absent/connexió equivocada/ja tancat és error SQL, no failed fictici/no-op. No audit/UUID. Incert de Complete o SMTP després d'èxit no activa Fail; connexió perduda no es reconstrueix.

SESSION_CONTEXT petit aprovat: tipus llançament/completa-parcial/recomptes inicials de l'abast, no secrets/taula/RunId/transacció global. No guardar JSON MAX llarg en valor de 8 KB. **HASH d'abast descartat**: backend conserva conjunt inicial, SQL valida l'abast rebut i pertinència; sense llista inicial a SQL no afirmar igualtat de conjunts entre crides. SHA-256 del token d'AppSession intacte. Dependència SQL Server 2017 a inventari/comentaris anglesos futurs, no implementació o configuració aplicada.

### 22.50 Frontera final, activitats i estat de consolidació — D360–D367

Càrrega externa: únic origen parkod.dbo.PARKOD, destí còpia acumulativa VARIANTS_PARKOD.dbo.Parkod. No programar carregador/integritat periòdica de producció/SourceSkuOccurrenceCount, CSV/intermediaris o recàrrega prèvia de producció per aquest projecte. App només lectura de còpia/SourceIsPresent/CLIGNE actual, classificació conservada fins revisió. Auxiliars de noms/EAN/CATEGORY/FAMILY preservades, no fonts noves o camps addicionals; original intocable.

SourceIsPresent i dos camps Parkod de SynchronizationStatus externs. **Actualització D379 del tall D364:** indicador0 durant càrrega/fallada, 1/data nova només després de càrrega completa correcta de còpia; no càrregues parcials o reparació per marques. Data de publicació de còpia, no recàrrega original, cinc camps intactes. App només dos camps variants segons conciliació completa/parcial. Justificació i contracte vigent a §23.

Mateixa coordinació exclou càrrega i conciliació; connexió dedicada durant cada procés, no transacció llarga/locks de taules, cooperació externa obligatòria. **GUI possible durant càrrega**, però controls de context/confirmació estable quan depenguin d'entrada pendent de concretar. Conciliació amb zero sessions vigents i còpia coherent/disponible, no nous logins mentre dura. No veto global de tota la cadena; tall intermedi D366 substituït. Sessió inactiva 30 minuts configurables caduca lògicament sense logout RDS/finestra obligatori; neteja per demanda/no heartbeat, no bloqueja conciliació si caducada.

Dos `.bat` seqüenciats pel Planificador: primer càrrega externa i després conciliació. No nou planificador intern o vigilància de tots els escriptors nocturns legacy; treball extraordinari gestionat manualment, aturada no presumeix rollback o còpia preparada. D91/D116 continuen comprovant sessions de l'app a l'inici, diferent de vigilar activitat de tots els usuaris Windows/producció.

Consolidació 2026-11-03: D01–D330 històrics preservats, D331–D367 incorporats, 76 signatures de disseny/funció separada, 14/99/tipus/PK/FK intactes. No codi/SQL/font/dades/configuració/commit/push. La nova especificació exigeix contrast complet de les etapes: només disseny d'etapa 0, encara oberta. Formats/guards/cobertura identificats com a pendents no es donen per humanament validats pel fet d'estar documentats.

### 22.51 Visibilitat en iniciar sessió: incidències i validacions — D368/D370

En **cada inici de sessió correcte de l'app**, mostrar al tècnic una llista de tasques o problemes pendents, agrupada per categories. No es limita al log tècnic ni només a correccions de línia. Interfície i missatges en francès; categories funcionals confirmades:

| Categoria | Contingut |
|---|---|
| Incidències tècniques | Inicialment, SKU amb línia carregada diferent de la línia classificada. Altres incidències només amb detecció i tractament definits; no afegir automàticament qualsevol error de log. |
| Treballs pendents de validació | Quatre àmbits diferenciats: grups, pertinences SKU–grup, associacions grup–tipus i assignacions SKU–valor. Mostrar-los junts no fusiona decisions ni hereta aprovacions. |

La discrepància de línia es calcula comparant Parkod.CLIGNE amb ProductVariant.LineCode del mateix SKU, identificat pels tres codis. Llista amb identificació del SKU i les dues línies; no font original, nova columna física o flag de pendent. La classificació variant–grup coherent es conserva i la correcció es fa pels circuits ja acordats. Si desapareix la discrepància, no és un pendent actual, però això no demostra per si sol qui l'ha corregida; només l'auditoria real acredita una operació. Un canvi de valor no fa desaparèixer la discrepància.

La llista mostra situació pendent, no crea reserves, validacions o auditoria de lectura ni obliga a resoldre-la tota abans de treballar. Es mantenen controls d'activitat de grup, permisos/reserves, caducitat i revisió actual quan s'entri al circuit corresponent. Sense assignació personal de tasques, noves taules/camps o historial d'estats de tasca pressupostos. Login dos passos i resposta CreateAppSession intactes; no transacció oberta durant presentació/revisió.

Principi d'aparició a cada login i categories **resolts**, no tornar a validar-los. D374–D378 concreten valors absents/finalització/retirats i avís durant càrrega/fallada a §22.54/model §6.41.4–6.41.5. Assignació absent no és candidata, ni fase 2 aprovada sense codi és pendent d'aprovar. Resta concretar consulta/resposta/elegibilitat restant i protecció de lectures; no signatura SQL nova o GUI desenvolupada fora d'etapa.

### 22.52 Corregir un valor encara que hi hagi línia pendent — D369

Es permet corregir un valor d'un ProductVariant dins del seu grup actual **sense exigir abans resoldre la discrepància de línia**. Un desajust CLIGNE/LineCode present al context revisat no bloqueja per si sol el circuit de correcció de valor del model §6.23, manual o amb proposta segons les regles existents. No aprovació separada de la línia per habilitar aquesta correcció.

No es dispensa cap altre control: sessió/permisos/reserva/grup actiu, classificació variant–grup coherent, habilitació/compatibilitat del tipus, valor vàlid/únic, context actual i atomicitat/auditoria. Si el context rellevant canvia durant la revisió, cal tornar a revisar; no és el mateix que una discrepància ja coneguda. Risc/originals/no-op/UUID/resposta continuen segons el contracte de correcció, sense nous paràmetres o estats.

Corregir el valor no canvia LineCode, grup o còpia, no valida la nova línia i **no tanca el pendent de línia**, que continua a incidències mentre difereixin les dues línies. No s'audita una correcció de línia que no s'ha fet. SourceIsPresent extern i elegibilitat d'exportació intactes. No extrapolar aquesta permissió a totes les altres validacions, altes, trasllats o finalitzacions: contrast separat al model §6.40.

**Tall documental D368–D370 — 2026-11-03:** incorporats aquests acords i corregida l'etiqueta de pendent dels contextos locals 7/6 derivats. 76 signatures/funció i model 14/99 intactes. Aquell tall encara deixava cobertura/format de tancament pendents; resolts en disseny per D371–D373 a continuació, no els controls executables/altres consultes/GUI/proves. Etapa 0 oberta, sense SQL/dades/font/configuració, commit o push.

### 22.53 Cobertura individual i JSON de SKU no incorporats — D371–D373

**Criteri final confirmat:** per a cada SKU de la còpia dins de l'abast de conciliació, hi ha ProductVariant o una incidència d'admissió identificada per aquell SKU durant l'execució. Sense variant i sense explicació individual, no es pot declarar completed; no n'hi ha prou que quadrin sumes globals. Les incidències individuals controlades poden permetre completar amb avisos, però no infraestructura/lectura incompletes o resultat incert disfressats de motiu de rebuig. No DELETE, SKU invàlids o rollback de COMMIT anteriors per igualar recomptes.

CompleteReconciliation rep ara **@UnincorporatedSkuIncidentsJson NVARCHAR(MAX), obligatori sense default, abans de @BrandCodesJson opcional**. Set paràmetres totals; cinc recomptes d'entrada, tipus/default d'abast i resposta original de cinc columnes intactes. És un canvi exprés de la signatura D358, no un procediment nou: inventari 76, altres 75 signatures i NormalizeWhitespace preservades.

Array JSON transitori d'una entrada per SKU sense variant; cada objecte conté **exactament quatre propietats obligatòries**:

| Propietat | Contingut |
|---|---|
| BrandCode | String de 3 caràcters ASCII A–Z/0–9. |
| CategoryCode | String de 2 caràcters ASCII A–Z/0–9. |
| ProductCode | String de 3 caràcters ASCII A–Z/0–9. |
| Reason | String tècnica amb contingut, emesa en anglès pel backend, sense secrets; no catàleg nou de codis d'error. |

Noms exactes, sense propietats desconegudes/duplicades o claus SKU repetides; ordre irrellevant, zeros preservats i codis sense retall/conversió/majúscules automàtics. Reason no pot ser buit ni contenir només blancs; sense truncament/normalització silenciosos. SQL NULL, JSON null, buit, estructura incorrecta o valor de tipus erroni es rebutgen. **[] explícit si cap SKU de l'abast queda sense variant**, no si falta informació; no extrapolar-ho a BrandCodesJson. Sense ProductVariantId inventat. Forma i exemple canònics al model §6.39.7.

SQL contrasta les claus amb l'estat local final coordinat: existents a la còpia, dins l'abast i sense variant; el conjunt ha de coincidir exactament, sense omissions o sobrants. El backend manté les causes al log d'aquella execució. Conjunt de claus, sumes i Reason no certifiquen per si sols la causa declarada, idioma o lectura/processament complets; controls i responsabilitats del cicle preservats. No font original rellegida o còpia escrita, noves taules/camps/HASH/RunId, JSON MAX en SESSION_CONTEXT o auditoria de tancament.

Un pendent de línia amb variant existent no entra a aquest JSON ni justifica una altra absència. Exemple: 100 còpies/98 variants/5 incidències, amb 2 no incorporats i 3 discrepàncies amb variant, exigeixen 2 entrades JSON, no 5. No és un nou recompte físic/de resposta. La llista inicial GUI D368/D370 no s'amplia automàticament amb aquest payload transitori ni es crea una cua persistent d'incidències.

**Consolidació D371–D373 — 2026-11-03:** criteri, canvi de signatura i estructura transitòria exacta documentats; camps físics/tipus/PK/FK/model 14/99 intactes. Parser/comparador/SQL/permisos/concurrència/proves i altres circuits continuen pendents. No implementació, execució SQL, dades/configuració/font, commit o push; etapa 0 oberta.

### 22.54 Tasques, retirats i disponibilitat de la llista — D374–D378

La llista inicial inclou també **valors encara no assignats** a un SKU per a un tipus aprovat al seu grup, diferenciats de candidates ProductVariantValue existents amb IsValidated=0 (D374). Mostrar una absència no crea la fila ni un valor de catàleg, i no inventa IDs: l'alta manual, si es decideix, continua per §6.24 del model. L'assignació candidata es revisa pel circuit de §6.15, no upsert.

Les associacions ProductGroupVariantType amb IsValidated=1 i ParkodVariantCode NULL també apareixen com a **pendents de finalització**, separades de candidates de fase 2 pendents d'aprovar (D375). No codi automàtic o garantia de finalització immediata: D253–D256 conserven valors requerits, almenys un present amb pertinença validada i principal coherent. Grup amb només retirats no obté codi nou.

**D376 — SKU retirats, SourceIsPresent=0:** tot el que ja existeix i es pot validar pels circuits vigents apareix com a tasca i es valida mitjançant decisió humana ordinària. Inclou pertinença pendent admissible i candidata SKU–valor existent. Tot el que encara manca assignar es conserva absent i **no** es mostra com a tasca pendent d'assignar per aquell SKU. No DELETE, ocultació automàtica de candidates existents o prohibició nova d'actuacions manuals permeses. No validació automàtica en mostrar la llista, ni nous flags/taules/estats de tasca.

**D377 — càrrega en curs:** si obtenir la llista requereix consultar VARIANTS_PARKOD.dbo.Parkod, mostrar un avís explícit de **llista temporalment no disponible**. No llista buida interpretada com a «cap feina» ni resultats parcials presentats com a complets. Confirmat inicialment per càrrega total/parcial, després acotat per D379: només càrregues completes externes admeses (§23).

**D378 — càrrega fallida:** mantenir no disponible la llista que depèn de Parkod fins a nova publicació correcta; amb D379, ha de ser una nova càrrega completa verificada. No afirmar càrrega encara en curs quan ha fallat: indicador0 no distingeix aquests dos casos. Missatges externs en francès; formulacions orientatives durant càrrega coneguda i indisponibilitat respectivament: «La liste des tâches est temporairement indisponible : mise à jour des données Parkod en cours.» / «La liste des tâches est temporairement indisponible : les données Parkod ne sont pas disponibles.»

L'avís no bloqueja login o tota l'app, ni altera CreateAppSession, permisos, reserves, auditoria o contextos dels circuits. La consulta de llista és separada de l'autenticació; operacions independents conserven controls existents. No permissió/bloqueig universal de la resta de mutadors amb còpia, cache persistent, refresc automàtic o lector/signatura nous aprovats. La proposta de bloqueig de validació de pertinença SKU–grup per desajust de línia no va obtenir confirmació final; continua pendent, sense modificar D369. Consulta/resposta exactes, altres criteris, mecanismes concurrents i proves encara per concretar al model §6.40–6.41.

## 23. Procés de carrega de VARIANTS_PARKOD.parkod

### 23.1 Finalitat, noms i responsabilitats

**Capítol documental del procés extern, no especificació d'un carregador a desenvolupar dins del projecte.** Reuneix els acords de càrrega i el contracte d'entrada que consumeix Gestionnaire de Variantes. Nom físic complet de la destinació: **VARIANTS_PARKOD.dbo.Parkod**; el títol n'utilitza la forma abreujada demanada, no un esquema o taula nous.

| Procés | Entrada → sortida | Responsabilitat i abast |
|---|---|---|
| Càrrega externa | parkod.dbo.PARKOD → VARIANTS_PARKOD.dbo.Parkod | Externa al projecte; sempre completa, totes les marques (D379). |
| Conciliació de variants | Còpia Parkod → ProductVariant, grups i dades pròpies autoritzades | App; completa o per marques seleccionades, sense modificar la còpia. |
| Correcció humana de línia | CLIGNE local revisada → LineCode/classificació | App, circuits aprovats de §22.47/model §6.38; no carregador o relectura de CLIGNE original. |

L'únic origen del flux de càrrega és parkod.dbo.PARKOD. No CSV, exportació/transferència intermèdia, base intermèdia o recàrrega prèvia de producció exigits. Els fitxers de proves són evidències, no passos obligatoris del procés. Noms auxiliars de PARKOD/CATEGORY, navegació FAMILY i consulta EAN conserven els accessos autoritzats del model §5; no es copien com a part d'aquest procés ni s'amplien les fonts.

El carregador és l'únic propietari de les escriptures dels nou camps de la còpia, SourceIsPresent inclòs, i dels dos senyals Parkod de SynchronizationStatus. L'app només llegeix la còpia, no manté presència, no desenvolupa un escàner periòdic de producció i no repara càrregues. El generador Parkod existent és un altre consumidor, no un exportador nou de l'app.

### 23.2 Contracte de dades de la còpia

Només es copien els vuit camps acordats; el novè és local i mantingut externament:

| Camp | Tipus i nul·litat aprovats | Tractament |
|---|---|---|
| CMARQ | NVARCHAR(3) NOT NULL | Marca, component de la PK; còpia literal. |
| CCATEG | NVARCHAR(2) NOT NULL | Categoria, component de la PK; còpia literal. |
| CPROD | NVARCHAR(3) NOT NULL | Producte, component de la PK; còpia literal. |
| CLIGNE | NVARCHAR(2) NOT NULL | Última línia carregada de la font; pot diferir de la classificació vigent. |
| DESIGN1 | NVARCHAR(18) NOT NULL | Denominació original, sense normalització ni truncament. |
| DESIGN2 | NVARCHAR(18) NULL | Denominació complementària, NULL preservat. |
| code1 | NVARCHAR(13) NOT NULL | Quantitat original textual, sense conversió o reparació; NOT NULL no acredita quantitat vàlida. |
| code2 | NVARCHAR(1) NULL | Unitat original textual, NULL preservat. |
| SourceIsPresent | BIT NOT NULL DEFAULT(1) | Estat de presència determinat exclusivament pel procés extern. |

PK `(CMARQ, CCATEG, CPROD)`. SKU = concatenació textual exacta de 3+2+3 caràcters A–Z/0–9, sense separadors/conversió numèrica, zeros preservats. No és ProductVariantId. CLIGNE no forma part de la FK SKU–còpia; l'app preserva sempre la coherència LineCode entre variant i grup, encara que difereixi de CLIGNE.

French_CI_AS als vuit camps copiats segons el contracte font acceptat; noms, tipus, longituds i nul·litat canònics al model §3.1/§5. No copiar noms de mestres, preus, EAN, país o altres camps. Canvi futur de metadades requereix avís i revisió d'impacte, mai truncament/adaptació silenciosa. code1/code2 es copien literalment: interpretar quantitats/unitats és un tractament separat de l'app, no una conversió durant la càrrega.

### 23.3 Càrrega sempre completa i risc que s'evita — D379

**Tota càrrega externa admesa és completa, per a totes les marques.** Es descarten les càrregues parcials per marques, també com a recuperació després d'una fallada. La selecció de marques es conserva exclusivament per a la conciliació posterior. No nou indicador/estat per marca, versió, HASH o canvi de signatura per substituir aquesta regla.

Motiu confirmat: una càrrega completa pot fallar després d'actualitzar només part de la còpia. Una càrrega posterior reeixida d'una marca no acredita recuperació de la resta; posar llavors ParkodRefreshSucceeded=1 podria donar un **fals senyal de disponibilitat global**. Només una nova càrrega completa verificada i publicada correctament pot tornar a acreditar l'èxit global. D379 substitueix expressament la modalitat parcial de D364, sense esborrar-ne l'historial.

Completa significa abast global de lectura/actualització, **no buidar, esborrar o recrear la taula**, reciclar claus, perdre històric o forçar igualtat entre original/còpia/variants. Tampoc és una garantia automàtica d'atomicitat de tota la càrrega: transaccions i comprovacions externes concretes no es donen per implementades. Llegir totes les marques no basta si hi ha infraestructura incompleta, lectura fallida o publicació no fiable.

### 23.4 Històric, presència, reaparicions i línia

La còpia és acumulativa: referències antigues i actuals conservades, sense DELETE per desaparèixer de l'últim flux. El procés extern estableix SourceIsPresent=1 si el SKU és present i 0 només amb absència contrastada mitjançant lectura global completa i fiable. Antiguitat, rebuig d'admissió a variants, incremental o càrrega fallida no proven retirada. Un SKU observat però rebutjat no es considera desaparegut.

Origen global buit amb SKU encara presents: no retirades massives automàtiques o declaració fictícia d'èxit. Protecció i comprovacions d'integritat/duplicats són responsabilitat externa, no algoritmes nous de l'app. No s'han aprovat llindars, percentatges, override automàtic o SourceSkuOccurrenceCount. La PK de còpia i les FK internes es conserven; no eliminar dades per fer passar els controls.

Una reaparició o actualització publica la CLIGNE actual i presència fiable. **No mou ni desvalida automàticament** ProductVariant, grup, valors o decisions existents, i no crea un segon ID del mateix SKU. CLIGNE és línia d'entrada; ProductVariant.LineCode/ProductGroup.LineCode són classificació vigent fins a revisió humana. El desajust és incidència tècnica calculada, no un flag nou; correccions pels circuits aprovats, sense escriure la còpia. Última classificació validada d'un SKU present pot continuar exportable si supera la resta de controls.

### 23.5 Publicació i SynchronizationStatus

Els cinc camps i tipus de SynchronizationStatus es mantenen; només el procés extern escriu els dos camps Parkod:

| Moment | ParkodRefreshSucceeded | ParkodLastCompletedAtUtc |
|---|---|---|
| Abans de modificar la còpia i durant la càrrega completa | 0 | Data de l'última càrrega completa correcta conservada; pot ser NULL si no n'hi ha cap. |
| Càrrega completa verificada i publicada correctament | 1 | Nova data UTC de final de la càrrega correcta de còpia. |
| Fallada/interrupció sense publicació correcta | 0 | Data anterior conservada; no avançar-la per un intent incomplet. |

L'èxit no es publica només per haver llançat el procés, arribat a l'últim pas o quadrat recomptes. El procés extern ha de comprovar completesa/coherència i publicar els senyals després de final correcte, abans d'alliberar coordinació. La data és de càrrega de **còpia**, no recàrrega original, generació CSV o conciliació. Un valor 0 no permet distingir tot sol càrrega en curs de fallada; no s'afegeix cap estat físic per distingir-les.

No s'assumeix que una interrupció desfaci els COMMIT previs o restitueixi íntegrament l'estat anterior. Mantenir data antiga no acredita una còpia anterior encara coherent. La recuperació confirmada és nova càrrega completa verificada i publicada correctament, no una reparació parcial que marqui 1. L'app no modifica senyals Parkod per superar aquest problema.

VariantsLastCompletedAtUtc/VariantsReconciliationSucceeded corresponen a la conciliació de l'app, no al carregador. Només conciliació completa els actualitza segons el contracte existent; parcial per marques i omissions els deixen intactes. El carregador no els utilitza per declarar una conciliació que no s'ha executat.

### 23.6 Coordinació i límits transaccionals

Càrrega externa i conciliació s'exclouen mitjançant la mateixa coordinació lògica a VARIANTS_PARKOD: obtenir abans de modificar/llegir, mantenir durant cada procés amb connexió dedicada i publicar l'estat abans d'alliberar. La conciliació comprova disponibilitat després d'obtenir la coordinació. Connexió dedicada **no** significa una transacció global oberta tota l'execució, bloqueig deliberat de taules o locks durant l'edició d'un formulari.

El publicador extern ha de cooperar efectivament. sp_getapplock no obliga escriptors no cooperatius ni coordina automàticament l'original. Noms/modes/recursos/permisos i proves encara pendents; aquest capítol no inventa nous bloquejos o procediments SQL. Perdre connexió no autoritza continuar descoordinat, assumir rollback o marcar còpia preparada.

SNAPSHOT aprovat només a VARIANTS_PARKOD, no a parkod; no coherència conjunta entre bases presumpta, NOLOCK o configuració nova de producció. La lectura font coherent, impacte i cooperació externa s'han d'acreditar sense objectes/permisos nous del projecte a l'original.

### 23.7 Seqüència d'execució i conciliació per marques

Dos `.bat` externament orquestrats pel **Planificador de tasques de Windows**, en seqüència i després de final correcte verificat: primer càrrega completa externa, després conciliació de l'app. Pauta habitual nocturna diària, llançament manual possible segons operativa acordada; sense planificador, reintents o servei central dins de l'app. Excepcions nocturnes gestionades manualment, suspenent/aturant tasques; no vigilància nova de tots els escriptors legacy. El calendari no és prova de coherència.

Conciliació completa o d'una/diverses marques amb BrandCodesJson segons §22.49/model §6.39. Entrada ja carregada i estable, app només dades pròpies; no càrrega parcial dissimulada o relectura original. Incorporació inicial de variants per marques conservada, conciliació completa programada desactivada fins acabar-la, però la còpia continua carregant-se completament. D371–D373 exigeixen cobertura individual només dins de l'abast revisat de conciliació; no igualtat indiscriminada de totals o nou criteri de completesa de font.

La càrrega no crea ProductVariant, grups o aprovacions: una fila de còpia encara sense variant és un estat normal abans de conciliar, també fora de les marques inicialment incorporades. Les incidències d'admissió pròpies, com CPROD dins d'un bloc reservat, corresponen a la conciliació: no justifiquen esborrar la còpia o deduir retirada. Logs/correu urgent agrupat i tractament de SMTP són els de §22.13, no un nou control de producció o canvi dels senyals de càrrega. L'èxit de càrrega tampoc acredita conciliació o classificació comercial acabades.

Sessió d'app vigent, també administrativa: la conciliació no arrenca; durant conciliació no nous logins. Omissió per sessió/altre batch, sortida0/log NOT RUN, no èxit fictici. Una càrrega fallida no es converteix en entrada disponible per conciliar, tampoc seleccionant una marca. L'exclusió GUI–conciliació no s'estén a tota la cadena de càrrega externa.

### 23.8 Operativa d'usuari i llista temporalment no disponible

**GUI permesa durant la càrrega**, D367 intacte. Molts contextos normals necessiten CLIGNE/SourceIsPresent de còpia: incidències de línia i criteris de tasques; revisió de valors, grups/pertinences/associacions; trasllats/creacions/substitucions; correcció tècnica de línia i finalització de fase 3. DESIGN1/DESIGN2/code1/code2 continuen sent dades font consultables, no rèpliques addicionals del model propi. Autenticació/gestió de comptes/sessions o edició manual del nom de grup no obtenen un veto nou per aquesta càrrega.

D377–D378: quan obtenir la llista requereixi consultar Parkod durant càrrega o després d'una fallada, mostrar **llista temporalment no disponible**, no «cap tasca» o resultats parcials donats per complets. Després de fallada, mantenir l'avís fins a nova càrrega completa verificada/publicada (D379). No afirmar «en curs» si només es coneix indicador0. Missatges orientatius en francès, segons situació coneguda:

- Càrrega efectivament en curs: «La liste des tâches est temporairement indisponible : mise à jour des données Parkod en cours.»
- Fallada/indisponibilitat sense càrrega vigent acreditada: «La liste des tâches est temporairement indisponible : les données Parkod ne sont pas disponibles.»

Avís separat del login, no revocació de sessió, reserva, decisió/auditoria o bloqueig general d'app. No permet confirmar sobre context rellevant canviat: cada lector/mutador conserva controls, amb mecanismes concurrents encara pendents de prova. D369 permet corregir valor amb discrepància ja revisada, però no ignora canvis concurrents. No política universal nova de tots els mutadors, cache persistent, refresc automàtic o signatura nova del lector de tasques.

El generador Parkod existent continua independent: indicadors0 informatius al seu log, no vetos nous. Lectura inicial coherent de variants en SNAPSHOT curt local; lectures originals separades amb protocol pendent. Aquest avís de GUI no altera elegibilitat comercial o crea un exportador nou.

### 23.9 No-intervenció a producció i estat de les garanties

**Cap escriptura, DDL, manteniment, índex, trigger, vista, sinònim, usuari, concessió de permisos o canvi de configuració a parkod per aquest projecte.** Només lectures controlades/autoritzades amb permisos disponibles i impacte verificat, sense prometre impacte nul. Si la integració exigís modificar l'original, cal redissenyar-la. Configuració aprovada de nova base, compatibilitat 140/French_CI_AS/SNAPSHOT ON/RCSI OFF, encara pendent d'autorització d'aplicació; producció SQL Server 2017 Express/Windows Server 2019 intacta. Proves locals de 2019 no autoritzen dependències exclusives de 2019.

L'app no assumeix integritat provada pel sol indicador, nombre de files o horari nocturn. Controls periòdics de producció, identitat/claus, metadades i publicació fiable són contracte extern; integració/permisos/lectura/impacte/coordinació s'han de provar. Càrrega global pot durar més i compartir recursos CPU/memòria/disc: mesurar-ne impacte, sense llindars o límits nous aprovats. Express manté límit de 10 GB de dades per base.

### 23.10 Traçabilitat i pendents

Referències: D230–D233 (contracte/entorn/seqüència), D348/D351–D352 (històric/presència/protecció), D360–D365/D367 (frontera/propietat/coordinació/GUI), D377–D379 (avís/fallada/càrrega sempre completa). El sentit parcial de D364 i de les notes anteriors queda substituït expressament per D379; es conserva l'historial de decisions. Model canònic a DATA_MODEL.md §3.1/§3.14/§5/§6.7/§6.35/§6.41, conciliació §6.39.

Pendents: demostrar integritat/completesa externa i cooperació, permisos dels comptes d'integració, lectura autoritzada/impacte a producció, seqüència efectiva, tractament d'interrupcions i protecció de consultes/confirmacions. No es fixa aquí l'algoritme, DDL, signatura o implementació del carregador extern. L'etapa 0 continua oberta i exigeix contrast complet de les especificacions canviades; etapes 1–4 no implementades ni provades. Consolidació documental de 2026-11-04, no execució SQL, dada/font/configuració canviades, commit o push.
