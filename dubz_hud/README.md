# Dubz HUD

Dubz HUD is a Garry's Mod DarkRP HUD and UI suite built on DubzFramework.

## AI Disclosure

AI assistance was used during review and revision for code-audit suggestions, UI polish recommendations, documentation drafting, and refactor planning. The addon remains structured, tested, supported, and maintained by the author; AI is not required to understand, repair, or extend the product.

## Install

Place both folders in `garrysmod/addons/`:

- `dubzframework`
- `dhud`

Restart the server or refresh Lua after installing.

## Admin

Open the master Dubz admin console with:

```text
dubzconfig
```

Open the HUD menu directly with:

```text
dubzhud
dhud_config
```

Only admins can save HUD configuration. Server-side config is stored under the `data/dhud/` folder.

The Overview tab includes language selection and interface hover sound settings. Built-in HUD labels support English, Spanish, French, German, and Portuguese (Brazil).

## Notes

- The HUD does not run remote code.
- Optional scoreboard images are limited to Imgur image IDs or `https://i.imgur.com/*.png` URLs.
- DubzFramework is required and included in this package.
