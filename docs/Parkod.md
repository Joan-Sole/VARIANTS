# Parkod – Project Context

> Actualització funcional: 2026-10-27, acords consolidats fins a D247. Arquitectura vigent: SQL Server 2017 Express, base exclusiva VARIANTS_PARKOD.dbo; parkod original només en lectura controlada, sense intervenció del projecte. Proves locals en SQL Server 2019, amb parkod poblada i VARIANTS_PARKOD existent sense taules; no canvia el destí 2017. Estructura font acceptada per l'usuari, French_CI_AS de producció preservada al destí; diagnòstics previs de lectura separats de les proves de domini. Signatures A → B, recuperació manual només admin i sis contractes de candidates consolidades, sense camps nous. El [model de dades](DATA_MODEL.md) conté diagrama, diccionari i contractes; el [registre de decisions](DECISIONS.md) conserva la traçabilitat. Etapa 0 oberta, sense DDL implementat/desplegat ni proves SQL de domini executades.

## 1. Objectiu del projecte

Parkod és un sistema d’identificació i classificació de productes orientat principalment als sectors de:

- perfumeria
- cosmètica
- parafarmàcia

L’objectiu del nou desenvolupament és evolucionar Parkod perquè pugui representar correctament els productes tal com són necessaris actualment en entorns eCommerce, ERP, PIM i POS.

La necessitat principal és passar d’un model centrat essencialment en una referència Parkod individual a un model capaç d’identificar:

**Producte / família de producte → Variant o declinació → EAN(s)**

El sistema ha de continuar sent compatible amb la base Parkod històrica.

Gestionnaire de Variantes afegeix classificació als SKU Parkod amb totes les escriptures i objectes a **VARIANTS_PARKOD.dbo**, base nova separada a la mateixa instància. Només copia els vuit camps acordats de `parkod.dbo.PARKOD` a `VARIANTS_PARKOD.dbo.Parkod`. A la còpia de proves aportada, consulta puntualment PARKOD.NOM_MARQUE/NOM_LIGNE, CATEGORY, FAMILY i EAN; BRAND/LINE es conserven però no són necessàries per obtenir els noms. Inventari canònic i equivalències documentals a DATA_MODEL.md §5. **Cap actuació ni canvi de dades, estructura, manteniment, permisos o configuració a parkod**: només lectures controlades/autoritzades; si una solució exigeix alterar l'original, es redissenya. La gestió dels EAN continua al sistema existent.

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

ProductVariant incorpora `LineCode NVARCHAR(2) NOT NULL`, heretat de `Parkod.CLIGNE` de la font actual, sempre informat. `ProductCode` continua sent el component CPROD del SKU i no és ProductGroupId. Els camps de marca, categoria i línia utilitzen el sufix Code, no Id.

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

El model documentat conté catorze taules i 98 camps: set taules funcionals de base, ProductGroupCounter i les sis tècniques ParkodVariantCodeRegistry, ParkodVariantCodeBlock, EvaluationAuditEvent, AppAccount, AppSession i SynchronizationStatus. **Totes a VARIANTS_PARKOD.dbo**, amb FK internes, inclosa la còpia de PARKOD. Acords fins a D247; sense columnes/taules noves. D231 ajusta només DESIGN1/DESIGN2 a 18 caràcters i code1 a 13 NOT NULL; D237–D247 no alteren definicions físiques. Font local poblada i destí existent sense taules; estructura de referència acceptada per l'usuari, collation local diferent de producció. Els 78.220 SKU únics/formats vàlids observats no acrediten classificació humanament validada ni desplegament del model. Original parkod intacta.

Encara cal definir o validar:

- Les longituds 20/80/80/150, la collation `Latin1_General_100_CI_AI_SC`, els buits prohibits informats, el nom inicial, el comptador i l'ús de `sp_getapplock` estan confirmats; resten DDL i proves.
- IDs de catàleg INT IDENTITY(1,1); ProductVariantId segueix BIGINT IDENTITY(1,1). Numeració de ProductGroupId per marca–categoria, no per línia.
- Les claus candidates i FK compostes vigents requereixen materialització i proves. SourceIsPresent està aprovat. La FK SKU/grup inclou LineCode NOT NULL; la FK SKU/còpia inclou només la identitat de tres camps i la igualtat de CLIGNE es valida al procediment protegit. Les **dues** cascades limitades `ON UPDATE CASCADE` (rèpliques de grup a ProductVariantValue i rèplica Type a VariantTypeValue), la correcció atòmica i els bloquejos acordats requereixen DDL i proves.
- Controls SQL de compatibilitat de marca i de bloqueig de canvis de `VariantType.BrandCode`. El camp nullable està aprovat i figura al diagrama; la parella `Type + Characteristics` és única globalment, sense incloure BrandCode.
- `VariantType.ValueKind NVARCHAR(7) NOT NULL` i homogeneïtat numèrica/textual confirmats, també per a estructurats. Provar correspondència amb el catàleg i bloqueig amb qualsevol valor o associació aprovada, encara de fase 2 sense codi; no default, rèplica a la filla ni via excepcional aprovats.
- Controls SQL i transaccionals de `ProductGroup.PrimaryVariantTypeId`: pertinença als tipus habilitats del mateix grup, obligatorietat segons el nombre de tipus i bloqueig d'exportació/canvis invàlids. El camp i les regles estan aprovats; la FK composta i el seu manteniment són propostes a validar.
- Materialitzar i provar la via excepcional de BrandCode ja acordada: fora GUI, procediment protegit i identitat SQL administrativa específica, amb impacte/autorització previs, compatibilitat total i auditoria atòmica.
- Contrastar les quantitats/unitats i casos límit amb dades validades: font actual `code1`/`code2`; no reparar codis o quantitats invàlids. Scripts antics discrepants amb la font real.
- Contractes JSON/contextos, catàlegs i substitució expressa confirmats a §22.15–22.19/§22.23/§22.27. Sis signatures de candidates D241–D247 i context grup–tipus de quatre blocs aprovats; JSON SKU complet encara proposta, amb Parkod confirmat. A → B, entrada/resposta SKU, recuperació manual admin, login/global/editorials/gramàtica/reversions ja resolts, no reobrir-los. Altres contractes no coberts, controls executables/permisos/proves encara pendents.
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
- Només `parkod.dbo.PARKOD` es copia a la taula real `VARIANTS_PARKOD.dbo.Parkod`, amb clau única i els vuit camps de §22.5. No-intervenció absoluta sobre l'original: cap DML/DDL/manteniment/objecte/permís/configuració del projecte, només lectures controlades i autoritzades (§22.22).
- Les fonts de la còpia de proves són `PARKOD`, `CATEGORY`, `FAMILY`, `EAN`, `BRAND` i `LINE`; substitueixen els noms font antics segons DATA_MODEL.md §5.3, no reanomenen el model intern. Les dependències necessàries són les quatre primeres; BRAND/LINE es conserven sense dependència necessària per als noms. Cap mestre ni EAN es copia ni rep FK.
- Els noms de marca/línia provenen de `PARKOD.NOM_MARQUE`/`PARKOD.NOM_LIGNE`; categoria per `PARKOD.CCATEG = CATEGORY.IDCategory`, família per `CATEGORY.IDFamily = FAMILY.IDFamily`. Diagnòstics locals previs a DATA_MODEL.md §5.5; completar evidència i provar futurs accessos sense concessions ni objectes a l'original pel projecte.
- `EAN.IDParkod` correspon al SKU concatenat i `EAN.EANNum` aporta els EAN. L'aplicació no n'administra els codis, la vigència ni l'històric.
- `DEPARTEM` queda exclòs; FAMILY només serveix per navegar/preparar lots marca–família, sense canviar PK ni numeració del grup. IDCountry no filtra, agrupa, identifica ni classifica: el producte és independent del país. Això no prova unicitat global dels codis; qualsevol ambigüitat exigeix contrast/revisió, no selecció/fusió arbitrària.
- La taula d'equivalències és documental, no una taula SQL nova. Font poblada i destí sense taules identificats a .\SQLEXPRESS de proves; estructura font acceptada com a referència de producció per l'usuari, no verificada directament a producció. Exportacions/scripts preparatoris no acrediten el desplegament del model.

### 22.2 Taules, camps i funcions

| Taula | Funció | Camps funcionals principals |
|---|---|---|
| `Parkod` | Còpia de treball que ancora les referències als SKU sense afectar l'origen. | Vuit camps originals confirmats i SourceIsPresent; PK `CMARQ + CCATEG + CPROD`. |
| `ProductGroup` | Producte comercial amb marca, categoria i línia coherents, nom no necessàriament únic i tipus principal comú per a qualsevol ús. | PK `(BrandCode, CategoryCode, ProductGroupId)`; ProductGroupId INT positiu local, ProductGroupName NVARCHAR(150) NULL però informat inicialment, LineCode NOT NULL i PrimaryVariantTypeId INT NULL segons tipus habilitats. |
| `ProductVariant` | Identitat numèrica independent per a cada SKU. | ProductVariantId BIGINT IDENTITY(1,1), ProductGroupId INT, components de la clau Parkod únics en conjunt i LineCode NOT NULL heretat de CLIGNE. |
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
| `SynchronizationStatus` | Última recàrrega fiable i conciliació completa, no historial d'execucions. | Fila única 1, dues dates i dos indicadors; sense versions ni estats per marca. |

Definicions aprovades de camps/claus al diccionari DATA_MODEL.md §3; resten controls SQL, procediments i proves. ProductGroup/ProductVariant també tenen risc/IsValidated. Textos nous NVARCHAR, sense canvis a camps/tipus/dades originals; cap taula addicional de versions o snapshots aprovada.

#### Identitat del grup i compatibilitat dels SKU

- Es mantenen ProductGroup, ProductGroupId i ProductGroupVariantType; només es retiren les denominacions Product/ProductId proposades, no els canvis estructurals. ProductGroupId és independent de ProductVariant.ProductCode.
- ProductGroup té BrandCode NVARCHAR(3) NOT NULL, CategoryCode NVARCHAR(2) NOT NULL i LineCode NVARCHAR(2) NOT NULL. La seva identitat és la PK completa `(BrandCode, CategoryCode, ProductGroupId)`, no el número local sol; LineCode no forma part de la PK.
- ProductGroupId es genera automàticament des d'1 dins de cada parella BrandCode + CategoryCode, amb INT positiu NOT NULL. Pot repetir-se entre parelles: `(ABC, 01, 1)` i `(ABC, 02, 1)` són grups diferents. Comptador local i bloqueig exclusiu `sp_getapplock` per parella aprovats; DDL i proves pendents. Un IDENTITY global no expressa el requisit.
- ProductVariant.LineCode és NVARCHAR(2) NOT NULL i hereta Parkod.CLIGNE del mateix SKU. El nou grup hereta marca, categoria i línia del primer SKU creador; CLIGNE actual sempre està informat.
- Els SKU membres han de tenir la mateixa marca, categoria i línia informada que el grup. La clau candidata `UNIQUE (BrandCode, CategoryCode, ProductGroupId, LineCode)` i FK composta de ProductVariant impedeixen barrejar línies; no cal LineCode a ProductGroupVariantType ni ProductVariantValue.
- Compartir marca, categoria i línia és una condició necessària, no una clau comercial ni una autorització per fusionar grups. Es conserven els noms repetits i els grups buits. Si CLIGNE canvia a l'origen per a un SKU ja classificat, la sincronització conserva còpia/classificació vàlides, registra la discrepància i manté el SKU present fins a revisió tècnica; no reclassifica silenciosament. El tècnic tria un grup existent compatible només si confirma pertinença comercial, o crea un grup propi; tipus ja assignats al SKU s'han d'habilitar al destí i revalidar el principal sense perdre valors. La seqüència SQL encara s'ha de provar (DATA_MODEL.md §6.3).

#### Simplificació i rèpliques controlades

- ProductGroupVariantType manté PK de quatre camps NOT NULL, marca/categoria de grup i textos consultats a VariantType. Codi nullable, risc/IsValidated i JSON originals físics aprovats; habilitació final només amb indicador i codi.
- Es conserva VariantTypeValue.Type i la FK composta amb VariantTypeId per garantir la rèplica del pare. La deducció antiga «no-open_type = numèric» queda substituïda: CHECK local d'exclusió NumericValue/TextValue i open_type textual, més procediments protegits per correspondència amb ValueKind. No nova rèplica ni FK per a ValueKind.
- Es conserva ProductVariantValue.VariantTypeId com a part de la PK que limita una assignació per tipus i SKU. La FK composta proposada amb VariantTypeValueId haurà de garantir que el valor pertany al mateix tipus.
- Es conserva ProductVariantValue.ProductGroupId i s'hi afegeixen BrandCode i CategoryCode, tots tres NOT NULL, per comprovar el grup real complet del SKU i que el tipus hi està habilitat. Les FK proposades són `(ProductVariantId, ProductGroupId, BrandCode, CategoryCode)` cap a ProductVariant i `(ProductGroupId, BrandCode, CategoryCode, VariantTypeId)` cap a ProductGroupVariantType. La PK d'assignació `(ProductVariantId, VariantTypeId)` no canvia.
- El principal referencia una associació amb `(ProductGroupId, BrandCode, CategoryCode, PrimaryVariantTypeId)`. La referència al grup de ProductVariant afegeix LineCode cap a la clau candidata; ProductGroupVariantType utilitza la PK `(BrandCode, CategoryCode, ProductGroupId)`. ProductGroupId sol no és suficient.
- No són definicions independents editables. Les FK comproven la coherència, però no omplen automàticament les rèpliques, **excepte** dues cascades `ON UPDATE CASCADE` delimitades: ProductVariantValue → ProductVariant en trasllats de grup i VariantTypeValue(VariantTypeId, Type) → VariantType(VariantTypeId, Type) només per correcció editorial de Type. Cap cascada DELETE ni canvi silenciós d'IDs o valors; DDL/proves pendents.
- La PK `(CMARQ, CCATEG, CPROD)` de la còpia `VARIANTS_PARKOD.dbo.Parkod` és el destí de la FK SKU/còpia. La clau UNIQUE i FK de quatre camps amb CLIGNE abans proposades es retiren: SQL Server comprova les FK immediatament i impedirien corregir còpia/variant en qualsevol ordre. La igualtat de la línia entre còpia i variant es revalida als procediments protegits sota bloqueig per SKU; la FK SKU/grup amb línia segueix vigent com a proposta física acordada.

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
- Diversos SKU poden reutilitzar el mateix VariantTypeValueId mitjançant ProductVariantValue; no es creen valors duplicats al catàleg ni es fusionen les identitats de variant.
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

Les restriccions han de garantir identitat composta del grup, numeració local, igualtat de marca/categoria/línia no nul·la dels membres, tipus i valors, unicitats normalitzades CI_AI, compatibilitat de marca, principal i una assignació per tipus/SKU. La FK composta a la clau candidata de ProductGroup inclou LineCode NOT NULL i impedeix barrejar línies; l'herència de CLIGNE des de la còpia es verifica al procediment protegit, no per una FK de quatre camps a la còpia. Les FK per si soles no comproven compatibilitat condicional de marca ni obligatorietat del principal: procediments i bloquejos a DATA_MODEL.md. La cobertura completa Parkod–variant requereix comprovació del processament.

Un trasllat de grup es fa atòmicament, conserva identificadors i revalida marca, categoria i línia del SKU i del destí, els tipus habilitats, el principal, l'abast de marca i les assignacions. Actualitza coherentment les rèpliques del grup complet, sense fusionar ni perdre assignacions silenciosament. Es conserven els grups buits i els registres retirats per permetre auditoria i reversibilitat; no s'esborren en cascada.

Una associació a un grup incompatible amb el BrandCode informat del tipus, la creació d'una parella Type + Characteristics ja existent o un segon TextValue equivalent dins del mateix VariantTypeId es rebutgen. Les comparacions textuals acordades es fan després de normalitzar els blancs i segons CI_AI. La normalització aprovada no autoritza alterar BrandCode, Characteristics o TextValue per esquivar un conflicte, ni fusionar files automàticament. Si el problema apareix durant el processament, s'enregistra i es conserva el tractament tolerant a errors de registre.

#### Canvis de BrandCode

- És un canvi major d'abast, tant per als tipus estructurats com per als `open_type`.
- Si existeix qualsevol assignació del tipus a `ProductVariantValue`, el canvi de BrandCode queda bloquejat en l'edició ordinària. També compten les assignacions dels SKU retirats que es conserven.
- Sense assignacions, el canvi es permet només si totes les associacions existents a `ProductGroupVariantType` continuen sent compatibles amb el nou abast. No s'eliminen associacions silenciosament.
- Per exemple, passar de NULL a ABC no és vàlid si el tipus està associat a un grup XYZ, encara que aquest no tingui valors assignats.
- La comprovació i el canvi s'han de fer atòmicament en una transacció curta, sense permetre que una assignació o associació concurrent invalidi la comprovació.
- Canvi excepcional assignat: fora GUI, procediment protegit només per identitat SQL d'administració autoritzada, mai compte ordinari variants. Requereix impacte/autorització previs i compatibilitat de totes les associacions; si alguna incompatible, rebuig. No elimina associacions/valors ni canvia codis per forçar compatibilitat. Canvi i auditoria abans/després atòmics en transacció curta. Via aprovada, SQL/permisos/proves pendents.

### 22.5 Importació tolerant a errors

Conciliació completa conservada, programada externament o manual, més opció parcial d'una o diverses CMARQ en un únic batch. Parcial fa les mateixes altes, canvis, incidències i SourceIsPresent només dins les marques triades; cap canvi/retirada fora. Ambdues idempotents i una sola execució simultània. SKU nou vàlid rep còpia, variant i grup propi provisionals, amb IsValidated=0 i risc sustentat o NULL per grup/pertinença; alta i auditoria atòmiques, sense mitja incorporació. Intactes no es recreen ni requereixen revisió repetida. Canvis amb impacte/anomalies preserven decisions i passen a revisió. Resum de nous, actualitzats, intactes, rebutjats/pendents i retirats.

El batch el llança manualment el personal autoritzat o el Planificador de tasques de Windows; l'app no incorpora planificació ni reintents propis. Hi ha **exclusió global amb les sessions d'usuari**: si n'hi ha una d'activa, el batch no arrenca, finalitza amb codi de sortida **0** i deixa al log tècnic constància explícita de «no executat» i del motiu, sense presentar-ho com a conciliació completada. Mentre el batch corre no es permet obrir sessions d'usuari. Si s'ha omès, una execució manual o una futura tasca planificada el tornarà a intentar per mitjans externs. Això no impedeix les exportacions als clients; el control atòmic d'inici batch/inici sessió resta pendent de proves.

**Contracte vigent de la còpia (D230–D232):** `parkod.dbo.PARKOD` ha de proporcionar un SKU únic `(CMARQ, CCATEG, CPROD)`; es conserven **exactament els noms dels vuit camps font**: aquests tres NVARCHAR(3/2/3) NOT NULL, `CLIGNE NVARCHAR(2) NOT NULL`, `DESIGN1 NVARCHAR(18) NOT NULL`, `DESIGN2 NVARCHAR(18) NULL`, `code1 NVARCHAR(13) NOT NULL` i `code2 NVARCHAR(1) NULL`, més el marcador local `SourceIsPresent BIT NOT NULL DEFAULT(1)`. Ajustos de longitud/nul·litat acceptats a partir de les metadades locals; text preservat i French_CI_AS al destí segons producció confirmada, no SQL_Latin1 de proves. NOT NULL de code1 no en prova validesa numèrica. Canvis futurs es revisen a la interfície de conciliació amb avís d'impacte sobre el disseny, mai truncament/adaptació silenciosa. A la variant, `CMARQ → BrandCode`, `CCATEG → CategoryCode`, `CPROD → ProductCode`, `CLIGNE → LineCode`. No es copien noms, mestres, EAN, preus ni altres camps exportats; els autoritzats segueixen consultables. SourceIsPresent=1 inclou un SKU identificable rebutjat que conserva còpia anterior; 0 només amb lectura completa i fiable que confirma absència, sense esborrar decisions.

Per crear el nom inicial modificable del grup, després de numerar-lo, s'utilitza `PARKOD.NOM_MARQUE + '_' + PARKOD.NOM_LIGNE + '_' + CATEGORY.CategoryName + '_' + ProductGroupId`. Marca/línia provenen del SKU creador i categoria de `CATEGORY.IDCategory = PARKOD.CCATEG`. Si falta una fila o denominació (NULL/buit/blancs), el component corresponent passa a CMARQ/CLIGNE/CCATEG; no s'afegeix fallback a BRAND/LINE ni es tria una altra fila/SKU arbitràriament. Un nom absent no rebutja per si sol el SKU. Si el resultat normalitzat supera NVARCHAR(150), s'utilitza `CMARQ_CLIGNE_CCATEG_ProductGroupId`. Només es genera en crear el grup i no se sobreescriu a la sincronització. Fallada d'accés o ambigüitat no equivalen a nom absent. Només es desa el nom de grup resultant, no les denominacions font com a camps addicionals.

`code1` només accepta dígits ASCII amb punt decimal opcional i dígits als dos costats, sense signes, comes, blancs ni exponents. La lectura és exacta i ha de cabre sense arrodonir a DECIMAL(18,3); `50.0000` equival a `50`, `50.0001` es rebutja. `code2` només accepta exactament `L → volume/ml`, `G → weight/gr`, `U → count/unit`; NULL, buit, `l` o un altre codi es rebutgen, sense substituir per U/1. La quantitat ha de ser >0 i, per U, entera. La regla funcional per defecte U/1 no és una reparació de registres històrics. Error per registre: log en anglès, rollback i preservació de còpia anterior.

Les correccions de línia exigeixen relectura controlada de `parkod.dbo.PARKOD.CLIGNE` en executar la decisió i just abans de COMMIT; canvi respecte del revisat exigeix rollback/nova revisió. Protocol executable entre bases pendent, sense configurar SNAPSHOT a l'original. No transacció durant formulari ni bloqueig deliberat de taula. Canvis posteriors es detecten en conciliació següent; coordinació de fiabilitat/retirades de §22.12–22.13 encara per revalidar/provar.

1. Es llegeix l'origen sense modificar-lo.
2. Cada registre es tracta atòmicament amb una transacció curta.
3. Un error de registre desfà aquella operació, s'enregistra en un log tècnic en anglès i no impedeix continuar amb els altres registres.
4. Qualsevol clau SKU duplicada, encara amb files idèntiques, rebutja totes les files i genera avís urgent. Conservar còpia/decisions anteriors i presència si existeixen.
5. Rebutjat present no és absent. SKU inidentificable suspèn retirades de la marca afectada; marca inidentificable, de tot l'abast. Processar vàlids i registrar retirades suspeses.
6. Les retirades lògiques només es calculen després d'una lectura completa i fiable; no esborren la classificació ni trenquen les FK.
7. Una fallada d'infraestructura que impedeix continuar deixa l'execució incompleta, registrada i pendent de reprendre. No es declara èxit ni s'apliquen supressions d'una lectura incompleta.
8. El resum indica registres llegits, importats i omesos. Les dades i decisions humanes existents no se sobreescriuen silenciosament.

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

1. **Grups i SKU:** descoberta proposa grup comercial, tècnic valida configuració i cada pertinença individual. Un grup pot avançar sense esperar totes les marques. Proposta de pertinença candidata no es desa com a trasllat abans de validar; SKU manté grup propi provisional. Sense agrupació convincent no queda orfe ni va a grup genèric. Grups buits conservats.
2. **Tipus del grup:** candidates ProductGroupVariantType persistents amb risc, originals JSON, IsValidated=0 i codi NULL. Aprovació tècnica passa IsValidated a 1, però codi continua NULL i no habilita ús Parkod/principal.
3. **Valors per SKU:** només per associacions aprovades de fase 2. Candidates ProductVariantValue amb risc i validació propis; revisar/confirmar individualment. En completar els valors requerits dels SKU presents pertinents, assignar codi i revalidar principal atòmicament. SourceIsPresent=0 exclou retirats de l'exigència de valors. No nova taula ni procés de publicació separat: és la finalització de fase 3.

IA pot ajudar amb variables de SKU, dades Parkod/EAN i fonts GS1/marques/eCommerce, però només proposa. Recursos externs/IA es desenvoluparan en etapes 2/3 del projecte, sense saltar validació d'etapa 0; aquestes tres fases de treball no substitueixen les etapes del projecte. Conciliació de font acabada no implica classificació aprovada.

OriginalSourcesJson i OriginalProposalJson NVARCHAR(MAX) NULL, JSON vàlid si informat, a les dues taules candidates: fonts i proposta automàtica originals abans de correccions. No es guarden al catàleg compartit ni són esborranys manuals. En acceptar/corregir/rebutjar es preserven també a EvaluationAuditEvent.

Rebutjar candidata grup–tipus no validada sense codi ni valors elimina només aquella fila; grup/VariantType conservats. Rebutjar valor pendent IsValidated=0 elimina només ProductVariantValue d'aquell SKU/tipus; ProductVariant i VariantTypeValue conservats. Originals/risc/decisió es guarden a auditoria en mateixa transacció, abans d'eliminar; si falla qualsevol operació, rollback complet. Valor obligatori absent impedeix completar l'associació nova. Correccions reassignen a valor correcte existent o nou, sense canviar significat d'una fila compartida ni sobreescriure assignació validada abans de confirmar.

La preparació d'un tipus B en un grup ja habilitat amb A no altera el principal ni la lectura d'A mentre B no tingui codi. No s'aproven dues versions físiques de classificació per resoldre aquest procés de creació. Les correccions editorials i els canvis semàntics continuen sota les regles anteriors.

El moment de reutilització/alta del catàleg automàtic o manual està concretat a §22.18; crear catàleg no valida la candidata. La substitució expressa d'A per B es regula a §22.19, diferent d'aprovar tipus complementaris.

### 22.12 SynchronizationStatus i recàrrega fiable

Una única fila tècnica, cinc camps: SynchronizationStatusId TINYINT PK restringit a 1; ParkodLastCompletedAtUtc i VariantsLastCompletedAtUtc DATETIME2(3) NULL; ParkodRefreshSucceeded i VariantsReconciliationSucceeded BIT NOT NULL DEFAULT(0). No versions BIGINT ni estat SQL per marca. Historial d'execucions al log, canvis de dades a auditoria.

- **Senyals del carregador extern:** només camps Parkod a VARIANTS_PARKOD, inici 0/final complet verificat 1/data nova; fallada data anterior/0. Requisit de completesa CSV/font amb multiplicitats/errors/rebutjos preservat, però integració entre bases pendent sense modificar parkod ni scripts originals. No inferir font fiable d'un indicador sense coordinació efectiva; no s'exigeix mateix recompte original/còpia.
- **Batch complet:** abans de modificar dades posa indicador variants 0, conservant data anterior. Només amb lectura/processament acabats posa 1 i data nova; errors individuals o retirades suspeses registrats poden permetre èxit 1. Fallada d'infraestructura o lectura incompleta deixa 0. Una omissió no modifica camps variants.
- **Batch per marques:** consulta ParkodRefreshSucceeded, mateix tractament dins l'abast incloses retirades fiables, però no modifica camps globals variants. Abast/resultat al log; canvis auditats, cap taula per marca.
- **Omissió programada:** si ambdós indicadors són 1 i data variants posterior a data Parkod, font ja conciliada i batch complet s'omet. Manual explícit pot repetir. Dates suficients segons operativa acordada, sense comptadors de versió.
- **Lectura de fitxers:** els dos indicadors informen situació, no elegibilitat per SKU ni veto global; generador pot operar amb qualsevol indicador 0 i ho registra al seu log.

El manteniment/recarregador legacy de parkod continua **fora del projecte**. Aquest projecte no recarrega ni modifica la font, tampoc en una recuperació. Pauta nocturna D233: tasques del Planificador de Windows **en seqüència, primer recàrrega externa i després conciliació completa**, una vegada al dia `parkod → VARIANTS_PARKOD.dbo.Parkod`, després de final correcte verificat. Mecanisme d'orquestració ja acordat, no pendent de nova elecció. Completa no és buidar/recrear ni perdre decisions. Senyals i coordinació carregador/batch només a VARIANTS_PARKOD, materialització/proves pendents segons DATA_MODEL.md §6.7; horari de llançament no prova completesa.

Parkod de producció canvia en horari d'oficina; no s'exigeix nova garantia tècnica d'estabilitat nocturna ni control dels usuaris legacy per l'app. Treball extraordinari de nit: coordinació operativa de l'equip, com suspendre les tasques. Si una tasca ja iniciada s'interromp, queda incompleta, sense rollback presumpte dels COMMIT anteriors ni declaració d'èxit. Sense coordinació efectiva d'escriptures externes, el calendari no garanteix coherència; no s'afegeix detecció automàtica ni objectes/bloquejos a l'original. Exclusió sessions d'app/batch intacta.

### 22.13 Coordinació d'execucions, logs i correu urgent

Backend interactiu/batch comparteixen compte SQL tècnic nou i limitat; carregador separat, generador lector separat. Tècnics no tenen logins SQL propis. Procediments d'usuari comproven token, sessió/caducitat/reserva, deriven actor d'AppSession i consulten IsAdmin vigent. Sense DML directe de l'app.

Dos bloquejos d'execució protegeixen **batch exclusiu** i **global batch/login**. Netejar caducades abans de decidir: sessió activa o altre batch ometen execució amb sortida 0 i motius diferenciats; durant batch no nous logins. Mateixa connexió dedicada manté coordinació i escriu en transaccions curtes; perdre-la atura l'execució incompleta.

Coordinació addicional **recàrrega/batch**, només amb recursos del projecte a VARIANTS_PARKOD: cal demostrar que carregador extern i batch respecten el mateix protocol abans d'iniciar manteniment/llegir i que batch comprova fiabilitat després d'obtenir coordinació. sp_getapplock no coordina legacy o bases automàticament. Protocol entre bases/recursos/temps/proves pendents; no declarar conciliació segura sense resoldre-ho ni configurar parkod per facilitar-la. Operacions només variants i administració poden continuar amb font no fiable; les dependents s'ajornen. Generador independent.

Cada invocació registra al log tècnic anglès hora UTC d'invocació/inici efectiu, abast/marques, durada, completed/not_run/failed, motius i recomptes quan pertoqui. Intactes, errors sense canvi i inici/final no van a EvaluationAuditEvent. Marques amb retirades suspeses queden explícites; no es presenta omissió com èxit real.

Un sol correu urgent per execució, francès, amb apartats de duplicats SKU i CPROD en blocs reservats, claus i nombre de files. En acabament o interrupció amb deteccions disponibles; repetit en futures execucions mentre persisteixin. Compte/connexió disponibles; adreces i secrets en configuració protegida, no documents/logs/MEMORY. Sense reintents interns. Error d'enviament no desfà conciliació ni canvia èxit de dades, però procés acaba amb codi no zero i log inequívoc de notificació urgent no lliurada.

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

Les operacions només variants no exigeixen llegir parkod.dbo.PARKOD; les dependents de l'origen fiable i les correccions de línia mantenen els controls de §22.5/22.12–22.13 amb integració entre bases pendent. Un conflicte o error tècnic no es registra com a decisió humana confirmada.

### 22.17 Creació conjunta amb valors preexistents i coherència pendent

Quan es crea un grup amb SKU que ja tenen valors, el tècnic revisa prèviament grup/membres i les associacions compatibles necessàries. Les associacions del destí requereixen aprovació explícita, no herència dels grups anteriors. SQL compara contextos i crea grup/associacions aprovades/trasllats amb valors preservats en una transacció curta, decisions individuals i OperationId comú; qualsevol incoherència desfà tot. No grup preparatori buit persistent ni trasllat abans de validar.

Original de l'associació amb grup nou conserva ProductGroupId JSON null; resultat i clau de l'associació confirmada usen l'ID real. No es reescriu l'original ni canvia la nul·litat SQL. Codis anteriors no es traslladen ni es reciclen; codis nous subjectes a fase 3 i principal coherent. Les fases es revisen abans i s'executen conjuntament quan cal conservar valors, no s'aproven automàticament.

La revisió documental de 2026-10-18 contrasta aquest canvi conceptual amb el funcional/model: mateixa identitat de grup/SKU, 14 taules, dues cascades, unitats i codis preservats; ValueKind és l'única columna nova d'aquests darrers acords. Els controls abans atribuïts a Type s'han ajustat, i els JSON no es confonen amb rèpliques físiques.

**Etapa 0 oberta:** falten evidència física complementària, DDL, controls executables, permisos, concurrència, integracions i proves humanament validades. Sis signatures de candidates, quatre blocs grup–tipus, A → B, recuperació manual admin, entrada/resposta SKU, login/global/editorials/principal/gramàtica resolts documentalment. JSON SKU de set propietats encara proposta, amb Parkod confirmat. Reversions ordinàries i seqüència recàrrega → conciliació ja acordades; altres contractes no coberts a DATA_MODEL.md §7 pendents, sense extrapolar propostes sense ID. ValueKind sense default/collation/via excepcional. Cap etapa posterior implementada/validada.

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

El context complet de set blocs no és universal: grup, membres, associacions, tipus/valors implicats i assignacions d'A/B segons DATA_MODEL.md §6.11.4. Membres amb LineCode de ProductVariant i CLIGNE/SourceIsPresent de la còpia, sense risc de pertinença ni lectura obligatòria dbo; les línies coincideixen a l'estat coherent conservat. Assignació B absent és ProductVariantValue null explícit, no una pendent ni {}; absència/manca de validació requerida bloqueja finalització. JSON originals imbricats i conjunt sense duplicats, no noves columnes.

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
| parkod.dbo.PARKOD | Còpia controlada només CMARQ, CCATEG, CPROD, CLIGNE, DESIGN1, DESIGN2, code1, code2 a VARIANTS_PARKOD.dbo.Parkod; consultes puntuals previstes/preus, no copiats. |
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
- `dbo.GetVariantTypeEditorialContext`: quatre blocs VariantType/VariantTypeValues/ProductGroupVariantTypes/Usages, tot el catàleg i associacions del tipus candidates/aprovades.
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

**Context SKU–valor:** propietat Parkod amb exactament CLIGNE/SourceIsPresent de la còpia confirmada D243, per coherència de línia i situació de presència revisada. No nova font/camp, reclassificació silenciosa o prohibició nova de corregir retirats. La resta de la proposta completa de set propietats es conserva com a proposta a DATA_MODEL.md §6.15.3, no confirmada íntegrament per l'acord sobre Parkod.

**Context grup–tipus íntegrament confirmat D246:** ProductGroupVariantType, ProductGroup i VariantType complets; ProductVariants array de tots els membres reals amb ID/codis SKU/grup/LineCode/IsValidated i Parkod:{CLIGNE, SourceIsPresent} de la còpia. Inclou retirats i pertinences pendents, sense duplicats, [] si grup buit; null explícit als camps nullable i originals JSON imbricats. No el context editorial de quatre blocs ni el de substitució.

Aprovar fase 2 no crea valors SKU, assigna codis o modifica el principal; substituir el tipus té el seu circuit. Associació ja aprovada, encara sense codi, no rebutjable com a candidata. Rebuig no elimina SKU, grup, tipus, valors de catàleg o historial. Les signatures no aproven altes conjuntes ni altres circuits per extrapolació. 14 taules/98 camps/claus/tipus físics intactes; DDL, representació JSON SKU completa, altres contractes no coberts, permisos, integracions i proves encara pendents. Etapa 0 oberta, només actualització documental sense SQL.
