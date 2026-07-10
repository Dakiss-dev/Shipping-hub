# Shipping Hub

> Package intake and shipment management for diaspora shipment operators.

Diaspora shipping operators (the people who fill a container in Washington DC or Paris and get your packages to Ouagadougou or Bamako) mostly run on WhatsApp messages and paper notebooks. Shipping Hub is a Flutter app that gives an operator a real system: package intake, customer records, shipment batches, and status tracking, with cloud sync.

Built after shipping [SD Express](https://sd-express.pages.dev), a live site for exactly this kind of business. This is the operator-side tool of the same world.

## Features

- **Package intake:** log packages with sender, receiver, international phone numbers (proper country codes), and per-package detail screens
- **Shipment batches:** group packages into shipments, track status through the shipping lifecycle
- **Customer records:** repeat senders and receivers, one tap away
- **WhatsApp sharing:** share package/shipment info with customers on the channel they actually use, with correct international number formatting
- **Auth and onboarding:** email verification, Google Sign-In, guided business setup wizard, welcoming empty states
- **Cloud sync:** Supabase backend (`supabase/schema.sql` included), offline-tolerant local storage with a sync service
- **Installable PWA:** runs as a web app with a manifest and iOS meta tags, so operators install it from the browser, no app store needed
- **Bilingual-ready:** l10n scaffolding in place (EN/FR world)

## Stack

Flutter/Dart · Supabase (PostgreSQL, Auth) · PWA web target

## Run it

```bash
flutter pub get

# create a Supabase project, apply supabase/schema.sql, then:
cp env.example.json env.json   # fill in your project URL + anon key
flutter run --dart-define-from-file=env.json
```

## Status

Working MVP, built in a 6-day sprint (Feb 2026). The original demo backend has been retired; bring your own Supabase project with the included schema. Part of a trilogy of diaspora-logistics systems I've shipped, alongside [SD Express](https://sd-express.pages.dev) (customer-facing site, live) and a 4-role water-delivery ops app run daily across two continents.

## License

MIT.
