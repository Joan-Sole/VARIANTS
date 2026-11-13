# Control d'accessos i coordinació de VARIANTS_PARKOD

## 1. Objectiu, estat i traçabilitat

Document explicatiu actualitzat **2026-11-14, registre vigent finsD446**: recursos de còpia/batch/login **ReconciliationRun, ParkodCopyAccess, BatchLoginGate**, i recurs de comptes **AppAdministratorSet**. Acords D425–D434, amb dependències, protecció de sessions i tractament d'errors. El repàs conceptual posterior no n'afegeix cap ni canvia modes/esperes/errors/signatures.

Traçabilitat a [DECISIONS.md](DECISIONS.md) D365/D367/D379/D396/D402–D406 i consolidació D425–D434; contractes canònics a [DATA_MODEL.md](DATA_MODEL.md) §6.49–§6.51/§8.8 et [Parkod.md](Parkod.md) §23/§31. ReconcileSku i Complete6senseUpdatedCount són D418–D419; no es canvien aquí signatures per explicar bloquejos.

**És disseny acordat, no SQL desplegat ni concurrència provada.** Els assentiments que abans només constaven al xat ara es consoliden als documents canònics. No tornar-los a presentar com a decisions pendents perquè falti SQL. Les proves anteriors de constants2019 només tractaven l'ordre de codis, no aquests recursos, transaccions o permisos.

No crea taules, columnes, procediments o signatures addicionals. Tampoc implementa el carregador extern, modifica la base original `parkod`, escull connector o tanca l'etapa 0. Els punts encara oberts s'enumeren a §12.

**Punt de represa2026-11-14:** [model](DATA_MODEL.md) **§6.55 — Repàs conceptual d'integritat i punt de represa**, [funcional](Parkod.md) §33 i [interfície](INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md) **§7 — Proposta pendent: unitat d'entrada de la llista**. La granularitat objecte-motiu encara no està confirmada; no lector/signatura/recurs/operativa de refresc nous per documentar-la. Sessió/autorització actuals, disponibilitat real de còpia, absència decontextparcial/[]fictici i transaccionscurtes ja acordats es mantenen; la consulta de llista no és nova crida aCreateAppSession, reserva o auditoria de lectura. No es materialitza o prova coordinació amb aquest desament.

## 2. Què és un recurs lògic

Un recurs és un **nom de coordinació gestionat per SQL Server amb `sys.sp_getapplock`**. Els participants demanen accés i comproven que SQL Server l'ha concedit abans de continuar.

`ParkodCopyAccess` **no és** una taula o un bloqueig compartit físic sobre totes les dades. No es creen taules amb aquests noms; els quatre recursos són noms gestionats pel motor i no substitueixen les proteccions de dades.

La identitat efectiva de cadascun combina:

| Element | Valor acordat |
|---|---|
| Base de dades | `VARIANTS_PARKOD` |
| Principal de base de dades | `public` |
| Nom exacte del recurs | Un dels quatre noms de §3 |

Tots els participants han d'utilitzar la mateixa identitat efectiva. Una petició en una altra base o sota un altre principal no serveix per coordinar aquest recurs. Cal conservar literalment els noms acordats, sense afegir-hi marca o usuari.

`public` és el rol incorporat de la base: **no significa accés anònim ni concedeix per si sol permisos sobre taules**. Els permisos efectius del compte de l'app, del carregador i dels procediments continuen subjectes al model aprovat i a verificació. Aquest ús no exigeix crear un rol específic nou.

És coordinació cooperativa: un procés que escrigui directament sense demanar el recurs no queda aturat automàticament per aquest applock. No és una garantia contra manipulació intencionada de credencials o codi, ni una substitució dels permisos i restriccions SQL.

### 2.1 Modes i compatibilitat

| Mode ja concedit | Nova petició | Compatible sobre el mateix recurs? |
|---|---|---|
| `Shared` | `Shared` | Sí |
| `Shared` | `Exclusive` | No |
| `Exclusive` | `Shared` | No |
| `Exclusive` | `Exclusive` | No |

Demanar `Exclusive` no implica obtenir-lo immediatament. Si ja hi ha un compartit incompatible, l'exclusiu encara no està concedit i el carregador no pot començar. Si l'exclusiu ja està concedit, un nou compartit no pot continuar fins a obtenir accés, o acaba sense obtenir-lo segons l'espera aplicable. No es pressuposa un ordre de cua o una garantia d'equitat no provats.

### 2.2 Propietat: `Session` no és `AppSession`

- **`Session` SQL:** el bloqueig pertany a la sessió de la connexió SQL. Un COMMIT intermedi no l'allibera; requereix alliberament explícit en la sortida controlada, amb `sys.sp_releaseapplock`.
- **`Transaction` SQL:** el bloqueig pertany a la transacció curta que l'ha adquirit i s'allibera quan aquesta acaba amb COMMIT o ROLLBACK.
- **`AppSession`:** és la sessió funcional de l'usuari de l'app. No és cap de les dues propietats anteriors ni una connexió SQL mantinguda durant tota la pantalla.

Les connexions dedicades de càrrega i conciliació mantenen la coordinació durant cada procés, **sense una transacció global oberta**. Els detalls executables de neteja i errors encara s'han de provar.

## 3. Els recursos i la seva responsabilitat

| Recurs | Què coordina | Per què és diferent dels altres |
|---|---|---|
| `ReconciliationRun` | Un únic torn d'invocació de conciliació. | Permet ometre una segona conciliació sense deixar-la en cua darrere de la primera. |
| `ParkodCopyAccess` | Accés estable a la còpia entre càrrega, conciliació i revisions dependents. | Impedeix modificar la còpia mentre un participant la necessita estable. |
| `BatchLoginGate` | Creació de sessions d'usuari respecte de l'admissió i execució de conciliació. | Evita un login entre comprovar que no hi ha sessions i començar el batch. |
| `AppAdministratorSet` | Altes de comptes, canvis d'accessos i bootstrap. | Ordena la comprovació/canvi del conjunt d'administradors actius et la inicialització única. |

Els tres primers concreten recursos de §6.7; D434 afegeix expressament el quart només per comptes. No són els únics bloquejos de l'app: tipus, SKU, marques, grups, comptes i sessions tenen coordinació de dades pròpia. No es crea un quart recurs de còpia o un recurs per usuari/marca per aquests noms globals.

### 3.1 Participants, modes i durades

| Participant | Recurs | Mode | Propietat | Durada |
|---|---|---|---|---|
| Carregador extern | `ParkodCopyAccess` | `Exclusive` | `Session` | Abans de marcar inici o escriure còpia, fins a publicar i confirmar el resultat i alliberar. |
| Conciliació | `ReconciliationRun` | `Exclusive` | `Session` | Des de l'admissió de la invocació fins al tancament; alliberament també si l'inici es descarta. |
| Conciliació | `ParkodCopyAccess` | `Exclusive` | `Session` | Abans de comprovar disponibilitat/llegir còpia, durant tota la conciliació. |
| Conciliació | `BatchLoginGate` | `Exclusive` | `Session` | Des d'abans de comprovar sessions vigents fins al tancament, o fins a descartar l'inici. |
| `CreateAppSession` | `BatchLoginGate` | `Shared` | `Transaction` | Només la transacció curta que revalida i crea la sessió. |
| Lector de context dependent de còpia | `ParkodCopyAccess` | `Shared` | `Session` | Adquirit abans d'obrir el SNAPSHOT; alliberat explícitament en acabar la lectura curta. |
| Confirmació/rebuig dependent de còpia | `ParkodCopyAccess` | `Shared` | `Transaction` | Operació curta, abans de comprovar indicador/context i fins al COMMIT/ROLLBACK. |
| CreateAppAccount / SetAppAccountAccess / BootstrapAppAccount | `AppAdministratorSet` | `Exclusive` | `Transaction` | Abans de comptes-sessions finsCOMMITROLLBACK; no formulari/Argon2id. |

La propietat transaccional de les mutacions aplica el contracte existent del model §6.2. Els modes exclusius de **càrrega i conciliació** estan confirmats: el compartit que s'havia proposat per a tota la conciliació va quedar substituït, no és una alternativa vigent.

La conciliació parcial per marques conserva aquesta exclusió **global**: no té un recurs de còpia o de login per marca. La selecció de marques no permet càrrega simultània ni usuaris simultanis.

### 3.2 Esperes acordades i límits de la configuració

| Petició | Comportament acordat |
|---|---|
| `ParkodCopyAccess` per operació interactiva dependent | Espera màxima de **5 segons** per obtenir-lo. |
| `ParkodCopyAccess` per carregador o inici de conciliació | Espera màxima de **60 segons** per obtenir-lo. |
| `ReconciliationRun` | **0ms**; espera esgotada explícita→not_run_other_batch, sense cua o execució posterior. |
| `BatchLoginGate` a CreateAppSession | **0ms**; espera esgotada explícita→51003THROW, cap sessió nova. |
| `BatchLoginGate` a inici batch | **5s**; espera esgotada explícita→51003THROW, no started ni not_run_active_session fictici. |
| `AppAdministratorSet` als tres participants | **5s**; espera esgotada explícita→51004THROW. |

Les esperes són confirmades per cada recurs, configuració tècnica fora GUI/proves pendents. Limiten **l'adquisició**, no operació/connector/vida de sessió; sense reintents automàtics. No extrapolar-les a bloquejos de dades encara no concretats. Els60s són per obtenir còpia, **no per esperar que surti un usuari**: sessió vigent comprovada sotaGate implica omissió immediata.

## 4. Responsabilitats de SQL Server, T-SQL i Python

| Capa | Responsabilitat |
|---|---|
| SQL Server | Gestionar els applocks i fer respectar la compatibilitat entre peticions del mateix recurs. |
| Procediments T-SQL | Demanar i comprovar l'accés, revalidar estat/sessió/permisos/context, executar transaccions curtes i alliberar els recursos que corresponguin. |
| App Python | Orquestrar les crides, conservar la connexió dedicada del batch, gestionar respostes/logs/GUI i mantenir separat el context revisat de les edicions. |
| Carregador extern | Cooperar amb el mateix recurs a `VARIANTS_PARKOD`, mantenir la connexió durant la càrrega completa i publicar-ne el resultat abans d'alliberar. |

**No es substitueix la coordinació SQL per un `Lock` de Python.** Un bloqueig en memòria d'un procés no coordina les altres instàncies de l'app o el carregador extern.

No s'envia un autor lliure a SQL ni es registren secrets. El compte de l'app manté l'accés aprovat per procediments, sense DML directe general. No s'adopta cap connector ni política d'autocommit/pool en aquest document.

## 5. Seqüència del carregador extern

1. Obrir la connexió dedicada al context de coordinació de `VARIANTS_PARKOD`.
2. Demanar `ParkodCopyAccess` en `Exclusive`, propietat `Session`, amb espera màxima de 60 segons.
3. Comprovar que s'ha concedit. **Sense obtenir-lo, no marcar inici, no posar l'indicador a 0 ni modificar la còpia.**
4. Amb l'exclusiu concedit, publicar i confirmar `ParkodRefreshSucceeded=0`, conservant la data de l'última completa correcta.
5. Executar la càrrega completa de totes les marques. Conservar història i claus; completa no significa buidar o recrear la taula. Mantenir la mateixa connexió i el bloqueig malgrat els COMMIT de les transaccions de treball.
6. Verificar completesa i coherència segons el contracte extern. Arribar a l'última instrucció o quadrar un recompte no basta.
7. Només després d'una completa correcta, publicar i confirmar `ParkodRefreshSucceeded=1` i la nova `ParkodLastCompletedAtUtc`.
8. Alliberar explícitament `ParkodCopyAccess` després de publicar el resultat.

Si una càrrega ja iniciada falla sense publicació correcta, l'indicador queda a 0 i la data anterior es conserva. No es pressuposa que la fallada desfaci COMMIT previs. La recuperació és una altra càrrega **completa verificada**, no una parcial que declari èxit global. Una fallada d'adquisició anterior al pas 4 no autoritza a modificar aquests senyals sense protecció.

El carregador no ha d'obtenir `BatchLoginGate`: la càrrega no exigeix expulsar usuaris o impedir logins. Tampoc crea variants/grups o modifica classificacions per efecte d'aquest protocol. És una obligació d'integració del procés extern, **no un carregador implementat pel projecte**.

## 6. Inici, execució i tancament de conciliació

### 6.1 Ordre d'adquisició confirmat

```text
ReconciliationRun (Exclusive, Session)
    -> ParkodCopyAccess (Exclusive, Session)
        -> BatchLoginGate (Exclusive, Session)
```

Aquest ordre és el dels recursos globals d'inici, no un canvi de l'ordre de recursos de dades tipus → SKU → marca/comptador → grup del model §6.2.

### 6.2 Admissió de la invocació

1. Validar identitat SQL tècnica i arguments de `BeginReconciliation`, segons el seu contracte.
2. Obtenir el torn exclusiu de `ReconciliationRun`. Si una altra invocació ja ocupa el torn, retornar `not_run_other_batch`, sense deixar una execució pendent en cua. Això també cobreix un inici que encara espera còpia: no afirma que ja s'hagin processat SKU.
3. Demanar `ParkodCopyAccess` exclusiu, amb espera màxima de 60 segons. Mentre s'espera, **encara no es té `BatchLoginGate`** i no es veten els logins per aquest intent.
4. Amb l'accés a la còpia obtingut, comprovar-ne disponibilitat. Amb `ParkodRefreshSucceeded=0`, no iniciar processament sobre entrada indisponible.
5. Obtenir `BatchLoginGate` exclusiu, espera5s. Els nous CreateAppSession no poden obtenir simultàniament el seu compartit; espera esgotada és51003, no prova d'una sessió d'usuari vigent.
6. Sota aquesta protecció, netejar les sessions caducades i comprovar les vigents. Qualsevol sessió activa, també administrativa, impedeix començar: retornar `not_run_active_session` i alliberar els recursos adquirits. No expulsar sessions ni alliberar reserves vigents per forçar l'inici.
7. Aplicar els altres controls i l'omissió `not_run_up_to_date` només quan el contracte de completa programada ho permeti. No canviar SynchronizationStatus per una omissió; alliberar els recursos corresponents.
8. Si s'admet, establir les metadades de connexió ja aprovades i l'estat d'inici que pertoqui a completa/parcial. Retornar `started` només després del COMMIT efectiu de l'inici.

Els tres `not_run_*` conserven sortida batch 0 i log tècnic inequívoc `NOT RUN`, diferent d'un processament completat o d'un error. Permisos, disponibilitat, infraestructura o una petició incerta no es disfressen d'aquestes omissions.

### 6.3 Processament sobre entrada estable

1. Amb la mateixa connexió dedicada, obtenir totes les files de còpia de l'abast amb `GetReconciliationSkus`.
2. Consumir la lectura **completament a memòria abans de processar cap SKU**. Una lectura interrompuda o memòria insuficient no permet processar la part llegida ni declarar un completed fictici.
3. Mantenir els tres recursos durant el cicle. **No alliberar `ParkodCopyAccess` després de llegir a memòria**: les relectures i comprovacions SQL també necessiten entrada estable.
4. Tractar cada operació amb transaccions curtes, dades/auditoria atòmiques i controls SQL vigents. Els COMMIT individuals no alliberen aquests recursos de propietat `Session`.
5. No escriure la còpia ni donar per revisada la font. La conciliació conserva les correccions humanes confirmades abans d'iniciar-se.

`ParkodCopyAccess` en exclusiu **no impedeix a la conciliació escriure dades pròpies**: no és un bloqueig compartit físic sobre les taules. Les mutacions de `ProductVariant`, grups, comptadors o auditoria continuen protegides pels seus mecanismes específics.

### 6.4 Tancament

En una finalització correcta, `CompleteReconciliation` comprova el balanç/cobertura i publica l'estat de conciliació que pertoqui a completa/parcial. En una execució conegudament incompleta, `FailReconciliation` tanca segons el seu contracte, sense desfer COMMIT previs.

Després del COMMIT efectiu del tancament, netejar les metadades et alliberar els recursos adquirits **en ordre invers: BatchLoginGate→ParkodCopyAccess→ReconciliationRun**. No alliberar abans de publicar/confirmar resultat. En omissió/error d'inici, alliberar només el subconjunt adquirit; abansstarted noFail. Error individualSKU recuperable no allibera recursos del cicle. Equilibrar cada adquisició/alliberament, no reacquirir perSKU amb un únicrelease final. SQL/proves pendents (§10.3).

Una resposta perduda de Complete no autoritza reenviar-lo ni cridar Fail automàticament. Una connexió perduda no es reemplaça per una altra que simuli la continuïtat del cicle.

### 6.5 Per què no basta un únic recurs per a les dues funcions

L'exclusiu de `ParkodCopyAccess` ja evita el solapament entre dues conciliacions, però no identifica per si sol si qui ocupa el recurs és el carregador o una altra conciliació.

Amb només aquest recurs, una segona conciliació podria esperar 60 segons, obtenir-lo quan acabi la primera i executar-se després. No hi hauria solapament, però tampoc l'omissió diferenciada `not_run_other_batch`.

`ReconciliationRun` controla **l'admissió d'invocacions**, mentre que `ParkodCopyAccess` controla **l'estabilitat de la còpia**. Aquesta és la raó de conservar-los tots dos; no és que l'exclusiu de còpia sigui insuficient per evitar simultaneïtat.

## 7. Login i absència de cursa amb el batch

1. `GetAppAccountAuthenticationData` obté les dades mínimes d'autenticació autoritzades.
2. Python verifica Argon2id fora de transacció, sense conservar `BatchLoginGate` durant el càlcul.
3. CreateAppSession obre la transacció curta i demana BatchLoginGate compartit/Transaction **amb espera0ms**, abans de crear la sessió. Espera esgotada explícita→51003, cap alta ni reenviament automàtic.
4. Amb l'accés concedit, revalida compte actiu/hash esperat exacte, token, caducades, sessió única i altres controls aprovats. No substitueix aquestes comprovacions per tenir el bloqueig.
5. Crea `AppSession` i fa COMMIT. Retorna l'identificador només després del COMMIT; el compartit transaccional queda alliberat.

Dos logins poden tenir compartit simultàniament, subjectes als controls SQL de compte/sessió única. No mantenen el bloqueig durant tota la vida d'AppSession.

Si el login confirma primer, el batch trobarà la sessió vigent sotaGate i s'ometrà immediatament. Si el batch obté l'exclusiu i supera admissió primer, CreateAppSession no crea sessió durant el cicle. No s'esténGate a totes les operacions ordinàries de sessió ni durant Argon2id. Hashesperat/compteactiu/sessióúnica/token i resposta post-COMMIT intactes.

**La càrrega externa no obté aquesta porta.** Per això una càrrega no afegeix un veto global de login, mentre que la conciliació sí que s'exclou amb totes les sessions d'usuari.

## 8. Lectura i confirmació d'un context d'usuari

### 8.1 Obrir la revisió

1. Demanar `ParkodCopyAccess` compartit amb propietat `Session`, amb espera màxima de 5 segons.
2. Comprovar la concessió **abans d'obrir la transacció de lectura SNAPSHOT**. Així no es fixa una visió antiga mentre s'espera el carregador.
3. Fer les comprovacions de disponibilitat i controls aplicables i llegir/capturar el context coherent, només de la nova base pel que fa a les dades de revisió de còpia.
4. Acabar la transacció curta de lectura i alliberar explícitament el compartit abans de retornar el context a l'app.
5. En error controlat, tancar la transacció pròpia si s'ha iniciat i alliberar el recurs obtingut abans de propagar l'error quan sigui possible. No retornar un context parcial.

La seqüència SQL exacta i els permisos s'han de provar. SNAPSHOT està aprovat només a `VARIANTS_PARKOD`, no a l'original `parkod`.

### 8.2 Treballar a la pantalla

L'app mostra les dades i conserva el context revisat separat de les edicions. **No manté aquest applock ni una transacció SQL mentre l'usuari pensa o edita.** La reserva funcional del grup, quan pertoqui, és un altre mecanisme.

El carregador pot obtenir l'exclusiu després de la lectura i abans de la confirmació. La seguretat no prové d'immobilitzar la pantalla, sinó de rellegir i comparar el context en confirmar.

### 8.3 Confirmar o rebutjar

1. Obrir la nova transacció curta de l'operació, sobre estat actual.
2. Obtenir `ParkodCopyAccess` compartit amb propietat `Transaction`, abans de comprovar indicador/context de còpia.
3. Verificar de nou disponibilitat, sessió/token, permisos, activitat, reserva i altres controls de l'operació.
4. Rellegir l'estat rellevant sota la protecció corresponent i contrastar-lo amb el context revisat. Un canvi rellevant exigeix nova lectura/revisió; no actualitzar silenciosament el context del client.
5. Si tot és admissible, aplicar només l'acció expressa autoritzada i la seva auditoria atòmicament. Fer COMMIT; el compartit es manté fins al COMMIT/ROLLBACK. Retornar el resultat capturat segons el contracte propi del procediment.

No totes les operacions necessiten la còpia: només s'aplica aquest requisit quan hi ha una dependència real. No afegir-lo per analogia a comptes, nom manual, cancel·lació o altres operacions independents.

### 8.4 Dependència variable dels lectors — D429

Editorials, lector protegit de marca, validació de grup i sis famílies grup–tipus (§6.15/6.17/6.21/6.26/6.27/6.11 del model): verificació d'accés aplicable, lectura preparatòria **de dades pròpies** per detectar usos/membres, SharedCopyabansSNAPSHOT si cal, i després rellegir **tot el context definitiu en un SNAPSHOT curt**. Preparatòria no és baseline ni context retornat; no nou exclusiupertipus només per llegir. Nova dependència no protegida descoberta al definitiu→aturar sense parcial/[]fictici/adquisició tardana/retryautomàtic; nova consulta expressa.

GetUncertainOperationContext conserva preparació específica d'auditoria verificada: proteccióCopy només si retornarà estat actualparkod_copy. Fotografies i originals històrics amb dades font no són dependència actual. Rellegir auditoria i estats definitius en elmateixSNAPSHOT; cap dels dos conjunts com a èxit parcial. Sense dependència real no vetar per l'indicador de còpia.

### 8.5 Dependència variable de mutadors — D430

Context esperat amb usos/membres: SharedCopy/Transaction abans de comptes-sessions i bloquejos de negoci. Esperatbuit: verificar absència real a les taules pròpies sota coordinació exclusiva de tipus/grup, respectant ordre global. Aparició concurrent=contextcanviat abans de modificar/auditar; nova lectura, noCopytard o confiançacega en[]client. JSONesvalida íntegrament.

Àmbit: dos confirmadors editorials, vies§6.30decatàleg, parellavalidaciógrup i sis famílies grup–tipus. No uniforme admissibilitat: tipus amb assignacions no passa a marcaordinària; no salt automàtic a excepcional; ValueKind no-op ambusos encara contrasta tot elcontext. Grupsbuits poden llegir-se/validar-se segons circuit; codi nou segueix requerint almenys un SKU present/pertinença validada i valors/principal. Retirats i pendents són membres, no buits.

### 8.6 Dependències fixes i operacions independents — D431

Revisiófont, vuitSKU–valor, pertinença, trasllat, creació i rebutjos ambSKUoriginals sempre tenen unSKUrevisat ambParkod: no lectura preparatòria per justificar dependència. Assignació absent noSKUabsent; destíbuit no contextbuit. Nommanual evita fonts de denominacions, no la còpia delsSKU de creació.

Principal/nommanual posterior/catàlegbase-altesglobals/comptes-sessions-reserves/desactivaciógruprealmentbuit independents deCopy. Usageseditorials nomésSourceIsPresent, noParkod7 o fotografia afegits. Indepèndencia no és bypass de sessió/permisos/grupactiu: durantcàrrega externa no vetoCopyindependent; durantbatchadmes no sessionsvigents peroperarGUI. Generador existent manté independència/integració pendent, no nousrecursos o vetos.

## 9. Si dos clients escriuen a la mateixa taula

Tenir `ParkodCopyAccess` compartit **no és un permís d'escriptura ni una exclusió entre mutacions de dades pròpies**.

| Situació | Protecció aplicable |
|---|---|
| SKU diferents, mateixa taula d'assignacions | Poden coexistir, subjectes a permisos, reserves, integritat i bloquejos específics de les operacions. |
| Mateix SKU o grup | Coordinació exclusiva corresponent, reserva quan pertoqui, comparació de context actual i bloquejos de dades del motor. Esperar no autoritza a sobreescriure un context antic. |
| Comptador de la mateixa marca | Increment SQL atòmic i coordinació per marca, dins de la transacció de creació; no llegir/calcular un MAX+1 al client. |
| Escriptura a la còpia | Només el carregador extern, després d'obtenir `ParkodCopyAccess` exclusiu. L'app no hi escriu. |

L'ordre tipus → SKU → marca/comptador → grup i les restriccions SQL continuen vigents. No es promet absència d'interbloquejos ni bloqueig físic estrictament per fila en tots els plans d'execució.

### 9.1 Comptes i sessions protegits durant operacions curtes — D432–D433

Protegir el registreAppSession amb **bloquejos de dades** finsCOMMITROLLBACK de l'operació admesa. Comprovar autorització vigent, no nomésSNAPSHOTantic. Logout/revocació/neteja respecten la protecció i revaliden després d'esperar; context de tancament canviat exigeix revisió, no tancament cec. Revocació confirmada primer o sessió ja caducada impedeix actuar; operació admesa pot acabar encara que travessi el límit30min, sense renovar automàticament la sessió. Sense nouapplockglobaldesessió/heartbeat/lockformulari/Argon2id.

Ordre: **Copy si cal→comptes existents perAppAccountId ascendent→sessions perordreestableAppSessionId→revalidació actual→tipus→SKU→marca/comptador→grup**. Identificar sessions sota coordinaciódecomptes; actors/destinataris no canvien ordre. Identitats iguals una vegada, modes previstos abans d'adquirir, no conversionsimprovisades. CreateSession conservaGateprimer; iniciBatchRun-Copy-Gate abanscontrols. Ordre/modes TSQL detallats pendents de prova, no garantia d'absència de deadlocks o nou timeout inventat.

### 9.2 AppAdministratorSet — D434

**Exclusive/Transaction/5s, VARIANTS_PARKOD/public**, abans de comptes-sessions, nomésCreateAppAccount/SetAppAccountAccess/BootstrapAppAccount. Ordena comprovació-canvi del conjunt d'adminsactius i bootstrapbuitatòmic. Primera desactivació admissible confirma; següent revalida estat actual i no pot eliminar l'últimadminactiu. Capnou compte/columnes/índexúnicIsAdmin.

Es mantenen diversos administradors; l'alternativa d'administradorúnic no es va adoptar. No emprar aquestrecurs en login/renovació/reserva/reset/negoci. No transacció durantArgon2id o formulari. COMMITROLLBACK l'allibera automàticament; no tractamentSession ni51005 per aquesta via.51004 només esperaesgotada explícita d'adquisició, no control d'últimadmin, permisos o altreserrors. Sense retries/signatures/respostes d'èxit noves. Sintaxi/permisos/proves pendents.

## 10. Disponibilitat, errors i alliberament

### 10.1 Bloqueig i indicador són complementaris

- L'applock evita coincidència d'operacions incompatibles participants.
- `ParkodRefreshSucceeded` indica si la còpia ha estat publicada com a disponible després d'una càrrega completa correcta.

Obtenir un compartit després d'una fallada del carregador no converteix la còpia en disponible: pot continuar a 0. Cal comprovar l'indicador **després d'obtenir protecció**, no reutilitzar un 1 observat abans.

### 10.2 Errors acotats de disponibilitat, adquisició i alliberament

| Error SQL | Condició acotada | Què no significa |
|---|---|---|
| `51001`, amb `THROW` | Indisponibilitat D396: operació dependent que obté coordinació i comprova `ParkodRefreshSucceeded=0`. | No és un retirat, una línia discrepant, un timeout o qualsevol error d'adquisició. |
| `51002`, amb `THROW` | `sp_getapplock` retorna explícitament espera esgotada en adquirir **`ParkodCopyAccess`**. | No prova càrrega en curs ni s'estén a `BatchLoginGate`, permisos, cancel·lacions, interbloquejos o timeouts del connector. |
| `51003`, amb `THROW` | Espera esgotada explícita en adquirir BatchLoginGate, login o inici batch. | No contrasenya incorrecta, sessióvigent comprovada, font0 o transport. |
| `51004`, amb `THROW` | Espera esgotada explícita en adquirir AppAdministratorSet. | No intent d'eliminar l'últimadmin, permisos, deadlock o cancel·lació. |
| `51005`, amb `THROW` | Retorn explícit de fallada sp_releaseapplock d'un recurs Session adquirit per l'operació. | No alliberamentTransaction, errorCOMMITROLLBACK, desconnexió, font0 o catchgenèric. |

Els casos51001–51005 estan confirmats amb aquestes condicions, no com a catàleg general que substitueixi altreserrors. No missatges globalsSQL, camps o signatures noves. Transport numèric estructurat/mappingfrancès/multierrors/ROLLBACK/neteja encara pendents de connector/proves; no interpretar text oSQLSTATEsol per identificar-los. Runocupat és not_run_other_batch, no un altre error5100x.

Quan no s'obté accés, no continuar sense protecció ni confirmar canvis de negoci. Alliberar només els recursos que l'operació ha adquirit, sense afectar transaccions alienes. Edicions i candidates es conserven; no hi ha auditoria de decisió humana fictícia, expulsió, reenviament o reintent automàtic.

### 10.3 Connexions i resultats incerts

Un bloqueig `Session` no s'allibera simplement fent COMMIT, tancant un cursor o retornant una connexió al pool. Els lectors l'han d'alliberar explícitament en acabar, també en errors controlats. No reutilitzar una connexió com si estigués neta quan no s'ha comprovat la neteja; el tractament executable d'aquests errors encara s'ha de definir/provar amb el connector.

**Fallada d'alliberament confirmadaD428:** aturar seqüència normal, connexió fora d'ús/no retornar alpool com a neta, log tècnic i sortidabatch nozero. Només tancamentfísic segonsconnector pendent, noKILL o alliberamentimmediat presumptiu. Si hi havia un altreerror, conservar totsdos incidents sense ocultar l'original; 51005 no és mapping universal de neteja.

Després deCOMMIT conegut deComplete, noFail ni reenviar; després deFailconegut, no repetir-lo; omissió abansstarted no crea inici/Fail. No desferCOMMIT previs o fer incert unCOMMIT conegut només perquè falli la neteja. Quan resposta/COMMIT són realment incerts, D238 intacte.51005sol no és prova d'estatdades: cal el punt d'execució. RecursosTransaction es deixen aCOMMITROLLBACK, sense releaseexplícit d'aquest camí.

SQL Server allibera els bloquejos de sessió quan aquesta sessió SQL finalitza, però una desconnexió percebuda per l'app no prova que aquesta finalització ja s'hagi produït. Desconnectar RDS no equival a tancar la sessió SQL o AppSession.

D238 es manté: timeout de transport, desconnexió o resposta incompleta poden deixar resultat incert. No assumir rollback, còpia preparada, alliberament immediat, ni que una petició hagi acabat; no reconnectar per reprendre artificialment l'execució o reenviar una confirmació. Els COMMIT previs no es desfan perquè s'hagi perdut la connexió.

## 11. Exemples i compatibilitat amb el capítol 23

### 11.1 Revisió curta abans d'una càrrega

1. Un lector obté compartit, llegeix el context i l'allibera.
2. El carregador pot obtenir exclusiu quan no queden accessos incompatibles; l'usuari continua a la pantalla sense aquest bloqueig.
3. El carregador actualitza la còpia, publica resultat i allibera.
4. L'usuari confirma obtenint compartit de nou. Si ha canviat el context rellevant, es demana nova revisió, sense sobreescriure l'estat nou.

Si la confirmació intenta obtenir compartit mentre la càrrega manté l'exclusiu, no continua sense accés. Si s'esgota explícitament l'espera de 5 segons, és el cas 51002, no una prova que l'indicador sigui 0. Després d'una càrrega fallida, pot obtenir compartit però trobar indicador0: llavors és el cas 51001.

### 11.2 Conciliació esperant el carregador

1. El carregador té `ParkodCopyAccess` exclusiu.
2. La conciliació obté `ReconciliationRun` i espera per la còpia, encara sense `BatchLoginGate`.
3. Els logins no es veten per aquest intent de conciliació durant l'espera. Les revisions dependents de còpia, en canvi, estan subjectes a l'exclusiu del carregador.
4. En obtenir còpia disponible, la conciliació obté la porta de login i comprova sessions. Si algun usuari ha entrat i la seva sessió continua vigent, retorna `not_run_active_session` i allibera els recursos. No l'expulsa per iniciar el batch.

### 11.3 Una segona conciliació

Si una invocació ja té `ReconciliationRun`, una altra s'omet amb `not_run_other_batch` sota el protocol acordat, en lloc d'esperar la seva finalització i executar-se després. Errors d'adquisició diferents de l'ocupació no es converteixen en aquest resultat. Cap llista de treball, RunId o taula nova és necessària per explicar aquesta distinció.

### 11.4 Resum operatiu

| Situació | Logins / GUI | Revisions dependents de còpia | Generador Parkod existent |
|---|---|---|---|
| Càrrega externa | Permesos, sense veto global per càrrega. | Només poden continuar si obtenen compartit i disponibilitat; no s'utilitza una còpia en càrrega o fallida. | Independent; indicadors0 informatius segons contracte. |
| Conciliació admesa | No conviu amb sessions d'usuari vigents; no es creen noves sessions durant el batch. | No hi ha operativa d'usuari simultània; l'exclusiu de còpia també és incompatible amb els compartits participants. | No s'afegeix obligació d'adquirir aquests recursos ni veto nou. |
| Operativa ordinària | Sessions i reserves segons model existent. | Compartit només durant operacions SQL curtes, no durant formularis. | Conserva lectura coherent i integració pendents ja establertes. |

La llista de tasques dependent indisponible es mostra com a temporalment no disponible, no com a «cap tasca» o [] fictici. Els missatges externs són en francès i els logs tècnics en anglès, sense secrets. Vegeu també [INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md](INTERFICIE_ACTUALITZACIO_VARIANTS_PARKOD.md).

Aquest esquema desenvolupa §23.6 i conserva §23.5/§23.7/§23.8: publicació abans d'alliberar, càrrega compatible amb GUI, conciliació incompatible amb sessions, i cap veto nou al generador. No activa SNAPSHOT a `parkod`, no pressuposa coherència instantània entre bases, no usa NOLOCK i no promet impacte nul.

## 12. Acords desats, pendents i verificació futura

### 12.1 Estat consolidat D425–D434

- Noms dels tres recursos, base `VARIANTS_PARKOD` i principal `public`.
- Exclusiu per connexió durant càrrega i conciliació, també parcial per marques; no compartit de conciliació com a alternativa vigent.
- Compartit de lectors amb propietat `Session`, abans del SNAPSHOT i alliberament explícit en acabar; cap lock de formulari.
- `BatchLoginGate` compartit transaccional a CreateAppSession i exclusiu per sessió SQL al batch; no bloqueig durant Argon2id.
- Separació entre torn de conciliació i accés a la còpia per conservar `not_run_other_batch` sense cua d'execucions.
- Ordre `ReconciliationRun` → `ParkodCopyAccess` → `BatchLoginGate`, confirmat expressament.
- Esperes de còpia de 5/60 segons, sense reintents automàtics, i error51002 exclusiu de l'espera esgotada explícita d'aquell recurs.

La consolidació general ja desa també noms/modificacióComplete/ReconcileSku/dates/contextos/índexs, amb les referències canòniques de§1. Aquest document concentra coordinació, inclòsAppAdministratorSet/esperes/errors/condicionals/protecciódesessió; no amplia els arguments dels procediments o camps delmodel.

### 12.2 Disseny o materialització encara pendents

1. Materialitzar els modes/esperes/retorns ja confirmats, sense nous timeouts o errors per analogia. Comptes-sessions i recursosdedades encara requereixen concretar modes/esperes no coberts.
2. SeqüènciesTSQL d'adquisició, comptatge, captura, COMMITROLLBACK, neteja i alliberament per cada camí; condicions51001–51005 conegudes, transmissió d'errororiginal+neteja i tancamentfísic pendent de connector. No reaprovar Run0/Gate0-5/Copy5-60/Admin5.
3. Aplicació executable de la matriu i ordre a cada procediment, inclosos lectors amb preparació/absència verificada/confirmadors i sessióautoritzacióactual; casos encara no coberts no són permisos universals.
4. Comptes i permisos efectius dels participants, coincidència de base/principal/nom, integració obligatòria del carregador extern i impacte real. Cap intervenció del projecte a la base original per obtenir-los.
5. Tria i validació del connector al final del disseny, amb pyodbc com a primera opció de contrast; transport numèric d'errors sense parser de missatges, timeouts del connector, cancel·lacions, connexions/pool i neteja. No s'ha adoptat driver o configuració d'autocommit.
6. Mantenir traçabilitat dels acords i resoldre només mancances reals. **D444–D446 confirmats:** categoria alfanumèrica, controls reserva/O durant càrrega externa amb avisos als tècnics, DATALENGTH+UNICODE per codis aprovat en disseny ([model](DATA_MODEL.md)§6.54/[funcional](Parkod.md)§23.2.1/§32). No recurs/error/signatura nous o trasllat de controls externs al gestor; token/normalització intactes. SQL/proves pendents/etapa0oberta, sense SQL/font modificats en consolidar.

### 12.3 Proves necessàries, no executades

- Exclusió carregador/conciliació i manteniment dels bloquejos `Session` entre COMMIT curts, també en conciliació parcial.
- Segona invocació amb torn ocupat: omissió correcta, sense falsa omissió per permisos o connexió i sense execució posterior en cua.
- Cursa CreateAppSession/BeginReconciliation, diversos logins i sessions caducades/vigents, incloses administratives.
- Logins permesos mentre s'espera el carregador, sense veto anticipat per BatchLoginGate.
- Compartits coexistents, exclusiu incompatible, adquisició abans del SNAPSHOT i alliberament de tots els lectors en èxit/error controlat.
- Canvi de còpia entre lectura i confirmació: context nou exigit, sense escriptura sobre un estat revisat antic.
- Indicador0 amb recurs ja alliberat, càrrega interrompuda després de COMMIT parcials, publicació abans d'alliberament i recuperació només amb completa correcta.
- Distinció51001–51005, ocupacióRun/Gate/Admin, altreserrors-cancel·lació-deadlock-transport et resultat incert, sense remapping genèric, retries o rollback presumptiu.
- Condicionals: preparatòria buida→úsnou alSNAPSHOT/confirmador, absència protegida, capcontextparcial oCopyadquirida tard; grupsretirats no buits i Usages sense fontampliada.
- AppSessionoperaciócurta versuscaducitat-revocació, ordrecompte-sessió en actorscreuats, permísactual; AppAdministratorSet i duesautodesactivacions/bootstrapconcurrent, senseadministradorúnic imposat.
- Connexió física encara viva després de desconnexió percebuda, pooling i fallada d'alliberament, sense assumir una sessió neta o reconstruir un batch amb una altra connexió.
- Concurrència sobre dades pròpies malgrat compartit de còpia, controls de grup/SKU/tipus/comptador i independència del generador.

Les proves de domini/concurrència/integració requeriran autorització i dades de proves adequades, amb compatibilitat **SQL Server 2017 Express / Windows Server 2019**. Escriure aquest document no acredita cap prova SQL ni tanca l'etapa 0.
