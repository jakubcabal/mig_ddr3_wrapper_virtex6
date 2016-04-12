# MIG DDR3 Wrapper for FPGA Virtex 6

MIG Wrapper usnadňuje práci s DDR3 paměťovým řadičem na FPGA řady Virtex 6. Byl vytvořen jako školní projekt v rámci předmětu MPLD na FEKT VUT v Brně.

## Uživatelské rozhraní MIG Wrapperu

Zde je jednoduchý popis uživatelského rozhraní MIG Wrapperu, který slouží pro jednoduchou komunikaci s pamětí. Mimo uživatelského rozhraní obsahuje MIG Wrapper diferenční vstup referenčních hodin (200MHz), vstup asynchronního resetu, výstup uživatelských hodin (200MHz) generovaných MIG řadičem a také DDR3 rozhraní připojené přímo k paměti DDR3. Pro celé uživatelské rozhraní platí, že aktivní stav je log. 1.

Název portu | IN/OUT | Datová šířka | Popis portu
--- | --- | --- | ---
MIG_ADDR | IN | 25b | Vstup pro adresování zápisových a čtecích požadavků, adresa musí být platná, pokud je aktivní vstup MIG_WR_EN nebo MIG_RD_EN.
MIG_READY | OUT | 1b | Výstup, který říká, zda lze nastavit nový požadavek v dalším taktu a zda MIG Wrapper přijal současný požadavek na zápis nebo čtení.
MIG_RD_EN | IN | 1b | Vstup, který povoluje požadavek na čtení z paměti z adresy nastavené na vstupu MIG_ADDR. Požadavek je přijat, když je aktivní výstup MIG_READY.
MIG_WR_EN | IN | 1b | Vstup, který povoluje požadavek na zápis dat nastavených na vstupu MIG_WR_DATA do paměti na adresu nastavenou na vstupu MIG_ADDR. Požadavek je přijat, když je aktivní výstup MIG_READY.
MIG_WR_DATA | IN | 512b | Datový vstup pro zápis dat do paměti, data musí být platná když je aktivní vstup MIG_WR_EN.
MIG_RD_DATA | OUT | 512b | Datový výstup pro čtení dat z paměti, data jsou platná, když je aktivní výstup MIG_RD_DATA_VLD.
MIG_RD_DATA_VLD | OUT | 1b | Výstup, který říká, zda jsou data na výstupu MIG_RD_DATA platná.

**Příklad zápisu do paměti**

Následující příklad ukazuje časový diagram požadavků na zápis dat do paměti. Jelikož samotný MIG řadič má datovou šířku pouze 256b, ale datový paket pro DDR3 paměť v režimu BL8 má délku 512b, proto MIG Wrapper zapisuje data do řadiče po dobu dvou taktů. Uživatel tuto situaci nemusí řešit, protože rovnou posílá 512b dat a MIG Wrapper si příchozí data pozastaví sám nastavením výstupu MIG_READY do neaktivního stavu (log. 0). Výhodou tohoto režimu je maximální datová propustnost do paměti.

![Příklad zápisu do paměti](https://rawgit.com/jakubcabal/mig_ddr3_wrapper_virtex6/master/docs/images/write.svg)

**Příklad požadavku na čtení z paměti**

Následující příklad ukazuje časový diagram požadavků na vyčtení z paměti, ale není zde znázorněno samotné přijetí dat. Vyčtená data příjdou s jistou latencí ve stejném pořadí (pokud je správně nastaven MIG řadič) jako byly odeslány požadavky na čtení.

![Příklad požadavku na čtení z paměti](https://rawgit.com/jakubcabal/mig_ddr3_wrapper_virtex6/master/docs/images/read.svg)

## Naměřené přenosové rychlosti

Další popis bude brzy doplněn...
