# MindMaster — Brain Training Games

> 6 brain-training games in one app. Built with pure HTML, CSS & JavaScript. No frameworks, no downloads. Just play.

![MindMaster Banner](docs/screenshots/home.png)

## 🎮 Games

| Game | Description | Difficulty |
|------|-------------|------------|
| **Math Sprint** | 60 seconds of speed math. +, -, ×, ÷ | Easy / Medium / Hard |
| **Logic Puzzles** | Sudoku-lite puzzles, 4×4 to 9×9 grids | Easy (4×4) / Medium (6×6) / Hard (9×9) |
| **Color Match** | Stroop test. Tap the COLOR, not the word! | 4 / 6 / 8 colors |
| **Focus Grid** | Tap 1-25 in order. How fast can you go? | 4×4 / 5×5 / 6×6 |
| **Memory Matrix** | Pattern recall memory game | Coming soon |
| **Pattern Recall** | Simon Says style game | Coming soon |

## ✨ Features

- **Pure Web** — HTML, CSS & JavaScript only. No frameworks.
- **Offline Ready** — No external CDN dependencies. Works without internet.
- **2040 Aesthetic** — Glassmorphism, neon accents, particle backgrounds.
- **Mouse Tracking** — Interactive 3D tilt effects on cards.
- **Sound Effects** — Procedural audio synthesis (Web Audio API).
- **Haptic Feedback** — Vibration support on mobile devices.
- **Progress Tracking** — Local storage for scores & achievements.
- **Responsive** — Works on mobile, tablet & desktop.

## 🚀 Play Now

**Live URL:** https://fsix7115-arch.github.io/MindMaster/

Or run locally:
```bash
cd mindmaster
python3 -m http.server 8080
# Open http://localhost:8080
```

## 📁 Project Structure

```
mindmaster/
├── index.html              # Landing page with all games
├── math-sprint.html        # Speed math game
├── logic-puzzles.html      # Sudoku-lite puzzles
├── color-match.html        # Stroop color test
├── focus-grid.html         # Number tap challenge
├── assets/
│   ├── css/
│   │   └── styles.css      # 2040 futuristic theme
│   ├── js/
│   │   ├── core/           # Engine, storage, audio, haptics
│   │   ├── games/          # Game modules
│   │   └── shared/         # Reusable UI components
│   └── models/             # 3D assets
└── docs/
    └── screenshots/        # Game screenshots
```

## 🎨 Tech Stack

- **HTML5** — Semantic markup
- **CSS3** — Glassmorphism, animations, responsive design
- **JavaScript (ES6+)** — No frameworks
- **Web Audio API** — Procedural sound synthesis
- **IndexedDB** — Local game data persistence
- **Three.js** — 3D elements (optional)

## 🛠️ Development

```bash
# Clone the repo
git clone https://github.com/fsix7115-arch/MindMaster.git
cd MindMaster

# Make changes
# Edit HTML, CSS, or JS files

# Test locally
python3 -m http.server 8080

# Commit & push
git add .
git commit -m "Your message"
git push origin main
```

## 📱 Browser Support

- Chrome 80+
- Firefox 75+
- Safari 14+
- Edge 80+
- Mobile browsers

## 📄 License

MIT License — Free for personal & commercial use.

## 👨💻 Author

Built with ❤️ by **Aether** (AI Assistant) for the MindMaster project.

---

**MindMaster** — Train your brain, one game at a time.