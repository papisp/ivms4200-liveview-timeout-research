# iVMS-4200 3.14.1.3 — rozwiązanie problemu pięciominutowego limitu podglądu

> **Nieoficjalne badanie i poprawka.** W lokalnym teście trzy kamery działały równocześnie ponad godzinę, bez liczników, z prawidłowym przełączaniem. Inne wersje i konfiguracje nie zostały zweryfikowane.
>
> Projekt nie jest związany z Hikvision. Modyfikacja oprogramowania może naruszać warunki licencji lub obowiązujące prawo. Stosuj wyłącznie w zakresie posiadanych uprawnień, na własne ryzyko.

[**English documentation**](README.md)

## Problem

Przy połączeniu przez Hik-Connect wersja iVMS-4200 3.14.1.3 wyświetlała licznik pięciu minut, a po upływie tego czasu kończyła transmisję LIVE. Ta sama konfiguracja w starszej wersji 3.6.0.6_E nie wykazywała takiego ograniczenia.

## Wyniki diagnostyki

Badanie przeprowadzono w x64dbg, analizując proces `iVMS-4200.Video.C.exe` i bibliotekę `MainViewPlugin.dll`.

- Odliczanie w interfejsie (`MainViewPlugin+492D97`) nie odpowiadało bezpośrednio za moment zakończenia podglądu. Modyfikowanie wyświetlanego czasu nie zmieniało rzeczywistego limitu.
- Podczas automatycznego zakończenia występowało zdarzenie `0x19` (`EVENT25`) w gałęzi `MainViewPlugin+41BCC2`. Podczas porównawczego testu ręcznego zamknięcia podglądu to zdarzenie nie wystąpiło.
- Stos wywołań potwierdził ścieżkę od zdarzenia do funkcji `PreviewLogical::CBasePreview::StopPreview()`.
- Pominięcie gałęzi zdarzenia pozwoliło przedłużyć podgląd; osobna zmiana ukryła tekst licznika.

## Dwie zmiany bajtowe

**To offsety w pliku, nie adresy pamięci ani RVA. Nie stosuj zmian do innej kompilacji DLL.**

| Offset w pliku | Przed | Po | Działanie |
|---|---|---|---|
| `0x41B16C` | `C2` | `D7` | Przekierowanie wpisu tablicy skoków `EVENT25` z `MainViewPlugin+41BCC2` na `MainViewPlugin+41BCD7` |
| `0x6639B8` | `25` (`%`) | `00` | Wyzerowanie pierwszego bajtu ciągu `%1:%2:%3` formatującego licznik |

Rozmiar oryginalnej biblioteki: **9 384 448 bajtów**.

SHA-256 oryginału:

```text
5610F35B164599FD9ADB425E80B38CF4BE98BD1CEE21A3EFAA0A1706272AF66A
```

SHA-256 po modyfikacji:

```text
9848B2043EEBBB74F58C045C7A0D264A48FD897BFE37A243D2A9AD0C235B9207
```

Skrypt [`patch.ps1`](patch.ps1) sprawdza sumę kontrolną oryginału przed wykonaniem zmian, tworzy kopię `.bak`, weryfikuje wynik i obsługuje `-Restore`. Nie modyfikuje nieznanych wersji pliku.

## Instrukcja

1. Zamknij iVMS-4200 oraz wszystkie jego procesy, szczególnie `iVMS-4200.Video.C.exe`.
2. Odszukaj `MainViewPlugin.dll` we własnej instalacji i zachowaj dodatkową kopię oryginału.
3. Uruchom w Windows PowerShell:
   ```powershell
   .\patch.ps1 -DllPath 'C:\sciezka\do\MainViewPlugin.dll'
   ```
   Przy plikach w `Program Files` mogą być wymagane uprawnienia administratora.
4. Uruchom program i sprawdź aktualizację czasu LIVE, kilka kamer, przełączanie oraz transmisję po pięciu minutach.
5. Przywróć oryginał, jeśli to konieczne:
   ```powershell
   .\patch.ps1 -DllPath 'C:\sciezka\do\MainViewPlugin.dll' -Restore
   ```
   Możesz też ręcznie przywrócić zweryfikowaną kopię `.bak`.

## Potwierdzone testy

| Scenariusz | Obserwacja |
|---|---|
| Jedna kamera przez ponad 10 minut | Transmisja trwa |
| Przełączenie na inną kamerę, ponad 15 minut | Transmisja trwa |
| Dwie kamery przy liczniku `00:00` | Podgląd działa przy obejściu `EVENT25` |
| Trzy kamery po obu zmianach | Ponad godzina, brak liczników, poprawne przełączanie |

## Ograniczenia

Jest to eksperymentalna poprawka konkretnej kompilacji, a nie oficjalne rozwiązanie producenta. Nie wykonano kompleksowych testów wszystkich funkcji programu. Modyfikacja może unieważnić podpis cyfrowy pliku, jeśli taki występuje.

**Nie publikujemy oryginalnych ani zmodyfikowanych bibliotek DLL Hikvision.** Repozytorium zawiera wyłącznie opis badania i skrypt do modyfikacji własnej kopii.

W zgłoszeniu problemu podaj wersję iVMS, SHA-256 oryginalnej biblioteki i typ połączenia. Nie publikuj haseł, identyfikatorów kont i urządzeń ani prywatnych nagrań z kamer.
