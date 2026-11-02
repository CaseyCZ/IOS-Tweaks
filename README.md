# IOS-Tweaks

Vlastní iOS tweaky od CaseyCZ (kolekce CaseyTweaks). Cíl: vrátit oblíbené funkce starších jailbreaků
v moderní podobě a postupně přidávat nové nápady.

> **Stav: vývojový základ, ne veřejné vydání.** Pro iPhone 15 Pro Max s iOS
> 27.0.1 dosud nemáme potvrzený veřejný jailbreak ani funkční testovací prostředí.
> Žádný balíček tu proto není označený jako kompatibilní s iOS 27.

## Co obsahuje první verze

- `tweaks/CHello/` – malý rootless tweak, který pouze zapíše zprávu do logu
  po načtení v aplikaci Nastavení. Žádné systémové funkce nemění.
- `.github/workflows/build.yml` – **ručně spouštěné** sestavení na macOS v GitHub
  Actions. Není nutný Theos na vlastním PC nebo serveru.
- `scripts/build-repo.sh` – vytvoří základní APT index pro Sileo/Zebra z ověřených
  `.deb` souborů, které správce vloží do `dist/`.
- `docs/` – připravená složka pro budoucí GitHub Pages repo. Dokud není balíček
  sestavený a otestovaný, zdroj není publikovaný.
- `ROADMAP.md` – náměty ze starých screenshotů a nové nápady.
- `INSPIRACE.md` – roztříděný přehled historických balíčků ze screenshotů.

## Jak vytvořit .deb

Projekt používá [Theos](https://theos.dev/) a rootless balíčkování pro iOS 15+.
Na Macu s Xcode a Theosem v proměnné `THEOS`:

```sh
make package FINALPACKAGE=1
```

V GitHubu lze použít **Actions → Build tweak (manual) → Run workflow**.
Výsledný `.deb` soubor bude k dispozici jako artefakt běhu. Workflow samo nic
nezveřejňuje a na iPhone nic neinstaluje.

## Jak připravit index pro Sileo

Teprve po ověření balíčků:

1. Vlož vydané `.deb` soubory do složky `dist/`.
2. Na Ubuntu s `dpkg-dev`, `apt-utils` a `gzip` spusť `bash scripts/build-repo.sh`.
3. Zkontroluj `docs/Packages`, `docs/Packages.gz`, `docs/Release` a `docs/debs/`.
4. Pokud se později rozhodneme pro veřejný zdroj, zapni GitHub Pages z `/docs`.

Po zapnutí GitHub Pages pro repozitář `CaseyCZ/IOS-Tweaks` z `/docs` by adresa pro Sileo byla
`https://caseycz.github.io/IOS-Tweaks/`. **Tato adresa nyní není potvrzeně aktivní.**

## Bezpečnost a kompatibilita

- Neinstaluj tyto balíčky na primární iPhone bez testování na podporované verzi.
- Nepřebíráme cizí uzavřený kód; staré tweaky jsou inspirace funkcemi.
- Systémové hooky se mohou změnit mezi verzemi iOS.
- Rootless balíček neobchází nutnost jailbreaku.
- Nepřidáváme pirátské balíčky, cracky ani nástroje pro obcházení placených nákupů.

## Licence

Zdrojový kód, který sami vytvoříme, bude pod licencí MIT (viz `LICENSE`).
