> **Context inicial històric, no especificació vigent.** L'objectiu SQL Server 2019 d'aquest missatge inicial ha estat substituït per SQL Server 2017 Express, base exclusiva `VARIANTS_PARKOD.dbo`, sense intervenció a la `parkod` original. Prevalen `AGENTS.md`, `docs/Parkod.md`, `docs/DATA_MODEL.md` i els acords vigents de `docs/DECISIONS.md`. Es conserva el text original com a antecedent, no com a instrucció d'implementació.

## Rol
Actua com a desenvolupador backend sènior que escriu codi simple, clar i fàcil de entendre per a algú que té un nivell mig de programació.
## Context
Vull crear des de zero una aplicació multiusuari anomenada "Gestionnaire de variantesG  que permeti a un equip de persones que es dedica a codificar productes afegir a la codificació un codi de declinació que permite classificar-los i mostrar les variants.
 1. Hi haura una primera versió per processar tota una base de dades de codificació i afegir les declinacions i 
 2. una segona versió centrada en un us diari de la aplicació per a crear les variants dels productes nous. 
 Necesito jugar amb percentatges d'encert per ajudar en les validacions manuals.
## Tasca
Crea una app que pugui ser invocada per un equip de persones per a 
1. processar un base de dades de codis de productes i identifiqui les variants 
2. els resultats puguin ser posteriorment validats manualment 
3. en un us diari l'equip pugui introduir les variants de productes nous.
4. hi hagi una sistema d'audit trail de modificacions en les dades per a:
    1. poder tirar feines enrerre facilment
    2. identificar els autors dels canvis 
5. es proporcionara més infomració funcional.
## Restriccions i regles
Tota la codificació de variants així com l'enregistraments de dades es faran en taules SQL noves. NO es tocarà per res la codificació existent per motius de compatibilitat. Es respectaran els conceptes i formats de la base de dades de la codificació actual. En cas de dubtes preguntar abans de tirar endavant.
## Tècniques: 
Tecnologia de backend Python amb llibreries de GUI que permetin un alt nivell d'usabilitat al personal tècnic. L'app resultant sera multifuncional i multiusuari. Ha d'executar en entorn Windows Server i SQLServer 2019. No afegeixis res que no aparegui en aquest missatge. - Disseny net i modern. La programació, parametrització tècnica, logs i tot els missatges de debug i tècnics serà en llenguatge angles. Les interfícies GUI i els missatges al mon exterior seran en llenguatge Francés. 
## Format de sortida
1. Missatges de log d'execució en format texte
2. Interficie GUI per una operativa humana
3. Interficie amb SQLServer de lectura i escriptura.
