// server.js
const express = require("express");
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const cors = require("cors");
require("dotenv").config();
const axios = require("axios");

const app = express();
app.use(express.json());
app.use(cors());

mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB connected"))
  .catch(err => console.error("MongoDB connection error:", err));

/**
 * Schemas
 */
const userSchema = new mongoose.Schema({
  username: String,
  email: { type: String, unique: true, index: true },
  password: String
}, { timestamps: true });

const User = mongoose.model("User", userSchema);

const choiceSchema = new mongoose.Schema({
  id: String,
  text: String,
  consequenceType: { type: String, enum: ["correct", "warning", "fatal", "neutral"], default: "neutral" },
  consequenceText: String,
  scoreDelta: { type: Number, default: 0 }
}, { _id: false });

const sceneSchema = new mongoose.Schema({
  id: Number,
  title: String,
  description: String,
  hint: String,
  choices: [choiceSchema],
  defaultChoiceId: String
}, { _id: false });

const trainingSchema = new mongoose.Schema({
  title: { type: String, required: true },
  summary: String,
  type: String,
  location: {
    name: String,
    floor: String,
    extra: String
  },
  difficulty: { type: String, enum: ["easy","medium","hard"], default: "medium" },
  aiGenerated: { type: Boolean, default: false },
  aiMeta: {
    model: String,
    promptSeed: String,
    version: String
  },
  durationEstimateSec: Number,
  scenes: [sceneSchema],
  summaryMetrics: {
    totalChoices: Number
  },
  stats: {
    attempts: { type: Number, default: 0 },
    successes: { type: Number, default: 0 },
    avgTimeSec: { type: Number, default: 0 }
  },
  tags: [String],
  assets: [String],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
  isPublished: { type: Boolean, default: false }
}, { timestamps: true });

const Training = mongoose.model("Training", trainingSchema);

/**
 * Auth middleware
 */
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "Токен отсутствует" });

  try{
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.id;
    next();
  }catch(err){
    res.status(403).json({message: "Неверный или истекший токен"});
  }
}

/**
 * Hugging Face Router helper + parsers + fallbacks
 */
async function callRouter(body) {
  const HF_TOKEN = process.env.HF_TOKEN;
  const apiUrl = 'https://router.huggingface.co/v1/chat/completions';
  if (!HF_TOKEN) throw new Error('HF_TOKEN not set in environment');

  const resp = await axios.post(apiUrl, body, {
    headers: { Authorization: `Bearer ${HF_TOKEN}`, 'Content-Type': 'application/json' },
    timeout: 90000
  });
  if (!resp.data) throw new Error('Empty response from HF router');
  const d = resp.data;
  let text = '';
  if (Array.isArray(d.choices) && d.choices.length > 0) {
    const ch = d.choices[0];
    if (ch.message && typeof ch.message.content === 'string') text = ch.message.content;
    else if (ch.text && typeof ch.text === 'string') text = ch.text;
    else text = JSON.stringify(ch);
  } else if (typeof d.output === 'string') {
    text = d.output;
  } else {
    text = JSON.stringify(d);
  }
  return text;
}

function extractJsonArray(text) {
  const first = text.indexOf('[');
  const last = text.lastIndexOf(']');
  if (first !== -1 && last !== -1 && last > first) {
    const jsonStr = text.slice(first, last + 1);
    return JSON.parse(jsonStr);
  }
  throw new Error('No JSON array found in model output');
}

/** Local fallback: simple skeleton (titles only) */
function simpleGenerateScenesSkeleton(title, scenesCount = 5, choicesPerScene = 3) {
  const base = (title || "Сценарий").trim();
  const scenes = [];
  for (let i = 1; i <= scenesCount; i++) {
    const choices = [];
    for (let c = 0; c < choicesPerScene; c++) {
      const id = String.fromCharCode(97 + c); // a, b, c...
      choices.push({
        id,
        text: `Вариант ${id.toUpperCase()} для сцены ${i}`,
        consequenceType: "neutral",
        consequenceText: "",
        scoreDelta: 0
      });
    }
    scenes.push({
      id: i,
      title: `${base} — Сцена ${i}`,
      description: `Короткое описание для сцены ${i}.`,
      hint: `Подсказка для сцены ${i}.`,
      choices,
      defaultChoiceId: choices[0].id
    });
  }
  return scenes;
}

/** Local full fallback (theory + practice style -> here: descriptions + choices) */
function simpleGenerateScenes(title, scenesCount = 5, choicesPerScene = 3) {
  const base = (title || "Сценарий").trim();
  const scenes = [];
  for (let i = 1; i <= scenesCount; i++) {
    const choices = [];
    for (let c = 0; c < choicesPerScene; c++) {
      const id = String.fromCharCode(97 + c);
      const isCorrect = c === 0; // первый вариант — корректный по умолчанию
      choices.push({
        id,
        text: isCorrect ? `Правильное действие ${id.toUpperCase()} при ситуации ${i}` : `Неправильное/менее удачное действие ${id.toUpperCase()} при ситуации ${i}`,
        consequenceType: isCorrect ? "correct" : (c === 1 ? "warning" : "fatal"),
        consequenceText: isCorrect ? `Это безопасный и рекомендованный вариант.` : (c === 1 ? "Это рискованно — приведёт к замедлению эвакуации." : "Это опасно — возможны жертвы."),
        scoreDelta: isCorrect ? 10 : (c === 1 ? -2 : -10)
      });
    }
    scenes.push({
      id: i,
      title: `${base} — Сцена ${i}`,
      description: `Подробное описание ситуации ${i}, где участнику нужно принять решение в условиях ограниченного времени.`,
      hint: `Подумайте о безопасности людей и возможных путях эвакуации.`,
      choices,
      defaultChoiceId: choices[0].id
    });
  }
  return scenes;
}

/** Generate scenes via HF Router */
async function generateScenesHf(title, scenesCount = 5, choicesPerScene = 3) {
  const model = process.env.HF_MODEL;
  const systemMsg = 'You are an assistant that outputs ONLY valid JSON arrays. Use concise Russian. No extra text.';
  const prompt = `
Generate EXACTLY a JSON array of scene objects for a training with title: "${title}".
Return an array with ${scenesCount} objects. Each object must have:
- id: number (1..${scenesCount})
- title: short title (string)
- description: one paragraph describing the scene/situation
- hint: 1-2 sentence hint for the participant
- choices: an array with ${choicesPerScene} objects, each having:
  - id: string ("a","b","c",...)
  - text: short text of the choice
  - consequenceType: one of "correct","warning","fatal","neutral"
  - consequenceText: one short sentence describing consequence
  - scoreDelta: integer (can be negative or positive)
- defaultChoiceId: the id of a default choice (e.g. "a")

Do NOT output any explanation or extra text — ONLY the JSON array.
Example element:
{"id":1,"title":"...","description":"...","hint":"...","choices":[{"id":"a","text":"...","consequenceType":"correct","consequenceText":"...","scoreDelta":10}, ...],"defaultChoiceId":"a"}
`;

  const body = {
    model,
    messages: [
      { role: 'system', content: systemMsg },
      { role: 'user', content: prompt }
    ],
    stream: false,
    max_new_tokens: 1200,
    temperature: 0.25
  };

  try {
    const text = await callRouter(body);
    const parsed = extractJsonArray(text);
    if (!Array.isArray(parsed)) throw new Error('Parsed not array');
    // Normalize parsed items
    const scenes = parsed.map((it, idx) => {
      const choices = Array.isArray(it.choices) ? it.choices.map((c, ci) => ({
        id: String(c.id || String.fromCharCode(97 + ci)),
        text: String(c.text || '').trim(),
        consequenceType: (String(c.consequenceType || 'neutral')).trim(),
        consequenceText: String(c.consequenceText || '').trim(),
        scoreDelta: Number(c.scoreDelta || 0)
      })) : [];
      return {
        id: Number(it.id) || (idx + 1),
        title: String(it.title || `Сцена ${idx+1}`).trim(),
        description: String(it.description || '').trim(),
        hint: String(it.hint || '').trim(),
        choices,
        defaultChoiceId: String(it.defaultChoiceId || (choices.length ? choices[0].id : 'a'))
      };
    });
    return scenes;
  } catch (err) {
    console.warn('generateScenesHf failed, using fallback:', err.message || err);
    // fallback to full generator
    return simpleGenerateScenes(title, scenesCount, choicesPerScene);
  }
}

/**
 * Auth routes (register/login) and users/profile
 */
app.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body;
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ message: "Пользователь уже существует" });

    const hash = await bcrypt.hash(password, 10);
    const newUser = new User({ username, email, password: hash });
    await newUser.save();

    const token = jwt.sign({ id: newUser._id }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.status(201).json({ message: "Регистрация успешна", token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "Неверный email или пароль" });

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(400).json({ message: "Неверный email или пароль" });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: "1d" });
    res.json({ message: "Успешный вход", token });
  } catch (err) {
    res.status(500).json({ message: "Ошибка сервера" });
  }
});

app.get("/users", async(req, res) =>{
  try{
    const users = await User.find({}, "-password");
    res.json(users);
  }catch(err){
    res.status(500).json({message: "Ошибка при получении пользователей"});
  }
});

app.get("/profile", authMiddleware, async(req, res) =>{
  try{
    const user = await User.findById(req.userId, "-password");
    if (!user) return res.status(404).json({message: "Пользователь не найден"});
    res.json(user);
  }catch(err){
    res.status(500).json({message: "Ошибка при получении данных профиля"});
  }
});

/**
 * Trainings endpoints
 */

/** List trainings */
app.get("/trainings", async (req, res) => {
  try {
    const { type, tag, isPublished, q, limit = 20, skip = 0 } = req.query;
    const filter = {};
    if (type) filter.type = type;
    if (typeof isPublished !== "undefined") filter.isPublished = isPublished === "true";
    if (tag) filter.tags = tag;
    if (q) filter.$text = { $search: q };

    const trainings = await Training.find(filter)
      .select("-scenes.choices.consequenceText")
      .limit(Math.min(100, parseInt(limit)))
      .skip(parseInt(skip))
      .sort({ createdAt: -1 });

    res.json(trainings);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при получении тренингов" });
  }
});

/** Get one training */
app.get("/trainings/:id", async (req, res) => {
  try {
    const t = await Training.findById(req.params.id).populate("createdBy", "username email");
    if (!t) return res.status(404).json({ message: "Тренировка не найдена" });
    res.json(t);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при получении тренировки" });
  }
});

/** Create training (auth) — с интеграцией AI (если нужно) */
app.post("/trainings", authMiddleware, async (req, res) => {
  try {
    const payload = req.body;
    if (!payload.title) return res.status(400).json({ message: "Не указан title" });

    // determine scenes: if scenes provided and non-empty => use them; otherwise if aiGenerate true => call HF; else require at least one scene
    let scenes = Array.isArray(payload.scenes) ? payload.scenes : [];
    const defaultScenesCount = Number(process.env.DEFAULT_SCENES) || 5;
    const scenesCount = Number(payload.scenesCount) || defaultScenesCount;
    const choicesPerScene = Number(payload.choicesPerScene) || 3;

    let aiMeta = { model: null, promptSeed: null, version: null };
    let aiGeneratedFlag = false;

    if ((!scenes || scenes.length === 0) && payload.aiGenerate) {
      // generate via HF (full scenes)
      try {
        const generated = await generateScenesHf(payload.title, scenesCount, choicesPerScene);
        // ensure ids are numeric and choices ids exist
        scenes = generated.map((s, idx) => ({
          id: Number(s.id) || (idx + 1),
          title: s.title,
          description: s.description,
          hint: s.hint,
          choices: Array.isArray(s.choices) ? s.choices : [],
          defaultChoiceId: s.defaultChoiceId || (Array.isArray(s.choices) && s.choices.length ? s.choices[0].id : "a")
        }));
        aiGeneratedFlag = true;
        aiMeta = { model: process.env.HF_MODEL || null, promptSeed: payload.title, version: new Date().toISOString() };
      } catch (err) {
        console.warn("AI generation failed during create, falling back to local generator:", err.message || err);
        scenes = simpleGenerateScenes(payload.title, scenesCount, choicesPerScene);
        aiGeneratedFlag = false;
      }
    } else if ((!scenes || scenes.length === 0) && !payload.aiGenerate) {
      // if no scenes and user didn't request aiGenerate — use simple skeleton fallback with defaultScenesCount
      scenes = simpleGenerateScenesSkeleton(payload.title, scenesCount, choicesPerScene);
    } else {
      // scenes provided by user — ensure shape and numeric ids
      scenes = scenes.map((s, idx) => ({
        id: Number(s.id) || (idx + 1),
        title: s.title || `Сцена ${idx+1}`,
        description: s.description || "",
        hint: s.hint || "",
        choices: Array.isArray(s.choices) ? s.choices.map((c, ci) => ({
          id: String(c.id || String.fromCharCode(97 + ci)),
          text: c.text || "",
          consequenceType: c.consequenceType || "neutral",
          consequenceText: c.consequenceText || "",
          scoreDelta: Number(c.scoreDelta || 0)
        })) : [],
        defaultChoiceId: s.defaultChoiceId || (Array.isArray(s.choices) && s.choices.length ? s.choices[0].id : "a")
      }));
    }

    // calculate totalChoices
    const totalChoices = scenes.reduce((acc, s) => acc + (Array.isArray(s.choices) ? s.choices.length : 0), 0);

    const training = new Training({
      ...payload,
      scenes,
      aiGenerated: aiGeneratedFlag,
      aiMeta,
      summaryMetrics: { totalChoices },
      createdBy: req.userId
    });

    await training.save();
    res.status(201).json(training);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при создании тренировки" });
  }
});

/** Update training */
app.put("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    Object.assign(training, req.body);

    if (Array.isArray(req.body.scenes)) {
      training.summaryMetrics = { totalChoices: req.body.scenes.length };
    }

    await training.save();
    res.json(training);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при обновлении тренировки" });
  }
});

/** Delete training */
app.delete("/trainings/:id", authMiddleware, async (req, res) => {
  try {
    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    await Training.deleteOne({ _id: req.params.id });
    res.json({ message: "Тренировка удалена" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при удалении тренировки" });
  }
});

/**
 * Attempt endpoint unchanged
 */
app.post("/trainings/:id/attempt", authMiddleware, async (req, res) => {
  try {
    const { choices, timeSec } = req.body;
    if (!Array.isArray(choices)) return res.status(400).json({ message: "Неверные данные попытки" });

    const training = await Training.findById(req.params.id);
    if (!training) return res.status(404).json({ message: "Тренировка не найдена" });

    const sceneMap = new Map();
    for (const s of training.scenes) {
      const choiceMap = new Map();
      for (const c of s.choices) choiceMap.set(c.id, c);
      sceneMap.set(s.id, { scene: s, choices: choiceMap });
    }

    let totalScore = 0;
    let correctAnswers = 0;
    let totalScenesConsidered = 0;
    const details = [];

    for (const userChoice of choices) {
      const { sceneId, choiceId } = userChoice;
      const sm = sceneMap.get(sceneId);
      if (!sm) {
        details.push({ sceneId, ok: false, reason: "Сцена не найдена" });
        continue;
      }
      totalScenesConsidered++;
      const choice = sm.choices.get(choiceId);
      if (!choice) {
        details.push({ sceneId, ok: false, reason: "Выбор не найден" });
        continue;
      }

      totalScore += (choice.scoreDelta || 0);
      if (choice.consequenceType === "correct") correctAnswers++;
      details.push({
        sceneId,
        choiceId,
        consequenceType: choice.consequenceType,
        scoreDelta: choice.scoreDelta
      });
    }

    const totalChoices = training.summaryMetrics?.totalChoices ?? training.scenes.length;
    const success = (correctAnswers === totalChoices);

    const prevAttempts = training.stats.attempts || 0;
    const prevAvg = training.stats.avgTimeSec || 0;
    const newAttempts = prevAttempts + 1;
    const newAvgTime = prevAvg === 0 ? (timeSec || 0) : Math.round(((prevAvg * prevAttempts) + (timeSec || 0)) / newAttempts);

    training.stats.attempts = newAttempts;
    if (success) training.stats.successes = (training.stats.successes || 0) + 1;
    training.stats.avgTimeSec = newAvgTime;

    await training.save();

    res.json({
      message: "Результат записан",
      result: {
        totalScore,
        correctAnswers,
        totalChoices,
        success,
        timeSec: timeSec || null,
        details
      },
      updatedStats: training.stats
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Ошибка при записи попытки" });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
