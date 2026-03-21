# Nexus-Lingua
**Note on AI use:** This project is mainly brainstormed, conceptualized, and built with Gemini 3, Claude Sonnet 4.6 and Cursor. The README file is written by Gemini 3 while PRD is drafted by Gemini 3 and finalized by Claude Sonnet 4.6, for your information.

🌌 **Nexus Lingua: Universal Vocabulary Engine**

**"Vocabulary is not memorized. It is engineered."** 

Nexus Lingua is a gamified flashcards app for learning and practicing vocabulary with a **neon style** and **clear UI**, utilizing **spaced reinforcement** and gamification to drive long-term retention.

Unlike rigid, one-size-fits-all tools, Nexus Lingua is **modular** and adapts to the specific needs of different languages. Features such as **case sensitivity**, **genders**, **and explicit plural forms** are entirely optional, configured via a template-based schema that makes the engine truly language-agnostic.

🛠️ **The Mathematics of Mastery**

Nexus Lingua replaces subjective "self-rating" with algorithmic precision.
**1. FSRS 4.5 Integration**
The application implements the Free Spaced Repetition Scheduler (FSRS 4.5) to optimize the forgetting curve. The engine tracks three primary state variables:
   * **Stability ($S$)**: The interval (in days) required for Retrievability to decay to 90%.
   * **Difficulty ($D$)**: A 1.0–10.0 scale reflecting the intrinsic cognitive load of a word.
   * **Retrievability ($R$)**: The real-time probability of recall, modeled as:$$R(t) = 0.9^{(t/S)}$$
**2. Normalized Linguistic Convergence (Desktop)**
On Windows, the app uses a **Similarity Evaluator** to grade answers automatically. To ensure fairness across words of different lengths, it calculates a **Normalized Levenshtein Ratio ($R$)**:

$$R = 1 - \frac{d\bigl(T(U,p),\ T(T,p)\bigr)}{\max(\text{len}(U),\ \text{len}(T))}$$

This metric allows for minor typos on long German nouns while requiring perfect precision for short lemmas.

🎨 **Cyber-Minimalist Design & Gamification**

The UI is built on a **"Cyber-Minimalist"** aesthetic, using obsidian backgrounds and high-contrast neon accents to create an immersive study environment.
  * **The Box Method:** A dynamic, nested UI grid that expands from 2×2 to 3×2 depending on which linguistic metadata fields (Genders, Plurals, etc.) are active for the current language.
  * **State-Based Shaders:** Neon borders **pulse and glow** based on a card’s Stability ($S$). Words you know well literally shine brighter on your screen.
  * **Visual Progression:** Features linear **XP Bars** for word stability and **Mastery Badges** (Novice → Legend) to reinforce the habit loop.

🏗️ **Technical Stack**

  * **Frontend:** Flutter (Dart) for unified Windows 11 and Android deployment.
  * **Database:** SQLite via a **Singleton** DatabaseHelper, utilizing a JSON-metadata bridge ($\phi$) for schema-less flexibility.
  * **Logic:** Custom Dart implementation of the FSRS algorithm and Levenshtein string metrics.
  * **Sync:** Local-first architecture with optional **JSON Export/Import** and future Supabase mirroring.

**License:** Distributed under the MIT License.
