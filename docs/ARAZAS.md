# SpaceMaker Pro – havi induló árterv

2026-09-13. **Javaslat, nem éles áruházi beállítás.** Egyetlen havi, automatikusan megújuló előfizetés; korlátlan swipe és reklámmentesség. Nincs heti csomag vagy megtévesztő éves/havi összehasonlítás. A 20 ingyenes swipe nem előfizetési próba, nem indul utána automatikus terhelés.

## Induló árak, prioritási sorrendben

| Piac | Havi célár |
|---|---:|
| US · USA | 3.99 USD |
| GB · United Kingdom | 2.99 GBP |
| CA · Canada | 4.99 CAD |
| AU · Australia | 5.99 AUD |
| DE · Germany | 3.99 EUR |
| FR · France | 3.99 EUR |
| IT · Italy | 3.99 EUR |
| ES · Spain | 3.99 EUR |
| NL · Netherlands | 3.99 EUR |
| JP · Japan | 480 JPY |
| KR · South Korea | 4900 KRW |
| CH · Switzerland | 3.9 CHF |
| AT · Austria | 3.99 EUR |
| BE · Belgium | 3.99 EUR |
| IE · Ireland | 3.99 EUR |
| PT · Portugal | 2.99 EUR |
| FI · Finland | 3.99 EUR |
| GR · Greece | 2.99 EUR |
| SE · Sweden | 39 SEK |
| NO · Norway | 39 NOK |
| DK · Denmark | 29 DKK |
| NZ · New Zealand | 6.99 NZD |
| SG · Singapore | 4.98 SGD |
| HK · Hong Kong | 28 HKD |
| TW · Taiwan | 90 TWD |
| AE · UAE | 12.99 AED |
| SA · Saudi Arabia | 12.99 SAR |
| IL · Israel | 12.9 ILS |
| HU · Hungary | 990 HUF |
| PL · Poland | 12.99 PLN |
| CZ · Czechia | 79 CZK |
| RO · Romania | 14.99 RON |
| SK · Slovakia | 2.99 EUR |
| HR · Croatia | 2.99 EUR |
| BR · Brazil | 9.9 BRL |
| MX · Mexico | 39 MXN |
| CL · Chile | 1990 CLP |
| CO · Colombia | 7900 COP |
| PE · Peru | 6.9 PEN |
| IN · India | 99 INR |
| ID · Indonesia | 19000 IDR |
| PH · Philippines | 79 PHP |
| TH · Thailand | 59 THB |
| MY · Malaysia | 6.9 MYR |
| VN · Vietnam | 29000 VND |
| TR · Türkiye | 79.99 TRY |
| ZA · South Africa | 29.99 ZAR |
| EG · Egypt | 59.99 EGP |
| PK · Pakistan | 299 PKR |
| BD · Bangladesh | 149 BDT |

Minden további, a szolgáltatók által támogatott és kiadásra jóváhagyott piacon a 3,99 USD amerikai alapár áruházi lokalizált megfelelője legyen az indulás, a legközelebbi engedélyezett árszintre kerekítve. Ez nem ígéret minden ország technikai vagy jogi lefedettségére. Kína szárazföldi területe és bármely nem támogatott/korlátozott piac külön kiadási és reklámszolgáltatói ellenőrzést igényel; ezekre ne kapcsoljunk be vakon globális terjesztést.

## Miért ezek?

Ezek tesztelendő üzleti hipotézisek, nem bizonyítottan optimális árak, és nem pontos devizaátváltások. USA: alacsony belépési küszöbű, 3,99 USD/hó egyszerű fotórendezőre. Nyugat-Európa/angolszász piacok: hasonló pozicionálás, helyi árformátum. Közép-Európa, Latin-Amerika és Ázsia egy része: alacsonyabb belépési ár, erősebb ingyenes/reklámos opció.

A [Swipewipe amerikai App Store-listája](https://apps.apple.com/us/app/swipewipe-photo-cleaner/id1583884012) több heti ajánlatot (például 9,99 USD) és 29,99 USD-s éves terméket is felsorol. Ezek különböző termékek, nem minden felhasználó aktuális ajánlatai; a SpaceMakernek kevesebb funkciója van, ezért nem tekintjük az árakat közvetlen ekvivalensnek.

Az [Apple területenkénti előfizetési árazása](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions) és a [Google Play helyi pénznemei](https://support.google.com/googleplay/android-developer/answer/1169947?hl=en) az áruházi konzolban kezelendők. A fenti táblázat célár; az engedélyezett árszintek, adók és kerekítések miatt az éles összeg eltérhet. A táblázat nem nettó fejlesztői bevételt mutat.

## Beállítás és optimalizálás

- Géppel olvasható terv: config/regional-pricing.json. Nem közvetlen Store API-import formátum.
- A havi termékeket és ezeket a területi árakat App Store Connectben és Play Console-ban kell létrehozni. Innen még nem történt publikálás.
- A paywall kizárólag a store-ból lekért lokalizált priceString értéket mutatja, nem a telefon nyelvéből vagy a fenti táblázatból kitalált összeget.
- 4–6 hetes induló mérés után piac/platform bontásban vizsgáljuk: fizetésre váltás, megújítás, lemondás, visszatérítés, reklámos használat és nettó bevétel/aktív felhasználó. Kis mintán ne hirdessünk győztest. Ekkor érdemes a 3,99 vs 4,99 USD-t és a helyi megfelelőket tesztelni; a jelenlegi build nem telepít külön analitikai SDK-t.
- Magas inflációjú piacok célárát havonta, a többit negyedévente felülvizsgálni. Árteszt ne jelentsen automatikus áremelést a meglévő előfizetőknek.
