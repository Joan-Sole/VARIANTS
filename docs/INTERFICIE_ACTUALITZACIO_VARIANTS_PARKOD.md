# Interficie d'actualització de VARIANTS_PARKOD

## 1. Objectiu i estat

Aclarir treball pendent versus balançB.2. Actualització **2026-11-14, registre finsD446**: repàs conceptual d'integritat desat al [model](DATA_MODEL.md) §6.55 i [funcional](Parkod.md) §33, sense noves signatures o decisions de domini. **§7 recull la proposta d'una entrada per objecte i motiu encara NO confirmada**. Criteris de font/fotografia/categories/retirats vigents; consulta/retorn/GUI i proves pendents. No lector de tasques o format de resposta aprovat pel fet de documentar la proposta.

Descriu el disseny acordat, no una interfície GUI, SQL o programari ja implementats. «Tasques» significa aquí treball pendent mostrat a l'usuari, no files d'una taula de tasques.

## 2. La conciliació no crea files de tasques

No hi ha taula específica de tasques. La llista es calcula amb dades persistents; per revisió de font hi ha dues dates i una fotografia informativa:

| Camp | Responsabilitat |
|---|---|
| `Parkod.SourceUpdatedAtUtc` | El procés extern l'informa en l'alta i l'actualitza quan modifica les dades font acordades, incloent-hi retirada lògica i reaparició. Una recàrrega sense canvis no l'avança. |
| `ProductVariant.ReviewedSourceUpdatedAtUtc` | L'app l'actualitza exclusivament després d'una revisió expressa del tècnic, conservant exactament la marca de font que ha revisat, no l'hora del clic. |
| `ProductVariant.ReviewedSourceJson` | Fotografia informativa dels sis camps font de l'última revisió expressa, capturada per SQL conjuntament amb la marca revisada. SQL NULL si mai revisat; no la renoven carregador o batch. |

El SKU apareix pendent quan es compleix la condició següent, expressada conceptualment, no com a consulta executable:

```text
ReviewedSourceUpdatedAtUtc IS NULL
OR ReviewedSourceUpdatedAtUtc < SourceUpdatedAtUtc
```

`NULL` significa que encara no s'ha confirmat cap revisió de font. Els camps font vigilats són `DESIGN1`, `DESIGN2`, `code1`, `code2`, `CLIGNE` i `SourceIsPresent`. Els tres codis de la clau continuen identificant el SKU; una recodificació és un altre SKU.

### 2.1 Persistència del pendent

La tasca no és temporal ni depèn de la memòria del programa:

- Les dues dates queden desades a la base.
- Mostrar la llista no modifica dades, crea reserves o registra una auditoria de lectura.
- La càrrega i la conciliació no actualitzen la data revisada.
- Una conciliació correcta no elimina el pendent ni el dona per revisat.
- El pendent es manté fins que un tècnic confirma expressament la revisió.
- Un canvi posterior de font torna a deixar el SKU pendent; una nova conciliació no duplica tasques.

La confirmació humana renova fotografia+marca i queda auditada en una mateixa transacció. No elimina una fila de tasca: actualitza la referència de revisió del SKU. No aprova automàticament grup/pertinença/tipus/valors. D415 retira discrepància i correctors de línia: CLIGNE és dada actual de còpia, tractada com code1. Les altres tasques mantenen condicions pròpies.

D417 concreta datesUTC DATETIME2(3) senseDEFAULT i formatJSON .fffZ; fontNOTNULL/revisadaNULL. D423 protegeix parella fotografia-marca: totesduesNULL o totesduesinformades, JSONvàlid si fotografia. Forma exacta de sis camps capturada pelprocediment SQL, no fotografia lliure delclient o igualtatpermanent ambcòpia. No-op només versiója revisada/referènciacoherent/totscontrols, senseUPDATE/audit/UUID. DDL/parser/provespendents.

Per a SKU nou, la conciliació crea ProductVariant sense LineCode, amb fotografia i data revisadesNULL. Per a un existent, un canvi pot deixar pendent després de càrrega completa publicada correctament, **abans de la conciliació**, sense modificar decisions o referència anterior.

### 2.2 Revisió humana abans de conciliar

Si la càrrega canvia un SKU a les 10:00 i el tècnic revisa aquella font a les 10:20, la marca revisada queda a les **10:00**, no a les 10:20. La conciliació posterior conserva tant la revisió com les correccions humanes ja confirmades. No cal que una altra càrrega detecti el canvi fet a `ProductVariant`: aquest canvi ja està desat en les dades pròpies i la seva auditoria.

La confirmació comprova font i estat rellevant actuals. Si canvien, nova lectura/revisió, no reconeixement d'una versió posterior no vista. Si còpia indisponible, no [] com si no hi hagués feina o confirmació fictícia: D396/D403/D406 i mecanisme de [CONTROL_ACCESSOS_COORDINACIO.md](CONTROL_ACCESSOS_COORDINACIO.md).

### 2.3 Mostrar què ha canviat respecte de l'última revisió

ReviewedSourceJson NVARCHAR(MAX) NULL conserva exactament DESIGN1, DESIGN2, code1, code2, CLIGNE i SourceIsPresent. La GUI pot comparar literalment aquests valors amb la còpia actual i destacar diferències, per exemple última revisió code1="50"/CLIGNE="01" versus actual"100"/"02". La referència és l'última revisió del tècnic, no l'última càrrega intermèdia.

Sense referència anterior, valors anteriors **buits**, actuals visibles; no inventar-los o afirmar que cada camp ha canviat. Càrregues i correccions de valors/trasllats no renoven la fotografia. Serveix només d'informació: no línia antiga vigent o veto nou per diferències, ni aprovació comercial.

La condició de dates continua determinant el pendent, també si la font va canviar i després va tornar als mateixos valors revisats: pot haver-hi pendent amb zero diferències actuals. No historial complet de càrregues, taula de tasques o tancament automàtic per igualtat de JSON. Històric/auditories anteriors literalment intactes.

## 3. Funció de la comprovació de pendents durant la conciliació

El punt anteriorment anomenat **«B.2 — Detectar pendents»** s'entén millor com:

### B.2 — Avaluar l'estat del SKU per al balanç

La conciliació comprova les condicions de pendent acordades per classificar el resultat del processament i explicar-lo al log tècnic.

Per a un SKU existent:

- Sense incidències: compta com a **intacte**.
- Amb revisió de font pendent o altra incidència definida: compta com a **rebutjat/pendent**. No incidència separada CLIGNE–LineCode després de D415.

Cada SKU compta una sola vegada, encara que tingui diversos motius. Aquesta categoria tècnica no significa que un tècnic hagi rebutjat una proposta. Una alta correcta compta només com a **nova**, encara que el SKU comenci amb revisió humana pendent; una incidència d'admissió sense variant compta com a **rebutjat/pendent**.

D418 formalitza ReconcileSku(clauSKU,abastopcional): una fila ResultCode/ProductVariantId/OperationId/Reason, SQLrellegeixcòpia/mateixaconnexióstarted/altaatòmica o existentconservat. D419 **elimina UpdatedCount**, no l'envia a0: Complete té sisarguments i balanç Read=Inserted+Unchanged+RejectedOrPending. Mateixa resposta5columnes, JSON nomésSKUencarasensevariant; la llista de revisió no és aquellJSON o un quartrecompte.

### 3.1 Exemple amb variant existent

Un SKU existent té la font pendent de revisar. La conciliació:

1. El compta una vegada a `RejectedOrPendingCount`.
2. Registra el motiu al log tècnic, en anglès.
3. Conserva les dades, les decisions i la data revisada existents.
4. No crea cap fila de tasca.
5. No l'inclou a `UnincorporatedSkuIncidentsJson`, perquè ja té variant.

Aquest JSON de tancament conté exclusivament els SKU de l'abast que continuen **sense** variant, amb una incidència d'admissió individual justificada. Errors d'infraestructura, lectures incompletes o operacions incertes no es converteixen en simples pendents per declarar una conciliació completa.

## 4. Distinció essencial

**La llista de tasques mostra el treball pendent dels tècnics. El balanç de conciliació explica què ha trobat i processat el batch.**

La comprovació B.2 serveix per al segon objectiu. No és necessària per crear, conservar o mostrar la tasca de revisió de font d'un SKU ja incorporat. `VariantsLastCompletedAtUtc` continua indicant l'última conciliació completa correcta: no és una data de revisió humana i no tanca les tasques.

Els canvis de font no reassignen comercialment res. Grup/tipus/valors es corregeixen pels circuits i controls propis; els quatre correctors de línia queden retirats, sense substitució automàtica. Es retiren vetos de discrepància, no s'afegeix veto general per font pendent. No gestor d'assignació personal, taula de tasques, historial complet de font, generador de línia anterior o procés d'exportació nou. Només disseny documental, no GUI/SQL implementats.

## 5. Context revisat, dependències i noms

GetSkuSourceReviewContext té una resposta confirmada d'una fila ContextJson amb set propietats exactes (§6.49.7 del model). ProductVariant complet9 inclou referència anterior; Parkod conté font actual7. D424 amplia els membres de finalització/substitució completa i reutilitzacions aParkod7, no elsUsageseditorials (nomésSourceIsPresent), ni afegeixfotografia alsreduïts.

Dependència variable: preparatòria de dadespròpies, SharedCopyabansSNAPSHOTsi cal, context definitiu d'un mateixSNAPSHOT. Dependència nova no protegida→aturar sensecontextparcial/[]fictici/adquisiciótardana o retry; nova consultaexpressa. Mutadors ambcontextesperatbuit comprovenabsènciarealprotegida; membresnous=contextcanviat, no permissióperquè[]client. SKUexplícits semprecòpia; principal/nommanual/catàlegbase/comptes/desactivaciórealmentbuida independents. Grupambretiratsno buit, fontpendent no veto universal.

ProductGroupName es genera només en creació amb fonts delcreador i fórmula/fallback/límit150 aprovats. D421 **retira comprovació deCLIGNEoriginal**: NOM_LIGNE disponible directament, dada descriptivaeditable/no congelaciófinsCOMMIT/no regeneració després decàrrega; fallback de línia ambCLIGNEcòpia. Nommanual senseconsultaauxiliar, no eliminadependènciaCopydelsSKU de creació. No nova tasca de discrepànciadenom o aprovaciócomercial per aquestnom.

## 6. Estat de les proves i següent pendent

Proves anteriors de referència i constantsSQL2019 PASS, detallmodel§6.53: no GUI, domini, concurrència, índexreal, SQL2017 o procedimentsdesplegats. ÍndexsD435–D443 són disseny, no implementació deconsulta de tasques. Aquesta consulta/retorn/presentació continuen pendentsE08, sensecamp/taula/reserva/assignaciópersonal afegits.

**Actualització2026-11-13/D444–D446:** categoria de dos caràcters ASCIIA–Z/0–9, no només numèrica; DATALENGTH+UNICODE per codis aprovat en disseny, SQL/proves2017 pendents ([model](DATA_MODEL.md)§6.54). Càrrega externa valida marca/categoria/producte/línia senseO i CCATEG<'DE', avisa tècnics ([funcional](Parkod.md)§23.2.1); no nova tasca/notificació/filtreSKU al gestor o correcció de font. Etapa0oberta, sense SQL/instal·lació/desplegament/commit/push. Coordinació/incertesa a [CONTROL_ACCESSOS_COORDINACIO.md](CONTROL_ACCESSOS_COORDINACIO.md).

## 7. Proposta pendent: unitat d'entrada de la llista

**Estat a2026-11-14: PROPOSTA NO CONFIRMADA.** Es va presentar després del repàs conceptual de les13taules i controls entre taules; abans de respondre la pregunta de confirmació, l'usuari va demanar documentar el punt. Posar al dia documentació no és un assentiment a la proposta. No hi ha nova decisióD, signaturaSQL, camps exactes oGUI implementada.

### 7.1 Base funcional ja acordada

D368/D370/D374–D378/D415–D416 estableixen llista a cada login, dues categories principals i quatre àmbits comercials diferenciats. Fontpendent perdates, fotografia nomésinformativa. Candidates devalor existents separades d'assignacions absents, associacions aprovades sensecodi com finalització; retirats amb treball existent admissible sí/mancancesvalors no, inactius nooperables. Lectura no crea/reserva/audita ni assigna personalment feina. No imposa resoldre tota la llista o aprova perherència; accions pels circuits propis/contextactual. SenseParkoddisponible, no []fictici o parcial presentat com complet. Aquests punts ja decidits no requereixen nova confirmació.

### 7.2 Granularitat proposada, pendent d'assentiment

**Proposta:** una entrada del resultat calculat per objecte i motiu pendent. Els casos funcionals de treball són existents; la granularitat i organització del retorn següents encara es proposen:

| Treball pendent | Unitat proposada de la llista |
|---|---|
| Revisar font | Un SKU. |
| Validar grup | Un grup. |
| Validar pertinença | Un SKU en el seu grup actual. |
| Aprovar associació grup–tipus | Una associació candidata existent. |
| Finalitzar associació aprovada sense codi | Una associació, diferenciada de la candidata pendent d'aprovar. |
| Validar valor candidat existent | Una parella SKU–tipus amb assignació pendent existent. |
| Assignar valor absent | Una parella SKU–tipus absent, diferenciada de la candidata, sense tasca de mancances per retirats. |

Un mateixSKU **podria** aparèixer en diferents apartats: per exemple font pendent i valor pendent de validar. Es tractaria de decisions independents, no d'una segona filaSKU o aprovació conjunta. Aquesta possibilitat forma part de la proposta encara no acceptada, no d'un contracte de recompte o criteri de deduplicació ja aprovat.

### 7.3 Què no s'ha aprovat i com reprendre

No s'han aprovat per aquesta proposta noms/signatures deprocediments, DTO/camps/enum de motius, formatJSON, ordenació/paginació, resposta o recompte de tasques, nouIDde tasca, persistència, assignaciópersonal o historial. «Entrada» significa element de lectura calculat, no fila d'una nova taula. Model13/92/inventari76actives+funció/quatre retirades intactes; no ampliar-lo per semblança amb altreslectors.

**Pregunta pendent concreta:** confirmar o ajustar una entrada per objecte i motiu, amb possible mateixSKU en diversosapartats, abans de definir camps exactes del retorn. Després cal concretar consulta/contracte/controls/permisos i proves, sense començarGUI o executarSQL dins d'aquesta tasca. Punt de represa també model§6.55.6/§7E08 i funcional§33.3. Etapa0continua oberta, connector al final del disseny abans de codificar.
