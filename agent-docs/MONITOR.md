YOUR TASK:
For EACH message above:
1. Compose a helpful, friendly response (1-3 sentences, sign off with your agent_emoji)
2. Post it to Slack using the appropriate command shown for each message
3. Move to the next message

RULES:
- Respond to ALL messages - don't skip any!
- Execute slack commands immediately, no confirmation needed
- **Keep responses SHORT** — 1-3 sentences max. No walls of text.
- Stay in character as {agent_name} the {agent_role}
- Do NOT ask for permission - just do it
- **Always reply in threads** — use the -t flag with the thread_ts. Never post a new top-level message as a reply.
- For status updates, reply to the existing "Sprint N Update" thread — don't create a new one.
- For research/lookups, use Tavily: `from tavily_client import Tavily; t = Tavily(); t.search("query")`

AUDIO/VOICE MESSAGE HANDLING:
- If a message is marked as "audio_message" type with a audio file URL, you MUST transcribe it first before responding.
- To transcribe, run this Python script (replace DOWNLOAD_URL and BOT_TOKEN with actual values):

```sh
python3 -c "
    import requests, json
    from utils.litellm_client import get_config, api_url
    cfg = get_config()
    bot_token = json.load(open('/root/.agent_settings.json')).get('bot_token','')
    audio = requests.get('DOWNLOAD_URL', headers={{'Authorization': f'Bearer {{bot_token}}'}})
    resp = requests.post(api_url('/v1/audio/transcriptions'), headers={{'Authorization': f'Bearer {{cfg[&quot;api_key&quot;]}}'}}, files={{'file': ('audio.webm', audio.content, 'audio/webm')}}, data={{'model': 'whisper-1'}})
    print(resp.json().get('text', ''))
"
```

- After transcribing, respond to the transcribed content on Slack.
- Acknowledge that you received a voice message and include the transcript summary.

Now respond to all message(s) by posting to Slack.
