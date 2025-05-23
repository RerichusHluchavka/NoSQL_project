# Dotazy

Dotazy jsou byly spoušteny v `mongo shell`u po inicializaci a importování dat pomocí:

    docker-compose up --attach init-container

Do `mongo shell`u se dá připojit pomocí:

    docker-compose exec router01 mongosh --port 27017 -u "admin" -p "admin" --authenticationDatabase admin

Dotazy většinou pracují s databází `mojedb` a kolekcemi `narozeni, plodnost, nadeje`.

## Práce s daty
Dotazy které pracují s daty (insert, update, delete, merge)

### Dotaz 1
Přetypuje všechny hodnoty `IndicatorType` v kolekcích na string pomocí `updateMany` a `toString`. Následně ověří, že jsou hodnoty přetypovány na string pomocí `findOne`.:


    db.nadeje.updateMany(
        {},
        [
            {
                $set: {
                    IndicatorType: { $toString: "$IndicatorType" }
                }
            }
        ]
    );

    db.plodnost.updateMany(
        {},
        [
            {
                $set: {
                    IndicatorType: { $toString: "$IndicatorType" }
                }
            }
        ]
    );

    db.narozeni.updateMany(
        {},
        [
            {
                $set: {
                    IndicatorType: { $toString: "$IndicatorType" }
                }
            }
        ]
    );

    db.nadeje.findOne({ IndicatorType: { $type: "string" } });
    db.plodnost.findOne({ IndicatorType: "5406" });
    db.narozeni.findOne({ IndicatorType: "4355" });

### Dotaz 2
Vytvoří embedded dokument v nové kolekci `prumery` s průměrnou nadějí dožití mužů a žen pro každý rok.
Vyhledání a vypočítání průměru provede pomocí `aggregate` a vloží je do kolekce `prumery` pomocí `merge`. Následně ověří zda jsou data vložena do kolekce `prumery` pomocí `find`.

    db.nadeje.aggregate([
        {
            $match: {
                Pohlaví: { $in: ["muži", "ženy"] }
            }
        },
        {
            $group: {
                _id: { rok: "$Roky", pohlavi: "$Pohlaví" },
                prumerNadeje: { $avg: "$Hodnota" }
            }
        },
        {
            $group: {
                _id: "$_id.rok",
                prumery: {
                    $push: {
                        pohlavi: "$_id.pohlavi",
                        prumer: "$prumerNadeje"
                    }
                }
            }
        },
        {
            $project: {
                _id: 0,
                rok: "$_id",
                nadeje: {
                    $arrayToObject: {
                        $map: {
                            input: "$prumery",
                            as: "item",
                            in: [ "$$item.pohlavi", { $round: [ "$$item.prumer", 2 ] } ]
                        }
                    }
                }
            }
        },
        {
            $sort: { rok: 1 }
        },
        {
            $merge: {
            into: "prumery",
            whenMatched: "merge",
            whenNotMatched: "insert"
            }
        }
        ]);

        db.prumery.find({ nadeje: { $exists: true } }).pretty()       
   
## Dotaz 3

Vytvoří embedded dokument v kolekci `prumery`, který průměruje hodnoty z kolekce narozeni podle roku a jednotlivých ukazatelů.
Vyhledání a vypočítání průměru provede pomocí `aggregate` a vloží je do kolekce `prumery` pomocí `merge`. Následně ověří zda jsou data vložena do kolekce `prumery` pomocí `find`.

    db.narozeni.aggregate([
        {
            $group: {
                _id: { rok: "$Roky", indicator: "$IndicatorType" },
                prumer: { $avg: "$Hodnota" },
                Ukazatel: { $first: "$Ukazatel" }
            }
        },
        {
            $group: {
                _id: "$_id.rok",
                indikatory: {
                    $push: {
                        ukazatel: "$Ukazatel",
                        indicator: "$_id.indicator",
                        prumer: { $round: ["$prumer", 2] }
                    }
                }
            }
        },
        {
            $project: {
                _id: 0,
                rok: "$_id",
                indikatory: 1
            }
        },
        {
            $sort: { rok: 1 }
        },
        {
            $merge: {
                into: "prumery",
                whenMatched: "merge",
                whenNotMatched: "insert"
            }
        }
    ]);

    db.prumery.find({ indikatory: { $exists: true } }).pretty()

## Dotaz 4
Vytvoří embedded dokument v kolekci `prumery`, který průměruje hodnoty plodnosti podle věkových kategorií a roků.
Vyhledání a vypočítání průměru provede pomocí `aggregate` a vloží je do kolekce `prumery` pomocí `merge`. Následně ověří zda jsou data vložena do kolekce `prumery` pomocí `find`.

    db.plodnost.aggregate([
        {
            $group: {
                _id: { rok: "$Roky", vekovaKategorie: "$Věk (jednoleté skupiny)" },
                prumerPlodnosti: { $avg: "$Hodnota" }
            }
        },
        {
            $group: {
                _id: "$_id.rok",
                vekoveKategorie: {
                    $push: {
                        vekovaKategorie: "$_id.vekovaKategorie",
                        prumer: { $round: ["$prumerPlodnosti", 2] }
                    }
                }
            }
        },
        {
            $project: {
                _id: 0,
                rok: "$_id",
                plodnostPodleVeku: {
                    $sortArray: {
                        input: "$vekoveKategorie",
                        sortBy: { vekovaKategorie: 1 }
                    }
                }
            }
        },
        {
            $sort: { rok: 1 }
        },
        {
            $merge: {
                into: "prumery",
                whenMatched: "merge",
                whenNotMatched: "insert"
            }
        }
    ]);

    db.prumery.find({ plodnostPodleVeku: { $exists: true } }).pretty()


## Dotaz 5
Vloží globální průměry pro plodnost v jednotlivých rocích do kolekce `prumery`.
Vyhledá a vypočítá průměr pomocí `aggregate` a vloží je do kolekce `prumery` pomocí `merge`. Následně ověří zda jsou data vložena do kolekce `prumery` pomocí `find`.

    db.prumery.aggregate([
        {
            $match: { plodnostPodleVeku: { $exists: true } }
        },
        {
            $project: {
                rok: 1,
                prumery: {
                    $map: {
                        input: "$plodnostPodleVeku",
                        as: "item",
                        in: "$$item.prumer"
                    }
                }
            }
        },
        {
            $project: {
                rok: 1,
                globalniPrumerPlodnosti: { $round: [{ $avg: "$prumery" }, 2] }
            }
        },
        {
            $merge: {
                into: "prumery",
                whenMatched: "merge",
                whenNotMatched: "insert"
            }
        }
    ]);

## Dotaz 6
Smaže z kolekce `prumery` dokumenty, kde je naděje dožití žen je větší než naděje mužů o více jak 3.8, a zobrazí data, která budou smazána.
Vytvoří konstantu `toDelete`, pro vysání dat, které budou smazány. Poté provede `deleteMany` pro smazání dokumentů, které splňují podmínku. Následně ověří zda jsou data smazána pomocí `find`.


**! Data se budou používat v dalších dotazech, takže mazat pozdeji**

    const toDelete = db.prumery.find({
        "nadeje.ženy": { $exists: true },
        "nadeje.muži": { $exists: true },
        $expr: { $gt: [ { $subtract: [ "$nadeje.ženy", "$nadeje.muži" ] }, 3.8 ] }
    }).toArray();

    print("Dokumenty k odstranění (počet: "+ toDelete.length  +"):");
    printjson(toDelete);

    db.prumery.deleteMany({
        "nadeje.ženy": { $exists: true },
        "nadeje.muži": { $exists: true },
        $expr: { $gt: [ { $subtract: [ "$nadeje.ženy", "$nadeje.muži" ] }, 3.8] }
    });

## Agregační funkce
Dotazy které pracují s agregačními funkcemi

### Dotaz 1
Spočítá průměrnou naději dožití žen mezi staré 30-35 let v letech 2015-2017 pro regiony CZ05 a CZ06 zaokrouhlenou na 2 desetinná místa. Výstup bude obsahovat region, rok, průměrnou naději dožití a počet záznamů.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a roku. Nakonec použije `project` pro výběr a zaokrouhlení výsledků.


    db.nadeje.aggregate([
        {
            $match: {
            Pohlaví: "ženy",
            Roky: { $gte: 2015, $lte: 2017 },
            Uz01A: { $in: ["CZ05", "CZ06"] },
            "Věk (roky)": { $gte: 30, $lte: 35 }
            }
        },
        {
            $group: {
            _id: null,
            prumernaNadejeDožití: { $avg: "$Hodnota" },
            pocetZaznamu: { $sum: 1 }
            }
        },
        {
            $project: {
            _id: 0,
            region: "$_id.region",
            rok: "$_id.rok",
            prumernaNadejeDožití: { $round: ["$prumernaNadejeDožití", 2] },
            pocetZaznamu: 1
            }
        }
    ]);

### Dotaz 2
Spočítá průměrnou plodnost žen ve věku 20-40 let pro všechny kraje a ukáže 5 krajů s největší průměrnou plodností.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a průměrné plodnosti. Nakonec použije `sort` a `limit` pro seřazení a omezení výsledků na 5 krajů, které pomocí `project` zaokrouhlí na 2 desetinná místa.

    db.plodnost.aggregate([
        {
            $match: {
            "Věk (jednoleté skupiny)": { $gte: 20, $lte: 40 },
            $expr: { $ne: ["$Uz012", "$Uz01A"] }
            }
        },
        {
            $group: {
            _id: "$Uz012",
            prumernaPlodnost: { $avg: "$Hodnota" },
            pocetZaznamu: { $sum: 1 },
            Oblast: { $first: "$Oblast" }
            }
        },
        {
            $sort: { prumernaPlodnost: -1 }
        },
        {
            $limit: 5
        },
        {
            $project: {
            _id: 0,
            kodOblasti: "$_id",
            Oblast: "$Oblast",
            prumernaPlodnost: { $round: ["$prumernaPlodnost", 2] },
            }
        }
    ]);

### Dotaz 3

Ukáže v jakých krajích je největší a nejmenší průměrný věk matky při porodu prvního dítěte a průměrný věk matky při porodu dítěte.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a průměrného věku matky při porodu. Nakonec použije `addFields` pro výpočet rozdílu mezi průměrným věkem matky při porodu prvního dítěte a průměrným věkem matky při porodu dítěte. Použije `sort` pro seřazení výsledků podle rozdílu a `facet` pro zobrazení největšího a nejmenšího rozdílu.

 Nepůjde pokud se předtímto dotazem nespustil dotak který přetypovává `IndicatorType` na string (případně je třeba změnit v dotazu IndicatorType: { $in: ["7406", "7406D1"] } -> IndicatorType: { $in: [7406, "7406D1"] }).

    db.narozeni.aggregate([
        {
            $match: {
            IndicatorType: { $in: ["7406", "7406D1"] },
            $expr: { $ne: ["$Uz012", "$Uz01A"] }
            }
        },
        {
            $group: {
            _id: {
                kraj: "$Uz012",
                typVeku: "$IndicatorType"
            },
            prumerVek: { $avg: "$Hodnota" },
            nazevKraje: { $first: "$Oblast" }
            }
        },
        {
            $group: {
            _id: "$_id.kraj",
            nazevKraje: { $first: "$nazevKraje" },
            vekData: {
                $push: {
                typ: "$_id.typVeku",
                vek: "$prumerVek"
                }
            }
            }
        },
        {
            $addFields: {
            rozdilVeku: {
                $subtract: [
                { 
                    $arrayElemAt: [
                    "$vekData.vek",
                    { $indexOfArray: ["$vekData.typ", 7406] }
                    ]
                },
                { 
                    $arrayElemAt: [
                    "$vekData.vek",
                    { $indexOfArray: ["$vekData.typ", "7406D1"] }
                    ]
                }
                ]
            }
            }
        },
        {
            $sort: { rozdilVeku: -1 }
        },
        {
            $facet: {
            nejvetsiRozdil: [{ $limit: 1 }],
            nejmensiRozdil: [{ $sort: { rozdilVeku: 1 } }, { $limit: 1 }]
            }
        }
    ]);

### Dotaz 4
Ukáže nadeji dožití (v roce 2023) věkové skupiny žen která má průměrně největší plodnost.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle věkové skupiny a průměrné plodnosti. Nakonec použije `sort` a `limit` pro seřazení a omezení výsledků na 1 věkovou skupinu, která má největší průměrnou plodnost. Použije `lookup` pro připojení dat z kolekce `nadeje` a `unwind` pro rozbalení výsledků.

 Nepujde pokud se předtímto dotazem nespstil dotak který přetypovává `IndicatorType` na string (případně je třeba změnit v dotazu IndicatorType: "5406" -> IndicatorType: 5406).

    db.plodnost.aggregate([
        {
            $match: {
            IndicatorType: "5406"
            }
        },
        {
            $group: {
            _id: "$Věk (jednoleté skupiny)",
            prumernaPlodnost: { $avg: "$Hodnota" },
            pocetZaznamu: { $sum: 1 },
            Oblast: { $first: "$Oblast" },

            }
        },
        {
            $sort: { prumernaPlodnost: -1 }
        },
        {
            $limit: 1
        },
        {
            $lookup: {
            from: "nadeje",
            let: { vekovaSkupina: "$_id" },
            pipeline: [
                {
                $match: {
                    $expr: {
                    $and: [
                        { $eq: ["$Věk (roky)", "$$vekovaSkupina"] },
                        { $eq: ["$Pohlaví", "ženy"] }
                    ]
                    }
                }
                },
                { $sort: { Roky: -1 } },
                { $limit: 1 }
            ],
            as: "nadejeData"
            }
        },
        {
            $unwind: "$nadejeData"
        },
        {
            $project: {
            _id: 0,
            "Věková skupina s nejvyšší plodností": "$_id",
            "Průměrná plodnost": { $round: ["$prumernaPlodnost", 2] },
            "Naděje dožití": "$nadejeData.Hodnota",
            "Rok měření naděje dožití": "$nadejeData.Roky",
            "Zdrojové záznamy": "$pocetZaznamu"
            }
        }
    ]);

### Dotaz 5
Ukáže naději dožití novorozenych kluků (0 roků) v roce 2020 pro region v regionech kde byl průměrný věk matky při porodu 29 a více.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a průměrného věku matky při porodu. Nakonec použije `lookup` pro připojení dat z kolekce `nadeje` a `unwind` pro rozbalení výsledků.

Nepujde pokud se předtímto dotazem nespstil dotak který přetypovává `IndicatorType` na string (případně je třeba změnit v dotazu IndicatorType: "7406" -> IndicatorType: 7406).

    db.narozeni.aggregate([
        {
            $match: {
            IndicatorType: "7406",
            Hodnota: { $gte: 31 },
            Roky: 2020 
            }
        },
        {
            $group:{
                _id: "$Uz01A",
                prumer: { $avg: "$Hodnota" }
            }
        },
        {
            $lookup: {
            from: "nadeje",
            let: { region: "$_id" },
            pipeline: [
                {
                $match: {
                    $expr: {
                    $and: [
                        { $eq: ["$Roky", 2020] },
                        { $eq: ["$Uz01A", "$$region"] },
                        { $eq: ["$Věk (roky)", 0]},
                        { $eq: ["$Pohlaví", "muži"] }
                    ]
                    }
                }
                }
            ],
            as: "nadejeData"
            }
        },
        {
            $unwind: {
            path: "$nadejeData",
            preserveNullAndEmptyArrays: true 
            }
        },
        {
            $project: {
            _id: 0,
            region: "$_id",
            regionNazev: "$nadejeData.ČR, regiony",
            prumerVekMatky: 1,
            nadejeDožitíNovorozence: "$nadejeData.Hodnota"
            }
        },
            {
            $sort: { nadejeDožitíNovorozence: -1 }
        }
    ]);

### Dotaz 6
Ukáže kraj kde je největší poměr mrtvě narozených dětí k živě narozeným dětem.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a typu indikátoru. Nakonec použije `addFields` pro výpočet poměru mezi mrtvě narozenými a živě narozenými dětmi a `sort` pro seřazení výsledků podle poměru.


    db.narozeni.aggregate([
    {
        $match: {
        IndicatorType: { $in: ["4355MN", "4355ZN"] },
        $expr: { $ne: ["$Uz012", "$Uz01A"] }
        }
    },
    {
        $group: {
        _id: {
            region: "$Uz012",
            typ: "$IndicatorType"
        },
        pocet: { $sum: "$Hodnota" },
        nazevRegionu: { $first: "$Oblast" }
        }
    },
    {
        $group: {
        _id: "$_id.region",
        nazevRegionu: { $first: "$nazevRegionu" },
        data: {
            $push: {
            typ: "$_id.typ",
            pocet: "$pocet"
            }
        }
        }
    },
    {
        $addFields: {
            pomer: {
                $divide: [
                    {
                        $arrayElemAt: [
                        "$data.pocet",
                        { $indexOfArray: ["$data.typ", "4355MN"] }
                        ]
                    },
                    {
                        $arrayElemAt: [
                        "$data.pocet",
                        { $indexOfArray: ["$data.typ", "4355ZN"] }
                        ]
                    }
  
                ]
            }
            }
    },
    {
        $sort: { pomer: -1 }
    },
    {
        $limit: 1
    },
    {
        $project: {
        _id: 0,
        region: "$_id",
        nazevRegionu: 1,
        "Mrtvě narození (celkem)": "$mrtveNarozeni",
        "Živě narození (celkem)": "$ziveNarozeni",
        "Poměr (mrtvě/živě)": { $round: ["$pomer", 4] },
        "Poměr %": {
            $multiply: [
            { $round: ["$pomer", 4] },
            100
            ]
        }
        }
    }
    ])

## Konfigurační dotazy
Dotazy které pracují s konfigurací databáze a kolekcí

### Dotaz 1
Ukáže všechny kolekce v databázi `mojedb` a informace o nich.
Vytvoří dotaz na kolekce v databázi `mojedb` a pomocí `stats` získá informace o počtu dokumentů, velikosti kolekce a indexech. Poté zobrazí informace o každé kolekci.

    db.getCollectionNames().forEach(function(collection) {
        var stats = db[collection].stats();
        print("Kolekce: " + collection);
        print("Počet dokumentů: " + stats.count);
        print("Velikost kolekce: " + stats.size + " B");
        print("Indexy: " + JSON.stringify(stats.indexSizes));
        print("Sharding: " + JSON.stringify(stats.sharded));
        print("\n");
    });

### Dotaz 2
Zobrazí rozdělení chunků s informacemi o hostitelských kontejnerech.
Vytvoří dotaz na kolekci `chunks` v databázi `config`, která obsahuje informace o shardingových chucích. Pomocí `$lookup` připojí informace o shardu a pomocí `$project` vybere potřebné informace.

    use config

    db.chunks.aggregate([
    {
        $lookup: {
        from: "shards",
        localField: "shard",
        foreignField: "_id",
        as: "shardInfo"
        }
    },
    {
        $project: {
        shard: 1,
        container: { $arrayElemAt: ["$shardInfo.host", 0] },
        min: 1,
        max: 1
        }
    }
    ])

### Dotaz 3
Zobrazí informace o sharding klíčích a jejich indexech pro všechny kolekce v databázi `mojedb`.
Vytvoří dotaz na kolekce v databázi `mojedb` a pomocí `getIndexes` získá informace o indexech. Poté zobrazí informace o každé kolekci, včetně sharding klíče a unikátnosti.


    use mojedb

    db.getCollectionNames().forEach(function(collection) {
        var info = db.getSiblingDB("config").collections.findOne({ _id: "mojedb." + collection });
        print("Kolekce: " + collection);
        if (info && info.key) {
            print("Sharding klíč: " + JSON.stringify(info.key));
            print("Unikátní: " + (info.unique ? "ano" : "ne"));
        } else {
            print("Sharding klíč: neshardovaná kolekce");
        }
        var indexes = db[collection].getIndexes();
        print("Indexy:");
        indexes.forEach(idx => printjson(idx));
        print("\n");
    });


### Dotaz 4
Přidá sharding do kolekce `prumery` s velikostí chunku 1 MB a zobrazí informace o sharadovani.
Vytvoří dotaz na kolekci `prumery` a pomocí `sh.shardCollection` přidá sharding. Poté zobrazí informace o shardingu.


    // Mělo by být už nastavené při inicializaci
    use config
    db.settings.updateOne(
        { _id: "chunksize" },
        { $set: { value: 1 } },
        { upsert: true }
    );
    use mojedb;
    sh.enableSharding("mojedb");
    //Konec sekce která by měla být už nastavená při inicializaci

    db.prumery.createIndex({ rok: 1 });
    sh.shardCollection("mojedb.prumery", { rok: 1 });
    sh.status();


### Dotaz 5
Simuluje výpadek sekundárního uzlu shardu a kontroluje stav replikace.


1. Je potřeba se dostat do shardu

        docker-compose exec router01 mongosh "mongodb://admin:admin@shard01-b:27017/?replicaSet=rs-shard-01"

2. V shardu pak lze testovat výpadek primárního uzlu a kontrolovat stav replikace. Pomocí `db.shutdownServer` simulujeme výpadek sekundárního uzlu a pomocí `rs.status()` kontrolujeme stav replikace.


        use admin

        // Simulace výpadku
        db.shutdownServer({
        force: true,
        timeoutSecs: 5
        })  

        // Kontrola stavu replikace
        rs.status().members.forEach(m => {
            printjson({
                _id: m._id,
                uzel: m.name,
                stav: m.stateStr,
                lag: m.optimeLag,
                zdraví: m.health
            })
        })

### Dotaz 6
Znovu aktivace sekundárního uzlu a kontrola stavu replikace.


1. Je potřeba znovu spustit sekundární uzel

        docker-compose restart shard01-a

2. Připojit se do jineho než restartovaného shardu
        docker-compose exec router01 mongosh "mongodb://admin:admin@shard01-b:27017/?replicaSet=rs-shard-01"

3. Rekonfigurace shardu a kontrola stavu replikace. Pomocí `rs.reconfig` znovu nakonfigurujeme shard a pomocí `rs.status()` zkontrolujeme stav replikace.

        rs.reconfig(
        {
            _id: "rs-shard-01",
            members: [
            { _id: 0, host: "shard01-a:27017" },
            { _id: 1, host: "shard01-b:27017" },
            { _id: 2, host: "shard01-c:27017" }
            ]
        }
        )

        rs.status().members.forEach(m => {
            printjson({
                _id: m._id,
                uzel: m.name,
                stav: m.stateStr,
                lag: m.optimeLag,
                zdraví: m.health
            })
        })

## Nested (embedded) dokumenty
Dotazy které pracují s nested (embedded) dokumenty

### Dotaz 1

Ukáže detailní informace z kolekce `plodnost` pro záznamy z roku 2020, kde je hodnota větší než globální průměr plodnosti pro daný rok (z kolekce `prumery`).
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `lookup` pro připojení dat z kolekce `prumery` a `unwind` pro rozbalení výsledků a `match` pro filtrování podle podmínky. Nakonec použije `project` pro výběr výsledků.

    db.plodnost.aggregate([
        {
            $match: { Roky: 2020 }
        },
        {
            $lookup: {
                from: "prumery",
                let: { rok: "$Roky" },
                pipeline: [
                    {
                        $match: {
                            $expr: { $eq: ["$rok", "$$rok"] },
                            globalniPrumerPlodnosti: { $exists: true }
                        }
                    },
                    {
                        $project: { globalniPrumerPlodnosti: 1, _id: 0 }
                    }
                ],
                as: "prumerData"
            }
        },
        {
            $unwind: "$prumerData"
        },
        {
            $match: {
                $expr: { $gt: ["$Hodnota", "$prumerData.globalniPrumerPlodnosti"] }
            }
        },
        {
            $project: {
                _id: 0,
                Roky: 1,
                "Věk (jednoleté skupiny)": 1,
                Hodnota: 1,
                globalniPrumerPlodnosti: "$prumerData.globalniPrumerPlodnosti",
                Oblast: 1
            }
        }
    ])

### Dotaz 2
Ukáže první věkovou skupinu z každého kraje, kde je naděje dožití menší než globální průměrná naděje pro rok 2020 (z kolekce `prumery`).
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `lookup` pro připojení dat z kolekce `prumery` a `unwind` pro rozbalení výsledků a `match` pro filtrování podle podmínky. Nakonec použije `sort`, `group` a `project` pro výběr výsledků.

    db.nadeje.aggregate([
        {
            $match: { Roky: 2020 }
        },
        {
            $lookup: {
                from: "prumery",
                let: { rok: "$Roky" },
                pipeline: [
                    {
                        $match: {
                            $expr: { $eq: ["$rok", "$$rok"] },
                            globalniPrumerPlodnosti: { $exists: true }
                        }
                    },
                    {
                        $project: { globalniPrumerPlodnosti: 1, _id: 0 }
                    }
                ],
                as: "prumerData"
            }
        },
        { $unwind: "$prumerData" },
        {
            $match: {
                $expr: { $lt: ["$Hodnota", "$prumerData.globalniPrumerPlodnosti"] }
            }
        },
        {
            $sort: { Uz01A: 1, "Věk (roky)": 1 }
        },
        {
            $group: {
                _id: "$Uz01A",
                prvniVek: { $first: "$Věk (roky)" },
                nadeje: { $first: "$Hodnota" },
                oblast: { $first: "$ČR, regiony" },
                prumer: { $first: "$prumerData.globalniPrumerPlodnosti" }
            }
        },
        {
            $project: {
                _id: 0,
                region: "$_id",
                oblast: 1,
                prvniVek: 1,
                nadeje: 1,
                globalniPrumer: "$prumer"
            }
        }
    ])

### Dotaz 3
Ukáže v jakých krajích je v roce 2020 více narozených dětí s pořadím 4 a více než je průměr.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `group` pro seskupení dat podle regionu a počtu dětí. Nakonec použije `lookup` pro připojení dat z kolekce `prumery` a `unwind` pro rozbalení výsledků a `match` pro filtrování podle podmínky. Nakonec použije `project` pro výběr a zaokrouhlení výsledků.

    db.narozeni.aggregate([
        {
            $match: {
                Roky: 2020,
                IndicatorType: "4355WZNP4AV",
                $expr: { $ne: ["$Uz012", "$Uz01A"] }
            }
        },
        {
            $group: {
                _id: "$Uz012",
                oblast: { $first: "$Oblast" },
                pocetDeti: { $sum: "$Hodnota" }
            }
        },
        {
            $lookup: {
                from: "prumery",
                let: { rok: 2020 },
                pipeline: [
                    {
                        $match: {
                            $expr: { $eq: ["$rok", "$$rok"] },
                            indikatory: { $exists: true }
                        }
                    },
                    {
                        $unwind: "$indikatory"
                    },
                    {
                        $match: {
                            "indikatory.indicator": "4355WZNP4AV"
                        }
                    },
                    {
                        $project: {
                            _id: 0,
                            prumer: "$indikatory.prumer"
                        }
                    }
                ],
                as: "prumerData"
            }
        },
        { $unwind: "$prumerData" },
        {
            $match: {
                $expr: { $gt: ["$pocetDeti", "$prumerData.prumer"] }
            }
        },
        {
            $project: {
                _id: 0,
                region: "$_id",
                oblast: 1,
                pocetDeti: 1,
                prumer: { $round: ["$prumerData.prumer", 2] }
            }
        },
        { $sort: { pocetDeti: -1 } }
    ])

### Dotaz 4

Ukáže rok kdy byl nejmenší rozdíl mezi nadějí průměrným dožití mužů a žen.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `project` pro výpočet rozdílu mezi nadějí dožití mužů a žen. Nakonec použije `sort` a `limit` pro seřazení a omezení výsledků na 1 rok.

    db.prumery.aggregate([
        {
            $match: {
                "nadeje.muži": { $exists: true },
                "nadeje.ženy": { $exists: true },
            }
        },
        {
            $project: {
                rok: 1,
                rozdil: { $round: [{ $subtract: ["$nadeje.ženy", "$nadeje.muži"] }, 2] },
                nadejeMuzi: "$nadeje.muži",
                nadejeZeny: "$nadeje.ženy"
            }
        },
        {
            $sort: { rozdil: 1 }
        },
        {
            $limit: 1
        }
    ])

### Dotaz 5

Ukáže všechny roky, ve kterých byl globální průměr plodnosti vyšší než 45 a zároveň průměrná naděje dožití žen přesáhla 33.75 let.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `lookup` pro připojení dat z kolekce `prumery` a `unwind` pro rozbalení výsledků. Nakonec použije `project` pro výběr výsledků.

    db.prumery.aggregate([
        {
            $match: {
                globalniPrumerPlodnosti: { $exists: true, $gt: 45 }
            }
        },
        {
            $lookup: {
                from: "prumery",
                let: { rok: "$rok" },
                pipeline: [
                    {
                        $match: {
                            $expr: { $eq: ["$rok", "$$rok"] },
                            "nadeje.ženy": { $exists: true, $gt: 33.75 }
                        }
                    },
                    {
                        $project: { _id: 0, nadejeZeny: "$nadeje.ženy" }
                    }
                ],
                as: "nadejeData"
            }
        },
        { $unwind: "$nadejeData" },
        {
            $project: {
                rok: 1,
                globalniPrumerPlodnosti: 1,
                nadejeZeny: "$nadejeData.nadejeZeny"
            }
        }
    ]);

### Dotaz 6

Najde rok, ve kterém byl největší rozdíl mezi průměrným počtem živě narozených a mrtvě narozených dětí.
Vyhledává pomocí `aggregate` a `match` pro filtrování dat. Poté použije `project` pro výpočet rozdílu mezi průměrným počtem živě narozených a mrtvě narozených dětí. Nakonec použije `sort` a `limit` pro seřazení a omezení výsledků na 1 rok.

    db.prumery.aggregate([
        {
            $match: {
                indikatory: { $exists: true }
            }
        },
        {
            $project: {
                rok: 1,
                zive: {
                    $let: {
                        vars: {
                            idx: { $indexOfArray: ["$indikatory.indicator", "4355ZN"] }
                        },
                        in: { $arrayElemAt: ["$indikatory.prumer", "$$idx"] }
                    }
                },
                mrtve: {
                    $let: {
                        vars: {
                            idx: { $indexOfArray: ["$indikatory.indicator", "4355MN"] }
                        },
                        in: { $arrayElemAt: ["$indikatory.prumer", "$$idx"] }
                    }
                }
            }
        },
        {
            $addFields: {
                rozdil: { $abs: { $subtract: ["$zive", "$mrtve"] } }
            }
        },
        { $sort: { rozdil: -1 } },
        { $limit: 1 },
        {
            $project: {
                _id: 0,
                rok: 1,
                zive: 1,
                mrtve: 1,
                rozdil: 1
            }
        }
    ])

## Indexy
Dotazy které pracují s indexy

### Dotaz 1
Vytvoří složený částečný index na kolekci `narozeni`, který indexuje pole `Roky` a `IndicatorType` pouze pro dokumenty, kde je `Roky` větší nebo rovno 2018 a vypíše všechny indexy v kolekci `narozeni`.
Vytvoří dotaz na kolekci `narozeni` a pomocí `createIndex` vytvoří index. Poté zobrazí informace o všech indexech v kolekci.

    db.narozeni.createIndex(
        { Roky: 1, IndicatorType: 1 },
        {
            name: "NovyNarozeniIndex",
            partialFilterExpression: { Roky: { $gte: 2018 } }
        }
    );

    db.narozeni.getIndexes().forEach(idx => printjson(idx));



### Dotaz 2
Dotazy pro porovnání výkonu podobných dotazů s a bez indexu.
Vytvoří dva vyhledávací dotazy na kolekci `narozeni`, jeden s používá nově vytvořený indexu a druhý ne. Poté zobrazí statistiky výkonu pro oba dotazy.

    db.narozeni.aggregate([
        {
            $match: {
                Roky: { $gte: 2010, $lte: 2014 },
                IndicatorType: "4355ZNMM"
            }
        },
        {
            $group: {
                _id: "$Oblast",
                soucet: { $sum: "$Hodnota" }
            }
        },
        { $sort: { soucet: 1 } },
        { $limit: 1 }
    ]).explain("executionStats");


    db.narozeni.aggregate([
        {
            $match: {
                Roky: { $gte: 2018, $lte: 2022 },
                IndicatorType: "4355ZNMM"
            }
        },
        {
            $group: {
                _id: "$Oblast",
                soucet: { $sum: "$Hodnota" }
            }
        },
        { $sort: { soucet: 1 } },
        { $limit: 1 }
    ]).explain("executionStats");

### Dotaz 3

Vytvoří index na kolekci `nadeje` pro pole `Roky` a `Pohlaví`, index pojmenuje `IndexNadejeRokPohlavi` a vypíše všechny indexy v kolekci `nadeje`:

    db.nadeje.createIndex(
        { Roky: 1, Pohlaví: 1 },
        { name: "IndexNadejeRokPohlavi" }
    );

    db.nadeje.getIndexes().forEach(idx => printjson(idx));


### Dotaz 4
Využije index `IndexNadejeRokPohlavi` při dotazu na průměrnou naději dožití žen v letech 2018–2022 a zobrazí statistiky využití indexu.
Vytvoří dva vyhledávací dotazy na kolekci `nadeje`, jeden využívá nově vytvořený index a druhý ne. Poté zobrazí statistiky výkonu pro oba dotazy.

db.nadeje.aggregate([
    {
        $match: {
            Roky: { $gte: 2018, $lte: 2022 },
            Pohlaví: "ženy"
        }
    },
    {
        $group: {
            _id: "$Roky",
            prumerNadeje: { $avg: "$Hodnota" }
        }
    }
]).explain("executionStats");

### Dotaz 5

Vytvoří index na kolekci `plodnost` pro pole `Roky` a `Věk (jednoleté skupiny)`, index pojmenuje `IndexPlodnostRokVek` a vypíše všechny indexy v kolekci `plodnost`:

    db.plodnost.createIndex(
        { Roky: 1, "Věk (jednoleté skupiny)": 1 },
        { name: "IndexPlodnostRokVek" }
    );

    db.plodnost.getIndexes().forEach(idx => printjson(idx));

### Dotaz 6

Využije index `IndexPlodnostRokVek` při dotazu na průměrnou plodnost žen ve věku 25–35 let v letech 2015–2020 a zobrazí statistiky využití indexu.
Vytvoří dva vyhledávací dotazy na kolekci `plodnost`, jeden využívá nově vytvořený index a druhý ne. Poté zobrazí statistiky výkonu pro oba dotazy.

    db.plodnost.aggregate([
        {
            $match: {
                Roky: { $gte: 2015, $lte: 2020 },
                "Věk (jednoleté skupiny)": { $gte: 25, $lte: 35 }
            }
        },
        {
            $group: {
                _id: "$Roky",
                prumerPlodnosti: { $avg: "$Hodnota" }
            }
        }
    ]).explain("executionStats");
