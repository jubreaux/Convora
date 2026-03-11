# Setup Verification Checklist

Use this checklist to verify that everything is installed correctly before running the application.

## ✅ Prerequisites Check

- [ ] **Node.js Installed** (v14 or higher)
  ```bash
  node --version
  ```
  Expected output: `v14.0.0` or higher

- [ ] **npm Installed**
  ```bash
  npm --version
  ```
  Expected output: `6.0.0` or higher

- [ ] **Project Folder Exists**
  ```
  c:\Users\breau\OneDrive\Documents\projects\Real Estate mentor\app\
  ```

---

## ✅ Backend Setup Verification

### Step 1: Navigate to Backend
- [ ] Open terminal/command prompt
- [ ] Run: `cd backend`
- [ ] Verify: Current directory shows `backend` in path

### Step 2: Install Dependencies
- [ ] Run: `npm install`
- [ ] Wait for completion (may take 1-2 minutes)
- [ ] Verify: `node_modules` folder created
- [ ] Verify: No error messages

### Step 3: Start Backend Server
- [ ] Run: `npm start`
- [ ] Verify: Output shows "Real Estate Role Play Assistant backend running on port 5000"
- [ ] Verify: No error messages
- [ ] Verify: Terminal shows no crashes

### Step 4: Test Backend
In a new terminal, run:
```bash
curl http://localhost:5000/api/scenarios
```
- [ ] Should return JSON array of scenarios
- [ ] Should not have connection errors

---

## ✅ Frontend Setup Verification

### Step 1: Open New Terminal Window
- [ ] Do NOT close the backend terminal
- [ ] Open a NEW terminal/command prompt

### Step 2: Navigate to Frontend
- [ ] Run: `cd frontend`
- [ ] Verify: Current directory shows `frontend` in path

### Step 3: Install Dependencies
- [ ] Run: `npm install`
- [ ] Wait for completion (may take 2-3 minutes)
- [ ] Verify: `node_modules` folder created
- [ ] Verify: No error messages

### Step 4: Start Frontend Server
- [ ] Run: `npm start`
- [ ] Verify: Browser automatically opens to http://localhost:3000
- [ ] Verify: Welcome page displays correctly
- [ ] Verify: No console errors (press F12 to check)

---

## ✅ Application Functionality Check

### Menu Screen
- [ ] Title "🏠 Real Estate Role Play Assistant" displays
- [ ] Welcome text is visible
- [ ] 4 conversation starter buttons visible
- [ ] Buttons are clickable

### Scenario Selection
- [ ] Click any conversation starter button
- [ ] Scenario selector page loads
- [ ] "Back to Menu" button visible
- [ ] All 6 scenarios display with titles
- [ ] Difficulty badges show (Easy, Medium, Hard)
- [ ] Duration shows for each scenario

### Start Training Session
- [ ] Click "Start This Scenario" on any scenario
- [ ] Training session page loads
- [ ] Client greeting message displays
- [ ] Message input field is visible
- [ ] "Send Message" button is visible
- [ ] Status badge shows "● Active"

### Send Messages
- [ ] Type a message in the input field
- [ ] Click "Send Message" or press Enter
- [ ] Your message appears with "👤 You" label
- [ ] Client response appears with "🤝 Client" label
- [ ] Continue conversation for 5-10 exchanges

### Conversation Progression
- [ ] Messages flow naturally
- [ ] Client responds to your messages
- [ ] Message timestamps display
- [ ] Conversation area scrolls smoothly

### Appointment Setting
- [ ] Say something about scheduling a meeting
- [ ] Watch for status to change to "✓ Appointment Set"
- [ ] Green success badge appears
- [ ] "View Feedback & Score" button becomes active

### Feedback Screen
- [ ] Click "View Feedback & Score"
- [ ] Score circle displays with number (0-100)
- [ ] Client profile displays (name, age, DISC type, etc.)
- [ ] Strengths section shows list
- [ ] Improvements section shows list
- [ ] Conversation metrics display
- [ ] "Try Another Scenario" button is visible

### Return to Menu
- [ ] Click "Try Another Scenario" or "New Scenario"
- [ ] Returns to menu or scenario selector
- [ ] Can start another scenario

---

## ✅ Backend Files Check

Verify all these files exist:
- [ ] `backend/package.json`
- [ ] `backend/server.js`
- [ ] `backend/.gitignore`
- [ ] `backend/node_modules/` (folder)

---

## ✅ Frontend Files Check

Verify all these files exist:
- [ ] `frontend/package.json`
- [ ] `frontend/.env`
- [ ] `frontend/.gitignore`
- [ ] `frontend/src/App.js`
- [ ] `frontend/src/App.css`
- [ ] `frontend/src/index.js`
- [ ] `frontend/src/components/ScenarioSelector.js`
- [ ] `frontend/src/components/TrainingSession.js`
- [ ] `frontend/src/components/FeedbackScreen.js`
- [ ] `frontend/public/index.html`
- [ ] `frontend/node_modules/` (folder)

---

## ✅ Scenario Files Check

Verify all 6 scenarios exist:
- [ ] `scenarios/scenario_001.json` (First-Time Buyer)
- [ ] `scenarios/scenario_002.json` (Aggressive Investor)
- [ ] `scenarios/scenario_003.json` (Relocating Family)
- [ ] `scenarios/scenario_004.json` (Downsizer)
- [ ] `scenarios/scenario_005.json` (Distressed Seller)
- [ ] `scenarios/scenario_006.json` (Retired Downsizer)

---

## ✅ Documentation Files Check

Verify all documentation exists:
- [ ] `README.md`
- [ ] `QUICKSTART.md`
- [ ] `DISC_GUIDE.md`
- [ ] `API_DOCUMENTATION.md`
- [ ] `PROJECT_SUMMARY.md`
- [ ] `.github/copilot-instructions.md`

---

## ✅ Browser & UI Check

### Responsive Design (Desktop)
- [ ] Page displays properly at 1920px width
- [ ] Page displays properly at 1024px width
- [ ] All text is readable
- [ ] Buttons are clickable
- [ ] Colors display correctly

### Responsive Design (Tablet)
- [ ] Page displays at ~768px width
- [ ] Layout adjusts for tablet
- [ ] Touch targets are large enough
- [ ] No horizontal scrolling needed

### Responsive Design (Mobile)
- [ ] Page displays at ~375px width
- [ ] Layout is mobile-friendly
- [ ] Messages display vertically
- [ ] Buttons are easy to tap
- [ ] No horizontal scrolling

### CSS Styling
- [ ] Purple/gradient theme displays
- [ ] Buttons have hover effects
- [ ] Messages have different colors for ISA vs Client
- [ ] Animations are smooth
- [ ] Layout uses flexbox properly

---

## ✅ Network & API Check

### Backend API
- [ ] Backend responds on http://localhost:5000
- [ ] GET /api/scenarios returns JSON
- [ ] POST /api/sessions creates session
- [ ] POST /api/sessions/:id/messages works
- [ ] POST /api/sessions/:id/end generates feedback

### CORS Configuration
- [ ] Frontend can communicate with backend
- [ ] No CORS errors in browser console (F12)
- [ ] API responses arrive within 200ms

### Session Management
- [ ] Each session has unique ID
- [ ] Messages are stored correctly
- [ ] Session ends without errors
- [ ] Feedback includes all details

---

## ✅ Console Check

Press F12 in browser and check Console tab:
- [ ] No red error messages
- [ ] No "Failed to fetch" errors
- [ ] No CORS errors
- [ ] Only yellow warnings are acceptable

---

## ✅ Performance Check

### Load Times
- [ ] Menu loads instantly
- [ ] Scenarios load in < 1 second
- [ ] Session starts in < 2 seconds
- [ ] Messages send in < 1 second
- [ ] Feedback generates in < 2 seconds

### Memory Usage
- [ ] Page doesn't lag after 10+ messages
- [ ] No memory leaks visible
- [ ] Browser tab stays responsive

---

## 🐛 Common Issues & Fixes

### Issue: "Backend not running on port 5000"
```bash
# Kill the process using port 5000
# On Windows:
netstat -ano | findstr :5000
taskkill /PID [PID] /F

# Then restart: npm start
```

### Issue: "Cannot GET /api/scenarios"
```bash
# Make sure backend is running
# Check that you're hitting http://localhost:5000
# Not http://localhost:3000
```

### Issue: "CORS error in console"
```bash
# This shouldn't happen - backend has CORS enabled
# Try restarting both frontend and backend
```

### Issue: "Scenarios not loading"
```bash
# Check scenario files exist in scenarios/ folder
# Verify JSON syntax is correct
# Restart backend to reload scenarios
```

### Issue: "Session ID not found"
```bash
# Make sure backend is running
# Don't send messages before starting session
# Check browser console for errors
```

---

## ✅ Full Workflow Test

Complete this full workflow to verify everything:

1. [ ] Start backend (terminal 1): `npm start` from backend folder
2. [ ] Verify backend is running on port 5000
3. [ ] Start frontend (terminal 2): `npm start` from frontend folder
4. [ ] Browser opens to http://localhost:3000
5. [ ] Click "Start a new scenario"
6. [ ] Select "Scenario 1: First-Time Home Buyer"
7. [ ] Read the client's greeting
8. [ ] Type: "Hi, thanks for reaching out. Can you tell me what brings you in today?"
9. [ ] Click Send Message
10. [ ] Verify client responds
11. [ ] Continue conversation for 5-10 exchanges
12. [ ] Try to schedule an appointment
13. [ ] Verify status changes to "✓ Appointment Set"
14. [ ] View feedback
15. [ ] Verify score displays (0-100)
16. [ ] Verify client profile shows name, DISC type, budget, etc.
17. [ ] Check strengths and improvements sections
18. [ ] Click "Try Another Scenario"
19. [ ] Verify you're back at scenario selector
20. [ ] Done! ✅

---

## ✅ Deployment Readiness Checklist

Before deploying to production:
- [ ] All tests pass
- [ ] No console errors
- [ ] Performance is acceptable
- [ ] Mobile design is responsive
- [ ] API response times are good
- [ ] Error handling is robust
- [ ] Documentation is complete
- [ ] Code is properly commented
- [ ] Security headers are added (when deploying)
- [ ] Database is configured (when deploying)

---

## 📝 Sign-Off

**Setup Completed By**: ___________________
**Date**: ___________________
**Issues Found**: ___________________
**Resolution**: ___________________

---

## 🎉 Success!

If all checkboxes are checked, your Real Estate Role Play Assistant is fully functional and ready to use!

### Next Steps:
1. Review `DISC_GUIDE.md` to understand personality types
2. Go through each scenario to understand different client types
3. Practice improving your score
4. Share with other ISAs for training
5. Provide feedback for improvements

**Happy training! 🚀**
