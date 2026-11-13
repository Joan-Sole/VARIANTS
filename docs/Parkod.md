# Parkod – Project Context

> Actualització **2026-11-14, registre finsD446**: repàs conceptual de les13taules i controls entre taules, operativaSynchronizationStatus i punt de represa a **§33**/[model](DATA_MODEL.md) §6.55/§7. No noves decisions de domini, camps, signatures o índexs:13/92,76actives+funció/quatre retirades/33índexs intactes. **Proposta E08 d'una entrada per objecte i motiu pendent de confirmació**, no aprovada per demanar documentar-la. Categoria/reserva/mecanismeD444–D446 confirmats§32. Etapa0oberta/connectoral final; només documentació, senseSQL/DDL/dades-font-configuració/instal·lació/desplegament/commit/push.

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

SKU original = `CMARQ + CCATEG + CPROD`, textual3+2+3 exactes, zeros preservats. **Tots tres components admeten ASCII A–Z/0–9; CCATEG són dos caràcters alfanumèrics**, encara que actualment no s'hi utilitzin lletres (D444 substitueix D388), NVARCHAR(2) conservat. Parkod diferent implica variant diferent, no necessàriament grup diferent. Identificador nouBrandCode3+ParkodVariantCode5, també8, no substitueix SKU. Reserva i controls de càrrega externa§23.2.1.

IDParkod=BrandCode+CategoryCode+ProductCode=CMARQ+CCATEG+CPROD, textual3+2+3=8/zeros preservats/no separadors o conversió. IDLine actual de font/còpia=CMARQ+CLIGNE, textual3+2 quan informat. Les equivalències IDBrand/LineCode del mestre legacy són documentals i no es modifiquen; D415 elimina ProductVariant.LineCode, no les fonts o el format original. IDParkod no és ProductVariantId, cap IDLine intern nou o línia operativa derivada de la fotografia.

La regla de l'entorn Parkod prohibeix O en CMARQ/CCATEG/CPROD/CLIGNE. D445 confirma que **l'app externa de càrrega** validarà aquests quatre codis senseO i categories < 'DE', i n'informarà els tècnics (§23.2.1). El gestor manté validador general deSKU sense afegir-hi control específic d'O/reserva o modificar originals. El nouParkodVariantCode sí que es genera i valida senseO.

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

ProductGroup conserva nom descriptiu no únic i ProductGroupId INT positiu, numerat des d'1 per marca. **PK `(BrandCode, ProductGroupId)`**, no ID global. Membres comparteixen marca, però poden tenir categories/línies diferents. CategoryCode/LineCode retirats del grup, no substituïts per una categoria/línia principal. Fonts de noms del SKU creador i fórmula inicial conservades, sense copiar denominacions o imposar-les com a classificació comuna.

SKU sense grup comercial conegut rep grup propi actiu/provisional de la mateixa marca, no grup genèric. Compartir marca/aroma/atributs no prova equivalència comercial: decisió humana. Canvis de grup conserven ProductVariantId i assignacions; grups buits/històric conservats. Un únic grup actual per SKU, no agrupacions alternatives per client.

IsActive/default1 independent de validació, nous grups actius. Admin pot desactivar amb zero ProductVariant, retirades/pendents incloses, i cap reserva vigent. D386: selecció per marca o totalitat, no categoria de grup buit. Fila/associacions/codis/història preservats, sense DELETE/reactivació/reciclatge.

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

ProductVariant conserva categoria identificadora pròpia del SKU, **sense LineCode**. La línia actual és només Parkod.CLIGNE. ReviewedSourceJson NVARCHAR(MAX) NULL conserva la font de l'última revisió expressa per mostrar valors anteriors; no és classificació o font operativa alternativa. Càrrega de CLIGNE no mou grup o modifica valors/riscs/validacions; pendent general de font com code1. Canvi de CCATEG continua nou SKU, no edició de categoria del mateix ProductVariant (§30).

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
- Acords fins a D394: model13/90, identitat marca–grup, codi5/DE000/sense blocs o retorn i matriu de línia resolts (§24). Inventari base76 noms/funció separada, signatures afectades no totes adaptades. Càrrega D379 sempre completa (§23), conciliació completa/per marques i coberturaD373 conservades. Pendents exactes E01–E11 al model §7, no reaprovar principis decidits. Etapa0 oberta, sense SQL/GUI/algoritmes o pas d'etapa.
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

**Lectura actual D415–D416:** §30 preval sobre les notes anteriors de línia pròpia/discrepància/correctors/vetos i formes afectades. Categoria/claus/riscos/validacions/codis/altres controls conservats. Les formulacions històriques i exemples amb LineCode es mantenen per traçabilitat, no per implementar-los com a contractes actuals.

**Lectura D394:** principis compartits a continuació; contractes detallats i talls històrics s'han de contrastar amb §24/model §6.42. G9/R5, signatures amb categoria de grup, reserva amb categoria, codi3 o blocs són del tall D379, no una interfície nova ja adaptada. No signatures inventades per tancar E02/E03.

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
| `ProductGroup` | Grup comercial d'una marca, categories/línies diverses, nom no únic, principal i activitat independents. | PK `(BrandCode, ProductGroupId)`, set camps, sense CategoryCode/LineCode; tipus/defaults restants conservats. |
| `ProductVariant` | Identitat estable, pertinença actual única i referència informativa de l'última revisió de font. | ProductVariantId BIGINT IDENTITY(1,1), grup de mateixa marca/clauSKU única; data revisada i ReviewedSourceJson, sense LineCode. |
| `VariantType` | Defineix la naturalesa, unitat/escala o característica comercial, representació homogènia i abast de marca. | Identificador, `Type`, `Characteristics`, `BrandCode` nullable i `ValueKind NVARCHAR(7) NOT NULL` numeric/text; parella Type + Characteristics única globalment, sense ValueKind. |
| `VariantTypeValue` | Catàleg de valors d'un tipus, no una variant SKU. | Identificador, VariantTypeId, Type replicat conservat; exactament un NumericValue/TextValue segons ValueKind del pare. No rèplica ValueKind; unicitats no NULL per tipus. |
| `ProductGroupVariantType` | Associació candidata/aprovada/final d'un grup i tipus compatible amb marca. | PK `(ProductGroupId, BrandCode, VariantTypeId)`, sense categoria; codiNVARCHAR(5) NULL fins a fase3, risc/validació/originals conservats. |
| `ProductVariantValue` | Assigna/proposa un valor per tipus i SKU després d'aprovar fase2. | PK intacta, rèpliques BrandCode/ProductGroupId sense categoria; valor/risc/validació/originals conservats. |
| `ProductGroupCounter` | Numeració tècnica transaccional per marca. | BrandCode PK i LastAllocatedId INT NOT NULL inicial0, sense categoria, no MAX+1/IDENTITY global. |
| `ParkodVariantCodeRegistry` | Codis permanents actuals/retirats, sense reciclatge o blocs. | PK `(BrandCode, ParkodVariantCode)`, codi5, grup/tipus, candidata quatre camps. |
| `EvaluationAuditEvent` | Decisions i canvis confirmats, append-only sense purga automàtica. | Identitat BIGINT, OperationId, moment/actor, acció/àmbit, JSON originals/resultat/snapshots. |
| `AppAccount` | Comptes propis administrats a l'app. | Identitat INT, LoginName únic normalitzat CI_AI, hash Argon2id, IsActive/IsAdmin. |
| `AppSession` | Una sessió per compte i reserva opcional exclusiva de grup. | UUID/compte/hash/activitat i reserva marca–grup de dos camps, sense ReservedCategoryCode. |
| `SynchronizationStatus` | Última càrrega completa correcta de còpia (D379) i última conciliació completa; no historial. | Fila única 1, dues dates/dos indicadors; cinc camps, sense versions o estat per marca. |

Definicions aprovades de camps/claus al diccionari DATA_MODEL.md §3; resten controls SQL, procediments i proves. ProductGroup/ProductVariant també tenen risc/IsValidated. Textos nous NVARCHAR, sense canvis a camps/tipus/dades originals; cap taula addicional de versions o snapshots aprovada.

Model13/90, IsActive només al grup, no a rèpliques/PK/FK/claus JSON; AppAccount conserva el seu significat. Grup complet7 i reduït SKU–valor3, activitat SQL. Contextos exactes E02; no completar/ignorar propietats antigues silenciosament, originals/snapshots històrics intactes. Cap camp nou o substitut de blocs.

#### Identitat del grup i compatibilitat dels SKU

- Es mantenen ProductGroup, ProductGroupId i ProductGroupVariantType; només es retiren les denominacions Product/ProductId proposades, no els canvis estructurals. ProductGroupId és independent de ProductVariant.ProductCode.
- PK marca–grup, sense categoria/línia comunes. ProductGroupId positiu des d'1 per marca, comptador/coordinació SQL, no MAX+1 o IDENTITY global.
- SKU en únic grup actual de la mateixa marca, actiu i amb permisos/reserva/integritat. Categories/línies diverses admeses, però compartir marca/aroma no prova equivalència comercial.
- Categoria del SKU continua identificadora/dos dígits textuals; línia només CLIGNE a còpia. Canvi de categoria és nou SKU; CLIGNE activa revisió general de font com els altres camps vigilats, no corrector de línia.
- Corrector manté grup/risc o trasllada a existent/propi nou amb risc de nova pertinençaNULL. Valors/metadades preservats, no còpia escrita o relectura original, nou flag d'incidència o agrupacions alternatives de client.

#### Simplificació i rèpliques controlades

- ProductGroupVariantType té PK de tres camps marca/grup/tipus i cap categoria; textos no replicats, codi5nullable, fase2/risc/originals conservats. Final només1/codi informat.
- Es conserva VariantTypeValue.Type i la FK composta amb VariantTypeId per garantir la rèplica del pare. La deducció antiga «no-open_type = numèric» queda substituïda: CHECK local d'exclusió NumericValue/TextValue i open_type textual, més procediments protegits per correspondència amb ValueKind. No nova rèplica ni FK per a ValueKind.
- Es conserva ProductVariantValue.VariantTypeId com a part de la PK que limita una assignació per tipus i SKU. La FK composta proposada amb VariantTypeValueId haurà de garantir que el valor pertany al mateix tipus.
- ProductVariantValue conserva BrandCode/ProductGroupId i retira CategoryCode: FK al grup real amb ProductVariantId/grup/marca, i a l'associació amb grup/marca/tipus. PK d'assignació intacta, no segona pertinença independent.
- Principal referencia associació grup/marca/tipus. SKU i associació referencien marca–grup; sense categoria/línia a la referència de grup.
- No són definicions independents editables. Les FK comproven la coherència, però no omplen automàticament les rèpliques, **excepte** dues cascades `ON UPDATE CASCADE` delimitades: ProductVariantValue → ProductVariant en trasllats de grup i VariantTypeValue(VariantTypeId, Type) → VariantType(VariantTypeId, Type) només per correcció editorial de Type. Cap cascada DELETE ni canvi silenciós d'IDs o valors; DDL/proves pendents.
- PK/FK SKU3 i FK marca–grup intactes, CCATEG textual de dos caràcters ASCII A–Z/0–9D444. SenseLineCode/FKamb línia-categoria de grup/còpia escrita. ReviewedSourceJson informatiu, no prova comercial.

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

Restriccions: grup marca–ID/numeració per marca, tipus/valors/unicitats/principal i un valor per tipus/SKU. Categoria/línia pròpies no són FK de grup; SKU/còpia tres camps. Entrada local revalidada en alta/correcció, desajust posterior visible. CoberturaD371–D373 resolta en disseny; comparadors/SQL/proves pendents, no criteri a reaprovar.

Trasllat atòmic conserva identitat/valors i revalida marca comuna, habilitacions, principal, context i rèpliques reals. Validació ordinària de pertinença exigeix línia resolta D390; cap correcció implícita, pèrdua/fusió o DELETE en cascada. Categoria/línia de destí ja no són atributs del grup.

Una associació a un grup incompatible amb el BrandCode informat del tipus, la creació d'una parella Type + Characteristics ja existent o un segon TextValue equivalent dins del mateix VariantTypeId es rebutgen. Les comparacions textuals acordades es fan després de normalitzar els blancs i segons CI_AI. La normalització aprovada no autoritza alterar BrandCode, Characteristics o TextValue per esquivar un conflicte, ni fusionar files automàticament. Si el problema apareix durant el processament, s'enregistra i es conserva el tractament tolerant a errors de registre.

#### Canvis de BrandCode

- És un canvi major d'abast, tant per als tipus estructurats com per als `open_type`.
- Si existeix qualsevol assignació del tipus a `ProductVariantValue`, el canvi de BrandCode queda bloquejat en l'edició ordinària. També compten les assignacions dels SKU retirats que es conserven.
- Sense assignacions, el canvi es permet només si totes les associacions existents a `ProductGroupVariantType` continuen sent compatibles amb el nou abast. No s'eliminen associacions silenciosament.
- Per exemple, passar de NULL a ABC no és vàlid si el tipus està associat a un grup XYZ, encara que aquest no tingui valors assignats.
- La comprovació i el canvi s'han de fer atòmicament en una transacció curta, sense permetre que una assignació o associació concurrent invalidi la comprovació.
- Canvi excepcional assignat: fora GUI, procediment protegit només per identitat SQL d'administració autoritzada, mai compte ordinari variants. Requereix impacte/autorització previs i compatibilitat de totes les associacions; si alguna incompatible, rebuig. No elimina associacions/valors ni canvia codis per forçar compatibilitat. Canvi i auditoria abans/després atòmics en transacció curta. Via aprovada, SQL/permisos/proves pendents.

### 22.5 Càrrega externa i conciliació tolerant a errors

**Actualització D415–D416:** lectura completa a memòria D407 intacta/còpia10; variant9 ara sense LineCode i amb ReviewedSourceJson. Alta inclòs retirat admissible: grup propi provisional/referència i marca revisadesNULL. Existents: decisions/correccions/revisió conservades; no es generen tasques físiques o revisió automàtica. ReconcileSku ja confirmat en conversa, formalització global pendent fora d'aquest lot; no SQL executable (§30/model§6.48).

**Conciliació des de la còpia**, completa o parcial d'una/diverses CMARQ, manual o programada: idempotent, una execució i zero sessions vigents. Un SKU admissible encara sense variant rep ProductVariant/grup propi actiu provisional i auditories atòmiques; la còpia ja existeix i no s'escriu. Risc inicial sustentat o NULL, IsValidated=0; no aprovació comercial. Intactes/històrics no es recreen; decisions/IDs/valors preservats. Abast parcial no modifica marques alienes. SourceIsPresent i absències són externs, no actuacions del batch. Balanç de processament i diferències de cobertura a §22.48/model §6.39.6.

El batch el llança manualment el personal autoritzat o el Planificador de tasques de Windows; l'app no incorpora planificació ni reintents propis. Hi ha **exclusió global amb les sessions d'usuari**: si n'hi ha una d'activa, el batch no arrenca, finalitza amb codi de sortida **0** i deixa al log tècnic constància explícita de «no executat» i del motiu, sense presentar-ho com a conciliació completada. Mentre el batch corre no es permet obrir sessions d'usuari. Si s'ha omès, una execució manual o una futura tasca planificada el tornarà a intentar per mitjans externs. Això no impedeix les exportacions als clients; el control atòmic d'inici batch/inici sessió resta pendent de proves.

**Contracte de còpia D230–D232, frontera D361–D367 actualitzada D379:** mateixa PK `(CMARQ, CCATEG, CPROD)` i vuit noms/tipus: CMARQ/CCATEG/CPROD NVARCHAR(3/2/3) NOT NULL, CLIGNE NVARCHAR(2) NOT NULL, DESIGN1 NVARCHAR(18) NOT NULL, DESIGN2 NVARCHAR(18) NULL, code1 NVARCHAR(13) NOT NULL, code2 NVARCHAR(1) NULL; SourceIsPresent BIT NOT NULL DEFAULT(1) local i **externament mantingut**. Història acumulada, no DELETE. App només lectura; CLIGNE recent pot diferir de LineCode classificat. Text/French_CI_AS preservats, NOT NULL de code1 no prova quantitat vàlida. Noms/mestres/EAN/preus no s'afegeixen a la còpia; auxiliars autoritzades conservades. Canvis futurs de metadades exigeixen revisió/avís, no truncament. Absències fiables amb càrrega global completa i integritat de producció són responsabilitat externa, no escàner original de l'app. Procés reunit a §23.

Per crear el nom inicial modificable del grup, després de numerar-lo, s'utilitza `PARKOD.NOM_MARQUE + '_' + PARKOD.NOM_LIGNE + '_' + CATEGORY.CategoryName + '_' + ProductGroupId`. Marca/línia provenen del SKU creador i categoria de `CATEGORY.IDCategory = PARKOD.CCATEG`. Si falta una fila o denominació (NULL/buit/blancs), el component corresponent passa a CMARQ/CLIGNE/CCATEG; no s'afegeix fallback a BRAND/LINE ni es tria una altra fila/SKU arbitràriament. Un nom absent no rebutja per si sol el SKU. Si el resultat normalitzat supera NVARCHAR(150), s'utilitza `CMARQ_CLIGNE_CCATEG_ProductGroupId`. Només es genera en crear el grup i no se sobreescriu a la sincronització. Fallada d'accés o ambigüitat no equivalen a nom absent. Només es desa el nom de grup resultant, no les denominacions font com a camps addicionals.

`code1` només accepta dígits ASCII amb punt decimal opcional i dígits als dos costats, sense signes, comes, blancs ni exponents. Lectura exacta DECIMAL(18,3), sense arrodonir: 50.0000 equival a 50, 50.0001 rebutjat. code2 exactament L→volume/ml, G→weight/gr, U→count/unit; NULL/buit/l/altres rebutjats sense U/1. Quantitat >0/entera per U; això no imposa positivitat als valors generals de catàleg. Error de tractament: log anglès/rollback de l'operació/prèvia classificació conservada; l'app no repara ni restaura la còpia actual externa.

D415 retira correccions de línia: la revisió de font contrasta còpia local/context i captura fotografia+marca en transacció curta/auditoria. No escriptura de còpia, lectura original de classificació o transacció durant formulari. Canvi rellevant de context exigeix nova revisió; canvis posteriors tornen a deixar font pendent, sense alterar grup/assignacions/flags (§30/model§6.48).

1. Llegir còpia local disponible/coherent dins de l'abast, sense canviar els seus nou camps o rellegir l'original per conciliació.
2. Tractament de dades pròpies atòmic per operació en transacció curta, no tota l'execució.
3. Error individual conegut: rollback només de l'intent/log anglès/continuar quan segur, conservant decisions.
4. PK de còpia garanteix unicitat; integritat periòdica/duplicats originals i càrrega són externs, cap SourceSkuOccurrenceCount de l'app.
5. SourceIsPresent es consumeix tal com publicat; rebuig d'admissió o incidència no calcula una retirada ni elimina història.
6. Variant/grup/assignacions/validacions conservats; canvi de qualsevol dada font inclosa CLIGNE activa pendent per dates, fotografia anterior conservada fins revisió expressa. No discrepància CLIGNE–LineCode.
7. Infraestructura incompleta: aturada/resultat fallit, cap èxit fictici o rollback de COMMIT previs. Última operació incerta continua incerta, no reenviament automàtic.
8. Resum de resultats sense doble recompte o transicions externes inventades. Cobertura individual D371–D373 resolta, parser/comparador/proves pendents.

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

Principal d'una associació del mateix grup marca–ID, compatible amb VariantType.BrandCode; FK grup/marca/PrimaryVariantTypeId a associació grup/marca/VariantTypeId. No barrejar marques amb mateix número de grup. Tipus principal compartible per diversos grups, sense duplicar definició o principals alternatius per client.

El recompte és per VariantTypeId habilitat, no pel text Type: si Size/letter i Size/cms estan tots dos finalment habilitats, compten com dos tipus i cal selecció tècnica del principal, encara que tots dos s'anomenin Size.

Quan falta el principal obligatori o no és vàlid, es bloqueja l'exportació del grup i es rebutgen els canvis ordinaris que deixin un estat final invàlid. Es permeten les operacions correctives necessàries per definir-lo. Afegir o retirar tipus, canviar el principal o traslladar SKU requereix revalidació atòmica en una transacció curta, sense transaccions obertes durant l'edició del formulari.

No es pot retirar l'associació seleccionada sense deixar un principal coherent amb els tipus resultants en la mateixa operació. Amb més d'un tipus no s'escull arbitràriament el primer ni se substitueix silenciosament una selecció tècnica vàlida. El principal no elimina altres tipus, valors o SKU, ni els fusiona.

Un grup amb diversos SKU però sense tipus definits continua pendent de classificació: tenir el principal NULL no autoritza l'exportació. Disposar d'un principal vàlid tampoc garanteix, per si sol, que tots els SKU tinguin valor o siguin distingibles en una destinació amb una sola característica. Els controls específics del connector s'hauran de concretar sense alterar ni perdre la classificació interna.

La columna admet NULL per representar zero tipus, però és funcionalment obligatòria quan n'hi ha un o més. La FK composta ha estat acceptada com a disseny; el seu DDL i els controls SQL/transaccionals de recompte, selecció tècnica i bloqueig continuen pendents de validar a l'etapa 0. No s'ha implementat cap d'aquests mecanismes.

### 22.8 Primera validació i lectura pels programes Parkod

Per primera vegada un ProductGroup només és exportable quan se n'ha validat la creació/configuració, **té almenys un SKU present i aprovat**, el tipus principal està informat i és vàlid, tots els VariantType habilitats al grup estan validats i **tots els SKU incorporats que s'exportaran** tenen un VariantTypeValue assignat i validat per **cada** tipus habilitat. No n'hi ha prou amb el valor del principal. El tipus es pot aprovar abans d'acabar els valors dels SKU, però el grup no esdevé exportable només per això. Es conserven grups buits; aquests i els grups amb només SKU retirats no s'exporten.

D330 explicita també IsActive=1 a la lectura de variants pel generador existent. No nou veto global de SynchronizationStatus, exportador/vista o escriptura a parkod; integració/proves pendents. Activitat no substitueix cap validació ni garanteix exportabilitat.

«Complet» es refereix als SKU **coneguts, incorporats i presents** a l'origen, no a un inventari hipotètic de SKU encara desconeguts. Els SKU amb `SourceIsPresent=0` es conserven per traçabilitat, però s'exclouen tant de l'exportació com del control de valors que en determina l'exportabilitat. Un SKU nou detectat com a possible membre d'un grup existent no n'atura l'exportació: fins que s'aprova la pertinença i els valors, el grup continua exportant-ne els membres validats, sense incloure el candidat. La introducció pendent no invalida el grup que ja era exportable.

El generador existent llegeix codis/tipus/característiques/valors comercials validats de VARIANTS_PARKOD, sense rèplica d'assignacions a l'original o exportador nou. D415 no conserva línia anterior operativa: si cal línia local actual, és Parkod.CLIGNE, no ReviewedSourceJson/auditoria. Grup/valors/codis aprovats es mantenen durant font pendent, sense veto general nou. SNAPSHOT inicial curt només nova base/lectures originals separades/protocol pendent, sense NOLOCK o coherència interbases presumpta. Independent de càrrega/batch/validació, indicadors0 informatius, retirats exclosos; integració/permisos/proves pendents, cap SQL legacy canviat.

L'adaptació del lector ha de respectar ValueKind i el camp informat, no deduir «numèric» només perquè Type no sigui open_type. Això no autoritza canviar el format legacy ni afegir un exportador a l'app; integració i proves encara pendents.

### 22.9 Comptes, sessions i edició concurrent

Els tècnics s'identifiquen amb **comptes propis de l'aplicació**, no amb comptes Windows. Un administrador gestiona comptes/permisos; validacions per tècnic identificat. Linux només és possibilitat futura, no substitueix Windows Server 2019/SQL Server 2017 Express. **Una sessió activa per compte:** segon intent rebutjat sense expulsar l'anterior. Caducitat de **30 minuts d'inactivitat per defecte**, parametritzable fora GUI; allibera reserva i descarta edicions manuals no validades.

AppAccount/AppSession i camps/claus aprovats al diccionari. Una sola pantalla/grup per usuari amb reserva opcional exclusiva a la mateixa AppSession, sense transacció de formulari ni bloqueig de consulta/generació. Tokens aleatoris només com hash SHA-256, contrasenyes Argon2id. Només interacció real renova activitat, no heartbeat; neteja per demanda. IsActive=0 impedeix login però no expulsa sessió; retirar IsAdmin elimina permisos administratius immediatament. Qualsevol restabliment de contrasenya sí revoca sessió/reserva. Batch i sessions globalment exclosos, també per marques. Procediments/permisos/proves pendents.

RDS/RemoteApp amb compte Windows propi i instància d'app per sessió, AppAccount i token de 32 bytes segons §22.20. Windows no és AppSession ni substitueix token. Confiança interna i Argon2id en Python confirmats; permisos/connexió/proves pendents, no la decisió d'autenticació. Sense servei central.

### 22.10 `ParkodVariantCode`: codi extern de l'habilitació grup–tipus

ParkodVariantCode NVARCHAR(5) identifica habilitació grup–tipus, no SKU/grup/valor o VariantType global; únic per marca entre totes les habilitacions actuals/retirades. Identificador extern BrandCode3+codi5=8, derivat sense columna nova; SKU original intacte. No ProductVariantCode nou o reutilització de CPROD per grup d'un sol SKU.

**S'assigna al final de fase 3**, amb valors requerits validats, reserva i principal coherent en una mateixa transacció. La fase 2 pot tenir IsValidated=1/codi NULL; no és habilitació final. Validesa final exigeix indicador i codi. Un cop assignat, immutable i mai reciclat; registre permanent conserva reserva/habilitació després de retirada. Nova habilitació de la mateixa parella consumeix codi nou. Retirada bloquejada amb assignacions referenciades o principal invàlid. Sense codi disponible es rebutja finalització atòmicament, GUI francesa/log anglès. Substitueix l'assignació anticipada de D93.

D382–D383: primera assignació **DE000** per marca, increment ASCII0–9/A–N/P–Z fins a **ZZZZZ**, sense retorn a00000 o reciclatge. Sense blocs disponibles/prohibits, taula ParkodVariantCodeBlock retirada sense substitut. Màxim ordenat del registre complet de marca+successor protegits per coordinació SQL, unicitat i transacció atòmica amb habilitació/principal/auditoria. Esgotament rebutja sense estat parcial, no MAX+1 desprotegit o reserva durant formulari.

Exactament cinc ASCII majúsculs senseO, text/zeros preservats. **D444–D445:** CCATEG alfanumèrica, separació basada en reserva externa(categories < 'DE'), no en categoria numèrica. Carregador detecta anomalies de reserva/O i informa tècnics§23.2.1; DE inclòs al rang reservat. Sense control de col·lisió/reserva/O dels originals nou al gestor o font alterada. D389rebuigCPROD/correu retirats, resta d'admissió/logs intacta. SQL/concurrència/provesE06 pendents.

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

D389 retira rebuig/incidència/correu urgent CPROD d'antics blocs; no notificació nova en substitució. Resta de controls/logs i integritat periòdica original externa D360 intactes. Notes històriques SMTP no creen un motiu nou d'enviament o FailReconciliation després de Complete.

Durant incorporació inicial, batch complet desactivat al Planificador extern; marques principalment manuals. Després activar completa. Operativa habitual nocturna recàrrega → conciliació; revisió humana l'endemà i generador Parkod manual posterior, sense convertir aquesta seqüència en bloqueig global de la generació independent.

### 22.14 Auditoria física i administració excepcional

EvaluationAuditEvent té camps i contractes dels casos aprovats al diccionari (§3.11): EventKind proposal_decision/confirmed_change, ActionName controlat proposal_review/create/update/retire/password_reset, autor user/process, àmbit/clau, originals, resultat i snapshots. Decisions de proposta exigeixen humà. Una entrada per objecte/decisió amb OperationId compartit; snapshots complets, sense secrets, alta només posterior i eliminació només anterior. Rebuig sense canvi no té snapshots. Rebuig amb eliminació de candidata és una sola entrada proposal_decision/proposal_review/rejected, amb Before complet, After/resultat NULL i auditoria abans del DELETE en la mateixa transacció. No purga, lectures, esborranys ni SKU intactes. Controls SQL, procediments i casos addicionals pendents.

Només administrador restableix contrasenyes, sense funció de canvi propi per tècnic. Qualsevol restabliment revoca sessió/reserva; única excepció de confirmed_change amb ambdós snapshots NULL, acció password_reset i cap secret a la traça. Impedir atòmicament desactivar/retirar IsAdmin de l'últim administrador actiu.

Bootstrap fora GUI només amb AppAccount buit i identitat SQL d'administració autoritzada, mai compte ordinari variants; primer compte actiu/administrador, Argon2id sense contrasenya predeterminada i auditoria process/bootstrap en mateixa transacció. Recuperació excepcional amb identitat SQL administrativa autoritzada, fora GUI: administrador existent, contrasenya nova i sessió/reserva revocades; no modifica IsActive/IsAdmin ni crea comptes; auditoria process/admin_recovery/password_reset. No compte/contrasenya permanent de reserva. Via excepcional BrandCode definida a §22.4 amb els mateixos límits de permisos, impacte i auditoria, no accessible des de GUI ordinària.

### 22.15 Originals, resultats i claus JSON confirmats

El contracte canònic dels casos confirmats és a DATA_MODEL.md §3.11.1–3.11.5 (D143–D155/D159/D165–D167, ampliat per D171–D172 i els casos de substitució). No són nous camps SQL ni estructures desplegades.

- **Fonts:** OriginalSourcesJson és una llista `{source, records:[{source_identifier, raw_value}]}`. source identifica la taula realment llegida: VARIANTS_PARKOD.dbo.Parkod per a la còpia, parkod.dbo.PARKOD per a l'original; raw_value conserva noms i dades observades. [] és absència expressa de fonts; SQL NULL és no registrat/no aplicable.
- **Propostes:** grup–tipus conserva grup/tipus, Type, Characteristics i ValueKind; SKU–valor conserva SKU/grup/tipus/valor, textos i ValueKind/NumericValue/TextValue. No convertir aquests textos històrics en noves columnes replicades. Pertinença identifica el destí; creació de grup, configuració i conjunt ProductVariantIds amb ID de grup JSON null, almenys un SKU real i sense duplicats.

**Formes actuals D415–D416:** grup–tipus7/creació4/SKU–valor11 intactes; membres de proposta grup–tipus nomésProductVariantId. Pertinença4/5si nom proposat en grup nou, LineCode retirat sense substitució per CLIGNE/fotografia. Notes antigues de línia superior/pròpia i exemples amb LineCode són història, no entrades actuals. Originals/snapshots literals; referència informativa nova explicitada §30/model§6.48.
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

**Etapa0 oberta:** D394, model13/90 i matriu §24.2 consolidats. Base76 noms, contractes exactes afectats E02/E03 pendents. Càrrega/avís/coberturaD373 conservats; bloqueig ordinari de pertinença amb línia pendent ara **confirmat D390**, no reobrir. Resta E01–E11 al model §7, sense SQL/etapes1–4 o APIs noves inventades.

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

**D404 posterior:** en el circuit complet, línia discrepant coneguda al context revisat no bloqueja per si sola retirades/rebutjos individuals expressos d'assignacions d'A i retirada de l'associació A. Incidència pendent/sense LineCode-grup-validació de pertinença canviats, admissibilitat pròpia de cada retire/reject i altres controls/atomicitat intactes. Si B necessita codi NOU, D392 exigeix línies resoltes dels requerits; si ja té codi propi, conservar-lo. No transferir/reciclar el d'A, cap permissió universal de retirades (§27.1/model §6.45.1).

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

**D237 adaptat D380:** marca NVARCHAR(MAX)/grup INT als dos procediments, sense @CategoryCode; context/decisions/A/B/principal/tipus-ordre-defaults intactes. Marca exactament3 abans de convertir/ID positiu. Lector una fila ContextJson/set blocs actuals grup7-associacions8-assignacions9/membres amb categoria-línia pròpies. No D237 a reaprovar o SQL provat; altres formes E02 encara pendents.

Set blocs exclusius de substitució segons model §6.11.4, membres amb LineCode propi/CLIGNE-SourceIsPresent locals, no línia de grup o risc de pertinença afegits/lectura original. D404 permet desajust conegut sense resoldre'l; D392 abans de codi nou intacte. Assignació B absent JSONnull explícit, pendent és fila completa/no {}, absència o manca de validació requerida bloqueja transició. Originals imbricats, sense duplicats/columnes noves.

Èxit: una fila **post-COMMIT**, OperationId UNIQUEIDENTIFIER, ParkodVariantCode **NVARCHAR(5)** final de B i PrimaryVariantTypeId INT final, tots informats. Principal pot ser altre tipus habilitat. Resultat/auditoria generats per SQL i capturats dins de l'operació.

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

**Adaptació directa D380 consolidada:** tres signatures grup–tipus sense categoria, context de quatre blocs grup7/associació8/tipus5/membres reduïts amb categoria-línia pròpies. Tres signatures SKU intactes/set blocs amb grup reduït3/associació5/assignació9. D245–D248 i efectes de cada circuit conservats, no totes les formes E02 adaptades (§27.2–§27.3/model §6.45).

**D400 posterior:** rebuig de candidata SKU–valor D244 i grup–tipus D247 permesos amb discrepància de línia coneguda; efectes/condicions pròpies intactes. D396/D402–D403 continuen impedint actuació dependent amb dades indisponibles. Detall dels vuit rebutjos contrastats al model §6.44.1, resum §26.1.

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

**Context grup–tipus D246 adaptat D415:** quatre blocs ProductGroupVariantType/ProductGroup/VariantType complets i ProductVariants de tots els membres reals amb ID/codisSKU/grup/IsValidated/Parkod, sense LineCode/risc/fotografia al reduït. Parkod de la forma ampliada confirmada en conversa inclou set dades font. Retirats/pendents/[] només buit real/nullable explícits/originals imbricats conservats. No confondre amb editorials o substitució.

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

**Contrast E02 consolidat:** alta manual/principal/finalització sense categoria a signatures; grup7/associacions8/assignacions9 segons el context propi. Resposta de finalització OperationId/codiNVARCHAR(5)/principalINT. Quatre blocs d'alta, tres de principal i sis de finalització conservats, no contextos intercanviables (§27.2/model §6.45.4).

**D401:** l'alta manual AddGroupVariantTypes també admet discrepàncies de línia conegudes, només tipus existents compatibles/grup existent i altres condicions D273–D275 intactes. Incidència pendent, no pertinences/valors/línies/principal/codi nous, disponibilitat D396 conservada (§26.1/model §6.21).

**Actualització D381–D394:** codi5 per marca i línies requerides resoltes abans de codi nou; fase2 permesa amb incidència coneguda. Retorns/contextos de grup a continuació són base D379 per adaptar E02, no forma nova ja aprovada. Principal i separació entre fases conservats.

dbo.AddGroupVariantTypes aprova manualment 1+ associacions noves a **un grup existent**, amb tipus de catàleg existents compatibles. Lot no buit/sense duplicats, totes o cap; associació ja existent, també candidata, exigeix revisió, no s'ignora ni s'aprova silenciosament. Cadascuna 1/codi NULL/risc/originals NULL, una auditoria create per fila amb OperationId comú. No nous tipus/valors, codis o principal. Resposta: OperationId, després totes les associacions completes, una per tipus. El lector té quatre propietats; no és el de candidata persistent singular.

dbo.FinalizeGroupVariantType finalitza **una** associació 1/codi NULL amb context de sis propietats i valors requerits validats. Donar un codi nou exigeix almenys un SKU present amb pertinença validada; zero requerits es pot mostrar però bloqueja finalització. No revoca codis anteriors si el grup després queda buit/retirat. Codi nou, principal i auditories atòmics, sense codi reservat durant pantalla ni consum concurrent com a conflicte. Resposta OperationId/codi/principal finals informats.

El principal compta només 1/codi informat, no SKU ni valors; fase 2 no l'altera. dbo.SetProductGroupPrimaryVariantType és selecció expressa independent amb lector de tres propietats: argument obligatori sense default, NULL només amb zero finals, un final obliga aquell ID, diversos exigeixen un final compatible. No confondre aquest NULL amb SelectedPrimary opcional de finalització/substitució, que significa sense nova tria. Només canvia principal, risc/IsValidated intactes. Resposta OperationId+grup complet; mateix principal vàlid després de totes les comprovacions, cap UPDATE/auditoria i OperationId resposta NULL. Lectura permesa per corregir principal invàlid, sense forçar cap selecció arbitrària.

### 22.31 Trasllats, creador i decisions de creació conjunta

Grup origen de trasllat derivat de pertinença real del SKU, destí complet existent; no nou grup o correcció de CLIGNE per aquest contracte. Context de set propietats amb SKU complet/còpia, dos grups amb composicions/associacions, totes les assignacions del SKU i catàlegs. No valors dels altres membres. Manual sense proposta: nous originals/risc d'entrada NULL i risc de pertinença nova NULL, no antic risc ni 0; amb proposta, originals del backend i risc presentat preservats, SQL determina accepted/corrected. Dades/rèpliques/auditories atòmiques i dos conjunts de resposta: OperationId+SKU complet, després assignacions completes; buit no omès.

Creació conjunta: @CreatorProductVariantId explícit/seleccionat/aprovat, no primer d'array o mínimID. Grup de la seva marca/numeració per marca, **sense categoria/línia comunes heretades** D380; les dades del creador continuen servint per a les fonts del nom. ProductGroupNameNULL demana nom automàtic després d'assignar número; manual normalitzat/no buit/<=150/sense sufix. Fallback compacte només automàtic, nul·litat física/edició posterior intactes; protocol fiable de lectures de noms encara pendent, no SNAPSHOT original.

Context de cinc propietats amb seleccionats complets i grups actuals/composicions reduïdes/associacions, assignacions seleccionades i catàlegs. Els seleccionats poden venir de grups provisionals o comercials diferents: no equivalència ni fusió de grups sencers. Repetició del SKU complet i dins de composició reduïda és solapament JSON, no duplicació SQL. Només els aprovats es traslladen, resta roman i grups buits es conserven; si ja hi ha grup correcte, es pot fer trasllat a existent en lloc de crear-ne un altre.

Arrays separats d'aprovació d'associacions i decisions approve/reject per SKU, cadascun amb originals/risc propis. Manual sense proposta exigeix originals/fonts/risc null; approve confirma pertinença amb risc presentat o NULL, reject necessita original i conserva estat anterior. Almenys un aprovat i creador entre ells; no alta buida. Tipus necessaris per conservar assignacions aprovades explícitament inclosos, no herència o rebuig per omissió. No convertir un esborrany descartat en rebuig humà.

Grup nou validat, associacions aprovades sense codi, trasllats i rebutjos explícits en transacció curta/OperationId comú. Originals finals dels arguments només del grup, mai propagats a membres/tipus. Quatre conjunts: OperationId+grup, SKU traslladats, associacions creades, assignacions preservades. N tipus → N files del tercer conjunt; zero només si no es necessiten per valors conservats. Rebutjats auditats però no retornats com a SKU/assignacions modificats. No catàlegs nous ni finalització implícita: per si sol no fa exportable el grup.

### 22.32 Rebutjar una proposta no és eliminar una classificació vigent

**D400:** els quatre rebutjos no persistents d'aquest apartat permesos amb discrepàncies de línia conegudes. Només auditen decisions expresses, classificacions vigents intactes, incidència pendent; D269–D272/controls/context i disponibilitat D396 conservats. Cap aprovació de pertinença per aquesta permissió, D390 intacte (§26.1).

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

**D400:** rebutjar proposta nova sobre valor validat (§6.23.5 del model/D282) admès amb discrepància coneguda; fila/risc/validació/originals/catàlegs íntegres, auditoria de nova proposta rebutjada, no DELETE com a candidata pendent. Incidència pendent, D396/altres controls conservats (§26.1).

Quan una correcció efectiva canvia el valor: amb proposta nova acceptada/corregida, la fila rep risc/originals nous del backend; manual sense proposta, aquests tres camps SQL NULL. IsValidated=1, estat anterior complet amb antics originals a Before, història intacta. No utilitzar JSON antics de la fila com a originals d'una proposta nova ni reescriure els nous amb correccions/IDs generats.

Mateix ID final actual després de totes les comprovacions: manual sense proposta deixa fila/risc/originals intactes, sense UPDATE/auditoria, OperationId de resposta NULL. Nova proposta expressament revisada també deixa fila intacta però registra accepted/corrected amb originals/risc nous i resultat real a auditoria, snapshots SQL NULL i OperationId informat. És una decisió nova, no lectura rutinària d'un SKU intacte; snapshots NULL no volen dir fila absent ni amplien l'excepció password_reset de confirmed_change. NewValueJson duplicant un valor no es transforma en no-op: conflicte/revisió.

### 22.35 Revisió D240–D247 i límits de la consolidació

D240 i sis signatures de candidates contrastats amb conversa/diccionari: dos conjunts de candidata, defaults/ordre/tipus, quatre blocs grup–tipus i rebuig D247 intactes. D247 revisat inclòs amb aclariment d'error tècnic versus resultat incert. El context SKU complet es confirma per D248, no per reescriure l'aprovació parcial de D243. Noves entrades/respostes aplicades expressament als circuits respectius, no generalització automàtica a tots els casos.

14 taules/98 camps, claus i definicions físiques preservats; SQL Server 2017/French_CI_AS i frontera de no-intervenció intactes. **En el tall D284**, tipus nous sense IDs, contracte conjunt de rebuig sense membres aprovats i altres operacions no cobertes continuaven pendents; D285–D293 concreten després només els casos de §22.36–22.37. Comparadors, recursos de bloqueig, permisos, lectures de noms/integracions, DDL i proves humanament validades segueixen pendents. No codi, SQL o fonts/configuracions canviats; etapa 0 oberta. Dates de consolidació, no de cada confirmació ni autorització de desplegament.

### 22.36 Rebuig conjunt de propostes d'un grup nou

**D400:** també permès amb discrepàncies de línia conegudes, efectes D285–D289 intactes, sense crear/eliminar classificacions vigents o aprovar pertinences. Incidència pendent, originals/context complet/disponibilitat D396 conservats (§26.1).

**D285–D289; DATA_MODEL.md §6.25.** Una mateixa confirmació pot registrar només els rebutjos expressament marcats del grup nou, de pertinences i/o d'associacions proposades. Originals/fonts/risc independents per decisió, una auditoria rejected per decisió amb mateix OperationId, tot o res; cap canvi de classificacions vigents, catàlegs, comptadors o codis. Rebutjar grup no rebutja automàticament els fills, ometre no és rebutjar, i descartar esborrany manual no s'audita com a rejected.

RejectProductGroupCreationProposals rep context revisat, arrays de rebutjos de pertinença/tipus i objecte opcional de rebuig de grup. Arrays [] admesos, però almenys una decisió conjunta. Original objecte no nul obligatori, fonts array/null i risc exacte 0–100/null, IDs reals/ProductGroupId proposat null. No camp Decision perquè totes les entrades són rebutjos. Resposta només OperationId informat post-COMMIT, sense canvis parcials davant de conflicte detectat; incert segons D238.

GetProductGroupCreationRejectionContext deriva el context de cinc propietats de la unió dels membres originals implicats, no una selecció corregida més petita: SKU complets/còpia local, grups actuals amb membres/associacions, assignacions i catàlegs. Un sol SNAPSHOT curt només nova base, sense creador aprovat o acceptabilitat per crear: es rebutja. Fila requerida absent dona error, no context parcial. Els rebutjos individuals continuen existint; diverses crides independents no comparteixen OperationId automàticament.

### 22.37 Correcció de candidata A amb tipus B nou o existent

**D399:** els dos correctors permesos amb discrepàncies de línia conegudes. A candidata0/codiNULL/sense assignacions del grup/original; B nou o existent segons regles següents, metadades/auditories pròpies, B aprovada intacta. Incidència pendent, cap línia/pertinença/valor SKU/principal modificats o codi nou; no ampliar a A aprovada/amb assignacions. D396/altres controls intactes (§26.1/model §6.26).

**D290–D293; DATA_MODEL.md §6.26.** Només A candidata existent 0/codi NULL/sense assignacions al grup/original disponible. Substitució expressa, no retirada d'un tipus aprovat ni inferència perquè coexisteixin tipus complementaris. Amb assignacions d'A, usar el circuit complet §22.19/§6.11 del model: preparar B conservant A i revisar retirades individuals, sense conversió/còpia d'aprovacions.

**Garantia aclarida amb l'usuari:** si qualsevol SKU del ProductGroup revisat té assignació a A, encara pendent o retirat, aquesta correcció no és admissible. No s'elimina ni trasllada cap assignació per fer-la possible. Error amb rollback conegut conserva totes les assignacions a A, incloses les del grup revisat, A/B/catàlegs/historial sense canvis d'aquest intent. No rejected humana fictícia ni rollback presumptiu davant d'una connexió perduda; COMMIT aliens/anteriors preservats. Assignacions d'A en altres grups no s'alteren per corregir una associació admissible.

- **B nou:** NewVariantTypeJson amb exactament Type/Characteristics/ValueKind/BrandCode, sense ID/risc/validació/codi/valors inicials. Preparació només en memòria; normalització/unicitat vigents, col·lisió exigeix revisió. CorrectGroupVariantTypeProposalWithNewType crea tipus/associació B 1/codi NULL, elimina només associació A i conserva risc/originals d'A a B, amb auditories D177 atòmiques. Reutilitza expressament els quatre blocs del lector D246, definició nova separada; no catàleg A/usos eliminats.
- **B existent:** CorrectGroupVariantTypeProposalWithExistingType crea associació B si absent, aprova candidata B després de revisió dels seus originals D179 o conserva B ja aprovada completament intacta/sense auditoria fictícia. Originals no barrejats. Context confirmat de cinc propietats: ProductGroup, ProductVariants, VariantTypes, GroupVariantTypeToReplace, ReplacementGroupVariantType. Associació B absent JSON null, B pendent fila completa, no absència del tipus B de catàleg.

Cap valor SKU, codi nou o principal modificat pels dos correctors. Tots dos retornen dos conjunts d'una fila capturats dins de l'operació/post-COMMIT: OperationId+associació B completa, després VariantType B complet nou/existent. Signatures confirmades de disseny, no SQL. **GetGroupVariantTypeProposalCorrectionContext confirmat després per D294:** D293 n'aprovava només el context; D294 confirma expressament nom/signatura/resposta sense canviar la proposta. Una fila ContextJson de cinc blocs, SNAPSHOT curt local, cap canvi de negoci o auditoria de lectura; A candidata, no A ja aprovada.

### 22.38 Interfície App–SQL i abast de les confirmacions

**Tall històric D373 en el paràgraf següent:** després, D380/D386 deriven29retirades de categoria a signatures, quatre concretades D398 i altres25al lot§27/model§6.45. No interpretar «75altres intactes» com a inventari vigent D404; noms/funció/principis de transaccions i auditoria conservats, altres formes E02 pendents.

El capítol 8 de DATA_MODEL.md, «Interficie  App - motor SQL», preserva lectura/revisió/confirmació en transaccions curtes, captura interna i resposta post-COMMIT, tres fases/quatre validacions/valor compartit. Inventari de **76 procediments de disseny**, NormalizeWhitespace separada. Únic canvi d'arguments després de D370: JSON obligatori de Complete segons D373; 75 altres signatures i respostes intactes. Altres controls afectats per còpia externa pendents §6.40. Signatura no és implementació/signatura digital ni aprovació d'altres circuits. IsActive/G9/R5/història immutable, sense nous camps físics.

AppSessionId identifica sessió funcional, no transacció/connexió/RDS ni prova d'autenticació per si sol. SessionToken de 32 bytes només en memòria; SQL valida longitud abans de convertir i desa/comprova només SHA-256 a SessionTokenHash. OperationId generat per SQL agrupa auditories d'una operació atòmica, no tota la sessió/batch ni un identificador d'idempotència del client. No secrets als contextos/logs/auditoria; no-op amb OperationId de resposta NULL només on està expressament autoritzat, sense fila d'auditoria amb UUID NULL.

Cada COMMIT confirma la seva operació curta de dades/auditoria, no la pantalla ni el lliurament de la resposta. Cap transacció durant formularis/Argon2id; un COMMIT anterior/aliè no es desfà per error posterior, batch interromput no té rollback global presumptiu. Resposta capturada dins de l'operació i emesa post-COMMIT, pèrdua de connexió/resultat incomplet incert segons D238. Recuperació administrativa manual dins del seu abast, no fallback A/B extrapolat a tots els correctors ni restauració de snapshots. Etapa 0 oberta, cap codi/SQL executable/configuració/dada font modificada.

### 22.39 Substitució d'A aprovada sense codi per B candidata de fase 2

**D398, confirmació posterior:** una discrepància de línia coneguda no bloqueja per si sola aquest cas estricte, inclosa la retirada conjunta d'A. Totes dues associacions sense assignacions al grup; cap canvi de SKU/valors/línies/principal/codis, incidència pendent conservada. Disponibilitat segons dependència real D396 (§25.2); altres substitucions continuen exigint el seu contrast, no permissió universal. Contracte al model §6.27, no §6.27 d'aquest funcional.

**D295–D296; DATA_MODEL.md §6.27.** Concreta D180, no una regla nova de retirada: mateix grup existent, tipus A/B reals diferents/compatibles, A associació 1/codi NULL i B candidata 0/codi NULL amb original. Totes dues sense assignacions SKU al grup, també pendents o de retirats. Els valors de catàleg no assignats i usos en altres grups poden existir i es conserven. B absent/null/ja aprovada no entra en aquest circuit; no s'amplia el corrector de candidata A ni s'aplica la transició final amb codi.

GetGroupVariantTypePhase2ReplacementContext retorna una fila ContextJson/cinc blocs D293 amb estats diferents: ProductGroup7, ProductVariants, VariantTypes5, GroupVariantTypeToReplace8 i ReplacementGroupVariantType8. A aprovada/B candidata obligatòria-noNULL, membres retirats-pendents/Parkod local inclosos. Signatura sense categoria/marca exactament3/grup positiu, sessió-permisos-reserva-activitat i SNAPSHOT curt només nova base/tancat abans de revisar. Sense retirada/aprovació/auditoria de lectura.

ConfirmGroupVariantTypePhase2Replacement contrasta context en nova transacció curta; retira només associació A amb confirmed_change/retire, Before complet/After NULL, conservant l'aprovació històrica. Aprova explícitament B amb la decisió dels seus originals, mantenint risc/originals propis i codi NULL, sense copiar els d'A. Dues auditories/OperationId comú, dades/auditories atòmiques. Si apareixen assignacions o canvia context rellevant, rollback conegut conserva A/B/SKU/historial d'aquest intent, no rejected fictícia; COMMIT anteriors/aliens intactes i connexió incerta segons D238.

Resposta en dos conjunts d'una fila capturats dins de l'operació i emesos post-COMMIT: OperationId+associació B completa, després VariantType B complet existent. Sense catàleg nou, assignacions/pertinences SKU, codis o principal modificats. No finalitza fase 3 ni fa el grup exportable per si sol; aprovació tècnica de B encara sense codi. Explicació i signatures confirmades, no implementació ni autorització de DDL.

### 22.40 Cicle de sessió i comptes — D297–D313

Contractes complets a DATA_MODEL.md §6.28–6.29, sense servei central o model de confiança nous. CloseAppSession tanca només sessió/token vigents i allibera reserva, no Windows/RDS o decisions confirmades. RenewAppSession només interacció real i hora SQL, no heartbeat o renaixement. ReserveProductGroup només grup existent actiu/disponible, mateixa reserva conserva, altre grup requereix release explícit i reserva aliena error. ReleaseProductGroup allibera coincidència o conserva absència, altre grup error; no logout, la sessió encara exclou conciliació. Reserva/alliberament són lògics, cap transacció durant pantalla.

Adaptació D380: ReserveProductGroup/ReleaseProductGroup sense categoria, resposta segura quatre camps AppSessionId/ReservedBrandCode/ReservedProductGroupId/LastActivityAtUtc, reserva dos camps informats o tots dosNULL. GetAppSessionsForForcedClosure llista vuit camps; GetAppSessionForcedClosureContext manté AppAccount4/AppSession5 sense hashes i ForceCloseAppSession conserva signatura/duescolumnes de resposta. Admin vigent/altra sessió vigent/context actual, eliminació-reserva i una app_session/confirmed_change/retire atòmiques/Before segur5-AfterNULL. No contrasenya canviada/reserva transferida/candidates esborrades; finestra RDS pot seguir visible i següent crida detecta revocació.

**D305:** incidències d'aquest tancament forçat s'investiguen fora de l'app amb SQL administratiu autoritzat. No ampliació de GetUncertainOperationContext o lector nou de recuperació; resta de recuperació ja aprovada intacta. Avís/no reenviament/rollback no presumit. Idea de tancar totes les sessions/verificar inconsistències no és un procediment nou de manteniment o reparació autoritzat.

GetAppAccounts retorna els quatre camps auditables de tots els comptes, sense hashes; CreateAppAccount crea amb nom normalitzat únic també entre inactius/hash Argon2id extern/flags explícits, auditoria create i cap sessió automàtica. SetAppAccountAccess reutilitza la fila revisada, només flags amb protecció atòmica d'últim admin i autoedició admesa; desactivar no expulsa, retirar IsAdmin és immediat. No-op exacte després de controls sense UPDATE/auditoria/UUID.

ResetAppAccountPassword només admin, també propi; context quatre camps, no hash al context. Hash nou/revocació de sessió-reserva/password_reset atòmics, fins i tot hash igual, flags/nom/negoci intactes. Propi admin ha de tornar a entrar. Dos restabliments admissibles serialitzats, cadascun auditat, últim hash confirmat vigent; no idempotència o reenviament. Única auditoria password_reset amb snapshots NULL i cap secret/app_session extra. BootstrapAppAccount només SQL admin autoritzat/AppAccount buit, crea primer compte 1/1 i audita process/bootstrap. RecoverAppAdministratorPassword només SQL admin/admin existent, no compte/sessió nous ni canvi IsActive/IsAdmin, process/admin_recovery; no reactiva admin desactivat. Sense contrasenya predeterminada o compte permanent de reserva.

### 22.41 Abast de marca i ValueKind — D314–D317

DATA_MODEL.md §6.30 concreta la via D142 sense reobrir-la. GetVariantTypeBrandScopeChangeContext i ChangeVariantTypeBrandScope són SQL administratius fora GUI, no permisos ordinaris d'IsAdmin. Lector de quatre blocs editorials complets, una columna ContextJson, no canvi/reserva/auditoria; canvi amb assignacions exigeix impacte/autorització i context actual. NewBrandCode NULL és global; informat, CMARQ de tres caràcters i totes les associacions compatibles, també dels grups inactius. Només BrandCode/audit update process/variant_type_brand_scope_change, no eliminacions/codis/validacions/originals forçats.

SetUnassignedVariantTypeBrandScope és ordinari de tècnic, cap assignació pendent/validada/retirada enlloc, valors de catàleg no assignats no bloquegen marca. Context editorial quatre blocs, compatibilitat total; assignació apareguda exigeix revisió, no salt a excepcional. SetVariantTypeValueKind ordinari reutilitza quatre blocs, numeric/text/open_type textual: canvi només sense valors de catàleg ni cap associació IsValidated=1, també inactiva/fase 2 sense codi. No conversió/eliminació/desvalidació/default/collation o excepció D142. No-op coincident validat de ValueKind admès encara amb usos; no UPDATE/auditoria/UUID. Canvis efectius auditats/UUID i tipus complet post-COMMIT, sense afectar grups o SKU intactes.

### 22.42 Normalització interna i nom descriptiu — D318–D320

NormalizeWhitespace és funció interna NVARCHAR(MAX) → NVARCHAR(MAX), NULL conserva NULL, comportament Unicode White_Space/D48 intacte. No procediment GUI, camps d'aplicació nous, truncament o buit→NULL; límits/buit/unicitat es validen després. Signatura a DATA_MODEL.md §6.31, implementació/proves pendents.

SetProductGroupName (§6.32) sense categoria, consumeix exactament només bloc ProductGroup de **set camps** de D276/nom desitjat separat. Tècnic/sessió-token/grup actiu/reserves, nom normalitzat<=150/no buit/repetible/sense número afegit. **NULL deixa sense nom**, no generació automàtica d'alta. Sense fonts/reagrupació/aprovació o risc-validació-principal-tipus-valors-codis canviats. Una update/Before-After7/UUID i resposta UUID+grup7 capturats dins/post-COMMIT. Mateix nom exacte normalitzat després de controls: no UPDATE-audit/UUIDNULL; case/accents sí canvi real.

### 22.43 Grups buits i desactivació administrativa — D321–D325

**D380/D386 adaptats:** tres signatures sense categoria/grup7/marca–ID, selectors només marca o totalitat. Candidats7+HasActiveReservation calculat fora del context, resposta desactivació4/inactius7/ordre marca–ID. Resta de garanties/resultats/història conservats.

**ProductGroup.IsActive BIT NOT NULL DEFAULT(1)** és únic camp físic nou. No és IsValidated ni ocupació: quedar buit no modifica validació/risc. En destí buit, N SKU vàlids nous acceptats originen N variants/N grups propis provisionals actius, no N grups comercials aprovats. No recreació per conciliacions repetides o alta per files rebutjades. Reagrupacions posteriors poden deixar grups buits, conservats físicament; cost de fila/índexs/dependències dins d'Express, sense bloqueig SQL permanent pel fet de ser buits. No consumeixen codi només per existir, però codis anteriors es conserven.

Admin de l'app vigent pot desactivar actius **només sense cap ProductVariant assignada**, retirats-pendents inclosos, i cap reserva de sessió vigent també pròpia. No expulsar/alliberar/moure/esborrar per forçar-ho. Marca opcionalNULL=totalitat, informada exactament3/no buit; cap categoria deduïda d'un grup buit. Operació lògica/no DELETE/estalvi de dades o reciclatge d'IDs-codis, risc-validació-principal-associacions-història/integritat intactes. No reactivació aprovada.

GetEmptyProductGroupDeactivationCandidates: grup7+HasActiveReservation calculat/no camp físic, reservats inclosos per mostrar motiu. DeactivateEmptyProductGroup consumeix només ProductGroup7 i revalida estat actual/reserva, UPDATE IsActive1→0+audit atòmics. Resposta exactament OperationId/BrandCode/ProductGroupId/ResultCode; només deactivated informa UUID/audita. Cinc resultats i prioritat D330 després d'auth-forma/existència: already_inactive→context_changed→not_empty→reserved→deactivated. No error tècnic/canvi aliè com resultat controlat fictici.

Lot de transaccions curtes per grup/conjunt revisat no ampliat, controlats continuen/errors-incertesa aturen/sense reenvio. COMMIT previs conservats/no UUID o rollback globals/heartbeat/expulsió. Resum distingeix coneguts/no processats/incerts; no conciliació batch, exclusió batch-sessions intacta. Només canvi audita marca–grup/Before-After **set camps** 1/0/After objecte existent/altres camps intactes, no skips/fills intactes.

GetInactiveProductGroups: admin/històric/IsActive0/set camps/marca o totalitat/ordre marca–ID/sense filtre IsValidated. Sense mutació-reactivació-auditoria-UUID, no selector ordinari o prova d'autoria d'una petició incerta. Contractes model§6.33; cap dependència nova de Parkod per nom/principal/desactivació.

### 22.44 Cinc blocs d'adaptació transversal — D326–D330

**Formats del tall D379:** G9/R5 i clau antiga següents no són el diccionari actual. Grup complet7/reduït3 i reserva marca–grup segons D380/model §6.42.4; formes exactes E02. IsActive i història intactes.

Matriu completa dels **65 procediments** a DATA_MODEL.md §6.34.6, inventari de signatures §8.8. No nous paràmetres ordinaris IsActive o canvis de PK/FK/rèpliques/altres camps. IsActive només al grup, independent d'AppAccount.IsActive. Context actual complet G9 també als grups imbricats; R5 SKU–valor intacte amb control SQL. Context vell de vuit camps exigeix lectura nova, no assumir 1. Originals/JSON de fonts/snapshots històrics no reescrits; nous snapshots complets G9.

Operativa ordinària només IsActive=1, també per clau coneguda/admin/no-op; no filtre automàtic per tenir SKU o IsValidated=1. Actiu buit operatiu fins a desactivació expressa. Comprovació SQL dins de transacció/coordinació; grup desactivat durant formulari causa error sense canvi/auditoria/activació/redirecció o rejected humana automàtica. Revisió antiga invalidada; candidates persistents conservades no operables i propostes no persistents sense originals reescrits. No traslladar/incorporar a inactiu.

Catàleg: lector editorial retorna ContextJson quatre blocs complets i InactiveProductGroupsJson de presentació, mateix SNAPSHOT. Només claus completes de grups inactius referenciats/úniques/[] real, no cinquè bloc o paràmetre. GUI no mostra usos/enllaços/destinacions inactius; SQL manté compatibilitat BrandCode/bloqueig ValueKind històrics. No amagar tipus/valors compartits. Lector SQL protegit una columna/quatre blocs i editorial de valor tres blocs intactes.

Administració: GetUncertainOperationContext manté vies/permisos, grup inactiu existent com objecte G9/IsActive=0, no NULL; claus inalterades i D305 intacte. Alliberaments/revocacions/password reset i neteja de caducades login/batch no exigeixen grup actiu. Reserva caducada pot seguir físicament fins a neteja, no és vigent. No restaura snapshots o afegeix reactivació.

Concurrència: inactiu sense SKU ni nova reserva vigent, comprovació/canvi coordinats amb incorporacions/trasllats/reserves; ordre global/esperes finites/transaccions curtes, sense locks de formulari/taules deliberats. Conciliació nova/CLIGNE/descoberta/generador usen grups actius sense reactivar, alterar font, exportador, comptador, registre permanent o SynchronizationStatus. Client no inventa IsActive=1/[]/camps per resposta incompleta; mutació incerta no és fals èxit.

**Consolidació documental 2026-10-31:** D297–D330 incorporats després de totes les confirmacions dels cinc blocs. Diagrama/diccionari 14/99, signatures/contextos/flux/funcional/instruccions alineats; la matriu final no afegeix D331. Les notes històriques 14/98 i 44 signatures anteriors són talls passats. Revisió només documental, sense codi/SQL/dades/configuració/font/commit/push; la nova especificació exigeix contrast complet de totes les etapes, però només hi ha disseny d'etapa 0. DDL, permisos, comparadors, integracions, altres contractes no coberts i proves humanament validades continuen pendents.

### 22.45 Validar un grup existent sense reagrupar — D331–D334

**D391/D380 contrastats:** configuració validable amb línia coneguda sense aprovar membres. Dues signatures marca–grup sense categoria/quatre blocs/grup7-associacions8, membres amb categoria-línia pròpies; cap grup amb categoria/línia comuna vigent.

GetProductGroupValidationContext i ConfirmProductGroupValidation, signatures exactes al model §6.36. Tècnic ordinari/grup actiu/reserves/context; lector de quatre blocs ProductGroup complet, tots els membres reduïts amb Parkod local, totes les associacions i definicions dels tipus. SNAPSHOT local curt i sense valors/SKU assignats desitjats. El grup pot estar provisional, validat o buit.

Confirmar només IsValidated0→1/risc-nom-principal-relacions intactes, no fills aprovats o fases2–3 exigides. Buit actiu admès/integritat-principal-reserves comprovats. Una product_group/update/clau marca–grup/Before-After7/camps de propostaNULL; resposta OperationId nullable+grup7 capturada dins/post-COMMIT. Revisat ja1 després de controls no UPDATE-audit/UUIDNULL; canvi concurrent0→1 és conflicte/no no-op antic.

### 22.46 Validar una pertinença sense trasllat — D335–D337

**D390:** validació ordinària bloquejada fins a resolució de línia; corrector pot resoldre i confirmar conjuntament. D380 compatibilitat només marca; formes exactes del nou grup E02. La resta de validació sense trasllat es conserva.

GetGroupMembershipValidationContext/ConfirmGroupMembershipValidation, model §6.37. Una ProductVariant sempre té un únic grup actual: IsValidated=0 vol dir pertinença provisional, no absència de grup; 1 vol dir pertinença aprovada, no classificació/exportació completa. Passar per grups al llarg del temps es conserva a auditoria, no en pertinences actuals múltiples.

Grup derivat del SKU/actiu; grup encara provisional i SKU retirat admesos. Context cinc blocs: ProductVariant complet i els quatre del lector de grup, sense assignacions/valors, objecte un cop entre membres. Confirmació només flag/risc antic conservat, cap trasllat, línia o altre àmbit aprovats. Una group_membership/update amb grup actual real, snapshots vuit camps/actor verificat/camps de proposta NULL, resposta OperationId nullable+SKU complet post-COMMIT. No-op només amb revisió ja validada/control complet; context canviat exigeix revisió.

### 22.47 Històric retirat D415: correcció tècnica de línia

**Retirat del disseny actiu:** D415 elimina ProductVariant.LineCode i quatre signatures específiques. El text següent conserva D338–D347/D395, no vies actuals. Revisió de font §30 i moviments/creacions/validació pels circuits propis, controls/decisions/auditoria independents. No reconvertir automàticament correctors o desplegar-los buits.

**D395 concreta D384–D385:** mateix lector/confirmador de destí existent també per mantenir grup, sense tercera parella de procediments o flag nou. Mateix grup: pertinença1/risc conservat/assignacions intactes; altre existent o propi nou: nova pertinença1/riscNULL. Marca comuna D380, no categoria/línia comunes. Signatures actuals al model §6.38, implementació/protecció/proves pendents, no E03 funcional per decidir.

La càrrega externa ha canviat CLIGNE de còpia; ProductVariant conserva línia/grup/decisions fins a revisió. L'app només revalida **la còpia local**, no CLIGNE original ni les dades d'un client com a línia arbitrària. Si canvia context, error sense canvi/auditoria d'aquell intent, no reenvio o rejected humana fictícia. No no-op: cal correcció efectiva, no trasllat ordinari dissimulat.

- **Destí existent, també actual:** GetVariantLineCorrectionToExistingGroupContext/ConfirmVariantLineCorrectionToExistingGroup, model §6.38.2–§6.38.3, sense argument de categoria. Set blocs; SourceGroup i DestinationGroup complets amb el mateix contingut si coincideixen, mai null/omissió. Grup actiu de la mateixa marca, habilitacions preparades/compatibles; si falten, revisar sense crear-les o perdre assignacions. LineCode local revisat→SKU/pertinença1; mateix grup conserva risc, altre risc nouNULL. Grups/principals/codis intactes. Tres conjunts: UUID+SKU8, totes les assignacions9 (intactes si mateix grup) i còpia9 només llegida, capturats dins de l'operació/post-COMMIT.
- **Grup propi nou:** GetVariantLineCorrectionToNewGroupContext/ConfirmVariantLineCorrectionToNewGroup, model §6.38.4–§6.38.5. Únic SKU creador, grup de la seva marca/número per marca/actiu-validat/riscNULL/principalNULL, sense categoria/línia comunes. Línia final del SKU. Aprovacions exactament dels tipus assignats, [] si cap, associacions1/codi-risc-originalsNULL, sense herència automàtica. NomNULL automàtic/manual normalitzat<=150/no buit/no sufix, protocol auxiliar pendent. Sis blocs locals/cinc conjunts amb files actuals7/8/9, sense SourceParkod o destí futur fictici.

En tots els resultats SourceIsPresent intacte també0, sense veto nou per retirat; D396 tracta separadament còpia indisponible. Una group_membership/update amb Before/After complets i clau anterior real; mateix grup sense auditoria d'assignacions intactes, trasllat amb audit només de rèpliques canviades; create de grup/associacions només al propi nou. No audit parkod_copy, dades/còpia intactes o història reescrita. Cap codi/fase3/exportabilitat implícits; captura interna/post-COMMIT/incertesaD238 conservades.

Els contextos originals8/7 incloïen SourceParkod; D363 el retira i deixa7/6 locals ja aprovats. D395 no reobre aquell acord: només concreta reutilització per al mateix grup i els dos blocs coincidents. Files segons diccionari13/90, categoria/línia del SKU preservades, originals antics intactes. La disponibilitat D396, concurrència executable i noms auxiliars s'han de materialitzar/provar, no una nova API presumpta.

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

D415 retira la comparació CLIGNE–LineCode i el pendent separat de línia. Revisió general per dates; D416 mostra diferències de la font actual respecte dels sis valors de l'última revisió expressa, anteriors buits si no existeix fotografia. Sense història inventada o afirmació d'autoria per igualtat de valors. Corregir un valor no renova la referència ni marca automàticament la font com a revisada.

La llista mostra situació pendent, no crea reserves, validacions o auditoria de lectura ni obliga a resoldre-la tota abans de treballar. Es mantenen controls d'activitat de grup, permisos/reserves, caducitat i revisió actual quan s'entri al circuit corresponent. Sense assignació personal de tasques, noves taules/camps o historial d'estats de tasca pressupostos. Login dos passos i resposta CreateAppSession intactes; no transacció oberta durant presentació/revisió.

Principi d'aparició a cada login i categories **resolts**, no tornar a validar-los. D374–D378 concreten valors absents/finalització/retirats i avís durant càrrega/fallada a §22.54/model §6.41.4–6.41.5. Assignació absent no és candidata, ni fase 2 aprovada sense codi és pendent d'aprovar. Resta concretar consulta/resposta/elegibilitat restant i protecció de lectures; no signatura SQL nova o GUI desenvolupada fora d'etapa.

### 22.52 Corregir un valor encara que hi hagi línia pendent — D369

Es permet corregir un valor d'un ProductVariant dins del seu grup actual **sense exigir abans resoldre la discrepància de línia**. Un desajust CLIGNE/LineCode present al context revisat no bloqueja per si sol el circuit de correcció de valor del model §6.23, manual o amb proposta segons les regles existents. No aprovació separada de la línia per habilitar aquesta correcció.

No es dispensa cap altre control: sessió/permisos/reserva/grup actiu, classificació variant–grup coherent, habilitació/compatibilitat del tipus, valor vàlid/únic, context actual i atomicitat/auditoria. Si el context rellevant canvia durant la revisió, cal tornar a revisar; no és el mateix que una discrepància ja coneguda. Risc/originals/no-op/UUID/resposta continuen segons el contracte de correcció, sense nous paràmetres o estats.

Corregir valor no canvia grup/còpia/fotografia/marca revisada ni dona per revisada tota la font. No línia pròpia o audit de corrector. SourceIsPresent extern i controls propis d'elegibilitat/validació/trasllat/finalització conservats, sense permissió universal o veto general de font pendent (§30/model§6.48).

**Tall documental D368–D370 — 2026-11-03:** incorporats aquests acords i corregida l'etiqueta de pendent dels contextos locals 7/6 derivats. 76 signatures/funció i model 14/99 intactes. Aquell tall encara deixava cobertura/format de tancament pendents; resolts en disseny per D371–D373 a continuació, no els controls executables/altres consultes/GUI/proves. Etapa 0 oberta, sense SQL/dades/font/configuració, commit o push.

### 22.53 Cobertura individual i JSON de SKU no incorporats — D371–D373

**Criteri final confirmat:** per a cada SKU de la còpia dins de l'abast de conciliació, hi ha ProductVariant o una incidència d'admissió identificada per aquell SKU durant l'execució. Sense variant i sense explicació individual, no es pot declarar completed; no n'hi ha prou que quadrin sumes globals. Les incidències individuals controlades poden permetre completar amb avisos, però no infraestructura/lectura incompletes o resultat incert disfressats de motiu de rebuig. No DELETE, SKU invàlids o rollback de COMMIT anteriors per igualar recomptes.

CompleteReconciliation rep ara **@UnincorporatedSkuIncidentsJson NVARCHAR(MAX), obligatori sense default, abans de @BrandCodesJson opcional**. Set paràmetres totals; cinc recomptes d'entrada, tipus/default d'abast i resposta original de cinc columnes intactes. És un canvi exprés de la signatura D358, no un procediment nou: inventari 76, altres 75 signatures i NormalizeWhitespace preservades.

Array JSON transitori d'una entrada per SKU sense variant; cada objecte conté **exactament quatre propietats obligatòries**:

| Propietat | Contingut |
|---|---|
| BrandCode | String de 3 caràcters ASCII A–Z/0–9. |
| CategoryCode | String de 2 caràcters ASCII A–Z/0–9, zeros preservats (D444 substitueix D388). |
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

Avís separat del login, sense veto general/cache/refresc automàtic/lector nou. Línia coneguda segons D390–D394/D398, disponibilitat de les altres revisions ara segons D396 (§25.2/model §6.43.1): dependència real de Parkod, no tota l'app bloquejada. D369 conservat, context canviat sempre nova revisió; consulta/resposta exactes i altres criteris/proves de llista E08.

## 23. Procés de carrega de VARIANTS_PARKOD.parkod

### 23.1 Finalitat, noms i responsabilitats

**Capítol documental del procés extern, no especificació d'un carregador a desenvolupar dins del projecte.** Reuneix els acords de càrrega i el contracte d'entrada que consumeix Gestionnaire de Variantes. Nom físic complet de la destinació: **VARIANTS_PARKOD.dbo.Parkod**; el títol n'utilitza la forma abreujada demanada, no un esquema o taula nous.

| Procés | Entrada → sortida | Responsabilitat i abast |
|---|---|---|
| Càrrega externa | parkod.dbo.PARKOD → VARIANTS_PARKOD.dbo.Parkod | Externa al projecte; sempre completa, totes les marques (D379). |
| Conciliació de variants | Còpia Parkod → ProductVariant, grups i dades pròpies autoritzades | App; completa o per marques seleccionades, sense modificar la còpia. |
| Revisió humana de font | Còpia actual comprovada → ReviewedSourceJson + marca revisada | App, D416/§30/model§6.48; informativa, sense línia pròpia, còpia escrita o aprovació comercial implícita. |

L'únic origen del flux de càrrega és parkod.dbo.PARKOD. No CSV, exportació/transferència intermèdia, base intermèdia o recàrrega prèvia de producció exigits. Els fitxers de proves són evidències, no passos obligatoris del procés. Noms auxiliars de PARKOD/CATEGORY, navegació FAMILY i consulta EAN conserven els accessos autoritzats del model §5; no es copien com a part d'aquest procés ni s'amplien les fonts.

El carregador és l'únic propietari dels **deu camps locals** de còpia, presència/datafont incloses, i dels dos senyals Parkod de SynchronizationStatus. App només lectura, sense escàner de producció/reparació de càrregues. ReviewedSourceUpdatedAtUtc i ReviewedSourceJson són de ProductVariant, renovats només per revisió expressa, mai pel carregador. Generador independent, no exportador nou.

### 23.2 Contracte de dades de la còpia

Només es copien els vuit camps originals acordats; SourceIsPresent i la nova SourceUpdatedAtUtc són locals i mantinguts externament. Noms/funcions dels dos camps de dates nous confirmats; detall físic de tipus/precisió a confirmar, no aprovació implícita de DDL:

| Camp | Tipus i nul·litat aprovats | Tractament |
|---|---|---|
| CMARQ | NVARCHAR(3) NOT NULL | Marca, component de la PK; còpia literal. |
| CCATEG | NVARCHAR(2) NOT NULL | Categoria, dos caràcters ASCII A–Z/0–9D444, zeros preservats/PK/còpia literal. Reserva i absència d'O validades externament§23.2.1. |
| CPROD | NVARCHAR(3) NOT NULL | Producte, component de la PK; còpia literal. |
| CLIGNE | NVARCHAR(2) NOT NULL | Última línia carregada de la font; pot diferir de la classificació vigent. |
| DESIGN1 | NVARCHAR(18) NOT NULL | Denominació original, sense normalització ni truncament. |
| DESIGN2 | NVARCHAR(18) NULL | Denominació complementària, NULL preservat. |
| code1 | NVARCHAR(13) NOT NULL | Quantitat original textual, sense conversió o reparació; NOT NULL no acredita quantitat vàlida. |
| code2 | NVARCHAR(1) NULL | Unitat original textual, NULL preservat. |
| SourceIsPresent | BIT NOT NULL DEFAULT(1) | Estat de presència determinat exclusivament pel procés extern. |
| SourceUpdatedAtUtc | Data UTC confirmada; DATETIME2(3) NOT NULL proposat | Marca d'alta/inicialització/canvi real dels sis camps de §29.2, inclosa retirada/reaparició; no data de cada recàrrega idèntica o revisió humana. |

PK `(CMARQ, CCATEG, CPROD)`. SKU textual3+2+3 amb tots tres components ASCII A–Z/0–9D444, zeros preservats/sense separadors o conversió; no ProductVariantId. CLIGNE no forma part de la FK SKU–còpia ni és línia pròpia deProductVariantD415. Càrrega no trasllada o valida comercialment res; controls específics de codis originals externs§23.2.1.

French_CI_AS als vuit camps copiats segons el contracte font acceptat; noms, tipus, longituds i nul·litat canònics al model §3.1/§5. No copiar noms de mestres, preus, EAN, país o altres camps. Canvi futur de metadades requereix avís i revisió d'impacte, mai truncament/adaptació silenciosa. code1/code2 es copien literalment: interpretar quantitats/unitats és un tractament separat de l'app, no una conversió durant la càrrega.

#### 23.2.1 Validació de codis durant la càrrega externa — D444–D445

L'aplicació externa **aprofitarà la càrrega per validar els codis de marca (CMARQ), categoria (CCATEG), producte (CPROD) i línia (CLIGNE)**. Només caràcters ASCII **A–Z i 0–9, sense la lletra O**, amb les longituds establertes3/2/3/2, respectivament. CCATEG és alfanumèrica encara que actualment no s'hi utilitzin lletres; no restringir-la a dígits o convertir-la aINT.

Per a les categories comprovarà també **CCATEG < 'DE'**: DE queda inclòs dins del rang reservat; una categoria >= 'DE' és anomalia, no només una categoria > 'DE'. L'usuari confirma l'existència de la reserva; la separació amb els nous codis DE000…ZZZZZ depèn de respectar-la, no del caràcter numèric de les categories actuals.

**Les anomalies detectades es comunicaran als tècnics**, sense corregir automàticament els codis originals. Funcionalitat de l'app externa de càrrega, no del gestor de variants: no nou escàner de producció, circuit d'avisos, filtre d'admissió deSKU o CHECK de reserva/O originals al gestor. No reactivar el rebuigCPROD/correu antics retiratsD389. Canal d'avís i tractament del lot/files invàlides no queden decidits per aquesta anotació: no inventar bloqueig, exclusió, retirada automàtica o èxit de càrrega parcial. La càrrega completa fiable, publicació i SourceIsPresent, coordinació i no-intervenció a l'original mantenen els seus controls; aquest lot no implementa el carregador.

### 23.3 Càrrega sempre completa i risc que s'evita — D379

**Tota càrrega externa admesa és completa, per a totes les marques.** Es descarten les càrregues parcials per marques, també com a recuperació després d'una fallada. La selecció de marques es conserva exclusivament per a la conciliació posterior. No nou indicador/estat per marca, versió, HASH o canvi de signatura per substituir aquesta regla.

Motiu confirmat: una càrrega completa pot fallar després d'actualitzar només part de la còpia. Una càrrega posterior reeixida d'una marca no acredita recuperació de la resta; posar llavors ParkodRefreshSucceeded=1 podria donar un **fals senyal de disponibilitat global**. Només una nova càrrega completa verificada i publicada correctament pot tornar a acreditar l'èxit global. D379 substitueix expressament la modalitat parcial de D364, sense esborrar-ne l'historial.

Completa significa abast global de lectura/actualització, **no buidar, esborrar o recrear la taula**, reciclar claus, perdre històric o forçar igualtat entre original/còpia/variants. Tampoc és una garantia automàtica d'atomicitat de tota la càrrega: transaccions i comprovacions externes concretes no es donen per implementades. Llegir totes les marques no basta si hi ha infraestructura incompleta, lectura fallida o publicació no fiable.

### 23.4 Històric, presència, reaparicions i línia

La còpia és acumulativa: referències antigues i actuals conservades, sense DELETE per desaparèixer de l'últim flux. El procés extern estableix SourceIsPresent=1 si el SKU és present i 0 només amb absència contrastada mitjançant lectura global completa i fiable. Antiguitat, rebuig d'admissió a variants, incremental o càrrega fallida no proven retirada. Un SKU observat però rebutjat no es considera desaparegut.

Origen global buit amb SKU encara presents: no retirades massives automàtiques o declaració fictícia d'èxit. Protecció i comprovacions d'integritat/duplicats són responsabilitat externa, no algoritmes nous de l'app. No s'han aprovat llindars, percentatges, override automàtic o SourceSkuOccurrenceCount. La PK de còpia i les FK internes es conserven; no eliminar dades per fer passar els controls.

Reaparició/actualització publica CLIGNE/presència fiables i marca font. **No mou, desvalida o duplica** variant/grup/assignacions/decisions. D415 retira LineCode de ProductVariant: CLIGNE és l'única línia actual, canvi tractat com code1 per revisió de font, fotografia anterior conservada per comparar. No pendent separat/corrector o veto nou per font pendent. Grup/valors/codis validats poden continuar elegibles, no una línia anterior operativa (§30).

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

**D409–D410:** SourceUpdatedAtUtc és marca per SKU de la còpia; ReviewedSourceUpdatedAtUtc és marca d'aquella font revisada pel tècnic, no hora del clic. Cap de les dues substitueix les dates globals o crea indicador per marca. Una conciliació completa correcta no dona la font per revisada ni elimina tasques. Inicialització i avanç segur de la marca externa §29.2/model§6.47.3, integració/proves pendents.

### 23.6 Coordinació i límits transaccionals

Càrrega externa i conciliació s'exclouen mitjançant la mateixa coordinació lògica a VARIANTS_PARKOD: obtenir abans de modificar/llegir, mantenir durant cada procés amb connexió dedicada i publicar l'estat abans d'alliberar. La conciliació comprova disponibilitat després d'obtenir la coordinació. Connexió dedicada **no** significa una transacció global oberta tota l'execució, bloqueig deliberat de taules o locks durant l'edició d'un formulari.

**Ús obligatori de sp_getapplock pel carregador extern — D403:** ha d'obtenir un bloqueig lògic **Exclusive** sobre el mateix recurs de coordinació de còpia, dins de **VARIANTS_PARKOD**, que utilitzen els procediments dependents de l'app. Obtenir-lo **abans de marcar l'inici i modificar la còpia**, mantenir-lo per connexió durant tota la càrrega completa i publicar-ne el resultat abans d'alliberar-lo. Sense obtenir-lo no iniciar modificacions descoordinades. No es tracta de TABLOCK o bloqueig físic deliberat de tota la taula, ni d'una transacció global de càrrega.

Les operacions de l'app que necessiten Parkod demanen **Shared**: lector durant lectura SQL curta; confirmació/rebuig fins COMMIT/ROLLBACK de l'operació curta. Protecció abans de fixar estat llegit/SNAPSHOT i comprovar indicador; mai durant el formulari. Revisions poden coexistir, subjectes als altres controls/bloquejos; en confirmar cal obtenir protecció de nou i revalidar context. Conciliació manté exclusió amb carregador i zero sessions, sense nous modes executables de batch/login decidits aquí (§26.3/model §6.44.3).

SQL coneix el resultat d'adquisició del recurs lògic, no necessita detectar una taula físicament bloquejada. Incompatibilitat no prova càrrega en curs; indicador0 també pot persistir després de fallada amb recurs ja alliberat. Sempre comprovar disponibilitat després d'obtenir coordinació, només completa verificada/publicada correcta recupera. Error tècnic d'adquisició o connexió perduda no es disfressa d'indisponibilitat controlada/rollback conegut.

El publicador extern ha de cooperar efectivament: sp_getapplock no obliga escriptors no participants ni coordina automàticament l'original. Recurs/àmbit SQL efectiu han de coincidir; noms/permisos/esperes/propietat/seqüència SQL i proves pendents, no garantia d'impacte nul o absència de bloquejos normals del motor. Perdre connexió no autoritza continuar descoordinat, assumir rollback dels COMMIT previs o marcar còpia preparada. Carregador continua extern, sense implementació o modificació de parkod per aquest projecte.

SNAPSHOT aprovat només a VARIANTS_PARKOD, no a parkod; no coherència conjunta entre bases presumpta, NOLOCK o configuració nova de producció. La lectura font coherent, impacte i cooperació externa s'han d'acreditar sense objectes/permisos nous del projecte a l'original.

### 23.7 Seqüència d'execució i conciliació per marques

Dos `.bat` externament orquestrats pel **Planificador de tasques de Windows**, en seqüència i després de final correcte verificat: primer càrrega completa externa, després conciliació de l'app. Pauta habitual nocturna diària, llançament manual possible segons operativa acordada; sense planificador, reintents o servei central dins de l'app. Excepcions nocturnes gestionades manualment, suspenent/aturant tasques; no vigilància nova de tots els escriptors legacy. El calendari no és prova de coherència.

Conciliació completa o d'una/diverses marques amb BrandCodesJson segons §22.49/model §6.39. Entrada ja carregada i estable, app només dades pròpies; no càrrega parcial dissimulada o relectura original. Incorporació inicial de variants per marques conservada, conciliació completa programada desactivada fins acabar-la, però la còpia continua carregant-se completament. D371–D373 exigeixen cobertura individual només dins de l'abast revisat de conciliació; no igualtat indiscriminada de totals o nou criteri de completesa de font.

Càrrega no crea variants/grups/aprovacions; còpia sense variant és normal abans de conciliar o fora de marques incorporades. Incidències d'admissió restants són de l'app, no justifiquen esborrar còpia o inferir retirada. **D389 retira CPROD d'antics blocs/correu específic**, no un nou motiu de notificació/control de producció. Èxit de càrrega no acredita conciliació o classificació comercial acabades.

Sessió d'app vigent, també administrativa: la conciliació no arrenca; durant conciliació no nous logins. Omissió per sessió/altre batch, sortida0/log NOT RUN, no èxit fictici. Una càrrega fallida no es converteix en entrada disponible per conciliar, tampoc seleccionant una marca. L'exclusió GUI–conciliació no s'estén a tota la cadena de càrrega externa.

### 23.8 Operativa d'usuari i llista temporalment no disponible

**GUI permesa durant la càrrega**, D367 intacte. Molts contextos normals necessiten CLIGNE/SourceIsPresent de còpia: incidències de línia i criteris de tasques; revisió de valors, grups/pertinences/associacions; trasllats/creacions/substitucions; correcció tècnica de línia i finalització de fase 3. DESIGN1/DESIGN2/code1/code2 continuen sent dades font consultables, no rèpliques addicionals del model propi. Autenticació/gestió de comptes/sessions o edició manual del nom de grup no obtenen un veto nou per aquesta càrrega.

D377–D378: quan obtenir la llista requereixi consultar Parkod durant càrrega o després d'una fallada, mostrar **llista temporalment no disponible**, no «cap tasca» o resultats parcials donats per complets. Després de fallada, mantenir l'avís fins a nova càrrega completa verificada/publicada (D379). No afirmar «en curs» si només es coneix indicador0. Missatges orientatius en francès, segons situació coneguda:

- Càrrega efectivament en curs: «La liste des tâches est temporairement indisponible : mise à jour des données Parkod en cours.»
- Fallada/indisponibilitat sense càrrega vigent acreditada: «La liste des tâches est temporairement indisponible : les données Parkod ne sont pas disponibles.»

Avís separat del login, sense revocació de sessió/reserva/auditoria o veto general. D396 impedeix revisions dependents amb0, no operacions independents. D369/D399–D401 tracten línia coneguda disponible, no canvis concurrents ignorats. D402 error SQL identificable i D403 Shared/Exclusive decidits (§26.2–§26.3); numeració/transport/detalls executables/integració/proves pendents, sense cache/auto-refresc/API de tasques nova.

El generador Parkod existent continua independent: indicadors0 informatius al seu log, no vetos nous. Lectura inicial coherent de variants en SNAPSHOT curt local; lectures originals separades amb protocol pendent. Aquest avís de GUI no altera elegibilitat comercial o crea un exportador nou.

### 23.9 No-intervenció a producció i estat de les garanties

**Cap escriptura, DDL, manteniment, índex, trigger, vista, sinònim, usuari, concessió de permisos o canvi de configuració a parkod per aquest projecte.** Només lectures controlades/autoritzades amb permisos disponibles i impacte verificat, sense prometre impacte nul. Si la integració exigís modificar l'original, cal redissenyar-la. Configuració aprovada de nova base, compatibilitat 140/French_CI_AS/SNAPSHOT ON/RCSI OFF, encara pendent d'autorització d'aplicació; producció SQL Server 2017 Express/Windows Server 2019 intacta. Proves locals de 2019 no autoritzen dependències exclusives de 2019.

L'app no assumeix integritat provada pel sol indicador, nombre de files o horari nocturn. Controls periòdics de producció, identitat/claus, metadades i publicació fiable són contracte extern; integració/permisos/lectura/impacte/coordinació s'han de provar. Càrrega global pot durar més i compartir recursos CPU/memòria/disc: mesurar-ne impacte, sense llindars o límits nous aprovats. Express manté límit de 10 GB de dades per base.

### 23.10 Traçabilitat i pendents

Referències: D230–D233 contracte/entorn/seqüència, D348/D351–D352 històric/presència, D360–D365/D367 frontera/coordinació/GUI, D377–D379 avís/càrrega completa, **D402–D403 error i cooperació lògica compartida/exclusiva**. D379 substitueix sentit parcial de D364, històric conservat. Model canònic §3.1/§3.14/§5/§6.7/§6.35/§6.41/§6.44, conciliació §6.39.

Pendents: acreditar integritat/completesa/cooperació externa, permisos/àmbit efectiu del recurs/esperes/propietat/alliberament, lectura autoritzada/impacte, seqüència executable/interrupcions i proves. Exclusive del carregador/Shared de revisions curtes ja decidits D403, no protecció demostrada. Sense algoritme/DDL/signatura/implementació del carregador aprovats aquí. Actualització documental2026-11-05, etapa0 oberta/contrast complet requerit, etapes1–4 no implementades/provades; cap SQL/dada/font/configuració/commit/push.

## 24. Nous requeriments i represa de l'etapa 0 — D380–D394

**Lectura actualitzada a D404:** acordsD380–D403 conservats, §27 afegeix substitució completa amb línia coneguda i adaptacions directes d'E02.25signatures restants sense categoria/set blocs SKU–valor adaptats, no tots els formats o etapa0 tancats.

### 24.1 Acords confirmats i substitucions

- Un únic ProductGroup actual per SKU, mateixa marca, categories/línies diverses admeses. PK marca–ID, numeració per marca. CategoryCode/LineCode de grup i CategoryCode d'associació/assignació/registre retirats. Comptador i reserva adaptats com a conseqüència, no camps nous; model13taules/90camps al diccionari/ER.
- Codi5 ASCII0–9/A–N/P–Z, primera assignació **DE000** per marca, increment fins a **ZZZZZ**, sense retorn. Registre complet/permanent també de retirats, unicitat i assignació SQL atòmiques. ParkodVariantCodeBlock retirada sense substitut; no repetir codis o suposar espai infinit. Moment final de fase3/principal coherent intactes.
- Identificador externBrandCode3+ParkodVariantCode5=8. D444–D445 substitueixen justificacióD388: CCATEG alfanumèrica, reservaexterna < 'DE' separa espais si es respecta; carregador detecta anomalies i avisa tècnics§23.2.1. Tipus/zeros/dades preservats, sense nou camp/filtre de col·lisió al gestor. RebuigCPROD/correu antics retirats i altrescontrols/logs intactes.
- Només canvi de CLIGNE provoca revisió sobre el mateix SKU. Canvi de CCATEG continua essent nou SKU D04/D106, antic conservat. Còpia externa/SourceIsPresent/última classificació preservats fins revisió, sense trasllat/desvalidació automàtics.
- Corrector pot actualitzar LineCode amb CLIGNE local revisada i confirmar continuïtat: pertinença1/risc conservat/assignacions i metadades intactes. En trasllat, risc de nova pertinençaNULL. Sense font/còpia escrites, original rellegit, valors perduts o codi nou.
- Administració de buits/inactius per marca o totalitat, no marca–categoria. Controls d'admin/zeroSKU/cap reserva/història/resultats per grup conservats.

Vxxxx/V0000 i retorn a00000 són propostes substituïdes pel règim final DE000…ZZZZZ sense retorn. Les notes D379 de bloqueig de pertinença no confirmat ja no són vigents. No decisions duplicades per confirmacions repetides, recordatoris o derivacions inequívoces. Tot el que l'usuari no modifica es conserva, excepte incoherència real a contrastar una per una.

### 24.2 Històric de matriu de línia — substituït per D415

Matriu següent històrica: discrepància CLIGNE–LineCode i vetosD390/D392 **no són controls actuals**. Resta d'admissibilitat/requisits de codi-valors-principal-context i auditoria conservats, sense veto general nou de font pendent (§30/model§6.48).

| Operació amb discrepància coneguda CLIGNE/LineCode | Criteri |
|---|---|
| Validar ordinàriament pertinença | Bloquejat fins a resoldre línia (D390). |
| Corrector que resol línia i confirma pertinença | Permès conjuntament, sense validació ordinària prèvia circular; mateix grup/risc conservat o trasllat/risc nouNULL. |
| Validar configuració del grup | Permès, sense aprovar membres o resoldre incidència (D391). |
| Aprovar tipus al grup en fase2 | Permès1/codiNULL, sense pertinences/valors/línies/codi/principal aprovats implícitament (D393). |
| Retirar A aprovada sense codi i aprovar B candidata, totes dues sense assignacions al grup | Permès amb línia coneguda, cas reduït D295–D296/D398; incidència pendent, SKU/valors/codis/principal intactes. |
| Substitució completa amb retirada/rebuig exprés d'assignacions d'A i retirada d'A | Permès D404/§22.19, condicions pròpies de cada decisió/valors-principal-context-atomicitat intactes; incidència pendent/no línia-grup-pertinença canviats. D392 abans de codi nou de B, codi propi existent conservat. |
| Corregir candidata grup–tipus amb B nou o existent | Permès amb admissibilitat de §22.37/D399; A sense assignacions, incidència pendent. |
| Rebutjar candidates o proposta nova de correcció validada | Permès pels tres circuits específics D400, eliminació només de candidata admissible/validada íntegra segons cas. |
| Rebutjar propostes no persistents, individuals o conjuntes | Permès D400/§22.32/§22.36, només auditories expresses/sense canvi de classificacions vigents. |
| Alta manual de tipus existents al grup existent | Permès D401/§22.30, lot atòmic/associacions absents/1-codiNULL, sense pertinences/línies/codis finals nous. |
| Corregir valor ja validat | Permès, D369 intacte. |
| Confirmar candidata SKU–valor | Permès amb tots els controls del seu circuit (D394). |
| Primera assignació manual de valor | Permès amb absència revisada/tipus aprovat/resta de controls, no upsert (D394). |
| Assignar ParkodVariantCode NOU | Bloquejat si algun requerit té línia pendent (D392). |

Requerits = SourceIsPresent1 i pertinença validada D255–D256. Flags ja validats no es posen0 automàticament en canviar CLIGNE, però aquella incidència també s'ha de resoldre abans de codi nou. No veto addicional per retirats o pertinences pendents fora de requerits; mínim d'un requerit conservat. Codis antics immutables i última exportació validada D80 intacta.

Tres estats/circuits de valors, risc/originals/no-op/auditoria/XOR/representació exacta conservats. Context canviat sempre nova revisió; permisos/reserva/grup actiu/habilitació/integritat intactes. D374–D376: tasques existents admissibles de retirats sí, mancances d'assignació no, sense validació automàtica o taula de pendents nova.

### 24.3 Punts pendents d'etapa 0

**Registre canònic al model §7**, amb identificadors per reprendre després de compactar:

| ID | Pendent real |
|---|---|
| E01 | D415–D416 model13/92, LineCode retirat/ReviewedSourceJson NVARCHAR(MAX) NULL/sis camps informatius. DatesUTC3 confirmades en conversa; CHECK/coherència/parser/índexs/DDL/proves pendents, no execució autoritzada. |
| E02 | SKU9 de contingut nou/senseLineCode/fotografia imbricada/reduïts sense fotografia afegida, propostes4-5/membresIDsol.75signatures actives/quatre retirades. Cobertura/formes pròpies/comparadors/parser pendents, Usages no ampliats, història literal. |
| E03 | Quatre correctors de línia retirats D415, no via nova o procediments buits. Conservar història i contrastar trasllats/creació/validació pels circuits propis; no tornar a decidir correcció d'una línia pròpia inexistent. |
| E04 | Sense matriu de discrepància o vetosD390/D392, resta d'admissibilitat de cada circuit conservada. Completar només altres controls/retirades/no-op no coberts, sense font pendent com a veto general o permissió universal. |
| E05 | D396/D402/D403/D406 intactes; D408 connector al final del disseny abans de codificar, pyodbc primera opció a contrastar, cap adopció. Transport estructurat/mapping francès/error-ROLLBACK/matriu inclosa revisió de font/recurs/permisos/ordre/integració/proves pendents, no parser de missatges aprovat. |
| E06 | French_CI_AS mantinguda D397, BIN2 no adoptada. Ordre/accés/SQL2017/successor/concurrència/límits/esgotament/rollback/incertesa per provar, sense comptador de codis nou. |
| E07 | Alta senseLineCode/referència-marcaNULL/existentconservat/pendent perfont sense categoria de línia. ReconcileSku i retiradaUpdatedCount confirmats en conversa, formalització global/escriptors/noms/parser/cobertura/SQL/memòria pendents; no èxit fictici d'infraestructura. |
| E08 | Llista per dates, fotografia informativa dels sis camps de l'última revisió/anteriorsbuits si absent/no diferències inventades. Consulta/presentació exactes/GUI/proves pendents, no taula o assignació personal. Retiratsfont sí/mancancesvalors no. |
| E09 | Presència-data font externes/inicialització/càrrega completa a integrar/provar, no fotografia renovada pel carregador. Generador línia actual de còpia/no anterior des d'auditoria-fotografia, estat comercial conservat. Metadades/permisos/impacte/noms/recuperació pendents, cap intervenció original. |
| E10 | Proves autoritzades/humanament validades i compatibilitat2017: claus, valors/JSON, matriu, codis, sessions/admin/reserves, incertesa/rendiment. |
| E11 | Circuits encara no coberts; no alta exclusiva/reactivació/recuperació forçada GUI o excepció ValueKind per aprovació implícita. |

E05 continua essent diferent de discrepància de línia o SourceIsPresent0: **D396 confirma ara** el criteri de disponibilitat, també correcció de valor durant càrrega/fallada. D377–D378 regulaven només la llista; D396 no en deriva un veto global, sinó de la dependència del context. No reaprovar seqüència/alfabet/primer codi, marca única, matriu o altres principis resolts. E03 ja concretat, E02/E04 restants i implementació/proves encara oberts.

### 24.4 Estat documental i garanties de represa

DECISIONS.md D415–D416/D01–D414 literals, model§6.48/§7/funcional§30. Model13/92/SKU9 contingut nou,75signatures actives consolidades/quatre retirades, funció intacta. Originals/snapshots preservats; altres assentiments de conversa no reoberts però formalització global separada. Etapa0/E02/E05 oberts, cap dependència adoptada o SQL provat.

CàrregaD379 sempre completa/appreadonly10camps després de D409, només conciliació per marques. Presència/data font externes, revisada només humana. SQL2017/Windows2019, confiança/autenticació/catàlegs/normalització/ValueKind/decimals/quatrevalidacions/principal/no-retries/incertesa conservats. Cap servei/exportador/carregador/taula de tasques nous implementats, SQL/font/dades/configuració canviats o avanç d'etapes. Etapa0 oberta, preparació no és prova executada.

## 25. Lot d'acords del xat — D395–D398

### 25.1 Corrector de línia reutilitzat, també sense trasllat — D395

GetVariantLineCorrectionToExistingGroupContext/ConfirmVariantLineCorrectionToExistingGroup admeten el grup actual com a destí explícit marca–ID. Mateixos noms, sense argument de categoria, flag de mode o tercera parella de procediments. Exactament set blocs: ProductVariant, Parkod, SourceGroup, DestinationGroup, ProductVariantValues, VariantTypes i VariantTypeValues. Quan coincideixen origen/destí, **els dos blocs de grup es mantenen complets amb el mateix contingut**, llegits en el mateix SNAPSHOT curt; no null o omissió, ni doble pertinença/reserva SQL. Grup actual7, membres amb categories/línies pròpies, associacions8 i assignacions9.

Canvi efectiu de línia amb CLIGNE local revisada, pertinença1. Mateix grup/risc conservat/assignacions intactes; altre grup/risc nouNULL/rèpliques canviades, valors/metadades preservats. Cap no-op, còpia escrita/CLIGNE original rellegida/grup-codi-principal-catàleg nou. Context canviat exigeix revisió; disponibilitat §25.2 i altres controls conservats.

Tres conjunts capturats dins de l'operació/emesos post-COMMIT: UUID+SKU complet, totes les assignacions completes (encara intactes quan no hi ha trasllat), còpia Parkod9 llegida. Una group_membership/update amb Before/After8/clau anterior real; afegir audit d'assignació només per rèplica realment modificada en trasllat. Cap audit d'assignacions intactes/lectures/còpia, història intacta. Contracte canònic model §6.38, materialització/proves pendents.

### 25.2 Disponibilitat de les revisions segons dependència de Parkod — D396

| Context necessari per revisar/confirmar | ParkodRefreshSucceeded=0, càrrega o fallada |
|---|---|
| Requereix dades de la còpia local Parkod | Avís francès; no nou context revisable, confirmació o rebuig formal. Cap context parcial, [] o null ficticis per suplir informació indisponible. |
| Completament construïble i verificable amb dades pròpies, sense Parkod | Cap veto nou per l'indicador. Operació admissible només segons el contracte i la resta de controls existents. |

Confirmat per als tres circuits SKU–valor (correcció validada, candidata, primera alta), els seus tres lectors i els dos rebutjos formals; després per candidata grup–tipus i finalment **com a criteri transversal**, no regla per preguntar de nou per cada procediment. Candidates, assignacions, catàlegs i decisions existents conservats; cap auditoria de decisió fictícia. Cancel·lar edició manual/tancar pantalla continua permès pels circuits existents, sense rebuig auditat; indisponibilitat no expulsa sessions o elimina edicions per si sola.

Grup amb membres: els contextos que inclouen CLIGNE/SourceIsPresent locals de tots els membres necessiten Parkod, també retirats/pendents. **Grup realment buit**: no veto si el context complet no necessita còpia; [] comprovat, no un error de lectura amagat. Revalidar composició/context en confirmar, canvi concurrent nova revisió. Buit no permet finalitzar codi nou sense almenys un requerit o saltar altres requisits.

Usages editorials amb assignacions inclouen SourceIsPresent i depenen de Parkod; catàleg simple/principal/nom manual/comptes/sessions sense aquella dependència no reben veto nou. Generador independent/indicadors0 al log, tancaments tècnics de sessió/batch no bloquejats per analogia amb una decisió humana. Sense cache/auto-refresc/estat físic/API/camp d'error o veto global de GUI/login nous.

Reprendre amb **nova lectura i revisió després de publicació completa correcta** D379, no reenvio automàtic/context antic; data anterior o càrrega per marca no certifiquen recuperació. SourceIsPresent0 i discrepància coneguda no són còpia indisponible. D369/D394/D398 permeten els seus casos de línia amb dades necessàries disponibles i altres controls intactes.

**D402–D403 concreten després** error SQL identificable i esquema de coordinació (§26.2–§26.3/model §6.44). Dependències exactes/numeració/transport/recurs/esperes/permisos/seqüència executable/proves pendents. Indicador1 aïllat no prova estabilitat; cap transacció de formulari, intervenció original o carregador desenvolupat per l'app. Regla D396 conservada, no reoberta.

### 25.3 Contrast de trasllats, creació i substitucions

Derivacions D380/D390/D261–D268, no decisions noves: mateixa marca permet categories/línies diverses, però pertinença ordinària aprovada exigeix línia resolta del SKU. Línies diferents entre SKU sense discrepància individual no impedeixen agrupar. Creador explícit seleccionat/aprovat i almenys un approve; exclusió manual sense proposta exigeix selecció/context nous, no rejected fictícia. Cap veto nou per incidències d'altres membres dels grups que no s'aproven/traslladen, assignacions preservades. Contractes del model §6.18–§6.19 concretats en aquests punts.

Substitució completa D183/D392: B amb codi propi ja assignat el conserva; no afegir-hi un veto de línia de codi NOU si no se n'assigna cap. Si B necessita codi nou, línies resoltes dels requerits presents/pertinença validada, sense veto addicional pels altres. Codis d'A permanents/no transferits/no reciclats, valors/principal/retirades/context/auditoria atòmics i COMMIT previs conservats.

**D404 posterior:** la substitució completa també admet explícitament línia coneguda en retirades/rebutjos individuals d'assignacions d'A i retirada de l'associació A, sense correcció de línia/grup/validació de pertinença. Cada decisió conserva condicions pròpies i D392/altres controls intactes; incidència pendent (§27.1/model §6.45.1).

**D398:** cas reduït A1/codiNULL→B candidata0/codiNULL amb original, mateix grup i cap assignació d'A/B, també pendent/validada/de retirat. Discrepància coneguda no bloqueja retirada/aprovació conjuntes. Riscos/originals propis/dues auditories/UUID comú/dos conjunts conservats, sense SKU/valors/línies/principal/codis canviats; incidència pendent. D396 i controls D295–D296 intactes. Referència **DATA_MODEL.md §6.27**, resum funcional §22.39, no substitució universal o catàlegs buits exigits.

### 25.4 Ordre del màxim dels codis — D397

Mantenir **French_CI_AS** per cercar el codi més avançat del registre permanent de cada marca, retirats inclosos. BIN2 sense necessitat demostrada no adoptada, recomanació retirada. Amb codis5 ASCII majúsculs validats és esperable l'ordre, però cal verificar-lo i comprovar el pla d'accés en SQL2017, no prova executada o rendiment garantit.

D382 intacte: cap codi registrat→DE000; màxim→successor sense O, finsZZZZZ/esgotament sense retorn/parcial. Exemple fictici: màximDE00N→DE00P. No nombre de SKU o MAX(ProductGroupId), no reciclatge de forats. Coordinació per marca/restricció única/transacció atòmica de registre-associació-codi-principal-auditoria conservades; ordenar no evita curses per si sol. Sense collation física/FK/base/font/configuració modificades o comptador de codis nou. Alternativa futura només amb justificació/revisió.

### 25.5 Estat del tall D398 i represa posterior

**Tall històric:** estat següent de D398, precisat per D399–D403 a §26; error/cas compartit-exclusiu ja decidits, detalls/proves encara pendents.

Data documental2026-11-05, no data exacta de cada confirmació. Quatre acords D395–D398, sense duplicar confirmacions o derivacions. Model13/90 i mateixos76 noms; quatre signatures de destí adaptades D380 (trasllat i corrector a existent, lector/confirmador). Altres25 signatures amb categoria i formes restants E02; altres47 sense aquella retirada d'arguments no equivalen a retorns/contextos intactes. Cap API nova per indisponibilitat o corrector sense trasllat.

E03 concretat, E05 criteri decidit, E06 French_CI_AS mantinguda: no reobrir-los perquè falti SQL. E02/E04 restants, matriu/error/protecció E05, E01/E06–E11 i etapa0 pendents de contrast/materialització/integracions/proves autoritzades. Històric/originals/snapshots preservats, scripts/fonts/configuració intactes; cap SQL/app/dada/commit/push o etapa posterior implementada. Memòria/regles alineades amb el tall.

## 26. Acords de línia coneguda i coordinació del carregador — D399–D403

### 26.1 Correccions, rebutjos i alta manual

Casos expressament confirmats amb discrepàncies CLIGNE/LineCode **conegudes al context revisat**, no dades indisponibles o canvi concurrent ignorat:

| Acord | Circuit i efectes conservats |
|---|---|
| D399 | Dos correctors de candidata amb B nou/existent (§22.37/model §6.26). A0/codiNULL/original/sense assignacions al grup; B segons D177–D179, B aprovada intacta. No SKU/valors/línies/pertinences/principal canviats o codi nou. |
| D400 | Rebuig de candidata grup–tipus D247 o SKU–valor D244: elimina només candidata admissible/auditoria atòmiques. Rebuig de proposta nova sobre validada D282: fila/risc/originals/validació/catàlegs íntegres, només decisió auditada. |
| D400 | Quatre rebutjos no persistents D269–D272 i conjunt D285–D289 (§22.32/§22.36), només auditen decisions expresses, cap classificació vigent creada/eliminada o grup/SKU/assignació/catàleg/comptador/codi modificats. |
| D401 | Alta manual AddGroupVariantTypes (§22.30/model §6.21): tipus existents compatibles/grup existent/lot no buit/tot o res/sense duplicats o associació ja existent ignorada. Noves associacions1/codi-risc-originalsNULL, no catàleg/valors/codis/principal nous. |

Els vuit rebutjos D400 s'enumeren al model §6.44.1: RejectGroupVariantTypeProposal, RejectVariantValueProposal, RejectVariantValueCorrectionProposal, RejectProductGroupProposal, RejectNewGroupVariantTypeProposal, RejectNewGroupMembershipProposal, RejectGroupMembershipMoveProposal i RejectProductGroupCreationProposals. No permissió universal per a altres rebutjos/retirades o ús de via de candidata sobre fase2 aprovada.

Incidència de línia pendent, originals/riscs/auditories/identitats/contextos/respostes propis conservats; no nous formats/paràmetres o control saltat. No rebuig implícit de fills o cancel·lació manual auditada. D390 manté línia resolta abans d'aprovar pertinença ordinària; D392 abans de codi nou dels requerits. Disponibilitat D396 i resta de controls intactes, no tancament global d'E04.

### 26.2 Indisponibilitat comunicada amb error SQL — D402

Si D396 impedeix una operació dependent de còpia, **error SQL específic identificable pel backend sense dependre del text**, no context revisable parcial/buit fictici o resposta d'èxit/OperationId que aparenti decisió executada. Signatures i respostes d'èxit actuals intactes, no camp/taula/resultset nou.

GUI francesa/logs tècnics anglesos/sense secrets; dades/candidates/edicions preservades, cap decisió fictícia auditada. Després de completa correcta nova lectura/revisió/no reenvio. **D406 posterior fixa número51001 amb THROW**, no transport provat o driver escollit. Altres números/errors d'adquisició no es converteixen en indisponibilitat; timeout/connexió perduda/resposta incompleta mantenen D238/sense rollback presumptiu. Mapping/missatge final/seqüència error-ROLLBACK/SQL/proves pendents, no catàleg general d'errors o parser de missatges aprovat (§28.2).

### 26.3 Shared/Exclusive sobre un recurs lògic, no sobre tota la taula — D403

**Obligació del carregador ja escrita a §23.6:** utilitzar sp_getapplock Exclusive sobre el mateix recurs de còpia dins VARIANTS_PARKOD, abans de marcar inici/tocar còpia, manteniment per connexió durant tota la càrrega completa, publicar resultat abans d'alliberar. Sense obtenir-lo no modificar descoordinadament. Sense transacció global, nova taula/recurs o intervenció original; carregador extern no implementat pel projecte.

Lectures de context dependents Shared durant lectura SQL curta; confirmació/rebuig dependent Shared fins COMMIT/ROLLBACK. Protecció abans de fixar estat llegit/SNAPSHOT i comprovar indicador, no context antic escrit o coordinació mantinguda durant formulari. En confirmar es torna a obtenir i revalidar context. Compartit permet coexistència de revisions, subjectes als altres bloquejos/controls; carregador exclusiu espera final d'operacions incompatibles abans d'obtenir accés. Esperes exactes pendents, no fail-fast o reintents nous aprovats.

SQL comprova resultat d'adquisició lògica, no necessita detectar bloqueig físic de taula. Incompatibilitat no prova càrrega en curs o TABLOCK. Indicador0 pot continuar després de fallada/recurs alliberat: coordinació no substitueix disponibilitat, només completa correcta recupera. Errors tècnics de permisos/adquisició/deadlock/desconnexió no s'amaguen com càrrega acreditada/indisponibilitat controlada/rollback conegut. No snapshots que fixin estat antic abans d'obtenir protecció.

Cooperació externa efectiva indispensable, sp_getapplock no obliga escriptors no participants ni elimina bloquejos normals del motor/impacte. No veto global GUI/login, lock de formulari, requisit nou d'aquest recurs al generador independent D129 o a operacions realment independents de Parkod. Conciliació manté exclusió de càrrega/zero sessions, no reobrir D365/D367 o seqüència Windows D233/D379. Noms/àmbit/permisos/propietat/alliberament/esperes/ordre amb tipus→SKU→marca→grup i proves pendents. Detall canònic model §6.44.3.

### 26.4 Consolidació i treball restant

**Tall històric D403:** els25arguments amb categoria pendents aleshores s'adapten després a §27/model§6.45. D404 és una única decisió nova sobre el circuit complet; la resta deriva d'acords anteriors. La verificació anterior no és prova del nou lot.

Cinc acords per tema, sense duplicar confirmacions successives: els tres blocs de rebutjos s'agrupen en D400, menció explícita del carregador és part de D403. Data documental2026-11-05, no data exacta atribuïda a cada acord. D01–D398/originals/snapshots històrics conservats; model13/90,76noms/signatures/funció i respostes d'èxit intactes respecte del tall D398. Altres25signatures amb categoria i formes restants encara E02.

E03 concretat, E04 només casos realment no coberts, E05 criteri/error/esquema lògic decidits però numeració/transport/matriu/recurs/seqüència/permisos/proves pendents. E01/E06–E11 conservats, etapa0 oberta. No SQL/DDL/app/dades/font/configuració/carregador/commit/push o avanç d'etapes implementats. Registre model §7/funcional §24.3 alineats; documentació no és prova d'integració/concurrència o domini.

## 27. Revisió d'etapa0 consolidada: contractes i substitució completa — D404

### 27.1 Substitució completa amb discrepància coneguda: acord nou

Confirmació expressa de l'usuari, no extrapolació de D398/D400: en el circuit complet de model§6.11/funcional§22.19, una discrepància CLIGNE/LineCode **coneguda al context revisat** no bloqueja per si sola les retirades/rebutjos individuals expressos d'assignacions d'A i retirada de l'associació A.

Cada retire/reject conserva les seves condicions i auditoria: retirada funcional expressa també de validada/retirat; rebuig només de candidata pendent amb original, no conversió automàtica. Decisions de totes les assignacions revisades d'A, cap conservada com a fila si es retira completament A. Catàlegs/història/COMMIT previs conservats, sense cascades o retirada pel sol SourceIsPresent0.

La incidència continua pendent. **No canviar LineCode, grup actual del SKU, risc/validació de pertinença o còpia**, ni aprovar-los per herència. Això no impedeix l'ajust del principal del grup que D183/D235 ja exigeixen dins de la transició atòmica. Context/sessió/permisos/grup actiu/reserva/integritat/valors requerits de B/principal i dades–auditoria atòmics intactes. B conserva codi propi existent; si necessita codi NOU, D392 exigeix línies resoltes dels requerits presents/pertinença validada, sense veto nou als altres. Codi d'A permanent/no transferit-reciclat. D396/D402–D403 i incertesa D238 intactes. No permissió universal per a altres retirades/no-op o ampliació del circuit reduït.

### 27.2 Adaptacions directes:25signatures, no25decisions

Segons D380/D386, les25signatures restants retiren només CategoryCode als contractes i inventari model§8.8. Tipus/ordre/defaults dels altres arguments intactes. Quatre DestinationCategoryCode ja retirades D398: **29signatures adaptades respecte D379**, mateixos76noms/funció separada, cap API nova. Els altres47noms no canvien signatura per aquest motiu, però poden tenir contextos afectats. Matriu exacta dels25 al model§6.45.2.

| Família revisada | Forma adaptada/garanties conservades |
|---|---|
| Sessions/reserves | Resposta reserva-alliberament4, reserva2 informada o tots dosNULL, context forçat compte4/sessió segura5 i llista8. Sense auditoria rutinària/UUID, reservar exigeix grup actiu/alliberar no; tancament forçat una auditoria/snapshot segur5. |
| Principal/nom/desactivació | Grup complet7. Principal tres blocs/sense SKU-valors/ID obligatori-NULL només zero finals; nom només bloc ProductGroup7/nom desitjat separat/NULL sense nom-no regeneració. Desactivació marca o totalitat/ordre marca–ID/candidat7+indicador separat/resposta4/inactius7; només canvi audita. |
| Candidata/correctors/fase2 | Quatre blocs de candidata, quatre per B nou i cinc per B existent; grup7/associació8/tipus5. B aprovada intacta, candidats amb originals propis; fase2 reduïda A1-B0 obligatòria/sense assignacions d'A-B/no Bnull o aprovada. No contextos intercanviables o barreja d'originals. |
| Alta manual/validació de grup | Quatre blocs amb VariantTypes seleccionats en alta, tipus referenciats per associacions actuals en validació: mateixos noms no són context universal. Lot manual no buit/tot o res/cap associació existent ignorada, resposta UUID+associacions8 en dos conjunts. Grup només flag/risc conservat/buit actiu admès/no-op revisat1; canvi concurrent0→1 és conflicte. |
| Finalització/substitució/incertesa | Finalització sis blocs/substitució completa set, grup7-associacions8-assignacions9. Resposta OperationId/codiNVARCHAR(5)/principalINT. Codi no congelat en pantalla/consum concurrent no conflicte, D392 i mínim d'un requerit abans de codi nou intactes. Consulta admin XOR ID o marca–grup–A–B, dos conjunts/auditoria literal/PK actuals/inactiu existent noNULL, cap fallback nou. |

Categoria/línia pròpies dels SKU/membres/raw_value conservades; retirar-les del grup no n'autoritza eliminació indiscriminada. Noves claus marca–grup/associació3, no IsActive a claus o grups reduïts. Snapshots/originals històrics literals, no acceptar context vell ignorant propietats/completant defaults. Les altres formes no contrastades continuen E02.

### 27.3 Vuit SKU–valor: signatures intactes, set blocs adaptats

Tres de candidata, tres de correcció validada i dos de primera assignació (§22.33–§22.34/model§6.15/§6.23–§6.24). **Grup reduït3** BrandCode/ProductGroupId/IsValidated i **associació reduïda5** ProductGroupId/BrandCode/VariantTypeId/IsValidated/ParkodVariantCode; no substituir per files completes7/8 o afegir IsActive. Assignació completa9 o JSONnull obligatori només per alta absent; SKU reduït7 conserva categoria-línia/sense risc afegit, tipus/valors complets5 i Parkod2 CLIGNE-SourceIsPresent. Detall model§6.45.3.

Tres estats/no upsert, original/actual sempre inclòs amb fila existent, només seleccionat o [] amb absent; valor nou desitjat separat. XOR/gramàtica decimals/normalització/unicitat/IDs reals i dues vies de confirmació intactes. Dues parts post-COMMIT assignació9+UUID/valor5, UUIDnullable només no-op manual autoritzat. Proposta nova sense canvi audita però conserva fila-metadades/snapshotsNULL; canvi efectiu metadades segons D279. Rebutjar candidata només audit+DELETE admissible; rebutjar proposta nova sobre validada només audit/fila intacta, una fila UUID. No fase3/codi automàtics/no nova prohibició de retirats.

Tots vuit necessiten Parkod: línia coneguda permesa D369/D394/D400 no és disponibilitat0. D396 impedeix revisió/confirmació/rebuig formal amb0, dades-candidates-edicions preservades; D402 error identificable/D403 Shared SQL curt i nova lectura-revisió després de completa correcta. Sense locks de formulari/reenvio/decisió fictícia o signatures noves.

### 27.4 Història, pendents i represa

**Tall històric D404:** els pendents descrits a continuació són els d'aquell lot. El contrast posterior i D405–D406 s'incorporen a §28/model§6.46; no conservar com a pendent el significat de LineCode o el número/instrucció de l'error ja confirmats. La resta de treball tècnic/proves continua obert.

Una decisió nova D404; resta adaptacions citant acords originals, no duplicar assentiments. Data documental2026-11-05/no data exacta inventada de cada confirmació. D01–D403 literals/model13taules-90camps/mateixos76noms/funció. Nova plantilla grup–tipus al model§6.45.4 elimina només categoria/línia superiors i conserva membres amb ID/línia originals; altres plantilles encara E02. Cap original persistent/snapshot antic migrat o reescrit.

**E02 restant:** catàlegs/editorials/Usages/metadata d'inactius, altres contextos compostos/rebutjos/creacions i retorns no contrastats, plantilles/claus/snapshots/comparadors exactes. No25arguments encara a retirar ni76formes completes aprovades. **E04:** només casos realment no coberts, D404 ja resolt/no tornar-lo a preguntar. **E05:** criteri/error/esquemaS-X decidits, número/transport/matriu incloent consulta administrativa/recurs-àmbit-permisos-propietat-alliberament-esperes-ordre SQL/integració/proves pendents.

E03 concretat, E01/E06–E11 preservats al model§7/funcional§24.3. Etapa0 oberta, no algorismes/GUI/etapes1–4 o proves SQL-domini-concurrència-integració superades. Només documentació, sense SQL/DDL/app/dades/font/configuració/commit/push. Continuar per catàlegs/editorials i usos, distingint adaptació pendent d'una decisió ja confirmada.

## 28. Consolidació post-D404: formats, indisponibilitat i conciliació — D405–D406

**Tall històric D406:** §29/model§6.47 incorporen després dues dates, contextos SKU ampliats/tres signatures noves i connector diferit. La prioritat provisional de pymssql, els còmputs13/90/76 i les formes afectades següents no són l'estat actual. Història i observacions es conserven, no es reescriuen.

### 28.1 Dues precisions de significat i formes noves

«Canvi d'identitat de grup» significava adaptar la clau del disseny a **BrandCode/ProductGroupId** D380, no renumerar/fusionar grups durant l'operativa. Cada SKU incorporat té grup actual, encara propi provisional; pot tenir valors perquè ja té associacions aprovades en aquell grup, no perquè existeixi un SKU sense grup. En el corrector amb grup propi nou el que encara no existeix és el **destí**, creat amb associacions/trasllat/preservació de valors/auditories atòmicament.

**D405 expressament confirmat:** als nous JSON de pertinença, LineCode conserva la línia pròpia del SKU en preparar la proposta, no una línia del grup destí. CategoryCode del SKU es conserva; destí marca–ID, grup nou IDnull/nom només descriptiu si proposat. Un trasllat ordinari no canvia LineCode; correcció exclusivament pel circuit aprovat. Resultat amb ID real/destí final/línia pròpia final, originals/història intactes. Mateixes5/6propietats, cap camp nou.

Plantilles actuals del model§3.11.2: grup–tipus7propietats/creació4, sense categoria/línia comunes; SKU–valor11 amb categoria pròpia. No afegir membres imbricats/creador/versió per semblança. Claus d'auditoria de grup no creat amb marca/IDnull/SKU originals, associació afegeix tipus; pertinença amb grup anterior real. Snapshots complets grup7/SKU8/associació8/assignació9 i catàlegs5, no els reduïts dels contextos. Desactivació After objecte existent, rebuig sense canvi dos snapshotsNULL/no fila desapareguda, D280 i excepció password_reset conservats.

### 28.2 Número51001 i THROW — D406

Concreció de D402: **error SQL51001 amb THROW** quan l'operació necessita la còpia i comprova ParkodRefreshSucceeded0 sota coordinació D403. Càrrega/fallada poden deixar0; carregador ja aturat no prova còpia disponible, només completa verificada/publicada correcta recupera1. Sense context revisable parcial/fictici, confirmació/rebuig formal, candidats esborrats o decisions inexistents auditades. Operacions independents sense veto nou, edicions conservades/nova lectura-revisió després de recuperació.

No codi general de discrepància Parkod–ProductVariant, SourceIsPresent0, línia pendent, permisos o adquisició de lock. El connector ha de conservar qualsevol número natiu, no només51001; altres números mantenen tractament propi. Si el cas previst51001 arriba amb altre número, investigar/no substituir-lo silenciosament. SQLSTATE sol insuficient, no interpretar el text. D238 timeout/desconnexió/resposta incompleta continua resultat incert/no reenvio/rollback presumptiu. Sense missatges globals nous al servidor, signatures/resultats d'èxit/camps/resultsets nous o catàleg general d'errors.

Número i instrucció decidits, **transport/mapping francès/error-ROLLBACK/proves encara pendents**. No s'ha aprovat parser de diagnòstics textuals per facilitar l'ús d'un connector. Model§6.44.2/§6.46.3.

### 28.3 Contextos i comparadors revisats, no nous circuits

Un «bloc» és una secció/propietat del document JSON retornat per SQL, no una nova taula, fase o bloqueig. SourceGroups són grups actuals d'origen, no la base original. L'estat SQL revisat queda separat de les decisions desitjades; al confirmar s'ha de contrastar amb estat actual, no mantenir la transacció durant la pantalla.

Catàleg2/editorial de valor3/tipus4blocs i signatures intactes. Usages conserva assignació9 i SKU reduït amb categoria pròpia/Parkod només SourceIsPresent, sense línia/risc de pertinença afegits. Metadata d'inactius exactament marca–ID/[] real, segona columna de la mateixa fila/SNAPSHOT, no cinquè bloc/paràmetre. Totes les associacions8 també inactives compten per compatibilitat/bloqueig ValueKind; GUI no les converteix en operatives. Comparació exacta de textos/conjunts/absències, no CI_AI d'unicitat; no-op només després de controls, auditar només files realment modificades. Propagació exacta i proves encara pendents, no reversió genèrica.

Creació/rebuig conjunt5blocs amb grup7/associacions8/assignacions9, respostes4conjunts/una filaUUID, signatures/payloads/originals independents conservats. Creador seleccionat/aprovat/mínim un approve i D390 per cadascun en crear; rebuig conjunt sobre unió dels membres **originals**, sense creador aprovat exigit/rebuig de fills implícit. Validació de pertinença5blocs/SKU8/grup7/clau marca–grup–SKU, només flag/risc conservat i D390 abans de no-op. Corrector propi nou6blocs/5conjunts/aprovacions exactament tipus assignats, còpia només llegida. Detalls model§6.46.4–§6.46.5, sense nova decisió per cada adaptació directa.

### 28.4 Connectors: resultat de recerca, no selecció definitiva

Versions examinades: pyodbc5.3.0, pymssql2.4.6/FreeTDS1.5.19 i mssql-python1.17.0. Les dues últimes comunicades per l'usuari; les observacions locals de l'agent en altres intèrprets no les substitueixen. Fonts versionades i límits d'evidència al model§6.46.6. Recerques/lectures de metadata, no connexió SQL, instal·lació o validació de producció.

- Pyodbc integra el número al diagnòstic textual; l'API revisada no dona D402 per resolt.
- Pymssql usa FreeTDS/DB-Library, no ODBC. Preserva número separat en errors SQL d'execució i és **candidat prioritari de validació**, no biblioteca adoptada. Unicode/NVARCHAR(MAX) amb via de crida adequada, formats d'excepció, timeouts globals/fils/TLS/auth/entorn encara per provar.
- Mssql-python ofereix binding Unicode explícit/nextset, però la versió revisada no trasllada nativeError a ErrorInfo/excepció pública. Pool de connexions i dependències empaquetades requereixen contrast, no reenviament de negoci presumptiu o integració Azure aprovada.

Instal·lar paquets o tenir requirements.txt no acredita compatibilitat completa ni decideix dependències del projecte. No adaptar silenciosament D402 o el model a una limitació del connector; no parser textual adoptat.

### 28.5 Conciliació: circuit complet i comprovacions proposades

**VARIANTS_PARKOD.dbo.Parkod→VARIANTS_PARKOD.dbo.ProductVariant/dades pròpies** per les claus SKU3+2+3, no la càrrega externa de producció. La còpia no s'escriu. Alta nova variant/grup propi/auditories atòmics; existent conserva IDs/grup/decisions/classificació/valors, discrepància calculada visible; cada no incorporat té incidència individual d'aquella execució. No variant sense grup/DELETE o totals artificials.

Mateixa connexió dedicada Begin→operacions curtes→Complete o Fail quan pertoqui. Contractes Begin/Complete/Fail intactes, sumes/claus/Reason no proven lectura completa; NOT RUN no és completed/failed no desfà COMMIT previs. No sessió d'app durant conciliació, còpia disponible/estable/coordinació externa efectiva. SourceIsPresent/absències només externs.

El connector no ha d'obrir una transacció exterior de tot el procés. Per pymssql autocommit=False obre BEGIN TRAN; autocommit=True és **proposta tècnica coherent a validar**, no configuració aplicada/driver adoptat. SQL conserva BEGIN/COMMIT/ROLLBACK explícits i atomicitat de cada alta/auditoria, no cada INSERT independent. Connexió perduda atura/no reconstrucció ni Fail des de connexió nova; resultat incert no reenvia. La tria no es basa només51001.

Proves encara a definir/autoritzar: error51001 i altres diagnòstics, Unicode/JSON>4000caràcters, decimals exactes/UUID/token32bytes, tots els conjunts també buits/NULL, COMMIT real/rollback limitat/locks/sessions/desconnexió-resposta perduda. Només dades de domini humanament validades i target2017/Windows2019, sense instal·lar o canviar font/configuració en aquesta tasca. Model§6.46.7.

### 28.6 Estat de represa abans de compactar

D405–D406 i adaptacions desats, històric D01–D404 literal, model13/90/76signatures/funció preservats. E02 resta de cobertura creuada/contextos-retorns/comparadors executables; E04 només no coberts. E05 transport/connector/configuració/missatge-ROLLBACK/matriu/recurs/permisos/propietat/esperes/ordre SQL/integració/proves, no número51001/THROW a tornar a decidir. E07 lectors/escriptors/noms/balanç/parser pendents; altres E01–E11 conservats, etapa0 oberta. No algoritmes/GUI/etapes1–4 o proves SQL-domini-concurrència-integració executats. Compactar la conversa és gestió d'OpenCode, no funcionalitat/checkpoint SQL del projecte.

## 29. Revisió dels canvis de font i conciliació — D407–D414

### 29.1 Acords, model i límit de la consolidació

Consolidació2026-11-10, sense dates inventades dels assentiments. D407 lectura completa a memòria/lector; D408 connector diferit; D409–D410 dues dates per SKU/inicialització; D411 contextos/revisió abans de batch; D412 parella de procediments/auditoria; D413 retirats admissibles; D414 recompte i tasques derivades. Model de disseny **13taules/92camps**, només dues dates noves, cap canvi dels90camps/tipus/PK/FK previs. Còpia completa10/SKU complet9; altres files i originals/snapshots històrics intactes.

**Tall D414 substituït pels acords posteriors:** inventari actual76actives+funció/quatre retirades. D417 confirma dates físiques/avanç/format; D418ReconcileSku, D419Complete6 senseUpdatedCount i D422formaexacta de revisió es formalitzen a §31/model§6.49. Altres arguments de procediments conservats, història literal. No SQLdesplegat ni etapa0tancada.

### 29.2 Dates de canvi i revisió per SKU

**SourceUpdatedAtUtc a la còpia:** propietat exclusiva del procés extern, informada en alta/inicialització i canvi real de DESIGN1/DESIGN2/code1/code2/CLIGNE/SourceIsPresent. Inclou retirada lògica1→0/reaparició0→1; càrrega amb mateix contingut no l'avança. Els codis CMARQ/CCATEG/CPROD identifiquen el SKU; recodificació no actualitza silenciosament la mateixa identitat. No es modifica l'original ni s'afegeixen denominacions font a ProductVariant.

**ReviewedSourceUpdatedAtUtc a ProductVariant:** marca de font revisada, només acció humana expressa, no hora del clic/càrrega/batch. D416 afegeix ReviewedSourceJson, fotografia dels sis camps revisats en la mateixa acció. SQLNULL=mai revisat per ambdós; pendent si marcaNULL/anterior, sense taula de tasques o historial de totes les càrregues. Quatre validacions/riscs/assignacions/grup/IDs/codis independents.

Primera càrrega externa completa amb el mecanisme informa referència UTC d'inicialització de totes les files existents, **no data històrica inventada de producció**. Totes les variants incorporades comencen amb revisadaNULL i apareixen pendents d'aquesta revisió inicial, encara que estiguessin validades. Impacte expressament acceptat; no reset de validacions o marques de revisió automàtiques.

Dates DATETIME2(3)UTC/fontNOTNULL-revisadaNULL/senseDEFAULT confirmats explícitament en conversa. Amb canvi literal, marca=UTCmillis si>anterior, altrament anterior+1ms; contingut/marca conjuntament, sense recàrrega idèntica. Implementació/overflow/recuperació/proves pendents, UTC/tipus sols no garanteixen monotonia. Revisada>font és incoherència, no hora normal d'una revisió tardana. Fotografia D416 associada a la mateixa marca, no història inventada.

VariantsLastCompletedAtUtc continua només final de completa correcta, amb els cinc camps globals/casos parcial/omissions intactes. No data per SKU o revisió humana: una conciliació completa posterior no elimina pendents humans anteriors. Cap veto nou del generador per aquestes dates o revisió pendent confirmat.

### 29.3 Contextos actuals i tècnic abans de conciliació

El tècnic revisa SKU incorporat amb còpia disponible abans del batch: font actual només local/assignacions actuals; D416 referencia els sis valors de l'última revisió per comparar, no font operativa. Contextos SKU amb set dades actuals D411 i completsSKU9 sense LineCode/ambfotografia, reduïts sense fotografia afegida. Cap relectura original o context universal, Usages/editorials no ampliats per semblança. Cobertura/formes/comparadors pendents E02.

Confirmació SQL compara dades font/marca i estat rellevant actuals amb els revisats, sota controls de sessió/permisos/reserva/activitat/integritat/D396/D403. Canvi concurrent exigeix context nou/revisió; no transacció de formulari o confirmació d'una versió posterior no vista. Càrrega0 no és context revisable, tampoc llista buida; operacions independents/login/generador conserven regles.

Canvi de font10:00, tècnic10:20: desa Reviewed=10:00. Si ha corregit un valor, aquell canvi està desat/auditat, no espera batch11:00 o recàrrega per recuperar-lo. Batch conserva correcció i revisió, no crea altra tasca pel mateix canvi. Nova font12:00 torna a deixar pendent. Modificar un valor no confirma per herència tota la font; reconèixer font no aprova grup/pertinença/tipus/valors ni resol CLIGNE discrepant.

### 29.4 Operació expressa de revisió i auditoria

Signatures intactes model§6.47.6/§8.8.26, context exacteD422§6.49.7: lector rep sessió/token/SKU, confirmador afegeixExpectedContextJson, obligatoris sense defaults o fotografia-data-autor lliures. Una fila ContextJsonNVARCHAR(MAX)NOTNULL/set propietats exactes, SKU9/Parkod7/grup7/totesassociacions/totesassignacionsSKU/tipusreferenciats/valorsnomésassignats. Parser/comparadorsSQLpendents, no formafuncional perreaprovar. Sense reserva/auditdelectura.

Confirmador D416 captura sis camps locals i renova fotografia+marca amb font/context verificats; pot significar «he revisat i tot continua correcte», sense corregir valors. Una **source_review/confirmed_change/update**, actor verificat/clauSKU/Before-AfterSKU9 amb fotografia imbricada, dades-auditoria atòmiques/OperationId SQL. Cap nou àmbit/EventKind/ActionName o cinquena validació comercial.

Resposta confirmada una fila UUIDnullable+ProductVariant complet post-COMMIT/captura interna. Ja revisat amb context/control vàlids: no UPDATE/audit/UUIDNULL. Error o resposta incerta no acrediten revisió; D238/no reenvio/rollback presumptiu conservats. Correcció de valor i confirmació de font separades tenen auditories/UUID propis; context antic queda desactualitzat després de corregir, cal tornar a obtenir-lo.

### 29.5 Lectura i admissió de cada SKU durant la conciliació

D407 GetReconciliationSkus(BrandCodesJson opcionalNULL) confirmat: mateixa connexió started/abast fixat/coordinació/còpia disponible, un conjunt amb els deu camps locals de totes les files de l'abast. Tipus/zeros/NULL/textos preservats, retirats i sense variant inclosos; sense filtre de validació o admissibilitat. Lectura completa a memòria **abans de processar SKU**, sense segona connexió/paginació/fitxer intermedi/transacció global. Lectura interrompuda o memòria insuficient no permet treballar amb llista parcial o declarar completed. Buit real només, no dades indisponibles com[].

Variant absent/admissible: variant/grup propi actiu provisional/auditories atòmics, numeració per marca/nom segons fórmula, **sense LineCode i amb fotografia/marca revisadesNULL**. D413 també retirat0, sense exportació/codi/valors absents forçats; admès no és validat. Error conegut sense parcial/clau-motiu explicats, còpia sempre intacta.

Variant existent: preservar IDs/grup/riscs/validacions/assignacions i referència/marca revisades, present o retirat. Balanç no reclassifica ni desfà canvis humans, sense línia pròpia o fotografia actualitzada pel batch. No tipus/valors/associacions/assignacions/codis automàtics per code1 o CLIGNE en aquest circuit; fases2–3 separades/no algoritmes desenvolupats.

Paper de les13taules model§6.47.7 intacte: còpia noméslectura; variant/grup/comptador/auditories en alta atòmica, catàlegs/assignacions/codis conservats. ReconcileSku4args/resposta4 confirmatD418. NomsD421 ambdenominacions puntuals/no comprovacióCLIGNEoriginal/únicCOMMIT; SQL-permisos-impactependents, no error d'accés convertit en nom absent o font escrita.

### 29.6 B.2: balanç del batch, no creació de tasques

**«B.2 — Avaluar l'estat del SKU per al balanç»** substitueix el títol ambigu «Detectar pendents». Serveix per classificar el resultat i log tècnic de l'execució, no és el pas que crea/conserva/fa visible una tasca.

Alta correcta només nova, amb fotografia/marca revisadesNULL; sense variant amb incidència rebutjat/pendent; existent font pendent rebutjat/pendent, revisat/sense altres incidències intacte. D415 retira línia discrepant com a categoria. Un SKU una vegada/sense rejected humana fictícia; RejectedOrPendingCount inclou existents, JSON Complete només sense variant.

Llista derivada de dates persistents: mostrar no escriu/reserva/audita i batch no avança revisada/no elimina/no duplica tasques. SKU existent pendent pot ser visible abans del batch. Retirats també revisió de font pendent; D376 conserva treball validable existent i exclou assignacions absents de tasques. Infraestructura/lectura incompleta/resultat incert no es transforma en Reason d'un rebuig per tancar falsament amb èxit. Vegeu [Interficie d'actualització de VARIANTS_PARKOD](INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md).

### 29.7 Exemple: code1 fa necessari corregir un valor assignat

Exemple fictici, sense canviar unitat/tipus: font code1=50/code2=L i assignació validada volume/ml→valor50. Càrrega externa posa code1=100/data font10:00; assignació50 preservada. Pendent per dates visible sense esperar batch. Tècnic veu font100 i assignació50; selecciona valor100 existent del mateix tipus o prepara NewValueJson, sense editar el catàleg50 compartit.

ConfirmVariantValueCorrection existent §6.23 revalida context/controls i crea valor100 si cal/corregeix assignació/audita atòmicament, retorna dos conjunts complets post-COMMIT. Correcció manual efectiva conserva IsValidated1 i posa risc/originals de filaNULL segons D279, antics a Before/història; grup/tipus/codi intactes. Després, context de revisió de font **nou** amb assignació100, confirmació expressa→Reviewed10:00. Si aquest últim pas no es confirma, correcció100 guardada però font encara pendent. Batch posterior conserva correcció/revisió. Dos circuits/UUID separats, no cascada automàtica de revisió.

### 29.8 Pendents i connector al final del disseny

D408 tria/validació de connector al final del disseny abans de codi, pyodbc primera opció de contrast segons experiència de l'usuari, cap adopció. Recerca de pymssql/execute queda evidència/no prioritat funcional, no prova de fallada general de pyodbc. D402/D406 estructurat sense interpretar missatges intactes, no canvis presumptament menors o relaxació silenciosa dels contractes.

Pendents§32/model§7: contractes/dates/contextos/CHECKfoto/recursos/índexs i DATALENGTH+UNICODED446 confirmats; categoria alfanumèricaD444/controls externsD445. RestenSQL/parser/comparadors/memòria-cobertura, permisos/integracions/neteja/connector al final, consultallistaGUI i proves2017. No mecanismeSQL, UpdatedCount0 o escriptor per reaprovar; E03retirat/E04nomésnocoberts.

**Tall històric D414:** aquests còmputs/marques de proposta no són el disseny després dels assentiments de conversa i D415–D416. Quatre correctors retirats/nouSKU9/fotografia §30. ReconcileSku i retiradaUpdatedCount confirmats en conversa, formalització global separada. Autorització documental no autoritza SQL/desplegament/proves; etapa0 oberta, etapes1–4 no iniciades ni provades.

## 30. Línia només a còpia i última font revisada — D415–D416

### 30.1 Acords i límit de la consolidació

L'usuari confirma expressament eliminar ProductVariant.LineCode amb els canvis de l'estudi d'impacte i afegir ReviewedSourceJson amb els sis camps de l'última revisió del tècnic, per ús informatiu. Consolidació específica2026-11-11; no dates inventades dels assentiments o implementació.

Model **13taules/92camps**: un camp retirat i un afegit, no taula/classificació nova. ProductVariant continua amb nou camps, però **sense LineCode i amb ReviewedSourceJson**; còpia10/grup7/associació8/assignació9/catàlegs5/sessió segura5 i PK/FK intactes. L'antiga línia ja no formava part de claus actuals després de D380.

§30/model§6.48 prevalen sobre les referències anteriors a línia pròpia/discrepància/correctors/vetos i formes afectades. D01–D414 i originals/snapshots/exemples antics amb LineCode es conserven literalment, no com a entrades actuals. Fonts/format legacy/LINE.LineCode intactes; altres assentiments post-D414 no es reobren ni es formalitzen globalment per aquest lot.

### 30.2 Una única línia actual

La línia actual del SKU és **VARIANTS_PARKOD.dbo.Parkod.CLIGNE**, com code1 o les descripcions. No línia classificada lliure o acceptada anterior independent, ni línia comuna del grup.

El carregador continua mantenint exclusivament còpia i SourceUpdatedAtUtc. Canvi literal de CLIGNE genera marca/pendent de font com els altres cinc camps; no trasllada grup, assigna valors, posa flags a0 o aprova res comercialment. SourceIsPresent extern; canvi de CCATEG/CPROD continua un altre SKU. Les dates mantenen el pendent, però no indiquen quin camp canvià: la fotografia de §30.3 serveix per facilitar la revisió.

### 30.3 Fotografia informativa i pantalla

**ProductVariant.ReviewedSourceJson NVARCHAR(MAX) NULL** conserva exactament DESIGN1, DESIGN2, code1, code2, CLIGNE i SourceIsPresent tal com eren a la còpia en l'última revisió expressa. Sis propietats obligatòries/nulls-textos-booleà literals/code1 textual; no normalització/conversió d'unitats, codis SKU, hora del clic, autor, hash o marca duplicada dins del JSON.

No és la càrrega immediatament anterior o l'historial de totes les càrregues. Si l'última revisió tenia50 i hi ha càrregues75/100, es compara **50→100**, no75→100. Càrrega, conciliació i correccions de valor/trasllats no renoven la referència.

En alta/inicialització/mai revisat: fotografia i marca revisada SQLNULL. La GUI mostra valors anteriors **buits**, actuals visibles, sense inventar història o afirmar que tots els camps han canviat. Distingir internament absència de fotografia i un valorNULL legítim d'una fotografia existent.

Exemple informatiu de pantalla, no GUI implementada:

| Champ | Dernière valeur revue | Valeur actuelle |
|---|---|---|
| Ligne — modifiée | 01 | 02 |
| Quantité — modifiée | 50 | 100 |
| Unité | L | L |

Si la font canvia i torna als valors revisats, pot continuar pendent per marca més recent i mostrar zero diferències actuals. No reconstruir canvis intermedis o tancar revisió automàticament per igualtat. La fotografia no determina grup, assignacions, codi, línia operativa o elegibilitat.

### 30.4 Confirmació expressa, auditoria i no-op

GetSkuSourceReviewContext/ConfirmSkuSourceReview conserven signatures. Lector d'una fila ContextJson amb les set propietats ja confirmades en conversa, ProductVariant complet9 inclosa referència anterior i Parkod7 actual. No bloc superior nou o fotografia/data/autor lliures del client; comparar ExpectedContextJson amb estat rellevant actual sota controls SQL de sessió/token/permisos/reserva/activitat/disponibilitat/coordinació.

SQL captura els sis camps **de la còpia local protegida** i en una sola transacció curta confirma fotografia+ReviewedSourceUpdatedAtUtc+auditoria. La marca és SourceUpdatedAtUtc revisada, no hora del clic; dates UTC/mil·lisegons/senseDEFAULT ja confirmats en conversa. Retorn UUIDnullable+SKU complet9 d'una fila, captura interna/post-COMMIT.

Auditoria source_review/confirmed_change/update/actor verificat/clau ProductVariantId/Before-AfterSKU9 amb fotografia imbricada. Una entrada/UUID per operació, no nou àmbit/ActionName/taula, audit de lectures o càrregues. Camps de proposta/risc/resultat/DecisionOutcome de l'esdeveniment SQLNULL per canvi sense proposta; snapshots històrics literals.

Mateixa versió ja revisada/referència coherent/tots els controls superats: no UPDATE/audit/UUIDNULL. No reparar silenciosament una referència absent/incoherent. D238 conserva resultat incert/no reenvio/rollback presumptiu. Revisar font **no aprova grup/pertinença/tipus/valors**; correcció i revisió són crides/UUID separats, amb context nou després d'un canvi rellevant. Retirats poden revisar font sense exportabilitat o valors absents forçats.

### 30.5 Simplificació de controls i circuits

- Retirar incidència separada CLIGNE–LineCode de tasques/balanç. Pendent de font per dates, B.2 només classifica execució/log, no crea tasques.
- Retirar vetosD390/D392 abans de pertinença/codi nou. **No substituir-los per font pendent o diferències informatives com a veto general.**
- Cada circuit conserva sessió/permisos/reserva/grup actiu/marca/associacions/valors/principal/context/integritat/auditoria. Codi nou exigeix almenys un requerit present amb pertinença validada i valors necessaris; codis antics no es revoquen.
- Quatre contractes Get/ConfirmVariantLineCorrectionToExistingGroup/NewGroup retirats. No reanomenament automàtic, procediments buits o via nova; trasllats/creació/validació pels circuits existents amb decisions/controls propis. Mateix grup no exigeix trasllat per revisar font; pertinença provisional s'aprova separadament.
- Inventari consolidat79→75actius+funció, quatre signatures històriques a part. ReconcileSku ja confirmat en conversa, formalització global fora d'aquest lot, no decisió pendent d'aprovació.

### 30.6 Formes JSON i història

ProductVariant complet9 actual: ProductVariantId, ProductGroupId, BrandCode, CategoryCode, ProductCode, EstimatedRiskPercent, IsValidated, ReviewedSourceUpdatedAtUtc, ReviewedSourceJson. Referència imbricada/null explícit, no string escapada. Mateix nombre9 no autoritza un context antic amb LineCode o sense la nova propietat.

Reduïts: senseLineCode/fotografia-data-risc-IsActive afegits persemblança. SKU–valor6/setblocs/grup3-associació5-Parkod7 intactes. **D424 confirma expressament Parkod7 de cada membre real en finalització/substitució completa i reutilitzacions§6.17.2**, blocs6/7 intactes. Membre sis campsSKU+Parkod; Usageseditorials nomésSourceIsPresent (§31/model§6.49.9).

Propostes noves: grup–tipus conserva set propietats superiors i ProductVariants amb només ProductVariantId; pertinença quatre propietats/cinquenaProductGroupName si proposat en grup nou. No CLIGNE o fotografia substituint LineCode. Creació4/SKU–valor11 intactes. Originals persistits i històric no reescrits, no emprats per fabricar referències revisades.

Respostes i nous snapshots que ja incloïen SKU complet usen nouSKU9; altres conjunts/claus no canvien, fora de correctors retirats. No ampliar Usages/editorials/contextos independents. Parser/comparadors/formes pendents E02, sense versió nova o propietats desconegudes ignorades per acceptar context antic.

### 30.7 Generador, noms i control d'accés

El generador conserva l'estat comercial validat fins als canvis expressos: grup/pertinença/habilitacions/valors/codis. Si necessita línia actual local, l'obté de còpia, **no una línia anterior operativa des de fotografia o auditoria**. Integració/permisos/proves pendents, sense canvi de SQL legacy/original, nou exportador o coherència instantània interbases. Font pendent no introdueix veto global.

Noms de grup descriptius/generats una vegada/editables/fonts-fallback del creador conservats, sense regeneració automàtica quan canvia CLIGNE. IDLine de font/còpia=CMARQ+CLIGNE, no camp de ProductVariant. Fonts/unitats/presència externa/clauSKU intactes.

La coordinació posterior D425–D434 està consolidada a §31 i [CONTROL_ACCESSOS_COORDINACIO.md](CONTROL_ACCESSOS_COORDINACIO.md): tres recursos de càrrega/batch/login més AppAdministratorSet només per comptes, sense recursos nous causats pels dos camps. Revisió dependent coordinada/sense lock de formulari; generador independent/GUI segons controls propis.

### 30.8 Represa i verificació

E01 fotografiaJSON/CHECK/DDL; E02 formes/parser/comparadors/història; E03 correctors retirats, no nova correcció de línia per decidir; E04 controls propis restants; E05 permisos/neteja/errors/connector al final; E07 escriptors/balanç/memòria; E08 comparació informativa i cel·les anteriors buides; E09 generador/integració; E10–E11 proves. Assentiments sobre ReconcileSku/retiradaUpdatedCount i altres detalls no es reobren, sense formalització global automàtica per aquest lot.

Contrastar totes les etapes pel canvi d'especificació. Només etapa0 documental, encara oberta; no algoritmes/GUI/proves SQL-domini-concurrència-integració executats. No DDL, instal·lacions, font/dades/configuració, commit o push autoritzats per aquesta consolidació.

## 31. Acords generals de l'etapa 0 consolidats — D417–D443

### 31.1 Estat actual i traçabilitat

Consolidació2026-11-12 dels acords confirmats en conversa, preservant literalment D01–D416. Model de **13 taules/92 camps**, sense cap camp o clau lògica afegits per aquest lot; ProductVariant complet9/còpia10. Inventari **76 signatures actives + NormalizeWhitespace**, quatre correctors de línia retirats i mai reconvertits. ReconcileSku s'incorpora com a contracte confirmat; CompleteReconciliation perd nomésUpdatedCount. Les altres signatures anteriors es conserven.

Aquest capítol i el model§6.49–§6.53 substitueixen les marques de pendent antigues afectades, no les garanties dels circuits. Documentar no és desplegar ni validar etapa0. No s'implementen algoritmes, GUI, carregador extern o exportador; cap escriptura/DDL/permisos/configuració a parkod original. Les proves tècniques anteriors de constants es diferencien expressament de les proves de domini i concurrència.

### 31.2 Dates i revisió de font

D417 concreta les dates: DATETIME2(3) UTC, senseDEFAULT; fontNOTNULL i revisadaNULL. Canvi literal dels sis camps vigilats, inclosos caixa, accents, espais i NULL/buit; retirada i reaparició compten, càrrega idèntica no. Marca nova=UTCmillis si és posterior, altrament anterior+1ms, contingut i marca atòmics; pot avançar el rellotge. Inicialització completa sense història inventada i amb tots els incorporats inicialment pendents, flags comercials intactes. JSON de les dues dates exactament YYYY-MM-DDTHH:mm:ss.fffZ/tres decimals o revisadaJSONnull; no extensió automàtica a altres dates.

ReviewedSourceJson continua només referència informativa de sis valors de l'última revisió, no l'última càrrega ni classificació operativa. D423 aprova CHECKs locals: fotografia i marca totes duesNULL o totes dues informades, JSON vàlid si fotografia informada. El procediment comprova forma exacta/tipus/nulls/sense duplicats-desconegudes i captura de còpia protegida, amb marca i una auditoria atòmiques. No igualtat permanent amb còpia actual o fotografia lliure aportada pel client. Valors anteriors buits si mai revisat, no història reconstruïda. Mateixa versió/referència coherent/controls superats=no-op senseUPDATE/audit/UUID.

D422 confirma lector d'una fila ContextJson de set propietats: ProductVariant/Parkod/ProductGroup/ProductGroupVariantTypes/ProductVariantValues/VariantTypes/VariantTypeValues, amb abast exacte al model§6.49.7. D424 amplia Parkod dels membres reals de finalització i substitució completa a les set dades actuals, amb reutilitzacions expresses d'altes de tipus/corrector existent/fase2. No fotografia als reduïts o ampliació dels Usages editorials, que conserven nomésSourceIsPresent. Revisar font no aprova grup/pertinença/tipus/valors; correccions tenen context nou i UUID separats.

### 31.3 Conciliació i balanç

Seqüència acordada: BeginReconciliation→GetReconciliationSkus consumit completament a memòria→ReconcileSku per cada clau→CompleteReconciliation o tancament de fallada coneguda pel seu circuit. Mateixa connexió dedicada i recursos durant el procés, transaccions curtes per operació; no global, paginació, segona connexió o llista parcial presentada com a completa.

ReconcileSku rep BrandCode/CategoryCode/ProductCodeNVARCHAR(MAX) obligatoris i BrandCodesJsonNVARCHAR(MAX)=NULL. SQL valida clau/abast i rellegeix còpia; una fila ResultCodeNVARCHAR32NOTNULL/ProductVariantIdBIGINTNULL/OperationIdUUIDNULL/ReasonMAXNULL. ResultCode=inserted/unchanged/rejected_or_pending; Reason anglès tècnic no buit noméspending i UUID nomésaltaauditada. Variant absent admissible, tambéretirat0, rep grup propi actiu provisional/fotografia-marcaNULL; existent conserva totes les decisions i referència revisada. Error individual conegut sense parcial pot permetre continuar; infraestructura/incertesa no es converteixen en motius ficticis.

Complete té **sis arguments**, quatre recomptes Read/Inserted/Unchanged/RejectedOrPending, JSON obligatori de no incorporats i abast opcional al final. UpdatedCount **retirat, no enviat a0**. Balanç Read=Inserted+Unchanged+RejectedOrPending; una vegada perSKU, alta correcta nomésinserted. Resposta de cinc columnes i controlsD373 intactes; JSON nomésclaus encara sensevariant, no tots els pendents. B.2 explica l'execució/log, no crea tasques o revisió humana. Les sumes, els textos Reason i els conjunts no substitueixen el consum complet de dades o la causa real.

### 31.4 Creació, comptador i noms descriptius

Primera assignació de comptador: crear0 i assignar1 per marca només si no té grups. Comptador absent amb grups és incoherència tècnica, no reparació ambMAX. Increment/grup/variant si alta/nom/auditories comparteixen transacció i únicCOMMIT, sense reserva preparatòria de número. EsgotamentINT2147483647 en novaadmissióSKU és pending individual ambIDsNULL i cap parcial, incidentJSON si segueixsensevariant; manualcreació és error sensealta, no retorn deReconcileSku per analogia. Identificadors no reciclats.

Nom automàtic: noms de marca/línia del SKU creador i categoria segons fonts/fórmula/fallback aprovats, lectura puntual dins de la creació. **No consultar o comparar CLIGNE original contra còpia per generar-lo**: utilitzar NOM_LIGNE disponible directament, sense avortar per aquella diferència o exigir immutabilitat dels noms finsCOMMIT. Retirada explícita del control intermedi proposat en conversa.

Nom només descriptiu, editable i no regenerat per càrregues. Fallback de línia amb CLIGNE local, normalització/límit150/compacte automàtic conservats; accés fallit o ambigüitat no són nom absent. Nom manual no requereix fonts auxiliars i no rep sufixnumèric; el context delsSKU de creació continua dependent de còpia. No es copien denominacions o mestres ni es promet coherència global entre bases. Permisos, SQL de lectura i impacte pendents.

### 31.5 Recursos, admissió i errors

Quatre noms globals de coordinació a VARIANTS_PARKOD/public, sense taules amb aquests noms:

| Recurs | Ús aprovat |
|---|---|
| ReconciliationRun | Exclusive/Session/0ms, torn únic sense cua, omissió not_run_other_batch. |
| ParkodCopyAccess | Exclusive/Session durant càrrega completa i conciliació, tambéparcial; Shared curt de revisions dependents.5s interactiu/60s processos per adquirir. |
| BatchLoginGate | Shared/Transaction/0ms nomésCreateAppSession; Exclusive/Session/5s inici batch i mantingut durant cicle. |
| AppAdministratorSet | Exclusive/Transaction/5s nomésCreateAppAccount, SetAppAccountAccess i BootstrapAppAccount, abans de comptes-sessions. |

Batch adquireix Run→Copy→Gate. Mentre esperaCopy no veta logins; després comprova sessions sotaGate. Sessióvigent tambéadmin→not_run_active_session immediat/0/NOT RUN, no espera60s a sortida d'usuari. CapFailabansstarted, expulsió o recursos de còpia per marca. Argon2id fora de transacció i Gate. AppAdministratorSet conserva diversosadministradors, no s'adopta l'alternativa d'administradorúnic.

Errors ambTHROW acotats:51001 indicadorCopy0 comprovat sota protecció,51002 esperaesgotada explícitaCopy,51003 esperaesgotada explícitaGate,51004 esperaesgotada explícitaAdminSet,51005 retorn explícit de fallada d'alliberamentSession adquirit. No remapping de permisos/deadlocks/cancel·lacions/transport/COMMITROLLBACK o altresrecursos per defecte, missatgesglobalsSQL o signatures/respostes d'èxit noves. Transport estructurat, no parser de textos; mappingfrancès/connector al final i proves pendents.

### 31.6 Dependències i protecció de sessions

Lectors condicionals: lectura preparatòria de dades pròpies/usos-membres, proteccióCopy abansSNAPSHOT si cal, totcontext definitiu en unSNAPSHOT. Preparatòria no és baseline. Dependència nova descoberta tard senseprotecció→aturar sensecontextparcial/[]fictici/retry/adquisiciótardana; nova consulta expressa. Patró específic d'incertesa usa auditoriaprèvia i protegeixCopy només per estat actualparkod_copy, no per textos històrics.

Mutadors condicionals: segons usos/membres del context esperat, Copyabansbloquejosdades; si esperatbuit, absènciarealSQL protegida sota tipus/grup. Si ara hiha usos/membres, contextcanviat abansDML/audit, no confiar en[]client o adquirirCopytard. Sis famílies grup–tipus, validació de grup, editorials i canvis de catàleg mantenen admissibilitat pròpia; no codi nou sense almenys un requerit present/pertinença validada i valors/principal coherents. Grups amb nomésretirats no buits. SKUexplícit/valors/pertinença/trasllat/creació-rebutjosSKU sempre dependents; catàlegbase, principal, nommanual, comptes-sessions-reserves i desactivaciórealmentbuida independents.

AppSession es protegeix amb bloquejos de dades durant operacióSQLcurta: actualautorització-token-caducitat, no nomésSNAPSHOT antic. Operació admesa primer potacabar; revocació/neteja esperen i revaliden. Caducada o revocada primer no actua, caprenaixement. Creuar el límit temporal durant petició admesa no lacancel·la ni renova automàticament; capformulari/Argon2id/heartbeat bloquejat. IsAdminvigent i desactivació noexpulsiva conservats.

Ordre de dades: Copy si cal→comptes existents perIDascendent→sessions en ordre estableID→revalidació→tipus→SKU→marca/comptador→grup. Papersactor/destinatari noalterenordre; identitatrepetida una vegada i modeprevist. PrefixAdminSet només tresparticipants; CreateSessionGate i batchRun-Copy-Gate conserven seqüències pròpies. Aquest ordre no garanteix absència de bloquejos interns o deadlocks; SQL/permisos/proves pendents.

### 31.7 Tancament, neteja i resultat conegut

Després delCOMMIT de publicacióComplete/Fail: netejar metadades i alliberar Session **Gate→Copy→Run**, només recursos adquirits i comptatgeequilibrat. Omissió/errorinici allibera subconjunt; errorSKUrecuperable no allibera recursos delcicle. ElsTransaction acabenambCOMMITROLLBACK, no releaseexplícit o locks durantformulari.

Si falla unalliberament: aturar seqüència normal, connexió no reutilitzable com a neta/no retornalpool, error tècnic/log i sortidanozero. NoKILL, finalització física immediata presumpta o reintents. ConservarCOMMIT coneguts: després deComplete noFail, després deFail no repetir, abansstarted no iniciar/Fail. Errororiginal i neteja totsdos conservats; transport/tancamentfísic exactes pendents deconnector. Incertesa realD238 sense reenviament/reconnexió-continuïtat/rollbackpresumptiu; neteja fallida sola no fa incert unCOMMIT conegut.

### 31.8 Disseny físic i evidència tècnica

D435–D443 aproven13PKCLUSTERED, unicitatsNONCLUSTERED i vuitaccessos addicionals, inventari inicial33estructures al model§6.52. Mateixescolumnes-tipus-PK/FK-collations, unicitatsfiltrades nomésvalorsnonnull/reservacompleta, índexfiltrat d'auditoria group_variant_type, senseJSONduplicat o columnesextretes perdefecte. OperationId noúnic, LoginNameúnic tambéinactius, diversosadministradorspermesos. Reservaíndex sensefiltretemporal, caducades físiques netejades sota coordinació. No índexnomgrupúnic, DDLoriginal, exclusió de retirats o rendimentgarantit.

Proves autoritzades anteriors2026-11-12: referència enmemòria53018codis contraoracleindependent, SQL2019Express15.0.2210.4 amb680comparacions/884codisordenats/5màximspermarca de constantsFrench_CI_AS. PASS159754asserccions, cincSELECTinclmetadades abans-desprésdestí, zerotaulesusuari/150-SQLLatin-SNAPSHOT0-RCSI0 iguals. Senseoriginalparkod, dadesdenegoci, objectes nous o configuraciómodificada. SQLCMDexistent nomésdiagnòstic, no connectorappadoptat. Evidències al model§6.53, no reexecució en aquestlot.

Aquestes proves no acrediten2017, registres/índexsplansreals, concurrència, assignació-auditoria atòmiques, domini, GUI o procedimentsSQLdesplegats. Etapa0 i E01–E11 oberts segonspendents; no pas a etapes1–4.

### 31.9 Represa i evolució de la validació de codis

La proposta pendent del tallD443 **ha estat expressament confirmada per D446**, després d'aclarir categoria alfanumèrica i reserva/controls externsD444–D445. No s'aprova pel fet de consolidar. Controls token32/normalitzacióbytes-longitud intactes; abast actual§32/model§6.54, SQL/proves pendents.

Després de desar/verificar, reprendre mancances reals de disseny deDDL/comparadors/permisos-cooperació/consultallista/integració/proves2017, no acords ja confirmats. Connector al final abans de codi, pyodbc primeraopció noadoptada. Compactar no és checkpointSQL/reenvio o garantia d'idempotència.

## 32. Categoria, reserva externa i validació exacta — D444–D446

### 32.1 Categoria alfanumèrica i reserva

CCATEG/CategoryCode són exactament dos caràcters ASCII A–Z/0–9, lletres admeses encara que avui no s'utilitzin. D444 substitueix la limitació numèrica de D388, no NVARCHAR(2), zeros, nul·litat, SKU3+2+3, claus o recodificació→nouSKU. També regeix les entradesJSON actuals d'incidències de conciliació. Història D01–D443 i originals/snapshots no reescrits.

L'usuari confirma reserva externa i precisa **categories < 'DE'**. DE queda reservat; comprovar només > 'DE' seria insuficient perquè DE+000 podria coincidir amb el codi nou DE000. Separació basada en respecte de reserva, no en ús actual només numèric. Rang de nouscodis/immutabilitat/registre permanent/assignació atòmica intactes.

### 32.2 Validació i avisos de la càrrega externa

Funcionalitat descrita al lloc del carregador, **§23.2.1**: comprovar marca/categoria/producte/línia amb alfabetASCII senseO/longituds establertes, també CCATEG<'DE', i informar els tècnics d'anomalies. Sense correcció automàtica de font. No traslladar-la al gestor de variants o reactivar l'antic rebuigCPROD/correu retirats.

Aquest acord no concreta per si sol canal d'avís, bloqueig del lot, exclusió de files o retirada automàtica. Càrrega completa fiable/presència/publicació/coordinació i no-intervenció originals conservades; no loader implementat o èxit parcial fictici.

### 32.3 Mecanisme SQL confirmat

**D446: DATALENGTH per longitud exacta i UNICODE per posició** per validar els codis, abans de convertir entrades àmplies a tipus curts i amb CHECKs corresponents a les columnes del projecte. ASCII deSKU A–Z/0–9 en3+2+3, nouParkodVariantCode5 amb0–9/A–N/P–Z; nul·litat segons cada contracte. Sense trim, majusculització, truncament, farciment o reparació silenciosa.

No només igualtat per collation; conservar punts de codi i longitud reals, sense collation nova o funció pròpia. Els controls externs reserva/O dels originals no passen a ser vetos o CHECKs específics nous del gestor. El codi nou conserva la seva exclusió d'O. Detall/dependènciesmodel§6.54.3/§6.12. SQL concret/CHECKs executables/proves2017 pendents, no acreditats per constants2019 o verificació documental.

### 32.4 Estat i continuació

Consolidació2026-11-13,13taules/92camps,76signatures actives+funció/quatre retirades i33índexs de disseny intactes. Només alfabet de categoria/justificació de separació i validacions acordades, no nous camps/tipus/PK/FK/APIs o etapes. DATALENGTH+UNICODE és decisió tancada en disseny, no implementació acabada; etapa0oberta. Represa del lot§6.54/§7, actualitzada després pel repàs§33/model§6.55. Connector al final abans de codificar; cap SQL, DDL, instal·lació, dades/font/configuració, commit o push.

## 33. Repàs conceptual d'integritat i punt de represa

### 33.1 Què s'ha revisat i què continua pendent

Desament2026-11-14 de la revisió en conversa de les13taules i controls principals entre taules. **No s'afegeixen decisions noves de domini**: es recullen i es relacionen els acords vigents, sense numerar-los de nou. Registre finsD446/model13/92/signatures76+funció/quatre retirades/índexs33 intactes. Mapa pertaula al model **§6.55 — Repàs conceptual d'integritat i punt de represa**.

S'han distingit restriccions locals/relacionals de controls transaccionals: codis/longituds/nul·litat/normalització/unicitat, compatibilitatmarca-ValueKind, aprovació de fase2/assignacions, principal segons habilitacions finals, codis permanents/comptador, auditoria, comptes-sessions i estatglobal. FK, índexs o campsBIT no substitueixen autorització actual, disponibilitat real de còpia, context revisat, coordinació o dades-auditoria atòmiques. No s'exigeix categoria/línia comunes en trasllats ni es reaplica D392; D415 i circuits propis prevalen.

RiscNULL=noestimable/0novalida; assignacióabsent no candidata; aprovació de tipus no valida valors/pertinences. Mateixvalor compartible, principal nomésassociacions1/codiinformat. Operacions conegudament confirmades es conserven, error/incertesa no rebuighumà ni rollback assumit. Només proposta explícita decidida pot justificar auditoria amb fila intacta segonsD280; no-opmanualsenseaudit/UUIDNULL i excepciópassword_reset pròpies. Originals, snapshots i secrets segueixen regles existents.

Aquest repàs és **conceptual**, no DDLpreparat, integritat materialitzada, concurrència/SQL2017 provats o etapa0tancada. Resten permisos/SQL/parser/comparadors/integracions/proves humanament validades, i mancances reals encara no detallades. No implementar algoritmes, carregador, exportador oGUI per aquest desament; connector al final del disseny abans de codi.

### 33.2 Recordatori de l'operativa de SynchronizationStatus

Una fila global amb SynchronizationStatusId1. La PKrestringida limita a una fila; la inicialització ha d'assegurar-ne l'existència, sense noucontractedebootstrap. Responsabilitats independents:

| Camps | Responsable |
|---|---|
| ParkodRefreshSucceeded, ParkodLastCompletedAtUtc | Aplicació externa de càrrega completa de còpia. |
| VariantsReconciliationSucceeded, VariantsLastCompletedAtUtc | Gestor de variants en conciliacions completes. |

Per al procés complet corresponent: inici efectiu posaindicador0 i conserva dataanterior; final completcorrecteverificat/publicat posa1 i novadataUTC; falladaconeguda deixa0/dataanterior. DataNULL si maihaacabatcorrectament. Conciliacions parcials per marques i omissions **no modifiquen campsglobals**, tampoc elsParkod. Extern no publica èxit de conciliació i app no publica disponibilitat de càrrega.

DataParkod és de còpia carregada correctament, no producció/revisióhumana.0 no distingeix procés en curs de fallada; conservar data antiga no prova restitució de còpia o rollback delsCOMMIT previs. Recuperació externa només nova càrrega completa fiable/publicadaD379. Una conciliació completa pot tenir incidències individuals controlades, no lectura/infrastructuraincompleta presentada com èxit. Èxitbatch no valida comercialment ni esborra fontpendent; revisarSKU no modifica aquesta taula. Generador independent sense veto global perindicadors0, revisions dependents segonsD396. Detall també§23.5/model§3.14/§6.55.5, incertesaD238 sense reenviament.

### 33.3 E08: acord vigent i proposta encara no confirmada

Els criteris de llista de treball ja estan acordats: cada login, incidències/revisiófont i quatreàmbits devalidació; candidates existents, valors absents i finalitzaciófase2sensecodi diferenciats. Retirats: treball existent admissible visible, mancancesvalors no; inactius nooperables. Font pendent per dates/fotografia només informativa, sense discrepància de línia o veto comercial general. Consulta no crea/reserva/audita/assignapersonalmenttasques, cadaacció context actual/circuit propi. Còpiaindisponible no llistabuida o parcialcompleta fictícia (§22.51/§22.54/model§6.41).

**Pendent de confirmació:** organitzar el resultat amb **una entrada per objecte i motiu pendent**, permetent que un mateixSKU aparegui en diversos apartats per decisions independents. La proposta concreta de set casos/unitats és a [INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md](INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md), **§7 — Proposta pendent: unitat d'entrada de la llista**. Es va preguntar i, abans de contestar, l'usuari va demanar posar al dia documentació; aquesta petició no confirma la proposta.

No nova signaturaSQL, camps exactes/DTO/enum de motius, taula/ID de tasca, historial o representació universal aprovats per analogia. No es transforma en una cinquena validació o implementacióGUI. Els criteris ja confirmats no es reobren pel fet de concretar la granularitat del retorn.

### 33.4 Continuació

Represa: confirmar o ajustar la granularitat proposada a§33.3/model§6.55.6/interface§7; després concretar camps i contracte deconsulta amb controls/permisos/proves. Altres pendentsmodel§7E01–E11 continuen segons manca real; DDL/SQL/2017 encara pendents, connector al final. Desament2026-11-14 nomésdocumental: senseSQL, instal·lació, font/dades/configuració, desplegament, commit o push.
