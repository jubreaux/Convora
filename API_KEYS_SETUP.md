# 🔑 API Keys Configuration Guide

Your Convora app needs API keys to function:

## 1. Anthropic API Key (For Conversations)

**Required for**: Claude AI to handle training conversations

**Get your key:**
1. Go to https://console.anthropic.com/
2. Sign up or log in
3. Navigate to **API Keys** section
4. Create a new API key or copy an existing one
5. Copy the key (starts with `sk-ant-`)

**Update**: Edit `backend/.env`

```env
ANTHROPIC_API_KEY="sk-ant-your-actual-key-here"
```

---

## 2. OpenAI API Key (For Text-to-Speech)

**Required for**: Voice feature - converts AI responses to speech (DISC voice mapping)

**Get your key:**
1. Go to https://platform.openai.com/api-keys
2. Sign up or log in with OpenAI account
3. Click **+ Create new secret key**
4. Copy the key immediately (starts with `sk-`)

**Update**: Edit `backend/.env`

```env
OPENAI_API_KEY="sk-your-actual-key-here"
```

---

## 3. Location & File Format

**File**: `backend/.env`

**Full .env file should look like:**
```env
ANTHROPIC_API_KEY="sk-ant-your-actual-key"
OPENAI_API_KEY="sk-your-actual-key"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
DATABASE_URL="sqlite:///./convora.db"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=10080
```

---

## 4. After Updating Keys

1. **Stop backend**: Press `Ctrl+C` in backend terminal
2. **Restart backend**:
   ```bash
   cd backend
   source ../.venv/bin/activate
   python3 main.py
   ```
3. **Restart Flutter app**: Press `r` in Flutter terminal for hot reload, or `R` for restart

---

## 5. Test It Works

1. Login with `test@example.com` / `password123`
2. Click a scenario (e.g., "Real Estate Sales Call")
3. Send a message via voice or text
4. **Voice test**: Tap the mic button and speak
5. **Should see**: AI response with synthetic speech playing

---

## ⚠️ Important Notes

- **Keep keys secret**: Never commit `.env` to GitHub
- **Free tier limits**: Check Anthropic and OpenAI pricing (usually $5-20/month for testing)
- **Rate limits**: Both services have rate limits on free plans
- **Environment file**: `.env` is already in `.gitignore` ✅

---

## 🐛 Troubleshooting

**"No module named anthropic"** → Missing dependency
- Solution: `pip install -r requirements.txt` in backend directory

**"Invalid API key"** → Key is wrong or expired
- Solution: Verify key format matches the service (sk-ant-* vs sk-*)

**No voice playback** → OpenAI key missing
- Solution: Add OPENAI_API_KEY to .env and restart backend

**Connection refused** → Backend not running
- Solution: Ensure `python3 main.py` is running in backend terminal

---

**Need help?** Check backend logs: `tail -50 /tmp/backend.log`
