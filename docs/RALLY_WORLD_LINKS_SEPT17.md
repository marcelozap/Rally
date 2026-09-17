# World destination links — September 17, 2026

The World map now exposes **Official site** and **Maps** buttons on featured cards and destination rows. These buttons are siblings of the destination-details button, have 44-point minimum touch height and descriptive accessibility labels, and use `RallyReferralLinkRouter`. Detail screens put official links and maps immediately after the introduction, show the website domain, and suppress duplicate URL actions.

Apple Maps searches the destination name and city, with the catalog coordinate as a search hint. This lets Maps resolve its business listing rather than creating an arbitrary named pin. Parameter behavior follows [Apple's Map Links documentation](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html). Maps links open through the same validated in-app browser route as other venue links. Satellite links retain the existing atlas coordinates.

## Repaired destinations and primary sources

| Destination | Finding and replacement |
| --- | --- |
| Indian Wells | `bnppopen.com` failed DNS. Replaced with the [BNP Paribas Open site](https://bnpparibasopen.com/) and its [tickets page](https://bnpparibasopen.com/tickets). |
| Australian Open | The old tickets subdomain returned HTTP 530. Replaced with [AO ticket information](https://ausopen.com/ticket-info). |
| Queen's Club | The previous LTA tournament domain failed to load. Replaced with the [LTA HSBC Championships page](https://www.lta.org.uk/fan-zone/international/hsbc-championships/) and [LTA ticket information](https://www.lta.org.uk/fan-zone/ticketing-information/). |
| Ferrero | Old `equelite.com` URLs timed out. Updated to the [current academy site](https://ferreroacademy.com/en_en/), [short stays](https://ferreroacademy.com/competicion-corta-estancia/), and [Summer Stage](https://ferreroacademy.com/en_en/summer-stage/). |
| Evert | Followed the official redirects to the current [weekly camps](https://evertacademy.com/tennis-camps/weekly-pre-tournament-camps/) and [academy mission](https://evertacademy.com/about-evert-academy/our-mission/) pages. |
| Meydan / Tennis 360 | The former `tennisthreesixty.com` domain returned HTTP 200 but displayed unrelated gambling content. Removed every occurrence from the catalog. The replacement is the [Meydan Hotel's tennis academy page](https://www.themeydanhotel.com/experiences/meydan-tennis-academy), which identifies Tennis 360 as its operator. Repeated destination URLs appear as one action. |
| Emilio Sánchez Academy | Old `sanchezcasal.com` failed DNS. Preserved the catalog ID and updated the displayed name, [Barcelona site](https://emiliosanchezacademy.com/barcelona), [official enrollment](https://booking.emiliosanchezacademy.com/), and [intensive summer program](https://emiliosanchezacademy.com/en/barcelona/summer/programs/intensive). The primary program source and official booking site identify the Barcelona campus. |
| Rafa Nadal Costa Mujeres | Old camp pages now describe broader international methodology. Followed the current [RNA International Mexico page](https://international.rafanadalacademy.com/en/mexico_/) to the [Cancún center](https://cancun.rafanadaltenniscenter.com/en/), then verified its linked [adult programs](https://cancun.rafanadaltenniscenter.com/en/programs/adult-programs-2/adult-programs/), [junior programs](https://cancun.rafanadaltenniscenter.com/en/programs/juniors-programs/), and [about page](https://cancun.rafanadaltenniscenter.com/en/about-us/). |

Existing official domains for Wimbledon, Roland-Garros, US Open, Monte-Carlo, Rome, Newport, Barcelona, Shanghai, Rafa Nadal Manacor, Mouratoglou, IMG and Riaan Venter were also checked by browser retrieval and/or HTTP requests. Relevant existing links were retained. No partner codes, discounts, availability claims or third-party ticket sellers were added.

## Validation and limits

- Swift syntax parsing and `git diff --check` pass for all three changed source files.
- URL review combines page content and HTTP checks: a successful HTTP status alone does not establish that the content still belongs to the intended venue.
- The final HTTP probe reached 41 of 48 distinct catalog URLs with status 200, including all three Emilio Sánchez URLs. Four Cancún center pages and the Barcelona tournament page returned automated-request restrictions; the RCT Barcelona club and Meydan Hotel pages timed out. Those destinations were corroborated through official page content retrieved by web search/browsing. These responses do not prove a dead page, and phone tap checks remain necessary.
- Final app compilation, in-app browser tap checks, and device layout evidence are handled by the main task. No simulator/build was run by the World editor.
- Catalog coordinates and on-site reward eligibility are unchanged. The Apple Maps place search avoids treating these static atlas coordinates as a verified entrance.
