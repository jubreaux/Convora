# Quick Start Guide - Real Estate Role Play Assistant

## 🚀 Get Up and Running in 5 Minutes

### Prerequisites
- Node.js (v14 or higher)
- npm (comes with Node.js)
- Terminal/Command Prompt

---

## Step 1: Backend Setup (2 minutes)

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Start the server
npm start
```

✅ You should see: `Real Estate Role Play Assistant backend running on port 5000`

---

## Step 2: Frontend Setup (2 minutes)

**Open a NEW terminal window** and run:

```bash
# Navigate to frontend
cd frontend

# Install dependencies
npm install

# Start the app
npm start
```

✅ The app will automatically open at `http://localhost:3000`

---

## Step 3: Start Training! (1 minute)

1. Click any conversation starter or "Select Scenario"
2. Choose a difficulty level
3. Engage in the conversation with the client
4. Try to set an appointment
5. Get your score and detailed feedback!

---

## 🎯 Key Points to Remember

### During a Session
- ❌ You DON'T see the client profile
- ✅ You only see what the client tells you
- ✅ Focus on asking good questions
- ✅ Listen actively and adapt
- ✅ Try to set an appointment

### After the Session
- ✅ Client profile is revealed
- ✅ Your score out of 100 is shown
- ✅ Detailed feedback on strengths and improvements
- ✅ DISC profile analysis

---

## 📊 Understanding Your Score

| Score | Rating | Meaning |
|-------|--------|---------|
| 85-100 | Excellent | Great job! You demonstrated strong sales skills |
| 70-84 | Good | Solid performance with room for growth |
| 60-69 | Adequate | Basic competency; focus on improvements |
| Below 60 | Needs Work | Areas to practice and develop |

---

## 💡 Tips for Success

### Effective Questioning
- Ask open-ended questions ("What brings you in today?" not "Are you buying?")
- Follow up with probing questions
- Show curiosity about their situation
- Uncover pain points and motivations

### Active Listening
- Acknowledge what they say ("I understand..." "That makes sense...")
- Reflect back their concerns
- Show you're focused on their needs
- Don't interrupt or rush

### Building Rapport
- Match their communication style (friendly, direct, detailed, etc.)
- Show genuine interest in them
- Find common ground
- Be authentic and professional

### Setting the Appointment
- Know when it's the right time to ask
- Be clear and specific ("Tuesday at 2 PM work?")
- Provide options to choose from
- Confirm the details
- Express genuine interest in helping them

---

## 🆘 Troubleshooting

### Backend won't start
```bash
# Make sure you're in the backend directory
# Kill any process using port 5000
# Try again: npm start
```

### Frontend won't connect
```bash
# Make sure backend is running first (port 5000)
# Check .env file has correct API URL
# Restart frontend: npm start
```

### Messages aren't sending
```bash
# Check browser console for errors (F12)
# Make sure session ID was created
# Refresh and try again
```

---

## 📁 File Structure at a Glance

```
Real Estate mentor/app/
├── backend/          ← Server (port 5000)
├── frontend/         ← React app (port 3000)
└── scenarios/        ← Training data (JSON files)
```

---

## 🎓 Learning the DISC System

Each scenario features a client with one of four DISC personality types:

- **D** = Dominant (direct, results-focused)
- **I** = Influencing (enthusiastic, people-focused)
- **S** = Steady (supportive, stable)
- **C** = Conscientious (detail-oriented, analytical)

**Pro Tip**: Pay attention to how the client communicates and adapt your approach!

See `DISC_GUIDE.md` for detailed information.

---

## 📝 Typical Session Flow

1. **Greeting** (You read client's opening message)
2. **Discovery** (You ask questions to learn their situation)
3. **Qualification** (You understand their needs and budget)
4. **Presentation** (You show how you can help)
5. **Closing** (You set an appointment)
6. **Feedback** (System reveals client profile and scores you)

---

## 🔧 Want to Add Your Own Scenario?

1. Create a new JSON file in `scenarios/` folder
2. Follow the template from `scenario_001.json`
3. Include DISC profile information
4. Restart backend to load it

---

## 📞 Need Help?

- Check `README.md` for detailed documentation
- Review `DISC_GUIDE.md` for personality type information
- Look at existing scenarios for examples
- Check browser console (F12) for error messages

---

## 🎮 Practice Scenarios Included

1. **First-Time Buyer** (Easy) - Build trust with anxious client
2. **Aggressive Investor** (Medium) - Match pace with fast decision-maker
3. **Relocating Family** (Medium) - Build relationships with social client
4. **Downsizer** (Hard) - Provide detailed analysis for analytical client
5. **Distressed Seller** (Hard) - Show empathy with emotional client

---

## ✨ Pro Tips

- Repeat each scenario multiple times to improve your score
- Try different communication approaches
- Notice how different client types respond differently
- Pay attention to feedback on your performance
- Practice active listening and questioning techniques
- Build genuine rapport with the client

---

**Ready? Start the backend, then the frontend, and begin training! 🚀**

Good luck, and remember - the best ISAs are always learning and adapting!
