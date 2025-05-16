# Dotazy

Dotazy jsou byly spoušteny v `mongo shell`u po inicializaci a importování dat pomocí:

    docker-compose up --attach init-container

Do `mongo shell`u se dá připojit pomocí:

    docker-compose exec router01 mongosh --port 27017 -u "admin" -p "admin" --authenticationDatabase admin

Dotazy pracují s databází `mojedb` a kolekcemi `narozeni, plodnost, nadeje`.

## Práce s daty
Dotazy které pracují s daty (insert, update, delete, merge)

### Dotaz 1

## Agregační funkce
Dotazy které pracují s agregačními funkcemi

### Dotaz 1
Spočítá průměrnou naději dožití žen mezi staré 30-35 let v letech 2015-2017 pro regiony CZ05 a CZ06 zaokrouhlenou na 2 desetinná místa. Výstup bude obsahovat region, rok, průměrnou naději dožití a počet záznamů.


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

    db.narozeni.aggregate([
        {
            $match: {
            IndicatorType: { $in: [7406, "7406D1"] },
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

    db.plodnost.aggregate([
        {
            $match: {
            IndicatorType: 5406
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

    db.narozeni.aggregate([
        {
            $match: {
            IndicatorType: 7406,
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
                $divide: [{
                        $arrayElemAt: [
                        "$data.pocet",
                        { $indexOfArray: ["$data.typ", "4355ZN"] }
                        ]
                    },
                    {
                        $arrayElemAt: [
                        "$data.pocet",
                        { $indexOfArray: ["$data.typ", "4355MN"] }
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
        $limit: 5
    },
    {
        $project: {
        _id: 0,
        region: "$_id",
        nazevRegionu: 1,
        "Mrtvě narození (celkem)": "$mrtveNarozeni",
        "Živě narození (celkem)": "$ziveNarozeni",
        "Poměr (živě/mrtvě)": { $round: ["$pomer", 4] },
        "Poměr %": {
            $multiply: [
            { $round: ["$pomer", 4] },
            100
            ]
        }
        }
    }
    ])