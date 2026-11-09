# Telegram_logs_media: mídia do grupo @arqueologiadigital

Layer 2 of the archive of the Telegram group [@arqueologiadigital](https://t.me/arqueologiadigital):
photos, stickers, GIFs, audio and documents of **10 MB or less**, as posted.

The messages and the index of these files are in
[`Telegram_logs`](https://github.com/ArqueologiaDigital/Telegram_logs).
`media/manifest.jsonl` there maps every file to its message id, size and sha256, so the
files can be verified without this repo's history.

| path                          | what                                                         |
|-------------------------------|--------------------------------------------------------------|
| `YYYY/YYYY-MM/<msgid>[-name]` | media of message `<msgid>`, posted in that UTC month         |
| `legacy/2018-telegram-cli/`   | the files saved by the 2018 dump, under their original names |

Larger files (videos, big documents) are in the Internet Archive item
`arqueologiadigital-telegram-media`; their URLs are in the manifest (`ia_url`).

Files are written only by `tools/tg_media.py` in `Telegram_logs`; nothing here is edited by hand.
Media of deleted messages is kept; the message's `archive.deletion` record says so.
