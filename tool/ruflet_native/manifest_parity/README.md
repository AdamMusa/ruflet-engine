One `<feature>.txt` per feature whose replaced plugin merges entries into
apps today (SPEC §6.2 table): one manifest element per line, copied from the
old plugin's AndroidManifest.xml, for example

    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

`../check_manifest_parity.sh` fails when the example's merged manifest lacks
one. Entries the owner accepted to drop (D6) are not listed.
