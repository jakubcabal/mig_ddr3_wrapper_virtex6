# MIG DDR3 Wrapper for FPGA Virtex 6

MIG Wrapper usnadňuje práci s DDR3 paměťovým řadičem Xilinx MIG na FPGA řady Virtex 6. Byl vytvořen jako školní projekt v rámci předmětu MPLD na FEKT VUT v Brně pod licencí MIT. Součástí je také ukázkový design, který navíc obsahuje generátor ovládaný přes UART. Ukázkový design umožňuje základní měření rychlosti komunikace s DDR3 pamětí. MIG Wrapper byl vyvíjen na vývojové desce ML605.

Samotný řadič Xilinx MIG je nutné vygenerovat pomocí Xilinx CORE generator! Součástí takto vygenerovaného řadiče je také model DDR3 paměti, který je nutný pro simulaci pomocí přiloženého souboru [source/testbench.vhd](source/testbench.vhd)! Vygenerovaný řadič MIG je nutné pro desku ML605 upravit, potřebné instrukce lze získat na webu firmy Xilinx v [dokumentu XTP047](http://www.xilinx.com/support/documentation/boards_and_kits/xtp047.pdf). Na webu firmy Xilinx lze též získat [ukázkový design řadiče MIG pro desku ML605](http://www.xilinx.com/products/boards-and-kits/ek-v6-ml605-g.html#documentation).

## Uživatelské rozhraní MIG Wrapperu

Zde je jednoduchý popis uživatelského rozhraní MIG Wrapperu, který slouží pro jednoduchou komunikaci s pamětí. Mimo uživatelského rozhraní obsahuje MIG Wrapper diferenční vstup referenčních hodin (200MHz), vstup asynchronního resetu, výstup uživatelských hodin (200MHz) generovaných MIG řadičem a také DDR3 rozhraní připojené přímo k paměti DDR3. Pro celé uživatelské rozhraní platí, že aktivní stav je log. 1.

Název portu | IN/OUT | Datová šířka | Popis portu
--- | --- | --- | ---
MIG_ADDR | IN | 25b | Adresování zápisových a čtecích požadavků. Adresa musí být platná, pokud je aktivní MIG_WR_EN nebo MIG_RD_EN.
MIG_READY | OUT | 1b | V aktivním stavu značí, že lze v dalším taktu nastavit nový požadavek na zápis nebo čtení.
MIG_RD_EN | IN | 1b | Povolení požadavku na čtení z paměti z adresy nastavené na vstupu MIG_ADDR. Požadavek je přijat, když je aktivní MIG_READY. MIG_RD_EN nesmí být aktivní ve stejném taktu jako MIG_WR_EN!
MIG_WR_EN | IN | 1b | Povolení požadavku na zápis dat nastavených na vstupu MIG_WR_DATA do paměti na adresu nastavenou na vstupu MIG_ADDR. Požadavek je přijat, když je aktivní výstup MIG_READY. MIG_WR_EN nesmí být aktivní ve stejném taktu jako MIG_RD_EN!
MIG_WR_DATA | IN | 512b | Data pro zápis do paměti. Data musí být platná, když je aktivní MIG_WR_EN.
MIG_RD_DATA | OUT | 512b | Data vyčtená z paměti. Data jsou platná, když je aktivní MIG_RD_DATA_VLD.
MIG_RD_DATA_VLD | OUT | 1b | V aktivním stavu značí, že data na výstupu MIG_RD_DATA jsou platná.

**Příklad zápisu do paměti**

Následující příklad ukazuje časový diagram požadavků na zápis dat do paměti. Jelikož samotný MIG řadič má datovou šířku pouze 256b, ale datový paket pro DDR3 paměť v režimu BL8 má délku 512b, proto MIG Wrapper zapisuje data do řadiče po dobu dvou taktů. Uživatel tuto situaci nemusí řešit, protože rovnou posílá 512b dat a MIG Wrapper si příchozí data pozastaví sám nastavením výstupu MIG_READY do neaktivního stavu (log. 0). Výhodou tohoto režimu je maximální datová propustnost do paměti.

![Příklad zápisu do paměti](https://rawgit.com/jakubcabal/mig_ddr3_wrapper_virtex6/master/docs/images/write.svg)

**Příklad požadavku na čtení z paměti**

Následující příklad ukazuje časový diagram požadavků na vyčtení z paměti, ale není zde znázorněno samotné přijetí dat. Vyčtená data příjdou s jistou latencí ve stejném pořadí (pokud je správně nastaven MIG řadič) jako byly odeslány požadavky na čtení.

![Příklad požadavku na čtení z paměti](https://rawgit.com/jakubcabal/mig_ddr3_wrapper_virtex6/master/docs/images/read.svg)

## Naměřené přenosové rychlosti

* Rychlost sekvenčního zápisu: 5,69 GB/s
* Rychlost sekvenčního čtení: 6,23 GB/s
* Rychlost sekvenčního zápisu a čtení v poměru 1:1: 0,69 GB/s*

*V tomto režimu, kdy se po jednom střídají požadavky na zápis a čtení, došlo k výraznému poklesu rychlost, proto není vhodné tento styl komunikace s pamětí používat v praxi.
